//
//  IdeaNoteEntity+CoreDataProperties.swift
//  Production Runner
//

import Foundation
import CoreData

extension IdeaNoteEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<IdeaNoteEntity> {
        return NSFetchRequest<IdeaNoteEntity>(entityName: "IdeaNoteEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var section: IdeaSectionEntity?

}

extension IdeaNoteEntity: Identifiable {

}
