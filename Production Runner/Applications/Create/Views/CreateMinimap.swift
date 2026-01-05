import SwiftUI

// MARK: - Minimap View
struct CreateMinimap: View {
    @ObservedObject var viewModel: CreateCanvasViewModel

    @State private var isDragging: Bool = false

    // Minimap scale factor (how much smaller than actual canvas)
    private let minimapScale: CGFloat = 0.05

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))

                // Blocks representation
                ForEach(viewModel.blocks) { block in
                    Rectangle()
                        .fill(blockColor(for: block))
                        .frame(
                            width: max(4, block.width * minimapScale),
                            height: max(4, block.height * minimapScale)
                        )
                        .position(
                            x: geometry.size.width / 2 + (block.positionX - viewModel.canvasOffset.x) * minimapScale,
                            y: geometry.size.height / 2 + (block.positionY - viewModel.canvasOffset.y) * minimapScale
                        )
                }

                // Viewport indicator
                viewportIndicator(in: geometry.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .gesture(minimapDragGesture(in: geometry.size))
        }
    }

    // MARK: - Block Color
    private func blockColor(for block: CreateBlockModel) -> Color {
        if viewModel.selectedBlockIDs.contains(block.id) {
            return .white
        }
        return block.blockType.accentColor.opacity(0.8)
    }

    // MARK: - Viewport Indicator
    private func viewportIndicator(in size: CGSize) -> some View {
        // Calculate viewport size relative to canvas scale
        let viewportWidth = size.width / viewModel.canvasScale
        let viewportHeight = size.height / viewModel.canvasScale

        return Rectangle()
            .strokeBorder(Color.white, lineWidth: isDragging ? 2 : 1)
            .background(Color.white.opacity(isDragging ? 0.2 : 0.1))
            .frame(
                width: max(20, viewportWidth * minimapScale * 10),
                height: max(20, viewportHeight * minimapScale * 10)
            )
            .position(
                x: size.width / 2,
                y: size.height / 2
            )
    }

    // MARK: - Drag Gesture
    private func minimapDragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true

                // Convert minimap coordinates to canvas coordinates
                let deltaX = value.translation.width / minimapScale
                let deltaY = value.translation.height / minimapScale

                viewModel.canvasOffset.x += deltaX * 0.1
                viewModel.canvasOffset.y += deltaY * 0.1
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

// MARK: - Preview
#if DEBUG
struct CreateMinimap_Previews: PreviewProvider {
    static var previews: some View {
        CreateMinimap(viewModel: {
            let vm = CreateCanvasViewModel()
            vm.blocks = [
                .createNote(at: CGPoint(x: 100, y: 100)),
                .createImage(at: CGPoint(x: 300, y: 200)),
                .createTodo(at: CGPoint(x: -100, y: 50))
            ]
            return vm
        }())
        .frame(width: 150, height: 100)
        .padding()
        .background(Color.gray)
    }
}
#endif
