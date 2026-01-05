import SwiftUI
import CoreData
import Combine

// MARK: - Board View Model
class CreateBoardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var boards: [CreateBoardModel] = []
    @Published var selectedBoardID: UUID?
    @Published var searchText: String = ""

    // MARK: - Core Data Context
    private var moc: NSManagedObjectContext?

    // MARK: - Computed Properties
    var rootBoards: [CreateBoardModel] {
        boards.filter { $0.parentBoardID == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var filteredBoards: [CreateBoardModel] {
        if searchText.isEmpty {
            return rootBoards
        }
        return boards.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func childBoards(of parentID: UUID) -> [CreateBoardModel] {
        boards.filter { $0.parentBoardID == parentID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func hasChildren(_ boardID: UUID) -> Bool {
        boards.contains { $0.parentBoardID == boardID }
    }

    func boardPath(to boardID: UUID) -> [CreateBoardModel] {
        var path: [CreateBoardModel] = []
        var currentID: UUID? = boardID

        while let id = currentID, let board = boards.first(where: { $0.id == id }) {
            path.insert(board, at: 0)
            currentID = board.parentBoardID
        }

        return path
    }

    // MARK: - Configuration
    func configure(with context: NSManagedObjectContext) {
        self.moc = context
        fetchBoards()
    }

    // MARK: - Fetch
    func fetchBoards() {
        guard let moc = moc else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let entities = try moc.fetch(request)
            boards = entities.map { entity in
                CreateBoardModel(
                    id: entity.value(forKey: "id") as? UUID ?? UUID(),
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
            }

            // Select first board if none selected
            if selectedBoardID == nil, let first = rootBoards.first {
                selectedBoardID = first.id
            }
        } catch {
            print("Error fetching boards: \(error)")
        }
    }

    // MARK: - CRUD Operations
    func createBoard(name: String = "Untitled Board", parentID: UUID? = nil) -> UUID {
        guard let moc = moc else { return UUID() }

        let newID = UUID()
        let now = Date()
        let maxSortOrder = (boards.map(\.sortOrder).max() ?? 0) + 1

        // Fetch parent board entity if needed
        if let parentID = parentID {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
            request.predicate = NSPredicate(format: "id == %@", parentID as CVarArg)
            _ = try? moc.fetch(request).first
        }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "CreateBoardEntity", into: moc)
        entity.setValue(newID, forKey: "id")
        entity.setValue(name, forKey: "name")
        entity.setValue(parentID, forKey: "parentBoardID")
        entity.setValue(0.0, forKey: "canvasOffsetX")
        entity.setValue(0.0, forKey: "canvasOffsetY")
        entity.setValue(1.0, forKey: "canvasScale")
        entity.setValue(maxSortOrder, forKey: "sortOrder")
        entity.setValue(now, forKey: "createdAt")
        entity.setValue(now, forKey: "updatedAt")

        do {
            try moc.save()

            let newBoard = CreateBoardModel(
                id: newID,
                name: name,
                parentBoardID: parentID,
                sortOrder: maxSortOrder,
                createdAt: now,
                updatedAt: now
            )
            boards.append(newBoard)
            selectedBoardID = newID
        } catch {
            print("Error creating board: \(error)")
        }

        return newID
    }

    func renameBoard(_ id: UUID, to name: String) {
        guard let moc = moc,
              let index = boards.firstIndex(where: { $0.id == id }) else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try moc.fetch(request).first {
                entity.setValue(name, forKey: "name")
                entity.setValue(Date(), forKey: "updatedAt")
                try moc.save()

                boards[index].name = name
                boards[index].updatedAt = Date()
            }
        } catch {
            print("Error renaming board: \(error)")
        }
    }

    func deleteBoard(_ id: UUID) {
        guard let moc = moc else { return }

        // Find all child boards to delete
        var idsToDelete: Set<UUID> = [id]
        var queue: [UUID] = [id]

        while !queue.isEmpty {
            let currentID = queue.removeFirst()
            let childIDs = boards.filter { $0.parentBoardID == currentID }.map(\.id)
            childIDs.forEach { idsToDelete.insert($0) }
            queue.append(contentsOf: childIDs)
        }

        // Delete from Core Data
        for deleteID in idsToDelete {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
            request.predicate = NSPredicate(format: "id == %@", deleteID as CVarArg)

            do {
                if let entity = try moc.fetch(request).first {
                    moc.delete(entity)
                }
            } catch {
                print("Error fetching board to delete: \(error)")
            }
        }

        do {
            try moc.save()
            boards.removeAll { idsToDelete.contains($0.id) }

            // Clear selection if deleted
            if let selected = selectedBoardID, idsToDelete.contains(selected) {
                selectedBoardID = rootBoards.first?.id
            }
        } catch {
            print("Error saving after delete: \(error)")
        }
    }

    func duplicateBoard(_ id: UUID) -> UUID? {
        guard let board = boards.first(where: { $0.id == id }) else { return nil }

        let newName = "\(board.name) Copy"
        return createBoard(name: newName, parentID: board.parentBoardID)
    }

    func moveBoard(_ id: UUID, toParent newParentID: UUID?) {
        guard let moc = moc,
              let index = boards.firstIndex(where: { $0.id == id }) else { return }

        // Prevent moving a board into its own descendant
        if let newParentID = newParentID {
            var checkID: UUID? = newParentID
            while let parentID = checkID {
                if parentID == id { return }
                checkID = boards.first(where: { $0.id == parentID })?.parentBoardID
            }
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try moc.fetch(request).first {
                entity.setValue(newParentID, forKey: "parentBoardID")
                entity.setValue(Date(), forKey: "updatedAt")
                try moc.save()

                boards[index].parentBoardID = newParentID
                boards[index].updatedAt = Date()
            }
        } catch {
            print("Error moving board: \(error)")
        }
    }

    func reorderBoard(_ id: UUID, toIndex newIndex: Int, inParent parentID: UUID?) {
        guard let moc = moc else { return }

        // Get siblings at the same level
        var siblings = boards.filter { $0.parentBoardID == parentID }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = siblings.firstIndex(where: { $0.id == id }) else { return }

        // Reorder
        let board = siblings.remove(at: currentIndex)
        let insertIndex = min(newIndex, siblings.count)
        siblings.insert(board, at: insertIndex)

        // Update sort orders
        for (index, sibling) in siblings.enumerated() {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CreateBoardEntity")
            request.predicate = NSPredicate(format: "id == %@", sibling.id as CVarArg)

            do {
                if let entity = try moc.fetch(request).first {
                    entity.setValue(Int32(index), forKey: "sortOrder")
                }
            } catch {
                print("Error reordering board: \(error)")
            }

            if let boardIndex = boards.firstIndex(where: { $0.id == sibling.id }) {
                boards[boardIndex].sortOrder = Int32(index)
            }
        }

        do {
            try moc.save()
        } catch {
            print("Error saving reorder: \(error)")
        }
    }

    // MARK: - Ensure Default Board
    func ensureDefaultBoard() {
        if boards.isEmpty {
            _ = createBoard(name: "My First Board")
        }
    }
}
