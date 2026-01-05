import Foundation
import CoreData

extension PlanScheduleItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanScheduleItemEntity> {
        return NSFetchRequest<PlanScheduleItemEntity>(entityName: "PlanScheduleItemEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var isAllDay: Bool
    @NSManaged public var category: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var notes: String?
    @NSManaged public var locationID: UUID?
    @NSManaged public var assignedActorIDs: String?
    @NSManaged public var assignedCrewIDs: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension PlanScheduleItemEntity: Identifiable {
}
