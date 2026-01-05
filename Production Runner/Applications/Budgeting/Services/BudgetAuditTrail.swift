import Foundation

/// Records and manages audit trail for budget changes
/// Provides change history, undo capability, and compliance tracking
final class BudgetAuditTrail: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var entries: [AuditEntry] = []
    @Published private(set) var undoStack: [AuditEntry] = []
    @Published private(set) var redoStack: [AuditEntry] = []

    // MARK: - Configuration

    private let maxEntries: Int
    private let maxUndoStackSize: Int
    private let storageKey = "budgetAuditTrail"

    // MARK: - Initialization

    init(maxEntries: Int = 1000, maxUndoStackSize: Int = 50) {
        self.maxEntries = maxEntries
        self.maxUndoStackSize = maxUndoStackSize
        loadEntries()
    }

    // MARK: - Audit Entry Recording

    /// Record a change to the budget
    func recordChange(
        action: AuditAction,
        entityType: String,
        entityID: UUID,
        details: String,
        previousValue: String? = nil,
        newValue: String? = nil,
        userID: String? = nil
    ) {
        let entry = AuditEntry(
            id: UUID(),
            timestamp: Date(),
            action: action,
            entityType: entityType,
            entityID: entityID,
            details: details,
            previousValue: previousValue,
            newValue: newValue,
            userID: userID ?? "system"
        )

        entries.insert(entry, at: 0)

        // Trim if exceeded max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        // Add to undo stack for undoable actions
        if action.isUndoable {
            undoStack.append(entry)
            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }
            // Clear redo stack on new action
            redoStack.removeAll()
        }

        saveEntries()

        // Convert to BudgetLogger.AuditAction if applicable
        if let loggerAction = BudgetLogger.AuditAction(rawValue: action.rawValue) {
            BudgetLogger.logAuditEntry(action: loggerAction, entityType: entityType, entityID: entityID)
        }
    }

    /// Record a line item change with before/after values
    func recordLineItemChange(
        action: AuditAction,
        item: BudgetLineItem,
        previousItem: BudgetLineItem? = nil
    ) {
        var details = "\(action.rawValue) line item '\(item.name)'"

        var previousValue: String? = nil
        var newValue: String? = nil

        if let previous = previousItem {
            // Calculate what changed
            var changes: [String] = []

            if previous.name != item.name {
                changes.append("name: '\(previous.name)' → '\(item.name)'")
            }
            if previous.quantity != item.quantity {
                changes.append("qty: \(previous.quantity) → \(item.quantity)")
            }
            if previous.days != item.days {
                changes.append("days: \(previous.days) → \(item.days)")
            }
            if previous.unitCost != item.unitCost {
                changes.append("rate: \(previous.unitCost.asCurrency()) → \(item.unitCost.asCurrency())")
            }
            if previous.total != item.total {
                changes.append("total: \(previous.total.asCurrency()) → \(item.total.asCurrency())")
            }

            if !changes.isEmpty {
                details += " - " + changes.joined(separator: ", ")
            }

            previousValue = encodeItem(previous)
        }

        newValue = encodeItem(item)

        recordChange(
            action: action,
            entityType: "BudgetLineItem",
            entityID: item.id,
            details: details,
            previousValue: previousValue,
            newValue: newValue
        )
    }

    /// Record a transaction change
    func recordTransactionChange(
        action: AuditAction,
        transaction: BudgetTransaction,
        previousTransaction: BudgetTransaction? = nil
    ) {
        var details = "\(action.rawValue) transaction: \(transaction.amount.asCurrency())"

        if let previous = previousTransaction {
            if previous.amount != transaction.amount {
                details += " (was \(previous.amount.asCurrency()))"
            }
        }

        recordChange(
            action: action,
            entityType: "BudgetTransaction",
            entityID: transaction.id,
            details: details
        )
    }

    // MARK: - Undo/Redo

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Get the last undoable entry
    func popUndo() -> AuditEntry? {
        guard let entry = undoStack.popLast() else { return nil }
        redoStack.append(entry)
        return entry
    }

    /// Get the last redoable entry
    func popRedo() -> AuditEntry? {
        guard let entry = redoStack.popLast() else { return nil }
        undoStack.append(entry)
        return entry
    }

    // MARK: - Query Methods

    /// Get entries for a specific entity
    func entries(for entityID: UUID) -> [AuditEntry] {
        entries.filter { $0.entityID == entityID }
    }

    /// Get entries for a specific entity type
    func entries(forType entityType: String) -> [AuditEntry] {
        entries.filter { $0.entityType == entityType }
    }

    /// Get entries within a date range
    func entries(from startDate: Date, to endDate: Date) -> [AuditEntry] {
        entries.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get entries for a specific action
    func entries(forAction action: AuditAction) -> [AuditEntry] {
        entries.filter { $0.action == action }
    }

    /// Get recent entries
    func recentEntries(limit: Int = 50) -> [AuditEntry] {
        Array(entries.prefix(limit))
    }

    // MARK: - Persistence

    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AuditEntry].self, from: data) {
            entries = decoded
            BudgetLogger.info("Loaded \(entries.count) audit entries", category: BudgetLogger.audit)
        }
    }

    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// Clear all audit entries (for testing/reset)
    func clearAll() {
        entries.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
        saveEntries()
        BudgetLogger.info("Cleared all audit entries", category: BudgetLogger.audit)
    }

    // MARK: - Export

    /// Export audit trail to JSON
    func exportToJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(entries)
        } catch {
            BudgetLogger.error("Failed to export audit trail: \(error.localizedDescription)", category: BudgetLogger.audit)
            return nil
        }
    }

    /// Export audit trail to CSV
    func exportToCSV() -> String {
        var csv = "Timestamp,Action,Entity Type,Entity ID,Details,User\n"

        let dateFormatter = ISO8601DateFormatter()

        for entry in entries {
            let row = [
                dateFormatter.string(from: entry.timestamp),
                entry.action.rawValue,
                entry.entityType,
                entry.entityID.uuidString,
                "\"\(entry.details.replacingOccurrences(of: "\"", with: "\"\""))\"",
                entry.userID
            ]
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }

    // MARK: - Helpers

    private func encodeItem(_ item: BudgetLineItem) -> String? {
        guard let data = try? JSONEncoder().encode(item) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeItem(_ string: String) -> BudgetLineItem? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BudgetLineItem.self, from: data)
    }
}

// MARK: - Audit Entry

struct AuditEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let action: AuditAction
    let entityType: String
    let entityID: UUID
    let details: String
    let previousValue: String?
    let newValue: String?
    let userID: String

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Audit Action

enum AuditAction: String, Codable, CaseIterable {
    case created = "CREATED"
    case updated = "UPDATED"
    case deleted = "DELETED"
    case locked = "LOCKED"
    case unlocked = "UNLOCKED"
    case exported = "EXPORTED"
    case imported = "IMPORTED"
    case duplicated = "DUPLICATED"
    case templateLoaded = "TEMPLATE_LOADED"
    case versionSelected = "VERSION_SELECTED"

    var icon: String {
        switch self {
        case .created: return "plus.circle.fill"
        case .updated: return "pencil.circle.fill"
        case .deleted: return "trash.circle.fill"
        case .locked: return "lock.circle.fill"
        case .unlocked: return "lock.open.fill"
        case .exported: return "square.and.arrow.up.circle.fill"
        case .imported: return "square.and.arrow.down.circle.fill"
        case .duplicated: return "doc.on.doc.fill"
        case .templateLoaded: return "doc.text.fill"
        case .versionSelected: return "checkmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .created: return "green"
        case .updated: return "blue"
        case .deleted: return "red"
        case .locked: return "orange"
        case .unlocked: return "yellow"
        case .exported, .imported: return "purple"
        case .duplicated: return "cyan"
        case .templateLoaded, .versionSelected: return "gray"
        }
    }

    var isUndoable: Bool {
        switch self {
        case .created, .updated, .deleted:
            return true
        default:
            return false
        }
    }
}
