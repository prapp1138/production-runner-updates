//
//  ScriptDifferTypes.swift
//  Production Runner
//
//  Minimal type definitions for script diffing used by SchedulerUpdateService
//

import Foundation
import CoreData

// MARK: - FDX Scene Draft

public struct FDXSceneDraft {
    public var numberString: String        // e.g. "3" or "12A"
    public var headingText: String         // exact <Text> content from the heading paragraph
    public var pageLength: String?         // e.g. "4/8"
    public var pageNumber: String?         // e.g. "2"
    public var scriptText: String?         // full scene body between this heading and the next (plain text)
    public var sceneFDX: String?           // RAW FDX XML fragment from this heading through the next heading (exclusive)
    public var ordinal: Int                // stable numeric order: 1,2,3,... by file sequence
}

// MARK: - Diff Result Structures

public struct DiffResult {
    public var added: [FDXSceneDraft]
    public var removed: [SceneEntity]
    public var modified: [ModifiedScene]
    public var moved: [MovedScene]
    public var unchanged: [UnchangedScene]
    public var conflicts: [ConflictScene]

    public init(
        added: [FDXSceneDraft] = [],
        removed: [SceneEntity] = [],
        modified: [ModifiedScene] = [],
        moved: [MovedScene] = [],
        unchanged: [UnchangedScene] = [],
        conflicts: [ConflictScene] = []
    ) {
        self.added = added
        self.removed = removed
        self.modified = modified
        self.moved = moved
        self.unchanged = unchanged
        self.conflicts = conflicts
    }

    /// Total number of changes detected
    public var totalChanges: Int {
        added.count + removed.count + modified.count + moved.count + conflicts.count
    }

    /// Quick summary string
    public var summary: String {
        var parts: [String] = []
        if !added.isEmpty { parts.append("\(added.count) added") }
        if !modified.isEmpty { parts.append("\(modified.count) modified") }
        if !removed.isEmpty { parts.append("\(removed.count) removed") }
        if !moved.isEmpty { parts.append("\(moved.count) moved") }
        if !conflicts.isEmpty { parts.append("\(conflicts.count) conflicts") }
        return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
    }
}

public struct ModifiedScene {
    public var existing: SceneEntity
    public var incoming: FDXSceneDraft
    public var changes: ChangeSet

    public struct ChangeSet {
        public var numberChanged: Bool = false
        public var headingChanged: Bool = false
        public var locationTypeChanged: Bool = false
        public var scriptLocationChanged: Bool = false
        public var timeOfDayChanged: Bool = false
        public var contentChanged: Bool = false
        public var pageEighthsChanged: Bool = false
        public var isMinorChange: Bool = false // Only whitespace/formatting

        public var hasSignificantChanges: Bool {
            !isMinorChange && (
                numberChanged ||
                headingChanged ||
                locationTypeChanged ||
                scriptLocationChanged ||
                timeOfDayChanged ||
                contentChanged ||
                pageEighthsChanged
            )
        }
    }
}

public struct MovedScene {
    public var scene: SceneEntity
    public var oldIndex: Int
    public var newIndex: Int
    public var incomingDraft: FDXSceneDraft
}

public struct UnchangedScene {
    public var scene: SceneEntity
    public var incomingDraft: FDXSceneDraft
}

public struct ConflictScene {
    public var scene: SceneEntity
    public var incoming: FDXSceneDraft
    public var reason: ConflictReason

    public enum ConflictReason: String {
        case localModifiedRemoteDeleted = "Scene modified locally but removed in new draft"
        case localDeletedRemoteModified = "Scene deleted locally but modified in new draft"
        case bothModifiedDifferently = "Scene modified differently in local and new draft"
        case ambiguousMatch = "Multiple possible matches found"
    }
}
