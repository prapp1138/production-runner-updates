//
//  ScreenplayPDFParser.swift
//  Production Runner
//
//  Screenplay element classification engine.
//  Uses position data and text patterns to identify screenplay elements.
//

import Foundation

// MARK: - Parsed Screenplay Element

/// A screenplay element parsed from PDF
public struct PDFParsedElement: Identifiable, Equatable {
    public let id = UUID()

    /// Element type (scene heading, action, character, dialogue, etc.)
    public var type: PDFElementType

    /// The text content
    public var text: String

    /// Original text before normalization (for debugging)
    public let originalText: String

    /// Page number where this element appears
    public var pageNumber: Int

    /// Scene number (only for scene headings)
    public var sceneNumber: String?

    /// Confidence score (0.0 to 1.0) - how confident we are in the classification
    public let confidence: Double

    /// Left indent from margin (in points)
    public let leftIndent: CGFloat

    /// Source lines that make up this element
    public let sourceLines: [PDFTextLine]

    public init(
        type: PDFElementType,
        text: String,
        originalText: String? = nil,
        pageNumber: Int,
        sceneNumber: String? = nil,
        confidence: Double = 1.0,
        leftIndent: CGFloat = 0,
        sourceLines: [PDFTextLine] = []
    ) {
        self.type = type
        self.text = text
        self.originalText = originalText ?? text
        self.pageNumber = pageNumber
        self.sceneNumber = sceneNumber
        self.confidence = confidence
        self.leftIndent = leftIndent
        self.sourceLines = sourceLines
    }
}

// MARK: - Element Type

public enum PDFElementType: String, CaseIterable, Codable {
    case sceneHeading = "Scene Heading"
    case action = "Action"
    case character = "Character"
    case parenthetical = "Parenthetical"
    case dialogue = "Dialogue"
    case transition = "Transition"
    case shot = "Shot"
    case pageNumber = "Page Number"
    case titlePage = "Title Page"
    case unknown = "Unknown"

    /// Whether this element type is typically ALL CAPS
    public var isAllCaps: Bool {
        switch self {
        case .sceneHeading, .character, .transition, .shot:
            return true
        default:
            return false
        }
    }
}

// MARK: - Parsed Scene

/// A complete scene parsed from PDF
public struct PDFParsedScene: Identifiable, Equatable {
    public let id = UUID()

    /// Scene number (e.g., "1", "12A")
    public var numberString: String

    /// Full heading text (e.g., "INT. KITCHEN - DAY")
    public var headingText: String

    /// Location type (INT, EXT, INT/EXT)
    public var locationType: String

    /// Script location (e.g., "KITCHEN")
    public var scriptLocation: String

    /// Time of day (DAY, NIGHT, etc.)
    public var timeOfDay: String

    /// Page number where scene starts
    public var pageNumber: String?

    /// Estimated page length in eighths (e.g., 4 = 4/8 page)
    public var pageLengthEighths: Int?

    /// Full scene body text
    public var scriptText: String?

    /// All elements in this scene
    public var elements: [PDFParsedElement]

    /// Import order (1-based)
    public var ordinal: Int

    public init(
        numberString: String,
        headingText: String,
        locationType: String = "",
        scriptLocation: String = "",
        timeOfDay: String = "",
        pageNumber: String? = nil,
        pageLengthEighths: Int? = nil,
        scriptText: String? = nil,
        elements: [PDFParsedElement] = [],
        ordinal: Int = 0
    ) {
        self.numberString = numberString
        self.headingText = headingText
        self.locationType = locationType
        self.scriptLocation = scriptLocation
        self.timeOfDay = timeOfDay
        self.pageNumber = pageNumber
        self.pageLengthEighths = pageLengthEighths
        self.scriptText = scriptText
        self.elements = elements
        self.ordinal = ordinal
    }
}

// MARK: - Parser Result

/// Complete result of parsing a screenplay PDF
public struct PDFParseResult {
    /// Title (from metadata or first page)
    public var title: String?

    /// Author (from metadata or title page)
    public var author: String?

    /// All parsed scenes
    public var scenes: [PDFParsedScene]

    /// All elements in document order
    public var elements: [PDFParsedElement]

    /// Total page count
    public var pageCount: Int

    /// Parsing warnings/notes
    public var warnings: [String]

    /// Overall confidence (average of element confidences)
    public var overallConfidence: Double {
        guard !elements.isEmpty else { return 0 }
        return elements.reduce(0.0) { $0 + $1.confidence } / Double(elements.count)
    }

    public init(
        title: String? = nil,
        author: String? = nil,
        scenes: [PDFParsedScene] = [],
        elements: [PDFParsedElement] = [],
        pageCount: Int = 0,
        warnings: [String] = []
    ) {
        self.title = title
        self.author = author
        self.scenes = scenes
        self.elements = elements
        self.pageCount = pageCount
        self.warnings = warnings
    }
}

// MARK: - Screenplay PDF Parser

/// Main parser class for classifying PDF text into screenplay elements
public final class ScreenplayPDFParser {

    public static let shared = ScreenplayPDFParser()

    // MARK: - Configuration

    /// Screenplay formatting constants (from ScreenplayFormat)
    private struct Format {
        // Standard indents (in points from left content edge)
        static let actionIndent: CGFloat = 0
        static let characterIndent: CGFloat = 180       // ~2.5" from content left
        static let dialogueIndent: CGFloat = 72         // ~1" from content left
        static let parentheticalIndent: CGFloat = 108   // ~1.5" from content left
        static let transitionIndent: CGFloat = 288      // Right-aligned

        // Tolerances for indent matching
        static let indentTolerance: CGFloat = 25

        // Content margins
        static let leftMargin: CGFloat = 108   // 1.5"
        static let rightMargin: CGFloat = 72   // 1"
        static let topMargin: CGFloat = 72     // 1"
    }

    // MARK: - Public API

    /// Parse extracted PDF text into screenplay elements and scenes
    /// - Parameter extraction: The result from PDFTextExtractor
    /// - Returns: Parsed screenplay result with scenes and elements
    public func parse(_ extraction: PDFExtractionResult) -> PDFParseResult {
        var elements: [PDFParsedElement] = []
        var warnings: [String] = []

        // First pass: classify individual lines
        for page in extraction.pages {
            let pageElements = classifyLines(page.lines, pageNumber: page.pageNumber)
            elements.append(contentsOf: pageElements)
        }

        // Second pass: merge adjacent elements and refine classifications
        elements = mergeAndRefine(elements)

        // Third pass: apply context-aware corrections
        elements = applyContextCorrections(elements)

        // Fourth pass: extract scenes from scene headings
        let scenes = extractScenes(from: elements)

        // Check for parsing issues
        if scenes.isEmpty {
            warnings.append("No scenes detected. PDF may not be a screenplay or may use non-standard formatting.")
        }

        let sceneHeadingCount = elements.filter { $0.type == .sceneHeading }.count
        if sceneHeadingCount == 0 {
            warnings.append("No scene headings found. INT./EXT. patterns not detected.")
        }

        return PDFParseResult(
            title: extraction.title,
            author: extraction.author,
            scenes: scenes,
            elements: elements,
            pageCount: extraction.pageCount,
            warnings: warnings
        )
    }

    // MARK: - Line Classification

    private func classifyLines(_ lines: [PDFTextLine], pageNumber: Int) -> [PDFParsedElement] {
        var elements: [PDFParsedElement] = []

        for line in lines {
            let element = classifyLine(line, pageNumber: pageNumber)
            elements.append(element)
        }

        return elements
    }

    private func classifyLine(_ line: PDFTextLine, pageNumber: Int) -> PDFParsedElement {
        let text = line.trimmedText
        let upper = text.uppercased()
        let indent = line.leftIndent

        // Check for page number (typically in header/footer area)
        if line.y < 72 || line.y > 720 { // Top or bottom margin
            if looksLikePageNumber(text) {
                return PDFParsedElement(
                    type: .pageNumber,
                    text: text,
                    pageNumber: pageNumber,
                    confidence: 0.95,
                    leftIndent: indent,
                    sourceLines: [line]
                )
            }
        }

        // Scene Heading detection (highest priority)
        if let sceneHeading = detectSceneHeading(text: text, upper: upper, line: line, pageNumber: pageNumber) {
            return sceneHeading
        }

        // Transition detection
        if let transition = detectTransition(text: text, upper: upper, indent: indent, line: line, pageNumber: pageNumber) {
            return transition
        }

        // Parenthetical detection
        if let parenthetical = detectParenthetical(text: text, indent: indent, line: line, pageNumber: pageNumber) {
            return parenthetical
        }

        // Character name detection (based on indent and ALL CAPS)
        if let character = detectCharacter(text: text, upper: upper, indent: indent, line: line, pageNumber: pageNumber) {
            return character
        }

        // Dialogue detection (based on indent)
        if let dialogue = detectDialogue(text: text, indent: indent, line: line, pageNumber: pageNumber) {
            return dialogue
        }

        // Shot detection
        if let shot = detectShot(text: text, upper: upper, line: line, pageNumber: pageNumber) {
            return shot
        }

        // Default to action
        return PDFParsedElement(
            type: .action,
            text: text,
            pageNumber: pageNumber,
            confidence: 0.6,
            leftIndent: indent,
            sourceLines: [line]
        )
    }

    // MARK: - Element Detection

    private func detectSceneHeading(
        text: String,
        upper: String,
        line: PDFTextLine,
        pageNumber: Int
    ) -> PDFParsedElement? {
        // Standard scene heading patterns
        let headingPrefixes = [
            "INT.", "INT ", "EXT.", "EXT ",
            "INT./EXT.", "INT/EXT.", "INT./EXT ", "INT/EXT ",
            "I/E.", "I/E "
        ]

        for prefix in headingPrefixes {
            if upper.hasPrefix(prefix) {
                // Extract scene number if present at start
                var sceneNumber: String? = nil
                var headingText = text

                // Check for scene number pattern like "1 INT." or "12A EXT."
                let sceneNumPattern = #"^(\d+[A-Z]?)\s+(INT|EXT|I/E)"#
                if let regex = try? NSRegularExpression(pattern: sceneNumPattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: upper, options: [], range: NSRange(upper.startIndex..<upper.endIndex, in: upper)),
                   let numRange = Range(match.range(at: 1), in: upper) {
                    sceneNumber = String(upper[numRange])
                    // Remove scene number from heading text
                    if let textNumRange = Range(match.range(at: 1), in: text) {
                        headingText = String(text[textNumRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                }

                return PDFParsedElement(
                    type: .sceneHeading,
                    text: headingText.uppercased(),
                    originalText: text,
                    pageNumber: pageNumber,
                    sceneNumber: sceneNumber,
                    confidence: 0.95,
                    leftIndent: line.leftIndent,
                    sourceLines: [line]
                )
            }
        }

        return nil
    }

    private func detectTransition(
        text: String,
        upper: String,
        indent: CGFloat,
        line: PDFTextLine,
        pageNumber: Int
    ) -> PDFParsedElement? {
        // Transitions are right-aligned and end with ":"
        let transitionPatterns = [
            "CUT TO:",
            "FADE TO:",
            "DISSOLVE TO:",
            "SMASH CUT:",
            "MATCH CUT:",
            "JUMP CUT:",
            "FADE IN:",
            "FADE OUT.",
            "FADE OUT:",
            "THE END"
        ]

        for pattern in transitionPatterns {
            if upper.contains(pattern) || upper.hasSuffix("TO:") {
                return PDFParsedElement(
                    type: .transition,
                    text: upper,
                    originalText: text,
                    pageNumber: pageNumber,
                    confidence: 0.9,
                    leftIndent: indent,
                    sourceLines: [line]
                )
            }
        }

        return nil
    }

    private func detectParenthetical(
        text: String,
        indent: CGFloat,
        line: PDFTextLine,
        pageNumber: Int
    ) -> PDFParsedElement? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // Parentheticals are wrapped in parentheses
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            let confidence: Double = abs(indent - Format.parentheticalIndent) < Format.indentTolerance ? 0.9 : 0.75
            return PDFParsedElement(
                type: .parenthetical,
                text: trimmed,
                pageNumber: pageNumber,
                confidence: confidence,
                leftIndent: indent,
                sourceLines: [line]
            )
        }

        return nil
    }

    private func detectCharacter(
        text: String,
        upper: String,
        indent: CGFloat,
        line: PDFTextLine,
        pageNumber: Int
    ) -> PDFParsedElement? {
        // Character names are:
        // 1. ALL CAPS
        // 2. Indented to character position (~2.5" from left margin)
        // 3. Short (typically under 40 characters)
        // 4. May have (V.O.), (O.S.), (CONT'D) etc.

        guard line.isAllCaps else { return nil }
        guard text.count < 50 else { return nil }
        guard text.count > 1 else { return nil }

        // Check indent is in character range
        let isCharacterIndent = abs(indent - Format.characterIndent) < Format.indentTolerance

        // Also check for character extensions
        let hasExtension = upper.contains("(V.O.)") ||
                           upper.contains("(O.S.)") ||
                           upper.contains("(O.C.)") ||
                           upper.contains("(CONT'D)") ||
                           upper.contains("(CONT'D)") ||
                           upper.hasSuffix(" (V.O.") ||
                           upper.hasSuffix(" (O.S.")

        // Must have some letters (not just numbers or punctuation)
        let hasLetters = text.rangeOfCharacter(from: .letters) != nil

        if (isCharacterIndent || hasExtension) && hasLetters {
            let confidence: Double = isCharacterIndent ? 0.85 : 0.7
            return PDFParsedElement(
                type: .character,
                text: upper,
                originalText: text,
                pageNumber: pageNumber,
                confidence: confidence,
                leftIndent: indent,
                sourceLines: [line]
            )
        }

        return nil
    }

    private func detectDialogue(
        text: String,
        indent: CGFloat,
        line: PDFTextLine,
        pageNumber: Int
    ) -> PDFParsedElement? {
        // Dialogue is indented to dialogue position (~1" from content edge)
        let isDialogueIndent = abs(indent - Format.dialogueIndent) < Format.indentTolerance

        if isDialogueIndent && !line.isAllCaps {
            return PDFParsedElement(
                type: .dialogue,
                text: text,
                pageNumber: pageNumber,
                confidence: 0.7,
                leftIndent: indent,
                sourceLines: [line]
            )
        }

        return nil
    }

    private func detectShot(
        text: String,
        upper: String,
        line: PDFTextLine,
        pageNumber: Int
    ) -> PDFParsedElement? {
        // Shot descriptions like "ANGLE ON", "CLOSE ON", "POV"
        let shotPrefixes = [
            "ANGLE ON", "CLOSE ON", "CLOSE UP", "CLOSEUP",
            "WIDE ON", "MEDIUM ON", "POV", "INSERT",
            "TIGHT ON", "PUSH IN", "PULL BACK",
            "PAN TO", "DOLLY", "CRANE", "AERIAL"
        ]

        for prefix in shotPrefixes {
            if upper.hasPrefix(prefix) {
                return PDFParsedElement(
                    type: .shot,
                    text: upper,
                    originalText: text,
                    pageNumber: pageNumber,
                    confidence: 0.85,
                    leftIndent: line.leftIndent,
                    sourceLines: [line]
                )
            }
        }

        return nil
    }

    // MARK: - Post-Processing

    private func mergeAndRefine(_ elements: [PDFParsedElement]) -> [PDFParsedElement] {
        guard !elements.isEmpty else { return [] }

        var result: [PDFParsedElement] = []
        // Safe: already validated elements is not empty above
        var current = elements[0]

        for i in 1..<elements.count {
            let next = elements[i]

            // Merge consecutive elements of same type (except scene headings)
            if current.type == next.type &&
               current.type != .sceneHeading &&
               current.type != .character &&
               current.type != .pageNumber &&
               current.pageNumber == next.pageNumber {

                // Merge text
                var merged = current
                merged.text = current.text + "\n" + next.text
                current = merged
            } else {
                result.append(current)
                current = next
            }
        }
        result.append(current)

        return result
    }

    private func applyContextCorrections(_ elements: [PDFParsedElement]) -> [PDFParsedElement] {
        guard elements.count > 1 else { return elements }

        var corrected = elements

        for i in 0..<corrected.count {
            let element = corrected[i]

            // If we see text after a character that's not dialogue/parenthetical,
            // and it's indented like dialogue, it should be dialogue
            if i > 0 {
                let prev = corrected[i - 1]
                if prev.type == .character &&
                   element.type == .action &&
                   abs(element.leftIndent - Format.dialogueIndent) < Format.indentTolerance {
                    corrected[i] = PDFParsedElement(
                        type: .dialogue,
                        text: element.text,
                        originalText: element.originalText,
                        pageNumber: element.pageNumber,
                        confidence: 0.8,
                        leftIndent: element.leftIndent,
                        sourceLines: element.sourceLines
                    )
                }
            }

            // If we have parenthetical after parenthetical, second should be dialogue
            if i > 0 {
                let prev = corrected[i - 1]
                if prev.type == .parenthetical && element.type == .parenthetical {
                    corrected[i] = PDFParsedElement(
                        type: .dialogue,
                        text: element.text,
                        originalText: element.originalText,
                        pageNumber: element.pageNumber,
                        confidence: 0.7,
                        leftIndent: element.leftIndent,
                        sourceLines: element.sourceLines
                    )
                }
            }
        }

        return corrected
    }

    // MARK: - Scene Extraction

    private func extractScenes(from elements: [PDFParsedElement]) -> [PDFParsedScene] {
        var scenes: [PDFParsedScene] = []
        var currentScene: PDFParsedScene? = nil
        var sceneOrdinal = 0
        var autoSceneNumber = 0

        for element in elements {
            if element.type == .pageNumber {
                continue // Skip page numbers
            }

            if element.type == .sceneHeading {
                // Finalize previous scene
                if var scene = currentScene {
                    scene.scriptText = buildScriptText(from: scene.elements)
                    scenes.append(scene)
                }

                // Start new scene
                sceneOrdinal += 1
                autoSceneNumber += 1

                let (locType, scriptLoc, tod) = parseHeadingComponents(element.text)

                currentScene = PDFParsedScene(
                    numberString: element.sceneNumber ?? "\(autoSceneNumber)",
                    headingText: element.text,
                    locationType: locType,
                    scriptLocation: scriptLoc,
                    timeOfDay: tod,
                    pageNumber: "\(element.pageNumber)",
                    elements: [element],
                    ordinal: sceneOrdinal
                )
            } else if var scene = currentScene {
                // Add element to current scene
                scene.elements.append(element)
                currentScene = scene
            }
        }

        // Finalize last scene
        if var scene = currentScene {
            scene.scriptText = buildScriptText(from: scene.elements)
            scenes.append(scene)
        }

        // Calculate page lengths
        scenes = calculatePageLengths(scenes)

        return scenes
    }

    private func buildScriptText(from elements: [PDFParsedElement]) -> String {
        var parts: [String] = []

        for element in elements {
            switch element.type {
            case .sceneHeading:
                continue // Skip heading in body text
            case .character:
                parts.append("\n" + element.text)
            case .parenthetical:
                parts.append("(" + element.text.trimmingCharacters(in: CharacterSet(charactersIn: "()")) + ")")
            case .dialogue:
                parts.append(element.text)
            case .transition:
                parts.append("\n" + element.text)
            case .action, .shot:
                parts.append(element.text)
            default:
                break
            }
        }

        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func calculatePageLengths(_ scenes: [PDFParsedScene]) -> [PDFParsedScene] {
        guard scenes.count > 1 else {
            return scenes.map { scene in
                var s = scene
                s.pageLengthEighths = 8 // Default to 1 page
                return s
            }
        }

        var result: [PDFParsedScene] = []

        for i in 0..<scenes.count {
            var scene = scenes[i]

            if i < scenes.count - 1 {
                let nextScene = scenes[i + 1]
                let startPage = Int(scene.pageNumber ?? "1") ?? 1
                let endPage = Int(nextScene.pageNumber ?? "\(startPage)") ?? startPage

                // Rough estimate: each page is 8 eighths
                let pageSpan = max(1, endPage - startPage + 1)
                scene.pageLengthEighths = pageSpan * 8 / 2 // Conservative estimate
            } else {
                scene.pageLengthEighths = 4 // Last scene default
            }

            result.append(scene)
        }

        return result
    }

    // MARK: - Heading Parsing

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

    // MARK: - Utilities

    private func looksLikePageNumber(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 10 else { return false }

        // Must have at least one digit
        guard trimmed.rangeOfCharacter(from: .decimalDigits) != nil else { return false }

        // Common patterns
        let patterns = [
            #"^\d+\.?$"#,              // "1" or "1."
            #"^Page\s*\d+"#,           // "Page 1"
            #"^\d+\s*[-–]\s*\d+$"#,    // "1-2" (continued)
            #"^\d+[A-Z]?\.?$"#         // "12A"
        ]

        for pattern in patterns {
            if trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }

        return false
    }
}
