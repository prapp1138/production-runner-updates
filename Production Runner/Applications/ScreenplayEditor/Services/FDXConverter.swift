//
//  FDXConverter.swift
//  Production Runner
//
//  Converts Final Draft FDX XML to Production Runner screenplay format.
//  Maintains exact formatting from Final Draft including revisions.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - FDX Element Types

/// Maps Final Draft element types to our ScriptElementType
enum FDXElementType: String {
    case sceneHeading = "Scene Heading"
    case action = "Action"
    case character = "Character"
    case parenthetical = "Parenthetical"
    case dialogue = "Dialogue"
    case transition = "Transition"
    case shot = "Shot"
    case general = "General"
    case castList = "Cast List"
    case newAct = "New Act"
    case endOfAct = "End of Act"

    var scriptElementType: ScriptElementType {
        switch self {
        case .sceneHeading: return .sceneHeading
        case .action: return .action
        case .character: return .character
        case .parenthetical: return .parenthetical
        case .dialogue: return .dialogue
        case .transition: return .transition
        case .shot: return .shot
        default: return .general
        }
    }
}

// MARK: - FDX Parsed Element

struct FDXParsedElement {
    let id: UUID
    let type: ScriptElementType
    var text: String
    var sceneNumber: String?
    var revisionColor: String?
    var revisionID: Int?
    var isOmitted: Bool
    var pageNumber: Int?
    var pageEighths: Int?       // Scene length in eighths from FDX Length attribute

    init(
        type: ScriptElementType,
        text: String,
        sceneNumber: String? = nil,
        revisionColor: String? = nil,
        revisionID: Int? = nil,
        isOmitted: Bool = false,
        pageNumber: Int? = nil,
        pageEighths: Int? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.text = text
        self.sceneNumber = sceneNumber
        self.revisionColor = revisionColor
        self.revisionID = revisionID
        self.isOmitted = isOmitted
        self.pageNumber = pageNumber
        self.pageEighths = pageEighths
    }

    func toScriptElement() -> ScriptElement {
        ScriptElement(
            id: id,
            type: type,
            text: text,
            sceneNumber: sceneNumber,
            isOmitted: isOmitted,
            pageEighths: pageEighths,
            revisionColor: revisionColor,
            revisionID: revisionID
        )
    }
}

// MARK: - FDX Revision Info

struct FDXRevisionInfo {
    let revisionID: Int
    let colorName: String
    let revisionMark: String
    let fullRevision: Bool
    let pageColor: String?
    let name: String?
    let style: String?

    var color: String {
        colorName.isEmpty ? "White" : colorName
    }
}

// MARK: - FDX Title Page Info

struct FDXTitlePageInfo {
    var title: String = ""
    var author: String = ""
    var contact: String = ""
    var copyright: String = ""
    var draftDate: String = ""
    var revision: String = ""
}

// MARK: - FDX Parse Result

struct FDXParseResult {
    let elements: [FDXParsedElement]
    let titlePage: FDXTitlePageInfo
    let revisions: [FDXRevisionInfo]
    let pageCount: Int
    let sceneCount: Int

    var document: ScreenplayDocument {
        // Build title page elements first
        var allElements: [ScriptElement] = []

        // Check if we have title page content
        let hasTitlePage = !titlePage.title.isEmpty || !titlePage.author.isEmpty

        if hasTitlePage {
            // Add title (centered, uppercased)
            if !titlePage.title.isEmpty {
                allElements.append(ScriptElement(type: .titlePage, text: titlePage.title.uppercased()))
            }

            // Add "Written by" and author
            if !titlePage.author.isEmpty {
                allElements.append(ScriptElement(type: .titlePage, text: "Written by"))
                allElements.append(ScriptElement(type: .titlePage, text: titlePage.author))
            }

            // Add draft date
            if !titlePage.draftDate.isEmpty {
                allElements.append(ScriptElement(type: .titlePage, text: titlePage.draftDate))
            }

            // Add revision info
            if !titlePage.revision.isEmpty {
                allElements.append(ScriptElement(type: .titlePage, text: titlePage.revision))
            }

            // Add contact info
            if !titlePage.contact.isEmpty {
                allElements.append(ScriptElement(type: .titlePage, text: titlePage.contact))
            }

            // Add copyright
            if !titlePage.copyright.isEmpty {
                allElements.append(ScriptElement(type: .titlePage, text: titlePage.copyright))
            }
        }

        // Add script elements after title page
        allElements.append(contentsOf: elements.map { $0.toScriptElement() })

        return ScreenplayDocument(
            title: titlePage.title.isEmpty ? "Untitled Screenplay" : titlePage.title,
            author: titlePage.author,
            draftInfo: titlePage.revision.isEmpty ? titlePage.draftDate : titlePage.revision,
            elements: allElements
        )
    }
}

// MARK: - FDX Converter

final class FDXConverter: NSObject, XMLParserDelegate {

    // MARK: - Properties

    /// Enable verbose debug logging for FDX parsing
    var debugMode: Bool = false

    private var elements: [FDXParsedElement] = []
    private var revisions: [FDXRevisionInfo] = []
    private var titlePage = FDXTitlePageInfo()

    // Parser state
    private var currentElementType: String = ""
    private var currentText: String = ""
    private var currentSceneNumber: String?
    private var currentRevisionColor: String?
    private var currentRevisionID: Int?
    private var currentPageNumber: Int?
    private var currentPageEighths: Int?
    private var isOmitted: Bool = false

    // Pending scene heading state - preserves scene heading info even when nested paragraphs
    // overwrite currentElementType (this is the key fix for the 41 vs 109 scene issue)
    private var pendingSceneHeading: Bool = false
    private var pendingSceneNumber: String?
    private var pendingSceneText: String = ""
    private var pendingScenePageNumber: Int?
    private var pendingScenePageEighths: Int?
    private var pendingSceneRevisionColor: String?
    private var pendingSceneRevisionID: Int?
    private var pendingSceneIsOmitted: Bool = false
    private var paragraphDepth: Int = 0  // Track nested paragraph depth

    // Tracking
    private var inParagraph: Bool = false
    private var inText: Bool = false
    private var inTitlePage: Bool = false
    private var inContent: Bool = false
    private var inRevisions: Bool = false
    private var titlePageField: String = ""

    // SceneNumber element tracking
    private var inSceneNumber: Bool = false
    private var sceneNumberText: String = ""

    // Scene tracking
    private var sceneCount: Int = 0
    private var pageCount: Int = 1

    // MARK: - Public API

    /// Convert FDX data to our screenplay format
    func convert(from data: Data) -> FDXParseResult? {
        // Reset state
        elements = []
        revisions = []
        titlePage = FDXTitlePageInfo()
        currentElementType = ""
        currentText = ""
        currentSceneNumber = nil
        currentRevisionColor = nil
        currentRevisionID = nil
        currentPageNumber = nil
        currentPageEighths = nil
        isOmitted = false
        inParagraph = false
        inText = false
        inTitlePage = false
        inContent = false
        inRevisions = false
        titlePageField = ""
        inSceneNumber = false
        sceneNumberText = ""
        sceneCount = 0
        pageCount = 1
        // Reset pending scene heading state
        pendingSceneHeading = false
        pendingSceneNumber = nil
        pendingSceneText = ""
        pendingScenePageNumber = nil
        pendingScenePageEighths = nil
        pendingSceneRevisionColor = nil
        pendingSceneRevisionID = nil
        pendingSceneIsOmitted = false
        paragraphDepth = 0

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            print("[FDXConverter] ❌ Parse failed: \(parser.parserError?.localizedDescription ?? "Unknown error")")
            return nil
        }

        // Debug: Log parsing summary
        let sceneHeadings = elements.filter { $0.type == .sceneHeading }
        print("[FDXConverter] ✅ Parse complete:")
        print("  - Total elements: \(elements.count)")
        print("  - Scene headings found: \(sceneHeadings.count)")
        print("  - Scene count tracker: \(sceneCount)")
        print("  - Page count: \(pageCount)")
        print("  - Title: '\(titlePage.title)' (empty: \(titlePage.title.isEmpty))")
        print("  - Author: '\(titlePage.author)'")
        if debugMode {
            print("[FDXConverter] 📋 Full Title Page Info:")
            print("    Title: '\(titlePage.title)'")
            print("    Author: '\(titlePage.author)'")
            print("    Contact: '\(titlePage.contact)'")
            print("    Copyright: '\(titlePage.copyright)'")
            print("    Draft Date: '\(titlePage.draftDate)'")
            print("    Revision: '\(titlePage.revision)'")
        }

        // Log each scene heading for debugging
        for (index, scene) in sceneHeadings.enumerated() {
            print("  - Scene \(index + 1): #\(scene.sceneNumber ?? "nil") - \"\(scene.text.prefix(50))...\" (eighths: \(scene.pageEighths ?? 0))")
        }

        return FDXParseResult(
            elements: elements,
            titlePage: titlePage,
            revisions: revisions,
            pageCount: pageCount,
            sceneCount: sceneCount
        )
    }

    /// Convert FDX file at URL
    func convert(from url: URL) -> FDXParseResult? {
        guard let data = try? Data(contentsOf: url) else {
            print("[FDXConverter] Failed to read file at: \(url.path)")
            return nil
        }
        return convert(from: data)
    }

    // MARK: - Case-insensitive attribute helper

    private func attr(_ dict: [String: String], _ key: String) -> String? {
        if let v = dict[key] { return v }
        let lower = key.lowercased()
        return dict.first(where: { $0.key.lowercased() == lower })?.value
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {

        // Use case-insensitive matching for element names
        let name = elementName.lowercased()

        switch name {
        case "titlepage":
            inTitlePage = true
            if debugMode {
                print("[FDXConverter] 📋 TITLE PAGE START")
            }

        case "content":
            inContent = true

        case "revisions":
            inRevisions = true

        case "revision":
            if inRevisions {
                parseRevision(attributes: attributeDict)
            } else if inTitlePage {
                titlePageField = "Revision"
            }

        case "paragraph":
            let paragraphType = attr(attributeDict, "Type") ?? "Action"
            let isSceneHeading = paragraphType.lowercased().contains("scene heading")

            paragraphDepth += 1
            print("[FDXConverter] 📑 Starting paragraph depth=\(paragraphDepth), type='\(paragraphType)', isSceneHeading=\(isSceneHeading)")

            // If we're at depth 1 (top-level paragraph), check if we need to finalize a pending scene
            if paragraphDepth == 1 {
                // Finalize any pending scene heading from previous paragraph
                if pendingSceneHeading {
                    print("[FDXConverter] 🔄 New paragraph starting - finalizing pending scene heading first")
                    finalizePendingSceneHeading()
                }

                inParagraph = true
                currentElementType = paragraphType
                currentText = ""
                currentSceneNumber = attr(attributeDict, "Number") ?? attr(attributeDict, "SceneNumber")
                currentRevisionID = attr(attributeDict, "RevisionID").flatMap { Int($0) }

                // If this is a scene heading, save it as pending
                if isSceneHeading {
                    sceneCount += 1
                    pendingSceneHeading = true
                    pendingSceneNumber = currentSceneNumber
                    if pendingSceneNumber == nil || pendingSceneNumber?.isEmpty == true {
                        pendingSceneNumber = "\(sceneCount)"
                    }
                    pendingSceneText = ""
                    pendingSceneRevisionID = currentRevisionID
                    pendingSceneIsOmitted = false
                    print("[FDXConverter] 🎬 Found Scene Heading paragraph #\(sceneCount), Number attr: \(attr(attributeDict, "Number") ?? "nil")")
                }
            } else {
                // Nested paragraph - don't change the pending scene heading state
                // Just track that we're in a nested paragraph
                print("[FDXConverter] 📑 Nested paragraph at depth \(paragraphDepth), type='\(paragraphType)' - NOT overwriting scene heading state")
            }

        case "text":
            inText = true
            currentRevisionColor = attr(attributeDict, "RevisionColor")
            // DEBUG: Log Text element start with all attributes
            if debugMode {
                let attrStr = attributeDict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                print("[FDXConverter] 📄 TEXT START: attrs=[\(attrStr)] (paragraph type: \(currentElementType))")
            }

        case "sceneproperties":
            // SceneProperties indicates this is a scene, even if paragraph type isn't "Scene Heading"
            // This matches how Final Draft marks scenes in some FDX variants

            // DEBUG: Log all SceneProperties attributes
            if debugMode {
                let attrStr = attributeDict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                print("[FDXConverter] 🎯 SCENE PROPERTIES: [\(attrStr)]")
            }

            // If we don't have a pending scene heading, this SceneProperties makes it one
            if !pendingSceneHeading {
                sceneCount += 1
                pendingSceneHeading = true
                print("[FDXConverter] 🎬 SceneProperties found without pending scene - creating scene #\(sceneCount)")
            }

            // Extract scene number from properties
            if let number = attr(attributeDict, "Number"), !number.isEmpty {
                pendingSceneNumber = number
                currentSceneNumber = number
            }
            if let page = attr(attributeDict, "Page"), let pageNum = Int(page) {
                pendingScenePageNumber = pageNum
                currentPageNumber = pageNum
                pageCount = max(pageCount, pageNum)
                if debugMode {
                    print("[FDXConverter] 📄 Scene on page \(pageNum)")
                }
            }
            // Extract page length from Length attribute (e.g., "1 2/8", "4/8", "2")
            if let lengthStr = attr(attributeDict, "Length") {
                let eighths = parsePageLengthToEighths(lengthStr)
                pendingScenePageEighths = eighths
                currentPageEighths = eighths
                if debugMode {
                    print("[FDXConverter] 📏 Scene length from FDX: '\(lengthStr)' -> \(eighths ?? 0) eighths")
                }
            } else if debugMode {
                print("[FDXConverter] ⚠️ No Length attribute in SceneProperties!")
            }
            if attr(attributeDict, "Omitted")?.lowercased() == "yes" {
                pendingSceneIsOmitted = true
                isOmitted = true
            }

            // If no scene number found yet, use the scene count
            if pendingSceneNumber == nil || pendingSceneNumber?.isEmpty == true {
                pendingSceneNumber = "\(sceneCount)"
            }

        case "pagebreak":
            pageCount += 1

        // Title page elements
        case "title":
            if inTitlePage { titlePageField = "Title" }

        case "written by", "writtenby", "author":
            if inTitlePage { titlePageField = "Author" }

        case "contact":
            if inTitlePage { titlePageField = "Contact" }

        case "copyright":
            if inTitlePage { titlePageField = "Copyright" }

        case "draft date", "draftdate":
            if inTitlePage { titlePageField = "DraftDate" }

        case "scenenumber", "number":
            // Handle <SceneNumber> or <Number> elements inside scene headings
            if inParagraph && currentElementType.lowercased().contains("scene heading") {
                inSceneNumber = true
                sceneNumberText = ""
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Capture scene number text from <SceneNumber> element
        if inSceneNumber {
            sceneNumberText += string
        }

        if inText && inParagraph {
            // DEBUG: Log every text fragment being captured
            if debugMode {
                let preview = string.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50)
                if !preview.isEmpty {
                    print("[FDXConverter] 📝 TEXT FRAGMENT: '\(preview)' (type: \(currentElementType), depth: \(paragraphDepth))")
                }
            }
            currentText += string
            // Also capture text for pending scene heading (at depth 1 only)
            if pendingSceneHeading && paragraphDepth == 1 {
                pendingSceneText += string
            }
        }

        // Title page fields
        if inTitlePage && !titlePageField.isEmpty {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if debugMode {
                    print("[FDXConverter] 📋 TITLE PAGE FIELD '\(titlePageField)': '\(trimmed)'")
                }
                switch titlePageField {
                case "Title":
                    titlePage.title += trimmed
                case "Author":
                    titlePage.author += trimmed
                case "Contact":
                    titlePage.contact += trimmed
                case "Copyright":
                    titlePage.copyright += trimmed
                case "DraftDate":
                    titlePage.draftDate += trimmed
                case "Revision":
                    titlePage.revision += trimmed
                default:
                    break
                }
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {

        // Use case-insensitive matching for element names
        let name = elementName.lowercased()

        switch name {
        case "titlepage":
            inTitlePage = false

        case "content":
            inContent = false

        case "revisions":
            inRevisions = false

        case "paragraph":
            paragraphDepth -= 1
            print("[FDXConverter] 📑 Ending paragraph, depth now=\(paragraphDepth)")

            // Only finalize when we're closing the top-level paragraph (depth goes to 0)
            if paragraphDepth == 0 {
                // Finalize non-scene-heading elements immediately
                if inParagraph && !pendingSceneHeading {
                    finishCurrentElement()
                }
                // Note: Scene headings are finalized when the NEXT paragraph starts,
                // or at end of document (parserDidEndDocument)
                inParagraph = false
                currentElementType = ""
                currentSceneNumber = nil
                currentRevisionID = nil
                isOmitted = false
            }
            // For nested paragraphs, just decrement depth - don't change other state

        case "text":
            inText = false

        case "scenenumber", "number":
            if inSceneNumber {
                let trimmedNumber = sceneNumberText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedNumber.isEmpty && (currentSceneNumber == nil || currentSceneNumber?.isEmpty == true) {
                    currentSceneNumber = trimmedNumber
                    print("[FDXConverter] 📝 Captured scene number from element: '\(trimmedNumber)'")
                }
                inSceneNumber = false
            }

        case "title", "written by", "writtenby", "author", "contact", "copyright", "draft date", "draftdate":
            if inTitlePage {
                titlePageField = ""
            }

        default:
            break
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        // Finalize any pending scene heading at end of document
        if pendingSceneHeading {
            print("[FDXConverter] 📄 End of document - finalizing pending scene heading")
            finalizePendingSceneHeading()
        }
        // Finalize the last element at end of document (if any pending)
        if inParagraph {
            print("[FDXConverter] 📄 End of document - finalizing last element")
            finishCurrentElement()
        }
    }

    // MARK: - Private Helpers

    /// Finalize a pending scene heading - creates the scene heading element from pending state
    private func finalizePendingSceneHeading() {
        guard pendingSceneHeading else { return }

        var sceneText = pendingSceneText.trimmingCharacters(in: .whitespacesAndNewlines)

        print("[FDXConverter] 🔧 finalizePendingSceneHeading called - text: '\(sceneText.prefix(30))...', sceneNum: \(pendingSceneNumber ?? "nil")")

        // Use placeholder if text is empty
        if sceneText.isEmpty {
            if let sceneNum = pendingSceneNumber, !sceneNum.isEmpty {
                sceneText = "SCENE \(sceneNum)"
                print("[FDXConverter] ⚠️ Empty Scene Heading - using placeholder: '\(sceneText)'")
            } else {
                sceneText = "SCENE \(sceneCount)"
                print("[FDXConverter] ⚠️ Empty Scene Heading with no number - using sceneCount: '\(sceneText)'")
            }
        }

        // Create scene heading element
        let element = FDXParsedElement(
            type: .sceneHeading,
            text: sceneText,
            sceneNumber: pendingSceneNumber,
            revisionColor: pendingSceneRevisionColor,
            revisionID: pendingSceneRevisionID,
            isOmitted: pendingSceneIsOmitted,
            pageNumber: pendingScenePageNumber,
            pageEighths: pendingScenePageEighths
        )
        elements.append(element)
        print("[FDXConverter] ✓ Created Scene Heading element: \"\(sceneText.prefix(50))\" sceneNum=\(pendingSceneNumber ?? "nil")")

        // Reset pending state
        pendingSceneHeading = false
        pendingSceneNumber = nil
        pendingSceneText = ""
        pendingScenePageNumber = nil
        pendingScenePageEighths = nil
        pendingSceneRevisionColor = nil
        pendingSceneRevisionID = nil
        pendingSceneIsOmitted = false
    }

    private func finishCurrentElement() {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Debug: Log every call to finishCurrentElement
        print("[FDXConverter] 🔧 finishCurrentElement called - type: '\(currentElementType)', text: '\(trimmedText.prefix(50))...', sceneNum: \(currentSceneNumber ?? "nil")")

        // DEBUG: Log full text for Action elements to help find missing text like "Nia"
        if debugMode && currentElementType == "Action" {
            print("[FDXConverter] 📝 FULL ACTION TEXT: '\(trimmedText)'")
        }

        // Scene headings are handled by finalizePendingSceneHeading, not here
        // This method only handles non-scene-heading elements (Action, Dialogue, etc.)

        // Skip empty elements
        guard !trimmedText.isEmpty else {
            currentText = ""
            currentRevisionColor = nil
            currentPageNumber = nil
            currentPageEighths = nil
            return
        }

        // Map element type to our internal types
        let fdxType = FDXElementType(rawValue: currentElementType) ?? .general
        let scriptType = fdxType.scriptElementType

        let element = FDXParsedElement(
            type: scriptType,
            text: trimmedText,
            sceneNumber: nil,
            revisionColor: currentRevisionColor,
            revisionID: currentRevisionID,
            isOmitted: false,
            pageNumber: currentPageNumber,
            pageEighths: nil
        )

        elements.append(element)

        // Reset for next element
        currentText = ""
        currentRevisionColor = nil
        currentPageNumber = nil
        currentPageEighths = nil
    }

    /// Parse FDX Length string to eighths (e.g., "1 2/8" -> 10, "4/8" -> 4, "2" -> 16)
    private func parsePageLengthToEighths(_ lengthStr: String) -> Int? {
        let trimmed = lengthStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var totalEighths = 0

        // Split by space to separate whole pages from fraction
        let parts = trimmed.split(separator: " ")

        if parts.count == 2 {
            // Format: "1 2/8" (whole pages + fraction)
            if let wholePages = Int(parts[0]) {
                totalEighths += wholePages * 8
            }
            // Parse fraction
            let fracParts = parts[1].split(separator: "/")
            if fracParts.count == 2,
               let numerator = Int(fracParts[0]),
               let denominator = Int(fracParts[1]),
               denominator != 0 {
                // Normalize to eighths
                totalEighths += (numerator * 8) / denominator
            }
        } else if parts.count == 1 {
            let single = String(parts[0])
            if single.contains("/") {
                // Format: "4/8" (fraction only)
                let fracParts = single.split(separator: "/")
                if fracParts.count == 2,
                   let numerator = Int(fracParts[0]),
                   let denominator = Int(fracParts[1]),
                   denominator != 0 {
                    totalEighths = (numerator * 8) / denominator
                }
            } else if let wholePages = Int(single) {
                // Format: "2" (whole pages only)
                totalEighths = wholePages * 8
            }
        }

        // DEBUG: Log page length parsing
        if debugMode {
            print("[FDXConverter] 📏 PAGE LENGTH: input='\(trimmed)' -> \(totalEighths) eighths (\(String(format: "%.2f", Double(totalEighths) / 8.0)) pages)")
        }

        return totalEighths > 0 ? totalEighths : nil
    }

    private func parseRevision(attributes: [String: String]) {
        guard let idString = attributes["ID"], let id = Int(idString) else { return }

        let revision = FDXRevisionInfo(
            revisionID: id,
            colorName: attributes["Color"] ?? "White",
            revisionMark: attributes["Mark"] ?? "*",
            fullRevision: attributes["FullRevision"] == "Yes",
            pageColor: attributes["PageColor"],
            name: attributes["Name"],
            style: attributes["Style"]
        )

        revisions.append(revision)
    }
}

// MARK: - Convenience Extensions

extension FDXConverter {

    /// Get revision color from FDX color name
    static func revisionColorFromFDX(_ fdxColor: String) -> String {
        let normalized = fdxColor.lowercased().trimmingCharacters(in: .whitespaces)

        switch normalized {
        case "white", "": return "White"
        case "blue": return "Blue"
        case "pink": return "Pink"
        case "yellow": return "Yellow"
        case "green": return "Green"
        case "goldenrod": return "Goldenrod"
        case "buff": return "Buff"
        case "salmon": return "Salmon"
        case "cherry": return "Cherry"
        case "tan": return "Tan"
        case "gray", "grey": return "Gray"
        default: return fdxColor.capitalized
        }
    }

    /// Compare two parse results to find changes
    static func compareRevisions(original: FDXParseResult, revised: FDXParseResult) -> (added: Int, modified: Int, removed: Int) {
        var added = 0
        var modified = 0
        var removed = 0

        let originalScenes = original.elements.filter { $0.type == .sceneHeading }
        let revisedScenes = revised.elements.filter { $0.type == .sceneHeading }

        let originalHeadings = Set(originalScenes.map { $0.text.uppercased() })
        let revisedHeadings = Set(revisedScenes.map { $0.text.uppercased() })

        // Count new scenes
        for heading in revisedHeadings {
            if !originalHeadings.contains(heading) {
                added += 1
            }
        }

        // Count removed scenes
        for heading in originalHeadings {
            if !revisedHeadings.contains(heading) {
                removed += 1
            }
        }

        // Count modified (scenes with revision marks)
        modified = revised.elements.filter { $0.revisionColor != nil && $0.revisionColor != "White" }.count

        return (added, modified, removed)
    }
}
