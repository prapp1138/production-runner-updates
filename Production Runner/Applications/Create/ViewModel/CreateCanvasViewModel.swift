import SwiftUI
import CoreData
import Combine

// MARK: - Canvas State for Undo/Redo
struct CreateCanvasState: Equatable {
    var blocks: [CreateBlockModel]
    var connectors: [CreateConnectorModel]
}

// MARK: - Canvas View Model
class CreateCanvasViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var blocks: [CreateBlockModel] = []
    @Published var connectors: [CreateConnectorModel] = []
    @Published var selectedBlockIDs: Set<UUID> = []
    @Published var currentBoardID: UUID?
    @Published var currentBoard: CreateBoardModel?

    @Published var canvasOffset: CGPoint = .zero
    @Published var canvasScale: CGFloat = 1.0

    @Published var isConnectorMode: Bool = false
    @Published var connectorSourceID: UUID?

    @Published var gridSpacing: CGFloat = 20
    @Published var showGrid: Bool = true
    @Published var snapToGrid: Bool = false

    // MARK: - Undo/Redo Manager
    let undoRedoManager = UndoRedoManager<CreateCanvasState>(maxHistorySize: 20)

    // MARK: - Core Data Context
    private var moc: NSManagedObjectContext?

    // MARK: - Computed Properties
    var hasSelection: Bool { !selectedBlockIDs.isEmpty }

    var selectedBlocks: [CreateBlockModel] {
        blocks.filter { selectedBlockIDs.contains($0.id) }
    }

    var selectedBlock: CreateBlockModel? {
        guard selectedBlockIDs.count == 1, let id = selectedBlockIDs.first else { return nil }
        return blocks.first { $0.id == id }
    }

    private var nextZIndex: Int32 {
        (blocks.map(\.zIndex).max() ?? 0) + 1
    }

    // MARK: - Configuration
    func configure(with context: NSManagedObjectContext) {
        self.moc = context
    }

    // MARK: - Board Loading
    func loadBoard(_ boardID: UUID) {
        guard let moc = moc else { return }

        currentBoardID = boardID

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
        request.predicate = NSPredicate(format: "id == %@", boardID as CVarArg)

        do {
            if let entity = try moc.fetch(request).first {
                currentBoard = CreateBoardModel(
                    id: entity.value(forKey: "id") as? UUID ?? boardID,
                    name: entity.value(forKey: "name") as? String ?? "Untitled",
                    parentBoardID: entity.value(forKey: "parentBoardID") as? UUID,
                    canvasOffsetX: entity.value(forKey: "canvasOffsetX") as? Double ?? 0,
                    canvasOffsetY: entity.value(forKey: "canvasOffsetY") as? Double ?? 0,
                    canvasScale: entity.value(forKey: "canvasScale") as? Double ?? 1.0,
                    backgroundColor: entity.value(forKey: "backgroundColor") as? String,
                    sortOrder: entity.value(forKey: "sortOrder") as? Int32 ?? 0,
                    createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
                    updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date()
                )

                canvasOffset = currentBoard?.canvasOffset ?? .zero
                canvasScale = CGFloat(currentBoard?.canvasScale ?? 1.0)

                fetchBlocks(for: boardID)
                fetchConnectors(for: boardID)
            }
        } catch {
            print("Error loading board: \(error)")
        }
    }

    private func fetchBlocks(for boardID: UUID) {
        guard let moc = moc else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBlockEntity")
        request.predicate = NSPredicate(format: "board.id == %@", boardID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "zIndex", ascending: true)]

        do {
            let entities = try moc.fetch(request)
            blocks = entities.compactMap { entity in
                guard let id = entity.value(forKey: "id") as? UUID,
                      let typeRaw = entity.value(forKey: "blockType") as? String,
                      let blockType = CreateBlockType(rawValue: typeRaw) else { return nil }

                return CreateBlockModel(
                    id: id,
                    blockType: blockType,
                    positionX: entity.value(forKey: "positionX") as? Double ?? 0,
                    positionY: entity.value(forKey: "positionY") as? Double ?? 0,
                    width: entity.value(forKey: "width") as? Double ?? blockType.defaultSize.width,
                    height: entity.value(forKey: "height") as? Double ?? blockType.defaultSize.height,
                    rotation: entity.value(forKey: "rotation") as? Double ?? 0,
                    zIndex: entity.value(forKey: "zIndex") as? Int32 ?? 0,
                    contentJSON: entity.value(forKey: "contentJSON") as? String,
                    colorHex: entity.value(forKey: "colorHex") as? String,
                    isLocked: entity.value(forKey: "isLocked") as? Bool ?? false,
                    createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
                    updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date()
                )
            }
        } catch {
            print("Error fetching blocks: \(error)")
        }
    }

    private func fetchConnectors(for boardID: UUID) {
        guard let moc = moc else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateConnectorEntity")
        request.predicate = NSPredicate(format: "board.id == %@", boardID as CVarArg)

        do {
            let entities = try moc.fetch(request)
            connectors = entities.compactMap { entity in
                guard let id = entity.value(forKey: "id") as? UUID,
                      let sourceBlock = entity.value(forKey: "sourceBlock") as? NSManagedObject,
                      let targetBlock = entity.value(forKey: "targetBlock") as? NSManagedObject,
                      let sourceID = sourceBlock.value(forKey: "id") as? UUID,
                      let targetID = targetBlock.value(forKey: "id") as? UUID else { return nil }

                return CreateConnectorModel(
                    id: id,
                    sourceBlockID: sourceID,
                    targetBlockID: targetID,
                    lineStyle: ConnectorLineStyle(rawValue: entity.value(forKey: "lineStyle") as? String ?? "solid") ?? .solid,
                    lineWidth: entity.value(forKey: "lineWidth") as? Double ?? 2.0,
                    colorHex: entity.value(forKey: "colorHex") as? String ?? "#000000",
                    arrowHead: ConnectorArrowHead(rawValue: entity.value(forKey: "arrowHead") as? String ?? "arrow") ?? .arrow,
                    controlPoints: CreateConnectorModel.fromJSON(entity.value(forKey: "pathControlPointsJSON") as? String),
                    createdAt: entity.value(forKey: "createdAt") as? Date ?? Date()
                )
            }
        } catch {
            print("Error fetching connectors: \(error)")
        }
    }

    // MARK: - Undo/Redo
    func saveStateForUndo() {
        undoRedoManager.saveState(CreateCanvasState(blocks: blocks, connectors: connectors))
    }

    func performUndo() {
        guard let state = undoRedoManager.undo(currentState: CreateCanvasState(blocks: blocks, connectors: connectors)) else { return }
        blocks = state.blocks
        connectors = state.connectors
        selectedBlockIDs.removeAll()
        syncToDatabase()
    }

    func performRedo() {
        guard let state = undoRedoManager.redo(currentState: CreateCanvasState(blocks: blocks, connectors: connectors)) else { return }
        blocks = state.blocks
        connectors = state.connectors
        selectedBlockIDs.removeAll()
        syncToDatabase()
    }

    // MARK: - Block Operations
    func addBlock(type: CreateBlockType, at position: CGPoint, url: URL? = nil) {
        saveStateForUndo()

        var block: CreateBlockModel
        let snappedPosition = snapToGrid ? snapPoint(position) : position

        switch type {
        case .note:
            block = .createNote(at: snappedPosition)
        case .image:
            block = .createImage(at: snappedPosition)
        case .link:
            block = .createLink(at: snappedPosition)
        case .file:
            block = .createFile(at: snappedPosition)
        case .color:
            block = .createColor(at: snappedPosition)
        case .todo:
            block = .createTodo(at: snappedPosition)
        case .boardLink:
            block = .createBoardLink(at: snappedPosition)
        }

        block.zIndex = nextZIndex
        blocks.append(block)
        selectedBlockIDs = [block.id]

        saveBlockToDatabase(block)

        // Fetch URL content if provided
        if let url = url, type == .link {
            fetchURLContent(for: block.id, url: url)
        }
    }

    func updateBlock(_ id: UUID, update: (inout CreateBlockModel) -> Void) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        saveStateForUndo()

        var block = blocks[index]
        update(&block)
        block.updatedAt = Date()
        blocks[index] = block

        updateBlockInDatabase(block)
    }

    func deleteBlock(_ id: UUID) {
        saveStateForUndo()

        // Remove associated connectors
        connectors.removeAll { $0.sourceBlockID == id || $0.targetBlockID == id }

        blocks.removeAll { $0.id == id }
        selectedBlockIDs.remove(id)

        deleteBlockFromDatabase(id)
    }

    func deleteSelectedBlocks() {
        guard hasSelection else { return }
        saveStateForUndo()

        let idsToDelete = selectedBlockIDs
        connectors.removeAll { idsToDelete.contains($0.sourceBlockID) || idsToDelete.contains($0.targetBlockID) }
        blocks.removeAll { idsToDelete.contains($0.id) }
        selectedBlockIDs.removeAll()

        for id in idsToDelete {
            deleteBlockFromDatabase(id)
        }
    }

    func moveBlock(_ id: UUID, to position: CGPoint) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }

        let snappedPosition = snapToGrid ? snapPoint(position) : position
        blocks[index].positionX = snappedPosition.x
        blocks[index].positionY = snappedPosition.y
        blocks[index].updatedAt = Date()

        updateBlockInDatabase(blocks[index])
    }

    func moveBlock(_ id: UUID, by delta: CGSize) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }

        blocks[index].positionX += delta.width
        blocks[index].positionY += delta.height
        blocks[index].updatedAt = Date()

        if snapToGrid {
            blocks[index].position = snapPoint(blocks[index].position)
        }

        updateBlockInDatabase(blocks[index])
    }

    func resizeBlock(_ id: UUID, to size: CGSize) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }

        blocks[index].width = max(50, size.width)
        blocks[index].height = max(50, size.height)
        blocks[index].updatedAt = Date()

        updateBlockInDatabase(blocks[index])
    }

    func bringToFront(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        saveStateForUndo()

        blocks[index].zIndex = nextZIndex
        updateBlockInDatabase(blocks[index])
    }

    func sendToBack(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        saveStateForUndo()

        let minZ = (blocks.map(\.zIndex).min() ?? 0) - 1
        blocks[index].zIndex = minZ
        updateBlockInDatabase(blocks[index])
    }

    func duplicateBlock(_ id: UUID) {
        guard let block = blocks.first(where: { $0.id == id }) else { return }
        saveStateForUndo()

        var newBlock = block
        newBlock = CreateBlockModel(
            id: UUID(),
            blockType: block.blockType,
            positionX: block.positionX + 20,
            positionY: block.positionY + 20,
            width: block.width,
            height: block.height,
            rotation: block.rotation,
            zIndex: nextZIndex,
            contentJSON: block.contentJSON,
            colorHex: block.colorHex,
            isLocked: false
        )

        blocks.append(newBlock)
        selectedBlockIDs = [newBlock.id]

        saveBlockToDatabase(newBlock)
    }

    // MARK: - Selection
    func selectBlock(_ id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            if selectedBlockIDs.contains(id) {
                selectedBlockIDs.remove(id)
            } else {
                selectedBlockIDs.insert(id)
            }
        } else {
            selectedBlockIDs = [id]
        }
    }

    func clearSelection() {
        selectedBlockIDs.removeAll()
    }

    func selectAll() {
        selectedBlockIDs = Set(blocks.map(\.id))
    }

    // MARK: - Connector Operations
    func startConnector(from blockID: UUID) {
        isConnectorMode = true
        connectorSourceID = blockID
    }

    func completeConnector(to targetID: UUID) {
        guard let sourceID = connectorSourceID, sourceID != targetID else {
            cancelConnector()
            return
        }

        // Check if connector already exists
        let exists = connectors.contains {
            ($0.sourceBlockID == sourceID && $0.targetBlockID == targetID) ||
            ($0.sourceBlockID == targetID && $0.targetBlockID == sourceID)
        }

        guard !exists else {
            cancelConnector()
            return
        }

        saveStateForUndo()

        let connector = CreateConnectorModel(
            sourceBlockID: sourceID,
            targetBlockID: targetID
        )

        connectors.append(connector)
        saveConnectorToDatabase(connector)
        cancelConnector()
    }

    func cancelConnector() {
        isConnectorMode = false
        connectorSourceID = nil
    }

    func deleteConnector(_ id: UUID) {
        saveStateForUndo()
        connectors.removeAll { $0.id == id }
        deleteConnectorFromDatabase(id)
    }

    // MARK: - Canvas Navigation
    func zoomIn() {
        canvasScale = min(3.0, canvasScale * 1.25)
        saveCanvasState()
    }

    func zoomOut() {
        canvasScale = max(0.25, canvasScale / 1.25)
        saveCanvasState()
    }

    func zoomToFit() {
        // Calculate bounds of all blocks
        guard !blocks.isEmpty else {
            canvasScale = 1.0
            canvasOffset = .zero
            return
        }

        let minX = blocks.map(\.positionX).min() ?? 0
        let minY = blocks.map(\.positionY).min() ?? 0
        let maxX = blocks.map { $0.positionX + $0.width }.max() ?? 0
        let maxY = blocks.map { $0.positionY + $0.height }.max() ?? 0

        let contentWidth = maxX - minX
        let contentHeight = maxY - minY

        // Center on content
        canvasOffset = CGPoint(
            x: minX + contentWidth / 2,
            y: minY + contentHeight / 2
        )
        canvasScale = 1.0
        saveCanvasState()
    }

    func resetZoom() {
        canvasScale = 1.0
        canvasOffset = .zero
        saveCanvasState()
    }

    // MARK: - Grid Helpers
    private func snapPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: round(point.x / gridSpacing) * gridSpacing,
            y: round(point.y / gridSpacing) * gridSpacing
        )
    }

    // MARK: - Database Operations
    private func saveCanvasState() {
        guard let moc = moc, let boardID = currentBoardID else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
        request.predicate = NSPredicate(format: "id == %@", boardID as CVarArg)

        do {
            if let entity = try moc.fetch(request).first {
                entity.setValue(canvasOffset.x, forKey: "canvasOffsetX")
                entity.setValue(canvasOffset.y, forKey: "canvasOffsetY")
                entity.setValue(Double(canvasScale), forKey: "canvasScale")
                entity.setValue(Date(), forKey: "updatedAt")
                try moc.save()
            }
        } catch {
            print("Error saving canvas state: \(error)")
        }
    }

    private func saveBlockToDatabase(_ block: CreateBlockModel) {
        guard let moc = moc, let boardID = currentBoardID else { return }

        // Fetch the board entity
        let boardRequest = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
        boardRequest.predicate = NSPredicate(format: "id == %@", boardID as CVarArg)

        do {
            guard let boardEntity = try moc.fetch(boardRequest).first else { return }

            let entity = NSEntityDescription.insertNewObject(forEntityName: "CreateBlockEntity", into: moc)
            entity.setValue(block.id, forKey: "id")
            entity.setValue(block.blockType.rawValue, forKey: "blockType")
            entity.setValue(block.positionX, forKey: "positionX")
            entity.setValue(block.positionY, forKey: "positionY")
            entity.setValue(block.width, forKey: "width")
            entity.setValue(block.height, forKey: "height")
            entity.setValue(block.rotation, forKey: "rotation")
            entity.setValue(block.zIndex, forKey: "zIndex")
            entity.setValue(block.contentJSON, forKey: "contentJSON")
            entity.setValue(block.colorHex, forKey: "colorHex")
            entity.setValue(block.isLocked, forKey: "isLocked")
            entity.setValue(block.createdAt, forKey: "createdAt")
            entity.setValue(block.updatedAt, forKey: "updatedAt")
            entity.setValue(boardEntity, forKey: "board")

            try moc.save()
        } catch {
            print("Error saving block: \(error)")
        }
    }

    private func updateBlockInDatabase(_ block: CreateBlockModel) {
        guard let moc = moc else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBlockEntity")
        request.predicate = NSPredicate(format: "id == %@", block.id as CVarArg)

        do {
            if let entity = try moc.fetch(request).first {
                entity.setValue(block.positionX, forKey: "positionX")
                entity.setValue(block.positionY, forKey: "positionY")
                entity.setValue(block.width, forKey: "width")
                entity.setValue(block.height, forKey: "height")
                entity.setValue(block.rotation, forKey: "rotation")
                entity.setValue(block.zIndex, forKey: "zIndex")
                entity.setValue(block.contentJSON, forKey: "contentJSON")
                entity.setValue(block.colorHex, forKey: "colorHex")
                entity.setValue(block.isLocked, forKey: "isLocked")
                entity.setValue(block.updatedAt, forKey: "updatedAt")
                try moc.save()
            }
        } catch {
            print("Error updating block: \(error)")
        }
    }

    private func deleteBlockFromDatabase(_ id: UUID) {
        guard let moc = moc else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBlockEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try moc.fetch(request).first {
                moc.delete(entity)
                try moc.save()
            }
        } catch {
            print("Error deleting block: \(error)")
        }
    }

    private func saveConnectorToDatabase(_ connector: CreateConnectorModel) {
        guard let moc = moc, let boardID = currentBoardID else { return }

        let boardRequest = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
        boardRequest.predicate = NSPredicate(format: "id == %@", boardID as CVarArg)

        let sourceRequest = NSFetchRequest<NSManagedObject>(entityName: "CreateBlockEntity")
        sourceRequest.predicate = NSPredicate(format: "id == %@", connector.sourceBlockID as CVarArg)

        let targetRequest = NSFetchRequest<NSManagedObject>(entityName: "CreateBlockEntity")
        targetRequest.predicate = NSPredicate(format: "id == %@", connector.targetBlockID as CVarArg)

        do {
            guard let boardEntity = try moc.fetch(boardRequest).first,
                  let sourceEntity = try moc.fetch(sourceRequest).first,
                  let targetEntity = try moc.fetch(targetRequest).first else { return }

            let entity = NSEntityDescription.insertNewObject(forEntityName: "CreateConnectorEntity", into: moc)
            entity.setValue(connector.id, forKey: "id")
            entity.setValue(connector.lineStyle.rawValue, forKey: "lineStyle")
            entity.setValue(connector.lineWidth, forKey: "lineWidth")
            entity.setValue(connector.colorHex, forKey: "colorHex")
            entity.setValue(connector.arrowHead.rawValue, forKey: "arrowHead")
            entity.setValue(connector.controlPointsJSON, forKey: "pathControlPointsJSON")
            entity.setValue(connector.createdAt, forKey: "createdAt")
            entity.setValue(sourceEntity, forKey: "sourceBlock")
            entity.setValue(targetEntity, forKey: "targetBlock")
            entity.setValue(boardEntity, forKey: "board")

            try moc.save()
        } catch {
            print("Error saving connector: \(error)")
        }
    }

    private func deleteConnectorFromDatabase(_ id: UUID) {
        guard let moc = moc else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateConnectorEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try moc.fetch(request).first {
                moc.delete(entity)
                try moc.save()
            }
        } catch {
            print("Error deleting connector: \(error)")
        }
    }

    private func syncToDatabase() {
        guard let moc = moc, let boardID = currentBoardID else { return }

        // Re-sync all blocks and connectors after undo/redo
        // This is a simplified approach - could be optimized with diff
        do {
            // Delete all existing blocks for this board
            let blockRequest = NSFetchRequest<NSManagedObject>(entityName: "CreateBlockEntity")
            blockRequest.predicate = NSPredicate(format: "board.id == %@", boardID as CVarArg)
            let existingBlocks = try moc.fetch(blockRequest)
            existingBlocks.forEach { moc.delete($0) }

            // Delete all existing connectors for this board
            let connectorRequest = NSFetchRequest<NSManagedObject>(entityName: "CreateConnectorEntity")
            connectorRequest.predicate = NSPredicate(format: "board.id == %@", boardID as CVarArg)
            let existingConnectors = try moc.fetch(connectorRequest)
            existingConnectors.forEach { moc.delete($0) }

            try moc.save()

            // Re-create all blocks
            for block in blocks {
                saveBlockToDatabase(block)
            }

            // Re-create all connectors
            for connector in connectors {
                saveConnectorToDatabase(connector)
            }
        } catch {
            print("Error syncing to database: \(error)")
        }
    }

    // MARK: - URL Content Fetching
    private func fetchURLContent(for blockID: UUID, url: URL) {
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    return
                }

                // Capture values to avoid concurrency issues
                let extractedTitle: String
                let extractedPreview: String
                let extractedImageURL: String?

                // Try to parse HTML content
                if let htmlString = String(data: data, encoding: .utf8) {
                    var tempTitle = url.absoluteString
                    var tempPreview = ""
                    var tempImageURL: String?

                    // Extract title
                    if let titleRange = htmlString.range(of: "<title>(.*?)</title>", options: .regularExpression) {
                        let titleText = String(htmlString[titleRange])
                        tempTitle = titleText
                            .replacingOccurrences(of: "<title>", with: "")
                            .replacingOccurrences(of: "</title>", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    // Extract meta description
                    if let metaRange = htmlString.range(of: "<meta[^>]*name=\"description\"[^>]*content=\"([^\"]*)\"", options: .regularExpression) {
                        let metaText = String(htmlString[metaRange])
                        if let contentRange = metaText.range(of: "content=\"([^\"]*)\"", options: .regularExpression) {
                            tempPreview = String(metaText[contentRange])
                                .replacingOccurrences(of: "content=\"", with: "")
                                .replacingOccurrences(of: "\"", with: "")
                        }
                    }

                    // Extract Open Graph image
                    if let ogImageRange = htmlString.range(of: "<meta[^>]*property=\"og:image\"[^>]*content=\"([^\"]*)\"", options: .regularExpression) {
                        let ogText = String(htmlString[ogImageRange])
                        if let contentRange = ogText.range(of: "content=\"([^\"]*)\"", options: .regularExpression) {
                            tempImageURL = String(ogText[contentRange])
                                .replacingOccurrences(of: "content=\"", with: "")
                                .replacingOccurrences(of: "\"", with: "")
                        }
                    }

                    // Fallback: get first paragraph text
                    if tempPreview.isEmpty {
                        if let pRange = htmlString.range(of: "<p[^>]*>(.*?)</p>", options: .regularExpression) {
                            let pText = String(htmlString[pRange])
                                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            tempPreview = String(pText.prefix(200))
                        }
                    }

                    extractedTitle = tempTitle
                    extractedPreview = tempPreview
                    extractedImageURL = tempImageURL
                } else {
                    extractedTitle = url.absoluteString
                    extractedPreview = ""
                    extractedImageURL = nil
                }

                await MainActor.run {
                    updateBlockContent(blockID, urlString: url.absoluteString, title: extractedTitle, preview: extractedPreview, imageURL: extractedImageURL)
                }
            } catch {
                print("Failed to fetch URL content: \(error.localizedDescription)")
                // Still update with basic info
                await MainActor.run {
                    updateBlockContent(blockID, urlString: url.absoluteString, title: url.host ?? url.absoluteString, preview: "Unable to fetch content", imageURL: nil)
                }
            }
        }
    }

    private func updateBlockContent(_ blockID: UUID, urlString: String, title: String, preview: String, imageURL: String?) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }

        // Download thumbnail image data if imageURL is provided
        var thumbnailData: Data? = nil
        if let imageURLString = imageURL, let imageURL = URL(string: imageURLString) {
            thumbnailData = try? Data(contentsOf: imageURL)
        }

        // Create LinkContent with fetched data
        let linkContent = LinkContent(
            url: urlString,
            title: title,
            description: preview,
            thumbnailData: thumbnailData
        )

        blocks[index].encodeContent(linkContent)
        updateBlockInDatabase(blocks[index])
    }

    // MARK: - Copy/Paste Operations
    private var copiedBlocks: [CreateBlockModel] = []

    var hasCopiedBlocks: Bool {
        !copiedBlocks.isEmpty
    }

    func copySelectedBlocks() {
        // Just copy the blocks as-is; new IDs will be generated on paste
        copiedBlocks = Array(selectedBlocks)
    }

    func pasteBlocks(at position: CGPoint? = nil) {
        guard !copiedBlocks.isEmpty else { return }

        saveStateForUndo()

        var newBlockIDs: [UUID] = []
        let pasteOffset = CGPoint(x: 20, y: 20) // Offset from original position

        // Calculate center point of copied blocks
        let centerX = copiedBlocks.map(\.positionX).reduce(0, +) / Double(copiedBlocks.count)
        let centerY = copiedBlocks.map(\.positionY).reduce(0, +) / Double(copiedBlocks.count)
        let copiedCenter = CGPoint(x: centerX, y: centerY)

        // Determine paste position
        let targetCenter = position ?? CGPoint(
            x: copiedCenter.x + pasteOffset.x,
            y: copiedCenter.y + pasteOffset.y
        )

        let deltaX = targetCenter.x - copiedCenter.x
        let deltaY = targetCenter.y - copiedCenter.y

        for copiedBlock in copiedBlocks {
            let newBlock = CreateBlockModel(
                id: UUID(),
                blockType: copiedBlock.blockType,
                positionX: copiedBlock.positionX + deltaX,
                positionY: copiedBlock.positionY + deltaY,
                width: copiedBlock.width,
                height: copiedBlock.height,
                rotation: copiedBlock.rotation,
                zIndex: nextZIndex,
                contentJSON: copiedBlock.contentJSON,
                colorHex: copiedBlock.colorHex,
                isLocked: false, // Pasted blocks are unlocked
                createdAt: Date(),
                updatedAt: Date()
            )

            blocks.append(newBlock)
            newBlockIDs.append(newBlock.id)
            saveBlockToDatabase(newBlock)
        }

        // Select the newly pasted blocks
        selectedBlockIDs = Set(newBlockIDs)
    }

    func duplicateSelectedBlocks() {
        copySelectedBlocks()
        pasteBlocks()
    }
}
