import Foundation
import os.log

/// Centralized logging for the Budgeting module
/// Replaces scattered print statements with structured, configurable logging
enum BudgetLogger {

    // MARK: - Log Categories

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.productionrunner"

    static let general = Logger(subsystem: subsystem, category: "Budget.General")
    static let data = Logger(subsystem: subsystem, category: "Budget.Data")
    static let template = Logger(subsystem: subsystem, category: "Budget.Template")
    static let calculation = Logger(subsystem: subsystem, category: "Budget.Calculation")
    static let transaction = Logger(subsystem: subsystem, category: "Budget.Transaction")
    static let validation = Logger(subsystem: subsystem, category: "Budget.Validation")
    static let export = Logger(subsystem: subsystem, category: "Budget.Export")
    static let audit = Logger(subsystem: subsystem, category: "Budget.Audit")

    // MARK: - Convenience Methods

    /// Log a debug message
    static func debug(_ message: String, category: Logger = general) {
        category.debug("\(message)")
    }

    /// Log an info message
    static func info(_ message: String, category: Logger = general) {
        category.info("\(message)")
    }

    /// Log a warning message
    static func warning(_ message: String, category: Logger = general) {
        category.warning("⚠️ \(message)")
    }

    /// Log an error message
    static func error(_ message: String, category: Logger = general) {
        category.error("❌ \(message)")
    }

    /// Log a success message
    static func success(_ message: String, category: Logger = general) {
        category.info("✅ \(message)")
    }

    // MARK: - Specialized Logging

    /// Log template loading operations
    static func logTemplateLoad(name: String, itemCount: Int) {
        template.info("Loaded template '\(name)' with \(itemCount) items")
    }

    /// Log template loading failure
    static func logTemplateError(_ error: Error, templateName: String) {
        template.error("Failed to load template '\(templateName)': \(error.localizedDescription)")
    }

    /// Log data persistence operations
    static func logDataOperation(_ operation: DataOperation, entity: String, success: Bool) {
        if success {
            data.info("\(operation.rawValue) \(entity) succeeded")
        } else {
            data.error("\(operation.rawValue) \(entity) failed")
        }
    }

    /// Log calculation operations
    static func logCalculation(type: String, result: Double) {
        calculation.debug("Calculated \(type): \(result)")
    }

    /// Log validation errors
    static func logValidationError(_ error: BudgetValidationError) {
        validation.warning("Validation failed: \(error.localizedDescription)")
    }

    /// Log export operations
    static func logExport(format: ExportFormat, itemCount: Int, success: Bool) {
        if success {
            export.info("Exported \(itemCount) items to \(format.rawValue)")
        } else {
            export.error("Failed to export \(itemCount) items to \(format.rawValue)")
        }
    }

    /// Log audit trail entries
    static func logAuditEntry(action: AuditAction, entityType: String, entityID: UUID) {
        audit.info("[\(action.rawValue)] \(entityType) \(entityID.uuidString.prefix(8))")
    }

    // MARK: - Supporting Types

    enum DataOperation: String {
        case create = "CREATE"
        case read = "READ"
        case update = "UPDATE"
        case delete = "DELETE"
        case save = "SAVE"
    }

    enum ExportFormat: String {
        case csv = "CSV"
        case pdf = "PDF"
        case json = "JSON"
        case excel = "Excel"
    }

    enum AuditAction: String {
        case created = "CREATED"
        case updated = "UPDATED"
        case deleted = "DELETED"
        case locked = "LOCKED"
        case unlocked = "UNLOCKED"
        case exported = "EXPORTED"
        case imported = "IMPORTED"
    }
}

// MARK: - Validation Error Types

enum BudgetValidationError: LocalizedError {
    case emptyName
    case invalidAmount(Double)
    case negativeQuantity
    case negativeDays
    case negativeUnitCost
    case futureDate
    case invalidCurrency(String)
    case duplicateName(String)
    case invalidAccountCode(String)
    case budgetLocked
    case transactionExceedsBudget(available: Double, requested: Double)
    case invalidDateRange(start: Date, end: Date)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Name cannot be empty"
        case .invalidAmount(let amount):
            return "Invalid amount: \(amount)"
        case .negativeQuantity:
            return "Quantity cannot be negative"
        case .negativeDays:
            return "Days cannot be negative"
        case .negativeUnitCost:
            return "Unit cost cannot be negative"
        case .futureDate:
            return "Transaction date cannot be in the future"
        case .invalidCurrency(let code):
            return "Invalid currency code: \(code)"
        case .duplicateName(let name):
            return "An item with name '\(name)' already exists"
        case .invalidAccountCode(let code):
            return "Invalid account code: \(code)"
        case .budgetLocked:
            return "This budget version is locked and cannot be modified"
        case .transactionExceedsBudget(let available, let requested):
            return "Transaction amount (\(requested.asCurrency())) exceeds available budget (\(available.asCurrency()))"
        case .invalidDateRange(let start, let end):
            return "Invalid date range: start (\(start)) must be before end (\(end))"
        }
    }
}
