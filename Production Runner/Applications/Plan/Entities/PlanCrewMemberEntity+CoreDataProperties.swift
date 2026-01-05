//
//  PlanCrewMemberEntity+CoreDataProperties.swift
//  Production Runner
//
//  Auto-generated Core Data entity properties
//

import Foundation
import CoreData

extension PlanCrewMemberEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanCrewMemberEntity> {
        return NSFetchRequest<PlanCrewMemberEntity>(entityName: "PlanCrewMemberEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var role: String?
    @NSManaged public var websiteURL: String?
    @NSManaged public var imdbID: String?
    @NSManaged public var headshotData: Data?
    @NSManaged public var headshotURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var rankNumber: Int16
    @NSManaged public var section: String?
    @NSManaged public var notes: String?
    @NSManaged public var tags: String?
    @NSManaged public var phone: String?
    @NSManaged public var email: String?
    @NSManaged public var agentName: String?
    @NSManaged public var agentPhone: String?
    @NSManaged public var agentEmail: String?
    @NSManaged public var availabilityStart: Date?
    @NSManaged public var availabilityEnd: Date?

}

extension PlanCrewMemberEntity: Identifiable {

}
