//
//  BreakdownVersion.swift
//  Production Runner
//
//  Breakdown version management for tracking different breakdown iterations
//

import Foundation

// MARK: - Breakdown Version Model

struct BreakdownVersion: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdDate: Date
    var scriptDraftId: UUID?        // Reference to screenplay draft (nil if imported externally)
    var scriptTitle: String         // Snapshot of script title
    var sceneCount: Int             // Snapshot of scene count
    var notes: String

    // Script revision tracking (for "sent" revisions from Screenplay)
    var scriptRevisionId: UUID?     // Reference to loaded script revision
    var scriptColorName: String?    // Color name for display (e.g., "Blue", "Pink")
    var scriptLoadedDate: Date?     // When the script was loaded into this version

    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        scriptDraftId: UUID? = nil,
        scriptTitle: String = "",
        sceneCount: Int = 0,
        notes: String = "",
        scriptRevisionId: UUID? = nil,
        scriptColorName: String? = nil,
        scriptLoadedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.scriptDraftId = scriptDraftId
        self.scriptTitle = scriptTitle
        self.sceneCount = sceneCount
        self.notes = notes
        self.scriptRevisionId = scriptRevisionId
        self.scriptColorName = scriptColorName
        self.scriptLoadedDate = scriptLoadedDate
    }

    /// Display name for the loaded script revision
    var scriptDisplayName: String? {
        guard let colorName = scriptColorName else { return nil }
        if colorName.lowercased() == "white" {
            return "Original Draft"
        }
        return "\(colorName) Revision"
    }

    /// Duplicate this version with a new ID and modified name
    func duplicate() -> BreakdownVersion {
        return BreakdownVersion(
            id: UUID(),
            name: name + " (Copy)",
            createdDate: Date(),
            scriptDraftId: scriptDraftId,
            scriptTitle: scriptTitle,
            sceneCount: sceneCount,
            notes: notes,
            scriptRevisionId: scriptRevisionId,
            scriptColorName: scriptColorName,
            scriptLoadedDate: scriptLoadedDate
        )
    }
}
