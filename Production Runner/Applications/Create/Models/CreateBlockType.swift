import SwiftUI

// MARK: - Block Type Enum
enum CreateBlockType: String, CaseIterable, Codable, Identifiable {
    case note
    case image
    case link
    case file
    case color
    case todo
    case boardLink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .note: return "Note"
        case .image: return "Image"
        case .link: return "Link"
        case .file: return "File"
        case .color: return "Color"
        case .todo: return "To-Do"
        case .boardLink: return "Board"
        }
    }

    var icon: String {
        switch self {
        case .note: return "note.text"
        case .image: return "photo"
        case .link: return "link"
        case .file: return "doc"
        case .color: return "paintpalette"
        case .todo: return "checklist"
        case .boardLink: return "folder"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .note: return CGSize(width: 200, height: 150)
        case .image: return CGSize(width: 200, height: 200)
        case .link: return CGSize(width: 240, height: 80)
        case .file: return CGSize(width: 180, height: 60)
        case .color: return CGSize(width: 80, height: 80)
        case .todo: return CGSize(width: 200, height: 120)
        case .boardLink: return CGSize(width: 160, height: 100)
        }
    }

    var accentColor: Color {
        switch self {
        case .note: return .yellow
        case .image: return .purple
        case .link: return .blue
        case .file: return .gray
        case .color: return .pink
        case .todo: return .green
        case .boardLink: return .teal
        }
    }
}

// MARK: - Content Models for Each Block Type

struct NoteContent: Codable {
    var title: String
    var content: String
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool

    init(title: String = "", content: String = "", fontSize: CGFloat = 14, isBold: Bool = false, isItalic: Bool = false) {
        self.title = title
        self.content = content
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
    }
}

struct ImageContent: Codable {
    var imageData: Data?
    var caption: String
    var aspectRatio: CGFloat

    init(imageData: Data? = nil, caption: String = "", aspectRatio: CGFloat = 1.0) {
        self.imageData = imageData
        self.caption = caption
        self.aspectRatio = aspectRatio
    }
}

struct LinkContent: Codable {
    var url: String
    var title: String
    var description: String
    var thumbnailData: Data?

    init(url: String = "", title: String = "", description: String = "", thumbnailData: Data? = nil) {
        self.url = url
        self.title = title
        self.description = description
        self.thumbnailData = thumbnailData
    }
}

struct FileContent: Codable {
    var fileName: String
    var fileData: Data?
    var fileSize: Int64
    var fileType: String

    init(fileName: String = "", fileData: Data? = nil, fileSize: Int64 = 0, fileType: String = "") {
        self.fileName = fileName
        self.fileData = fileData
        self.fileSize = fileSize
        self.fileType = fileType
    }
}

struct ColorContent: Codable {
    var colorHex: String
    var colorName: String

    init(colorHex: String = "#FFFFFF", colorName: String = "White") {
        self.colorHex = colorHex
        self.colorName = colorName
    }
}

struct TodoItem: Codable, Identifiable {
    var id: UUID
    var text: String
    var isCompleted: Bool
    var linkedTaskID: UUID?  // Links to TaskEntity in Tasks app

    init(id: UUID = UUID(), text: String = "", isCompleted: Bool = false, linkedTaskID: UUID? = nil) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.linkedTaskID = linkedTaskID
    }
}

struct TodoContent: Codable {
    var title: String
    var items: [TodoItem]

    init(title: String = "Tasks", items: [TodoItem] = []) {
        self.title = title
        self.items = items
    }
}

struct BoardLinkContent: Codable {
    var linkedBoardID: UUID?
    var linkedBoardName: String

    init(linkedBoardID: UUID? = nil, linkedBoardName: String = "") {
        self.linkedBoardID = linkedBoardID
        self.linkedBoardName = linkedBoardName
    }
}

// MARK: - Connector Line Styles
enum ConnectorLineStyle: String, CaseIterable, Codable {
    case solid
    case dashed
    case dotted

    var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .dashed: return "Dashed"
        case .dotted: return "Dotted"
        }
    }
}

enum ConnectorArrowHead: String, CaseIterable, Codable {
    case none
    case arrow
    case circle

    var displayName: String {
        switch self {
        case .none: return "None"
        case .arrow: return "Arrow"
        case .circle: return "Circle"
        }
    }
}
