//
//  ContactsService.swift
//  Production Runner
//
//  Shared service for adding contacts from other parts of the app.
//  Used by Plan app when cast/crew are confirmed.
//

import Foundation
import CoreData

/// Shared service for managing contacts from any part of the app
class ContactsService {
    static let shared = ContactsService()

    private let contactEntityName = "ContactEntity"

    private init() {}

    // MARK: - Public API

    /// Add a contact with just a name (used when confirming cast/crew in Plan)
    /// Only sets name, category, and department - all other fields left empty for user to fill in.
    /// - Parameters:
    ///   - name: The person's name
    ///   - category: The contact category (.cast, .crew, or .vendor)
    ///   - department: The department for the contact
    ///   - context: The Core Data managed object context
    /// - Returns: True if the contact was added successfully
    @discardableResult
    func addContact(
        name: String,
        category: Contact.Category,
        department: Contact.Department,
        context: NSManagedObjectContext
    ) -> Bool {
        // Don't add empty names
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("📇 [ContactsService] Skipping empty name")
            return false
        }

        // Check if contact with this name already exists
        if contactExists(name: name, context: context) {
            print("📇 [ContactsService] Contact '\(name)' already exists, skipping")
            return false
        }

        // Create new contact
        guard let entity = NSEntityDescription.entity(forEntityName: contactEntityName, in: context) else {
            print("📇 [ContactsService] ❌ Failed to get entity description for '\(contactEntityName)'")
            return false
        }

        let mo = NSManagedObject(entity: entity, insertInto: context)

        // Only set the essentials: id, name, category, department, and createdAt
        mo.setValue(UUID(), forKey: "id")
        mo.setValue(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "name")
        mo.setValue(Date(), forKey: "createdAt")

        // Set category
        writeCategory(category, into: mo, context: context)

        // Set department
        writeDepartment(department, into: mo, context: context)

        // Save
        do {
            try context.save()
            print("📇 [ContactsService] ✅ Added contact: \(name) (\(category.rawValue))")

            // Post notification so ContactsView can refresh
            NotificationCenter.default.post(name: .contactsDidChange, object: nil)

            return true
        } catch {
            print("📇 [ContactsService] ❌ Failed to save contact: \(error)")
            return false
        }
    }

    // MARK: - Private Helpers

    private func contactExists(name: String, context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: contactEntityName)
        request.predicate = NSPredicate(format: "name ==[c] %@", name.trimmingCharacters(in: .whitespacesAndNewlines))
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("📇 [ContactsService] Error checking for existing contact: \(error)")
            return false
        }
    }

    private func entityAttributes(context: NSManagedObjectContext) -> [String: NSAttributeDescription] {
        guard
            let psc = context.persistentStoreCoordinator,
            let entity = psc.managedObjectModel.entitiesByName[contactEntityName]
        else { return [:] }
        return entity.attributesByName
    }

    private func entityHas(_ key: String, context: NSManagedObjectContext) -> Bool {
        entityAttributes(context: context)[key] != nil
    }

    private func writeCategory(_ cat: Contact.Category, into mo: NSManagedObject, context: NSManagedObjectContext) {
        let attrs = entityAttributes(context: context)
        if let attr = attrs["category"] {
            switch attr.attributeType {
            case .stringAttributeType:
                mo.setValue(cat.rawValue, forKey: "category")
                return
            case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                let mapped: Int = (cat == .cast ? 0 : cat == .crew ? 1 : 2)
                mo.setValue(mapped as NSNumber, forKey: "category")
                return
            default:
                break
            }
        }
        // No `category` attribute — encode into `note` as a leading tag
        guard entityHas("note", context: context) else { return }
        let existing = (mo.value(forKey: "note") as? String) ?? ""
        mo.setValue("[\(cat.rawValue)] " + existing, forKey: "note")
    }

    private func writeDepartment(_ dept: Contact.Department, into mo: NSManagedObject, context: NSManagedObjectContext) {
        guard entityHas("department", context: context) else { return }
        mo.setValue(dept.rawValue, forKey: "department")
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let contactsDidChange = Notification.Name("contactsDidChange")
}
