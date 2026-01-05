//
//  StripboardSorter.swift
//  Production Runner
//
//  Provides sorting algorithms for the stripboard scheduler.
//  Allows sorting scenes by location, INT/EXT, time of day, page count, and cast.
//

import Foundation
import CoreData

// MARK: - Sort Options

/// Available sorting options for the stripboard
public enum StripboardSortOption: String, CaseIterable, Identifiable {
    case location = "By Location"
    case intExt = "By INT/EXT"
    case timeOfDay = "By Time of Day"
    case pageCount = "By Page Count"
    case cast = "By Cast"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .location: return "mappin.and.ellipse"
        case .intExt: return "rectangle.split.2x1"
        case .timeOfDay: return "sun.and.horizon"
        case .pageCount: return "doc.plaintext"
        case .cast: return "person.2"
        }
    }

    public var description: String {
        switch self {
        case .location: return "Group scenes by shooting location"
        case .intExt: return "Group INT scenes together, then EXT"
        case .timeOfDay: return "Group DAY scenes first, then NIGHT"
        case .pageCount: return "Sort by scene length"
        case .cast: return "Group scenes with similar cast"
        }
    }
}

/// Sort direction
public enum SortDirection: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"

    public var icon: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

// MARK: - Stripboard Sorter

/// Utility class for sorting stripboard scenes
public struct StripboardSorter {

    // MARK: - Main Sort Function

    /// Sort scenes by the specified option and direction
    /// - Parameters:
    ///   - scenes: Array of scene managed objects
    ///   - option: Sort option to use
    ///   - direction: Ascending or descending
    ///   - isDayBreak: Closure to check if a scene is a day break divider
    ///   - isOffDay: Closure to check if a scene is an off day divider
    /// - Returns: Sorted array of scenes with dividers preserved at their relative positions
    public static func sort(
        scenes: [NSManagedObject],
        by option: StripboardSortOption,
        direction: SortDirection = .ascending,
        isDayBreak: (NSManagedObject) -> Bool,
        isOffDay: (NSManagedObject) -> Bool
    ) -> [NSManagedObject] {
        // Separate dividers from regular scenes
        var dividers: [(index: Int, scene: NSManagedObject)] = []
        var regularScenes: [NSManagedObject] = []

        for (index, scene) in scenes.enumerated() {
            if isDayBreak(scene) || isOffDay(scene) {
                dividers.append((index, scene))
            } else {
                regularScenes.append(scene)
            }
        }

        // Sort regular scenes
        let sortedScenes: [NSManagedObject]
        switch option {
        case .location:
            sortedScenes = sortByLocation(regularScenes, direction: direction)
        case .intExt:
            sortedScenes = sortByIntExt(regularScenes, direction: direction)
        case .timeOfDay:
            sortedScenes = sortByTimeOfDay(regularScenes, direction: direction)
        case .pageCount:
            sortedScenes = sortByPageCount(regularScenes, direction: direction)
        case .cast:
            sortedScenes = sortByCast(regularScenes, direction: direction)
        }

        // Re-insert dividers at proportional positions
        return reinsertDividers(sortedScenes: sortedScenes, dividers: dividers, originalCount: scenes.count)
    }

    // MARK: - Sort By Location

    /// Group scenes by shooting location (alphabetically)
    private static func sortByLocation(_ scenes: [NSManagedObject], direction: SortDirection) -> [NSManagedObject] {
        // Group by location
        let grouped = Dictionary(grouping: scenes) { scene -> String in
            getLocation(from: scene).uppercased()
        }

        // Sort groups alphabetically
        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            direction == .ascending ? lhs < rhs : lhs > rhs
        }

        // Flatten back to array, keeping scenes within each location in original order
        return sortedKeys.flatMap { grouped[$0] ?? [] }
    }

    // MARK: - Sort By INT/EXT

    /// Sort scenes by interior/exterior (INT first, then EXT, then I/E)
    private static func sortByIntExt(_ scenes: [NSManagedObject], direction: SortDirection) -> [NSManagedObject] {
        // Define sort order
        let order: [String] = direction == .ascending
            ? ["INT", "EXT", "I/E", ""]
            : ["EXT", "INT", "I/E", ""]

        // Group by INT/EXT
        let grouped = Dictionary(grouping: scenes) { scene -> String in
            getIntExt(from: scene)
        }

        // Flatten in order
        var result: [NSManagedObject] = []
        for key in order {
            if let group = grouped[key] {
                result.append(contentsOf: group)
            }
        }

        // Add any remaining that didn't match
        let knownKeys = Set(order)
        for (key, group) in grouped where !knownKeys.contains(key) {
            result.append(contentsOf: group)
        }

        return result
    }

    // MARK: - Sort By Time of Day

    /// Sort scenes by time of day (DAY first, then NIGHT, then others)
    private static func sortByTimeOfDay(_ scenes: [NSManagedObject], direction: SortDirection) -> [NSManagedObject] {
        // Define sort order
        let order: [String] = direction == .ascending
            ? ["DAY", "NIGHT", "DAWN", "DUSK", "MORNING", "EVENING", "LATER", "CONTINUOUS", ""]
            : ["NIGHT", "DAY", "DUSK", "DAWN", "EVENING", "MORNING", "CONTINUOUS", "LATER", ""]

        // Group by time of day
        let grouped = Dictionary(grouping: scenes) { scene -> String in
            getTimeOfDay(from: scene)
        }

        // Flatten in order
        var result: [NSManagedObject] = []
        for key in order {
            if let group = grouped[key] {
                result.append(contentsOf: group)
            }
        }

        // Add any remaining that didn't match
        let knownKeys = Set(order)
        for (key, group) in grouped where !knownKeys.contains(key) {
            result.append(contentsOf: group)
        }

        return result
    }

    // MARK: - Sort By Page Count

    /// Sort scenes by page length (eighths)
    private static func sortByPageCount(_ scenes: [NSManagedObject], direction: SortDirection) -> [NSManagedObject] {
        return scenes.sorted { lhs, rhs in
            let lhsPages = getPageEighths(from: lhs)
            let rhsPages = getPageEighths(from: rhs)

            return direction == .ascending ? lhsPages < rhsPages : lhsPages > rhsPages
        }
    }

    // MARK: - Sort By Cast

    /// Sort scenes to group those with similar cast together
    /// Uses a greedy algorithm: start with scene with most cast, then add scene that shares most cast
    private static func sortByCast(_ scenes: [NSManagedObject], direction: SortDirection) -> [NSManagedObject] {
        guard !scenes.isEmpty else { return [] }

        var remaining = scenes
        var sorted: [NSManagedObject] = []

        // Start with scene that has the most cast members
        if let firstScene = remaining.max(by: { getCastSet(from: $0).count < getCastSet(from: $1).count }) {
            sorted.append(firstScene)
            remaining.removeAll { $0.objectID == firstScene.objectID }
        }

        // Greedily add scenes that share the most cast with the last added scene
        while !remaining.isEmpty {
            guard let lastScene = sorted.last else { break }
            let lastCast = getCastSet(from: lastScene)

            // Find scene with most overlap
            let nextScene = remaining.max { lhs, rhs in
                let lhsOverlap = getCastSet(from: lhs).intersection(lastCast).count
                let rhsOverlap = getCastSet(from: rhs).intersection(lastCast).count
                return lhsOverlap < rhsOverlap
            }

            if let next = nextScene {
                sorted.append(next)
                remaining.removeAll { $0.objectID == next.objectID }
            } else {
                break
            }
        }

        // Add any remaining scenes
        sorted.append(contentsOf: remaining)

        // Reverse if descending
        return direction == .ascending ? sorted : sorted.reversed()
    }

    // MARK: - Helper Functions

    /// Re-insert dividers at proportional positions in the sorted scenes
    private static func reinsertDividers(
        sortedScenes: [NSManagedObject],
        dividers: [(index: Int, scene: NSManagedObject)],
        originalCount: Int
    ) -> [NSManagedObject] {
        guard !dividers.isEmpty else { return sortedScenes }

        var result = sortedScenes
        let sceneCount = sortedScenes.count

        // Calculate proportional positions for dividers
        for divider in dividers.reversed() {
            // Calculate where this divider should go proportionally
            let originalPosition = Double(divider.index) / Double(max(1, originalCount))
            var newIndex = Int(originalPosition * Double(sceneCount))

            // Ensure index is valid
            newIndex = max(0, min(newIndex, result.count))

            result.insert(divider.scene, at: newIndex)
        }

        return result
    }

    /// Get location from a scene
    private static func getLocation(from scene: NSManagedObject) -> String {
        if let location = scene.value(forKey: "scriptLocation") as? String, !location.isEmpty {
            return location
        }
        if let heading = scene.value(forKey: "sceneSlug") as? String ?? scene.value(forKey: "sceneHeading") as? String {
            return parseLocationFromHeading(heading)
        }
        return ""
    }

    /// Get INT/EXT from a scene
    private static func getIntExt(from scene: NSManagedObject) -> String {
        if let locationType = scene.value(forKey: "locationType") as? String, !locationType.isEmpty {
            return normalizeIntExt(locationType)
        }
        if let heading = scene.value(forKey: "sceneSlug") as? String ?? scene.value(forKey: "sceneHeading") as? String {
            return parseIntExtFromHeading(heading)
        }
        return ""
    }

    /// Get time of day from a scene
    private static func getTimeOfDay(from scene: NSManagedObject) -> String {
        if let timeOfDay = scene.value(forKey: "timeOfDay") as? String, !timeOfDay.isEmpty {
            return timeOfDay.uppercased()
        }
        if let heading = scene.value(forKey: "sceneSlug") as? String ?? scene.value(forKey: "sceneHeading") as? String {
            return parseTimeOfDayFromHeading(heading)
        }
        return ""
    }

    /// Get page eighths from a scene
    private static func getPageEighths(from scene: NSManagedObject) -> Int {
        if let eighths = scene.value(forKey: "pageEighths") as? Int16 {
            return Int(eighths)
        }
        return 0
    }

    /// Get cast members as a set from a scene
    private static func getCastSet(from scene: NSManagedObject) -> Set<String> {
        if let castIDs = scene.value(forKey: "castIDs") as? String {
            let members = castIDs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return Set(members.filter { !$0.isEmpty })
        }
        return []
    }

    // MARK: - Parsing Helpers

    /// Parse INT/EXT from a scene heading
    private static func parseIntExtFromHeading(_ heading: String) -> String {
        let upper = heading.uppercased().trimmingCharacters(in: .whitespaces)

        if upper.hasPrefix("INT./EXT.") || upper.hasPrefix("INT/EXT") || upper.hasPrefix("I/E") {
            return "I/E"
        } else if upper.hasPrefix("INT.") || upper.hasPrefix("INT ") {
            return "INT"
        } else if upper.hasPrefix("EXT.") || upper.hasPrefix("EXT ") {
            return "EXT"
        }
        return ""
    }

    /// Normalize INT/EXT value
    private static func normalizeIntExt(_ value: String) -> String {
        let upper = value.uppercased().trimmingCharacters(in: .whitespaces)
        if upper.contains("INT") && upper.contains("EXT") {
            return "I/E"
        } else if upper.contains("INT") {
            return "INT"
        } else if upper.contains("EXT") {
            return "EXT"
        }
        return upper
    }

    /// Parse location from a scene heading
    private static func parseLocationFromHeading(_ heading: String) -> String {
        var text = heading.uppercased()

        // Remove INT./EXT. prefix
        let prefixes = ["INT./EXT.", "INT/EXT", "I/E", "INT.", "INT ", "EXT.", "EXT "]
        for prefix in prefixes {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        // Remove time of day suffix
        let suffixes = [" - DAY", " - NIGHT", " - DAWN", " - DUSK", " - MORNING", " - EVENING",
                        " - LATER", " - CONTINUOUS", " - MOMENTS LATER", " -- DAY", " -- NIGHT"]
        for suffix in suffixes {
            if text.hasSuffix(suffix) {
                text = String(text.dropLast(suffix.count))
                break
            }
        }

        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Parse time of day from a scene heading
    private static func parseTimeOfDayFromHeading(_ heading: String) -> String {
        let upper = heading.uppercased()

        let times = ["DAY", "NIGHT", "DAWN", "DUSK", "MORNING", "EVENING", "LATER", "CONTINUOUS", "MOMENTS LATER"]
        for time in times {
            if upper.contains(" - \(time)") || upper.contains(" -- \(time)") || upper.hasSuffix(" \(time)") {
                return time
            }
        }
        return ""
    }
}
