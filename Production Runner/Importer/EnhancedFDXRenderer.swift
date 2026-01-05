//
//  EnhancedFDXRenderer.swift
//  Production Runner
//
//  Professional FDX rendering with:
//  - Revision marks (colored bars in margins)
//  - Continued indicators at page breaks
//  - MORE/CONT'D for dialogue spanning pages
//  - Bold/Italic/Underline text styles
//  - Dual dialogue support
//  - Scene numbers in margins  
//  - Headers with script metadata
//

import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
#elseif canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
#endif

// MARK: - Data Models

struct FDXRevision {
    let id: String
    let color: String
    let mark: String?
}

struct FDXSceneNumber {
    let number: String
    let position: SceneNumberPosition
    
    enum SceneNumberPosition {
        case left, right, both
    }
}

struct FDXHeaderInfo {
    let title: String?
    let author: String?
    let draftDate: String?
    let revisionColor: String?
    let contact: String?
}

enum FDXParagraphType: String {
    case sceneHeading = "Scene Heading"
    case action = "Action"
    case character = "Character"
    case parenthetical = "Parenthetical"
    case dialogue = "Dialogue"
    case transition = "Transition"
    case shot = "Shot"
    case general = "General"
    
    var isDialogue: Bool {
        switch self {
        case .character, .parenthetical, .dialogue: return true
        default: return false
        }
    }
}

struct FDXTextRun {
    let text: String
    let isBold: Bool
    let isItalic: Bool
    let isUnderline: Bool
    let isStrikethrough: Bool
}

struct FDXParagraph {
    let type: FDXParagraphType
    let textRuns: [FDXTextRun]
    let sceneNumber: FDXSceneNumber?
    let revision: FDXRevision?
    let isDualDialogue: Bool
    
    var plainText: String {
        textRuns.map { $0.text }.joined()
    }
}

// MARK: - FDX Parser

final class EnhancedFDXParser: NSObject, XMLParserDelegate {
    private(set) var paragraphs: [FDXParagraph] = []
    private(set) var headerInfo: FDXHeaderInfo?

    /// Enable verbose debug logging
    var debugMode: Bool = false

    // Current parsing state
    private var currentParagraphType: FDXParagraphType = .action
    private var currentTextRuns: [FDXTextRun] = []
    private var currentSceneNumber: FDXSceneNumber?
    private var currentRevision: FDXRevision?
    private var currentIsDualDialogue = false

    // Text run accumulation
    private var currentText = ""
    private var currentIsBold = false
    private var currentIsItalic = false
    private var currentIsUnderline = false
    private var currentIsStrikethrough = false
    private var isBufferingText = false
    
    // Header info
    private var headerTitle: String?
    private var headerAuthor: String?
    private var headerDraftDate: String?
    private var headerRevisionColor: String?
    private var headerContact: String?
    private var isInContent = false
    private var currentElement = ""
    
    func parse(fdxData: Data) -> Bool {
        let parser = XMLParser(data: fdxData)
        parser.delegate = self
        return parser.parse()
    }
    
    func parse(fdxString: String) -> Bool {
        guard let data = fdxString.data(using: .utf8) else { return false }
        return parse(fdxData: data)
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        switch elementName {
        case "Content":
            isInContent = true
            
        case "TitlePage":
            isInContent = false
            
        case "Paragraph":
            startParagraph(attributes: attributeDict)
            
        case "SceneProperties":
            parseSceneProperties(attributes: attributeDict)
            
        case "Text":
            isBufferingText = true
            
        case "Style":
            parseStyle(attributes: attributeDict)
            
        case "Title" where !isInContent:
            currentText = ""
            
        case "Author" where !isInContent:
            currentText = ""
            
        case "DraftDate" where !isInContent:
            currentText = ""
            
        case "Contact" where !isInContent:
            currentText = ""
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isBufferingText || (!isInContent && !currentElement.isEmpty) {
            // DEBUG: Log text fragments being captured
            if debugMode {
                let preview = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !preview.isEmpty {
                    print("[EnhancedFDXParser] 📝 TEXT: '\(preview.prefix(50))' (bold:\(currentIsBold), italic:\(currentIsItalic), para:\(currentParagraphType.rawValue))")
                }
            }
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Text":
            if isBufferingText && !currentText.isEmpty {
                let run = FDXTextRun(
                    text: currentText,
                    isBold: currentIsBold,
                    isItalic: currentIsItalic,
                    isUnderline: currentIsUnderline,
                    isStrikethrough: currentIsStrikethrough
                )
                currentTextRuns.append(run)
                currentText = ""
            }
            isBufferingText = false
            
        case "Paragraph":
            endParagraph()
            
        case "Style":
            // Reset style flags when style block ends
            currentIsBold = false
            currentIsItalic = false
            currentIsUnderline = false
            currentIsStrikethrough = false
            
        case "Title" where !isInContent:
            headerTitle = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentText = ""
            
        case "Author" where !isInContent:
            headerAuthor = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentText = ""
            
        case "DraftDate" where !isInContent:
            headerDraftDate = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentText = ""
            
        case "Contact" where !isInContent:
            headerContact = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentText = ""
            
        case "FinalDraft":
            // Document ended - store header info
            headerInfo = FDXHeaderInfo(
                title: headerTitle,
                author: headerAuthor,
                draftDate: headerDraftDate,
                revisionColor: headerRevisionColor,
                contact: headerContact
            )
            
        default:
            break
        }
        
        currentElement = ""
    }
    
    // MARK: - Parsing Helpers
    
    private func startParagraph(attributes: [String: String]) {
        // Reset state
        currentTextRuns = []
        currentSceneNumber = nil
        currentRevision = nil
        currentIsDualDialogue = false
        
        // Parse type - handle case variations and spacing differences
        if let typeStr = attributes["Type"] ?? attributes["type"] {
            // Try exact match first
            if let exactMatch = FDXParagraphType(rawValue: typeStr) {
                currentParagraphType = exactMatch
            } else {
                // Normalize: lowercase and remove spaces for comparison
                let normalized = typeStr.lowercased().replacingOccurrences(of: " ", with: "")
                switch normalized {
                case "sceneheading", "slug":
                    currentParagraphType = .sceneHeading
                case "action":
                    currentParagraphType = .action
                case "character":
                    currentParagraphType = .character
                case "parenthetical":
                    currentParagraphType = .parenthetical
                case "dialogue", "dialog":
                    currentParagraphType = .dialogue
                case "transition":
                    currentParagraphType = .transition
                case "shot":
                    currentParagraphType = .shot
                case "general":
                    currentParagraphType = .general
                default:
                    currentParagraphType = .action
                }
            }
        } else {
            currentParagraphType = .action
        }
        
        // Parse scene number
        if let number = attributes["Number"] ?? attributes["number"] {
            print("📍 Scene Number found in Paragraph: \(number)")
            let position: FDXSceneNumber.SceneNumberPosition
            if let align = attributes["Alignment"] ?? attributes["alignment"] {
                switch align.lowercased() {
                case "left": position = .left
                case "right": position = .right
                case "both": position = .both
                default: position = .left
                }
            } else {
                position = .left
            }
            currentSceneNumber = FDXSceneNumber(number: number, position: position)
            print("✅ Set currentSceneNumber to: \(number), position: \(position)")
        }
        
        // Parse dual dialogue flag
        if let dual = attributes["DualDialogue"] ?? attributes["dualDialogue"] {
            currentIsDualDialogue = (dual.lowercased() == "true" || dual == "1")
        }
    }
    
    private func endParagraph() {
        guard !currentTextRuns.isEmpty else { return }

        let paragraph = FDXParagraph(
            type: currentParagraphType,
            textRuns: currentTextRuns,
            sceneNumber: currentSceneNumber,
            revision: currentRevision,
            isDualDialogue: currentIsDualDialogue
        )
        paragraphs.append(paragraph)

        // DEBUG: Log final paragraph content
        if debugMode {
            let fullText = currentTextRuns.map { $0.text }.joined()
            print("[EnhancedFDXParser] ✅ PARAGRAPH COMPLETE: type=\(currentParagraphType.rawValue), runs=\(currentTextRuns.count), text='\(fullText.prefix(80))...'")
        }
    }
    
    private func parseSceneProperties(attributes: [String: String]) {
        // Scene numbers can also be in SceneProperties
        if let number = attributes["Number"] ?? attributes["number"] {
            if currentSceneNumber == nil {
                currentSceneNumber = FDXSceneNumber(number: number, position: .left)
                print("📍 Scene Number found in SceneProperties: \(number)")
            }
        }

        // Parse revision info
        if let revID = attributes["RevisionID"] ?? attributes["revisionID"],
           let color = attributes["RevisionColor"] ?? attributes["revisionColor"] {
            let mark = attributes["RevisionMark"] ?? attributes["revisionMark"]
            currentRevision = FDXRevision(id: revID, color: color, mark: mark)

            // Store latest revision color for header
            if headerRevisionColor == nil {
                headerRevisionColor = color
            }
        }
    }
    
    private func parseStyle(attributes: [String: String]) {
        // Bold
        if let bold = attributes["Bold"] ?? attributes["bold"] {
            currentIsBold = (bold.lowercased() == "yes" || bold == "1")
        }
        
        // Italic
        if let italic = attributes["Italic"] ?? attributes["italic"] {
            currentIsItalic = (italic.lowercased() == "yes" || italic == "1")
        }
        
        // Underline
        if let underline = attributes["Underline"] ?? attributes["underline"] {
            currentIsUnderline = (underline.lowercased() == "yes" || underline == "1")
        }
        
        // Strikethrough
        if let strike = attributes["Strikeout"] ?? attributes["strikeout"] {
            currentIsStrikethrough = (strike.lowercased() == "yes" || strike == "1")
        }
    }
}

// MARK: - Revision Colors

struct RevisionColors {
    static func color(for colorName: String) -> PlatformColor {
        switch colorName.lowercased() {
        case "blue": return .systemBlue
        case "pink", "magenta": return .systemPink
        case "green": return .systemGreen
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "red": return .systemRed
        case "purple": return .systemPurple
        case "cyan": return .systemTeal
        case "gray", "grey": return .systemGray
        default: return .systemGray
        }
    }
}

#if canImport(AppKit)
typealias PlatformColor = NSColor
#else
typealias PlatformColor = UIColor
#endif

#if canImport(AppKit)
extension NSColor {
    static var label: NSColor { self.labelColor }
    static var secondaryLabel: NSColor { self.secondaryLabelColor }
}
#endif

// MARK: - Enhanced Attributed String Builder

class EnhancedFDXAttributedStringBuilder {
    private let paragraphs: [FDXParagraph]
    private let headerInfo: FDXHeaderInfo?
    private let pageWidth: CGFloat
    private let pageHeight: CGFloat
    private let includeHeader: Bool
    private let showRevisionMarks: Bool
    private let showSceneNumbers: Bool
    
    init(paragraphs: [FDXParagraph],
         headerInfo: FDXHeaderInfo?,
         pageWidth: CGFloat = 612,
         pageHeight: CGFloat = 792,
         includeHeader: Bool = true,
         showRevisionMarks: Bool = true,
         showSceneNumbers: Bool = true) {
        self.paragraphs = paragraphs
        self.headerInfo = headerInfo
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.includeHeader = includeHeader
        self.showRevisionMarks = showRevisionMarks
        self.showSceneNumbers = showSceneNumbers
    }
    
    func build() -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Add header if requested
        if includeHeader, let header = headerInfo {
            result.append(buildHeader(header))
        }

        // Track dialogue blocks for MORE/CONT'D
        var inDialogueBlock = false
        var previousType: FDXParagraphType? = nil

        for (index, para) in paragraphs.enumerated() {
            // Check if we need MORE/CONT'D indicators
            let isLastParagraph = (index == paragraphs.count - 1)
            let nextPara = isLastParagraph ? nil : paragraphs[index + 1]
            let isFirst = (index == 0)

            // Handle dialogue blocks
            if para.type == .character {
                inDialogueBlock = true
            }

            // Build the paragraph with context-aware spacing
            let paraString = buildParagraph(para,
                                           inDialogueBlock: inDialogueBlock,
                                           isLast: isLastParagraph,
                                           nextPara: nextPara,
                                           isFirst: isFirst,
                                           previousType: previousType)
            result.append(paraString)

            // End dialogue block after dialogue
            if para.type == .dialogue, nextPara?.type.isDialogue == false {
                inDialogueBlock = false
            }

            previousType = para.type
        }

        return result
    }
    
    private func buildHeader(_ header: FDXHeaderInfo) -> NSAttributedString {
        let headerString = NSMutableAttributedString()
        let headerFont = PlatformFont(name: "Courier", size: 10) ?? PlatformFont.systemFont(ofSize: 10)
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 6
        
        var headerText = ""
        if let title = header.title {
            headerText += title
        }
        if let date = header.draftDate {
            headerText += headerText.isEmpty ? "" : " - "
            headerText += date
        }
        if let color = header.revisionColor {
            headerText += headerText.isEmpty ? "" : " - "
            headerText += "\(color.uppercased()) REVISION"
        }
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .paragraphStyle: style,
            .foregroundColor: PlatformColor.black
        ]
        
        headerString.append(NSAttributedString(string: headerText + "\n\n", attributes: attrs))
        return headerString
    }
    
    private func buildParagraph(_ para: FDXParagraph,
                               inDialogueBlock: Bool,
                               isLast: Bool,
                               nextPara: FDXParagraph?,
                               isFirst: Bool = false,
                               previousType: FDXParagraphType? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Add scene number prefix if present
        if showSceneNumbers, let sceneNum = para.sceneNumber {
            if sceneNum.position == .left || sceneNum.position == .both {
                let numAttrs = sceneNumberAttributes()
                result.append(NSAttributedString(string: "\(sceneNum.number)      ", attributes: numAttrs))
                print("✏️ Rendering scene number: \(sceneNum.number) for paragraph type: \(para.type)")
            }
        }

        // Build main text with styles
        let mainText = buildStyledText(para.textRuns, type: para.type)
        result.append(mainText)

        // Add scene number suffix if present
        if showSceneNumbers, let sceneNum = para.sceneNumber {
            if sceneNum.position == .right || sceneNum.position == .both {
                let numAttrs = sceneNumberAttributes()
                result.append(NSAttributedString(string: "  \(sceneNum.number)", attributes: numAttrs))
            }
        }

        // Add newline
        result.append(NSAttributedString(string: "\n"))

        // Add paragraph style with context-aware spacing
        let attrs = paragraphAttributes(for: para.type, isFirst: isFirst, previousType: previousType)
        result.addAttributes(attrs, range: NSRange(location: 0, length: result.length))

        // Add revision mark if present
        if showRevisionMarks, let revision = para.revision {
            addRevisionMark(to: result, color: revision.color)
        }

        return result
    }
    
    private func buildStyledText(_ runs: [FDXTextRun], type: FDXParagraphType) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseFont = PlatformFont(name: "Courier", size: 12) ?? PlatformFont.systemFont(ofSize: 12)

        // Determine if this element type should be all caps
        let isAllCaps = (type == .sceneHeading || type == .character || type == .transition || type == .shot)

        for run in runs {
            var font = baseFont

            #if canImport(AppKit)
            // Apply bold/italic using NSFontManager on macOS
            if run.isBold {
                let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                if boldFont != font {
                    font = boldFont
                }
            }
            if run.isItalic {
                let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                if italicFont != font {
                    font = italicFont
                }
            }
            #else
            // Apply bold/italic using UIFont.SymbolicTraits on iOS
            var traits = font.fontDescriptor.symbolicTraits
            if run.isBold {
                traits.insert(.traitBold)
            }
            if run.isItalic {
                traits.insert(.traitItalic)
            }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                font = PlatformFont(descriptor: descriptor, size: font.pointSize)
            }
            #endif

            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: PlatformColor.black
            ]

            // Add underline
            if run.isUnderline {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            // Add strikethrough
            if run.isStrikethrough {
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attrs[.strikethroughColor] = PlatformColor.systemPink
            }

            // Apply uppercase for scene headings, characters, transitions, and shots
            let text = isAllCaps ? run.text.uppercased() : run.text
            result.append(NSAttributedString(string: text, attributes: attrs))
        }

        return result
    }
    
    private func paragraphAttributes(for type: FDXParagraphType, isFirst: Bool = false, previousType: FDXParagraphType? = nil) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0  // Single-spaced

        // Use shared constants for consistent formatting
        typealias Fmt = ScriptFormatConstants

        switch type {
        case .sceneHeading:
            style.firstLineHeadIndent = Fmt.sceneHeadingLeftIndent
            style.headIndent = Fmt.sceneHeadingLeftIndent
            style.tailIndent = -Fmt.sceneHeadingRightIndent
            style.alignment = .left
            style.paragraphSpacingBefore = isFirst ? 0 : Fmt.sceneHeadingSpaceBefore
            style.paragraphSpacing = Fmt.sceneHeadingSpaceAfter

        case .action, .general:
            style.firstLineHeadIndent = Fmt.actionLeftIndent
            style.headIndent = Fmt.actionLeftIndent
            style.tailIndent = -Fmt.actionRightIndent
            style.alignment = .left
            style.paragraphSpacingBefore = isFirst ? 0 : Fmt.actionSpaceBefore
            style.paragraphSpacing = Fmt.actionSpaceAfter

        case .character:
            // Character names: left-aligned with significant left indent
            // Standard: ~3.7" from page left = ~2.2" from content edge = ~158pt
            // Using the configured characterLeftIndent value
            style.firstLineHeadIndent = Fmt.characterLeftIndent
            style.headIndent = Fmt.characterLeftIndent
            style.tailIndent = -Fmt.characterRightIndent
            style.alignment = .left
            style.paragraphSpacingBefore = isFirst ? 0 : Fmt.characterSpaceBefore
            style.paragraphSpacing = Fmt.characterSpaceAfter

        case .parenthetical:
            style.firstLineHeadIndent = Fmt.parentheticalLeftIndent
            style.headIndent = Fmt.parentheticalLeftIndent
            style.tailIndent = -Fmt.parentheticalRightIndent
            style.alignment = .left
            style.paragraphSpacingBefore = Fmt.parentheticalSpaceBefore
            style.paragraphSpacing = Fmt.parentheticalSpaceAfter

        case .dialogue:
            style.firstLineHeadIndent = Fmt.dialogueLeftIndent
            style.headIndent = Fmt.dialogueLeftIndent
            style.tailIndent = -Fmt.dialogueRightIndent
            style.alignment = .left
            style.paragraphSpacingBefore = Fmt.dialogueSpaceBefore
            style.paragraphSpacing = Fmt.dialogueSpaceAfter

        case .transition:
            style.firstLineHeadIndent = Fmt.transitionLeftIndent
            style.headIndent = Fmt.transitionLeftIndent
            style.tailIndent = -Fmt.transitionRightIndent
            style.alignment = .left
            style.paragraphSpacingBefore = isFirst ? 0 : Fmt.transitionSpaceBefore
            style.paragraphSpacing = Fmt.transitionSpaceAfter

        case .shot:
            // Shot uses same formatting as scene heading
            style.firstLineHeadIndent = Fmt.sceneHeadingLeftIndent
            style.headIndent = Fmt.sceneHeadingLeftIndent
            style.tailIndent = -Fmt.sceneHeadingRightIndent
            style.alignment = .left
            style.paragraphSpacingBefore = isFirst ? 0 : Fmt.sceneHeadingSpaceBefore
            style.paragraphSpacing = Fmt.sceneHeadingSpaceAfter
        }

        return [.paragraphStyle: style]
    }
    
    private func sceneNumberAttributes() -> [NSAttributedString.Key: Any] {
        let font = PlatformFont(name: "Courier-Bold", size: 12) ?? PlatformFont.boldSystemFont(ofSize: 12)
        return [
            .font: font,
            .foregroundColor: PlatformColor.black
        ]
    }
    
    private func addRevisionMark(to attrString: NSMutableAttributedString, color: String) {
        // Use shared revision color constants
        let revColor = ScriptRevisionColors.platformColor(for: color)

        // Apply revision color to the text foreground
        attrString.addAttribute(.foregroundColor,
                               value: revColor,
                               range: NSRange(location: 0, length: attrString.length))
    }
}

// MARK: - SwiftUI View for Enhanced FDX Rendering

#if canImport(SwiftUI)

@available(macOS 11.0, iOS 14.0, *)
struct EnhancedFDXScriptView: View {
    let fdxXML: String
    let pageEighths: Int
    let showRevisionMarks: Bool
    let showSceneNumbers: Bool
    let includeHeader: Bool
    let showRawXML: Bool
    let startingPageNumber: Int
    var sceneID: String?

    // Observe highlight manager to rebuild view when highlights change
    @ObservedObject private var highlightManager = HighlightManager.shared

    // Use shared format constants
    private let pageWidth: CGFloat = ScriptFormatConstants.pageWidth
    private let pageHeight: CGFloat = ScriptFormatConstants.pageHeight
    private let contentWidth: CGFloat = ScriptFormatConstants.contentWidth
    private let contentHeight: CGFloat = ScriptFormatConstants.contentHeight

    init(fdxXML: String,
         pageEighths: Int,
         showRevisionMarks: Bool = true,
         showSceneNumbers: Bool = true,
         includeHeader: Bool = false,
         showRawXML: Bool = false,
         startingPageNumber: Int = 1,
         sceneID: String? = nil) {
        self.fdxXML = fdxXML
        self.pageEighths = pageEighths
        self.showRevisionMarks = showRevisionMarks
        self.showSceneNumbers = showSceneNumbers
        self.includeHeader = includeHeader
        self.showRawXML = showRawXML
        self.startingPageNumber = startingPageNumber
        self.sceneID = sceneID
    }

    var body: some View {
        if showRawXML {
            // Show raw XML from Final Draft
            rawXMLView
        } else {
            // Show formatted screenplay
            formattedScriptView
        }
    }

    private var rawXMLView: some View {
        #if os(macOS)
        ScrollView([.horizontal, .vertical]) {
            Text(formatXML(fdxXML))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.black)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.white)
        .frame(minWidth: pageWidth, minHeight: pageHeight)
        .frame(maxHeight: .infinity)
        #else
        ScrollView([.horizontal, .vertical]) {
            Text(formatXML(fdxXML))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.white)
        #endif
    }

    private var formattedScriptView: some View {
        // Access highlights to trigger rebuild when they change
        let currentHighlights = highlightManager.highlights

        let parser = EnhancedFDXParser()
        // DEBUG: Enable verbose logging for FDX rendering
        // Set FDX_DEBUG=1 environment variable to enable
        parser.debugMode = ProcessInfo.processInfo.environment["FDX_DEBUG"] == "1"

        let wrapped = "<FinalDraft>\n<Content>\n\(fdxXML)\n</Content>\n</FinalDraft>"
        let parseSuccess = parser.parse(fdxString: wrapped)
        print("🔍 FDX Parser: Success=\(parseSuccess), Paragraphs=\(parser.paragraphs.count), Highlights=\(currentHighlights.count)")

        let builder = EnhancedFDXAttributedStringBuilder(
            paragraphs: parser.paragraphs,
            headerInfo: parser.headerInfo,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            includeHeader: includeHeader,
            showRevisionMarks: showRevisionMarks,
            showSceneNumbers: showSceneNumbers
        )

        var attributedText = builder.build()

        // Apply highlight colors for tagged elements
        if let currentSceneID = sceneID {
            attributedText = applyHighlightColors(to: attributedText, sceneID: currentSceneID, highlights: currentHighlights)
        }

        print("🎨 FDX Builder: Built attributed string with \(attributedText.length) characters")

        #if os(macOS)
        return AttributedTextPageView(
            attributedText: attributedText,
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            lastPageFraction: lastPageFraction(from: pageEighths),
            startingPageNumber: startingPageNumber,
            sceneID: sceneID
        )
        .frame(minWidth: pageWidth, minHeight: pageHeight)
        .frame(maxHeight: .infinity)
        #else
        // iOS version - use AttributedTextPageViewiOS for proper formatting
        return AttributedTextPageViewiOS(
            attributedText: attributedText,
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            lastPageFraction: lastPageFraction(from: pageEighths),
            startingPageNumber: startingPageNumber
        )
        .frame(minWidth: pageWidth, minHeight: pageHeight)
        #endif
    }

    /// Applies colored background highlights to text that has been tagged as production elements
    private func applyHighlightColors(to attributedString: NSAttributedString, sceneID: String, highlights: [ScriptHighlight]) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullText = mutableString.string

        // Filter highlights for this scene
        let sceneHighlights = highlights.filter { $0.sceneID == sceneID }

        for highlight in sceneHighlights {
            let searchText = highlight.highlightedText

            // Find all occurrences of the highlighted text (case insensitive)
            var searchRange = fullText.startIndex..<fullText.endIndex
            while let range = fullText.range(of: searchText, options: .caseInsensitive, range: searchRange) {
                let nsRange = NSRange(range, in: fullText)

                // Apply background color based on element type
                let color = highlightColor(for: highlight.elementType)
                mutableString.addAttribute(.backgroundColor, value: color, range: nsRange)

                // Move search range forward
                if range.upperBound < fullText.endIndex {
                    searchRange = range.upperBound..<fullText.endIndex
                } else {
                    break
                }
            }
        }

        return mutableString
    }

    /// Returns the NSColor for a production element type
    private func highlightColor(for elementType: ProductionElementType) -> PlatformColor {
        switch elementType {
        case .cast: return PlatformColor.systemBlue.withAlphaComponent(0.3)
        case .stunts: return PlatformColor.systemOrange.withAlphaComponent(0.3)
        case .extras: return PlatformColor.systemMint.withAlphaComponent(0.3)
        case .props: return PlatformColor.systemPurple.withAlphaComponent(0.3)
        case .wardrobe: return PlatformColor.systemPink.withAlphaComponent(0.3)
        case .makeupHair: return PlatformColor.systemGreen.withAlphaComponent(0.3)
        case .setDressing: return PlatformColor.brown.withAlphaComponent(0.3)
        case .specialEffects: return PlatformColor.systemRed.withAlphaComponent(0.3)
        case .visualEffects: return PlatformColor.systemTeal.withAlphaComponent(0.3)
        case .animals: return PlatformColor.systemYellow.withAlphaComponent(0.3)
        case .vehicles: return PlatformColor.systemTeal.withAlphaComponent(0.3)
        case .specialEquipment: return PlatformColor.systemIndigo.withAlphaComponent(0.3)
        case .sound: return PlatformColor.systemGray.withAlphaComponent(0.3)
        }
    }

    private func formatXML(_ xml: String) -> String {
        // Pretty print the XML with indentation
        var formatted = ""
        var indentLevel = 0
        let lines = xml.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Decrease indent for closing tags
            if trimmed.hasPrefix("</") {
                indentLevel = max(0, indentLevel - 1)
            }

            // Add indented line
            let indent = String(repeating: "  ", count: indentLevel)
            formatted += indent + trimmed + "\n"

            // Increase indent for opening tags (but not self-closing or already-closed)
            if trimmed.hasPrefix("<") && !trimmed.hasPrefix("</") && !trimmed.hasSuffix("/>") && !trimmed.contains("</") {
                indentLevel += 1
            }
        }

        return formatted.isEmpty ? fdxXML : formatted
    }
    
    private func lastPageFraction(from totalEighths: Int) -> CGFloat {
        guard totalEighths > 0 else { return 1.0 }
        let pages = totalEighths / 8
        let rem = totalEighths % 8
        if pages == 0 {
            return max(0.125, CGFloat(rem) / 8.0)
        }
        return rem == 0 ? 1.0 : CGFloat(rem) / 8.0
    }
}

#if os(macOS)
// Flipped view to ensure pages render top-to-bottom
private class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

// Flipped page view for individual script pages
private class FlippedPageView: NSView {
    override var isFlipped: Bool { return true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        print("🎯 [FlippedPageView] hitTest at \(point), frame: \(frame), result: \(result?.className ?? "nil")")
        return result
    }

    // Forward mouse events to text view children
    override func mouseDown(with event: NSEvent) {
        print("🖱️ [FlippedPageView] mouseDown - forwarding to subviews")
        // Find the SelectionTrackingTextView child and forward the event
        for subview in subviews {
            if let textView = subview as? SelectionTrackingTextView {
                let locationInWindow = event.locationInWindow
                let locationInTextView = textView.convert(locationInWindow, from: nil)
                if textView.bounds.contains(locationInTextView) {
                    print("   -> Forwarding to SelectionTrackingTextView")
                    textView.window?.makeFirstResponder(textView)
                    textView.mouseDown(with: event)
                    return
                }
            }
        }
        super.mouseDown(with: event)
    }
}

// Custom NSTextView that auto-tags selection when an element type is active
private class SelectionTrackingTextView: NSTextView {
    var sceneID: String = ""
    private var lastTaggedRange: NSRange = NSRange(location: 0, length: 0)

    override var acceptsFirstResponder: Bool {
        print("🎯 [SelectionTrackingTextView] acceptsFirstResponder called, returning true")
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        print("🎯 [SelectionTrackingTextView] hitTest at \(point), frame: \(frame), result: \(result == self ? "SELF" : result?.className ?? "nil")")
        return result
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        print("🎯 [SelectionTrackingTextView] becomeFirstResponder: \(result)")
        return result
    }

    override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let locationInView = convert(locationInWindow, from: nil)
        print("🖱️ [SelectionTrackingTextView] mouseDown - locationInWindow: \(locationInWindow), locationInView: \(locationInView)")
        print("   frame: \(frame), bounds: \(bounds), isSelectable: \(isSelectable), isEditable: \(isEditable)")
        print("   textStorage length: \(textStorage?.length ?? -1), sceneID: '\(sceneID)'")
        print("   superview: \(superview?.className ?? "nil"), window: \(window != nil ? "exists" : "nil")")

        window?.makeFirstResponder(self)
        super.mouseDown(with: event)

        // NSTextView's mouseDown handles the entire drag-to-select loop
        // When it returns, the selection is complete, so check it now
        DispatchQueue.main.async { [weak self] in
            self?.checkAndTagSelection()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        print("🖱️ [SelectionTrackingTextView] mouseDragged")
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        print("🖱️ [SelectionTrackingTextView] mouseUp")
        super.mouseUp(with: event)
        // Also check selection on mouseUp in case mouseDown didn't catch it
        DispatchQueue.main.async { [weak self] in
            self?.checkAndTagSelection()
        }
    }

    private func checkAndTagSelection() {
        let range = selectedRange()
        print("🔍 Selection check - range: \(range), sceneID: '\(sceneID)', elementType: \(HighlightManager.shared.selectedElementType?.rawValue ?? "none")")

        // Skip if no selection or same as last tagged
        guard range.length > 0 else {
            print("   ❌ No text selected (length = 0)")
            return
        }

        // Prevent double-tagging the same selection
        if range == lastTaggedRange {
            print("   ⏭️ Same range already tagged, skipping")
            return
        }

        guard let storage = textStorage else {
            print("   ❌ No text storage")
            return
        }

        let selectedText = storage.attributedSubstring(from: range).string
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !selectedText.isEmpty else {
            print("   ❌ Selected text is empty after trimming")
            return
        }

        guard !sceneID.isEmpty else {
            print("   ❌ sceneID is empty")
            return
        }

        guard let elementType = HighlightManager.shared.selectedElementType else {
            print("   ℹ️ No element type selected - selection ignored (select element type first)")
            return
        }

        print("🏷️ Auto-tagging '\(selectedText.prefix(30))' as \(elementType.rawValue) for scene \(sceneID)")

        // Remember this range to prevent double-tagging
        lastTaggedRange = range

        // Create the highlight
        HighlightManager.shared.autoTag(text: selectedText, sceneID: sceneID)

        // Clear selection after tagging for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setSelectedRange(NSRange(location: 0, length: 0))
        }
    }
}

// MARK: - Centering Clip View
/// Custom NSClipView that centers its document view horizontally
@available(macOS 11.0, *)
private class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)

        guard let documentView = documentView else { return rect }

        // Center horizontally if document is narrower than clip view
        if documentView.frame.width < rect.width {
            rect.origin.x = (documentView.frame.width - rect.width) / 2
        }

        return rect
    }
}

// MARK: - Centering Scroll View
/// Custom NSScrollView that centers its document view horizontally when the content is narrower than the visible area
@available(macOS 11.0, *)
private class CenteringScrollView: NSScrollView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCenteringClipView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCenteringClipView()
    }

    private func setupCenteringClipView() {
        let centeringClipView = CenteringClipView()
        centeringClipView.drawsBackground = false
        self.contentView = centeringClipView
    }
}

@available(macOS 11.0, *)
private struct AttributedTextPageView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let lastPageFraction: CGFloat
    let startingPageNumber: Int
    var sceneID: String?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CenteringScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView.postsBoundsChangedNotifications = true

        // Center the document view horizontally
        scrollView.contentView.postsFrameChangedNotifications = true

        updateContent(in: scrollView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Always update sceneID on existing text views first
        if let container = nsView.documentView {
            for pageView in container.subviews {
                for subview in pageView.subviews {
                    if let textView = subview as? SelectionTrackingTextView {
                        let newSceneID = sceneID ?? ""
                        if textView.sceneID != newSceneID {
                            print("📝 Updating textView sceneID from '\(textView.sceneID)' to '\(newSceneID)'")
                            textView.sceneID = newSceneID
                        }
                    }
                }
            }
        }

        // Check if attributed text changed (including attributes like background colors)
        if let container = nsView.documentView,
           let existingTextView = container.subviews.first?.subviews.compactMap({ $0 as? NSTextView }).first,
           let existingAttrString = existingTextView.textStorage,
           existingAttrString.isEqual(to: attributedText) {
            // Content and attributes unchanged, no rebuild needed
            return
        }

        // Attributed text changed (new highlights added), rebuild content
        print("🔄 Rebuilding script view - highlights changed")
        updateContent(in: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastContentHash: Int = 0
    }

    private func updateContent(in scrollView: NSScrollView) {
        // Remove old container if exists
        if let oldContainer = scrollView.documentView {
            oldContainer.subviews.forEach { $0.removeFromSuperview() }
        }

        let containerView = FlippedView()
        containerView.wantsLayer = true

        let pages = paginate(
            attributedText: attributedText,
            contentSize: CGSize(width: contentWidth, height: contentHeight),
            lastPageFraction: lastPageFraction
        )

        print("📑 FDX Renderer: Created \(pages.count) pages")

        var yOffset: CGFloat = 0
        for (index, page) in pages.enumerated() {
            let pageView = createPageView(with: page, pageNumber: startingPageNumber + index)
            pageView.frame = CGRect(x: 0, y: yOffset, width: pageWidth, height: pageHeight)
            containerView.addSubview(pageView)
            print("📄 Page \(startingPageNumber + index) positioned at y=\(yOffset), text length: \(page.length)")
            yOffset += pageHeight + 20
        }

        let totalHeight = max(yOffset, pageHeight)
        containerView.frame = CGRect(x: 0, y: 0, width: pageWidth, height: totalHeight)
        scrollView.documentView = containerView
        print("✅ FDX Renderer: Container size = \(pageWidth) x \(totalHeight)")
    }

    private func createPageView(with text: NSAttributedString, pageNumber: Int) -> NSView {
        // Use FlippedPageView so y coordinates work top-to-bottom
        let pageView = FlippedPageView()
        pageView.wantsLayer = true
        pageView.layer?.backgroundColor = NSColor.white.cgColor
        pageView.layer?.cornerRadius = 6
        pageView.layer?.shadowColor = NSColor.black.cgColor
        pageView.layer?.shadowOpacity = 0.12
        pageView.layer?.shadowRadius = 8
        pageView.layer?.shadowOffset = CGSize(width: 0, height: 4)

        // Use SelectionTrackingTextView which reports selection to HighlightManager singleton
        // Position: x=108 (1.5" left margin), y=72 (1" top margin)
        let textView = SelectionTrackingTextView(frame: CGRect(x: 108, y: 72, width: contentWidth, height: contentHeight))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize.zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textStorage?.setAttributedString(text)
        textView.sceneID = sceneID ?? ""

        print("  ➡️ TextView created with sceneID: '\(textView.sceneID)', isSelectable: \(textView.isSelectable), chars: \(text.length), elementType: \(HighlightManager.shared.selectedElementType?.rawValue ?? "none")")

        pageView.addSubview(textView)

        // Add page number in top right (Final Draft style)
        // Page 1 typically doesn't show a number
        if pageNumber > 1 {
            let pageNumberLabel = NSTextField(labelWithString: "\(pageNumber).")
            pageNumberLabel.font = NSFont(name: "Courier", size: 12)
            pageNumberLabel.textColor = .black
            pageNumberLabel.alignment = .right
            // With flipped coordinates: y=36 is 36pt from top (in top margin area)
            pageNumberLabel.frame = CGRect(
                x: pageWidth - 72 - 40,  // Align with right margin
                y: 36 - 10,              // Top margin area
                width: 40,
                height: 20
            )
            pageView.addSubview(pageNumberLabel)
        }

        return pageView
    }
    
    private func paginate(attributedText: NSAttributedString, contentSize: CGSize, lastPageFraction: CGFloat) -> [NSAttributedString] {
        let storage = NSTextStorage(attributedString: attributedText)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        
        var pages: [NSAttributedString] = []
        let fullHeight = contentSize.height
        
        while true {
            let container = NSTextContainer(size: CGSize(width: contentSize.width, height: fullHeight))
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            
            layout.ensureLayout(for: container)
            let glyphRange = layout.glyphRange(for: container)
            let charRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            
            if charRange.length == 0 {
                layout.removeTextContainer(at: layout.textContainers.count - 1)
                break
            }
            
            let sub = storage.attributedSubstring(from: charRange)
            pages.append(sub)
            
            let end = charRange.location + charRange.length
            if end >= storage.length { break }
        }
        
        if pages.count >= 2, lastPageFraction > 0, lastPageFraction < 1 {
            let last = pages.removeLast()
            let lastStorage = NSTextStorage(attributedString: last)
            let lastLayout = NSLayoutManager()
            lastStorage.addLayoutManager(lastLayout)
            
            let fracHeight = max(24, contentSize.height * lastPageFraction + 12)
            let fracContainer = NSTextContainer(size: CGSize(width: contentSize.width, height: fracHeight))
            fracContainer.lineFragmentPadding = 0
            lastLayout.addTextContainer(fracContainer)
            lastLayout.ensureLayout(for: fracContainer)
            
            let glyphRange = lastLayout.glyphRange(for: fracContainer)
            let charRange = lastLayout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let clipped = lastStorage.attributedSubstring(from: charRange)
            pages.append(clipped)
        }
        
        return pages
    }
}
#endif

// MARK: - iOS Attributed Text Page View
#if os(iOS)
import UIKit

@available(iOS 14.0, *)
private struct AttributedTextPageViewiOS: UIViewRepresentable {
    let attributedText: NSAttributedString
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let lastPageFraction: CGFloat
    let startingPageNumber: Int

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true

        updateContent(in: scrollView)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Check if we need to rebuild
        if uiView.subviews.first?.tag != attributedText.hash {
            updateContent(in: uiView)
        }
    }

    private func updateContent(in scrollView: UIScrollView) {
        // Remove old content
        scrollView.subviews.forEach { $0.removeFromSuperview() }

        let containerView = UIView()
        containerView.tag = attributedText.hash

        let pages = paginate(
            attributedText: attributedText,
            contentSize: CGSize(width: contentWidth, height: contentHeight),
            lastPageFraction: lastPageFraction
        )

        var yOffset: CGFloat = 0
        for (index, page) in pages.enumerated() {
            let pageView = createPageView(with: page, pageNumber: startingPageNumber + index)
            pageView.frame = CGRect(x: 0, y: yOffset, width: pageWidth, height: pageHeight)
            containerView.addSubview(pageView)
            yOffset += pageHeight + 20
        }

        let totalHeight = max(yOffset, pageHeight)
        containerView.frame = CGRect(x: 0, y: 0, width: pageWidth, height: totalHeight)
        scrollView.addSubview(containerView)
        scrollView.contentSize = CGSize(width: pageWidth, height: totalHeight)
    }

    private func createPageView(with text: NSAttributedString, pageNumber: Int) -> UIView {
        // Standard screenplay margins (8.5" x 11" at 72 DPI = 612 x 792)
        // Left margin: 1.5" = 108pt, Right margin: 1" = 72pt
        // Top margin: 1" = 72pt, Bottom margin: 1" = 72pt
        let leftMargin: CGFloat = 108
        let rightMargin: CGFloat = 72
        let topMargin: CGFloat = 72
        let bottomMargin: CGFloat = 72

        let pageView = UIView()
        pageView.backgroundColor = .white
        pageView.layer.cornerRadius = 6
        pageView.layer.shadowColor = UIColor.black.cgColor
        pageView.layer.shadowOpacity = 0.15
        pageView.layer.shadowOffset = CGSize(width: 0, height: 2)
        pageView.layer.shadowRadius = 8

        // Page number label - positioned in top right margin area (Final Draft style)
        // Page 1 typically doesn't show a number
        if pageNumber > 1 {
            let pageLabel = UILabel()
            pageLabel.text = "\(pageNumber)."
            pageLabel.font = UIFont(name: "Courier", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
            pageLabel.textColor = .darkGray
            pageLabel.frame = CGRect(x: pageWidth - rightMargin - 40, y: topMargin / 2 - 8, width: 40, height: 16)
            pageLabel.textAlignment = .right
            pageView.addSubview(pageLabel)
        }

        // Text view for content - positioned with proper screenplay margins
        let textView = UITextView()
        textView.attributedText = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        // Use proper screenplay insets: top 72, left 108, bottom 72, right 72
        textView.textContainerInset = UIEdgeInsets(top: topMargin, left: leftMargin, bottom: bottomMargin, right: rightMargin)
        textView.textContainer.lineFragmentPadding = 0
        textView.frame = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        textView.isScrollEnabled = false
        pageView.addSubview(textView)

        return pageView
    }

    private func paginate(attributedText: NSAttributedString, contentSize: CGSize, lastPageFraction: CGFloat) -> [NSAttributedString] {
        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var pages: [NSAttributedString] = []
        var location = 0

        while location < storage.length {
            let container = NSTextContainer(size: contentSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)

            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            if glyphRange.length == 0 { break }

            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            if charRange.length == 0 { break }

            let sub = storage.attributedSubstring(from: charRange)
            pages.append(sub)

            location = charRange.location + charRange.length
            if location >= storage.length { break }
        }

        // Handle last page fraction for partial pages
        if pages.count >= 2, lastPageFraction > 0, lastPageFraction < 1 {
            let last = pages.removeLast()
            let lastStorage = NSTextStorage(attributedString: last)
            let lastLayout = NSLayoutManager()
            lastStorage.addLayoutManager(lastLayout)

            let fracHeight = max(24, contentSize.height * lastPageFraction + 12)
            let fracContainer = NSTextContainer(size: CGSize(width: contentSize.width, height: fracHeight))
            fracContainer.lineFragmentPadding = 0
            lastLayout.addTextContainer(fracContainer)
            lastLayout.ensureLayout(for: fracContainer)

            let glyphRange = lastLayout.glyphRange(for: fracContainer)
            let charRange = lastLayout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let clipped = lastStorage.attributedSubstring(from: charRange)
            pages.append(clipped)
        }

        return pages
    }
}
#endif

#endif
