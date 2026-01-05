import Foundation
import CoreData

// Extension for RateCardEntity (CoreData generates the class automatically)
extension RateCardEntity {
    
    // Convenience computed properties
    var displayName: String {
        name ?? "Untitled Rate Card"
    }
    
    var categoryType: String {
        category ?? "General"
    }
    
    var formattedRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: defaultRate)) ?? "$0.00"
    }
    
    // Fetch all rate cards
    static func fetchAll(in context: NSManagedObjectContext) -> [RateCardEntity] {
        let request: NSFetchRequest<RateCardEntity> = RateCardEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "category", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching rate cards: \(error)")
            return []
        }
    }
    
    // Fetch rate cards by category
    static func fetch(category: String, in context: NSManagedObjectContext) -> [RateCardEntity] {
        let request: NSFetchRequest<RateCardEntity> = RateCardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching rate cards by category: \(error)")
            return []
        }
    }
    
    // Create a new rate card
    static func create(
        name: String,
        category: String,
        defaultUnit: String,
        defaultRate: Double,
        notes: String = "",
        in context: NSManagedObjectContext
    ) -> RateCardEntity {
        let rateCard = RateCardEntity(context: context)
        rateCard.id = UUID()
        rateCard.name = name
        rateCard.category = category
        rateCard.defaultUnit = defaultUnit
        rateCard.defaultRate = defaultRate
        rateCard.notes = notes
        
        do {
            try context.save()
        } catch {
            print("Error creating rate card: \(error)")
        }
        
        return rateCard
    }
    
    // Update rate card
    func update(
        name: String? = nil,
        category: String? = nil,
        defaultUnit: String? = nil,
        defaultRate: Double? = nil,
        notes: String? = nil
    ) {
        if let name = name { self.name = name }
        if let category = category { self.category = category }
        if let defaultUnit = defaultUnit { self.defaultUnit = defaultUnit }
        if let defaultRate = defaultRate { self.defaultRate = defaultRate }
        if let notes = notes { self.notes = notes }
        
        if let context = self.managedObjectContext {
            do {
                try context.save()
            } catch {
                print("Error updating rate card: \(error)")
            }
        }
    }
    
    // Delete rate card
    func delete() {
        guard let context = managedObjectContext else { return }
        context.delete(self)
        
        do {
            try context.save()
        } catch {
            print("Error deleting rate card: \(error)")
        }
    }
}
