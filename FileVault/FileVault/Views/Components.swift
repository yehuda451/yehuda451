import SwiftUI

extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Color {
    static func fileIconTint(for iconColor: String) -> Color {
        switch iconColor {
        case "folder": return .accentColor
        case "image": return .green
        case "movie": return .purple
        case "audio": return .pink
        case "pdf": return .red
        case "archive": return .orange
        default: return .secondary
        }
    }
}

struct FileIconView: View {
    let node: FileNode
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: node.systemImageName)
            .font(.system(size: size * 0.62))
            .foregroundStyle(Color.fileIconTint(for: node.iconColor))
            .frame(width: size, height: size)
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TextFieldAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let placeholder: String
    var initialText: String = ""
    let onSubmit: (String) -> Void

    @State private var text: String = ""

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { onSubmit(trimmed) }
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue { text = initialText }
        }
    }
}

extension View {
    func textFieldAlert(
        isPresented: Binding<Bool>,
        title: String,
        placeholder: String,
        initialText: String = "",
        onSubmit: @escaping (String) -> Void
    ) -> some View {
        modifier(TextFieldAlertModifier(
            isPresented: isPresented,
            title: title,
            placeholder: placeholder,
            initialText: initialText,
            onSubmit: onSubmit
        ))
    }
}
