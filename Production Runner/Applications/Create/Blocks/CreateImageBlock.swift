import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Image Block
struct CreateImageBlock: View {
    let block: CreateBlockModel
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @State private var isHovering: Bool = false
    @State private var showImagePicker: Bool = false

    private var content: ImageContent {
        block.imageContent ?? ImageContent()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let imageData = content.imageData, let image = imageFromData(imageData) {
                // Image display
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(imageOverlay)
            } else {
                // Placeholder
                placeholderView
            }

            // Caption
            if !content.caption.isEmpty {
                Text(content.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
            }
        }
        .background(Color.purple.opacity(0.05))
        .onHover { hovering in
            isHovering = hovering
        }
        .onDrop(of: [.image], isTargeted: nil) { providers in
            handleImageDrop(providers)
        }
    }

    // MARK: - Placeholder View
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Drop image here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(.secondary.opacity(0.3))
                .padding(8)
        )
    }

    // MARK: - Image Overlay
    @ViewBuilder
    private var imageOverlay: some View {
        if isHovering {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        // Clear image
                        onContentUpdate { b in
                            var c = b.imageContent ?? ImageContent()
                            c.imageData = nil
                            b.encodeContent(c)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Image Helpers
    #if os(macOS)
    private func imageFromData(_ data: Data) -> CGImage? {
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
    }
    #else
    private func imageFromData(_ data: Data) -> CGImage? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
    }
    #endif

    // MARK: - Drop Handler
    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
            if let data = data {
                DispatchQueue.main.async {
                    onContentUpdate { b in
                        var c = b.imageContent ?? ImageContent()
                        c.imageData = data
                        b.encodeContent(c)
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Preview
#if DEBUG
struct CreateImageBlock_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CreateImageBlock(
                block: .createImage(at: .zero),
                onContentUpdate: { _ in }
            )
            .frame(width: 200, height: 200)
        }
        .padding()
    }
}
#endif
