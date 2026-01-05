import Foundation
import CoreData

// BudgetLineItemEntity extension for additional functionality
extension BudgetLineItemEntity {
    
    // Convenience computed properties
    var displayName: String {
        name ?? "Untitled Item"
    }
    
    var total: Double {
        quantity * days * unitCost
    }
    
    // MARK: - Fetch Requests
    
    // Fetch all items for a budget
    static func fetchAll(in context: NSManagedObjectContext) -> [BudgetLineItemEntity] {
        let request: NSFetchRequest<BudgetLineItemEntity> = BudgetLineItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching budget line items: \(error)")
            return []
        }
    }
    
    // Fetch items by category
    static func fetch(category: String, in context: NSManagedObjectContext) -> [BudgetLineItemEntity] {
        let request: NSFetchRequest<BudgetLineItemEntity> = BudgetLineItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching budget items by category: \(error)")
            return []
        }
    }
    
    // MARK: - CRUD Operations
    
    @discardableResult
    static func create(
        name: String,
        account: String = "",
        category: String,
        subcategory: String? = nil,
        section: String? = nil,
        quantity: Double = 1.0,
        days: Double = 1.0,
        unitCost: Double = 0.0,
        notes: String? = nil,
        order: Int16 = 0,
        in context: NSManagedObjectContext
    ) -> BudgetLineItemEntity {
        let item = BudgetLineItemEntity(context: context)
        item.id = UUID()
        item.name = name
        item.account = account
        item.category = category
        item.subcategory = subcategory
        item.section = section
        item.quantity = quantity
        item.days = days
        item.unitCost = unitCost
        item.notes = notes
        item.order = order
        item.isLinkedToRateCard = false
        item.createdAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Error creating budget line item: \(error)")
        }
        
        return item
    }
    
    func update(
        name: String? = nil,
        account: String? = nil,
        category: String? = nil,
        subcategory: String? = nil,
        quantity: Double? = nil,
        days: Double? = nil,
        unitCost: Double? = nil,
        notes: String? = nil
    ) {
        if let name = name { self.name = name }
        if let account = account { self.account = account }
        if let category = category { self.category = category }
        if let subcategory = subcategory { self.subcategory = subcategory }
        if let quantity = quantity { self.quantity = quantity }
        if let days = days { self.days = days }
        if let unitCost = unitCost { self.unitCost = unitCost }
        if let notes = notes { self.notes = notes }
        
        do {
            try managedObjectContext?.save()
            // Update parent budget's total
            budget?.recalculateTotal()
        } catch {
            print("Error updating budget line item: \(error)")
        }
    }
    
    func delete() {
        guard let context = managedObjectContext else { return }
        let parentBudget = budget
        context.delete(self)
        
        do {
            try context.save()
            // Update parent budget's total
            parentBudget?.recalculateTotal()
        } catch {
            print("Error deleting budget line item: \(error)")
        }
    }
}
