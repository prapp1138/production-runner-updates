import Foundation
import CoreData

extension PlanBudgetItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanBudgetItemEntity> {
        return NSFetchRequest<PlanBudgetItemEntity>(entityName: "PlanBudgetItemEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var subcategory: String?
    @NSManaged public var estimatedAmount: Double
    @NSManaged public var actualAmount: Double
    @NSManaged public var notes: String?
    @NSManaged public var vendorName: String?
    @NSManaged public var isPaid: Bool
    @NSManaged public var dueDate: Date?
    @NSManaged public var paidDate: Date?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension PlanBudgetItemEntity: Identifiable {
}
