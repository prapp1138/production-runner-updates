import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Custom UTTypes for Create App
extension UTType {
    static var createBlockDragItem: UTType {
        UTType(exportedAs: "com.productionrunner.create-block-drag-item")
    }

    static var createBoardDragItem: UTType {
        UTType(exportedAs: "com.productionrunner.create-board-drag-item")
    }
}

// MARK: - Block Drag Item
struct CreateBlockDragItem: Codable, Transferable {
    let id: UUID
    let blockType: String

    init(id: UUID, blockType: CreateBlockType) {
        self.id = id
        self.blockType = blockType.rawValue
    }

    var type: CreateBlockType? {
        CreateBlockType(rawValue: blockType)
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .createBlockDragItem)
    }
}

// MARK: - New Block Creation Drag Item (from toolbar)
struct CreateNewBlockDragItem: Codable, Transferable {
    let blockType: String

    init(blockType: CreateBlockType) {
        self.blockType = blockType.rawValue
    }

    var type: CreateBlockType? {
        CreateBlockType(rawValue: blockType)
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .createBlockDragItem)
    }
}

// MARK: - Board Drag Item (for reordering in sidebar)
struct CreateBoardDragItem: Codable, Transferable {
    let id: UUID
    let name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .createBoardDragItem)
    }
}

// MARK: - Image Drop Handler
struct CreateImageDropDelegate: DropDelegate {
    let onDrop: (Data, CGPoint) -> Void
    let location: CGPoint

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.image]) else { return false }

        let providers = info.itemProviders(for: [.image])
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data = data {
                    DispatchQueue.main.async {
                        onDrop(data, location)
                    }
                }
            }
        }
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.image])
    }
}

// MARK: - File Drop Handler
struct CreateFileDropDelegate: DropDelegate {
    let onDrop: (URL, CGPoint) -> Void
    let location: CGPoint

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.fileURL]) else { return false }

        let providers = info.itemProviders(for: [.fileURL])
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        onDrop(url, location)
                    }
                }
            }
        }
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }
}

// MARK: - URL Drop Handler (for link blocks)
struct CreateURLDropDelegate: DropDelegate {
    let onDrop: (URL, CGPoint) -> Void
    let location: CGPoint

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.url]) else { return false }

        let providers = info.itemProviders(for: [.url])
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        onDrop(url, location)
                    }
                }
            }
        }
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.url])
    }
}
