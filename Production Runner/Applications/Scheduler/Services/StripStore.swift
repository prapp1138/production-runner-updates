//
//  StripStore.swift
//  Production Runner
//
//  Shared source of truth for SceneEntity ("strips") across Breakdowns, Scheduler, Shot Lister.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
public final class StripStore: ObservableObject {
    @Published public private(set) var scenes: [SceneEntity] = []

    private let context: NSManagedObjectContext
    private var project: ProjectEntity?
    private var observer: NSObjectProtocol?
    private var reloadWorkItem: DispatchWorkItem?

    public init(context: NSManagedObjectContext, project: ProjectEntity?) {
        self.context = context
        self.project = project
        // Defer initial reload to avoid view update conflicts
        scheduleReload()
        setupObserver()
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if let syncObserver = syncObserver {
            NotificationCenter.default.removeObserver(syncObserver)
        }
        if let storeObserver = storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    private var syncObserver: NSObjectProtocol?

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // Check if any SceneEntity objects were inserted, deleted, or updated
            let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? Set()
            let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? Set()
            let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? Set()

            let hasSceneChanges = inserted.contains(where: { $0 is SceneEntity }) ||
                                   deleted.contains(where: { $0 is SceneEntity }) ||
                                   updated.contains(where: { $0 is SceneEntity })

            let hasBreakdownChanges = inserted.contains(where: { $0 is BreakdownEntity }) ||
                                       deleted.contains(where: { $0 is BreakdownEntity }) ||
                                       updated.contains(where: { $0 is BreakdownEntity })

            if hasSceneChanges || hasBreakdownChanges {
                Task { @MainActor in
                    self.reload()
                }
            }
        }

        // Also listen for screenplay sync completion notification
        syncObserver = NotificationCenter.default.addObserver(
            forName: .screenplayBreakdownSyncCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📋📋📋 [StripStore] Received screenplayBreakdownSyncCompleted notification")
            print("📋 [StripStore] self is nil: \(self == nil)")
            Task { @MainActor in
                guard let self = self else {
                    print("📋 [StripStore] ⚠️ self was deallocated - cannot reload")
                    return
                }
                print("📋 [StripStore] About to call reload()")
                self.reload()
                print("📋 [StripStore] reload() completed - scenes count: \(self.scenes.count)")
            }
        }

        // Also listen for store switch notification (used throughout app for refresh)
        storeObserver = NotificationCenter.default.addObserver(
            forName: .prStoreDidSwitch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📋 [StripStore] Received prStoreDidSwitch notification")
            Task { @MainActor in
                guard let self = self else { return }
                self.reload()
            }
        }
    }

    private var storeObserver: NSObjectProtocol?

    public func setProject(_ project: ProjectEntity?) {
        let oldID = self.project?.id?.uuidString ?? "nil"
        let newID = project?.id?.uuidString ?? "nil"
        NSLog("[StripStore] 🔄 Project switch: \(oldID) → \(newID)")

        self.project = project
        reload()
    }

    public func reload() {
        scheduleReload()
    }

    private func scheduleReload() {
        // Cancel any pending reload
        reloadWorkItem?.cancel()

        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.performReload()
        }

        reloadWorkItem = workItem

        // Schedule with a tiny delay to escape the view update cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001, execute: workItem)
    }

    private func performReload() {
        print("📋 [StripStore] performReload() called")

        // Refresh the context to pick up changes from other contexts
        context.refreshAllObjects()

        guard let project = self.project else {
            print("📋 [StripStore] ⚠️ No project set - returning empty scenes")
            scenes = []
            return
        }

        self.reloadScenes(for: project)
    }

    private func reloadScenes(for project: ProjectEntity) {

        // Re-fetch the project from the context to ensure we have the latest version
        // This fixes issues where the project object reference may be stale
        let freshProject: ProjectEntity
        if let projectID = project.id {
            let projectFetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            projectFetch.predicate = NSPredicate(format: "id == %@", projectID as CVarArg)
            projectFetch.fetchLimit = 1
            if let fetched = try? context.fetch(projectFetch).first {
                freshProject = fetched
                // Update our stored reference if it's different
                if freshProject.objectID != project.objectID {
                    print("📋 [StripStore] 🔄 Updated project reference from \(project.objectID) to \(freshProject.objectID)")
                    self.project = freshProject
                }
            } else {
                freshProject = project
            }
        } else {
            freshProject = project
        }

        print("📋 [StripStore] Using project: \(freshProject.objectID)")
        print("📋 [StripStore] Project ID: \(freshProject.id?.uuidString ?? "nil")")

        let req: NSFetchRequest<SceneEntity> = SceneEntity.fetchRequest()
        req.predicate = NSPredicate(format: "project == %@", freshProject)
        req.sortDescriptors = [
            NSSortDescriptor(key: "displayOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        do {
            scenes = try context.fetch(req)
            print("📋 [StripStore] Fetched \(scenes.count) scenes for project")

            // REMOVED: Async orphan detection - this caused race conditions
            // Orphan scenes should never exist if scenes are properly assigned at creation time
            // If orphans are detected, it indicates a bug in scene creation logic that should be fixed at the source

            // Debug logging only - do not attempt to fix orphans here
            let allScenesReq: NSFetchRequest<SceneEntity> = SceneEntity.fetchRequest()
            let allScenes = try context.fetch(allScenesReq)
            let orphanScenes = allScenes.filter { $0.project == nil }

            if !orphanScenes.isEmpty {
                NSLog("[StripStore] ⚠️ WARNING: Detected \(orphanScenes.count) orphan scenes without project assignment")
                NSLog("[StripStore] ⚠️ This indicates a bug in scene creation. Orphan scenes: \(orphanScenes.compactMap { $0.number }.joined(separator: ", "))")
            }

            print("📋 [StripStore] Total scenes in database (all projects): \(allScenes.count)")
            if scenes.count == 0 && allScenes.count > 0 {
                print("📋 [StripStore] No scenes match our project. Scenes belong to different projects:")
                for (idx, scene) in allScenes.prefix(3).enumerated() {
                    let sceneProjectID = scene.project?.id?.uuidString ?? "nil"
                    let ourProjectID = freshProject.id?.uuidString ?? "nil"
                    print("   Scene[\(idx)] '\(scene.number ?? "?")' projectID=\(sceneProjectID), ourProjectID=\(ourProjectID)")
                }
            }

            if scenes.count < 5 && scenes.count > 0 {
                for (idx, scene) in scenes.enumerated() {
                    print("   [\(idx)] number='\(scene.number ?? "(nil)")' displayOrder=\(scene.displayOrder)")
                }
            }
        } catch {
            NSLog("[StripStore] fetch error: %@", String(describing: error))
            scenes = []
        }
    }

    @discardableResult
    public func addScene(
        number: String,
        locationType: String,
        timeOfDay: String,
        scriptLocation: String,
        castIDsCSV: String,
        pageEighths: Int16
    ) -> SceneEntity? {
        // CRITICAL: Validate project before creating scene
        guard let project else {
            NSLog("[StripStore] ❌ CRITICAL: No project set. Cannot add scene.")
            NSLog("[StripStore] ❌ Call stack: %@", Thread.callStackSymbols.prefix(5).joined(separator: "\n"))
            assertionFailure("StripStore.addScene called without project set")
            return nil
        }

        // Validate project is not faulted and has valid ID
        guard !project.isFault, let projectID = project.id else {
            NSLog("[StripStore] ❌ CRITICAL: Project is faulted or has no ID")
            NSLog("[StripStore] ❌ Project fault: \(project.isFault), ID: \(project.id?.uuidString ?? "nil")")
            assertionFailure("Invalid project state in StripStore")
            return nil
        }

        let strip = SceneEntity(context: context)
        strip.id = UUID()
        strip.number = number.trimmingCharacters(in: .whitespacesAndNewlines)
        strip.locationType = locationType
        strip.timeOfDay = timeOfDay
        strip.scriptLocation = scriptLocation.uppercased()
        strip.castIDs = castIDsCSV
        strip.pageEighths = pageEighths
        strip.createdAt = Date()

        // CRITICAL: Set project BEFORE any other operations
        strip.project = project

        NSLog("[StripStore] ✅ Created scene '\(strip.number ?? "?")' for project \(projectID.uuidString)")

        // Append to end based on existing order
        let lastOrder = (scenes.last?.displayOrder ?? -1)
        strip.displayOrder = lastOrder + 1

        do {
            try context.save()
            reload()
            return strip
        } catch {
            NSLog("[StripStore] save error: %@", String(describing: error))
            context.rollback()
            return nil
        }
    }

    public func delete(_ scene: SceneEntity) {
        context.delete(scene)
        do {
            try context.save()
            reload()
        } catch {
            NSLog("[StripStore] delete error: %@", String(describing: error))
            context.rollback()
        }
    }

    /// Persist reordering (use from a List .onMove or DragTarget grid)
    public func move(from source: IndexSet, to destination: Int) {
        var current = scenes
        current.move(fromOffsets: source, toOffset: destination)
        for (i, s) in current.enumerated() {
            s.displayOrder = Int32(i)
        }
        do {
            try context.save()
            reload()
        } catch {
            NSLog("[StripStore] move/save error: %@", String(describing: error))
            context.rollback()
        }
    }
}
