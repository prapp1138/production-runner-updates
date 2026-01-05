//
//  IdeaSectionEntity+CoreDataProperties.swift
//  Production Runner
//

import Foundation
import CoreData

extension IdeaSectionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<IdeaSectionEntity> {
        return NSFetchRequest<IdeaSectionEntity>(entityName: "IdeaSectionEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var isExpanded: Bool
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var notes: NSSet?

}

// MARK: Generated accessors for notes
extension IdeaSectionEntity {

    @objc(addNotesObject:)
    @NSManaged public func addToNotes(_ value: IdeaNoteEntity)

    @objc(removeNotesObject:)
    @NSManaged public func removeFromNotes(_ value: IdeaNoteEntity)

    @objc(addNotes:)
    @NSManaged public func addToNotes(_ values: NSSet)

    @objc(removeNotes:)
    @NSManaged public func removeFromNotes(_ values: NSSet)

}

extension IdeaSectionEntity: Identifiable {

}
