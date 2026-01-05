import CoreData

/// Ensures SceneEntity has stable displayOrder and timestamps on insert/update,
/// and makes sure viewContext reflects background saves.
final class SceneDisplaySyncer {
    private let container: NSPersistentContainer
    private var token: NSObjectProtocol?

    init(container: NSPersistentContainer) { self.container = container }

    func start() {
        // Merge policy + auto-merge so SwiftUI @FetchRequest updates reliably.
        let ctx = container.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        token = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleSave(note)
        }
    }

    deinit { if let t = token { NotificationCenter.default.removeObserver(t) } }

    private func handleSave(_ note: Notification) {
        guard let ctx = note.object as? NSManagedObjectContext else { return }

        let insertedScenes = (note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.compactMap { $0 as? SceneEntity } ?? []
        let updatedScenes  = (note.userInfo?[NSUpdatedObjectsKey]  as? Set<NSManagedObject>)?.compactMap { $0 as? SceneEntity } ?? []

        // DEBUG: Log scene number changes
        for scene in updatedScenes {
            let changedKeys = scene.changedValuesForCurrentEvent()
            if changedKeys.keys.contains("number") {
                let oldValue = scene.committedValues(forKeys: ["number"])["number"] as? String ?? "(nil)"
                let newValue = scene.number ?? "(nil)"
                print("🔴 [SceneNumberDebug] Scene number CHANGED: '\(oldValue)' → '\(newValue)' | id=\(scene.id?.uuidString ?? "nil") | context=\(ctx.name ?? "unnamed")")
                // Print stack trace to identify the caller
                Thread.callStackSymbols.prefix(15).forEach { print("    \($0)") }
            }
        }

        for scene in insertedScenes {
            print("🟢 [SceneNumberDebug] Scene INSERTED: number='\(scene.number ?? "(nil)")' | id=\(scene.id?.uuidString ?? "nil") | displayOrder=\(scene.displayOrder)")
        }

        if insertedScenes.isEmpty && updatedScenes.isEmpty { return }

        let viewCtx = container.viewContext
        viewCtx.perform {
            for scene in insertedScenes {
                // Assign a stable displayOrder if missing
                if scene.displayOrder == 0, let project = scene.project {
                    scene.displayOrder = self.nextOrder(for: project, ctx: viewCtx)
                }
                // Soft timestamps (only if attributes exist in the model)
                let attrs = scene.entity.attributesByName
                if attrs["createdAt"] != nil {
                    if (scene.value(forKey: "createdAt") as? Date) == nil {
                        scene.setValue(Date(), forKey: "createdAt")
                    }
                }
                if attrs["updatedAt"] != nil {
                    scene.setValue(Date(), forKey: "updatedAt")
                }
            }
            for scene in updatedScenes {
                if scene.entity.attributesByName["updatedAt"] != nil {
                    scene.setValue(Date(), forKey: "updatedAt")
                }
            }
            if viewCtx.hasChanges { try? viewCtx.save() }
        }
    }

    private func nextOrder(for project: ProjectEntity, ctx: NSManagedObjectContext) -> Int32 {
        let req = NSFetchRequest<NSDictionary>(entityName: "SceneEntity")
        req.resultType = .dictionaryResultType
        req.predicate = NSPredicate(format: "project == %@", project)
        let expr = NSExpressionDescription()
        expr.name = "maxOrder"
        expr.expression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "displayOrder")])
        expr.expressionResultType = .integer32AttributeType
        let maxVal = (try? ctx.fetch(req)).flatMap { $0.first?["maxOrder"] as? Int32 } ?? 0
        return maxVal + 1
    }
}
