//
//  ContactHistoryService.swift
//  Production Runner
//
//  Tracks changes to contact fields and provides history viewing.
//

import SwiftUI
import CoreData

// MARK: - History Entry Model
struct ContactHistoryEntry: Identifiable {
    let id: UUID
    let contactID: UUID
    let fieldName: String
    let previousValue: String?
    let newValue: String?
    let changedBy: String?
    let changedAt: Date

    var displayFieldName: String {
        switch fieldName {
        case "name": return "Name"
        case "email": return "Email"
        case "phone": return "Phone"
        case "role": return "Role"
        case "category": return "Category"
        case "department": return "Department"
        case "allergies": return "Allergies"
        case "contractStatus": return "Contract Status"
        case "isFavorite": return "Favorite"
        case "tags": return "Tags"
        case "paperworkStarted": return "Paperwork Started"
        case "paperworkComplete": return "Paperwork Complete"
        case "availabilityStart": return "Available From"
        case "availabilityEnd": return "Available Until"
        default: return fieldName.capitalized
        }
    }

    var changeDescription: String {
        let prev = previousValue?.isEmpty == false ? previousValue! : "(empty)"
        let new = newValue?.isEmpty == false ? newValue! : "(empty)"

        if previousValue == nil || previousValue?.isEmpty == true {
            return "Set to \"\(new)\""
        } else if newValue == nil || newValue?.isEmpty == true {
            return "Cleared (was \"\(prev)\")"
        } else {
            return "\"\(prev)\" → \"\(new)\""
        }
    }
}

// MARK: - History Service
class ContactHistoryService {
    static let shared = ContactHistoryService()
    private let entityName = "ContactHistoryEntity"

    private init() {}

    // MARK: - Record Change

    /// Records a change to a contact field
    func recordChange(
        contactID: UUID,
        fieldName: String,
        previousValue: String?,
        newValue: String?,
        changedBy: String? = nil,
        context: NSManagedObjectContext
    ) {
        // Don't record if values are the same
        guard previousValue != newValue else { return }

        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            print("📜 [History] Failed to get entity description")
            return
        }

        let mo = NSManagedObject(entity: entity, insertInto: context)
        mo.setValue(UUID(), forKey: "id")
        mo.setValue(contactID, forKey: "contactID")
        mo.setValue(fieldName, forKey: "fieldName")
        mo.setValue(previousValue, forKey: "previousValue")
        mo.setValue(newValue, forKey: "newValue")
        mo.setValue(changedBy ?? getCurrentUser(), forKey: "changedBy")
        mo.setValue(Date(), forKey: "changedAt")

        // Don't save here - let the caller save with their other changes
    }

    /// Records multiple field changes at once
    func recordChanges(
        contactID: UUID,
        changes: [(field: String, previous: String?, new: String?)],
        changedBy: String? = nil,
        context: NSManagedObjectContext
    ) {
        for change in changes {
            recordChange(
                contactID: contactID,
                fieldName: change.field,
                previousValue: change.previous,
                newValue: change.new,
                changedBy: changedBy,
                context: context
            )
        }
    }

    // MARK: - Fetch History

    /// Fetches history for a specific contact
    func fetchHistory(for contactID: UUID, context: NSManagedObjectContext, limit: Int = 50) -> [ContactHistoryEntry] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "contactID == %@", contactID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "changedAt", ascending: false)]
        request.fetchLimit = limit

        do {
            let results = try context.fetch(request)
            return results.compactMap { mo -> ContactHistoryEntry? in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let cID = mo.value(forKey: "contactID") as? UUID,
                      let fieldName = mo.value(forKey: "fieldName") as? String,
                      let changedAt = mo.value(forKey: "changedAt") as? Date else {
                    return nil
                }

                return ContactHistoryEntry(
                    id: id,
                    contactID: cID,
                    fieldName: fieldName,
                    previousValue: mo.value(forKey: "previousValue") as? String,
                    newValue: mo.value(forKey: "newValue") as? String,
                    changedBy: mo.value(forKey: "changedBy") as? String,
                    changedAt: changedAt
                )
            }
        } catch {
            print("📜 [History] Failed to fetch history: \(error)")
            return []
        }
    }

    /// Clears all history for a contact (use when deleting contact)
    func clearHistory(for contactID: UUID, context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "contactID == %@", contactID as CVarArg)

        do {
            let results = try context.fetch(request)
            for mo in results {
                context.delete(mo)
            }
        } catch {
            print("📜 [History] Failed to clear history: \(error)")
        }
    }

    // MARK: - Helpers

    private func getCurrentUser() -> String {
        #if os(macOS)
        return NSFullUserName()
        #else
        return UIDevice.current.name
        #endif
    }
}

// MARK: - History View (macOS)
#if os(macOS)
struct ContactHistoryView: View {
    let contactID: UUID
    @Environment(\.managedObjectContext) private var context
    @State private var history: [ContactHistoryEntry] = []
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text("Change History")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    if !history.isEmpty {
                        Text("\(history.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if history.isEmpty {
                    Text("No changes recorded")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(history) { entry in
                                historyRow(entry)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .onAppear { loadHistory() }
    }

    private func historyRow(_ entry: ContactHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.displayFieldName)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Text(entry.changedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text(entry.changeDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let changedBy = entry.changedBy, !changedBy.isEmpty {
                Text("by \(changedBy)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func loadHistory() {
        history = ContactHistoryService.shared.fetchHistory(for: contactID, context: context)
    }
}

#elseif os(iOS)
struct ContactHistoryView: View {
    let contactID: UUID
    @Environment(\.managedObjectContext) private var context
    @State private var history: [ContactHistoryEntry] = []
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                        .frame(width: 24)

                    Text("Change History")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !history.isEmpty {
                        Text("\(history.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if history.isEmpty {
                    Text("No changes recorded")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 34)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(history.prefix(10)) { entry in
                            historyRow(entry)
                        }

                        if history.count > 10 {
                            Text("+ \(history.count - 10) more changes")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 34)
                        }
                    }
                }
            }
        }
        .onAppear { loadHistory() }
    }

    private func historyRow(_ entry: ContactHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.displayFieldName)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Text(entry.changedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text(entry.changeDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 34)
    }

    private func loadHistory() {
        history = ContactHistoryService.shared.fetchHistory(for: contactID, context: context)
    }
}
#endif
