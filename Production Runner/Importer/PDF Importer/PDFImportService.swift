//
//  PDFImportService.swift
//  Production Runner
//
//  Service for importing screenplay PDFs into Core Data.
//  Follows the same pattern as FDXImportService for consistency.
//

import Foundation
import CoreData
import PDFKit

// MARK: - Import Error

public enum PDFImportError: Error, LocalizedError {
    case invalidData
    case pdfParseFailed(String)
    case noScenesFound
    case missingProject
    case contextSaveFailed(Error)
    case accessDenied

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid or empty PDF data."
        case .pdfParseFailed(let reason):
            return "PDF parse failed: \(reason)"
        case .noScenesFound:
            return "No scenes were found in the PDF. The document may not be a screenplay or may use non-standard formatting."
        case .missingProject:
            return "Missing ProjectEntity reference."
        case .contextSaveFailed(let err):
            return "Failed to save Core Data: \(err.localizedDescription)"
        case .accessDenied:
            return "Access denied to PDF file."
        }
    }
}

// MARK: - Import Progress

/// Progress callback for UI updates during import
public typealias PDFImportProgressCallback = (PDFImportProgress) -> Void

public struct PDFImportProgress {
    public let stage: PDFImportStage
    public let progress: Double // 0.0 to 1.0
    public let message: String
    public let detail: String

    public init(stage: PDFImportStage, progress: Double, message: String, detail: String = "") {
        self.stage = stage
        self.progress = progress
        self.message = message
        self.detail = detail
    }
}

public enum PDFImportStage {
    case preparing
    case extractingText
    case parsingElements
    case classifyingScenes
    case savingToDatabase
    case complete
    case failed
}

// MARK: - PDF Import Service

public final class PDFImportService {

    public static let shared = PDFImportService()

    private let extractor = PDFTextExtractor.shared
    private let parser = ScreenplayPDFParser.shared

    // MARK: - Public API

    /// Import a screenplay PDF from URL
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - context: Core Data context
    ///   - project: ProjectEntity to associate scenes with
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Array of FDXSceneDraft (for compatibility with existing code)
    @discardableResult
    public func importPDF(
        from url: URL,
        into context: NSManagedObjectContext,
        for project: NSManagedObject,
        progressCallback: PDFImportProgressCallback? = nil
    ) throws -> [FDXSceneDraft] {

        progressCallback?(PDFImportProgress(
            stage: .preparing,
            progress: 0.05,
            message: "Preparing to import...",
            detail: url.lastPathComponent
        ))

        // Access security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw PDFImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Load PDF document
        guard let document = PDFDocument(url: url) else {
            throw PDFImportError.invalidData
        }

        return try importPDF(
            from: document,
            sourceURL: url,
            into: context,
            for: project,
            progressCallback: progressCallback
        )
    }

    /// Import a screenplay PDF from Data
    /// - Parameters:
    ///   - data: PDF data
    ///   - context: Core Data context
    ///   - project: ProjectEntity to associate scenes with
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Array of FDXSceneDraft (for compatibility with existing code)
    @discardableResult
    public func importPDF(
        from data: Data,
        into context: NSManagedObjectContext,
        for project: NSManagedObject,
        progressCallback: PDFImportProgressCallback? = nil
    ) throws -> [FDXSceneDraft] {
        guard !data.isEmpty else { throw PDFImportError.invalidData }

        guard let document = PDFDocument(data: data) else {
            throw PDFImportError.invalidData
        }

        return try importPDF(
            from: document,
            sourceURL: nil,
            into: context,
            for: project,
            progressCallback: progressCallback
        )
    }

    /// Import a screenplay PDF from PDFDocument
    @discardableResult
    public func importPDF(
        from document: PDFDocument,
        sourceURL: URL?,
        into context: NSManagedObjectContext,
        for project: NSManagedObject,
        progressCallback: PDFImportProgressCallback? = nil
    ) throws -> [FDXSceneDraft] {

        // Step 1: Extract text with position data
        progressCallback?(PDFImportProgress(
            stage: .extractingText,
            progress: 0.15,
            message: "Extracting text from PDF...",
            detail: "Reading \(document.pageCount) pages"
        ))

        let extraction: PDFExtractionResult
        do {
            extraction = try extractor.extract(from: document, sourceURL: sourceURL)
        } catch {
            throw PDFImportError.pdfParseFailed(error.localizedDescription)
        }

        print("📄 [PDFImport] Extracted \(extraction.allLines.count) lines from \(extraction.pageCount) pages")

        // Step 2: Parse elements
        progressCallback?(PDFImportProgress(
            stage: .parsingElements,
            progress: 0.35,
            message: "Analyzing screenplay structure...",
            detail: "Classifying elements"
        ))

        let parseResult = parser.parse(extraction)

        print("📄 [PDFImport] Parsed \(parseResult.elements.count) elements, \(parseResult.scenes.count) scenes")

        if !parseResult.warnings.isEmpty {
            for warning in parseResult.warnings {
                print("⚠️ [PDFImport] \(warning)")
            }
        }

        // Step 3: Convert to FDXSceneDraft for compatibility
        progressCallback?(PDFImportProgress(
            stage: .classifyingScenes,
            progress: 0.50,
            message: "Processing scenes...",
            detail: "\(parseResult.scenes.count) scenes found"
        ))

        let drafts = convertToFDXSceneDrafts(parseResult.scenes)

        if drafts.isEmpty {
            throw PDFImportError.noScenesFound
        }

        // Step 4: Save to Core Data
        progressCallback?(PDFImportProgress(
            stage: .savingToDatabase,
            progress: 0.70,
            message: "Saving scenes...",
            detail: "Writing to database"
        ))

        try context.performAndWait {
            for (index, draft) in drafts.enumerated() {
                let scene = NSEntityDescription.insertNewObject(forEntityName: "SceneEntity", into: context)
                assign(draft, toScene: scene, context: context)

                // Attach to project
                if let rel = scene.entity.relationshipsByName["project"] {
                    scene.setValue(project, forKey: rel.name)
                }

                // Progress update for each scene
                let sceneProgress = 0.70 + (Double(index + 1) / Double(drafts.count)) * 0.25
                progressCallback?(PDFImportProgress(
                    stage: .savingToDatabase,
                    progress: sceneProgress,
                    message: "Saving scenes...",
                    detail: "Scene \(draft.numberString): \(draft.headingText.prefix(30))..."
                ))
            }

            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                throw PDFImportError.contextSaveFailed(error)
            }
        }

        progressCallback?(PDFImportProgress(
            stage: .complete,
            progress: 1.0,
            message: "Import complete!",
            detail: "\(drafts.count) scenes imported"
        ))

        print("✅ [PDFImport] Successfully imported \(drafts.count) scenes")

        return drafts
    }

    // MARK: - Scene Deletion (matches FDXImportService)

    /// Delete all existing scenes for a project before import
    public func deleteAllScenes(for project: NSManagedObject, in context: NSManagedObjectContext) throws {
        try context.performAndWait {
            // Fetch all scenes for this project
            let sceneFetch = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
            sceneFetch.predicate = NSPredicate(format: "project == %@", project)
            let scenes = try context.fetch(sceneFetch)

            // Delete all shots associated with these scenes
            let shotFetch = NSFetchRequest<NSManagedObject>(entityName: "ShotEntity")
            shotFetch.predicate = NSPredicate(format: "scene IN %@", scenes)
            let shots = try context.fetch(shotFetch)
            for shot in shots {
                context.delete(shot)
            }

            // Clear scene references from ShootDayEntity
            let shootDayFetch = NSFetchRequest<NSManagedObject>(entityName: "ShootDayEntity")
            if let shootDays = try? context.fetch(shootDayFetch) {
                for shootDay in shootDays {
                    if shootDay.value(forKey: "scenes") as? NSSet != nil {
                        shootDay.setValue(NSSet(), forKey: "scenes")
                    }
                }
            }

            // Delete all scenes
            for scene in scenes {
                context.delete(scene)
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - Conversion

    private func convertToFDXSceneDrafts(_ scenes: [PDFParsedScene]) -> [FDXSceneDraft] {
        return scenes.map { scene in
            // Convert page eighths to string format like "4/8"
            var pageLengthStr: String? = nil
            if let eighths = scene.pageLengthEighths {
                let pages = eighths / 8
                let remainder = eighths % 8
                if pages > 0 && remainder > 0 {
                    pageLengthStr = "\(pages) \(remainder)/8"
                } else if pages > 0 {
                    pageLengthStr = "\(pages)"
                } else {
                    pageLengthStr = "\(remainder)/8"
                }
            }

            return FDXSceneDraft(
                numberString: scene.numberString,
                headingText: scene.headingText,
                pageLength: pageLengthStr,
                pageNumber: scene.pageNumber,
                scriptText: scene.scriptText,
                sceneFDX: nil, // No FDX XML from PDF import
                ordinal: scene.ordinal
            )
        }
    }

    // MARK: - Core Data Assignment

    private func assign(_ draft: FDXSceneDraft, toScene scene: NSManagedObject, context: NSManagedObjectContext) {
        func setIfExists(_ key: String, _ value: Any?) {
            guard scene.entity.attributesByName.keys.contains(key) else { return }
            scene.setValue(value, forKey: key)
        }

        // Generate UUID
        if scene.entity.attributesByName.keys.contains("id"),
           scene.value(forKey: "id") == nil {
            scene.setValue(UUID(), forKey: "id")
        }

        // Scene number
        setIfExists("numberString", draft.numberString)
        setIfExists("number", draft.numberString)
        setIfExists("numberRaw", draft.numberString)

        // Heading
        let safeHeading = draft.headingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "SCENE \(draft.numberString)".trimmingCharacters(in: .whitespacesAndNewlines)
            : draft.headingText
        setIfExists("sceneSlug", safeHeading)
        setIfExists("heading", safeHeading)
        setIfExists("title", safeHeading)

        // Parse heading components
        let (locType, scriptLoc, tod) = parseHeadingComponents(draft.headingText)
        setIfExists("locationType", locType)
        setIfExists("scriptLocation", scriptLoc)
        setIfExists("timeOfDay", tod)

        // Script text
        if let body = draft.scriptText, !body.isEmpty {
            setIfExists("scriptText", body)
        }

        // Page info
        if let len = draft.pageLength {
            setIfExists("pageEighthsString", len)
            if let e = parseEighths(len) {
                setIfExists("pageEighths", e)
            }
        }

        if let pageNum = draft.pageNumber {
            setIfExists("pageNumber", pageNum)
            setIfExists("page", pageNum)
            setIfExists("scriptPage", pageNum)
        }

        // Timestamps
        if scene.entity.attributesByName.keys.contains("createdAt"),
           scene.value(forKey: "createdAt") == nil {
            scene.setValue(Date(), forKey: "createdAt")
        }
        if scene.entity.attributesByName.keys.contains("updatedAt") {
            scene.setValue(Date(), forKey: "updatedAt")
        }

        // Sort order
        setIfExists("sortIndex", draft.ordinal)
        setIfExists("sortOrder", draft.ordinal)
        setIfExists("sequence", draft.ordinal)
        setIfExists("order", draft.ordinal)
        setIfExists("displayOrder", draft.ordinal)
        setIfExists("sceneIndex", draft.ordinal)

        // Mark import source
        setIfExists("importedFrom", "PDF")
    }

    // MARK: - Utilities

    // Convert strings like "4/8", "1 4/8", "2 0/8" to total eighths (Int16).
    private func parseEighths(_ s: String) -> Int16? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Handle formats like "1 4/8" (1 page + 4/8), "4/8", "2 0/8" (2 pages)
        let parts = trimmed.split(separator: " ")
        var totalEighths: Int16 = 0

        for part in parts {
            let str = String(part)
            if str.contains("/") {
                // Parse fraction like "4/8"
                let components = str.split(separator: "/")
                if components.count == 2,
                   let numerator = Int16(components[0]),
                   let denominator = Int16(components[1]),
                   denominator > 0 {
                    totalEighths += numerator
                }
            } else if let whole = Int16(str) {
                // Whole number of pages
                totalEighths += whole * 8
            }
        }

        return totalEighths > 0 ? totalEighths : nil
    }

    // Parse a scene heading like "INT. KITCHEN - DAY" into components.
    // Returns (locationType, scriptLocation, timeOfDay). All strings are trimmed; may be empty if not found.
    private func parseHeadingComponents(_ heading: String) -> (String, String, String) {
        var s = heading.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Detect INT/EXT
        var locationType = ""
        if s.hasPrefix("INT./EXT.") || s.hasPrefix("INT/EXT.") || s.hasPrefix("INT./EXT") || s.hasPrefix("INT/EXT") {
            locationType = "INT/EXT"
            s = String(s.dropFirst(s.hasPrefix("INT./EXT.") ? 9 : 8)).trimmingCharacters(in: .whitespaces)
        } else if s.hasPrefix("INT.") || s.hasPrefix("INT ") {
            locationType = "INT"
            s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if s.hasPrefix("EXT.") || s.hasPrefix("EXT ") {
            locationType = "EXT"
            s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if s.hasPrefix("I/E.") || s.hasPrefix("I/E ") {
            locationType = "INT/EXT"
            s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }

        // Split by " - " for time of day
        var scriptLocation = s
        var timeOfDay = ""

        if let dashRange = s.range(of: " - ") {
            scriptLocation = String(s[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            timeOfDay = String(s[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        return (locationType, scriptLocation, timeOfDay)
    }
}
