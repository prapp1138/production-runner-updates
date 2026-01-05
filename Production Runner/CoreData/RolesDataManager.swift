//
//  RolesDataManager.swift
//  Production Runner
//
//  Created by Editing on 11/24/25.
//

import CoreData
import Foundation

class RolesDataManager {

    static func loadDefaultRoles(context: NSManagedObjectContext) {
        // Check if roles already exist
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "RoleEntity")
        fetchRequest.fetchLimit = 1

        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                // Roles already loaded
                return
            }
        } catch {
            print("Error checking existing roles: \(error)")
        }

        // Define all roles with their categories and sort orders
        let rolesData: [(category: String, roles: [String])] = [
            ("⚡ Above-the-Line", [
                "Producer", "Executive Producer", "Co-Producer", "Associate Producer", "Line Producer",
                "Unit Production Manager (UPM)", "Director", "Assistant Director (1st AD)", "2nd Assistant Director",
                "2nd 2nd Assistant Director", "Assistant to Director", "Screenwriter", "Story Editor",
                "Showrunner (TV)", "Lead Cast / Principal Cast", "Supporting Cast", "Cameo Talent",
                "Background Actors / Extras", "Stunt Performers", "Stunt Coordinator", "Fight Choreographer",
                "Intimacy Coordinator"
            ]),
            ("📋 Production Department - Management", [
                "Production Supervisor", "Production Coordinator", "Assistant Production Coordinator",
                "Production Secretary", "Writers' Assistant", "Script Supervisor", "Production Accountant",
                "Assistant Accountant / Payroll Accountant", "Office PA", "Set PA", "Key PA"
            ]),
            ("📋 Production Department - Locations", [
                "Location Manager", "Assistant Location Manager", "Location Scout", "Location Assistant",
                "Location PA"
            ]),
            ("📋 Production Department - Casting", [
                "Casting Director", "Casting Associate", "Casting Assistant", "Extras Casting Director",
                "Extras Casting Assistant"
            ]),
            ("📚 Art Department - Direction", [
                "Production Designer", "Art Director", "Assistant Art Director", "Art Department Coordinator",
                "Art Department PA", "Illustrator", "Concept Artist", "Graphic Designer", "Matte Painter"
            ]),
            ("📚 Art Department - Set Decoration", [
                "Set Decorator", "Assistant Set Decorator", "Set Dec Buyer", "Set Dec Coordinator",
                "Leadman / Lead Person", "Set Dresser", "On-Set Dresser"
            ]),
            ("📚 Art Department - Construction", [
                "Construction Coordinator", "Construction Foreman", "Carpenter", "Scenic Carpenter",
                "Painter", "Scenic Painter", "Plasterer", "Rigger", "Laborer"
            ]),
            ("📚 Art Department - Props", [
                "Prop Master", "Assistant Prop Master", "Props Buyer", "Props Maker / Fabricator",
                "Weapons Wrangler / Armorer", "Props Assistant", "On-Set Props"
            ]),
            ("🎥 Camera Department", [
                "Director of Photography (DP / Cinematographer)", "Camera Operator", "A-Camera Operator",
                "B-Camera Operator", "C-Camera Operator", "Steadicam Operator", "Drone Operator / UAV Pilot",
                "1st AC (Focus Puller)", "2nd AC (Clapper Loader)", "Digital Loader / DIT Assistant",
                "DIT (Digital Imaging Technician)", "Camera PA"
            ]),
            ("💡 Grip Department", [
                "Key Grip", "Best Boy Grip", "Dolly Grip", "Rigging Grip", "Construction Grip",
                "Set Grip", "Grip Trainee"
            ]),
            ("💡 Electric Department", [
                "Gaffer (Chief Lighting Technician)", "Best Boy Electric", "Electrician / Lighting Technician",
                "Rigging Electric", "Generator Operator (Genny Op)"
            ]),
            ("🔈 Sound Department", [
                "Production Sound Mixer", "Boom Operator", "Utility Sound Technician", "Sound Assistant"
            ]),
            ("👗 Costume / Wardrobe", [
                "Costume Designer", "Assistant Costume Designer", "Costume Supervisor", "Set Costumer",
                "Costume Maker / Tailor", "Cutter / Fitter", "Wardrobe Assistant", "Costume PA"
            ]),
            ("💄 Hair & Makeup", [
                "Key Hair Stylist", "Key Makeup Artist", "Special Effects Makeup Artist", "Hair Assistant",
                "Makeup Assistant", "Barber", "Prosthetics Technician"
            ]),
            ("🎞 Specialty - SFX", [
                "Special Effects Supervisor", "Special Effects Coordinator", "SFX Technician",
                "Pyrotechnician"
            ]),
            ("🎞 Specialty - VFX", [
                "VFX Supervisor", "On-Set VFX Supervisor", "Data Wrangler", "Motion Capture Supervisor",
                "Mo-Cap Actor", "VFX Coordinator", "VFX PA"
            ]),
            ("🎞 Specialty - Animals", [
                "Animal Wrangler", "Animal Trainer", "Humane Officer"
            ]),
            ("🎞 Specialty - Vehicles", [
                "Picture Car Coordinator", "Picture Vehicle Mechanic", "Precision Driver"
            ]),
            ("🎞 Specialty - Weapons", [
                "Armorer", "Weapons Wrangler"
            ]),
            ("🎤 Talent Support", [
                "Talent Wrangler", "Stand-Ins", "Photo Double", "Stunt Double", "Body Double"
            ]),
            ("🚚 Transportation", [
                "Transportation Captain", "Transportation Coordinator", "Driver (Cast Driver, Crew Driver)",
                "Shuttle Driver", "Teamster"
            ]),
            ("🎨 Crafts - Script", [
                "Script Supervisor", "Script Coordinator"
            ]),
            ("🎨 Crafts - Services", [
                "Craft Services Lead", "Craft Truck Operator", "Chef", "Sous Chef", "Catering Assistant"
            ]),
            ("🏥 Health / Safety", [
                "Set Medic", "COVID Compliance Officer", "Safety Supervisor", "Fire Safety Officer",
                "Environmental Health Officer"
            ]),
            ("⛓ Unit & Support", [
                "Unit Manager", "Unit Assistant", "Base Camp Manager", "Honeywagon Operator"
            ]),
            ("📡 Post-Production - Editorial", [
                "Editor", "Assistant Editor", "Post Supervisor", "Post Coordinator", "Dailies Colorist",
                "Dailies Technician"
            ]),
            ("📡 Post-Production - Sound", [
                "Sound Designer", "Sound Editor", "Dialogue Editor", "Foley Artist", "Foley Recordist",
                "ADR Supervisor", "ADR Recordist", "Re-Recording Mixer"
            ]),
            ("📡 Post-Production - Picture", [
                "Colorist", "Online Editor", "Conform Editor", "DI Producer", "DI Technician"
            ]),
            ("📡 Post-Production - VFX", [
                "VFX Producer", "VFX Supervisor", "VFX Artist (Compositor, Modeler, Animator, TD, Roto/Paint, etc.)",
                "VFX Editor"
            ]),
            ("📡 Post-Production - Music", [
                "Composer", "Music Supervisor", "Music Editor", "Orchestrator", "Scoring Mixer",
                "Soundtrack Producer"
            ]),
            ("🎤 Marketing / Distribution", [
                "EPK Director", "EPK Camera Operator", "EPK Producer", "BTS Photographer", "BTS Videographer",
                "Unit Publicist", "Social Media Producer", "Trailer Editor", "Marketing Coordinator"
            ]),
            ("🧰 Miscellaneous", [
                "Greensman / Greens Department", "Marine Coordinator", "Aerial Coordinator", "Drones Team",
                "Fire Safety Team", "Security Coordinator", "Security Guard", "Teacher / Studio Teacher (for minors)",
                "Tutor", "Studio Liaison", "Insurance Coordinator", "Legal Counsel"
            ])
        ]

        // Insert all roles
        var sortOrder: Int16 = 0
        for (category, roles) in rolesData {
            for roleName in roles {
                let role = NSEntityDescription.insertNewObject(forEntityName: "RoleEntity", into: context)
                role.setValue(UUID(), forKey: "id")
                role.setValue(roleName, forKey: "name")
                role.setValue(category, forKey: "category")
                role.setValue(sortOrder, forKey: "sortOrder")
                role.setValue(false, forKey: "isCustom")
                role.setValue(true, forKey: "isDefault")
                role.setValue(Date(), forKey: "createdAt")
                sortOrder += 1
            }
        }

        // Save context
        do {
            try context.save()
            print("Successfully loaded \(sortOrder) default roles")
        } catch {
            print("Error saving default roles: \(error)")
        }
    }

    static func fetchAllRoles(context: NSManagedObjectContext) -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "RoleEntity")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "category", ascending: true),
            NSSortDescriptor(key: "sortOrder", ascending: true)
        ]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching roles: \(error)")
            return []
        }
    }

    static func fetchRolesByCategory(context: NSManagedObjectContext) -> [String: [NSManagedObject]] {
        let roles = fetchAllRoles(context: context)
        var grouped: [String: [NSManagedObject]] = [:]

        for role in roles {
            if let category = role.value(forKey: "category") as? String {
                if grouped[category] == nil {
                    grouped[category] = []
                }
                grouped[category]?.append(role)
            }
        }

        return grouped
    }

    static func addCustomRole(name: String, category: String, context: NSManagedObjectContext) {
        let role = NSEntityDescription.insertNewObject(forEntityName: "RoleEntity", into: context)
        role.setValue(UUID(), forKey: "id")
        role.setValue(name, forKey: "name")
        role.setValue(category, forKey: "category")
        role.setValue(999, forKey: "sortOrder") // Custom roles at end
        role.setValue(true, forKey: "isCustom")
        role.setValue(false, forKey: "isDefault")
        role.setValue(Date(), forKey: "createdAt")

        do {
            try context.save()
        } catch {
            print("Error saving custom role: \(error)")
        }
    }
}
