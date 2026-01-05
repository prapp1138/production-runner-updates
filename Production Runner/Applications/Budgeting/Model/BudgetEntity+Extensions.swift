import Foundation
import CoreData

// Extension for BudgetEntity (CoreData auto-generates the class)
extension BudgetEntity {
    
    // MARK: - Helper Properties
    
    var lineItemsArray: [BudgetLineItemEntity] {
        let set = lineItems as? Set<BudgetLineItemEntity> ?? []
        return set.sorted { $0.order < $1.order }
    }
    
    var displayName: String {
        return "\(name ?? "") v\(version ?? "")"
    }
    
    // MARK: - CRUD Operations
    
    @discardableResult
    static func create(
        name: String,
        version: String = "1.0",
        notes: String? = nil,
        in context: NSManagedObjectContext
    ) -> BudgetEntity {
        let budget = BudgetEntity(context: context)
        budget.id = UUID()
        budget.name = name
        budget.version = version
        budget.createdDate = Date()
        budget.modifiedDate = Date()
        budget.totalAmount = 0
        budget.notes = notes
        
        do {
            try context.save()
        } catch {
            print("Error creating budget: \(error)")
        }
        
        return budget
    }
    
    static func fetchAll(in context: NSManagedObjectContext) -> [BudgetEntity] {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \BudgetEntity.modifiedDate, ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching budgets: \(error)")
            return []
        }
    }
    
    static func fetch(byID id: UUID, in context: NSManagedObjectContext) -> BudgetEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching budget: \(error)")
            return nil
        }
    }
    
    func update(name: String? = nil, version: String? = nil, notes: String? = nil) {
        if let name = name { self.name = name }
        if let version = version { self.version = version }
        if let notes = notes { self.notes = notes }
        self.modifiedDate = Date()
        
        do {
            try managedObjectContext?.save()
        } catch {
            print("Error updating budget: \(error)")
        }
    }
    
    func delete() {
        guard let context = managedObjectContext else { return }
        context.delete(self)
        
        do {
            try context.save()
        } catch {
            print("Error deleting budget: \(error)")
        }
    }
    
    func duplicate(as newName: String? = nil) -> BudgetEntity? {
        guard let context = managedObjectContext else { return nil }
        
        let duplicateName = newName ?? "\(name ?? "") Copy"
        let duplicate = BudgetEntity.create(
            name: duplicateName,
            version: version ?? "1.0",
            notes: notes,
            in: context
        )
        
        // Copy all line items
        for item in lineItemsArray {
            let newItem = BudgetLineItemEntity.create(
                name: item.name ?? "",
                category: item.category ?? "",
                subcategory: item.subcategory,
                section: item.section,
                quantity: item.quantity,
                unitCost: item.unitCost,
                notes: item.notes,
                in: context
            )
            duplicate.addToLineItems(newItem)
        }
        
        duplicate.recalculateTotal()
        
        return duplicate
    }
    
    func recalculateTotal() {
        totalAmount = lineItemsArray.reduce(0) { $0 + $1.total }
        modifiedDate = Date()
        
        do {
            try managedObjectContext?.save()
        } catch {
            print("Error recalculating total: \(error)")
        }
    }
}
