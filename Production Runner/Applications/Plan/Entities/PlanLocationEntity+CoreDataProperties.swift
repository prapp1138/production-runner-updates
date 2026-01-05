import Foundation
import CoreData

extension PlanLocationEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanLocationEntity> {
        return NSFetchRequest<PlanLocationEntity>(entityName: "PlanLocationEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var address: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var notes: String?
    @NSManaged public var contactName: String?
    @NSManaged public var contactPhone: String?
    @NSManaged public var contactEmail: String?
    @NSManaged public var dailyRate: Double
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var section: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var additionalImagesData: Data?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension PlanLocationEntity: Identifiable {
}
