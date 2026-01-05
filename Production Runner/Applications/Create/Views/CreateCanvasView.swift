import SwiftUI
import UniformTypeIdentifiers

// MARK: - Canvas View
struct CreateCanvasView: View {
    @ObservedObject var viewModel: CreateCanvasViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var isDraggingBlock: Bool = false
    @State private var lastDragPosition: CGPoint = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                if viewModel.showGrid {
                    CreateGridView(spacing: viewModel.gridSpacing, scale: viewModel.canvasScale)
                }

                // Canvas background
                canvasBackground

                // Connectors layer (rendered below blocks)
                ForEach(viewModel.connectors) { connector in
                    CreateConnectorView(
                        connector: connector,
                        blocks: viewModel.blocks,
                        canvasOffset: viewModel.canvasOffset,
                        canvasScale: viewModel.canvasScale,
                        geometrySize: geometry.size
                    )
                }

                // Blocks layer
                ForEach(viewModel.blocks.sorted(by: { $0.zIndex < $1.zIndex })) { block in
                    CreateBlockView(
                        block: block,
                        isSelected: viewModel.selectedBlockIDs.contains(block.id),
                        isConnectorMode: viewModel.isConnectorMode,
                        onSelect: { addToSelection in
                            viewModel.selectBlock(block.id, addToSelection: addToSelection)
                        },
                        onDragStart: {
                            viewModel.saveStateForUndo()
                        },
                        onDrag: { delta in
                            viewModel.moveBlock(block.id, by: delta)
                        },
                        onDragEnd: {},
                        onResize: { size in
                            viewModel.resizeBlock(block.id, to: size)
                        },
                        onConnectorTap: {
                            if viewModel.isConnectorMode {
                                viewModel.completeConnector(to: block.id)
                            } else {
                                viewModel.startConnector(from: block.id)
                            }
                        },
                        onContentUpdate: { update in
                            viewModel.updateBlock(block.id, update: update)
                        }
                    )
                    .position(
                        canvasToScreen(block.position, in: geometry.size)
                    )
                    .scaleEffect(viewModel.canvasScale)
                }

                // Connector mode indicator
                if viewModel.isConnectorMode {
                    connectorModeOverlay
                }
            }
            .contentShape(Rectangle())
            .gesture(canvasPanGesture)
            .gesture(canvasMagnificationGesture)
            .onTapGesture {
                if viewModel.isConnectorMode {
                    viewModel.cancelConnector()
                } else {
                    viewModel.clearSelection()
                }
            }
            .onDrop(of: [.createBlockDragItem, .image, .fileURL, .url], delegate: CanvasDropDelegate(
                viewModel: viewModel,
                geometrySize: geometry.size,
                screenToCanvas: screenToCanvas
            ))
            .contextMenu {
                canvasContextMenu
            }
        }
    }

    // MARK: - Canvas Background
    private var canvasBackground: some View {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }

    // MARK: - Connector Mode Overlay
    private var connectorModeOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Text("Click a block to connect")
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }
            Spacer()
        }
    }

    // MARK: - Canvas Context Menu
    @ViewBuilder
    private var canvasContextMenu: some View {
        Menu("Add Block") {
            ForEach(CreateBlockType.allCases) { type in
                Button {
                    viewModel.addBlock(type: type, at: .zero)
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        }

        Divider()

        Button("Copy") {
            viewModel.copySelectedBlocks()
        }
        .disabled(!viewModel.hasSelection)
        .keyboardShortcut("c", modifiers: .command)

        Button("Paste") {
            viewModel.pasteBlocks()
        }
        .disabled(!viewModel.hasCopiedBlocks)
        .keyboardShortcut("v", modifiers: .command)

        Button("Duplicate") {
            viewModel.duplicateSelectedBlocks()
        }
        .disabled(!viewModel.hasSelection)
        .keyboardShortcut("d", modifiers: .command)

        Divider()

        Button("Zoom to Fit") {
            viewModel.zoomToFit()
        }

        Button("Reset Zoom") {
            viewModel.resetZoom()
        }
    }

    // MARK: - Gestures
    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDraggingBlock {
                    let delta = CGSize(
                        width: value.translation.width - dragOffset.width,
                        height: value.translation.height - dragOffset.height
                    )
                    viewModel.canvasOffset.x -= delta.width / viewModel.canvasScale
                    viewModel.canvasOffset.y -= delta.height / viewModel.canvasScale
                    dragOffset = value.translation
                }
            }
            .onEnded { _ in
                dragOffset = .zero
            }
    }

    private var canvasMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let newScale = viewModel.canvasScale * scale
                viewModel.canvasScale = max(0.25, min(3.0, newScale))
            }
    }

    // MARK: - Coordinate Conversion
    private func canvasToScreen(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - viewModel.canvasOffset.x) * viewModel.canvasScale + size.width / 2,
            y: (point.y - viewModel.canvasOffset.y) * viewModel.canvasScale + size.height / 2
        )
    }

    private func screenToCanvas(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - size.width / 2) / viewModel.canvasScale + viewModel.canvasOffset.x,
            y: (point.y - size.height / 2) / viewModel.canvasScale + viewModel.canvasOffset.y
        )
    }
}

// MARK: - Canvas Drop Delegate
struct CanvasDropDelegate: DropDelegate {
    let viewModel: CreateCanvasViewModel
    let geometrySize: CGSize
    let screenToCanvas: (CGPoint, CGSize) -> CGPoint

    func performDrop(info: DropInfo) -> Bool {
        let location = screenToCanvas(info.location, geometrySize)

        // Handle block type drops from toolbar
        if info.hasItemsConforming(to: [.createBlockDragItem]) {
            let providers = info.itemProviders(for: [.createBlockDragItem])
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.createBlockDragItem.identifier) { data, _ in
                    if let data = data,
                       let item = try? JSONDecoder().decode(CreateNewBlockDragItem.self, from: data),
                       let type = item.type {
                        DispatchQueue.main.async {
                            viewModel.addBlock(type: type, at: location)
                        }
                    }
                }
            }
            return true
        }

        // Handle image drops
        if info.hasItemsConforming(to: [.image]) {
            let providers = info.itemProviders(for: [.image])
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            _ = CreateBlockModel.createImage(at: location, imageData: data)
                            viewModel.addBlock(type: .image, at: location)
                        }
                    }
                }
            }
            return true
        }

        // Handle URL drops
        if info.hasItemsConforming(to: [.url]) {
            let providers = info.itemProviders(for: [.url])
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            viewModel.addBlock(type: .link, at: location, url: url)
                            // URL content will be fetched automatically
                        }
                    }
                }
            }
            return true
        }

        return false
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.createBlockDragItem, .image, .fileURL, .url])
    }
}

// MARK: - Grid View
struct CreateGridView: View {
    let spacing: CGFloat
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let scaledSpacing = spacing * scale
            guard scaledSpacing > 4 else { return } // Don't draw if too zoomed out

            let cols = Int(size.width / scaledSpacing) + 2
            let rows = Int(size.height / scaledSpacing) + 2

            var path = Path()

            // Vertical lines
            for i in 0...cols {
                let x = CGFloat(i) * scaledSpacing
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            // Horizontal lines
            for i in 0...rows {
                let y = CGFloat(i) * scaledSpacing
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CreateCanvasView_Previews: PreviewProvider {
    static var previews: some View {
        CreateCanvasView(viewModel: CreateCanvasViewModel())
    }
}
#endif
