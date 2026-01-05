//
//  FDXImportService.swift
//  Production Runner
//
//  Drop-in service that parses Final Draft (.fdx) and persists Scenes to Core Data.
//  Keep API surface small and stable so existing UIs can call it without depending on Breakdowns UI.
//
//  NOTE: This is intentionally self-contained. You can safely delete any importer UI from Breakdowns.swift.
//

import Foundation
import CoreData

// FDXSceneDraft is now defined in ScriptDifferTypes.swift to avoid duplication

public enum FDXImportError: Error, LocalizedError {
    case invalidData
    case xmlParseFailed(String)
    case missingProject
    case contextSaveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid or empty FDX data."
        case .xmlParseFailed(let reason): return "FDX XML parse failed: \(reason)"
        case .missingProject: return "Missing ProjectEntity reference."
        case .contextSaveFailed(let err): return "Failed to save Core Data: \(err.localizedDescription)"
        }
    }
}

public final class FDXImportService: NSObject {
    public static let shared = FDXImportService()

    // Clean up all existing scenes and related data before import
    public func deleteAllScenes(for project: NSManagedObject, in context: NSManagedObjectContext) throws {
        print("🔴 [FDXImportService] deleteAllScenes CALLED for project: \(project.objectID)")
        try context.performAndWait {
            // Fetch all scenes for this project
            let sceneFetch = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
            sceneFetch.predicate = NSPredicate(format: "project == %@", project)
            let scenes = try context.fetch(sceneFetch)
            print("🔴 [FDXImportService] Found \(scenes.count) scenes to delete")

            // Delete all shots associated with these scenes
            let shotFetch = NSFetchRequest<NSManagedObject>(entityName: "ShotEntity")
            shotFetch.predicate = NSPredicate(format: "scene IN %@", scenes)
            let shots = try context.fetch(shotFetch)
            print("🔴 [FDXImportService] Found \(shots.count) shots to delete")
            for shot in shots {
                context.delete(shot)
            }

            // Clear scene references from ShootDayEntity (if it exists)
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
            print("🔴 [FDXImportService] Deleted \(scenes.count) scenes")

            // Save changes
            if context.hasChanges {
                try context.save()
                print("🔴 [FDXImportService] Context saved after deletion")
            } else {
                print("🔴 [FDXImportService] No changes to save after deletion")
            }
        }
    }

    // Primary entry point: import from file URL
    @discardableResult
    public func importFDX(from url: URL, into context: NSManagedObjectContext, for project: NSManagedObject, breakdownVersionId: UUID? = nil) throws -> [FDXSceneDraft] {
        print("🔴 [FDXImportService] importFDX(URL) CALLED - url: \(url.lastPathComponent)")
        let data = try Data(contentsOf: url)
        return try importFDX(from: data, into: context, for: project, breakdownVersionId: breakdownVersionId)
    }

    // Secondary entry: import from Data
    @discardableResult
    public func importFDX(from data: Data, into context: NSManagedObjectContext, for project: NSManagedObject, breakdownVersionId: UUID? = nil) throws -> [FDXSceneDraft] {
        let projectID = project.value(forKey: "id") as? UUID
        print("🔴 [FDXImportService] importFDX(Data) CALLED - data size: \(data.count) bytes")
        print("🔴 [FDXImportService] project objectID: \(project.objectID)")
        print("🔴 [FDXImportService] project UUID: \(projectID?.uuidString ?? "nil")")
        guard !data.isEmpty else { throw FDXImportError.invalidData }

        let parser = XMLParser(data: data)
        let collector = FDXCollector()
        parser.delegate = collector

        if !parser.parse() {
            let reason = parser.parserError?.localizedDescription ?? "Unknown parse error"
            throw FDXImportError.xmlParseFailed(reason)
        }

        // Fallback: if the collector found fewer than 100 headings, try a regex scan.
        if collector.scenes.count < 100 {
            if let text = String(data: data, encoding: .utf8) {
                let regex = try? NSRegularExpression(pattern: #"<Paragraph[^>]*Type="[^"]*Scene Heading[^"]*"[^>]*>(.*?)</Paragraph>"#,
                                                     options: [.dotMatchesLineSeparators, .caseInsensitive])
                let textRegex = try? NSRegularExpression(pattern: #"<Text>(.*?)</Text>"#, options: [.dotMatchesLineSeparators, .caseInsensitive])
                let propsRegex = try? NSRegularExpression(pattern: #"<SceneProperties[^>]*>"#, options: [.caseInsensitive])
                let lenAttr = try? NSRegularExpression(pattern: #"Length="([^"]+)""#, options: [])
                let pageAttr = try? NSRegularExpression(pattern: #"Page="([^"]+)""#, options: [])
                let numAttr  = try? NSRegularExpression(pattern: #"Number="([^"]+)""#, options: [])
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                var drafts: [FDXSceneDraft] = []
                if let m = regex?.matches(in: text, options: [], range: range) {
                    for (idx, match) in m.enumerated() {
                        let paraRange = match.range(at: 1)
                        guard let swiftRange = Range(paraRange, in: text) else { continue }
                        let paraInner = String(text[swiftRange])
                        var heading = ""
                        var lengthStr: String? = nil
                        var pageStr: String? = nil
                        var numStr: String? = nil
                        if let t = textRegex?.firstMatch(in: paraInner, options: [], range: NSRange(paraInner.startIndex..<paraInner.endIndex, in: paraInner)),
                           let r = Range(t.range(at: 1), in: paraInner) {
                            // Preserve heading exactly as found inside <Text>…</Text>
                            heading = String(paraInner[r])
                        }
                        if let p = propsRegex?.firstMatch(in: paraInner, options: [], range: NSRange(paraInner.startIndex..<paraInner.endIndex, in: paraInner)) {
                            let propStr = (paraInner as NSString).substring(with: p.range)
                            if let l = lenAttr?.firstMatch(in: propStr, options: [], range: NSRange(propStr.startIndex..<propStr.endIndex, in: propStr)),
                               let lr = Range(l.range(at: 1), in: propStr) {
                                lengthStr = String(propStr[lr])
                            }
                            if let pg = pageAttr?.firstMatch(in: propStr, options: [], range: NSRange(propStr.startIndex..<propStr.endIndex, in: propStr)),
                               let pr = Range(pg.range(at: 1), in: propStr) {
                                pageStr = String(propStr[pr])
                            }
                            if let nm = numAttr?.firstMatch(in: propStr, options: [], range: NSRange(propStr.startIndex..<propStr.endIndex, in: propStr)),
                               let nr = Range(nm.range(at: 1), in: propStr) {
                                numStr = String(propStr[nr])
                            }
                        }
                        // Support a nested <SceneNumber> element
                        if numStr == nil {
                            if let sn = try? NSRegularExpression(pattern: #"<SceneNumber>(.*?)</SceneNumber>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                               let m2 = sn.firstMatch(in: paraInner, options: [], range: NSRange(paraInner.startIndex..<paraInner.endIndex, in: paraInner)),
                               let r2 = Range(m2.range(at: 1), in: paraInner) {
                                let candidate = String(paraInner[r2]).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !candidate.isEmpty { numStr = candidate }
                            }
                        }
                        // ordinal = 1-based index in fallback order; no scriptText from fallback
                        drafts.append(FDXSceneDraft(numberString: numStr ?? "", headingText: heading, pageLength: lengthStr, pageNumber: pageStr, scriptText: nil, sceneFDX: nil, ordinal: idx + 1))
                    }
                }
                if drafts.count > collector.scenes.count {
                    // Use fallback results
                    collector.scenes = drafts
                }
            }
        }

        // Persist minimal Scene info. This assumes your Core Data has SceneEntity with:
        // - id (UUID)
        // - numberString (String)
        // - sceneSlug (String)  // heading text
        // - pageEighthsString (String)  // "4/8" etc. optional
        // - createdAt / updatedAt (Date) optional
        //
        // and a relationship from SceneEntity -> ProjectEntity (to-many inverse).
        //
        // If your attribute names differ, adjust the KVC keys in `assign(_:toScene:context:)` below.
        var drafts = collector.scenes

        // Attach RAW FDX fragments per scene for exact-fidelity rendering.
        if let whole = String(data: data, encoding: .utf8) {
            // Regex to capture from a Scene Heading paragraph up to (but not including) the next Scene Heading paragraph.
            // Groups:
            //  1 = the heading paragraph
            //  2 = all content until the next heading (non-greedy)
            let pattern = #"(?s)(<Paragraph[^>]*Type="[^"]*Scene Heading[^"]*"[^>]*>.*?</Paragraph>)(.*?)(?=(<Paragraph[^>]*Type="[^"]*Scene Heading[^"]*"[^>]*>)|$)"#
            if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(whole.startIndex..<whole.endIndex, in: whole)
                let matches = re.matches(in: whole, options: [], range: range)
                var fragments: [String] = []
                fragments.reserveCapacity(matches.count)
                for m in matches {
                    guard m.numberOfRanges >= 3 else { continue }
                    let r1 = m.range(at: 1)
                    let r2 = m.range(at: 2)
                    if let R1 = Range(r1, in: whole), let R2 = Range(r2, in: whole) {
                        let xml = String(whole[R1]) + String(whole[R2])
                        fragments.append(xml)
                    }
                }
                // Map by ordinal order; if counts differ, fill while available
                let count = min(drafts.count, fragments.count)
                if count > 0 {
                    for i in 0..<count {
                        drafts[i].sceneFDX = fragments[i]
                    }
                }
            }
        }

        // --- Backfill missing headings from each scene fragment ---
        if !drafts.isEmpty {
            let headingRE = try? NSRegularExpression(
                pattern: #"<Paragraph[^>]*Type="[^"]*Scene Heading[^"]*"[^>]*>.*?<Text>(.*?)</Text>.*?</Paragraph>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
            for i in drafts.indices {
                var heading = drafts[i].headingText.trimmingCharacters(in: .whitespacesAndNewlines)
                if heading.isEmpty, let xml = drafts[i].sceneFDX, !xml.isEmpty {
                    let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
                    if let m = headingRE?.firstMatch(in: xml, options: [], range: range),
                       let r = Range(m.range(at: 1), in: xml) {
                        heading = String(xml[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                        drafts[i].headingText = heading
                    }
                }
            }
        }

        // --- Final fallback: synthesize a readable heading if still empty ---
        for i in drafts.indices {
            var h = drafts[i].headingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if h.isEmpty {
                // Try to derive from components parsed out of the original headingText (may be empty), else use number.
                let (locType, scriptLoc, tod) = parseHeadingComponents(h)
                if !locType.isEmpty || !scriptLoc.isEmpty || !tod.isEmpty {
                    var pieces: [String] = []
                    if !locType.isEmpty  { pieces.append(locType + ".") }
                    if !scriptLoc.isEmpty { pieces.append(scriptLoc) }
                    var synthesized = pieces.joined(separator: " ")
                    if !tod.isEmpty { synthesized += " - \(tod)" }
                    h = synthesized.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if h.isEmpty {
                    let n = drafts[i].numberString.trimmingCharacters(in: .whitespacesAndNewlines)
                    h = n.isEmpty ? "SCENE" : "SCENE \(n)"
                }
                drafts[i].headingText = h
            }
        }

        try context.performAndWait {
            // Cast project to SceneEntity-compatible type for proper relationship
            // This ensures the Core Data relationship is properly established
            let projectForRelationship: NSManagedObject = project

            for (index, d) in drafts.enumerated() {
                let scene = NSEntityDescription.insertNewObject(forEntityName: "SceneEntity", into: context)
                assign(d, toScene: scene, context: context)

                // CRITICAL: Set project relationship directly using KVC
                // This works regardless of whether project is NSManagedObject or ProjectEntity
                scene.setValue(projectForRelationship, forKey: "project")

                if index < 3 {
                    // Verify the relationship was set
                    let setProject = scene.value(forKey: "project") as? NSManagedObject
                    print("🔴 [FDXImportService] Set project relationship for scene[\(index)]: '\(d.numberString)' - project set: \(setProject != nil)")
                }

                // Tag scene with breakdown version ID for version-based filtering
                if let versionId = breakdownVersionId,
                   scene.entity.attributesByName.keys.contains("breakdownVersionId") {
                    scene.setValue(versionId, forKey: "breakdownVersionId")
                }
            }
            do {
                if context.hasChanges {
                    try context.save()
                    print("🔴 [FDXImportService] ✅ Saved \(drafts.count) scenes to context")

                    // Verify scenes were created with correct project
                    let verifyFetch = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
                    verifyFetch.predicate = NSPredicate(format: "project == %@", project)
                    let verifiedScenes = try context.fetch(verifyFetch)
                    print("🔴 [FDXImportService] ✅ Verified \(verifiedScenes.count) scenes with project UUID: \(projectID?.uuidString ?? "nil")")

                    // ALERT if verification shows 0 scenes despite creating them
                    if verifiedScenes.count == 0 && drafts.count > 0 {
                        print("🔴 [FDXImportService] ⚠️⚠️⚠️ CRITICAL: Created \(drafts.count) scenes but verification shows 0 linked to project!")
                        // Check how many scenes have nil project
                        let allScenesFetch = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
                        let allScenes = try context.fetch(allScenesFetch)
                        var orphanCount = 0
                        for s in allScenes {
                            if s.value(forKey: "project") == nil {
                                orphanCount += 1
                            }
                        }
                        print("🔴 [FDXImportService] Total scenes: \(allScenes.count), orphans (project=nil): \(orphanCount)")
                    }
                }
            } catch {
                throw FDXImportError.contextSaveFailed(error)
            }
        }
        return drafts
    }

    // Convert strings like "4/8", "1 4/8", "2 0/8" to total eighths (Int16).
    internal func parseEighths(_ s: String) -> Int16? {
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
    internal func parseHeadingComponents(_ heading: String) -> (String, String, String) {
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

    private func assign(_ draft: FDXSceneDraft, toScene scene: NSManagedObject, context: NSManagedObjectContext) {
        // Best-effort KVC writes; ignore missing keys to avoid crashes in varying schemas.
        func setIfExists(_ key: String, _ value: Any?) {
            guard scene.entity.attributesByName.keys.contains(key) else {
                print("⚠️ [FDXImport] Key '\(key)' not found in SceneEntity attributes")
                return
            }
            scene.setValue(value, forKey: key)
            if key == "number" {
                print("✅ [FDXImport] Set 'number' = '\(value ?? "nil")' for scene (draft.numberString='\(draft.numberString)')")
            }
        }

        // DEBUG: Log what we're about to import
        print("📥 [FDXImport] Assigning draft: numberString='\(draft.numberString)', heading='\(draft.headingText.prefix(40))...'")
        print("📥 [FDXImport] SceneEntity attributes: \(scene.entity.attributesByName.keys.sorted())")
        if scene.entity.attributesByName.keys.contains("id"),
           scene.value(forKey: "id") == nil {
            scene.setValue(UUID(), forKey: "id")
        }
        setIfExists("numberString", draft.numberString)
        let safeHeading = draft.headingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "SCENE \(draft.numberString)".trimmingCharacters(in: .whitespacesAndNewlines) : draft.headingText
        setIfExists("sceneSlug", safeHeading)
        // Derive standard heading components used by Scheduler/Breakdowns lists
        let (locType, scriptLoc, tod) = parseHeadingComponents(draft.headingText)
        setIfExists("locationType", locType)     // e.g., INT / EXT / INT/EXT
        setIfExists("scriptLocation", scriptLoc) // e.g., KITCHEN
        setIfExists("timeOfDay", tod)            // e.g., DAY / NIGHT
        // Also write to 'heading' or 'title' if those exist in schema
        setIfExists("heading", safeHeading)
        setIfExists("title", safeHeading)
        // Persist full scene body if available
        if let body = draft.scriptText, !body.isEmpty {
            setIfExists("scriptText", body)
        }
        if let len = draft.pageLength {
            setIfExists("pageEighthsString", len)
            if let e = parseEighths(len) {
                setIfExists("pageEighths", e)
            }
        }
        if let pageNum = draft.pageNumber {
            print("✅ FDXImport: Storing page number '\(pageNum)' for scene \(draft.numberString)")
            setIfExists("pageNumber", pageNum)
            setIfExists("page", pageNum)
            setIfExists("scriptPage", pageNum)
        } else {
            print("⚠️ FDXImport: No page number available for scene \(draft.numberString)")
        }
        if scene.entity.attributesByName.keys.contains("createdAt"),
           scene.value(forKey: "createdAt") == nil {
            scene.setValue(Date(), forKey: "createdAt")
        }
        if scene.entity.attributesByName.keys.contains("updatedAt") {
            scene.setValue(Date(), forKey: "updatedAt")
        }
        // Map numberString to common alternatives if present
        setIfExists("number", draft.numberString)
        setIfExists("numberRaw", draft.numberString)
        // Persist a stable import order for precise numerical listing 1,2,3...
        setIfExists("sortIndex", draft.ordinal)
        setIfExists("sortOrder", draft.ordinal)
        setIfExists("sequence", draft.ordinal)
        setIfExists("order", draft.ordinal)
        setIfExists("displayOrder", draft.ordinal)
        setIfExists("sceneIndex", draft.ordinal)

        // Persist raw FDX if the schema provides a place for it
        if let xml = draft.sceneFDX, !xml.isEmpty {
            setIfExists("scriptFDX", xml)
            setIfExists("fdxRaw", xml)
            setIfExists("fdxXML", xml)
            setIfExists("sourceFDX", xml)
        }
    }
}

// MARK: - XML Collector
// Detects every <Paragraph Type="...Scene Heading..."> as a heading.
// Accumulates all non-heading paragraphs until the next heading and stores them as scriptText.
private final class FDXCollector: NSObject, XMLParserDelegate {
    private var path: [String] = []
    fileprivate var scenes: [FDXSceneDraft] = []
    private var ordinalCounter: Int = 0

    // Heading context
    private var currentIsSceneHeading = false
    private var currentNumberString: String = ""
    private var currentHeadingText: String = ""
    private var currentPageLength: String? = nil
    private var currentPageNumber: String? = nil
    private var bufferingText = false

    // Open scene accumulator (body between headings)
    private var hasOpenScene = false
    private var openNumberString: String = ""
    private var openHeadingText: String = ""
    private var openPageLength: String? = nil
    private var openPageNumber: String? = nil
    private var openBody: [String] = []

    // Paragraph buffering for non-heading paragraphs
    private var bufferingParaText = false
    private var currentParaText = ""
    private var currentParaType = ""

    // Case-insensitive attribute getter (FDX may vary attribute capitalization)
    private func attr(_ dict: [String:String], _ key: String) -> String? {
        if let v = dict[key] { return v }
        let lower = key.lowercased()
        return dict.first(where: { $0.key.lowercased() == lower })?.value
    }

    // Buffer for <SceneNumber> or <Number> inside a heading paragraph
    private var bufferingSceneNumber = false
    private var currentSceneNumberText = ""

    private var strikeDepth = 0

    private func formatParagraph(type: String, text: String) -> String {
        let preserved = text.replacingOccurrences(of: "\r", with: "")
        let t = preserved
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        switch type.lowercased() {
        case let s where s.contains("character"):
            return "\n\(t.uppercased())"
        case let s where s.contains("parenthetical"):
            return "(\(t))"
        case let s where s.contains("dialogue"):
            return t
        case let s where s.contains("transition"):
            return "\n\(t.uppercased())"
        default:
            return t // Action, shot, general text
        }
    }

    private func finalizeOpenSceneIfNeeded() {
        guard hasOpenScene else { return }
        let body = openBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        ordinalCounter += 1

        // If no scene number was found in the FDX, auto-generate one based on ordinal
        let finalNumberString: String
        if openNumberString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalNumberString = "\(ordinalCounter)"
            print("⚠️ FDXCollector: No scene number in FDX, auto-generating: '\(finalNumberString)'")
        } else {
            finalNumberString = openNumberString
        }

        let draft = FDXSceneDraft(
            numberString: finalNumberString,
            headingText: openHeadingText,              // preserve exactly as parsed
            pageLength: openPageLength,
            pageNumber: openPageNumber,
            scriptText: body.isEmpty ? nil : body,
            sceneFDX: nil,
            ordinal: ordinalCounter
        )
        print("✅ FDXCollector: Finalized scene #\(finalNumberString) - pageNumber: \(openPageNumber ?? "nil"), pageLength: \(openPageLength ?? "nil")")
        scenes.append(draft)
        // reset
        hasOpenScene = false
        openNumberString = ""
        openHeadingText = ""
        openPageLength = nil
        openPageNumber = nil
        openBody.removeAll()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        path.append(elementName)
        let name = elementName.lowercased()

        if name == "paragraph" {
            let type = (attr(attributeDict, "Type") ?? "").lowercased()
            let looksLikeHeading = type.contains("scene heading")

            if looksLikeHeading {
                // Starting a new heading → close the previous open scene first
                finalizeOpenSceneIfNeeded()
                currentIsSceneHeading = true
                currentHeadingText = ""
                currentPageLength = nil
                currentPageNumber = nil
                // Capture scene number if the Paragraph itself carries it (Final Draft variants)
                let paraNum = attr(attributeDict, "Number") ?? attr(attributeDict, "SceneNumber")
                if let n = paraNum, !n.isEmpty {
                    currentNumberString = n
                } else {
                    // leave as-is (may be set later by <SceneProperties> or <SceneNumber>)
                    currentNumberString = currentNumberString.isEmpty ? "" : currentNumberString
                }
                return
            } else if hasOpenScene {
                // Non-heading paragraph: start buffering for the open scene
                bufferingParaText = true
                currentParaText = ""
                currentParaType = type
            }
        }

        if currentIsSceneHeading && name == "sceneproperties" {
            currentPageLength = attr(attributeDict, "Length")
            currentPageNumber = attr(attributeDict, "Page")
            print("📄 FDXCollector: Found SceneProperties - Page=\(currentPageNumber ?? "nil"), Length=\(currentPageLength ?? "nil")")
            if currentNumberString.isEmpty {
                if let n = attr(attributeDict, "Number"), !n.isEmpty {
                    currentNumberString = n
                } else if let n = attr(attributeDict, "SceneNumber"), !n.isEmpty {
                    currentNumberString = n
                }
            }
        }

        if currentIsSceneHeading && (name == "scenenumber" || name == "number") {
            bufferingSceneNumber = true
            currentSceneNumberText = ""
        }

        if name == "text" && (currentIsSceneHeading || bufferingParaText) {
            bufferingText = true
        }

        // Detect strikeout style runs inside <Text>
        if name.lowercased() == "style", bufferingText {
            let strikeAttr = (attr(attributeDict, "Strikeout") ?? "")
            if strikeAttr.lowercased() == "yes" {
                strikeDepth += 1
                if currentIsSceneHeading {
                    currentHeadingText.append("\u{F001}")
                } else if bufferingParaText {
                    currentParaText.append("\u{F001}")
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard bufferingText || bufferingSceneNumber else { return }
        if bufferingSceneNumber {
            currentSceneNumberText += string
        } else if currentIsSceneHeading {
            currentHeadingText += string
        } else if bufferingParaText {
            currentParaText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Handle closing strikeout style runs
        if elementName.lowercased() == "style", strikeDepth > 0 {
            strikeDepth -= 1
            if currentIsSceneHeading {
                currentHeadingText.append("\u{F002}")
            } else if bufferingParaText {
                currentParaText.append("\u{F002}")
            }
        }

        let name = elementName.lowercased()

        if name == "text" {
            bufferingText = false
        }

        if (name == "scenenumber" || name == "number") && bufferingSceneNumber {
            let trimmed = currentSceneNumberText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { currentNumberString = trimmed }
            bufferingSceneNumber = false
            currentSceneNumberText = ""
        }

        defer { _ = path.popLast() }

        if name == "paragraph" {
            if currentIsSceneHeading {
                // Finish heading paragraph → open a new scene context
                let rawHeading = currentHeadingText.uppercased()   // convert to ALL CAPS
                let trimmedHeading = rawHeading.trimmingCharacters(in: .whitespacesAndNewlines)

                var numStr = currentNumberString
                if numStr.isEmpty {
                    let s = trimmedHeading
                    if let hash = s.firstIndex(of: "#") {
                        let after = s.index(after: hash)
                        if let end = s[after...].firstIndex(where: { $0 == " " || $0 == ":" || $0 == "." }) {
                            let n = String(s[after..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !n.isEmpty { numStr = n }
                        }
                    } else if let end = s.firstIndex(where: { $0 == " " || $0 == ":" || $0 == "." }),
                              s[..<end].rangeOfCharacter(from: .decimalDigits) != nil {
                        numStr = String(s[..<end])
                    }
                }

                hasOpenScene = true
                openNumberString = numStr
                openHeadingText = rawHeading
                openPageLength = currentPageLength
                openPageNumber = currentPageNumber
                print("📋 FDXCollector: Opening scene '\(numStr)' - heading: \(rawHeading), pageNumber: \(currentPageNumber ?? "nil")")
                currentIsSceneHeading = false
            } else if bufferingParaText {
                // Commit non-heading paragraph into the open scene
                let line = formatParagraph(type: currentParaType, text: currentParaText)
                if hasOpenScene && !line.isEmpty { openBody.append(line) }
                bufferingParaText = false
                currentParaText = ""
                currentParaType = ""
            }
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        // Finalize the last scene at EOF
        finalizeOpenSceneIfNeeded()
    }
}
