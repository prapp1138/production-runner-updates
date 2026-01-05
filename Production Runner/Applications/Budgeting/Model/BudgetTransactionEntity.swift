import Foundation
import CoreData

// BudgetTransactionEntity extension for additional functionality
extension BudgetTransactionEntity {

    // MARK: - Computed Properties

    var displayDescription: String {
        descriptionText ?? "Untitled Transaction"
    }

    var displayPayee: String {
        payee ?? "Unknown"
    }

    // MARK: - Fetch Requests

    /// Fetch all transactions
    static func fetchAll(in context: NSManagedObjectContext) -> [BudgetTransactionEntity] {
        let request: NSFetchRequest<BudgetTransactionEntity> = BudgetTransactionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching budget transactions: \(error)")
            return []
        }
    }

    /// Fetch transactions by category
    static func fetch(category: String, in context: NSManagedObjectContext) -> [BudgetTransactionEntity] {
        let request: NSFetchRequest<BudgetTransactionEntity> = BudgetTransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching transactions by category: \(error)")
            return []
        }
    }

    /// Fetch transactions for a specific line item
    static func fetch(lineItemID: UUID, in context: NSManagedObjectContext) -> [BudgetTransactionEntity] {
        let request: NSFetchRequest<BudgetTransactionEntity> = BudgetTransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "lineItemID == %@", lineItemID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching transactions for line item: \(error)")
            return []
        }
    }

    /// Fetch transactions by type
    static func fetch(transactionType: String, in context: NSManagedObjectContext) -> [BudgetTransactionEntity] {
        let request: NSFetchRequest<BudgetTransactionEntity> = BudgetTransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "transactionType == %@", transactionType)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching transactions by type: \(error)")
            return []
        }
    }

    /// Fetch transactions within a date range
    static func fetch(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) -> [BudgetTransactionEntity] {
        let request: NSFetchRequest<BudgetTransactionEntity> = BudgetTransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching transactions by date range: \(error)")
            return []
        }
    }

    // MARK: - CRUD Operations

    @discardableResult
    static func create(
        date: Date = Date(),
        amount: Double,
        category: String,
        transactionType: String,
        descriptionText: String? = nil,
        payee: String? = nil,
        notes: String? = nil,
        lineItemID: UUID? = nil,
        vendorID: UUID? = nil,
        in context: NSManagedObjectContext
    ) -> BudgetTransactionEntity {
        let transaction = BudgetTransactionEntity(context: context)
        transaction.id = UUID()
        transaction.date = date
        transaction.amount = amount
        transaction.category = category
        transaction.transactionType = transactionType
        transaction.descriptionText = descriptionText
        transaction.payee = payee
        transaction.notes = notes
        transaction.lineItemID = lineItemID
        transaction.vendorID = vendorID
        transaction.createdAt = Date()
        transaction.updatedAt = Date()

        do {
            try context.save()
        } catch {
            print("Error creating budget transaction: \(error)")
        }

        return transaction
    }

    func update(
        date: Date? = nil,
        amount: Double? = nil,
        category: String? = nil,
        transactionType: String? = nil,
        descriptionText: String? = nil,
        payee: String? = nil,
        notes: String? = nil,
        lineItemID: UUID? = nil,
        vendorID: UUID? = nil
    ) {
        if let date = date { self.date = date }
        if let amount = amount { self.amount = amount }
        if let category = category { self.category = category }
        if let transactionType = transactionType { self.transactionType = transactionType }
        if let descriptionText = descriptionText { self.descriptionText = descriptionText }
        if let payee = payee { self.payee = payee }
        if let notes = notes { self.notes = notes }
        if let lineItemID = lineItemID { self.lineItemID = lineItemID }
        if let vendorID = vendorID { self.vendorID = vendorID }

        self.updatedAt = Date()

        do {
            try managedObjectContext?.save()
        } catch {
            print("Error updating budget transaction: \(error)")
        }
    }

    func delete() {
        guard let context = managedObjectContext else { return }
        context.delete(self)

        do {
            try context.save()
        } catch {
            print("Error deleting budget transaction: \(error)")
        }
    }

    // MARK: - Summary Calculations

    /// Calculate total for transactions
    static func calculateTotal(for transactions: [BudgetTransactionEntity]) -> Double {
        return transactions.reduce(0) { $0 + $1.amount }
    }

    /// Calculate total by category
    static func calculateTotalByCategory(in context: NSManagedObjectContext) -> [String: Double] {
        let transactions = fetchAll(in: context)
        var totals: [String: Double] = [:]

        for transaction in transactions {
            if let category = transaction.category {
                totals[category, default: 0] += transaction.amount
            }
        }

        return totals
    }
}
