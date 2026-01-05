import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Block
struct CreateFileBlock: View {
    let block: CreateBlockModel
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @State private var isHovering: Bool = false

    private var content: FileContent {
        block.fileContent ?? FileContent()
    }

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            fileIcon
                .frame(width: 40, height: 40)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(content.fileName.isEmpty ? "Drop file here" : content.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !content.fileName.isEmpty {
                    Text(formattedFileSize)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
        .onHover { hovering in
            isHovering = hovering
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
    }

    // MARK: - File Icon
    @ViewBuilder
    private var fileIcon: some View {
        let iconName = fileIconName(for: content.fileType)

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(fileColor.opacity(0.15))

            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundStyle(fileColor)
        }
    }

    // MARK: - Helpers
    private var fileColor: Color {
        switch content.fileType.lowercased() {
        case "pdf": return .red
        case "doc", "docx": return .blue
        case "xls", "xlsx": return .green
        case "ppt", "pptx": return .orange
        case "txt", "rtf": return .gray
        case "zip", "rar": return .purple
        case "mp3", "wav", "aac": return .pink
        case "mp4", "mov", "avi": return .indigo
        default: return .gray
        }
    }

    private func fileIconName(for type: String) -> String {
        switch type.lowercased() {
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "play.rectangle.fill"
        case "txt", "rtf": return "doc.plaintext.fill"
        case "zip", "rar": return "doc.zipper"
        case "mp3", "wav", "aac": return "music.note"
        case "mp4", "mov", "avi": return "film.fill"
        case "jpg", "jpeg", "png", "gif": return "photo.fill"
        default: return "doc.fill"
        }
    }

    private var formattedFileSize: String {
        let bytes = content.fileSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }

    // MARK: - Drop Handler
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            DispatchQueue.main.async {
                let fileName = url.lastPathComponent
                let fileType = url.pathExtension
                let fileSize: Int64

                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    fileSize = size
                } else {
                    fileSize = 0
                }

                onContentUpdate { b in
                    var c = FileContent()
                    c.fileName = fileName
                    c.fileType = fileType
                    c.fileSize = fileSize
                    // Note: For full implementation, you'd copy the file data
                    b.encodeContent(c)
                }
            }
        }
        return true
    }
}

// MARK: - Preview
#if DEBUG
struct CreateFileBlock_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CreateFileBlock(
                block: {
                    var block = CreateBlockModel.createFile(at: .zero)
                    let content = FileContent(fileName: "Document.pdf", fileSize: 1024 * 1024, fileType: "pdf")
                    block.encodeContent(content)
                    return block
                }(),
                onContentUpdate: { _ in }
            )
            .frame(width: 180, height: 60)

            CreateFileBlock(
                block: .createFile(at: .zero),
                onContentUpdate: { _ in }
            )
            .frame(width: 180, height: 60)
        }
        .padding()
    }
}
#endif
