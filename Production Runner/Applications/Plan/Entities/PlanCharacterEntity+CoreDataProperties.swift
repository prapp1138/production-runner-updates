import Foundation
import CoreData

extension PlanCharacterEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanCharacterEntity> {
        return NSFetchRequest<PlanCharacterEntity>(entityName: "PlanCharacterEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var castID: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var age: String?
    @NSManaged public var gender: String?
    @NSManaged public var traits: String?
    @NSManaged public var notes: String?
    @NSManaged public var sceneNumbers: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension PlanCharacterEntity: Identifiable {
}
