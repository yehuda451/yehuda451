import Foundation
import Compression

/// Zip/unzip with no third-party dependencies.
///
/// Compression reuses the documented `NSFileCoordinator(.forUploading)` trick,
/// which asks the system to produce a zip of a file or directory the same way
/// Mail/Share Sheet do. Extraction is a small hand-rolled reader of the ZIP
/// central directory, since Foundation has no public unzip API on iOS.
///
/// Limitations: extraction supports the common "stored" and "deflated" entry
/// types (covers everything `zip`/Finder/Windows produce) but not encrypted
/// archives or Zip64 (>4GB / >65535 entries) — rare on a phone-sized archive.
enum ZipService {
    enum ZipError: LocalizedError {
        case invalidArchive
        case unsupportedCompressionMethod
        case decompressionFailed

        var errorDescription: String? {
            switch self {
            case .invalidArchive:
                return "This doesn't look like a valid zip archive."
            case .unsupportedCompressionMethod:
                return "This archive uses a compression method that isn't supported."
            case .decompressionFailed:
                return "Couldn't decompress one of the files in this archive."
            }
        }
    }

    // MARK: - Compress

    static func zip(items: [URL], to destination: URL) throws {
        let fileManager = FileManager.default
        let sourceDirectory: URL
        let cleanupTemp: Bool

        if items.count == 1, items[0].hasDirectoryPath {
            sourceDirectory = items[0]
            cleanupTemp = false
        } else {
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            for item in items {
                try fileManager.copyItem(at: item, to: tempDir.appendingPathComponent(item.lastPathComponent))
            }
            sourceDirectory = tempDir
            cleanupTemp = true
        }
        defer {
            if cleanupTemp { try? fileManager.removeItem(at: sourceDirectory) }
        }

        var coordinatorError: NSError?
        var thrownError: Error?
        NSFileCoordinator().coordinate(readingItemAt: sourceDirectory, options: [.forUploading], error: &coordinatorError) { zippedURL in
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: zippedURL, to: destination)
            } catch {
                thrownError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let thrownError { throw thrownError }
    }

    // MARK: - Extract

    static func unzip(_ archiveURL: URL, to destinationDirectory: URL) throws {
        let data = try Data(contentsOf: archiveURL)
        let entries = try centralDirectoryEntries(in: data)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        for entry in entries {
            let sanitizedComponents = entry.name
                .split(separator: "/", omittingEmptySubsequences: true)
                .filter { $0 != ".." && $0 != "." }
            guard !sanitizedComponents.isEmpty else { continue }
            let relativePath = sanitizedComponents.joined(separator: "/")
            let outputURL = destinationDirectory.appendingPathComponent(relativePath)

            if entry.name.hasSuffix("/") {
                try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
                continue
            }

            try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let fileData = try extractData(for: entry, from: data)
            try fileData.write(to: outputURL, options: .atomic)
        }
    }

    // MARK: - ZIP parsing

    private struct Entry {
        let name: String
        let compressionMethod: UInt16
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    private static func centralDirectoryEntries(in data: Data) throws -> [Entry] {
        guard let eocdOffset = findEndOfCentralDirectory(in: data) else {
            throw ZipError.invalidArchive
        }
        let totalEntries = Int(data.fv_readUInt16(at: eocdOffset + 10))
        var offset = Int(data.fv_readUInt32(at: eocdOffset + 16))

        var entries: [Entry] = []
        entries.reserveCapacity(totalEntries)

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count, data.fv_readUInt32(at: offset) == 0x02014b50 else {
                throw ZipError.invalidArchive
            }
            let method = data.fv_readUInt16(at: offset + 10)
            let compressedSize = data.fv_readUInt32(at: offset + 20)
            let uncompressedSize = data.fv_readUInt32(at: offset + 24)
            let nameLength = Int(data.fv_readUInt16(at: offset + 28))
            let extraLength = Int(data.fv_readUInt16(at: offset + 30))
            let commentLength = Int(data.fv_readUInt16(at: offset + 32))
            let localHeaderOffset = data.fv_readUInt32(at: offset + 42)

            let nameStart = offset + 46
            guard nameStart + nameLength <= data.count else { throw ZipError.invalidArchive }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) ?? ""

            entries.append(Entry(
                name: name,
                compressionMethod: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))

            offset = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let searchFloor = max(0, data.count - 22 - 65535)
        var offset = data.count - 22
        while offset >= searchFloor {
            if data.fv_readUInt32(at: offset) == 0x06054b50 {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func extractData(for entry: Entry, from data: Data) throws -> Data {
        let localOffset = Int(entry.localHeaderOffset)
        guard localOffset + 30 <= data.count, data.fv_readUInt32(at: localOffset) == 0x04034b50 else {
            throw ZipError.invalidArchive
        }
        let nameLength = Int(data.fv_readUInt16(at: localOffset + 26))
        let extraLength = Int(data.fv_readUInt16(at: localOffset + 28))
        let dataStart = localOffset + 30 + nameLength + extraLength
        let dataEnd = dataStart + Int(entry.compressedSize)
        guard dataStart <= dataEnd, dataEnd <= data.count else { throw ZipError.invalidArchive }
        let compressedData = data.subdata(in: dataStart..<dataEnd)

        switch entry.compressionMethod {
        case 0:
            return compressedData
        case 8:
            return try inflate(compressedData, uncompressedSize: Int(entry.uncompressedSize))
        default:
            throw ZipError.unsupportedCompressionMethod
        }
    }

    private static func inflate(_ data: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        var output = Data(count: uncompressedSize)
        let resultSize = output.withUnsafeMutableBytes { outBuffer -> Int in
            data.withUnsafeBytes { inBuffer -> Int in
                guard let outPointer = outBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let inPointer = inBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                // Apple's Compression framework's "ZLIB" algorithm operates on raw
                // DEFLATE streams (no zlib/gzip wrapper), which is exactly what a
                // ZIP entry's compression method 8 stores.
                return compression_decode_buffer(outPointer, uncompressedSize, inPointer, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard resultSize == uncompressedSize else {
            throw ZipError.decompressionFailed
        }
        return output
    }
}

private extension Data {
    func fv_readUInt16(at offset: Int) -> UInt16 {
        let base = startIndex + offset
        return UInt16(self[base]) | (UInt16(self[base + 1]) << 8)
    }

    func fv_readUInt32(at offset: Int) -> UInt32 {
        let base = startIndex + offset
        return UInt32(self[base])
            | (UInt32(self[base + 1]) << 8)
            | (UInt32(self[base + 2]) << 16)
            | (UInt32(self[base + 3]) << 24)
    }
}
