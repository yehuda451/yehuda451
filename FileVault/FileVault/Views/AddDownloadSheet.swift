import SwiftUI
import UIKit

struct AddDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var customName = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("https://example.com/file.zip", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        if let clipboardString = UIPasteboard.general.string {
                            urlString = clipboardString
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                }
                Section("Save As (optional)") {
                    TextField("Leave blank to use the link's filename", text: $customName)
                        .autocorrectionDisabled()
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("New Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") { startDownload() }
                        .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func startDownload() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            errorMessage = "That doesn't look like a valid web link."
            return
        }
        DownloadEngine.shared.startDownload(from: url, suggestedName: customName)
        dismiss()
    }
}

#Preview {
    AddDownloadSheet()
}
