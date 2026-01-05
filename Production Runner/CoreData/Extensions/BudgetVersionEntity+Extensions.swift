//
//  BudgetVersionEntity+Extensions.swift
//  Production Runner
//
//  Created by Claude Code on 2026-01-05.
//  Extensions for BudgetVersionEntity Core Data entity
//

import Foundation
import CoreData

extension BudgetVersionEntity {

    /// Convert Core Data entity to model struct
    func toModel() -> BudgetVersion {
        var lineItems: [BudgetLineItem] = []
        var transactions: [BudgetTransaction] = []
        var payrollItems: [PayrollLineItem] = []

        // Deserialize line items from JSON
        if let json = lineItemsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([BudgetLineItem].self, from: data) {
            lineItems = decoded
        }

        // Deserialize transactions from JSON
        if let json = transactionsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([BudgetTransaction].self, from: data) {
            transactions = decoded
        }

        // Deserialize payroll items from JSON
        if let json = payrollItemsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([PayrollLineItem].self, from: data) {
            payrollItems = decoded
        }

        return BudgetVersion(
            id: id ?? UUID(),
            name: name ?? "Untitled",
            createdDate: createdDate ?? Date(),
            lineItems: lineItems,
            transactions: transactions,
            payrollItems: payrollItems,
            isLocked: isLocked,
            lockedAt: lockedAt,
            lockedBy: lockedBy,
            currency: currency ?? "USD",
            notes: notes ?? ""
        )
    }

    /// Update entity from model struct
    func update(from model: BudgetVersion) throws {
        self.id = model.id
        self.name = model.name
        self.createdDate = model.createdDate
        self.isLocked = model.isLocked
        self.lockedAt = model.lockedAt
        self.lockedBy = model.lockedBy
        self.currency = model.currency
        self.notes = model.notes

        // Serialize line items to JSON
        if let data = try? JSONEncoder().encode(model.lineItems),
           let json = String(data: data, encoding: .utf8) {
            self.lineItemsJSON = json
        } else {
            print("[BudgetVersionEntity] ⚠️ Failed to encode line items for version '\(model.name)'")
        }

        // Serialize transactions to JSON
        if let data = try? JSONEncoder().encode(model.transactions),
           let json = String(data: data, encoding: .utf8) {
            self.transactionsJSON = json
        } else {
            print("[BudgetVersionEntity] ⚠️ Failed to encode transactions for version '\(model.name)'")
        }

        // Serialize payroll items to JSON
        if let data = try? JSONEncoder().encode(model.payrollItems),
           let json = String(data: data, encoding: .utf8) {
            self.payrollItemsJSON = json
        } else {
            print("[BudgetVersionEntity] ⚠️ Failed to encode payroll items for version '\(model.name)'")
        }
    }

    /// Create new entity from model
    static func create(from model: BudgetVersion, in context: NSManagedObjectContext) throws -> BudgetVersionEntity {
        let entity = BudgetVersionEntity(context: context)
        try entity.update(from: model)
        return entity
    }

    /// Convenience method to get all versions sorted by creation date
    static func fetchAllVersions(in context: NSManagedObjectContext) throws -> [BudgetVersionEntity] {
        let fetchRequest: NSFetchRequest<BudgetVersionEntity> = BudgetVersionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        return try context.fetch(fetchRequest)
    }

    /// Fetch versions for a specific project
    static func fetchVersions(for projectID: UUID, in context: NSManagedObjectContext) throws -> [BudgetVersionEntity] {
        let fetchRequest: NSFetchRequest<BudgetVersionEntity> = BudgetVersionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "project.id == %@", projectID as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        return try context.fetch(fetchRequest)
    }
}
