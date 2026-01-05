// ProjectStore.swift
import Foundation
import CoreData

public final class ProjectStore: ObservableObject {
    public let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    @discardableResult
    public func create(name: String = "Untitled", user: String? = nil, statusRaw: String? = nil) -> NSManagedObject? {
        guard let entity = NSEntityDescription.entity(forEntityName: "ProjectEntity", in: context) else {
            #if DEBUG
            print("⚠️ ProjectStore.create: 'ProjectEntity' not found in model.")
            #endif
            return nil
        }
        let now = Date()
        let p = NSManagedObject(entity: entity, insertInto: context)
        p.setValue(UUID(), forKey: "id")
        p.setValue(name.isEmpty ? "Untitled" : name, forKey: "name")
        p.setValue(now, forKey: "createdAt")
        p.setValue(now, forKey: "updatedAt")
        if let user, entity.attributesByName.keys.contains("user") {
            p.setValue(user, forKey: "user")
        }
        if let statusRaw, entity.attributesByName.keys.contains("status") {
            p.setValue(statusRaw, forKey: "status")
        }
        try? context.save()
        return p
    }

    public func touch(_ obj: NSManagedObject) {
        if obj.entity.attributesByName.keys.contains("updatedAt") {
            obj.setValue(Date(), forKey: "updatedAt")
        }
        try? context.save()
    }

    public static func fetchAll(in context: NSManagedObjectContext) -> [NSManagedObject] {
        // Ensure the entity exists in the loaded model
        guard let entity = NSEntityDescription.entity(forEntityName: "ProjectEntity", in: context) else {
            #if DEBUG
            print("⚠️ ProjectStore.fetchAll: 'ProjectEntity' not found in model.")
            #endif
            return []
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")

        // Build sort descriptors only for keys that actually exist
        var sorts: [NSSortDescriptor] = []
        let keys = entity.attributesByName.keys
        if keys.contains("updatedAt") { sorts.append(NSSortDescriptor(key: "updatedAt", ascending: false)) }
        if keys.contains("createdAt") { sorts.append(NSSortDescriptor(key: "createdAt", ascending: false)) }
        if sorts.isEmpty {
            // Fallback to name if available, else no sorting
            if keys.contains("name") { sorts.append(NSSortDescriptor(key: "name", ascending: true)) }
        }
        request.sortDescriptors = sorts

        return (try? context.fetch(request)) ?? []
    }
}
