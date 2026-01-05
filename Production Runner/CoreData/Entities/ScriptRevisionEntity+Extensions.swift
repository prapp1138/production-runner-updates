//
//  ScriptRevisionEntity+Extensions.swift
//  Production Runner
//
//  Tracks script revisions and provides history of changes during production.
//

import Foundation
import CoreData
import CryptoKit

// MARK: - Provenance Flags
public struct SceneProvenanceFlags: OptionSet {
    public let rawValue: Int16
    
    public init(rawValue: Int16) {
        self.rawValue = rawValue
    }
    
    public static let renumbered = SceneProvenanceFlags(rawValue: 1 << 0)     // Scene number changed
    public static let moved      = SceneProvenanceFlags(rawValue: 1 << 1)     // Scene moved in script order
    public static let conflict   = SceneProvenanceFlags(rawValue: 1 << 2)     // Local edits vs source conflict
    public static let safeChange = SceneProvenanceFlags(rawValue: 1 << 3)     // Minor whitespace/format only
    public static let newScene   = SceneProvenanceFlags(rawValue: 1 << 4)     // Added in this revision
    public static let removed    = SceneProvenanceFlags(rawValue: 1 << 5)     // Removed from script
    public static let modified   = SceneProvenanceFlags(rawValue: 1 << 6)     // Content changed
}

// MARK: - ScriptRevisionEntity Extensions
extension ScriptRevisionEntity {
    
    /// The standard revision colors used in film production
    public enum RevisionColor: String, CaseIterable {
        case white = "White"
        case blue = "Blue"
        case pink = "Pink"
        case yellow = "Yellow"
        case green = "Green"
        case goldenrod = "Goldenrod"
        case buff = "Buff"
        case salmon = "Salmon"
        case cherry = "Cherry"
        case tan = "Tan"
        case gray = "Gray"
        case ivory = "Ivory"
        
        /// Typical order of revision colors in production
        public static var standardOrder: [RevisionColor] {
            [.white, .blue, .pink, .yellow, .green, .goldenrod, .buff, .salmon, .cherry, .tan, .gray, .ivory]
        }
        
        /// Get the next revision color in sequence
        public func next() -> RevisionColor {
            let order = RevisionColor.standardOrder
            if let currentIndex = order.firstIndex(of: self),
               currentIndex + 1 < order.count {
                return order[currentIndex + 1]
            }
            return .white // Cycle back to white
        }
    }
    
    /// Convenience: Get revision color as enum
    public var revisionColor: RevisionColor? {
        get {
            guard let colorName = colorName else { return nil }
            return RevisionColor(rawValue: colorName)
        }
        set {
            colorName = newValue?.rawValue
        }
    }
    
    /// Formatted display name (e.g., "Pink Revisions - Jan 15, 2025")
    public var displayName: String {
        var parts: [String] = []
        
        if let revisionName = revisionName, !revisionName.isEmpty {
            parts.append(revisionName)
        } else if let color = colorName, !color.isEmpty {
            parts.append("\(color) Revisions")
        }
        
        if let date = importedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            parts.append(formatter.string(from: date))
        }
        
        return parts.isEmpty ? "Untitled Revision" : parts.joined(separator: " - ")
    }
    
    /// Summary of changes in this revision
    public var changeSummary: String {
        var parts: [String] = []
        
        if scenesAdded > 0 {
            parts.append("\(scenesAdded) added")
        }
        if scenesModified > 0 {
            parts.append("\(scenesModified) modified")
        }
        if scenesRemoved > 0 {
            parts.append("\(scenesRemoved) removed")
        }
        
        if let delta = pageCountDelta as Decimal?, delta != 0 {
            let sign = delta > 0 ? "+" : ""
            let formatted = String(format: "%@%.2f pages", sign, NSDecimalNumber(decimal: delta).doubleValue)
            parts.append(formatted)
        }
        
        return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
    }
    
    /// Create a new revision for a project
    public static func create(
        in context: NSManagedObjectContext,
        project: ProjectEntity,
        fileName: String,
        fileData: Data,
        revisionName: String? = nil,
        colorName: String? = nil,
        importedBy: String? = nil
    ) -> ScriptRevisionEntity {
        let revision = ScriptRevisionEntity(context: context)
        revision.id = UUID()
        revision.importedAt = Date()
        revision.fileName = fileName
        revision.fileSize = Int64(fileData.count)
        revision.fileHash = Self.computeHash(for: fileData)
        revision.revisionName = revisionName
        revision.colorName = colorName
        revision.importedBy = importedBy
        revision.project = project
        
        return revision
    }
    
    /// Compute SHA-256 hash of file data
    public static func computeHash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Update statistics after import
    public func updateStatistics(
        sceneCount: Int,
        scenesAdded: Int,
        scenesModified: Int,
        scenesRemoved: Int,
        pageCount: Int,
        pageCountDelta: Decimal
    ) {
        self.sceneCount = Int32(sceneCount)
        self.scenesAdded = Int32(scenesAdded)
        self.scenesModified = Int32(scenesModified)
        self.scenesRemoved = Int32(scenesRemoved)
        self.pageCount = Int16(pageCount)
        self.pageCountDelta = pageCountDelta as NSDecimalNumber
    }
}

// MARK: - SceneEntity Revision Extensions
extension SceneEntity {
    
    /// Provenance flags for tracking scene changes
    public var provenance: SceneProvenanceFlags {
        get {
            SceneProvenanceFlags(rawValue: provenanceFlags)
        }
        set {
            provenanceFlags = newValue.rawValue
        }
    }
    
    /// Has this scene been locally edited since import?
    public var hasLocalEdits: Bool {
        guard let importedAt = importedAt,
              let lastEdit = lastLocalEdit else {
            return false
        }
        return lastEdit > importedAt
    }
    
    /// Mark scene as locally edited
    public func markAsEdited() {
        lastLocalEdit = Date()
    }
    
    /// Compute content hash for change detection
    public func computeContentHash() -> String {
        var components: [String] = []
        
        if let number = number { components.append(number) }
        if let location = scriptLocation { components.append(location) }
        if let locType = locationType { components.append(locType) }
        if let tod = timeOfDay { components.append(tod) }
        if let text = scriptText { components.append(text) }
        
        let combined = components.joined(separator: "|")
        let data = combined.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Compute normalized hash (ignores whitespace and trivial changes)
    public func computeNormalizedHash() -> String {
        var components: [String] = []
        
        // Normalize text by removing extra whitespace and punctuation
        let normalize: (String) -> String = { text in
            text.lowercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let number = number { components.append(normalize(number)) }
        if let location = scriptLocation { components.append(normalize(location)) }
        if let locType = locationType { components.append(normalize(locType)) }
        if let tod = timeOfDay { components.append(normalize(tod)) }
        if let text = scriptText { components.append(normalize(text)) }
        
        let combined = components.joined(separator: "|")
        let data = combined.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Update hashes after content changes
    public func updateHashes() {
        contentHash = computeContentHash()
        normalizedHash = computeNormalizedHash()
    }
    
    /// Set provenance information during import
    public func setProvenance(
        sourceID: String,
        fileHash: String,
        revision: ScriptRevisionEntity?
    ) {
        self.sourceID = sourceID
        self.sourceFileHash = fileHash
        self.importedAt = Date()
        self.importedFromRevision = revision
        updateHashes()
    }
}

// MARK: - Helper Functions
extension ScriptRevisionEntity {
    
    /// Fetch all revisions for a project, ordered by import date
    public static func fetchRevisions(
        for project: ProjectEntity,
        in context: NSManagedObjectContext
    ) throws -> [ScriptRevisionEntity] {
        let fetchRequest: NSFetchRequest<ScriptRevisionEntity> = ScriptRevisionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "project == %@", project)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "importedAt", ascending: false)]
        
        return try context.fetch(fetchRequest)
    }
    
    /// Get the most recent revision for a project
    public static func mostRecent(
        for project: ProjectEntity,
        in context: NSManagedObjectContext
    ) throws -> ScriptRevisionEntity? {
        let revisions = try fetchRevisions(for: project, in: context)
        return revisions.first
    }
}
