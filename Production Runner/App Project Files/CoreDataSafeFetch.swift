import CoreData
protocol EntityNamed { static var entityName: String { get } }
extension NSManagedObject: EntityNamed { public static var entityName: String { String(describing: Self.self) } }
extension NSManagedObjectContext { public func makeFetchRequest<T: NSManagedObject>(_ type: T.Type) -> NSFetchRequest<T> { NSFetchRequest<T>(entityName: T.entityName) } }
