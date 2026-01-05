import SwiftUI

// MARK: - Link Block
struct CreateLinkBlock: View {
    let block: CreateBlockModel
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @State private var isEditing: Bool = false
    @State private var isHovering: Bool = false
    @State private var isFetching: Bool = false

    private var content: LinkContent {
        block.linkContent ?? LinkContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing || content.url.isEmpty {
                editingView
            } else {
                linkPreviewView
            }
        }
        .background(Color.blue.opacity(0.05))
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            isEditing = true
        }
    }

    // MARK: - Editing View
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.blue)
                Text("Add Link")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            TextField("Enter URL...", text: Binding(
                get: { content.url },
                set: { newValue in
                    onContentUpdate { b in
                        var c = b.linkContent ?? LinkContent()
                        c.url = newValue
                        b.encodeContent(c)
                    }
                }
            ), onCommit: {
                isEditing = false
                fetchLinkMetadata()
            })
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))

            HStack {
                Spacer()
                Button("Done") {
                    isEditing = false
                    fetchLinkMetadata()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
    }

    // MARK: - Link Preview View
    private var linkPreviewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area
            if let thumbnailData = content.thumbnailData,
               let image = thumbnailImage(from: thumbnailData) {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 80)
                    .clipped()
            } else {
                // Placeholder thumbnail
                HStack {
                    Spacer()
                    Image(systemName: "link")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue.opacity(0.5))
                    Spacer()
                }
                .frame(height: 60)
                .background(Color.blue.opacity(0.1))
            }

            // Content area
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title.isEmpty ? urlDomain : content.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)

                if !content.description.isEmpty {
                    Text(content.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                    Text(urlDomain)
                        .font(.system(size: 9))
                }
                .foregroundStyle(.blue)
            }
            .padding(8)

            // Hover overlay
            if isHovering {
                HStack {
                    Spacer()
                    Button {
                        openURL()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .padding(4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
            }
        }
    }

    // MARK: - Helpers
    private var urlDomain: String {
        guard let url = URL(string: content.url),
              let host = url.host else {
            return content.url
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    #if os(macOS)
    private func thumbnailImage(from data: Data) -> CGImage? {
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
    }
    #else
    private func thumbnailImage(from data: Data) -> CGImage? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
    }
    #endif

    private func openURL() {
        guard let url = URL(string: content.url) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func fetchLinkMetadata() {
        guard !content.url.isEmpty else { return }
        // Basic metadata fetch - in production, use LinkPresentation framework
        isFetching = true

        // For now, just update with URL domain as title
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onContentUpdate { b in
                var c = b.linkContent ?? LinkContent()
                if c.title.isEmpty {
                    c.title = urlDomain
                }
                b.encodeContent(c)
            }
            isFetching = false
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CreateLinkBlock_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CreateLinkBlock(
                block: {
                    var block = CreateBlockModel.createLink(at: .zero, url: "https://example.com")
                    let content = LinkContent(url: "https://example.com", title: "Example Website", description: "This is an example website")
                    block.encodeContent(content)
                    return block
                }(),
                onContentUpdate: { _ in }
            )
            .frame(width: 240, height: 120)

            CreateLinkBlock(
                block: .createLink(at: .zero),
                onContentUpdate: { _ in }
            )
            .frame(width: 240, height: 80)
        }
        .padding()
    }
}
#endif
