//  PersistenceController.swift
//  Production Runner

import Foundation
import CoreData

/// Notification names for Core Data events
extension Notification.Name {
    static let coreDataStoreLoadFailed = Notification.Name("coreDataStoreLoadFailed")
}

/// Errors that can occur during Core Data persistence operations
enum PersistenceError: LocalizedError {
    case storeLoadFailed(Error)
    case storeAddFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .storeLoadFailed(let error):
            return "Failed to load Core Data store: \(error.localizedDescription)"
        case .storeAddFailed(let url, let error):
            return "Failed to add store at \(url.path): \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storeLoadFailed:
            return "The app's database could not be loaded. Try restarting the app. If the problem persists, you may need to reinstall."
        case .storeAddFailed:
            return "The project file could not be opened. The file may be corrupted or from an incompatible version."
        }
    }
}

final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    /// In-memory controller for SwiftUI previews
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Add sample data for previews if needed
        // Example:
        // let project = ProjectEntity(context: context)
        // project.id = UUID()
        // project.name = "Preview Project"
        
        do {
            try context.save()
        } catch {
            print("Preview context save error: \(error)")
        }
        
        return controller
    }()

    private let modelName = "ProductionRunner"
    private(set) var currentProjectURL: URL? = nil
    private(set) var container: NSPersistentContainer
    @Published var loadError: PersistenceError?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: modelName)
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        } else {
            // Enable automatic lightweight migration for production stores
            if let description = container.persistentStoreDescriptions.first {
                description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
                print("[PersistenceController] ✅ Automatic Core Data migration enabled")
            }
        }
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error {
                // Fixed: Store error for user notification instead of crashing
                print("❌ Core Data store load error: \(error)")
                self?.loadError = .storeLoadFailed(error)
                // Post notification so app can show alert to user
                NotificationCenter.default.post(name: .coreDataStoreLoadFailed, object: error)
            } else {
                print("✅ Core Data store loaded successfully: \(storeDescription.url?.lastPathComponent ?? "unknown")")
                print("[PersistenceController] Model version: ProductionRunner 3 (with BudgetVersionEntity, ScriptRevisionLoadTrackingEntity)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Enable undo manager for global undo/redo support
        container.viewContext.undoManager = UndoManager()
    }

    /// Load (or switch to) the Core Data store at the given URL (either a `.runner` package folder or a direct `.sqlite`).
    /// **FIXED**: Now reuses the same container instead of creating a new one, preventing duplicate model loading
    /// **FIXED**: Throws error instead of crashing with fatalError
    func load(at url: URL) throws {
        // Begin security scope if needed (sandbox-safe)
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let storeURL: URL = {
            if url.pathExtension.lowercased() == "sqlite" { return url }
            // package folder → Store/ProductionRunner.sqlite
            let preferred = url.appendingPathComponent("Store", isDirectory: true)
                               .appendingPathComponent("\(modelName).sqlite")
            return preferred
        }()

        // Ensure parent directory exists
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let coordinator = container.persistentStoreCoordinator

        // Remove all existing stores from the coordinator
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                print("⚠️ Error removing store: \(error)")
            }
        }

        // Add the new store to the same coordinator
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        do {
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
        } catch {
            // Fixed: Throw error instead of crashing
            print("❌ Failed loading store at \(storeURL): \(error)")
            loadError = .storeAddFailed(storeURL, error)
            throw PersistenceError.storeAddFailed(storeURL, error)
        }

        // Clear any cached objects from the old store
        container.viewContext.reset()
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Re-enable undo manager after store switch
        container.viewContext.undoManager = UndoManager()

        self.currentProjectURL = (url.pathExtension.lowercased() == "sqlite") ? url.deletingLastPathComponent() : url

        // DEBUG: Log scene numbers after store switch
        print("🔄 [SceneNumberDebug] PersistenceController.load() - Store switched to: \(storeURL.path)")
        let debugFetch = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
        debugFetch.sortDescriptors = [NSSortDescriptor(key: "displayOrder", ascending: true)]
        if let scenes = try? container.viewContext.fetch(debugFetch) {
            print("🔄 [SceneNumberDebug] After store switch, found \(scenes.count) scenes:")
            for (idx, scene) in scenes.enumerated() {
                let num = scene.value(forKey: "number") as? String ?? "(nil)"
                let order = scene.value(forKey: "displayOrder") as? Int32 ?? -1
                let id = (scene.value(forKey: "id") as? UUID)?.uuidString ?? "nil"
                print("   [\(idx)] number='\(num)' displayOrder=\(order) id=\(id)")
            }
        }

        NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
    }

    /// Resolve the SQLite store URL inside a project folder or package.
    /// Returns `<folder>/Store/ProductionRunner.sqlite` without creating it.
    static func storeURL(forProjectFolder folder: URL) -> URL {
        let storeDir = folder.appendingPathComponent("Store", isDirectory: true)
        return storeDir.appendingPathComponent("ProductionRunner.sqlite")
    }

    /// Create a background context for heavy operations
    /// Use this for bulk imports, exports, or processing that shouldn't block the UI
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    /// Perform a block of work on a background context
    /// - Parameter block: The work to perform, receiving the background context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            context.automaticallyMergesChangesFromParent = true
            block(context)
        }
    }
}
