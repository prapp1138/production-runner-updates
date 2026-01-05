
import Foundation
import CoreData

extension ProjectEntity {
    func createShootDay(type: ShootDayType = .shoot,
                        date: Date? = nil,
                        notes: String? = nil,
                        in context: NSManagedObjectContext) -> ShootDayEntity {
        let day = ShootDayEntity(context: context)
        day.id = UUID()
        day.project = self
        day.dayNumber = ShootDayEntity.nextDayNumber(in: context, project: self)
        day.type = type
        day.date = date
        day.notes = notes
        day.createdAt = Date()
        day.updatedAt = Date()
        return day
    }
}
