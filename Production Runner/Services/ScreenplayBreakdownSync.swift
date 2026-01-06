//
//  ScreenplayBreakdownSync.swift
//  Production Runner
//
//  Service that synchronizes screenplay data between Screenplay Editor and Breakdowns.
//  When a script is imported in Screenplay, it automatically populates Breakdowns scenes.
//

import Foundation
import CoreData

/// Service for syncing screenplay data to breakdowns
@MainActor
final class ScreenplayBreakdownSync {
    static let shared = ScreenplayBreakdownSync()

    private init() {}

    // MARK: - Sync Preference Check

    /// Check if auto-sync is enabled for a specific draft
    /// - Parameter draftId: The screenplay draft ID
    /// - Returns: True if auto-sync is enabled, false if manual mode
    func shouldAutoSync(for draftId: UUID) -> Bool {
        return ScriptSyncPreferenceManager.shared.isAutoSyncEnabled(for: draftId)
    }

    /// Get the sync mode for a draft
    func syncMode(for draftId: UUID) -> ScriptSyncMode {
        return ScriptSyncPreferenceManager.shared.syncMode(for: draftId)
    }

    // MARK: - Sync ScreenplayDocument to Breakdowns

    /// Sync a ScreenplayDocument to Breakdowns by creating SceneEntity objects
    /// - Parameters:
    ///   - document: The screenplay document to sync
    ///   - context: The Core Data context
    ///   - clearExisting: Whether to clear existing scenes before importing (default: false for versioned imports)
    ///   - breakdownVersionId: Optional version ID to tag scenes with (for version-based filtering)
    /// - Returns: Number of scenes created
    @discardableResult
    func syncToBreakdowns(
        document: ScreenplayDocument,
        context: NSManagedObjectContext,
        clearExisting: Bool = false,
        breakdownVersionId: UUID? = nil
    ) async throws -> Int {
        print("🟣 [ScreenplayBreakdownSync] syncToBreakdowns(document) CALLED - clearExisting: \(clearExisting), document scenes: \(document.scenes.count)")

        // Perform ALL Core Data operations in a single context.perform block
        // to avoid "different contexts" errors when setting relationships
        return try await context.perform {
            // Get or create project INSIDE the same context block where we'll use it
            let project = try self.getOrCreateProjectSync(in: context)
            print("🟣 [ScreenplayBreakdownSync] Got project: \(project.objectID)")

            // Count scenes BEFORE any changes
            let beforeFetch = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
            beforeFetch.predicate = NSPredicate(format: "project == %@", project)
            let beforeCount = try context.fetch(beforeFetch).count
            print("🟣 [ScreenplayBreakdownSync] Scene count BEFORE: \(beforeCount)")

            // Clear existing scenes if requested (usually not for versioned imports)
            if clearExisting {
                print("🟣 [ScreenplayBreakdownSync] Clearing existing scenes...")
                try self.clearExistingScenes(for: project, in: context)
                print("🟣 [ScreenplayBreakdownSync] Existing scenes cleared")
            } else {
                print("🟣 [ScreenplayBreakdownSync] ⚠️ NOT clearing existing scenes (clearExisting=false)")
            }

            // Extract scenes from document
            let scenes = document.scenes
            print("🟣 [ScreenplayBreakdownSync] Document has \(scenes.count) scenes to sync")

            if scenes.isEmpty {
                print("🟣 [ScreenplayBreakdownSync] ⚠️ WARNING: No scenes found in document!")
                print("🟣 [ScreenplayBreakdownSync] document.elements.count = \(document.elements.count)")
                // Log element types for debugging
                let elementTypes = document.elements.map { $0.type }
                let typeCounts = Dictionary(grouping: elementTypes, by: { $0 }).mapValues { $0.count }
                print("🟣 [ScreenplayBreakdownSync] Element types: \(typeCounts)")
            }

            var createdCount = 0

            for (index, scene) in scenes.enumerated() {
                // Create SceneEntity
                let sceneEntity = NSEntityDescription.insertNewObject(
                    forEntityName: "SceneEntity",
                    into: context
                )

                // Parse the heading to extract components
                let (locationType, scriptLocation, timeOfDay) = self.parseHeadingComponents(scene.heading)

                // Set basic scene properties using KVC for flexibility
                self.setIfExists(sceneEntity, key: "id", value: UUID())
                self.setIfExists(sceneEntity, key: "number", value: scene.number)
                self.setIfExists(sceneEntity, key: "sceneSlug", value: scene.heading)
                self.setIfExists(sceneEntity, key: "locationType", value: locationType)
                self.setIfExists(sceneEntity, key: "scriptLocation", value: scriptLocation)
                self.setIfExists(sceneEntity, key: "timeOfDay", value: timeOfDay)
                self.setIfExists(sceneEntity, key: "sortIndex", value: Int16(index))
                self.setIfExists(sceneEntity, key: "displayOrder", value: Int16(index))
                self.setIfExists(sceneEntity, key: "pageEighths", value: Int16(scene.pageEighths))
                self.setIfExists(sceneEntity, key: "createdAt", value: Date())
                self.setIfExists(sceneEntity, key: "updatedAt", value: Date())

                // Tag scene with breakdown version ID for version-based filtering
                if let versionId = breakdownVersionId {
                    self.setIfExists(sceneEntity, key: "breakdownVersionId", value: versionId)
                }

                // Extract script text for this scene (all elements until next scene heading)
                let scriptText = self.extractSceneText(from: document, sceneIndex: scene.index)
                self.setIfExists(sceneEntity, key: "scriptText", value: scriptText)

                // Generate and set scriptFDX for Script Preview in Breakdowns
                let scriptFDX = self.generateFDXFromScene(document: document, sceneIndex: scene.index, sceneNumber: scene.number)
                self.setIfExists(sceneEntity, key: "scriptFDX", value: scriptFDX)

                // Set project relationship
                if let rel = sceneEntity.entity.relationshipsByName["project"] {
                    sceneEntity.setValue(project, forKey: rel.name)
                    if index < 3 {
                        print("🟣 [ScreenplayBreakdownSync] Created scene[\(index)]: '\(scene.number)' - '\(String(scene.heading.prefix(30)))'")
                    }
                } else {
                    print("🟣 [ScreenplayBreakdownSync] ⚠️ WARNING: No 'project' relationship on SceneEntity!")
                }

                createdCount += 1
            }

            print("🟣 [ScreenplayBreakdownSync] Finished creating \(createdCount) scene entities")

            // Save changes
            if context.hasChanges {
                try context.save()
                print("🟣 [ScreenplayBreakdownSync] ✅ Saved \(createdCount) scenes to context")
            } else {
                print("🟣 [ScreenplayBreakdownSync] ⚠️ No changes to save!")
            }

            // Verify scenes were created for this project
            let verifyFetch = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
            verifyFetch.predicate = NSPredicate(format: "project == %@", project)
            let verifiedScenes = try context.fetch(verifyFetch)
            print("🟣 [ScreenplayBreakdownSync] ✅ Verification: \(verifiedScenes.count) scenes now exist for project \(project.objectID)")

            print("[ScreenplayBreakdownSync] Synced \(createdCount) scenes to Breakdowns (version: \(breakdownVersionId?.uuidString ?? "none"))")
            return createdCount
        }
    }

    /// Sync FDX data directly to Breakdowns (for when raw FDX is available)
    /// This uses the existing FDXImportService for full fidelity
    @discardableResult
    func syncFDXToBreakdowns(
        fdxData: Data,
        context: NSManagedObjectContext
    ) async throws -> Int {
        print("🔵 [ScreenplayBreakdownSync] syncFDXToBreakdowns CALLED - fdxData size: \(fdxData.count) bytes")

        // Get project as ProjectEntity (not NSManagedObject) for proper relationship assignment
        let project = try await getOrCreateProjectEntity(in: context)
        print("🔵 [ScreenplayBreakdownSync] Got project: \(project.objectID), UUID: \(project.id?.uuidString ?? "nil")")

        // Ensure project is saved before creating scenes
        if context.hasChanges {
            try context.save()
            print("🔵 [ScreenplayBreakdownSync] Saved project to context")
        }

        // Count scenes BEFORE clearing
        let beforeCount = context.performAndWait {
            let fetch = NSFetchRequest<SceneEntity>(entityName: "SceneEntity")
            fetch.predicate = NSPredicate(format: "project == %@", project)
            return (try? context.fetch(fetch).count) ?? 0
        }
        print("🔵 [ScreenplayBreakdownSync] Scene count BEFORE clear: \(beforeCount)")

        // Clear existing scenes before importing to prevent duplicates
        print("🔵 [ScreenplayBreakdownSync] About to call clearExistingScenes...")
        try clearExistingScenesSync(for: project, in: context)
        print("🔵 [ScreenplayBreakdownSync] clearExistingScenes completed")

        // Count scenes AFTER clearing
        let afterClearCount = context.performAndWait {
            let fetch = NSFetchRequest<SceneEntity>(entityName: "SceneEntity")
            fetch.predicate = NSPredicate(format: "project == %@", project)
            return (try? context.fetch(fetch).count) ?? 0
        }
        print("🔵 [ScreenplayBreakdownSync] Scene count AFTER clear: \(afterClearCount)")

        // Use the existing FDXImportService which handles all the complexity
        print("🔵 [ScreenplayBreakdownSync] About to call FDXImportService.importFDX...")
        let drafts = try FDXImportService.shared.importFDX(
            from: fdxData,
            into: context,
            for: project
        )
        print("🔵 [ScreenplayBreakdownSync] FDXImportService.importFDX returned \(drafts.count) drafts")

        // Count scenes AFTER import
        let afterImportCount = context.performAndWait {
            let fetch = NSFetchRequest<SceneEntity>(entityName: "SceneEntity")
            fetch.predicate = NSPredicate(format: "project == %@", project)
            return (try? context.fetch(fetch).count) ?? 0
        }
        print("🔵 [ScreenplayBreakdownSync] Scene count AFTER import: \(afterImportCount)")

        // CRITICAL: If scenes were created but don't have our project, fix them now
        if afterImportCount == 0 && drafts.count > 0 {
            print("🔵 [ScreenplayBreakdownSync] ⚠️ ALERT: Scenes created but none linked to project! Attempting fix...")
            try context.performAndWait {
                let allScenesFetch = NSFetchRequest<SceneEntity>(entityName: "SceneEntity")
                let allScenes = try context.fetch(allScenesFetch)
                var fixedCount = 0
                for scene in allScenes where scene.project == nil {
                    scene.project = project
                    fixedCount += 1
                }
                if fixedCount > 0 {
                    try context.save()
                    print("🔵 [ScreenplayBreakdownSync] ✅ Fixed \(fixedCount) orphan scenes")
                }
            }
        }

        print("[ScreenplayBreakdownSync] Synced \(drafts.count) scenes from FDX to Breakdowns")
        return drafts.count
    }

    // MARK: - Load from Screenplay Drafts

    /// Get all available screenplay drafts for selection
    func getAvailableDrafts() -> [ScreenplayDraftInfo] {
        return ScreenplayDataManager.shared.drafts
    }

    /// Load a specific draft and sync to breakdowns
    /// - Parameters:
    ///   - draftId: The UUID of the screenplay draft to load
    ///   - context: The Core Data context
    ///   - breakdownVersionId: Optional breakdown version ID to tag scenes with
    /// - Returns: Number of scenes created
    @discardableResult
    func loadDraftToBreakdowns(
        draftId: UUID,
        context: NSManagedObjectContext,
        breakdownVersionId: UUID? = nil
    ) async throws -> Int {
        print("🟢 [ScreenplayBreakdownSync] loadDraftToBreakdowns CALLED - draftId: \(draftId)")
        guard let document = ScreenplayDataManager.shared.loadDocument(id: draftId) else {
            throw SyncError.draftNotFound
        }
        print("🟢 [ScreenplayBreakdownSync] Loaded document with \(document.scenes.count) scenes")

        return try await syncToBreakdowns(
            document: document,
            context: context,
            clearExisting: true,  // Clear existing scenes to prevent duplicates
            breakdownVersionId: breakdownVersionId
        )
    }

    /// Load a draft to breakdowns only if auto-sync is enabled
    /// - Parameters:
    ///   - draftId: The UUID of the screenplay draft to load
    ///   - context: The Core Data context
    ///   - breakdownVersionId: Optional breakdown version ID to tag scenes with
    /// - Returns: Number of scenes created, or 0 if auto-sync is disabled
    @discardableResult
    func loadDraftToBreakdownsIfAutoSync(
        draftId: UUID,
        context: NSManagedObjectContext,
        breakdownVersionId: UUID? = nil
    ) async throws -> Int {
        // Check sync preference first
        guard shouldAutoSync(for: draftId) else {
            print("🟢 [ScreenplayBreakdownSync] Auto-sync disabled for draft \(draftId) - skipping sync")
            return 0
        }

        return try await loadDraftToBreakdowns(
            draftId: draftId,
            context: context,
            breakdownVersionId: breakdownVersionId
        )
    }

    // MARK: - Helper Methods

    private func getOrCreateProject(in context: NSManagedObjectContext) async throws -> NSManagedObject {
        return try await context.perform {
            try self.getOrCreateProjectSync(in: context)
        }
    }

    /// Synchronous version for use inside existing context.perform blocks
    /// This avoids "different contexts" errors by keeping all operations in the same block
    private func getOrCreateProjectSync(in context: NSManagedObjectContext) throws -> NSManagedObject {
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        fetch.fetchLimit = 1

        if let existing = try context.fetch(fetch).first {
            let existingID = existing.value(forKey: "id") as? UUID
            print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectSync - Found existing project: \(existing.objectID)")
            print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectSync - Project UUID: \(existingID?.uuidString ?? "nil")")
            return existing
        }

        // Create a default project if none exists
        print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectSync - No project found, creating new one...")
        let project = NSEntityDescription.insertNewObject(
            forEntityName: "ProjectEntity",
            into: context
        )
        let newID = UUID()
        self.setIfExists(project, key: "id", value: newID)
        self.setIfExists(project, key: "name", value: "Imported Project")
        self.setIfExists(project, key: "createdAt", value: Date())

        try context.save()
        print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectSync - Created new project: \(project.objectID)")
        print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectSync - New project UUID: \(newID.uuidString)")
        return project
    }

    /// Get or create project as ProjectEntity (strongly typed) for proper Core Data relationship assignment
    private func getOrCreateProjectEntity(in context: NSManagedObjectContext) async throws -> ProjectEntity {
        return try await context.perform {
            let fetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            fetch.fetchLimit = 1

            if let existing = try context.fetch(fetch).first {
                print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectEntity - Found existing project: \(existing.objectID)")
                print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectEntity - Project UUID: \(existing.id?.uuidString ?? "nil")")
                return existing
            }

            // Create a default project if none exists
            print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectEntity - No project found, creating new one...")
            let project = ProjectEntity(context: context)
            project.id = UUID()
            project.name = "Imported Project"
            project.createdAt = Date()

            try context.save()
            print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectEntity - Created new project: \(project.objectID)")
            print("🟣 [ScreenplayBreakdownSync] getOrCreateProjectEntity - New project UUID: \(project.id?.uuidString ?? "nil")")
            return project
        }
    }

    private func clearExistingScenes(for project: NSManagedObject, in context: NSManagedObjectContext) throws {
        // Use FDXImportService's cleanup which handles shots and scheduler data too
        try FDXImportService.shared.deleteAllScenes(for: project, in: context)
    }

    /// Synchronous version of clearExistingScenes to avoid async/await context issues
    private func clearExistingScenesSync(for project: ProjectEntity, in context: NSManagedObjectContext) throws {
        try context.performAndWait {
            // Fetch all scenes for this project
            let sceneFetch: NSFetchRequest<SceneEntity> = SceneEntity.fetchRequest()
            sceneFetch.predicate = NSPredicate(format: "project == %@", project)
            let scenes = try context.fetch(sceneFetch)
            print("🔵 [ScreenplayBreakdownSync] clearExistingScenesSync - Found \(scenes.count) scenes to delete")

            // Delete all shots associated with these scenes
            if !scenes.isEmpty {
                let shotFetch: NSFetchRequest<ShotEntity> = ShotEntity.fetchRequest()
                shotFetch.predicate = NSPredicate(format: "scene IN %@", scenes)
                let shots = try context.fetch(shotFetch)
                print("🔵 [ScreenplayBreakdownSync] clearExistingScenesSync - Found \(shots.count) shots to delete")
                for shot in shots {
                    context.delete(shot)
                }
            }

            // Clear scene references from ShootDayEntity
            let shootDayFetch: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
            if let shootDays = try? context.fetch(shootDayFetch) {
                for shootDay in shootDays {
                    shootDay.scenes = NSSet()
                }
            }

            // Delete all scenes
            for scene in scenes {
                context.delete(scene)
            }
            print("🔵 [ScreenplayBreakdownSync] clearExistingScenesSync - Deleted \(scenes.count) scenes")

            // Save changes
            if context.hasChanges {
                try context.save()
                print("🔵 [ScreenplayBreakdownSync] clearExistingScenesSync - Context saved")
            }
        }
    }

    private func setIfExists(_ object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName.keys.contains(key) else { return }
        object.setValue(value, forKey: key)
    }

    /// Parse a scene heading like "INT. KITCHEN - DAY" into components
    private func parseHeadingComponents(_ heading: String) -> (locationType: String, scriptLocation: String, timeOfDay: String) {
        let raw = heading.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.isEmpty { return ("", "", "") }

        // Detect and remove location type prefix
        var locationType = ""
        var remainder = raw

        if remainder.hasPrefix("INT./EXT.") || remainder.hasPrefix("INT/EXT.") {
            locationType = "INT/EXT"
            remainder = String(remainder.dropFirst(remainder.hasPrefix("INT./EXT.") ? 9 : 8))
                .trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("INT.") {
            locationType = "INT"
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("EXT.") {
            locationType = "EXT"
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("I/E.") {
            locationType = "INT/EXT"
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }

        // Split by " - " to get time of day
        let parts = remainder.components(separatedBy: " - ")
        var scriptLocation = remainder
        var timeOfDay = ""

        if parts.count >= 2 {
            timeOfDay = parts.last!.trimmingCharacters(in: .whitespaces)
            scriptLocation = parts.dropLast().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        }

        return (locationType, scriptLocation, timeOfDay)
    }

    /// Extract all text for a scene (from scene heading until next scene heading)
    private func extractSceneText(from document: ScreenplayDocument, sceneIndex: Int) -> String {
        var text = ""
        var currentIndex = sceneIndex

        // Start after the scene heading
        currentIndex += 1

        while currentIndex < document.elements.count {
            let element = document.elements[currentIndex]

            // Stop at next scene heading
            if element.type == .sceneHeading {
                break
            }

            // Add element text with appropriate formatting
            if !text.isEmpty {
                text += "\n\n"
            }
            text += element.displayText

            currentIndex += 1
        }

        return text
    }

    /// Generate FDX XML content from a ScreenplayDocument scene for Script Preview
    private func generateFDXFromScene(document: ScreenplayDocument, sceneIndex: Int, sceneNumber: String) -> String {
        var paragraphs: [String] = []

        // Start from the scene heading at sceneIndex
        var currentIndex = sceneIndex

        while currentIndex < document.elements.count {
            let element = document.elements[currentIndex]

            // Stop at the next scene heading (unless it's the first one)
            if currentIndex > sceneIndex && element.type == .sceneHeading {
                break
            }

            // Convert element to FDX paragraph XML
            let fdxType = fdxParagraphType(for: element.type)
            let escapedText = escapeXML(element.displayText)

            // Add scene number for scene headings
            if element.type == .sceneHeading {
                paragraphs.append("""
    <Paragraph Type="\(fdxType)" Number="\(sceneNumber)">
      <SceneProperties Length="1" Page="1"/>
      <Text>\(escapedText)</Text>
    </Paragraph>
""")
            } else {
                paragraphs.append("""
    <Paragraph Type="\(fdxType)">
      <Text>\(escapedText)</Text>
    </Paragraph>
""")
            }

            currentIndex += 1
        }

        // Wrap in minimal FDX structure
        let fdx = """
<?xml version="1.0" encoding="UTF-8"?>
<FinalDraft DocumentType="Script" Template="No" Version="1">
  <Content>
    \(paragraphs.joined(separator: "\n    "))
  </Content>
</FinalDraft>
"""
        return fdx
    }

    /// Map ScriptElementType to FDX paragraph type names
    private func fdxParagraphType(for elementType: ScriptElementType) -> String {
        switch elementType {
        case .sceneHeading:
            return "Scene Heading"
        case .action:
            return "Action"
        case .character:
            return "Character"
        case .dialogue:
            return "Dialogue"
        case .parenthetical:
            return "Parenthetical"
        case .transition:
            return "Transition"
        case .shot:
            return "Shot"
        case .general:
            return "General"
        case .titlePage:
            return "General"  // Title page elements are rare in scene content
        }
    }

    /// Escape special XML characters
    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Errors

    enum SyncError: LocalizedError {
        case draftNotFound
        case noProject
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .draftNotFound:
                return "Screenplay draft not found"
            case .noProject:
                return "No project available"
            case .saveFailed(let error):
                return "Failed to save: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Notification for sync completion

extension Notification.Name {
    static let screenplayBreakdownSyncCompleted = Notification.Name("screenplayBreakdownSyncCompleted")
}
