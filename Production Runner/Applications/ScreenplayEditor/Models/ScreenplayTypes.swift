//
//  ScreenplayTypes.swift
//  Production Runner
//
//  Industry-standard screenplay formatting constants and types.
//  Based on Final Draft formatting specifications.
//

import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Scene Number Position

/// Controls where scene numbers appear in the margins
enum SceneNumberPosition: String, CaseIterable, Identifiable {
    case none = "None"
    case left = "Left"
    case right = "Right"
    case both = "Both"

    var id: String { rawValue }

    var showLeft: Bool {
        self == .left || self == .both
    }

    var showRight: Bool {
        self == .right || self == .both
    }

    var isEnabled: Bool {
        self != .none
    }
}

// MARK: - Scene Number

/// Represents a screenplay scene number with support for inserted scenes
/// Industry standard:
/// - Original scenes: 1, 2, 3, etc.
/// - Scene inserted AFTER scene 12: 12A, 12B, 12C, etc.
/// - Scene inserted BEFORE scene 12: A12, B12, C12, etc.
/// - Nested insertions: 12AA, 12AB (after 12A), AA12, AB12 (before A12)
struct SceneNumber: Codable, Equatable, Hashable, CustomStringConvertible {
    /// The base number (e.g., 12 in "12A" or "A12")
    let baseNumber: Int

    /// Suffix letters for scenes inserted AFTER (e.g., "A" in "12A", "AA" in "12AA")
    let suffix: String

    /// Prefix letters for scenes inserted BEFORE (e.g., "A" in "A12", "AA" in "AA12")
    let prefix: String

    init(baseNumber: Int, suffix: String = "", prefix: String = "") {
        self.baseNumber = baseNumber
        self.suffix = suffix.uppercased()
        self.prefix = prefix.uppercased()
    }

    /// Create a simple numeric scene number
    init(_ number: Int) {
        self.baseNumber = number
        self.suffix = ""
        self.prefix = ""
    }

    /// Parse a scene number string (e.g., "12", "12A", "A12", "12AA", "AA12")
    init?(from string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else { return nil }

        // Check for prefix pattern (letters before number): A12, AA12, etc.
        if let match = trimmed.firstMatch(of: /^([A-Z]+)(\d+)([A-Z]*)$/) {
            guard let num = Int(match.2) else { return nil }
            self.prefix = String(match.1)
            self.baseNumber = num
            self.suffix = String(match.3)
            return
        }

        // Check for suffix pattern (letters after number): 12A, 12AA, etc.
        if let match = trimmed.firstMatch(of: /^(\d+)([A-Z]*)$/) {
            guard let num = Int(match.1) else { return nil }
            self.baseNumber = num
            self.suffix = String(match.2)
            self.prefix = ""
            return
        }

        return nil
    }

    var description: String {
        "\(prefix)\(baseNumber)\(suffix)"
    }

    /// Whether this is a simple numeric scene (no insertions)
    var isSimple: Bool {
        prefix.isEmpty && suffix.isEmpty
    }

    /// Whether this scene was inserted after another scene
    var isInsertedAfter: Bool {
        !suffix.isEmpty
    }

    /// Whether this scene was inserted before another scene
    var isInsertedBefore: Bool {
        !prefix.isEmpty
    }

    /// Generate the next scene number for inserting AFTER this scene
    /// 12 → 12A, 12A → 12B, 12Z → 12AA
    func nextAfter() -> SceneNumber {
        let nextSuffix = Self.incrementLetters(suffix.isEmpty ? "" : suffix)
        return SceneNumber(baseNumber: baseNumber, suffix: nextSuffix, prefix: prefix)
    }

    /// Generate the next scene number for inserting BEFORE this scene
    /// 12 → A12, A12 → B12, Z12 → AA12
    func nextBefore() -> SceneNumber {
        let nextPrefix = Self.incrementLetters(prefix.isEmpty ? "" : prefix)
        return SceneNumber(baseNumber: baseNumber, suffix: suffix, prefix: nextPrefix)
    }

    /// Increment letter sequence: "" → "A", "A" → "B", "Z" → "AA", "AZ" → "BA"
    private static func incrementLetters(_ letters: String) -> String {
        if letters.isEmpty {
            return "A"
        }

        var chars = Array(letters)
        var i = chars.count - 1

        while i >= 0 {
            if chars[i] == "Z" {
                chars[i] = "A"
                i -= 1
            } else {
                chars[i] = Character(UnicodeScalar(chars[i].asciiValue! + 1))
                return String(chars)
            }
        }

        // All were Z, need to add another A at the beginning
        return "A" + String(chars)
    }

    /// Compare scene numbers for sorting
    /// Order: 1, A1, B1, 1A, 1B, 2, A2, 2A, etc.
    static func < (lhs: SceneNumber, rhs: SceneNumber) -> Bool {
        // First compare base numbers
        if lhs.baseNumber != rhs.baseNumber {
            return lhs.baseNumber < rhs.baseNumber
        }

        // Same base number - prefixed scenes come before the base
        // A12 < 12 < 12A
        if !lhs.prefix.isEmpty && rhs.prefix.isEmpty && rhs.suffix.isEmpty {
            return true
        }
        if lhs.prefix.isEmpty && lhs.suffix.isEmpty && !rhs.prefix.isEmpty {
            return false
        }

        // Both have prefixes - compare prefixes
        if !lhs.prefix.isEmpty && !rhs.prefix.isEmpty {
            return lhs.prefix < rhs.prefix
        }

        // Base scene comes before suffixed scenes
        // 12 < 12A
        if lhs.suffix.isEmpty && !rhs.suffix.isEmpty {
            return true
        }
        if !lhs.suffix.isEmpty && rhs.suffix.isEmpty {
            return false
        }

        // Both have suffixes - compare suffixes
        if !lhs.suffix.isEmpty && !rhs.suffix.isEmpty {
            // Shorter suffix comes first (A < AA)
            if lhs.suffix.count != rhs.suffix.count {
                return lhs.suffix.count < rhs.suffix.count
            }
            return lhs.suffix < rhs.suffix
        }

        return false
    }
}

extension SceneNumber: Comparable {}

// MARK: - Script Element Types

enum ScriptElementType: String, CaseIterable, Identifiable, Codable {
    case sceneHeading = "Scene Heading"
    case action = "Action"
    case character = "Character"
    case parenthetical = "Parenthetical"
    case dialogue = "Dialogue"
    case transition = "Transition"
    case shot = "Shot"
    case general = "General"
    case titlePage = "Title Page"  // Deprecated: Title page is now a separate UI

    var id: String { rawValue }

    /// Element types available in the editor UI (excludes titlePage which is now separate)
    static var editorCases: [ScriptElementType] {
        allCases.filter { $0 != .titlePage }
    }

    /// Keyboard shortcut (Cmd+number)
    var shortcutKey: String {
        switch self {
        case .sceneHeading: return "1"
        case .action: return "2"
        case .character: return "3"
        case .parenthetical: return "4"
        case .dialogue: return "5"
        case .transition: return "6"
        case .shot: return "7"
        case .general: return "8"
        case .titlePage: return "9"
        }
    }

    /// What element follows after pressing Enter
    var nextElementOnEnter: ScriptElementType {
        switch self {
        case .sceneHeading: return .action
        case .action: return .character  // Single Enter after action prompts character
        case .character: return .dialogue
        case .parenthetical: return .dialogue
        case .dialogue: return .character
        case .transition: return .sceneHeading
        case .shot: return .action
        case .general: return .general
        case .titlePage: return .titlePage
        }
    }

    /// What element follows after pressing Enter on empty line
    /// Cycles through: Action → Character → Parenthetical → Dialogue → Scene Heading → Transition → Action
    var nextElementOnDoubleEnter: ScriptElementType {
        switch self {
        case .sceneHeading: return .transition
        case .action: return .character
        case .character: return .parenthetical
        case .parenthetical: return .dialogue
        case .dialogue: return .sceneHeading
        case .transition: return .action
        case .shot: return .action
        case .general: return .sceneHeading
        case .titlePage: return .sceneHeading
        }
    }

    /// Elements available when pressing Tab
    var tabCycleElements: [ScriptElementType] {
        switch self {
        case .sceneHeading: return [.action, .character, .transition]
        case .action: return [.character, .sceneHeading, .transition]
        case .character: return [.parenthetical, .dialogue, .action]
        case .parenthetical: return [.dialogue, .character]
        case .dialogue: return [.character, .parenthetical, .action]
        case .transition: return [.sceneHeading, .action]
        case .shot: return [.action, .character]
        case .general: return [.action, .sceneHeading]
        case .titlePage: return [.sceneHeading]
        }
    }

    /// Whether this element should be ALL CAPS
    var isAllCaps: Bool {
        switch self {
        case .sceneHeading, .character, .transition, .shot:
            return true
        default:
            return false
        }
    }

    /// Auto-detect element type from text
    static func detect(from text: String) -> ScriptElementType? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let upper = trimmed.uppercased()

        // Scene Heading
        if upper.hasPrefix("INT.") || upper.hasPrefix("INT ") ||
           upper.hasPrefix("EXT.") || upper.hasPrefix("EXT ") ||
           upper.hasPrefix("INT/EXT") || upper.hasPrefix("I/E") {
            return .sceneHeading
        }

        // Transition
        if upper.hasSuffix("TO:") || upper == "FADE IN:" ||
           upper == "FADE OUT." || upper == "CUT TO:" ||
           upper == "DISSOLVE TO:" || upper == "SMASH CUT:" {
            return .transition
        }

        // Parenthetical
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            return .parenthetical
        }

        return nil
    }
}

// MARK: - Formatting Constants (Industry Standard)

/// All measurements in points (72 points = 1 inch)
struct ScreenplayFormat {

    // MARK: - Shared Constants Alias
    // All formatting values come from ScriptFormatConstants for consistency
    private typealias Fmt = ScriptFormatConstants

    // MARK: - Page Dimensions

    static let pageWidth: CGFloat = Fmt.pageWidth
    static let pageHeight: CGFloat = Fmt.pageHeight

    // MARK: - Margins (Final Draft standard)

    static let marginLeft: CGFloat = Fmt.marginLeft
    static let marginRight: CGFloat = Fmt.marginRight
    static let marginTop: CGFloat = Fmt.marginTop
    static let marginBottom: CGFloat = Fmt.marginBottom

    static let contentWidth: CGFloat = Fmt.contentWidth
    static let contentHeight: CGFloat = Fmt.contentHeight

    // MARK: - Typography

    static let fontName = Fmt.fontName
    static let fontSize: CGFloat = Fmt.fontSize
    static let lineHeight: CGFloat = Fmt.lineHeight

    // MARK: - Element Indents (from content left edge)

    static let sceneHeadingLeftIndent: CGFloat = Fmt.sceneHeadingLeftIndent
    static let sceneHeadingRightIndent: CGFloat = Fmt.sceneHeadingRightIndent

    static let actionLeftIndent: CGFloat = Fmt.actionLeftIndent
    static let actionRightIndent: CGFloat = Fmt.actionRightIndent

    static let characterLeftIndent: CGFloat = Fmt.characterLeftIndent
    static let characterRightIndent: CGFloat = Fmt.characterRightIndent

    static let dialogueLeftIndent: CGFloat = Fmt.dialogueLeftIndent
    static let dialogueRightIndent: CGFloat = Fmt.dialogueRightIndent

    static let parentheticalLeftIndent: CGFloat = Fmt.parentheticalLeftIndent
    static let parentheticalRightIndent: CGFloat = Fmt.parentheticalRightIndent

    static let transitionLeftIndent: CGFloat = Fmt.transitionLeftIndent
    static let transitionRightIndent: CGFloat = Fmt.transitionRightIndent

    // MARK: - Paragraph Spacing (blank lines)

    static let blankLine: CGFloat = Fmt.blankLine

    static let sceneHeadingSpaceBefore: CGFloat = Fmt.sceneHeadingSpaceBefore
    static let sceneHeadingSpaceAfter: CGFloat = Fmt.sceneHeadingSpaceAfter

    static let actionSpaceBefore: CGFloat = Fmt.actionSpaceBefore
    static let actionSpaceAfter: CGFloat = Fmt.actionSpaceAfter

    static let characterSpaceBefore: CGFloat = Fmt.characterSpaceBefore
    static let characterSpaceAfter: CGFloat = Fmt.characterSpaceAfter

    static let parentheticalSpaceBefore: CGFloat = Fmt.parentheticalSpaceBefore
    static let parentheticalSpaceAfter: CGFloat = Fmt.parentheticalSpaceAfter

    static let dialogueSpaceBefore: CGFloat = Fmt.dialogueSpaceBefore
    static let dialogueSpaceAfter: CGFloat = Fmt.dialogueSpaceAfter

    static let transitionSpaceBefore: CGFloat = Fmt.transitionSpaceBefore
    static let transitionSpaceAfter: CGFloat = Fmt.transitionSpaceAfter

    // MARK: - Helper Methods

    #if canImport(AppKit)
    /// Get the font
    static func font() -> NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    /// Create paragraph style for element type
    static func paragraphStyle(for type: ScriptElementType) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0  // Single-spaced

        switch type {
        case .sceneHeading:
            style.alignment = .left
            style.firstLineHeadIndent = sceneHeadingLeftIndent
            style.headIndent = sceneHeadingLeftIndent
            style.tailIndent = sceneHeadingRightIndent == 0 ? 0 : -sceneHeadingRightIndent
            style.paragraphSpacingBefore = sceneHeadingSpaceBefore
            style.paragraphSpacing = sceneHeadingSpaceAfter

        case .action, .general:
            style.alignment = .left
            style.firstLineHeadIndent = actionLeftIndent
            style.headIndent = actionLeftIndent
            style.tailIndent = actionRightIndent == 0 ? 0 : -actionRightIndent
            style.paragraphSpacingBefore = actionSpaceBefore
            style.paragraphSpacing = actionSpaceAfter

        case .character:
            style.alignment = .left
            style.firstLineHeadIndent = characterLeftIndent
            style.headIndent = characterLeftIndent
            style.tailIndent = characterRightIndent == 0 ? 0 : -characterRightIndent
            style.paragraphSpacingBefore = characterSpaceBefore
            style.paragraphSpacing = characterSpaceAfter

        case .parenthetical:
            style.alignment = .left
            style.firstLineHeadIndent = parentheticalLeftIndent
            style.headIndent = parentheticalLeftIndent
            style.tailIndent = -parentheticalRightIndent
            style.paragraphSpacingBefore = parentheticalSpaceBefore
            style.paragraphSpacing = parentheticalSpaceAfter

        case .dialogue:
            style.alignment = .left
            style.firstLineHeadIndent = dialogueLeftIndent
            style.headIndent = dialogueLeftIndent
            style.tailIndent = -dialogueRightIndent
            style.paragraphSpacingBefore = dialogueSpaceBefore
            style.paragraphSpacing = dialogueSpaceAfter

        case .transition:
            style.alignment = .right
            style.firstLineHeadIndent = transitionLeftIndent
            style.headIndent = transitionLeftIndent
            style.tailIndent = transitionRightIndent == 0 ? 0 : -transitionRightIndent
            style.paragraphSpacingBefore = transitionSpaceBefore
            style.paragraphSpacing = transitionSpaceAfter

        case .shot:
            style.alignment = .left
            style.firstLineHeadIndent = sceneHeadingLeftIndent
            style.headIndent = sceneHeadingLeftIndent
            style.tailIndent = 0
            style.paragraphSpacingBefore = sceneHeadingSpaceBefore
            style.paragraphSpacing = sceneHeadingSpaceAfter

        case .titlePage:
            // Title page: centered text with single line spacing
            style.alignment = .center
            style.firstLineHeadIndent = 0
            style.headIndent = 0
            style.tailIndent = 0
            style.paragraphSpacingBefore = 12  // Single blank line between elements
            style.paragraphSpacing = 0
        }

        return style
    }

    /// Create typing attributes for element type
    static func typingAttributes(for type: ScriptElementType) -> [NSAttributedString.Key: Any] {
        [
            .font: font(),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle(for: type),
            .screenplayElementType: type.rawValue  // Store element type for extraction
        ]
    }
    #endif
}

// MARK: - Script Element Model

struct ScriptElement: Identifiable, Codable, Equatable {
    let id: UUID
    var type: ScriptElementType
    var text: String
    var sceneNumber: String?
    var isOmitted: Bool

    // Page length for scene headings (from FDX import)
    var pageEighths: Int?           // Scene length in eighths (8 = 1 page), nil means calculate

    // Revision tracking
    var revisionColor: String?      // e.g., "Blue", "Pink", "Yellow" - nil means unrevised/white
    var revisionID: Int?            // Revision sequence number
    var originalText: String?       // Text before this revision (for diff display)
    var isNewInRevision: Bool       // True if this element was added in the current revision
    var isDeletedInRevision: Bool   // True if this element is marked for deletion

    init(
        id: UUID = UUID(),
        type: ScriptElementType,
        text: String,
        sceneNumber: String? = nil,
        isOmitted: Bool = false,
        pageEighths: Int? = nil,
        revisionColor: String? = nil,
        revisionID: Int? = nil,
        originalText: String? = nil,
        isNewInRevision: Bool = false,
        isDeletedInRevision: Bool = false
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.sceneNumber = sceneNumber
        self.isOmitted = isOmitted
        self.pageEighths = pageEighths
        self.revisionColor = revisionColor
        self.revisionID = revisionID
        self.originalText = originalText
        self.isNewInRevision = isNewInRevision
        self.isDeletedInRevision = isDeletedInRevision
    }

    /// Returns true if this element has any revision marks
    var hasRevisionMark: Bool {
        revisionColor != nil && revisionColor?.lowercased() != "white"
    }

    /// Returns the SwiftUI Color for the revision
    var revisionSwiftUIColor: Color? {
        guard let colorName = revisionColor?.lowercased() else { return nil }
        switch colorName {
        case "white": return nil  // No highlight for white
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
        default: return nil
        }
    }

    /// Create a copy with revision mark applied
    func withRevision(color: String, id: Int, originalText: String? = nil) -> ScriptElement {
        var copy = self
        copy.revisionColor = color
        copy.revisionID = id
        copy.originalText = originalText ?? self.originalText
        return copy
    }

    /// Clear revision marks from this element
    func clearingRevision() -> ScriptElement {
        var copy = self
        copy.revisionColor = nil
        copy.revisionID = nil
        copy.originalText = nil
        copy.isNewInRevision = false
        copy.isDeletedInRevision = false
        return copy
    }

    /// Text formatted for display
    var displayText: String {
        // Omitted scenes show "OMITTED" text
        if isOmitted && type == .sceneHeading {
            return "OMITTED"
        }
        if type.isAllCaps {
            return text.uppercased()
        }
        if type == .parenthetical {
            var t = text.trimmingCharacters(in: .whitespaces)
            if !t.hasPrefix("(") { t = "(" + t }
            if !t.hasSuffix(")") { t = t + ")" }
            return t
        }
        return text
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if this is an inserted scene (has letters in scene number like 12A, 12AA)
    var isInsertedScene: Bool {
        guard let num = sceneNumber else { return false }
        return num.contains(where: { $0.isLetter })
    }
}

// MARK: - Revision Snapshot Model

/// Represents a saved revision state that can be restored or compared
struct RevisionSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let colorName: String           // "White", "Blue", "Pink", etc.
    let revisionNumber: Int         // Sequential revision number
    let savedAt: Date
    let pageCount: Int
    let sceneCount: Int
    let elementCount: Int
    let notes: String
    let elementsData: Data?         // Encoded [ScriptElement] for restoration

    var displayName: String {
        if colorName.lowercased() == "white" {
            return "Original Draft"
        }
        return "\(colorName) Revision"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: savedAt)
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

    /// Decode elements from stored data
    func decodeElements() -> [ScriptElement]? {
        guard let data = elementsData else { return nil }
        do {
            return try JSONDecoder().decode([ScriptElement].self, from: data)
        } catch {
            print("[RevisionSnapshot] ERROR: Failed to decode elements: \(error)")
            return nil
        }
    }
}

// MARK: - Screenplay Document Model

struct ScreenplayDocument: Codable, Equatable {
    var id: UUID
    var title: String
    var author: String
    var draftInfo: String
    var elements: [ScriptElement]
    var createdAt: Date
    var updatedAt: Date

    // Title page settings
    var showTitlePage: Bool             // Whether to display title page
    var contactName: String             // Contact name for title page
    var contactEmail: String            // Contact email for title page
    var contactPhone: String            // Contact phone for title page
    var contactAddress: String          // Contact address for title page
    var basedOn: String                 // "Based on..." credit
    var copyright: String               // Copyright notice

    // Revision tracking
    var currentRevisionColor: String?   // Active revision color (nil = White/none)
    var currentRevisionID: Int          // Current revision sequence number (0 = original)
    var isRevisionMode: Bool            // Whether revision tracking is active
    var revisionHistory: [RevisionSnapshot]  // History of saved revisions

    // Script locking (freezes scene numbers)
    var isLocked: Bool                  // Whether the script is locked
    var lockedAt: Date?                 // When the script was locked

    init(
        id: UUID = UUID(),
        title: String = "Untitled Screenplay",
        author: String = "",
        draftInfo: String = "",
        elements: [ScriptElement] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        showTitlePage: Bool = false,
        contactName: String = "",
        contactEmail: String = "",
        contactPhone: String = "",
        contactAddress: String = "",
        basedOn: String = "",
        copyright: String = "",
        currentRevisionColor: String? = nil,
        currentRevisionID: Int = 0,
        isRevisionMode: Bool = false,
        revisionHistory: [RevisionSnapshot] = [],
        isLocked: Bool = false,
        lockedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.draftInfo = draftInfo
        self.elements = elements
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.showTitlePage = showTitlePage
        self.contactName = contactName
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.contactAddress = contactAddress
        self.basedOn = basedOn
        self.copyright = copyright
        self.currentRevisionColor = currentRevisionColor
        self.currentRevisionID = currentRevisionID
        self.isRevisionMode = isRevisionMode
        self.revisionHistory = revisionHistory
        self.isLocked = isLocked
        self.lockedAt = lockedAt
    }

    // MARK: - Codable (backwards compatibility)

    private enum CodingKeys: String, CodingKey {
        case id, title, author, draftInfo, elements, createdAt, updatedAt
        case showTitlePage, contactName, contactEmail, contactPhone, contactAddress, basedOn, copyright
        case currentRevisionColor, currentRevisionID, isRevisionMode, revisionHistory
        case isLocked, lockedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        draftInfo = try container.decode(String.self, forKey: .draftInfo)
        elements = try container.decode([ScriptElement].self, forKey: .elements)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // Title page properties - default to hidden for existing documents
        showTitlePage = try container.decodeIfPresent(Bool.self, forKey: .showTitlePage) ?? false
        contactName = try container.decodeIfPresent(String.self, forKey: .contactName) ?? ""
        contactEmail = try container.decodeIfPresent(String.self, forKey: .contactEmail) ?? ""
        contactPhone = try container.decodeIfPresent(String.self, forKey: .contactPhone) ?? ""
        contactAddress = try container.decodeIfPresent(String.self, forKey: .contactAddress) ?? ""
        basedOn = try container.decodeIfPresent(String.self, forKey: .basedOn) ?? ""
        copyright = try container.decodeIfPresent(String.self, forKey: .copyright) ?? ""
        currentRevisionColor = try container.decodeIfPresent(String.self, forKey: .currentRevisionColor)
        currentRevisionID = try container.decodeIfPresent(Int.self, forKey: .currentRevisionID) ?? 0
        isRevisionMode = try container.decodeIfPresent(Bool.self, forKey: .isRevisionMode) ?? false
        revisionHistory = try container.decodeIfPresent([RevisionSnapshot].self, forKey: .revisionHistory) ?? []
        // New lock properties - default to unlocked for existing documents
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        lockedAt = try container.decodeIfPresent(Date.self, forKey: .lockedAt)
    }

    // MARK: - Revision Methods

    /// Start a new revision with the specified color
    mutating func startRevision(color: String) {
        currentRevisionColor = color
        currentRevisionID += 1
        isRevisionMode = true
    }

    /// Mark an element as revised (called when element is edited)
    mutating func markElementRevised(at index: Int, originalText: String? = nil) {
        guard isRevisionMode, let color = currentRevisionColor, index < elements.count else { return }
        elements[index].revisionColor = color
        elements[index].revisionID = currentRevisionID
        if let original = originalText {
            elements[index].originalText = original
        }
    }

    /// Mark a new element as added in this revision
    mutating func markElementAsNew(at index: Int) {
        guard isRevisionMode, let color = currentRevisionColor, index < elements.count else { return }
        elements[index].revisionColor = color
        elements[index].revisionID = currentRevisionID
        elements[index].isNewInRevision = true
    }

    /// Save current state as a revision snapshot
    mutating func saveRevisionSnapshot(notes: String = "") {
        let snapshot = RevisionSnapshot(
            id: UUID(),
            colorName: currentRevisionColor ?? "White",
            revisionNumber: currentRevisionID,
            savedAt: Date(),
            pageCount: estimatedPageCount,
            sceneCount: scenes.count,
            elementCount: elements.count,
            notes: notes,
            elementsData: {
                do {
                    return try JSONEncoder().encode(elements)
                } catch {
                    print("[ScreenplayDocument] ERROR: Failed to encode elements for revision snapshot: \(error)")
                    return nil
                }
            }()
        )
        revisionHistory.append(snapshot)
    }

    /// Clear all revision marks from elements
    mutating func clearAllRevisionMarks() {
        for i in elements.indices {
            elements[i] = elements[i].clearingRevision()
        }
    }

    /// Clear revision marks for a specific color only (merge that revision back to original)
    mutating func clearRevisionMarks(forColor color: String) {
        for i in elements.indices {
            if elements[i].revisionColor?.lowercased() == color.lowercased() {
                elements[i] = elements[i].clearingRevision()
            }
        }
    }

    /// Get count of revised elements for current revision
    var revisedElementCount: Int {
        elements.filter { $0.hasRevisionMark }.count
    }

    /// Get count of elements by revision color
    func elementCount(forRevisionColor color: String) -> Int {
        elements.filter { $0.revisionColor?.lowercased() == color.lowercased() }.count
    }

    static func newScreenplay(title: String = "Untitled Screenplay") -> ScreenplayDocument {
        ScreenplayDocument(
            title: title,
            elements: [
                ScriptElement(type: .action, text: "")
            ]
        )
    }

    var estimatedPageCount: Int {
        let totalLines = elements.reduce(0) { count, element in
            let textLines = max(1, (element.text.count / 60) + 1)
            return count + textLines + 1
        }
        return max(1, (totalLines / 55) + 1)
    }

    var scenes: [(number: String, heading: String, index: Int, pageEighths: Int)] {
        var sceneNum = 0
        var result: [(number: String, heading: String, index: Int, pageEighths: Int)] = []

        // Debug: Log element types for troubleshooting
        let elementTypeCounts = Dictionary(grouping: elements, by: { $0.type }).mapValues { $0.count }
        print("[ScreenplayDocument.scenes] Total elements: \(elements.count), Types: \(elementTypeCounts)")

        // Find all scene heading indices
        let sceneIndices = elements.enumerated().compactMap { index, element -> Int? in
            element.type == .sceneHeading ? index : nil
        }

        print("[ScreenplayDocument.scenes] Found \(sceneIndices.count) scene heading elements")

        for (i, sceneIndex) in sceneIndices.enumerated() {
            let element = elements[sceneIndex]
            sceneNum += 1

            // Use stored page eighths from FDX import if available
            let eighths: Int
            if let storedEighths = element.pageEighths, storedEighths > 0 {
                eighths = storedEighths
            } else {
                // Calculate page eighths based on line count for this scene
                let nextSceneIndex = (i + 1 < sceneIndices.count) ? sceneIndices[i + 1] : elements.count
                let sceneElements = elements[sceneIndex..<nextSceneIndex]

                // Count lines: 55 lines = 1 page = 8 eighths
                var totalLines = 0
                for el in sceneElements {
                    let textLength = el.text.count
                    let charsPerLine: Int
                    switch el.type {
                    case .dialogue: charsPerLine = 35
                    case .parenthetical: charsPerLine = 30
                    default: charsPerLine = 60
                    }
                    totalLines += max(1, (textLength / charsPerLine) + 1)
                }

                // Convert lines to eighths (55 lines = 8 eighths)
                eighths = max(1, Int(round(Double(totalLines) * 8.0 / 55.0)))
            }

            result.append((element.sceneNumber ?? "\(sceneNum)", element.text, sceneIndex, eighths))
        }

        print("[ScreenplayDocument.scenes] Returning \(result.count) scenes to inspector")
        return result
    }

    var characters: [String] {
        let names = elements
            .filter { $0.type == .character }
            .map { $0.text.uppercased().trimmingCharacters(in: .whitespaces) }
            .map { name -> String in
                if let idx = name.firstIndex(of: "(") {
                    return String(name[..<idx]).trimmingCharacters(in: .whitespaces)
                }
                return name
            }
        return Array(Set(names)).sorted()
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> ScreenplayDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScreenplayDocument.self, from: data)
    }

    // MARK: - Scene Insertion (Locked Script Mode)

    /// Insert a new scene AFTER the specified scene index
    /// Uses industry-standard numbering: 12 -> 12A, 12A -> 12B, etc.
    /// - Parameters:
    ///   - sceneIndex: Index in the scenes array (not elements array)
    ///   - heading: The scene heading text (e.g., "INT. NEW LOCATION - DAY")
    /// - Returns: The new scene number that was assigned
    mutating func insertSceneAfter(sceneIndex: Int, heading: String = "INT. NEW LOCATION - DAY") -> String? {
        let allScenes = scenes
        guard sceneIndex >= 0 && sceneIndex < allScenes.count else { return nil }

        let targetScene = allScenes[sceneIndex]
        let existingNumbers = SceneNumberUtils.allSceneNumbers(in: self)
        let newSceneNumber = SceneNumberUtils.nextNumberAfter(targetScene.number, existingNumbers: existingNumbers)

        // Find the element index to insert after
        // We need to insert after the last element belonging to this scene (before the next scene heading)
        let elementIndex = targetScene.index
        var insertIndex = elementIndex + 1

        // Find where the next scene starts (or end of document)
        while insertIndex < elements.count && elements[insertIndex].type != .sceneHeading {
            insertIndex += 1
        }

        // Create the new scene elements with revision tracking if in revision mode
        let newSceneHeading = ScriptElement(
            type: .sceneHeading,
            text: heading,
            sceneNumber: newSceneNumber,
            revisionColor: isRevisionMode ? currentRevisionColor : nil,
            revisionID: isRevisionMode ? currentRevisionID : nil,
            isNewInRevision: isRevisionMode
        )
        let newAction = ScriptElement(
            type: .action,
            text: "",
            revisionColor: isRevisionMode ? currentRevisionColor : nil,
            revisionID: isRevisionMode ? currentRevisionID : nil,
            isNewInRevision: isRevisionMode
        )

        elements.insert(contentsOf: [newSceneHeading, newAction], at: insertIndex)
        updatedAt = Date()

        return newSceneNumber
    }

    /// Insert a new scene BEFORE the specified scene index
    /// Uses industry-standard numbering: 12 -> A12, A12 -> B12, etc.
    /// - Parameters:
    ///   - sceneIndex: Index in the scenes array (not elements array)
    ///   - heading: The scene heading text (e.g., "INT. NEW LOCATION - DAY")
    /// - Returns: The new scene number that was assigned
    mutating func insertSceneBefore(sceneIndex: Int, heading: String = "INT. NEW LOCATION - DAY") -> String? {
        let allScenes = scenes
        guard sceneIndex >= 0 && sceneIndex < allScenes.count else { return nil }

        let targetScene = allScenes[sceneIndex]
        let existingNumbers = SceneNumberUtils.allSceneNumbers(in: self)
        let newSceneNumber = SceneNumberUtils.nextNumberBefore(targetScene.number, existingNumbers: existingNumbers)

        // Insert at the element index of the target scene
        let insertIndex = targetScene.index

        // Create the new scene elements with revision tracking if in revision mode
        let newSceneHeading = ScriptElement(
            type: .sceneHeading,
            text: heading,
            sceneNumber: newSceneNumber,
            revisionColor: isRevisionMode ? currentRevisionColor : nil,
            revisionID: isRevisionMode ? currentRevisionID : nil,
            isNewInRevision: isRevisionMode
        )
        let newAction = ScriptElement(
            type: .action,
            text: "",
            revisionColor: isRevisionMode ? currentRevisionColor : nil,
            revisionID: isRevisionMode ? currentRevisionID : nil,
            isNewInRevision: isRevisionMode
        )

        elements.insert(contentsOf: [newSceneHeading, newAction], at: insertIndex)
        updatedAt = Date()

        return newSceneNumber
    }

    /// Omit a scene (mark as OMITTED while preserving scene number)
    /// This is the industry-standard way to remove scenes from a locked script
    mutating func omitScene(at sceneIndex: Int) {
        let allScenes = scenes
        guard sceneIndex >= 0 && sceneIndex < allScenes.count else { return }

        let elementIndex = allScenes[sceneIndex].index

        // Store original text before omitting (for revision tracking)
        if isRevisionMode && elements[elementIndex].originalText == nil {
            elements[elementIndex].originalText = elements[elementIndex].text
        }

        elements[elementIndex].isOmitted = true
        elements[elementIndex].text = "OMITTED"

        // Mark with revision color if in revision mode
        if isRevisionMode, let color = currentRevisionColor {
            elements[elementIndex].revisionColor = color
            elements[elementIndex].revisionID = currentRevisionID
        }

        updatedAt = Date()
    }

    /// Restore an omitted scene
    mutating func restoreScene(at sceneIndex: Int, heading: String) {
        let allScenes = scenes
        guard sceneIndex >= 0 && sceneIndex < allScenes.count else { return }

        let elementIndex = allScenes[sceneIndex].index
        elements[elementIndex].isOmitted = false
        elements[elementIndex].text = heading

        // Mark with revision color if in revision mode (restoring a scene is a change)
        if isRevisionMode, let color = currentRevisionColor {
            elements[elementIndex].revisionColor = color
            elements[elementIndex].revisionID = currentRevisionID
        }

        updatedAt = Date()
    }
}

// MARK: - Scene Number Utilities

/// Utilities for generating inserted scene numbers
/// Industry standard:
/// - Scene inserted AFTER scene 12: 12A, 12B, 12C, etc.
/// - Scene inserted BEFORE scene 12: A12, B12, C12, etc.
enum SceneNumberUtils {

    /// Generate a scene number for inserting AFTER the specified scene
    /// - Parameters:
    ///   - sceneNumber: The scene to insert after (e.g., "12" or "12A")
    ///   - existingNumbers: Set of all existing scene numbers to avoid duplicates
    /// - Returns: The next available scene number (e.g., "12A", "12B", "12AA")
    static func nextNumberAfter(_ sceneNumber: String, existingNumbers: Set<String>) -> String {
        guard let parsed = SceneNumber(from: sceneNumber) else {
            return sceneNumber + "A"
        }

        var candidate = parsed.nextAfter()
        while existingNumbers.contains(candidate.description) {
            candidate = candidate.nextAfter()
        }
        return candidate.description
    }

    /// Generate a scene number for inserting BEFORE the specified scene
    /// - Parameters:
    ///   - sceneNumber: The scene to insert before (e.g., "12" or "A12")
    ///   - existingNumbers: Set of all existing scene numbers to avoid duplicates
    /// - Returns: The next available scene number (e.g., "A12", "B12", "AA12")
    static func nextNumberBefore(_ sceneNumber: String, existingNumbers: Set<String>) -> String {
        guard let parsed = SceneNumber(from: sceneNumber) else {
            return "A" + sceneNumber
        }

        var candidate = parsed.nextBefore()
        while existingNumbers.contains(candidate.description) {
            candidate = candidate.nextBefore()
        }
        return candidate.description
    }

    /// Legacy method for compatibility - generates number for inserting after
    static func nextInsertedNumber(after before: String, before after: String?, existingNumbers: Set<String>) -> String {
        return nextNumberAfter(before, existingNumbers: existingNumbers)
    }

    /// Parse a scene number into its numeric base and letter suffix/prefix
    /// - Parameter sceneNumber: e.g., "12A" or "12AA" or "12" or "A12"
    /// - Returns: Tuple of (baseNumber: Int, suffix: String) - note: prefix is ignored for legacy compatibility
    static func parseSceneNumber(_ sceneNumber: String) -> (Int, String) {
        if let parsed = SceneNumber(from: sceneNumber) {
            return (parsed.baseNumber, parsed.suffix)
        }
        return (0, "")
    }

    /// Get all scene numbers from a document
    static func allSceneNumbers(in document: ScreenplayDocument) -> Set<String> {
        Set(document.elements
            .filter { $0.type == .sceneHeading }
            .compactMap { $0.sceneNumber })
    }

    /// Sort scene numbers in proper order
    /// Order: A1, B1, 1, 1A, 1B, 1AA, A2, 2, 2A, etc.
    static func sortedSceneNumbers(_ numbers: [String]) -> [String] {
        numbers.compactMap { SceneNumber(from: $0) }
            .sorted()
            .map { $0.description }
    }
}
