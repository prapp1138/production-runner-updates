//
//  FDXRevisionImporter.swift
//  Production Runner
//
//  Handles importing FDX files as revisions and tracking changes
//  between script versions. Stores revisions in Core Data.
//

import Foundation
import CoreData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Revision Import Result

struct RevisionImportResult {
    let success: Bool
    let revisionId: UUID?
    let colorName: String
    let scenesAdded: Int
    let scenesModified: Int
    let scenesRemoved: Int
    let totalElements: Int
    let error: String?
}

// MARK: - Stored Revision Model

struct StoredRevision: Identifiable, Hashable {
    let id: UUID
    let colorName: String
    let fileName: String
    let fileHash: String
    let importDate: Date
    let scenesAdded: Int
    let scenesModified: Int
    let scenesRemoved: Int
    let notes: String?
    let pageCount: Int
    let sceneCount: Int

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

// MARK: - FDX Revision Importer

@MainActor
class FDXRevisionImporter: ObservableObject {

    // MARK: - Published Properties

    @Published var revisions: [StoredRevision] = []
    @Published var isImporting = false
    @Published var lastError: String?
    @Published var currentDraftId: UUID?

    // MARK: - Private Properties

    private var context: NSManagedObjectContext?
    private let converter = FDXConverter()

    // MARK: - Singleton

    static let shared = FDXRevisionImporter()

    private init() {}

    // MARK: - Configuration

    func configure(with context: NSManagedObjectContext) {
        self.context = context
        loadRevisions()
    }

    // MARK: - Load Revisions from Core Data

    func loadRevisions() {
        print("[FDXRevisionImporter DEBUG] loadRevisions() called")
        guard let context = context else {
            print("[FDXRevisionImporter DEBUG] loadRevisions() - no context, returning")
            return
        }

        context.perform { [weak self] in
            print("[FDXRevisionImporter DEBUG] loadRevisions() - performing fetch")
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScriptRevisionEntity")
            request.sortDescriptors = [
                NSSortDescriptor(key: "importedAt", ascending: false)
            ]

            do {
                let entities = try context.fetch(request)
                let revisions = entities.compactMap { entity -> StoredRevision? in
                    guard let id = entity.value(forKey: "id") as? UUID else { return nil }

                    return StoredRevision(
                        id: id,
                        colorName: entity.value(forKey: "colorName") as? String ?? "White",
                        fileName: entity.value(forKey: "fileName") as? String ?? "",
                        fileHash: entity.value(forKey: "fileHash") as? String ?? "",
                        importDate: entity.value(forKey: "importedAt") as? Date ?? Date(),
                        scenesAdded: (entity.value(forKey: "scenesAdded") as? Int) ?? 0,
                        scenesModified: (entity.value(forKey: "scenesModified") as? Int) ?? 0,
                        scenesRemoved: (entity.value(forKey: "scenesRemoved") as? Int) ?? 0,
                        notes: entity.value(forKey: "notes") as? String,
                        pageCount: (entity.value(forKey: "pageCount") as? Int) ?? 0,
                        sceneCount: (entity.value(forKey: "sceneCount") as? Int) ?? 0
                    )
                }

                DispatchQueue.main.async {
                    print("[FDXRevisionImporter DEBUG] Setting revisions - count: \(revisions.count)")
                    self?.revisions = revisions
                }
            } catch {
                print("[FDXRevisionImporter] Failed to load revisions: \(error)")
            }
        }
    }

    // MARK: - Import FDX Revision

    func importRevision(
        from url: URL,
        colorName: String,
        notes: String? = nil,
        compareWith previousRevisionId: UUID? = nil
    ) async -> RevisionImportResult {

        guard let context = context else {
            return RevisionImportResult(
                success: false,
                revisionId: nil,
                colorName: colorName,
                scenesAdded: 0,
                scenesModified: 0,
                scenesRemoved: 0,
                totalElements: 0,
                error: "Core Data context not configured"
            )
        }

        isImporting = true
        lastError = nil

        // Read and parse the FDX file
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            isImporting = false
            let errorMsg = "Failed to read FDX file: \(error.localizedDescription)"
            print("[FDXRevisionImporter] ERROR: \(errorMsg)")
            lastError = errorMsg
            return RevisionImportResult(
                success: false,
                revisionId: nil,
                colorName: colorName,
                scenesAdded: 0,
                scenesModified: 0,
                scenesRemoved: 0,
                totalElements: 0,
                error: errorMsg
            )
        }

        guard let parseResult = converter.convert(from: data) else {
            isImporting = false
            let error = "Failed to parse FDX file"
            lastError = error
            return RevisionImportResult(
                success: false,
                revisionId: nil,
                colorName: colorName,
                scenesAdded: 0,
                scenesModified: 0,
                scenesRemoved: 0,
                totalElements: 0,
                error: error
            )
        }

        // Calculate file hash for duplicate detection
        let fileHash = data.sha256Hash

        // Check for duplicate imports
        if isDuplicateRevision(hash: fileHash) {
            isImporting = false
            let error = "This revision has already been imported"
            lastError = error
            return RevisionImportResult(
                success: false,
                revisionId: nil,
                colorName: colorName,
                scenesAdded: 0,
                scenesModified: 0,
                scenesRemoved: 0,
                totalElements: parseResult.elements.count,
                error: error
            )
        }

        // Compare with previous revision if provided
        var scenesAdded = 0
        var scenesModified = 0
        var scenesRemoved = 0

        if let previousId = previousRevisionId,
           let previousData = loadRevisionData(id: previousId),
           let previousResult = converter.convert(from: previousData) {
            let comparison = FDXConverter.compareRevisions(original: previousResult, revised: parseResult)
            scenesAdded = comparison.added
            scenesModified = comparison.modified
            scenesRemoved = comparison.removed
        } else {
            // Count elements with revision marks as modified
            scenesModified = parseResult.elements.filter {
                $0.revisionColor != nil && $0.revisionColor?.lowercased() != "white"
            }.count
        }

        // Store in Core Data
        let revisionId = UUID()

        await context.perform {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "ScriptRevisionEntity", into: context)
            entity.setValue(revisionId, forKey: "id")
            entity.setValue(colorName, forKey: "colorName")
            entity.setValue(url.lastPathComponent, forKey: "fileName")
            entity.setValue(fileHash, forKey: "fileHash")
            entity.setValue(data, forKey: "fileData")
            entity.setValue(Int64(data.count), forKey: "fileSize")
            entity.setValue(Date(), forKey: "importedAt")
            entity.setValue(scenesAdded, forKey: "scenesAdded")
            entity.setValue(scenesModified, forKey: "scenesModified")
            entity.setValue(scenesRemoved, forKey: "scenesRemoved")
            entity.setValue(notes, forKey: "notes")
            entity.setValue(parseResult.pageCount, forKey: "pageCount")
            entity.setValue(parseResult.sceneCount, forKey: "sceneCount")

            do {
                try context.save()
            } catch {
                print("[FDXRevisionImporter] Save error: \(error)")
            }
        }

        loadRevisions()
        isImporting = false

        return RevisionImportResult(
            success: true,
            revisionId: revisionId,
            colorName: colorName,
            scenesAdded: scenesAdded,
            scenesModified: scenesModified,
            scenesRemoved: scenesRemoved,
            totalElements: parseResult.elements.count,
            error: nil
        )
    }

    // MARK: - Import from Current Screenplay Changes

    func createRevisionFromScreenplay(
        document: ScreenplayDocument,
        colorName: String,
        notes: String? = nil,
        previousDocument: ScreenplayDocument? = nil
    ) async -> RevisionImportResult {

        guard let context = context else {
            return RevisionImportResult(
                success: false,
                revisionId: nil,
                colorName: colorName,
                scenesAdded: 0,
                scenesModified: 0,
                scenesRemoved: 0,
                totalElements: 0,
                error: "Core Data context not configured"
            )
        }

        isImporting = true
        lastError = nil

        // Encode document to data for storage
        let documentData: Data
        do {
            documentData = try document.encode()
        } catch {
            isImporting = false
            let errorMsg = "Failed to encode screenplay document: \(error.localizedDescription)"
            print("[FDXRevisionImporter] ERROR: \(errorMsg)")
            lastError = errorMsg
            return RevisionImportResult(
                success: false,
                revisionId: nil,
                colorName: colorName,
                scenesAdded: 0,
                scenesModified: 0,
                scenesRemoved: 0,
                totalElements: 0,
                error: errorMsg
            )
        }

        let fileHash = documentData.sha256Hash

        // Calculate changes
        var scenesAdded = 0
        var scenesModified = 0
        var scenesRemoved = 0

        if let previous = previousDocument {
            let comparison = compareDocuments(original: previous, revised: document)
            scenesAdded = comparison.added
            scenesModified = comparison.modified
            scenesRemoved = comparison.removed
        }

        // Store revision
        let revisionId = UUID()

        await context.perform {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "ScriptRevisionEntity", into: context)
            entity.setValue(revisionId, forKey: "id")
            entity.setValue(colorName, forKey: "colorName")
            entity.setValue("\(document.title) - \(colorName) Revision", forKey: "fileName")
            entity.setValue(fileHash, forKey: "fileHash")
            entity.setValue(documentData, forKey: "fileData")
            entity.setValue(Int64(documentData.count), forKey: "fileSize")
            entity.setValue(Date(), forKey: "importedAt")
            entity.setValue(scenesAdded, forKey: "scenesAdded")
            entity.setValue(scenesModified, forKey: "scenesModified")
            entity.setValue(scenesRemoved, forKey: "scenesRemoved")
            entity.setValue(notes, forKey: "notes")
            entity.setValue(document.estimatedPageCount, forKey: "pageCount")
            entity.setValue(document.scenes.count, forKey: "sceneCount")

            do {
                try context.save()
            } catch {
                print("[FDXRevisionImporter] Save error: \(error)")
            }
        }

        loadRevisions()
        isImporting = false

        return RevisionImportResult(
            success: true,
            revisionId: revisionId,
            colorName: colorName,
            scenesAdded: scenesAdded,
            scenesModified: scenesModified,
            scenesRemoved: scenesRemoved,
            totalElements: document.elements.count,
            error: nil
        )
    }

    // MARK: - Delete Revision

    func deleteRevision(id: UUID) {
        guard let context = context else { return }

        context.perform { [weak self] in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScriptRevisionEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            do {
                if let entity = try context.fetch(request).first {
                    context.delete(entity)
                    try context.save()
                }
            } catch {
                print("[FDXRevisionImporter] ERROR: Failed to delete revision: \(error)")
            }

            DispatchQueue.main.async {
                self?.loadRevisions()
            }
        }
    }

    // MARK: - Clear All Revisions

    /// Clears all stored revisions from Core Data - called when a script is deleted
    func clearAllRevisions() {
        guard let context = context else { return }

        print("[FDXRevisionImporter] Clearing all revisions...")

        context.perform { [weak self] in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScriptRevisionEntity")

            do {
                let entities = try context.fetch(request)
                print("[FDXRevisionImporter] Deleting \(entities.count) revisions")

                for entity in entities {
                    context.delete(entity)
                }

                try context.save()
                print("[FDXRevisionImporter] All revisions cleared successfully")
            } catch {
                print("[FDXRevisionImporter] ERROR: Failed to clear revisions: \(error)")
            }

            DispatchQueue.main.async {
                self?.revisions = []
                self?.currentDraftId = nil
                self?.lastError = nil
            }
        }
    }

    /// Resets the importer state without touching Core Data
    func resetState() {
        currentDraftId = nil
        lastError = nil
        isImporting = false
    }

    // MARK: - Load Revision Document

    func loadRevisionDocument(id: UUID) -> ScreenplayDocument? {
        guard let data = loadRevisionData(id: id) else { return nil }

        // Try to decode as ScreenplayDocument first
        do {
            return try ScreenplayDocument.decode(from: data)
        } catch {
            print("[FDXRevisionImporter] INFO: Data is not ScreenplayDocument format, trying FDX parse: \(error)")
        }

        // Otherwise try to parse as FDX
        if let result = converter.convert(from: data) {
            return result.document
        }

        print("[FDXRevisionImporter] ERROR: Failed to load revision document - neither ScreenplayDocument nor FDX format")
        return nil
    }

    // MARK: - Private Helpers

    private func loadRevisionData(id: UUID) -> Data? {
        guard let context = context else { return nil }

        var result: Data?

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScriptRevisionEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                if let entity = try context.fetch(request).first {
                    result = entity.value(forKey: "fileData") as? Data
                }
            } catch {
                print("[FDXRevisionImporter] ERROR: Failed to load revision data: \(error)")
            }
        }

        return result
    }

    private func isDuplicateRevision(hash: String) -> Bool {
        guard let context = context else { return false }

        var isDuplicate = false

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScriptRevisionEntity")
            request.predicate = NSPredicate(format: "fileHash == %@", hash)
            request.fetchLimit = 1

            do {
                let results = try context.fetch(request)
                isDuplicate = !results.isEmpty
            } catch {
                print("[FDXRevisionImporter] ERROR: Failed to check for duplicate revision: \(error)")
            }
        }

        return isDuplicate
    }

    private func compareDocuments(original: ScreenplayDocument, revised: ScreenplayDocument) -> (added: Int, modified: Int, removed: Int) {
        var added = 0
        var removed = 0
        var modified = 0

        let originalScenes = original.elements.filter { $0.type == .sceneHeading }
        let revisedScenes = revised.elements.filter { $0.type == .sceneHeading }

        let originalHeadings = Set(originalScenes.map { $0.text.uppercased() })
        let revisedHeadings = Set(revisedScenes.map { $0.text.uppercased() })

        // New scenes
        for heading in revisedHeadings {
            if !originalHeadings.contains(heading) {
                added += 1
            }
        }

        // Removed scenes
        for heading in originalHeadings {
            if !revisedHeadings.contains(heading) {
                removed += 1
            }
        }

        // Modified scenes (scenes that exist in both but have different content)
        let originalById = Dictionary(uniqueKeysWithValues: original.elements.map { ($0.id, $0) })
        let revisedById = Dictionary(uniqueKeysWithValues: revised.elements.map { ($0.id, $0) })

        for (id, revisedElement) in revisedById {
            if let originalElement = originalById[id] {
                if originalElement.text != revisedElement.text {
                    modified += 1
                }
            }
        }

        return (added, modified, removed)
    }
}

// MARK: - Data Extension for SHA256 Hash

extension Data {
    var sha256Hash: String {
        // Simple hash implementation using CommonCrypto
        var hash = [UInt8](repeating: 0, count: 32)
        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import CommonCrypto
import CommonCrypto
