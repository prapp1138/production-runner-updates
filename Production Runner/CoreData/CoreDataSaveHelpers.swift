import Foundation
import CoreData
import SwiftUI

// MARK: - Save helpers
extension NSManagedObjectContext {
    /// Ensure required UUID `id` attributes are populated for inserted objects
    private func pr_autofillRequiredIDs() {
        for obj in insertedObjects {
            if let attr = obj.entity.attributesByName["id"],
               attr.attributeType == .UUIDAttributeType,
               obj.value(forKey: "id") == nil {
                obj.setValue(UUID(), forKey: "id")
            }
        }
    }

    /// Save the context, optionally only when there are changes.
    func pr_save(ifHasChangesOnly: Bool = true) {
        pr_autofillRequiredIDs()
        if !ifHasChangesOnly || hasChanges {
            do { try save() } catch {
                assertionFailure("CoreData save error: \(error)")
            }
        }
    }
}

/// Repeatedly autosave the given context every `seconds`.
func autosaveEvery(_ seconds: TimeInterval = 10, context: NSManagedObjectContext) {
    guard seconds > 0 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak context] in
        context?.pr_save()
        if let ctx = context {
            autosaveEvery(seconds, context: ctx)
        }
    }
}
