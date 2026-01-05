import Foundation
import CoreData

@objc public enum ShootDayType: Int16 {
    case shoot = 1
    case off = 2

    public var label: String {
        switch self {
        case .shoot: return "Shoot Day"
        case .off:   return "Day Off"
        }
    }
}

public extension ShootDayEntity {
    // Optional convenience request with default sorting (does not shadow the auto-generated fetchRequest())
    @nonobjc class func sortedFetchRequest() -> NSFetchRequest<ShootDayEntity> {
        let req = NSFetchRequest<ShootDayEntity>(entityName: "ShootDayEntity")
        req.sortDescriptors = [
            NSSortDescriptor(key: "dayNumber", ascending: true),
            NSSortDescriptor(key: "date", ascending: true)
        ]
        return req
    }

    var type: ShootDayType {
        get { ShootDayType(rawValue: typeRaw) ?? .shoot }
        set { typeRaw = newValue.rawValue }
    }

    override func willSave() {
        super.willSave()
        if createdAt == nil { createdAt = Date() }
        updatedAt = Date()
    }
}

public extension ShootDayEntity {
    static func nextDayNumber(in context: NSManagedObjectContext, project: ProjectEntity) -> Int32 {
        let req: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
        req.predicate = NSPredicate(format: "project == %@", project)
        req.sortDescriptors = [NSSortDescriptor(key: "dayNumber", ascending: false)]
        req.fetchLimit = 1
        let maxNum = (try? context.fetch(req).first?.dayNumber) ?? 0
        return maxNum + 1
    }

    static func reindexDays(in context: NSManagedObjectContext, project: ProjectEntity) {
        let req: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
        req.predicate = NSPredicate(format: "project == %@", project)
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true),
                               NSSortDescriptor(key: "dayNumber", ascending: true)]
        if let days = try? context.fetch(req) {
            var n: Int32 = 1
            for d in days {
                d.dayNumber = n
                n += 1
            }
        }
    }
}
