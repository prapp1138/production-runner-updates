import SwiftUI

// MARK: - Board Link Block
struct CreateBoardLinkBlock: View {
    let block: CreateBlockModel
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @State private var isHovering: Bool = false

    private var content: BoardLinkContent {
        block.boardLinkContent ?? BoardLinkContent()
    }

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 24))
                    .foregroundStyle(.teal)
            }

            // Board name
            Text(content.linkedBoardName.isEmpty ? "Link to Board" : content.linkedBoardName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Chevron indicator
            if content.linkedBoardID != nil {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.teal.opacity(0.6))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.teal.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isHovering ? Color.teal.opacity(0.5) : Color.teal.opacity(0.2),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CreateBoardLinkBlock_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            CreateBoardLinkBlock(
                block: {
                    let block = CreateBlockModel.createBoardLink(at: .zero, boardID: UUID(), boardName: "Design Board")
                    return block
                }(),
                onContentUpdate: { _ in }
            )
            .frame(width: 160, height: 120)

            CreateBoardLinkBlock(
                block: .createBoardLink(at: .zero),
                onContentUpdate: { _ in }
            )
            .frame(width: 160, height: 120)
        }
        .padding()
    }
}
#endif
