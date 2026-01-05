import SwiftUI

// MARK: - Toolbar View
struct CreateToolbar: View {
    @ObservedObject var canvasViewModel: CreateCanvasViewModel
    @Binding var showBoardBrowser: Bool
    @Binding var showInspector: Bool

    @State private var showAddMenu: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Board browser toggle
            #if os(macOS)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBoardBrowser.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .customTooltip("Toggle Board Browser")
            #endif

            Divider().frame(height: 20)

            // Add block menu
            Menu {
                ForEach(CreateBlockType.allCases) { type in
                    Button {
                        canvasViewModel.addBlock(type: type, at: .zero)
                    } label: {
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Block type quick buttons
            HStack(spacing: 4) {
                ForEach([CreateBlockType.note, .image, .link, .todo], id: \.self) { type in
                    BlockTypeButton(type: type) {
                        canvasViewModel.addBlock(type: type, at: .zero)
                    }
                }
            }

            Divider().frame(height: 20)

            // Connector tool
            Toggle(isOn: Binding(
                get: { canvasViewModel.isConnectorMode },
                set: { newValue in
                    if newValue {
                        // Start connector mode - user needs to select source block
                    } else {
                        canvasViewModel.cancelConnector()
                    }
                }
            )) {
                Image(systemName: "arrow.right")
            }
            .toggleStyle(.button)
            .customTooltip("Connect Blocks")

            Spacer()

            // Board name
            if let board = canvasViewModel.currentBoard {
                Text(board.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Grid toggle
            Toggle(isOn: $canvasViewModel.showGrid) {
                Image(systemName: "grid")
            }
            .toggleStyle(.button)
            .customTooltip("Toggle Grid")

            // Snap to grid toggle
            Toggle(isOn: $canvasViewModel.snapToGrid) {
                Image(systemName: "rectangle.3.group")
            }
            .toggleStyle(.button)
            .customTooltip("Snap to Grid")

            Divider().frame(height: 20)

            // Zoom controls
            HStack(spacing: 4) {
                Button {
                    canvasViewModel.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Text("\(Int(canvasViewModel.canvasScale * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 45)

                Button {
                    canvasViewModel.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Button {
                    canvasViewModel.zoomToFit()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .customTooltip("Zoom to Fit")
            }

            Divider().frame(height: 20)

            // Inspector toggle
            #if os(macOS)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showInspector.toggle()
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .customTooltip("Toggle Inspector")
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
    }
}

// MARK: - Block Type Button
struct BlockTypeButton: View {
    let type: CreateBlockType
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))
                Text(type.displayName)
                    .font(.system(size: 9))
            }
            .frame(width: 50, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? type.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(isHovered ? type.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .draggable(CreateNewBlockDragItem(blockType: type))
        .customTooltip("Add \(type.displayName)")
    }
}

// MARK: - Preview
#if DEBUG
struct CreateToolbar_Previews: PreviewProvider {
    static var previews: some View {
        CreateToolbar(
            canvasViewModel: CreateCanvasViewModel(),
            showBoardBrowser: .constant(true),
            showInspector: .constant(true)
        )
    }
}
#endif
