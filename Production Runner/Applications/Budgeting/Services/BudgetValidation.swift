import Foundation

/// Centralized validation for budget-related inputs
/// Provides consistent validation across the app with clear error messages
struct BudgetValidation {

    // MARK: - Line Item Validation

    /// Validate a budget line item before saving
    static func validate(_ item: BudgetLineItem, existingItems: [BudgetLineItem] = []) -> Result<Void, BudgetValidationError> {
        // Validate name
        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(.emptyName)
        }

        // Check for duplicate names in the same category/section
        let duplicates = existingItems.filter {
            $0.id != item.id &&
            $0.name.lowercased() == item.name.lowercased() &&
            $0.category == item.category &&
            $0.section == item.section
        }
        if !duplicates.isEmpty {
            return .failure(.duplicateName(item.name))
        }

        // Validate numeric fields
        if item.quantity < 0 {
            return .failure(.negativeQuantity)
        }

        if item.days < 0 {
            return .failure(.negativeDays)
        }

        if item.unitCost < 0 {
            return .failure(.negativeUnitCost)
        }

        return .success(())
    }

    // MARK: - Transaction Validation

    /// Validate a transaction before saving
    static func validate(_ transaction: BudgetTransaction, budgetRemaining: Double? = nil) -> Result<Void, BudgetValidationError> {
        // Validate amount
        if transaction.amount.isNaN || transaction.amount.isInfinite {
            return .failure(.invalidAmount(transaction.amount))
        }

        // Check for future dates (only for expenses)
        if transaction.transactionType == TransactionType.expense.rawValue {
            if transaction.date > Date() {
                return .failure(.futureDate)
            }
        }

        // Check if transaction exceeds available budget
        if let remaining = budgetRemaining,
           transaction.transactionType == TransactionType.expense.rawValue,
           transaction.amount > remaining {
            return .failure(.transactionExceedsBudget(available: remaining, requested: transaction.amount))
        }

        return .success(())
    }

    // MARK: - Budget Version Validation

    /// Validate a budget version can be modified
    static func canModify(_ version: BudgetVersion) -> Result<Void, BudgetValidationError> {
        if version.isLocked {
            return .failure(.budgetLocked)
        }
        return .success(())
    }

    // MARK: - Currency Validation

    /// Validate a currency code
    static func validateCurrency(_ code: String) -> Result<Void, BudgetValidationError> {
        let validCodes = Set(Locale.Currency.isoCurrencies.map { $0.identifier })
        if !validCodes.contains(code.uppercased()) {
            return .failure(.invalidCurrency(code))
        }
        return .success(())
    }

    // MARK: - Date Range Validation

    /// Validate a date range
    static func validateDateRange(start: Date, end: Date) -> Result<Void, BudgetValidationError> {
        if start > end {
            return .failure(.invalidDateRange(start: start, end: end))
        }
        return .success(())
    }

    // MARK: - Account Code Validation

    /// Validate an account code format
    static func validateAccountCode(_ code: String) -> Result<Void, BudgetValidationError> {
        // Allow empty account codes
        if code.isEmpty {
            return .success(())
        }

        // Standard format: XX-XX (e.g., 10-00, 20-01)
        let pattern = #"^\d{2}-\d{2}$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(code.startIndex..., in: code)

        if regex?.firstMatch(in: code, range: range) == nil {
            return .failure(.invalidAccountCode(code))
        }

        return .success(())
    }

    // MARK: - Batch Validation

    /// Validate multiple items and return all errors
    static func validateBatch(_ items: [BudgetLineItem]) -> [UUID: BudgetValidationError] {
        var errors: [UUID: BudgetValidationError] = [:]

        for item in items {
            if case .failure(let error) = validate(item, existingItems: items) {
                errors[item.id] = error
            }
        }

        return errors
    }

    // MARK: - Numeric Validation Helpers

    /// Clamp a value to a valid range
    static func clamp(_ value: Double, min: Double = 0, max: Double = Double.greatestFiniteMagnitude) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }

    /// Round to currency precision (2 decimal places)
    static func roundToCurrency(_ value: Double) -> Double {
        return (value * 100).rounded() / 100
    }

    /// Validate and sanitize a numeric input
    static func sanitizeNumeric(_ value: Double, allowNegative: Bool = false) -> Double {
        var result = value

        // Handle NaN and Infinity
        if result.isNaN || result.isInfinite {
            result = 0
        }

        // Apply non-negative constraint if needed
        if !allowNegative && result < 0 {
            result = 0
        }

        return result
    }
}

// MARK: - Validation Result Extension

extension Result where Success == Void, Failure == BudgetValidationError {

    /// Log validation failure if present
    func logIfFailure() {
        if case .failure(let error) = self {
            BudgetLogger.logValidationError(error)
        }
    }

    /// Convert to optional error (nil if success)
    var error: BudgetValidationError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
