import SwiftUI
import CoreData

// MARK: - In-Memory Block Model (mirrors Core Data entity)
struct CreateBlockModel: Identifiable, Equatable {
    let id: UUID
    var blockType: CreateBlockType
    var positionX: Double
    var positionY: Double
    var width: Double
    var height: Double
    var rotation: Double
    var zIndex: Int32
    var contentJSON: String?
    var colorHex: String?
    var isLocked: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        blockType: CreateBlockType = .note,
        positionX: Double = 0,
        positionY: Double = 0,
        width: Double? = nil,
        height: Double? = nil,
        rotation: Double = 0,
        zIndex: Int32 = 0,
        contentJSON: String? = nil,
        colorHex: String? = nil,
        isLocked: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.blockType = blockType
        self.positionX = positionX
        self.positionY = positionY
        self.width = width ?? blockType.defaultSize.width
        self.height = height ?? blockType.defaultSize.height
        self.rotation = rotation
        self.zIndex = zIndex
        self.contentJSON = contentJSON
        self.colorHex = colorHex
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    var size: CGSize {
        get { CGSize(width: width, height: height) }
        set {
            width = newValue.width
            height = newValue.height
        }
    }

    var frame: CGRect {
        CGRect(x: positionX, y: positionY, width: width, height: height)
    }

    // MARK: - Content Helpers
    func decodeContent<T: Decodable>(_ type: T.Type) -> T? {
        guard let json = contentJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    mutating func encodeContent<T: Encodable>(_ content: T) {
        if let data = try? JSONEncoder().encode(content),
           let json = String(data: data, encoding: .utf8) {
            self.contentJSON = json
            self.updatedAt = Date()
        }
    }

    // Convenience accessors for each content type
    var noteContent: NoteContent? {
        get { decodeContent(NoteContent.self) }
        set { if let value = newValue { var copy = self; copy.encodeContent(value); self = copy } }
    }

    var imageContent: ImageContent? {
        get { decodeContent(ImageContent.self) }
        set { if let value = newValue { var copy = self; copy.encodeContent(value); self = copy } }
    }

    var linkContent: LinkContent? {
        get { decodeContent(LinkContent.self) }
        set { if let value = newValue { var copy = self; copy.encodeContent(value); self = copy } }
    }

    var fileContent: FileContent? {
        get { decodeContent(FileContent.self) }
        set { if let value = newValue { var copy = self; copy.encodeContent(value); self = copy } }
    }

    var colorContent: ColorContent? {
        get { decodeContent(ColorContent.self) }
        set { if let value = newValue { var copy = self; copy.encodeContent(value); self = copy } }
    }

    var todoContent: TodoContent? {
        get { decodeContent(TodoContent.self) }
        set { if let value = newValue { var copy = self; copy.encodeContent(value); self = copy } }
    }

    var boardLinkContent: BoardLinkContent? {
        get { decodeContent(BoardLinkContent.self) }
        set { if let value = newValue { var copy = self; copy.encodeContent(value); self = copy } }
    }

    // MARK: - Create with default content
    static func createNote(at position: CGPoint) -> CreateBlockModel {
        var block = CreateBlockModel(blockType: .note, positionX: position.x, positionY: position.y)
        block.encodeContent(NoteContent())
        return block
    }

    static func createImage(at position: CGPoint, imageData: Data? = nil) -> CreateBlockModel {
        var block = CreateBlockModel(blockType: .image, positionX: position.x, positionY: position.y)
        block.encodeContent(ImageContent(imageData: imageData))
        return block
    }

    static func createLink(at position: CGPoint, url: String = "") -> CreateBlockModel {
        var block = CreateBlockModel(blockType: .link, positionX: position.x, positionY: position.y)
        block.encodeContent(LinkContent(url: url))
        return block
    }

    static func createFile(at position: CGPoint) -> CreateBlockModel {
        var block = CreateBlockModel(blockType: .file, positionX: position.x, positionY: position.y)
        block.encodeContent(FileContent())
        return block
    }

    static func createColor(at position: CGPoint, hex: String = "#FFFFFF") -> CreateBlockModel {
        var block = CreateBlockModel(blockType: .color, positionX: position.x, positionY: position.y)
        block.encodeContent(ColorContent(colorHex: hex))
        return block
    }

    static func createTodo(at position: CGPoint) -> CreateBlockModel {
        var block = CreateBlockModel(blockType: .todo, positionX: position.x, positionY: position.y)
        block.encodeContent(TodoContent())
        return block
    }

    static func createBoardLink(at position: CGPoint, boardID: UUID? = nil, boardName: String = "") -> CreateBlockModel {
        var block = CreateBlockModel(blockType: .boardLink, positionX: position.x, positionY: position.y)
        block.encodeContent(BoardLinkContent(linkedBoardID: boardID, linkedBoardName: boardName))
        return block
    }
}

// MARK: - Connector Model
struct CreateConnectorModel: Identifiable, Equatable {
    let id: UUID
    var sourceBlockID: UUID
    var targetBlockID: UUID
    var lineStyle: ConnectorLineStyle
    var lineWidth: Double
    var colorHex: String
    var arrowHead: ConnectorArrowHead
    var controlPoints: [CGPoint]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceBlockID: UUID,
        targetBlockID: UUID,
        lineStyle: ConnectorLineStyle = .solid,
        lineWidth: Double = 2.0,
        colorHex: String = "#000000",
        arrowHead: ConnectorArrowHead = .arrow,
        controlPoints: [CGPoint] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceBlockID = sourceBlockID
        self.targetBlockID = targetBlockID
        self.lineStyle = lineStyle
        self.lineWidth = lineWidth
        self.colorHex = colorHex
        self.arrowHead = arrowHead
        self.controlPoints = controlPoints
        self.createdAt = createdAt
    }

    var controlPointsJSON: String? {
        let points = controlPoints.map { ["x": $0.x, "y": $0.y] }
        guard let data = try? JSONEncoder().encode(points),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    static func fromJSON(_ json: String?) -> [CGPoint] {
        guard let json = json, let data = json.data(using: .utf8),
              let points = try? JSONDecoder().decode([[String: Double]].self, from: data) else {
            return []
        }
        return points.compactMap { dict in
            guard let x = dict["x"], let y = dict["y"] else { return nil }
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Board Model
struct CreateBoardModel: Identifiable, Equatable {
    let id: UUID
    var name: String
    var parentBoardID: UUID?
    var canvasOffsetX: Double
    var canvasOffsetY: Double
    var canvasScale: Double
    var backgroundColor: String?
    var sortOrder: Int32
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Untitled Board",
        parentBoardID: UUID? = nil,
        canvasOffsetX: Double = 0,
        canvasOffsetY: Double = 0,
        canvasScale: Double = 1.0,
        backgroundColor: String? = nil,
        sortOrder: Int32 = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentBoardID = parentBoardID
        self.canvasOffsetX = canvasOffsetX
        self.canvasOffsetY = canvasOffsetY
        self.canvasScale = canvasScale
        self.backgroundColor = backgroundColor
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var canvasOffset: CGPoint {
        get { CGPoint(x: canvasOffsetX, y: canvasOffsetY) }
        set {
            canvasOffsetX = newValue.x
            canvasOffsetY = newValue.y
        }
    }
}
