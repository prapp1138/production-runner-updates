import Foundation
import CoreData

extension ShotEntity {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        // Set id if the attribute exists and is nil
        if entity.attributesByName.keys.contains("id"), value(forKey: "id") == nil {
            setValue(UUID(), forKey: "id")
        }
        // createdAt / updatedAt if present in the model
        if entity.attributesByName.keys.contains("createdAt"), value(forKey: "createdAt") == nil {
            setValue(Date(), forKey: "createdAt")
        }
        if entity.attributesByName.keys.contains("updatedAt") {
            setValue(Date(), forKey: "updatedAt")
        }
    }

    public override func willSave() {
        super.willSave()
        if hasChanges, entity.attributesByName.keys.contains("updatedAt") {
            setValue(Date(), forKey: "updatedAt")
        }
    }
}
