//
//  ShotStore.swift
//  Production Runner
//

import Foundation
import CoreData

@MainActor
public final class ShotStore: ObservableObject {
    @Published public private(set) var shots: [ShotEntity] = []

    private let context: NSManagedObjectContext
    private weak var scene: SceneEntity?

    public init(context: NSManagedObjectContext, scene: SceneEntity?) {
        self.context = context
        self.scene = scene
        reload()
    }

    public func setScene(_ scene: SceneEntity?) {
        self.scene = scene
        reload()
    }

    public func reload() {
        guard let scene else { shots = []; return }
        let req: NSFetchRequest<ShotEntity> = ShotEntity.fetchRequest()
        req.predicate = NSPredicate(format: "scene == %@", scene)
        // Prefer `index`, fallback to `displayOrder` if present
        var sorters: [NSSortDescriptor] = []
        if ShotEntity.entity().attributesByName.keys.contains("index") {
            sorters.append(NSSortDescriptor(key: "index", ascending: true))
        } else if ShotEntity.entity().attributesByName.keys.contains("displayOrder") {
            sorters.append(NSSortDescriptor(key: "displayOrder", ascending: true))
        }
        req.sortDescriptors = sorters
        do {
            shots = try context.fetch(req)
        } catch {
            NSLog("[ShotStore] fetch error: %@", String(describing: error))
            shots = []
        }
    }

    @discardableResult
    public func addShot(
        code: String = "",
        type: String = "",
        lens: String = "",
        focalLength: String = "",
        descriptionText: String = "",
        notes: String = ""
    ) -> ShotEntity? {
        guard let scene else {
            NSLog("[ShotStore] No scene set. Cannot add shot.")
            return nil
        }
        let s = ShotEntity(context: context)
        s.id = UUID()
        s.code = code
        s.type = type
        s.lens = lens
        s.focalLength = focalLength
        s.descriptionText = descriptionText
        s.notes = notes
        s.scene = scene

        // Set sequential order if the field exists
        if ShotEntity.entity().attributesByName.keys.contains("index") {
            let nextIndex = (shots.last?.index ?? -1) + 1
            s.index = Int16(nextIndex)
        } else if ShotEntity.entity().attributesByName.keys.contains("displayOrder") {
            let last = (shots.last?.value(forKey: "displayOrder") as? NSNumber)?.intValue ?? -1
            s.setValue(last + 1, forKey: "displayOrder")
        }

        do {
            try context.save()
            reload()
            return s
        } catch {
            NSLog("[ShotStore] save error: %@", String(describing: error))
            context.rollback()
            return nil
        }
    }

    public func delete(_ shot: ShotEntity) {
        context.delete(shot)
        do {
            try context.save()
            reload()
        } catch {
            NSLog("[ShotStore] delete error: %@", String(describing: error))
            context.rollback()
        }
    }

    public func move(from source: IndexSet, to destination: Int) {
        var current = shots
        current.move(fromOffsets: source, toOffset: destination)
        // Reindex in-order
        for (i, sh) in current.enumerated() {
            if ShotEntity.entity().attributesByName.keys.contains("index") {
                sh.index = Int16(i)
            } else if ShotEntity.entity().attributesByName.keys.contains("displayOrder") {
                sh.setValue(i, forKey: "displayOrder")
            }
        }
        do {
            try context.save()
            self.shots = current
        } catch {
            NSLog("[ShotStore] move/save error: %@", String(describing: error))
            context.rollback()
            reload()
        }
    }
}
