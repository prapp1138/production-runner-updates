
import Foundation
import CoreData

extension SceneEntity {
    func assign(to day: ShootDayEntity?, in context: NSManagedObjectContext) {
        self.shootDay = day
    }
}
