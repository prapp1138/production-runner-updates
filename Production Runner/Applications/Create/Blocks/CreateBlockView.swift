import SwiftUI

// MARK: - Block View (Container)
struct CreateBlockView: View {
    let block: CreateBlockModel
    let isSelected: Bool
    let isConnectorMode: Bool

    let onSelect: (Bool) -> Void
    let onDragStart: () -> Void
    let onDrag: (CGSize) -> Void
    let onDragEnd: () -> Void
    let onResize: (CGSize) -> Void
    let onConnectorTap: () -> Void
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false
    @State private var isResizing: Bool = false

    private let resizeHandleSize: CGFloat = 10
    private let minBlockSize: CGFloat = 50

    var body: some View {
        ZStack {
            // Block content
            blockContent
                .frame(width: block.width, height: block.height)
                .background(blockBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(selectionOverlay)
                .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 8 : 4, y: 2)

            // Resize handles (when selected)
            if isSelected && !block.isLocked {
                resizeHandles
            }

            // Connector handle (when in connector mode or hovered)
            if isConnectorMode || isHovered {
                connectorHandle
            }
        }
        .opacity(block.isLocked ? 0.7 : 1.0)
        .offset(dragOffset)
        .gesture(selectionGesture)
        .gesture(dragGesture)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Block Content
    @ViewBuilder
    private var blockContent: some View {
        switch block.blockType {
        case .note:
            CreateNoteBlock(block: block, onContentUpdate: onContentUpdate)
        case .image:
            CreateImageBlock(block: block, onContentUpdate: onContentUpdate)
        case .link:
            CreateLinkBlock(block: block, onContentUpdate: onContentUpdate)
        case .file:
            CreateFileBlock(block: block, onContentUpdate: onContentUpdate)
        case .color:
            CreateColorBlock(block: block, onContentUpdate: onContentUpdate)
        case .todo:
            CreateTodoBlock(block: block, onContentUpdate: onContentUpdate)
        case .boardLink:
            CreateBoardLinkBlock(block: block, onContentUpdate: onContentUpdate)
        }
    }

    // MARK: - Block Background
    private var blockBackground: some View {
        Group {
            if let hex = block.colorHex, let color = Color(createHex: hex) {
                color.opacity(0.1)
            } else {
                #if os(macOS)
                Color(NSColor.controlBackgroundColor)
                #else
                Color(UIColor.secondarySystemBackground)
                #endif
            }
        }
    }

    // MARK: - Selection Overlay
    private var selectionOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isSelected ? Color.blue : (isHovered ? Color.blue.opacity(0.3) : Color.clear),
                lineWidth: isSelected ? 2 : 1
            )
    }

    // MARK: - Resize Handles
    private var resizeHandles: some View {
        ZStack {
            // Corner handles
            ForEach(CreateResizeHandle.allCases, id: \.self) { handle in
                Circle()
                    .fill(Color.blue)
                    .frame(width: resizeHandleSize, height: resizeHandleSize)
                    .position(handlePosition(for: handle))
                    .gesture(resizeGesture(for: handle))
                    .onHover { hovering in
                        if hovering {
                            #if os(macOS)
                            NSCursor.crosshair.push()
                            #endif
                        } else {
                            #if os(macOS)
                            NSCursor.pop()
                            #endif
                        }
                    }
            }
        }
        .frame(width: block.width, height: block.height)
    }

    // MARK: - Connector Handle
    private var connectorHandle: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    onConnectorTap()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.plain)
                .offset(x: 10, y: -10)
            }
            Spacer()
        }
        .frame(width: block.width, height: block.height)
    }

    // MARK: - Handle Position
    private func handlePosition(for handle: CreateResizeHandle) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: 0, y: 0)
        case .topRight:
            return CGPoint(x: block.width, y: 0)
        case .bottomLeft:
            return CGPoint(x: 0, y: block.height)
        case .bottomRight:
            return CGPoint(x: block.width, y: block.height)
        }
    }

    // MARK: - Gestures
    private var selectionGesture: some Gesture {
        TapGesture()
            .onEnded {
                #if os(macOS)
                let addToSelection = NSEvent.modifierFlags.contains(.shift)
                #else
                let addToSelection = false
                #endif
                onSelect(addToSelection)
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if block.isLocked { return }

                if !isDragging {
                    isDragging = true
                    onDragStart()
                }

                dragOffset = value.translation
            }
            .onEnded { value in
                if block.isLocked { return }

                onDrag(value.translation)
                dragOffset = .zero
                isDragging = false
                onDragEnd()
            }
    }

    private func resizeGesture(for handle: CreateResizeHandle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if block.isLocked { return }

                if !isResizing {
                    isResizing = true
                    onDragStart()
                }

                var newWidth = block.width
                var newHeight = block.height

                switch handle {
                case .topLeft:
                    newWidth = max(minBlockSize, block.width - value.translation.width)
                    newHeight = max(minBlockSize, block.height - value.translation.height)
                case .topRight:
                    newWidth = max(minBlockSize, block.width + value.translation.width)
                    newHeight = max(minBlockSize, block.height - value.translation.height)
                case .bottomLeft:
                    newWidth = max(minBlockSize, block.width - value.translation.width)
                    newHeight = max(minBlockSize, block.height + value.translation.height)
                case .bottomRight:
                    newWidth = max(minBlockSize, block.width + value.translation.width)
                    newHeight = max(minBlockSize, block.height + value.translation.height)
                }

                onResize(CGSize(width: newWidth, height: newHeight))
            }
            .onEnded { _ in
                isResizing = false
            }
    }
}

// MARK: - Resize Handle Enum
enum CreateResizeHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Preview
#if DEBUG
struct CreateBlockView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CreateBlockView(
                block: .createNote(at: .zero),
                isSelected: true,
                isConnectorMode: false,
                onSelect: { _ in },
                onDragStart: {},
                onDrag: { _ in },
                onDragEnd: {},
                onResize: { _ in },
                onConnectorTap: {},
                onContentUpdate: { _ in }
            )

            CreateBlockView(
                block: .createTodo(at: .zero),
                isSelected: false,
                isConnectorMode: false,
                onSelect: { _ in },
                onDragStart: {},
                onDrag: { _ in },
                onDragEnd: {},
                onResize: { _ in },
                onConnectorTap: {},
                onContentUpdate: { _ in }
            )
        }
        .padding(50)
    }
}
#endif
