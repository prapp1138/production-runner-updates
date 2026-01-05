//
//  ScriptRevisionSyncService.swift
//  Production Runner
//
//  Central service for syncing script revisions across Screenplay, Scheduler, Shots, and Breakdowns.
//  Handles sending revisions, tracking loads, and intelligent merge operations.
//

import Foundation
import CoreData
import SwiftUI
import Combine

// MARK: - ScreenplayDocument Extension for SceneStrip

extension ScreenplayDocument {
    /// Constants for page calculation (matching screenplay format)
    private static let charsPerLine = 60
    private static let linesPerPage = 55

    /// Calculate the page number for a given cumulative line count
    private func pageNumber(forLineCount lineCount: Int) -> Int {
        max(1, (lineCount / Self.linesPerPage) + 1)
    }

    /// Calculate line count for an element
    private func lineCount(for element: ScriptElement) -> Int {
        let textLines = max(1, (element.text.count / Self.charsPerLine) + 1)
        // Add spacing based on element type
        let spacing: Int
        switch element.type {
        case .sceneHeading:
            spacing = 2  // Extra space before scene headings
        case .character:
            spacing = 1
        case .dialogue, .parenthetical:
            spacing = 0
        default:
            spacing = 1
        }
        return textLines + spacing
    }

    /// Calculate page eighths from line count (55 lines = 1 page = 8 eighths)
    private func pageEighths(forLineCount lineCount: Int) -> Int {
        // 55 lines per page, 8 eighths per page
        // So each eighth is approximately 55/8 ≈ 6.875 lines
        let eighths = max(1, Int(round(Double(lineCount) * 8.0 / Double(Self.linesPerPage))))
        return eighths
    }

    /// Extract scenes from the document's elements as SceneStrips with calculated page numbers
    var sceneStrips: [SceneStrip] {
        var strips: [SceneStrip] = []
        var sceneIndex = 1
        var cumulativeLines = 0
        var pendingStrip: (id: UUID, index: Int, intExt: String, slugline: String, location: String, dayNight: String, startPage: Int, startLine: Int, sceneNumber: String?, isOmitted: Bool, rawHeading: String)?

        for element in elements {
            let elementLines = lineCount(for: element)

            if element.type == .sceneHeading {
                // Finalize previous scene if exists
                if let pending = pendingStrip {
                    let endPage = pageNumber(forLineCount: cumulativeLines)
                    let sceneLines = cumulativeLines - pending.startLine
                    let eighths = pageEighths(forLineCount: sceneLines)
                    strips.append(SceneStrip(
                        id: pending.id,
                        index: pending.index,
                        slugline: pending.slugline,
                        intExt: pending.intExt,
                        location: pending.location,
                        dayNight: pending.dayNight,
                        startPage: pending.startPage,
                        endPage: endPage,
                        sceneNumber: pending.sceneNumber,
                        isOmitted: pending.isOmitted,
                        rawHeading: pending.rawHeading,
                        pageEighths: eighths
                    ))
                }

                // Start new scene
                let startPage = pageNumber(forLineCount: cumulativeLines)
                let (intExt, slugline, location, dayNight) = parseSceneHeading(element.text)

                pendingStrip = (
                    id: element.id,
                    index: sceneIndex,
                    intExt: intExt,
                    slugline: slugline,
                    location: location,
                    dayNight: dayNight,
                    startPage: startPage,
                    startLine: cumulativeLines,
                    sceneNumber: element.sceneNumber,
                    isOmitted: element.isOmitted,
                    rawHeading: element.text
                )
                sceneIndex += 1
            }

            cumulativeLines += elementLines
        }

        // Finalize last scene
        if let pending = pendingStrip {
            let endPage = pageNumber(forLineCount: cumulativeLines)
            let sceneLines = cumulativeLines - pending.startLine
            let eighths = pageEighths(forLineCount: sceneLines)
            strips.append(SceneStrip(
                id: pending.id,
                index: pending.index,
                slugline: pending.slugline,
                intExt: pending.intExt,
                location: pending.location,
                dayNight: pending.dayNight,
                startPage: pending.startPage,
                endPage: endPage,
                sceneNumber: pending.sceneNumber,
                isOmitted: pending.isOmitted,
                rawHeading: pending.rawHeading,
                pageEighths: eighths
            ))
        }

        return strips
    }

    /// Parse a scene heading into its components
    private func parseSceneHeading(_ heading: String) -> (intExt: String, slugline: String, location: String, dayNight: String) {
        let raw = heading.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.isEmpty { return ("", "", "", "") }

        var intExt = ""
        var remainder = raw

        if remainder.hasPrefix("INT./EXT.") || remainder.hasPrefix("INT/EXT.") {
            intExt = "INT./EXT."
            remainder = String(remainder.dropFirst(remainder.hasPrefix("INT./EXT.") ? 9 : 8))
                .trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("INT.") {
            intExt = "INT."
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("EXT.") {
            intExt = "EXT."
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("I/E.") {
            intExt = "I/E."
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }

        let parts = remainder.components(separatedBy: " - ")
        var location = remainder
        var dayNight = ""

        if parts.count >= 2 {
            dayNight = parts.last!.trimmingCharacters(in: .whitespaces)
            location = parts.dropLast().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        }

        // Slugline is the same as location for now
        let slugline = location

        return (intExt, slugline, location, dayNight)
    }
}

// MARK: - Sent Revision Model

/// Represents a revision that has been "sent" from Screenplay and is available for loading in other apps
struct SentRevision: Identifiable, Codable, Hashable {
    let id: UUID
    let revisionId: UUID           // Reference to ScriptRevisionEntity
    let colorName: String
    let fileName: String
    let sentDate: Date
    let sceneCount: Int
    let pageCount: Int
    var loadedInScheduler: Bool
    var loadedInShots: Bool
    var loadedInBreakdowns: Bool
    var schedulerLoadDate: Date?
    var shotsLoadDate: Date?
    var breakdownsLoadDate: Date?

    init(
        id: UUID = UUID(),
        revisionId: UUID,
        colorName: String,
        fileName: String,
        sentDate: Date = Date(),
        sceneCount: Int,
        pageCount: Int,
        loadedInScheduler: Bool = false,
        loadedInShots: Bool = false,
        loadedInBreakdowns: Bool = false
    ) {
        self.id = id
        self.revisionId = revisionId
        self.colorName = colorName
        self.fileName = fileName
        self.sentDate = sentDate
        self.sceneCount = sceneCount
        self.pageCount = pageCount
        self.loadedInScheduler = loadedInScheduler
        self.loadedInShots = loadedInShots
        self.loadedInBreakdowns = loadedInBreakdowns
    }

    var displayName: String {
        if colorName.lowercased() == "white" {
            return "Original Draft"
        }
        return "\(colorName) Revision"
    }

    var color: Color {
        switch colorName.lowercased() {
        case "white": return Color(red: 1.0, green: 1.0, blue: 1.0)
        case "blue": return Color(red: 0.68, green: 0.85, blue: 0.90)
        case "pink": return Color(red: 1.0, green: 0.75, blue: 0.80)
        case "yellow": return Color(red: 1.0, green: 1.0, blue: 0.60)
        case "green": return Color(red: 0.60, green: 0.98, blue: 0.60)
        case "goldenrod": return Color(red: 0.93, green: 0.79, blue: 0.45)
        case "buff": return Color(red: 0.94, green: 0.86, blue: 0.70)
        case "salmon": return Color(red: 1.0, green: 0.63, blue: 0.48)
        case "cherry": return Color(red: 0.87, green: 0.44, blue: 0.63)
        case "tan": return Color(red: 0.82, green: 0.71, blue: 0.55)
        case "gray", "grey": return Color(red: 0.83, green: 0.83, blue: 0.83)
        default: return Color(red: 1.0, green: 1.0, blue: 1.0)
        }
    }
}

// MARK: - Merge Result Models

/// Result of merging a script revision into an app
struct MergeResult {
    var scenesAdded: [UUID]
    var scenesRemoved: [UUID]
    var scenesModified: [UUID]
    var conflicts: [MergeConflict]
    var preservedLocalEdits: Int

    init(
        scenesAdded: [UUID] = [],
        scenesRemoved: [UUID] = [],
        scenesModified: [UUID] = [],
        conflicts: [MergeConflict] = [],
        preservedLocalEdits: Int = 0
    ) {
        self.scenesAdded = scenesAdded
        self.scenesRemoved = scenesRemoved
        self.scenesModified = scenesModified
        self.conflicts = conflicts
        self.preservedLocalEdits = preservedLocalEdits
    }

    var hasChanges: Bool {
        !scenesAdded.isEmpty || !scenesRemoved.isEmpty || !scenesModified.isEmpty
    }

    var hasConflicts: Bool {
        !conflicts.isEmpty
    }

    var summary: String {
        var parts: [String] = []
        if !scenesAdded.isEmpty {
            parts.append("\(scenesAdded.count) added")
        }
        if !scenesModified.isEmpty {
            parts.append("\(scenesModified.count) modified")
        }
        if !scenesRemoved.isEmpty {
            parts.append("\(scenesRemoved.count) removed")
        }
        if preservedLocalEdits > 0 {
            parts.append("\(preservedLocalEdits) local edits preserved")
        }
        return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
    }
}

/// Represents a conflict between local edits and incoming script changes
struct MergeConflict: Identifiable {
    let id: UUID
    let sceneId: UUID
    let sceneNumber: String
    let localChange: String
    let incomingChange: String
    var resolution: ConflictResolution?

    init(
        id: UUID = UUID(),
        sceneId: UUID,
        sceneNumber: String,
        localChange: String,
        incomingChange: String,
        resolution: ConflictResolution? = nil
    ) {
        self.id = id
        self.sceneId = sceneId
        self.sceneNumber = sceneNumber
        self.localChange = localChange
        self.incomingChange = incomingChange
        self.resolution = resolution
    }

    enum ConflictResolution: String, Codable {
        case keepLocal = "Keep Local"
        case useIncoming = "Use Incoming"
        case keepBoth = "Keep Both"
    }
}

// MARK: - App Type

enum SyncAppType: String, Codable, CaseIterable {
    case scheduler = "Scheduler"
    case shots = "Shots"
    case breakdowns = "Breakdowns"

    var icon: String {
        switch self {
        case .scheduler: return "calendar"
        case .shots: return "camera"
        case .breakdowns: return "list.bullet.rectangle"
        }
    }
}

// MARK: - Script Revision Sync Service

@MainActor
final class ScriptRevisionSyncService: ObservableObject {

    // MARK: - Singleton

    static let shared = ScriptRevisionSyncService()

    // MARK: - Published Properties

    @Published var sentRevisions: [SentRevision] = []
    @Published var latestRevisionByApp: [SyncAppType: UUID] = [:]

    // MARK: - Private Properties

    @AppStorage("sentRevisionsData") private var sentRevisionsData: Data = Data()
    @AppStorage("latestRevisionByAppData") private var latestRevisionByAppData: Data = Data()

    private var context: NSManagedObjectContext?

    // MARK: - Initialization

    private init() {
        loadSentRevisions()
    }

    func configure(with context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Send Revision

    /// Send a revision from Screenplay to make it available in other apps
    func sendRevision(_ revision: StoredRevision, document: ScreenplayDocument) async {
        // Check if this revision was already sent
        if let existingIndex = sentRevisions.firstIndex(where: { $0.revisionId == revision.id }) {
            // Update existing entry
            sentRevisions[existingIndex].loadedInScheduler = false
            sentRevisions[existingIndex].loadedInShots = false
            sentRevisions[existingIndex].loadedInBreakdowns = false
        } else {
            // Create new sent revision entry
            let sentRevision = SentRevision(
                revisionId: revision.id,
                colorName: revision.colorName,
                fileName: revision.fileName,
                sceneCount: revision.sceneCount,
                pageCount: revision.pageCount
            )
            sentRevisions.insert(sentRevision, at: 0)
        }

        saveSentRevisions()

        // Post notification for other apps
        NotificationCenter.default.post(name: .scriptRevisionSent, object: revision.id)

        // Add user-visible notification
        NotificationManager.shared.addNotification(
            title: "Script Revision Sent",
            message: "\(revision.displayName) is now available in Scheduler, Shots, and Breakdowns",
            category: .scriptRevision
        )
    }

    // MARK: - Get Revision

    /// Get a sent revision by its ID
    func getRevision(_ id: UUID) -> SentRevision? {
        sentRevisions.first { $0.id == id }
    }

    /// Get a sent revision by the original revision ID
    func getRevisionByOriginalId(_ revisionId: UUID) -> SentRevision? {
        sentRevisions.first { $0.revisionId == revisionId }
    }

    // MARK: - Check for Updates

    /// Check if there are new revisions available that haven't been loaded into the app
    func hasUpdatesAvailable(for app: SyncAppType) -> Bool {
        guard let latestLoaded = latestRevisionByApp[app] else {
            // No revision loaded yet, so any sent revision is an update
            return !sentRevisions.isEmpty
        }

        // Check if there's a newer revision than what's loaded
        guard let latestLoadedRevision = sentRevisions.first(where: { $0.id == latestLoaded }) else {
            return !sentRevisions.isEmpty
        }

        // Check based on app
        switch app {
        case .scheduler:
            return sentRevisions.contains { !$0.loadedInScheduler && $0.sentDate > latestLoadedRevision.sentDate }
        case .shots:
            return sentRevisions.contains { !$0.loadedInShots && $0.sentDate > latestLoadedRevision.sentDate }
        case .breakdowns:
            return sentRevisions.contains { !$0.loadedInBreakdowns && $0.sentDate > latestLoadedRevision.sentDate }
        }
    }

    /// Get the latest unloaded revision for an app
    func getLatestUnloadedRevision(for app: SyncAppType) -> SentRevision? {
        switch app {
        case .scheduler:
            return sentRevisions.first { !$0.loadedInScheduler }
        case .shots:
            return sentRevisions.first { !$0.loadedInShots }
        case .breakdowns:
            return sentRevisions.first { !$0.loadedInBreakdowns }
        }
    }

    // MARK: - Load Revision

    /// Load a revision into an app with intelligent merge
    func loadRevision(
        _ revision: SentRevision,
        into app: SyncAppType,
        context: NSManagedObjectContext
    ) async throws -> MergeResult {

        // Get the document data for this revision
        guard let document = loadRevisionDocument(revisionId: revision.revisionId, context: context) else {
            throw SyncError.revisionNotFound
        }

        // Perform merge based on app type
        let result: MergeResult

        switch app {
        case .scheduler:
            result = try await mergeIntoScheduler(document: document, context: context)
        case .shots:
            result = try await mergeIntoShots(document: document, context: context)
        case .breakdowns:
            result = try await mergeIntoBreakdowns(document: document, context: context)
        }

        // Mark as loaded
        markAsLoaded(revision: revision, app: app)

        // Post notification
        NotificationCenter.default.post(
            name: .scriptRevisionLoaded,
            object: nil,
            userInfo: ["app": app, "revisionId": revision.id]
        )

        return result
    }

    /// Mark a revision as loaded in an app
    private func markAsLoaded(revision: SentRevision, app: SyncAppType) {
        guard let index = sentRevisions.firstIndex(where: { $0.id == revision.id }) else { return }

        switch app {
        case .scheduler:
            sentRevisions[index].loadedInScheduler = true
            sentRevisions[index].schedulerLoadDate = Date()
        case .shots:
            sentRevisions[index].loadedInShots = true
            sentRevisions[index].shotsLoadDate = Date()
        case .breakdowns:
            sentRevisions[index].loadedInBreakdowns = true
            sentRevisions[index].breakdownsLoadDate = Date()
        }

        latestRevisionByApp[app] = revision.id
        saveSentRevisions()
        saveLatestRevisionByApp()
    }

    // MARK: - Merge Operations

    private func mergeIntoScheduler(document: ScreenplayDocument, context: NSManagedObjectContext) async throws -> MergeResult {
        // Get existing scenes from Core Data
        let existingScenes = try await fetchExistingScenes(context: context)
        return try await performMerge(document: document, existingScenes: existingScenes, context: context)
    }

    private func mergeIntoShots(document: ScreenplayDocument, context: NSManagedObjectContext) async throws -> MergeResult {
        let existingScenes = try await fetchExistingScenes(context: context)
        return try await performMerge(document: document, existingScenes: existingScenes, context: context)
    }

    private func mergeIntoBreakdowns(document: ScreenplayDocument, context: NSManagedObjectContext) async throws -> MergeResult {
        let existingScenes = try await fetchExistingScenes(context: context)
        return try await performMerge(document: document, existingScenes: existingScenes, context: context)
    }

    /// Core merge logic that intelligently merges incoming script changes with existing data
    private func performMerge(
        document: ScreenplayDocument,
        existingScenes: [NSManagedObject],
        context: NSManagedObjectContext
    ) async throws -> MergeResult {

        var result = MergeResult()
        let incomingStrips = document.sceneStrips

        // Build lookup maps
        let existingByNumber = Dictionary(grouping: existingScenes) { scene -> String in
            (scene.value(forKey: "number") as? String) ?? ""
        }
        let incomingNumbers = Set(incomingStrips.compactMap { $0.sceneNumber })

        await context.perform {
            // 1. Detect and add new scenes
            for (index, strip) in incomingStrips.enumerated() {
                guard let sceneNumber = strip.sceneNumber else { continue }
                if existingByNumber[sceneNumber] == nil {
                    // New scene - create it
                    let newSceneId = self.createScene(
                        from: strip,
                        at: index,
                        in: context
                    )
                    result.scenesAdded.append(newSceneId)
                }
            }

            // 2. Detect removed scenes (mark as omitted, don't delete)
            for (number, scenes) in existingByNumber where !number.isEmpty {
                if !incomingNumbers.contains(number) {
                    for scene in scenes {
                        // Mark as removed but preserve
                        if let currentFlags = scene.value(forKey: "provenanceFlags") as? Int16 {
                            let newFlags = currentFlags | SceneProvenanceFlags.removed.rawValue
                            scene.setValue(newFlags, forKey: "provenanceFlags")
                        } else {
                            scene.setValue(SceneProvenanceFlags.removed.rawValue, forKey: "provenanceFlags")
                        }

                        if let sceneId = scene.value(forKey: "id") as? UUID {
                            result.scenesRemoved.append(sceneId)
                        }
                    }
                }
            }

            // 3. Detect modifications with conflict detection
            for strip in incomingStrips {
                guard let sceneNumber = strip.sceneNumber else { continue }
                if let existingScenesList = existingByNumber[sceneNumber], !existingScenesList.isEmpty {
                    let existingScene = existingScenesList[0]

                    // Check if scene has local edits
                    let hasLocalEdits = self.checkForLocalEdits(scene: existingScene)

                    if hasLocalEdits {
                        // Conflict detected - preserve local edits
                        if let sceneId = existingScene.value(forKey: "id") as? UUID {
                            result.conflicts.append(MergeConflict(
                                sceneId: sceneId,
                                sceneNumber: sceneNumber,
                                localChange: "Local edits exist",
                                incomingChange: "Script content updated"
                            ))
                            result.preservedLocalEdits += 1
                        }
                    } else {
                        // Safe to update - no local edits
                        let wasModified = self.updateScene(
                            existingScene,
                            from: strip,
                            in: context
                        )
                        if wasModified, let sceneId = existingScene.value(forKey: "id") as? UUID {
                            result.scenesModified.append(sceneId)
                        }
                    }
                }
            }

            // 4. Update sort order for all scenes
            self.updateSceneOrder(from: document, existingScenes: existingScenes, in: context)

            // Save changes
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("[ScriptRevisionSyncService] Failed to save merge: \(error)")
                }
            }
        }

        return result
    }

    /// Check if a scene has local edits that should be preserved
    private func checkForLocalEdits(scene: NSManagedObject) -> Bool {
        guard let importedAt = scene.value(forKey: "importedAt") as? Date,
              let lastLocalEdit = scene.value(forKey: "lastLocalEdit") as? Date else {
            return false
        }
        return lastLocalEdit > importedAt
    }

    /// Create a new scene entity from a SceneStrip
    private func createScene(from strip: SceneStrip, at index: Int, in context: NSManagedObjectContext) -> UUID {
        let sceneEntity = NSEntityDescription.insertNewObject(forEntityName: "SceneEntity", into: context)
        let sceneId = strip.id

        // Use the already-parsed heading components from SceneStrip
        let locationType = strip.intExt.replacingOccurrences(of: ".", with: "")
        let scriptLocation = strip.location
        let timeOfDay = strip.dayNight

        setIfExists(sceneEntity, key: "id", value: sceneId)
        setIfExists(sceneEntity, key: "number", value: strip.sceneNumber ?? "")
        setIfExists(sceneEntity, key: "sceneSlug", value: strip.rawHeading ?? strip.headingLine)
        setIfExists(sceneEntity, key: "locationType", value: locationType)
        setIfExists(sceneEntity, key: "scriptLocation", value: scriptLocation)
        setIfExists(sceneEntity, key: "timeOfDay", value: timeOfDay)
        setIfExists(sceneEntity, key: "sortIndex", value: Int16(index))
        setIfExists(sceneEntity, key: "displayOrder", value: Int16(index))
        setIfExists(sceneEntity, key: "createdAt", value: Date())
        setIfExists(sceneEntity, key: "updatedAt", value: Date())
        setIfExists(sceneEntity, key: "importedAt", value: Date())
        setIfExists(sceneEntity, key: "provenanceFlags", value: SceneProvenanceFlags.newScene.rawValue)

        // Page information from SceneStrip
        setIfExists(sceneEntity, key: "pageNumber", value: "\(strip.startPage)")
        setIfExists(sceneEntity, key: "pageEighths", value: Int16(strip.pageEighths))
        setIfExists(sceneEntity, key: "pageEighthsString", value: formatPageEighths(strip.pageEighths))

        return sceneId
    }

    /// Format page eighths as a string (e.g., "1 2/8" or "2/8")
    private func formatPageEighths(_ eighths: Int) -> String {
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

    /// Update an existing scene with incoming SceneStrip data (returns true if modified)
    private func updateScene(_ scene: NSManagedObject, from strip: SceneStrip, in context: NSManagedObjectContext) -> Bool {
        let locationType = strip.intExt.replacingOccurrences(of: ".", with: "")
        let scriptLocation = strip.location
        let timeOfDay = strip.dayNight
        let heading = strip.rawHeading ?? strip.headingLine

        var wasModified = false

        // Check each field and update if different
        if let currentHeading = scene.value(forKey: "sceneSlug") as? String, currentHeading != heading {
            scene.setValue(heading, forKey: "sceneSlug")
            wasModified = true
        }

        if let currentLocType = scene.value(forKey: "locationType") as? String, currentLocType != locationType {
            scene.setValue(locationType, forKey: "locationType")
            wasModified = true
        }

        if let currentLoc = scene.value(forKey: "scriptLocation") as? String, currentLoc != scriptLocation {
            scene.setValue(scriptLocation, forKey: "scriptLocation")
            wasModified = true
        }

        if let currentTOD = scene.value(forKey: "timeOfDay") as? String, currentTOD != timeOfDay {
            scene.setValue(timeOfDay, forKey: "timeOfDay")
            wasModified = true
        }

        // Always update page info (doesn't count as content modification)
        let newPageNumber = "\(strip.startPage)"
        if let currentPage = scene.value(forKey: "pageNumber") as? String, currentPage != newPageNumber {
            setIfExists(scene, key: "pageNumber", value: newPageNumber)
        }
        // Use pre-calculated pageEighths from SceneStrip (based on actual line count)
        setIfExists(scene, key: "pageEighths", value: Int16(strip.pageEighths))
        setIfExists(scene, key: "pageEighthsString", value: formatPageEighths(strip.pageEighths))

        if wasModified {
            scene.setValue(Date(), forKey: "updatedAt")

            // Add modified flag to provenance
            if let currentFlags = scene.value(forKey: "provenanceFlags") as? Int16 {
                let newFlags = currentFlags | SceneProvenanceFlags.modified.rawValue
                scene.setValue(newFlags, forKey: "provenanceFlags")
            }
        }

        return wasModified
    }

    /// Update scene order to match incoming document
    private func updateSceneOrder(from document: ScreenplayDocument, existingScenes: [NSManagedObject], in context: NSManagedObjectContext) {
        let incomingStrips = document.sceneStrips
        let sceneOrderMap = Dictionary(uniqueKeysWithValues: incomingStrips.enumerated().compactMap { index, strip -> (String, Int)? in
            guard let number = strip.sceneNumber else { return nil }
            return (number, index)
        })

        for scene in existingScenes {
            guard let number = scene.value(forKey: "number") as? String,
                  let newIndex = sceneOrderMap[number] else { continue }

            let currentIndex = scene.value(forKey: "sortIndex") as? Int16 ?? 0
            if currentIndex != Int16(newIndex) {
                scene.setValue(Int16(newIndex), forKey: "sortIndex")
                scene.setValue(Int16(newIndex), forKey: "displayOrder")
            }
        }
    }

    // MARK: - Helper Methods

    private func fetchExistingScenes(context: NSManagedObjectContext) async throws -> [NSManagedObject] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
            return try context.fetch(request)
        }
    }

    private func loadRevisionDocument(revisionId: UUID, context: NSManagedObjectContext) -> ScreenplayDocument? {
        // Try using FDXRevisionImporter first
        return FDXRevisionImporter.shared.loadRevisionDocument(id: revisionId)
    }

    private func setIfExists(_ object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName.keys.contains(key) else { return }
        object.setValue(value, forKey: key)
    }

    // MARK: - Persistence

    private func loadSentRevisions() {
        print("[ScriptRevisionSyncService DEBUG] loadSentRevisions() called")
        if let decoded = try? JSONDecoder().decode([SentRevision].self, from: sentRevisionsData) {
            print("[ScriptRevisionSyncService DEBUG] Loaded \(decoded.count) sent revisions")
            sentRevisions = decoded
        }

        if let decoded = try? JSONDecoder().decode([SyncAppType: UUID].self, from: latestRevisionByAppData) {
            print("[ScriptRevisionSyncService DEBUG] Loaded latestRevisionByApp: \(decoded)")
            latestRevisionByApp = decoded
        }
    }

    private func saveSentRevisions() {
        if let encoded = try? JSONEncoder().encode(sentRevisions) {
            sentRevisionsData = encoded
        }
    }

    private func saveLatestRevisionByApp() {
        if let encoded = try? JSONEncoder().encode(latestRevisionByApp) {
            latestRevisionByAppData = encoded
        }
    }

    // MARK: - Errors

    enum SyncError: LocalizedError {
        case revisionNotFound
        case mergeConflict
        case saveFailed(Error)
        case contextNotConfigured

        var errorDescription: String? {
            switch self {
            case .revisionNotFound:
                return "Script revision not found"
            case .mergeConflict:
                return "Merge conflict detected"
            case .saveFailed(let error):
                return "Failed to save: \(error.localizedDescription)"
            case .contextNotConfigured:
                return "Core Data context not configured"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let scriptRevisionSent = Notification.Name("scriptRevisionSent")
    static let scriptRevisionAvailable = Notification.Name("scriptRevisionAvailable")
    static let scriptRevisionLoaded = Notification.Name("scriptRevisionLoaded")
}
