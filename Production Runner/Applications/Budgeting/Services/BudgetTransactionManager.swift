import Foundation
import CoreData

/// Manages budget transaction operations with validation
/// Extracted from BudgetViewModel for single responsibility
final class BudgetTransactionManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var transactions: [BudgetTransaction] = []

    // MARK: - Private Properties

    private let context: NSManagedObjectContext
    private let auditTrail: BudgetAuditTrail

    // MARK: - Initialization

    init(context: NSManagedObjectContext, auditTrail: BudgetAuditTrail = BudgetAuditTrail()) {
        self.context = context
        self.auditTrail = auditTrail
    }

    // MARK: - Transaction Loading

    /// Load transactions from a budget version
    func loadTransactions(from version: BudgetVersion) {
        transactions = version.transactions
        BudgetLogger.info("Loaded \(transactions.count) transactions", category: BudgetLogger.transaction)
    }

    /// Load transactions from CoreData
    func loadTransactionsFromCoreData() {
        let entities = BudgetTransactionEntity.fetchAll(in: context)
        transactions = entities.map { entity in
            BudgetTransaction(
                id: entity.id ?? UUID(),
                date: entity.date ?? Date(),
                amount: entity.amount,
                category: entity.category ?? BudgetCategory.other.rawValue,
                department: "",
                transactionType: entity.transactionType ?? TransactionType.expense.rawValue,
                descriptionText: entity.descriptionText ?? "",
                payee: entity.payee ?? "",
                notes: entity.notes ?? "",
                lineItemID: entity.lineItemID,
                vendorID: entity.vendorID
            )
        }
        BudgetLogger.info("Loaded \(transactions.count) transactions from CoreData", category: BudgetLogger.transaction)
    }

    // MARK: - Transaction CRUD

    /// Add a new transaction with validation
    func addTransaction(_ transaction: BudgetTransaction, budgetRemaining: Double? = nil) -> Result<BudgetTransaction, BudgetValidationError> {
        // Validate transaction
        let validationResult = BudgetValidation.validate(transaction, budgetRemaining: budgetRemaining)
        if case .failure(let error) = validationResult {
            BudgetLogger.logValidationError(error)
            return .failure(error)
        }

        transactions.append(transaction)

        // Save to CoreData
        saveTransactionToCoreData(transaction)

        auditTrail.recordChange(
            action: .created,
            entityType: "Transaction",
            entityID: transaction.id,
            details: "Added transaction: \(transaction.amount.asCurrency())"
        )

        BudgetLogger.logDataOperation(.create, entity: "Transaction", success: true)
        return .success(transaction)
    }

    /// Update an existing transaction
    func updateTransaction(_ transaction: BudgetTransaction, budgetRemaining: Double? = nil) -> Result<BudgetTransaction, BudgetValidationError> {
        // Validate transaction
        let validationResult = BudgetValidation.validate(transaction, budgetRemaining: budgetRemaining)
        if case .failure(let error) = validationResult {
            BudgetLogger.logValidationError(error)
            return .failure(error)
        }

        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            updateTransactionInCoreData(transaction)

            auditTrail.recordChange(
                action: .updated,
                entityType: "Transaction",
                entityID: transaction.id,
                details: "Updated transaction: \(transaction.amount.asCurrency())"
            )

            BudgetLogger.logDataOperation(.update, entity: "Transaction", success: true)
            return .success(transaction)
        }

        return .failure(.invalidAmount(0))
    }

    /// Delete a transaction
    func deleteTransaction(_ transaction: BudgetTransaction) {
        transactions.removeAll { $0.id == transaction.id }
        deleteTransactionFromCoreData(transaction.id)

        auditTrail.recordChange(
            action: .deleted,
            entityType: "Transaction",
            entityID: transaction.id,
            details: "Deleted transaction: \(transaction.amount.asCurrency())"
        )

        BudgetLogger.logDataOperation(.delete, entity: "Transaction", success: true)
    }

    // MARK: - CoreData Operations

    private func saveTransactionToCoreData(_ transaction: BudgetTransaction) {
        let _ = BudgetTransactionEntity.create(
            date: transaction.date,
            amount: transaction.amount,
            category: transaction.category,
            transactionType: transaction.transactionType,
            descriptionText: transaction.descriptionText,
            payee: transaction.payee,
            notes: transaction.notes,
            lineItemID: transaction.lineItemID,
            vendorID: transaction.vendorID,
            in: context
        )
    }

    private func updateTransactionInCoreData(_ transaction: BudgetTransaction) {
        let request: NSFetchRequest<BudgetTransactionEntity> = BudgetTransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                entity.update(
                    date: transaction.date,
                    amount: transaction.amount,
                    category: transaction.category,
                    transactionType: transaction.transactionType,
                    descriptionText: transaction.descriptionText,
                    payee: transaction.payee,
                    notes: transaction.notes
                )
            }
        } catch {
            BudgetLogger.error("Failed to update transaction in CoreData: \(error.localizedDescription)", category: BudgetLogger.transaction)
        }
    }

    private func deleteTransactionFromCoreData(_ id: UUID) {
        let request: NSFetchRequest<BudgetTransactionEntity> = BudgetTransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                entity.delete()
            }
        } catch {
            BudgetLogger.error("Failed to delete transaction from CoreData: \(error.localizedDescription)", category: BudgetLogger.transaction)
        }
    }

    // MARK: - Filtering

    /// Filter transactions by category
    func transactions(for category: String) -> [BudgetTransaction] {
        transactions.filter { $0.category == category }
    }

    /// Filter transactions by line item
    func transactions(for lineItemID: UUID) -> [BudgetTransaction] {
        transactions.filter { $0.lineItemID == lineItemID }
    }

    /// Filter transactions by type
    func transactions(ofType type: TransactionType) -> [BudgetTransaction] {
        transactions.filter { $0.transactionType == type.rawValue }
    }

    /// Filter transactions by date range
    func transactions(from startDate: Date, to endDate: Date) -> [BudgetTransaction] {
        transactions.filter { $0.date >= startDate && $0.date <= endDate }
    }

    // MARK: - Calculations

    /// Calculate total for all transactions
    var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    /// Calculate total expenses
    var totalExpenses: Double {
        transactions(ofType: .expense).reduce(0) { $0 + $1.amount }
    }

    /// Calculate total by category
    func totalByCategory() -> [String: Double] {
        var totals: [String: Double] = [:]
        for transaction in transactions {
            totals[transaction.category, default: 0] += transaction.amount
        }
        return totals
    }

    /// Calculate total spent on a line item
    func totalSpent(for lineItemID: UUID) -> Double {
        transactions(for: lineItemID)
            .filter { $0.transactionType == TransactionType.expense.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Bulk Operations

    /// Set all transactions (used when loading from version)
    func setTransactions(_ newTransactions: [BudgetTransaction]) {
        transactions = newTransactions
    }

    /// Clear all transactions
    func clearTransactions() {
        transactions.removeAll()
    }
}
