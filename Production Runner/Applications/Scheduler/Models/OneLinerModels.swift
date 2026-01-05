//
//  OneLinerModels.swift
//  Production Runner
//
//  Models for One-Liner Schedule reports.
//  A condensed schedule format showing one line per scene, grouped by shoot day.
//

import Foundation
import CoreData

// MARK: - One-Liner Schedule Item

/// Represents a single scene in the one-liner schedule
public struct OneLinerItem: Identifiable, Codable {
    public let id: UUID
    public let sceneNumber: String
    public let intExt: String           // INT, EXT, or I/E
    public let setDescription: String   // Location/set name
    public let dayNight: String         // DAY, NIGHT, DAWN, DUSK
    public let pages: String            // Page count as eighths (e.g., "1 2/8")
    public let pageEighths: Int         // Raw eighths for calculations
    public let cast: String             // Comma-separated cast IDs
    public let location: String         // Shooting location
    public let notes: String?           // Optional notes

    public init(
        id: UUID = UUID(),
        sceneNumber: String,
        intExt: String,
        setDescription: String,
        dayNight: String,
        pages: String,
        pageEighths: Int,
        cast: String,
        location: String,
        notes: String? = nil
    ) {
        self.id = id
        self.sceneNumber = sceneNumber
        self.intExt = intExt
        self.setDescription = setDescription
        self.dayNight = dayNight
        self.pages = pages
        self.pageEighths = pageEighths
        self.cast = cast
        self.location = location
        self.notes = notes
    }

    /// Create from a scene managed object
    public static func from(scene: NSManagedObject) -> OneLinerItem? {
        // Get scene number
        guard let number = scene.value(forKey: "number") as? String ?? scene.value(forKey: "sceneNumber") as? String else {
            return nil
        }

        // Parse scene heading for INT/EXT and location
        let heading = scene.value(forKey: "sceneSlug") as? String
            ?? scene.value(forKey: "sceneHeading") as? String
            ?? scene.value(forKey: "heading") as? String
            ?? ""

        let (intExt, setDesc) = parseHeading(heading)

        // Get time of day
        let timeOfDay = scene.value(forKey: "timeOfDay") as? String ?? ""

        // Get page eighths
        let eighths = (scene.value(forKey: "pageEighths") as? Int16).map(Int.init) ?? 0
        let pagesStr = formatPageEighths(eighths)

        // Get cast IDs
        let castIDs = scene.value(forKey: "castIDs") as? String ?? ""

        // Get location
        let location = scene.value(forKey: "scriptLocation") as? String ?? ""

        // Get notes from breakdown if available
        var notes: String? = nil
        if let breakdown = scene.value(forKey: "breakdown") as? NSManagedObject {
            notes = breakdown.value(forKey: "notes") as? String
        }

        return OneLinerItem(
            sceneNumber: number,
            intExt: intExt,
            setDescription: setDesc.isEmpty ? location : setDesc,
            dayNight: timeOfDay.uppercased(),
            pages: pagesStr,
            pageEighths: eighths,
            cast: castIDs,
            location: location,
            notes: notes
        )
    }

    /// Parse heading like "INT. KITCHEN - DAY" into components
    private static func parseHeading(_ heading: String) -> (intExt: String, setDescription: String) {
        let upper = heading.uppercased().trimmingCharacters(in: .whitespaces)

        var intExt = ""
        var remaining = upper

        // Check for INT/EXT patterns
        if upper.hasPrefix("INT./EXT.") || upper.hasPrefix("INT/EXT") || upper.hasPrefix("I/E") {
            intExt = "I/E"
            if upper.hasPrefix("INT./EXT.") {
                remaining = String(upper.dropFirst(9))
            } else if upper.hasPrefix("INT/EXT") {
                remaining = String(upper.dropFirst(7))
            } else {
                remaining = String(upper.dropFirst(3))
            }
        } else if upper.hasPrefix("INT.") || upper.hasPrefix("INT ") {
            intExt = "INT"
            remaining = String(upper.dropFirst(4))
        } else if upper.hasPrefix("EXT.") || upper.hasPrefix("EXT ") {
            intExt = "EXT"
            remaining = String(upper.dropFirst(4))
        }

        // Remove time of day from end
        remaining = remaining
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " - DAY", with: "")
            .replacingOccurrences(of: " - NIGHT", with: "")
            .replacingOccurrences(of: " - DAWN", with: "")
            .replacingOccurrences(of: " - DUSK", with: "")
            .replacingOccurrences(of: " - LATER", with: "")
            .replacingOccurrences(of: " - CONTINUOUS", with: "")
            .replacingOccurrences(of: " - MOMENTS LATER", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove leading dash or period
        if remaining.hasPrefix("-") || remaining.hasPrefix(".") {
            remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        return (intExt, remaining)
    }

    /// Format page eighths as string (e.g., 10 -> "1 2/8")
    private static func formatPageEighths(_ eighths: Int) -> String {
        if eighths == 0 { return "0" }

        let wholePages = eighths / 8
        let remainingEighths = eighths % 8

        if wholePages > 0 && remainingEighths > 0 {
            return "\(wholePages) \(remainingEighths)/8"
        } else if wholePages > 0 {
            return "\(wholePages)"
        } else {
            return "\(remainingEighths)/8"
        }
    }
}

// MARK: - One-Liner Shoot Day

/// Represents a shoot day with its scenes
public struct OneLinerDay: Identifiable, Codable {
    public let id: UUID
    public let dayNumber: Int
    public let date: Date
    public var items: [OneLinerItem]

    public init(id: UUID = UUID(), dayNumber: Int, date: Date, items: [OneLinerItem] = []) {
        self.id = id
        self.dayNumber = dayNumber
        self.date = date
        self.items = items
    }

    /// Total page eighths for this day
    public var totalPageEighths: Int {
        items.reduce(0) { $0 + $1.pageEighths }
    }

    /// Formatted total pages string
    public var totalPagesString: String {
        let eighths = totalPageEighths
        if eighths == 0 { return "0" }

        let wholePages = eighths / 8
        let remainingEighths = eighths % 8

        if wholePages > 0 && remainingEighths > 0 {
            return "\(wholePages) \(remainingEighths)/8 pgs"
        } else if wholePages > 0 {
            return "\(wholePages) pgs"
        } else {
            return "\(remainingEighths)/8 pgs"
        }
    }

    /// Scene count for this day
    public var sceneCount: Int {
        items.count
    }
}

// MARK: - One-Liner Schedule

/// Complete one-liner schedule for a production
public struct OneLinerSchedule: Codable {
    public let productionName: String
    public var days: [OneLinerDay]
    public let generatedDate: Date

    public init(productionName: String, days: [OneLinerDay] = [], generatedDate: Date = Date()) {
        self.productionName = productionName
        self.days = days
        self.generatedDate = generatedDate
    }

    /// Total scenes across all days
    public var totalScenes: Int {
        days.reduce(0) { $0 + $1.sceneCount }
    }

    /// Total page eighths across all days
    public var totalPageEighths: Int {
        days.reduce(0) { $0 + $1.totalPageEighths }
    }

    /// Formatted total pages string
    public var totalPagesString: String {
        let eighths = totalPageEighths
        if eighths == 0 { return "0" }

        let wholePages = eighths / 8
        let remainingEighths = eighths % 8

        if wholePages > 0 && remainingEighths > 0 {
            return "\(wholePages) \(remainingEighths)/8"
        } else if wholePages > 0 {
            return "\(wholePages)"
        } else {
            return "\(remainingEighths)/8"
        }
    }

    /// Build a one-liner schedule from stripboard scenes
    public static func build(
        from scenes: [NSManagedObject],
        productionStartDate: Date,
        projectName: String,
        isDayBreak: (NSManagedObject) -> Bool,
        isOffDay: (NSManagedObject) -> Bool
    ) -> OneLinerSchedule {
        var days: [OneLinerDay] = []
        var currentDayNumber = 0
        var currentItems: [OneLinerItem] = []
        var currentDate = productionStartDate

        for scene in scenes {
            if isDayBreak(scene) {
                // Save current day if has items
                if !currentItems.isEmpty || currentDayNumber > 0 {
                    if currentDayNumber == 0 { currentDayNumber = 1 }
                    let day = OneLinerDay(
                        dayNumber: currentDayNumber,
                        date: currentDate,
                        items: currentItems
                    )
                    days.append(day)
                }

                // Start new day
                currentDayNumber += 1
                currentItems = []
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate

            } else if isOffDay(scene) {
                // Skip off days but advance date
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate

            } else {
                // Regular scene - add to current day
                if let item = OneLinerItem.from(scene: scene) {
                    currentItems.append(item)
                }
            }
        }

        // Don't forget the last day (scenes after last day break)
        if !currentItems.isEmpty {
            if currentDayNumber == 0 { currentDayNumber = 1 }
            let day = OneLinerDay(
                dayNumber: currentDayNumber,
                date: currentDate,
                items: currentItems
            )
            days.append(day)
        }

        return OneLinerSchedule(
            productionName: projectName,
            days: days
        )
    }
}
