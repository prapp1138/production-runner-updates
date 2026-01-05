//
//  FDXImportService+Revisions.swift
//  Production Runner
//
//  Enhanced FDX import with revision tracking and change detection.
//

import Foundation
import CoreData

extension FDXImportService {
    
    /// Import with revision tracking
    public struct RevisionImportOptions {
        public var revisionName: String?
        public var colorName: String?
        public var importedBy: String?
        public var createRevisionRecord: Bool = true
        
        public init(
            revisionName: String? = nil,
            colorName: String? = nil,
            importedBy: String? = nil,
            createRevisionRecord: Bool = true
        ) {
            self.revisionName = revisionName
            self.colorName = colorName
            self.importedBy = importedBy
            self.createRevisionRecord = createRevisionRecord
        }
    }
    
    /// Import FDX with full revision tracking
    @discardableResult
    public func importFDXWithRevisionTracking(
        from url: URL,
        into context: NSManagedObjectContext,
        for project: ProjectEntity,
        options: RevisionImportOptions = RevisionImportOptions()
    ) throws -> ScriptRevisionEntity? {
        
        // Load file data
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        
        // Create revision record if requested
        var revision: ScriptRevisionEntity? = nil
        if options.createRevisionRecord {
            revision = ScriptRevisionEntity.create(
                in: context,
                project: project,
                fileName: fileName,
                fileData: data,
                revisionName: options.revisionName,
                colorName: options.colorName,
                importedBy: options.importedBy
            )
        }
        
        // Parse the FDX
        let parser = XMLParser(data: data)
        let collector = FDXCollector()
        parser.delegate = collector
        
        guard parser.parse() else {
            let reason = parser.parserError?.localizedDescription ?? "Unknown parse error"
            throw FDXImportError.xmlParseFailed(reason)
        }
        
        var drafts = collector.scenes
        
        // Attach RAW FDX fragments per scene
        if let whole = String(data: data, encoding: .utf8) {
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
                let count = min(drafts.count, fragments.count)
                if count > 0 {
                    for i in 0..<count {
                        drafts[i].sceneFDX = fragments[i]
                    }
                }
            }
        }
        
        // Backfill missing headings
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
        
        // Synthesize headings if still empty
        for i in drafts.indices {
            var h = drafts[i].headingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if h.isEmpty {
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
        
        // Compute file hash for provenance
        let fileHash = ScriptRevisionEntity.computeHash(for: data)
        
        // Persist scenes with provenance tracking
        var scenesCreated = 0
        try context.performAndWait {
            for d in drafts {
                let scene = SceneEntity(context: context)
                scene.id = UUID()
                
                // Assign basic scene data
                assignBasicSceneData(d, toScene: scene)
                
                // Set provenance information
                let sourceID = "\(fileHash)-\(d.ordinal)"
                scene.setProvenance(
                    sourceID: sourceID,
                    fileHash: fileHash,
                    revision: revision
                )
                
                // Mark as new scene
                scene.provenance.insert(.newScene)
                
                // Attach to project
                scene.project = project
                
                scenesCreated += 1
            }
            
            // Update revision statistics
            if let revision = revision {
                let totalPages = drafts.reduce(0) { total, draft in
                    if let pageLength = draft.pageLength,
                       let eighths = parseEighths(pageLength) {
                        return total + Int(eighths)
                    }
                    return total
                }
                let pages = totalPages / 8
                
                revision.updateStatistics(
                    sceneCount: drafts.count,
                    scenesAdded: drafts.count,
                    scenesModified: 0,
                    scenesRemoved: 0,
                    pageCount: pages,
                    pageCountDelta: Decimal(pages)
                )
            }
            
            // Save context
            if context.hasChanges {
                try context.save()
            }
        }
        
        return revision
    }
    
    // MARK: - Helper Methods
    
    internal func assignBasicSceneData(_ draft: FDXSceneDraft, toScene scene: SceneEntity) {
        print("🔵 [SceneNumberDebug] FDXImport assignBasicSceneData: setting number='\(draft.numberString)' ordinal=\(draft.ordinal) for scene id=\(scene.id?.uuidString ?? "nil")")
        scene.number = draft.numberString
        
        let safeHeading = draft.headingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "SCENE \(draft.numberString)".trimmingCharacters(in: .whitespacesAndNewlines)
            : draft.headingText
        
        // Parse heading components
        let (locType, scriptLoc, tod) = parseHeadingComponents(safeHeading)
        scene.locationType = locType
        scene.scriptLocation = scriptLoc
        scene.timeOfDay = tod
        
        // Set body text
        if let body = draft.scriptText, !body.isEmpty {
            scene.scriptText = body
        }
        
        // Set page length
        if let len = draft.pageLength, let eighths = parseEighths(len) {
            scene.pageEighths = eighths
        }
        
        // Set FDX fragment
        if let xml = draft.sceneFDX, !xml.isEmpty {
            scene.scriptFDX = xml
        }
        
        // Set display order
        print("🔵 [SceneNumberDebug] FDXImport: setting displayOrder=\(draft.ordinal), sortIndex=\(draft.ordinal) for scene number='\(draft.numberString)' id=\(scene.id?.uuidString ?? "nil")")
        scene.displayOrder = Int32(draft.ordinal)
        scene.sortIndex = Int32(draft.ordinal)
        
        // Set creation date
        scene.createdAt = Date()
    }
}

// MARK: - Private FDX Collector (from original service)
private final class FDXCollector: NSObject, XMLParserDelegate {
    private var path: [String] = []
    fileprivate var scenes: [FDXSceneDraft] = []
    private var ordinalCounter: Int = 0
    
    private var currentIsSceneHeading = false
    private var currentNumberString: String = ""
    private var currentHeadingText: String = ""
    private var currentPageLength: String? = nil
    private var currentPageNumber: String? = nil
    private var bufferingText = false
    
    private var hasOpenScene = false
    private var openNumberString: String = ""
    private var openHeadingText: String = ""
    private var openPageLength: String? = nil
    private var openPageNumber: String? = nil
    private var openBody: [String] = []
    
    private var bufferingParaText = false
    private var currentParaText = ""
    private var currentParaType = ""
    
    private var bufferingSceneNumber = false
    private var currentSceneNumberText = ""
    
    private var strikeDepth = 0
    
    private func attr(_ dict: [String:String], _ key: String) -> String? {
        if let v = dict[key] { return v }
        let lower = key.lowercased()
        return dict.first(where: { $0.key.lowercased() == lower })?.value
    }
    
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
            return t
        }
    }
    
    private func finalizeOpenSceneIfNeeded() {
        guard hasOpenScene else { return }
        let body = openBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        ordinalCounter += 1
        let draft = FDXSceneDraft(
            numberString: openNumberString,
            headingText: openHeadingText,
            pageLength: openPageLength,
            pageNumber: openPageNumber,
            scriptText: body.isEmpty ? nil : body,
            sceneFDX: nil,
            ordinal: ordinalCounter
        )
        scenes.append(draft)
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
                finalizeOpenSceneIfNeeded()
                currentIsSceneHeading = true
                currentHeadingText = ""
                currentPageLength = nil
                currentPageNumber = nil
                let paraNum = attr(attributeDict, "Number") ?? attr(attributeDict, "SceneNumber")
                if let n = paraNum, !n.isEmpty {
                    currentNumberString = n
                } else {
                    currentNumberString = currentNumberString.isEmpty ? "" : currentNumberString
                }
                return
            } else if hasOpenScene {
                bufferingParaText = true
                currentParaText = ""
                currentParaType = type
            }
        }
        
        if currentIsSceneHeading && name == "sceneproperties" {
            currentPageLength = attr(attributeDict, "Length")
            currentPageNumber = attr(attributeDict, "Page")
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
                let rawHeading = currentHeadingText
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
                currentIsSceneHeading = false
            } else if bufferingParaText {
                let line = formatParagraph(type: currentParaType, text: currentParaText)
                if hasOpenScene && !line.isEmpty { openBody.append(line) }
                bufferingParaText = false
                currentParaText = ""
                currentParaType = ""
            }
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        finalizeOpenSceneIfNeeded()
    }
}
