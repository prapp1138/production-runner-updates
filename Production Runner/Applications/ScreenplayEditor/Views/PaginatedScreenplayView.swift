//
//  PaginatedScreenplayView.swift
//  Production Runner
//
//  A paginated screenplay editor with true page breaks.
//  Uses multiple NSTextContainers for real page-accurate editing.
//

import SwiftUI
#if canImport(AppKit)
import AppKit

// MARK: - Paginated Screenplay Layout Manager

/// Custom layout manager that handles screenplay-specific page break rules
/// Implements industry-standard screenplay pagination:
/// - Scene headings stay with at least one line of following action
/// - Character names stay with at least one line of dialogue
/// - Don't break in the middle of a parenthetical
/// - "(MORE)" and "(CONT'D)" for dialogue broken across pages
final class ScreenplayLayoutManager: NSLayoutManager {

    /// Callback when layout changes (pages may have changed)
    var onLayoutChanged: (() -> Void)?

    /// Reference to text storage for element type lookups
    weak var screenplayTextStorage: NSTextStorage?

    override func processEditing(for textStorage: NSTextStorage, edited editMask: NSTextStorageEditActions, range newCharRange: NSRange, changeInLength delta: Int, invalidatedRange invalidatedCharRange: NSRange) {
        super.processEditing(for: textStorage, edited: editMask, range: newCharRange, changeInLength: delta, invalidatedRange: invalidatedCharRange)

        // Notify that layout may have changed
        DispatchQueue.main.async { [weak self] in
            self?.onLayoutChanged?()
        }
    }

    /// Get element type at a character index
    private func elementType(at charIndex: Int) -> ScriptElementType? {
        guard let storage = screenplayTextStorage ?? textStorage,
              charIndex < storage.length else {
            return nil
        }

        let attrs = storage.attributes(at: charIndex, effectiveRange: nil)
        if let typeRawValue = attrs[.screenplayElementType] as? String,
           let type = ScriptElementType(rawValue: typeRawValue) {
            return type
        }
        return nil
    }

    /// Get the paragraph range containing a character index
    private func paragraphRange(at charIndex: Int) -> NSRange? {
        guard let storage = screenplayTextStorage ?? textStorage,
              charIndex < storage.length else {
            return nil
        }
        let string = storage.string as NSString
        return string.paragraphRange(for: NSRange(location: charIndex, length: 0))
    }


    /// Check if we should keep this line with the previous line (prevent orphans)
    func shouldKeepWithPrevious(at charIndex: Int) -> Bool {
        guard let storage = screenplayTextStorage ?? textStorage,
              charIndex > 0 else {
            return false
        }

        // Get current element type
        guard let currentType = elementType(at: charIndex) else {
            return false
        }

        // Get previous paragraph's element type
        let string = storage.string as NSString
        let currentParaRange = string.paragraphRange(for: NSRange(location: charIndex, length: 0))

        guard currentParaRange.location > 0 else { return false }

        let prevCharIndex = currentParaRange.location - 1
        guard let prevType = elementType(at: prevCharIndex) else {
            return false
        }

        // Rules for keeping elements together:

        // 1. Scene heading should have at least one line of action/description with it
        if prevType == .sceneHeading && (currentType == .action || currentType == .character) {
            return true
        }

        // 2. Character name should have at least one line of dialogue
        if prevType == .character && (currentType == .dialogue || currentType == .parenthetical) {
            return true
        }

        // 3. Parenthetical should stay with dialogue
        if prevType == .parenthetical && currentType == .dialogue {
            return true
        }

        // 4. Opening parenthetical should stay with character
        if prevType == .character && currentType == .parenthetical {
            return true
        }

        return false
    }

    /// Check if we should keep this line with the next line (prevent widows)
    func shouldKeepWithNext(at charIndex: Int) -> Bool {
        guard let storage = screenplayTextStorage ?? textStorage else {
            return false
        }

        // Get current element type
        guard let currentType = elementType(at: charIndex) else {
            return false
        }

        // Get current paragraph range
        let string = storage.string as NSString
        let currentParaRange = string.paragraphRange(for: NSRange(location: charIndex, length: 0))

        // Get next paragraph
        let nextParaStart = currentParaRange.location + currentParaRange.length
        guard nextParaStart < storage.length else { return false }

        guard let nextType = elementType(at: nextParaStart) else {
            return false
        }

        // Rules for keeping elements together:

        // 1. Scene heading should have following content
        if currentType == .sceneHeading {
            return true
        }

        // 2. Character should have dialogue
        if currentType == .character && (nextType == .dialogue || nextType == .parenthetical) {
            return true
        }

        // 3. Parenthetical should have dialogue after
        if currentType == .parenthetical && nextType == .dialogue {
            return true
        }

        return false
    }
}

// MARK: - Paginated Text Container

/// A text container for a single page with fixed height
/// Implements screenplay-specific page break rules to prevent orphaned scene headings
final class PageTextContainer: NSTextContainer {
    let pageIndex: Int

    /// Line height for Courier 12pt
    private let lineHeight: CGFloat = 12.0

    /// Minimum space required after a scene heading (heading + at least 1 line of content)
    /// Using 36pt to account for scene heading spacing (24pt before) plus one line (12pt)
    private let minSpaceAfterSceneHeading: CGFloat = 48.0

    /// Minimum space required after a character name (character + at least 1 line of dialogue)
    private let minSpaceAfterCharacter: CGFloat = 24.0

    init(size: NSSize, pageIndex: Int) {
        self.pageIndex = pageIndex
        super.init(size: size)
        self.widthTracksTextView = false
        self.heightTracksTextView = false
        self.lineFragmentPadding = 0
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override to enforce screenplay page break rules
    /// Returns .zero for the remaining rect to force content to next container when:
    /// - A scene heading would appear at the bottom without room for following content
    /// - A character name would appear without room for dialogue
    override func lineFragmentRect(forProposedRect proposedRect: NSRect, at characterIndex: Int, writingDirection baseWritingDirection: NSWritingDirection, remaining remainingRect: UnsafeMutablePointer<NSRect>?) -> NSRect {

        // Get the default line fragment rect first
        let rect = super.lineFragmentRect(forProposedRect: proposedRect, at: characterIndex, writingDirection: baseWritingDirection, remaining: remainingRect)

        // If default rect is empty, content doesn't fit
        guard !rect.isEmpty else {
            return rect
        }

        // Check if we need to apply screenplay page break rules
        guard let layoutManager = self.layoutManager,
              let textStorage = layoutManager.textStorage,
              characterIndex < textStorage.length else {
            return rect
        }

        // Get element type at this character position
        let attrs = textStorage.attributes(at: characterIndex, effectiveRange: nil)
        guard let typeRawValue = attrs[.screenplayElementType] as? String,
              let elementType = ScriptElementType(rawValue: typeRawValue) else {
            return rect
        }

        // Calculate space remaining on this page after this line
        let spaceRemaining = self.size.height - rect.maxY

        // Rule 1: Scene heading must have room for at least one line of following content
        if elementType == .sceneHeading {
            // If scene heading is near the bottom and there's not enough room for
            // the heading plus at least one line of content, force to next page
            if spaceRemaining < minSpaceAfterSceneHeading && rect.origin.y > lineHeight * 2 {
                // Return empty rect to force this content to the next container
                remainingRect?.pointee = .zero
                return .zero
            }
        }

        // Rule 2: Character name must have room for at least one line of dialogue
        if elementType == .character {
            if spaceRemaining < minSpaceAfterCharacter && rect.origin.y > lineHeight * 2 {
                remainingRect?.pointee = .zero
                return .zero
            }
        }

        // Rule 3: Parenthetical should stay with dialogue - don't orphan at page bottom
        if elementType == .parenthetical {
            // Parenthetical needs room for itself plus at least one line of dialogue
            if spaceRemaining < minSpaceAfterCharacter && rect.origin.y > lineHeight * 2 {
                remainingRect?.pointee = .zero
                return .zero
            }
        }

        return rect
    }
}

// MARK: - Paginated Screenplay Text View

/// Custom NSTextView for paginated screenplay editing with element type handling
final class PaginatedScreenplayTextView: NSTextView {

    /// Current element type at cursor
    var currentElementType: ScriptElementType = .sceneHeading

    /// Current revision color for new text (nil or "White" means no revision)
    var currentRevisionColor: String?

    /// Callbacks
    var onElementTypeChanged: ((ScriptElementType) -> Void)?
    var onContentChanged: (() -> Void)?

    /// Track typing state
    private var isTyping = false
    private var isProgrammaticChange = false

    /// Track if the last text change was an insertion (true) or deletion (false)
    /// Used to prevent revision marking on backspace/delete operations
    var lastChangeWasInsertion = false

    override func keyDown(with event: NSEvent) {
        // Cmd+number shortcuts for element types
        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers {
                for type in ScriptElementType.allCases {
                    if chars == type.shortcutKey {
                        setElementType(type)
                        return
                    }
                }
            }
        }

        // Tab key - cycle element types
        if event.keyCode == 48 {
            handleTab(shift: event.modifierFlags.contains(.shift))
            return
        }

        // Return key
        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.contains(.shift) {
                // Shift+Enter: soft return
                super.insertNewline(nil)
            } else {
                handleReturn()
            }
            return
        }

        // Backspace - check for element type change
        if event.keyCode == 51 {
            super.keyDown(with: event)
            checkElementTypeAfterBackspace()
            onContentChanged?()
            return
        }

        isTyping = true
        super.keyDown(with: event)
        isTyping = false
        onContentChanged?()
    }

    private func handleTab(shift: Bool) {
        let cycle = currentElementType.tabCycleElements
        guard !cycle.isEmpty else {
            super.insertTab(nil)
            return
        }

        if shift {
            if let idx = cycle.firstIndex(of: currentElementType) {
                let prev = idx == 0 ? cycle.count - 1 : idx - 1
                setElementType(cycle[prev])
            } else {
                setElementType(cycle.last ?? .action)
            }
        } else {
            if let idx = cycle.firstIndex(of: currentElementType) {
                let next = (idx + 1) % cycle.count
                setElementType(cycle[next])
            } else {
                setElementType(cycle.first ?? .action)
            }
        }
    }

    private func handleReturn() {
        guard let storage = textStorage else {
            super.insertNewline(nil)
            return
        }

        let cursor = selectedRange().location
        let text = storage.string as NSString

        // Get current paragraph
        let paraRange = text.paragraphRange(for: NSRange(location: cursor, length: 0))
        let paraText = text.substring(with: paraRange).trimmingCharacters(in: .newlines)

        // If empty line, cycle to next element type
        if paraText.trimmingCharacters(in: .whitespaces).isEmpty {
            let nextType = currentElementType.nextElementOnDoubleEnter
            setElementType(nextType)
            return
        }

        // Insert newline and transition to next element type
        let nextType = currentElementType.nextElementOnEnter

        isProgrammaticChange = true

        // Insert newline with proper spacing
        var attrs = ScreenplayFormat.typingAttributes(for: nextType)
        attrs[.screenplayElementType] = nextType.rawValue

        // Apply revision color if in revision mode
        if let revisionColor = currentRevisionColor,
           !revisionColor.isEmpty,
           revisionColor.lowercased() != "white" {
            attrs[.screenplayRevisionColor] = revisionColor
            if let textColor = revisionTextColor(for: revisionColor) {
                attrs[.foregroundColor] = textColor
            }
        }

        let newline = NSAttributedString(string: "\n", attributes: attrs)
        let insertLocation = selectedRange().location

        storage.insert(newline, at: insertLocation)
        setSelectedRange(NSRange(location: insertLocation + 1, length: 0))

        isProgrammaticChange = false

        // Update current element type
        currentElementType = nextType
        typingAttributes = attrs
        onElementTypeChanged?(nextType)
        onContentChanged?()
    }

    private func checkElementTypeAfterBackspace() {
        let cursorPos = selectedRange().location
        guard cursorPos > 0, let storage = textStorage else { return }

        // Get element type at cursor position
        let attrs = storage.attributes(at: cursorPos - 1, effectiveRange: nil)
        if let typeRaw = attrs[.screenplayElementType] as? String,
           let type = ScriptElementType(rawValue: typeRaw) {
            if type != currentElementType {
                currentElementType = type
                typingAttributes = ScreenplayFormat.typingAttributes(for: type)
                onElementTypeChanged?(type)
            }
        }
    }

    func setElementType(_ type: ScriptElementType) {
        currentElementType = type

        guard let storage = textStorage else { return }

        let selection = selectedRange()
        let text = storage.string as NSString
        let paraRange = text.paragraphRange(for: selection)

        var attrs = ScreenplayFormat.typingAttributes(for: type)
        attrs[.screenplayElementType] = type.rawValue

        // Apply revision color if in revision mode
        if let revisionColor = currentRevisionColor,
           !revisionColor.isEmpty,
           revisionColor.lowercased() != "white" {
            attrs[.screenplayRevisionColor] = revisionColor
            if let textColor = revisionTextColor(for: revisionColor) {
                attrs[.foregroundColor] = textColor
            }
        }

        isProgrammaticChange = true
        storage.addAttributes(attrs, range: paraRange)

        // Auto-capitalize
        if type.isAllCaps {
            let paraText = text.substring(with: paraRange)
            let upper = paraText.uppercased()
            if paraText != upper {
                storage.replaceCharacters(in: paraRange, with: upper)
            }
        }

        isProgrammaticChange = false

        typingAttributes = attrs
        onElementTypeChanged?(type)
        onContentChanged?()
    }

    // MARK: - Copy Handling

    /// Override copy to include screenplay formatting data
    override func copy(_ sender: Any?) {
        guard let storage = textStorage else {
            super.copy(sender)
            return
        }

        let selection = selectedRange()
        guard selection.length > 0 else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Get the selected attributed string
        let selectedAttrString = storage.attributedSubstring(from: selection)

        // Build screenplay data to preserve formatting
        var screenplayData: [[String: Any]] = []
        selectedAttrString.enumerateAttributes(in: NSRange(location: 0, length: selectedAttrString.length), options: []) { attrs, range, _ in
            var elementData: [String: Any] = [:]
            let text = (selectedAttrString.string as NSString).substring(with: range)
            elementData["text"] = text

            if let elementType = attrs[.screenplayElementType] as? String {
                elementData["elementType"] = elementType
            }
            if let revisionColor = attrs[.screenplayRevisionColor] as? String {
                elementData["revisionColor"] = revisionColor
            }
            if let revisionID = attrs[.screenplayRevisionID] as? Int {
                elementData["revisionID"] = revisionID
            }
            if let sceneNumber = attrs[.screenplaySceneNumber] as? String {
                elementData["sceneNumber"] = sceneNumber
            }
            if let isOmitted = attrs[.screenplayIsOmitted] as? Bool {
                elementData["isOmitted"] = isOmitted
            }
            if let isNewInRevision = attrs[.screenplayIsNewInRevision] as? Bool {
                elementData["isNewInRevision"] = isNewInRevision
            }
            if let originalText = attrs[.screenplayOriginalText] as? String {
                elementData["originalText"] = originalText
            }

            screenplayData.append(elementData)
        }

        // Write screenplay data as JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: screenplayData, options: []) {
            pasteboard.setData(jsonData, forType: ScreenplayTextView.screenplayPasteboardType)
        }

        // Also write plain text for external apps
        pasteboard.setString(selectedAttrString.string, forType: .string)

        print("[PaginatedScreenplayTextView] Copied \(selection.length) characters with screenplay formatting")
    }

    /// Override cut to use our copy implementation
    override func cut(_ sender: Any?) {
        copy(sender)
        deleteBackward(sender)
    }

    // MARK: - Paste Handling

    /// Override paste to preserve screenplay formatting when available
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // First, try to read screenplay-formatted data
        if let screenplayData = pasteboard.data(forType: ScreenplayTextView.screenplayPasteboardType),
           let jsonArray = try? JSONSerialization.jsonObject(with: screenplayData) as? [[String: Any]] {

            pasteScreenplayData(jsonArray)
            return
        }

        // Fall back to plain text with current element formatting
        if let plainText = pasteboard.string(forType: .string), !plainText.isEmpty {
            var attrs = ScreenplayFormat.typingAttributes(for: currentElementType)
            attrs[.screenplayElementType] = currentElementType.rawValue

            // Apply revision color if in revision mode
            if let revisionColor = currentRevisionColor,
               !revisionColor.isEmpty,
               revisionColor.lowercased() != "white" {
                attrs[.screenplayRevisionColor] = revisionColor
                if let textColor = revisionTextColor(for: revisionColor) {
                    attrs[.foregroundColor] = textColor
                }
            }

            let attrString = NSAttributedString(string: plainText, attributes: attrs)

            isProgrammaticChange = true

            let insertLocation = selectedRange().location
            if selectedRange().length > 0 {
                textStorage?.replaceCharacters(in: selectedRange(), with: attrString)
            } else {
                textStorage?.insert(attrString, at: insertLocation)
            }

            setSelectedRange(NSRange(location: insertLocation + plainText.count, length: 0))
            isProgrammaticChange = false
            onContentChanged?()
        } else {
            super.paste(sender)
        }
    }

    /// Get text color for revision color name (for paste operations)
    private func pasteRevisionTextColor(for colorName: String) -> NSColor? {
        switch colorName.lowercased() {
        case "white": return nil
        case "blue": return NSColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        case "pink": return NSColor(red: 0.85, green: 0.2, blue: 0.5, alpha: 1.0)
        case "yellow": return NSColor(red: 0.7, green: 0.55, blue: 0.0, alpha: 1.0)
        case "green": return NSColor(red: 0.0, green: 0.6, blue: 0.3, alpha: 1.0)
        case "goldenrod": return NSColor(red: 0.72, green: 0.53, blue: 0.04, alpha: 1.0)
        case "buff": return NSColor(red: 0.6, green: 0.45, blue: 0.2, alpha: 1.0)
        case "salmon": return NSColor(red: 0.9, green: 0.35, blue: 0.25, alpha: 1.0)
        case "cherry": return NSColor(red: 0.75, green: 0.15, blue: 0.4, alpha: 1.0)
        case "tan": return NSColor(red: 0.55, green: 0.4, blue: 0.25, alpha: 1.0)
        case "gray", "grey": return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        default: return nil
        }
    }

    /// Paste screenplay-formatted data preserving all attributes
    /// In revision mode, applies current revision color if it's higher priority
    private func pasteScreenplayData(_ data: [[String: Any]]) {
        let result = NSMutableAttributedString()

        for elementData in data {
            guard let text = elementData["text"] as? String else { continue }

            // Determine element type
            let elementTypeString = elementData["elementType"] as? String ?? currentElementType.rawValue
            let elementType = ScriptElementType(rawValue: elementTypeString) ?? currentElementType

            // Build attributes
            var attrs = ScreenplayFormat.typingAttributes(for: elementType)
            attrs[.screenplayElementType] = elementType.rawValue

            // Handle revision color - apply current revision color if in revision mode
            // This is industry standard: pasted text in revision mode gets current revision color
            if let currentRevColor = currentRevisionColor,
               !currentRevColor.isEmpty,
               currentRevColor.lowercased() != "white" {
                // Apply current revision color (we're in revision mode)
                attrs[.screenplayRevisionColor] = currentRevColor
                if let textColor = revisionTextColor(for: currentRevColor) {
                    attrs[.foregroundColor] = textColor
                }
            } else if let revisionColor = elementData["revisionColor"] as? String {
                // Not in revision mode, preserve original revision color from pasted data
                attrs[.screenplayRevisionColor] = revisionColor
                if let textColor = pasteRevisionTextColor(for: revisionColor) {
                    attrs[.foregroundColor] = textColor
                }
            }

            if let revisionID = elementData["revisionID"] as? Int {
                attrs[.screenplayRevisionID] = revisionID
            }
            if let sceneNumber = elementData["sceneNumber"] as? String {
                attrs[.screenplaySceneNumber] = sceneNumber
            }
            if let isOmitted = elementData["isOmitted"] as? Bool, isOmitted {
                attrs[.screenplayIsOmitted] = true
            }
            if let isNewInRevision = elementData["isNewInRevision"] as? Bool, isNewInRevision {
                attrs[.screenplayIsNewInRevision] = true
            }
            if let originalText = elementData["originalText"] as? String {
                attrs[.screenplayOriginalText] = originalText
            }

            result.append(NSAttributedString(string: text, attributes: attrs))
        }

        guard result.length > 0 else { return }

        let insertLocation = selectedRange().location
        let insertLength = selectedRange().length

        isProgrammaticChange = true

        if insertLength > 0 {
            textStorage?.replaceCharacters(in: selectedRange(), with: result)
        } else {
            textStorage?.insert(result, at: insertLocation)
        }

        let newCursorPos = insertLocation + result.length
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        isProgrammaticChange = false
        onContentChanged?()

        print("[PaginatedScreenplayTextView] Pasted screenplay data with \(data.count) formatted segments")
    }

    override func pasteAsPlainText(_ sender: Any?) {
        // For paste as plain text, ignore screenplay data and use plain text only
        let pasteboard = NSPasteboard.general
        if let plainText = pasteboard.string(forType: .string), !plainText.isEmpty {
            var attrs = ScreenplayFormat.typingAttributes(for: currentElementType)
            attrs[.screenplayElementType] = currentElementType.rawValue

            // Apply revision color if in revision mode
            if let revisionColor = currentRevisionColor,
               !revisionColor.isEmpty,
               revisionColor.lowercased() != "white" {
                attrs[.screenplayRevisionColor] = revisionColor
                if let textColor = revisionTextColor(for: revisionColor) {
                    attrs[.foregroundColor] = textColor
                }
            }

            let attrString = NSAttributedString(string: plainText, attributes: attrs)

            let insertLocation = selectedRange().location
            isProgrammaticChange = true

            if selectedRange().length > 0 {
                textStorage?.replaceCharacters(in: selectedRange(), with: attrString)
            } else {
                textStorage?.insert(attrString, at: insertLocation)
            }

            setSelectedRange(NSRange(location: insertLocation + plainText.count, length: 0))
            isProgrammaticChange = false
            onContentChanged?()
        }
    }

    // MARK: - Auto-Capitalization

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // Mark that this change is an insertion (not a deletion)
        lastChangeWasInsertion = true

        // Convert input to string
        var textToInsert: String
        if let str = string as? String {
            textToInsert = str
        } else if let attrStr = string as? NSAttributedString {
            textToInsert = attrStr.string
        } else {
            textToInsert = String(describing: string)
        }

        // Auto-capitalize for all-caps element types (scene heading, character, transition, shot)
        if currentElementType.isAllCaps {
            textToInsert = textToInsert.uppercased()
        }

        // Insert with proper attributes
        var attrs = ScreenplayFormat.typingAttributes(for: currentElementType)
        attrs[.screenplayElementType] = currentElementType.rawValue

        // Apply revision color if in revision mode
        if let revisionColor = currentRevisionColor,
           !revisionColor.isEmpty,
           revisionColor.lowercased() != "white" {
            attrs[.screenplayRevisionColor] = revisionColor
            if let textColor = revisionTextColor(for: revisionColor) {
                attrs[.foregroundColor] = textColor
            }
            print("[REVISION DEBUG] insertText: inserting '\(textToInsert.prefix(30))' with revisionColor=\(revisionColor), replacementRange=\(replacementRange)")
        }

        let attrString = NSAttributedString(string: textToInsert, attributes: attrs)

        print("[REVISION DEBUG] insertText: BEFORE super.insertText - textStorage.length=\(textStorage?.length ?? -1)")
        super.insertText(attrString, replacementRange: replacementRange)
        print("[REVISION DEBUG] insertText: AFTER super.insertText - textStorage.length=\(textStorage?.length ?? -1)")
    }

    override func deleteBackward(_ sender: Any?) {
        // Mark that this change is a deletion (not an insertion)
        lastChangeWasInsertion = false
        super.deleteBackward(sender)
    }

    override func deleteForward(_ sender: Any?) {
        // Mark that this change is a deletion (not an insertion)
        lastChangeWasInsertion = false
        super.deleteForward(sender)
    }

    /// Get revision text color for a given color name
    private func revisionTextColor(for colorName: String) -> NSColor? {
        let lower = colorName.lowercased()
        if lower == "white" || lower.isEmpty {
            return nil
        }
        return ScriptRevisionColors.platformColor(for: colorName)
    }
}

// MARK: - Page View (Single Page)

/// NSView representing a single page with its text container
final class ScreenplayPageView: NSView {
    let textView: PaginatedScreenplayTextView
    let pageIndex: Int
    private let pageWidth: CGFloat
    private let pageHeight: CGFloat
    private let marginTop: CGFloat
    private let marginBottom: CGFloat
    private let marginLeft: CGFloat
    private let marginRight: CGFloat
    private weak var layoutManager: NSLayoutManager?
    private weak var textContainer: PageTextContainer?

    /// Scene number position setting
    var sceneNumberPosition: SceneNumberPosition = .none {
        didSet { needsDisplay = true }
    }

    /// Current revision color for this page (used for header display)
    var currentRevisionColor: String? = nil {
        didSet { needsDisplay = true }
    }

    /// Editor appearance mode - "System", "Light", or "Dark"
    var editorAppearanceMode: String = "System" {
        didSet {
            updateAppearanceColors()
            needsDisplay = true
        }
    }

    /// Check if the effective appearance is dark mode
    private var isEffectivelyDarkMode: Bool {
        switch editorAppearanceMode {
        case "Dark":
            return true
        case "Light":
            return false
        default:
            // System mode - check the view's effective appearance (not NSApp's)
            return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    /// Current page background color based on appearance mode
    private var pageBackgroundColor: NSColor {
        if isEffectivelyDarkMode {
            return NSColor(calibratedWhite: 0.15, alpha: 1.0)  // Dark gray for dark mode
        } else {
            return NSColor.white
        }
    }

    /// Current text color based on appearance mode
    private var pageTextColor: NSColor {
        if isEffectivelyDarkMode {
            return NSColor(calibratedWhite: 0.9, alpha: 1.0)  // Light gray for dark mode
        } else {
            return NSColor.black
        }
    }

    /// Update colors when appearance mode changes
    private func updateAppearanceColors() {
        layer?.backgroundColor = pageBackgroundColor.cgColor
        textView.textColor = pageTextColor
        textView.insertionPointColor = pageTextColor
    }

    init(textContainer: PageTextContainer, sharedTextStorage: NSTextStorage, layoutManager: NSLayoutManager) {
        self.pageIndex = textContainer.pageIndex
        self.pageWidth = ScreenplayFormat.pageWidth
        self.pageHeight = ScreenplayFormat.pageHeight
        self.marginTop = ScreenplayFormat.marginTop
        self.marginBottom = ScreenplayFormat.marginBottom
        self.marginLeft = ScreenplayFormat.marginLeft
        self.marginRight = ScreenplayFormat.marginRight
        self.layoutManager = layoutManager
        self.textContainer = textContainer

        // Create text view for this page's container
        let contentFrame = NSRect(
            x: marginLeft,
            y: marginTop,
            width: ScreenplayFormat.contentWidth,
            height: ScreenplayFormat.contentHeight
        )

        // IMPORTANT: Create NSTextView with the text container that's already connected
        // to the shared layout manager and text storage. This ensures all pages share
        // the same text storage through the layout manager's text container chain.
        textView = PaginatedScreenplayTextView(frame: contentFrame, textContainer: textContainer)

        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.font = ScreenplayFormat.font()
        // Colors set after super.init via updateAppearanceColors()
        textView.textContainerInset = .zero  // Remove default padding
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        super.init(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        self.wantsLayer = true
        // Set initial colors using appearance-aware computed properties
        updateAppearanceColors()
        self.layer?.cornerRadius = 2
        self.layer?.shadowColor = NSColor.shadowColor.cgColor
        self.layer?.shadowOpacity = 0.2
        self.layer?.shadowRadius = 8
        self.layer?.shadowOffset = CGSize(width: 0, height: -4)

        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearanceColors()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Update appearance colors when view is added to a window
        // This ensures correct appearance detection after init
        if window != nil {
            updateAppearanceColors()
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw page background with dynamic color
        pageBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2).fill()

        let courierFont = NSFont(name: "Courier", size: 12) ?? NSFont.systemFont(ofSize: 12)

        // Draw scene numbers if enabled
        if sceneNumberPosition.isEnabled {
            drawSceneNumbers(font: courierFont)
        }

        // Draw revision asterisks in right margin for revised lines
        drawRevisionMarks(font: courierFont)

        // Draw revision header if page has revisions (e.g., "BLUE REVISIONS - 12/10/24")
        drawRevisionHeader(font: courierFont)

        // Draw page number in top right (Final Draft style)
        // Page 1 typically doesn't show a number, starts from page 2
        if pageIndex > 0 {
            let pageNumberString = "\(pageIndex + 1)."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: courierFont,
                .foregroundColor: pageTextColor
            ]
            let attrString = NSAttributedString(string: pageNumberString, attributes: attrs)
            let stringSize = attrString.size()
            // Position in top right margin area, aligned with right margin
            let pageNumberRect = NSRect(
                x: bounds.width - marginRight - stringSize.width,
                y: marginTop / 2 - stringSize.height / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            attrString.draw(in: pageNumberRect)
        }

        super.draw(dirtyRect)
    }

    private func drawSceneNumbers(font: NSFont) {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: pageTextColor
        ]

        // Find scene headings in this page's text container
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }

        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        guard let storage = layoutManager.textStorage else { return }
        let string = storage.string as NSString

        var sceneIndex = 1
        // Count scenes before this page
        if charRange.location > 0 {
            var loc = 0
            while loc < charRange.location {
                let paraRange = string.paragraphRange(for: NSRange(location: loc, length: 0))
                if paraRange.location < storage.length {
                    let paraAttrs = storage.attributes(at: paraRange.location, effectiveRange: nil)
                    if let typeRaw = paraAttrs[.screenplayElementType] as? String,
                       typeRaw == ScriptElementType.sceneHeading.rawValue {
                        sceneIndex += 1
                    }
                }
                loc = paraRange.location + paraRange.length
            }
        }

        // Draw scene numbers for this page
        var loc = charRange.location
        while loc < charRange.location + charRange.length && loc < storage.length {
            let paraRange = string.paragraphRange(for: NSRange(location: loc, length: 0))

            let paraAttrs = storage.attributes(at: paraRange.location, effectiveRange: nil)
            if let typeRaw = paraAttrs[.screenplayElementType] as? String,
               typeRaw == ScriptElementType.sceneHeading.rawValue {

                // Get Y position of this paragraph
                let paraGlyphRange = layoutManager.glyphRange(forCharacterRange: paraRange, actualCharacterRange: nil)
                let boundingRect = layoutManager.boundingRect(forGlyphRange: paraGlyphRange, in: textContainer)

                let sceneNumberStr = "\(sceneIndex)"
                let attrString = NSAttributedString(string: sceneNumberStr, attributes: attrs)
                let stringSize = attrString.size()

                let y = marginTop + boundingRect.origin.y + (boundingRect.height - stringSize.height) / 2

                // Draw on left margin if enabled
                // Left scene number: 0.75 inches from left edge = 54 points
                if sceneNumberPosition.showLeft {
                    let leftX: CGFloat = 54.0 - stringSize.width / 2
                    attrString.draw(at: NSPoint(x: leftX, y: y))
                }

                // Draw on right margin if enabled
                // Right scene number: 7.38 inches from left edge = 531.36 points
                if sceneNumberPosition.showRight {
                    let rightX: CGFloat = 531.36 - stringSize.width / 2
                    attrString.draw(at: NSPoint(x: rightX, y: y))
                }

                sceneIndex += 1
            }

            loc = paraRange.location + paraRange.length
        }
    }

    /// Draw revision asterisks (*) in the right margin for lines that have been revised
    /// Industry standard: asterisk appears in right margin next to any line that was changed
    private func drawRevisionMarks(font: NSFont) {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        // Find paragraphs with revision marks in this page's text container
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }

        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard let storage = layoutManager.textStorage else { return }
        let string = storage.string as NSString

        // Iterate through paragraphs on this page
        var loc = charRange.location
        while loc < charRange.location + charRange.length && loc < storage.length {
            let paraRange = string.paragraphRange(for: NSRange(location: loc, length: 0))

            // Check if this paragraph has a revision color (other than white)
            let paraAttrs = storage.attributes(at: paraRange.location, effectiveRange: nil)
            if let revisionColor = paraAttrs[.screenplayRevisionColor] as? String,
               !revisionColor.isEmpty,
               revisionColor.lowercased() != "white" {

                // Get Y position of this paragraph
                let paraGlyphRange = layoutManager.glyphRange(forCharacterRange: paraRange, actualCharacterRange: nil)
                let boundingRect = layoutManager.boundingRect(forGlyphRange: paraGlyphRange, in: textContainer)

                // Draw asterisk in right margin
                let asteriskColor = ScriptRevisionColors.platformColor(for: revisionColor)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: asteriskColor
                ]
                let asteriskString = NSAttributedString(string: "*", attributes: attrs)
                let stringSize = asteriskString.size()

                // Position asterisk in the right margin area
                // Right margin starts at: pageWidth - marginRight = 612 - 72 = 540 points
                // Place asterisk about 0.5 inches from right edge = ~36 points from right
                let asteriskX: CGFloat = bounds.width - 36 - stringSize.width / 2
                let y = marginTop + boundingRect.origin.y + (boundingRect.height - stringSize.height) / 2

                asteriskString.draw(at: NSPoint(x: asteriskX, y: y))
            }

            loc = paraRange.location + paraRange.length
        }
    }

    /// Draw revision header at top of page if page contains revisions
    /// Example: "BLUE REVISIONS - 12/10/24"
    private func drawRevisionHeader(font: NSFont) {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        // Check if this page has any revisions
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }

        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard let storage = layoutManager.textStorage else { return }
        let string = storage.string as NSString

        // Find the highest priority (most recent) revision color on this page
        var pageRevisionColor: String? = nil
        var loc = charRange.location

        while loc < charRange.location + charRange.length && loc < storage.length {
            let paraRange = string.paragraphRange(for: NSRange(location: loc, length: 0))
            let paraAttrs = storage.attributes(at: paraRange.location, effectiveRange: nil)

            if let revisionColor = paraAttrs[.screenplayRevisionColor] as? String,
               !revisionColor.isEmpty,
               revisionColor.lowercased() != "white" {
                // Keep the revision color (could track highest priority here if needed)
                pageRevisionColor = revisionColor
                break  // Found a revision, use this color for the header
            }

            loc = paraRange.location + paraRange.length
        }

        // Draw header if page has revisions
        guard let revColor = pageRevisionColor else { return }

        // Format: "BLUE REVISIONS - 12/10/24"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"
        let dateString = dateFormatter.string(from: Date())

        let headerText = "\(revColor.uppercased()) REVISIONS - \(dateString)"
        let headerColor = ScriptRevisionColors.platformColor(for: revColor)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: headerColor
        ]
        let headerString = NSAttributedString(string: headerText, attributes: attrs)
        let stringSize = headerString.size()

        // Position header centered in the top margin area
        let headerX = (bounds.width - stringSize.width) / 2
        let headerY = marginTop / 2 - stringSize.height / 2

        headerString.draw(at: NSPoint(x: headerX, y: headerY))
    }
}

// MARK: - Screenplay Title Page View

/// A dedicated view for rendering a professional screenplay title page
final class ScreenplayTitlePageView: NSView {
    var document: ScreenplayDocument? {
        didSet { needsDisplay = true }
    }

    var editorAppearanceMode: String = "System" {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    private var isEffectivelyDarkMode: Bool {
        switch editorAppearanceMode {
        case "Dark": return true
        case "Light": return false
        default: return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw white paper background
        NSColor.white.setFill()
        bounds.fill()

        // Draw subtle border/shadow
        NSColor(calibratedWhite: 0.85, alpha: 1.0).setStroke()
        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 1
        borderPath.stroke()

        guard let doc = document else { return }

        // Use Courier for professional screenplay look
        let titleFont = NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let textColor = NSColor.black

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let leftAlignStyle = NSMutableParagraphStyle()
        leftAlignStyle.alignment = .left

        // Margins - industry standard
        let leftMargin: CGFloat = 72  // 1 inch
        let rightMargin: CGFloat = 72
        let contentWidth = bounds.width - leftMargin - rightMargin

        // Title - approximately 1/3 down the page (around line 25-30 of 55 lines)
        let titleY: CGFloat = bounds.height * 0.35
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let title = doc.title.uppercased()
        let titleRect = NSRect(x: leftMargin, y: titleY, width: contentWidth, height: 20)
        (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)

        // "written by" - 4 lines below title
        let writtenByY = titleY + 48
        let writtenByAttrs = titleAttrs
        ("written by" as NSString).draw(in: NSRect(x: leftMargin, y: writtenByY, width: contentWidth, height: 20), withAttributes: writtenByAttrs)

        // Author name - 2 lines below "written by"
        let authorY = writtenByY + 32
        let authorName = doc.author.isEmpty ? "" : doc.author
        (authorName as NSString).draw(in: NSRect(x: leftMargin, y: authorY, width: contentWidth, height: 20), withAttributes: titleAttrs)

        // "Based on" credit if present - 2 lines below author
        var nextY = authorY + 32
        if !doc.basedOn.isEmpty {
            nextY += 16
            (doc.basedOn as NSString).draw(in: NSRect(x: leftMargin, y: nextY, width: contentWidth, height: 20), withAttributes: titleAttrs)
            nextY += 32
        }

        // Revision info if in revision mode - centered below credits
        if let revColor = doc.currentRevisionColor, revColor.lowercased() != "white" {
            nextY += 32
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM d, yyyy"
            let revisionText = "\(revColor) Revisions - \(dateFormatter.string(from: doc.updatedAt))"
            (revisionText as NSString).draw(in: NSRect(x: leftMargin, y: nextY, width: contentWidth, height: 20), withAttributes: titleAttrs)
        }

        // Contact info - bottom left corner
        let contactAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor,
            .paragraphStyle: leftAlignStyle
        ]

        var contactY = bounds.height - 144  // About 2 inches from bottom
        let hasContact = !doc.contactName.isEmpty || !doc.contactEmail.isEmpty || !doc.contactPhone.isEmpty || !doc.contactAddress.isEmpty

        if hasContact {
            if !doc.contactName.isEmpty {
                (doc.contactName as NSString).draw(at: NSPoint(x: leftMargin, y: contactY), withAttributes: contactAttrs)
                contactY += 16
            }
            if !doc.contactAddress.isEmpty {
                // Split address by newlines if present
                let addressLines = doc.contactAddress.components(separatedBy: "\n")
                for line in addressLines {
                    (line as NSString).draw(at: NSPoint(x: leftMargin, y: contactY), withAttributes: contactAttrs)
                    contactY += 16
                }
            }
            if !doc.contactPhone.isEmpty {
                (doc.contactPhone as NSString).draw(at: NSPoint(x: leftMargin, y: contactY), withAttributes: contactAttrs)
                contactY += 16
            }
            if !doc.contactEmail.isEmpty {
                (doc.contactEmail as NSString).draw(at: NSPoint(x: leftMargin, y: contactY), withAttributes: contactAttrs)
            }
        }

        // Draft date - bottom right or center bottom if no contact
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let draftDate = doc.draftInfo.isEmpty ? dateFormatter.string(from: doc.createdAt) : doc.draftInfo

        let rightAlignStyle = NSMutableParagraphStyle()
        rightAlignStyle.alignment = .right

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor,
            .paragraphStyle: hasContact ? rightAlignStyle : paragraphStyle
        ]

        let dateY = bounds.height - 144
        let dateRect = NSRect(x: leftMargin, y: dateY, width: contentWidth, height: 20)
        (draftDate as NSString).draw(in: dateRect, withAttributes: dateAttrs)

        // Copyright - bottom center
        if !doc.copyright.isEmpty {
            let copyrightY = bounds.height - 72
            (doc.copyright as NSString).draw(in: NSRect(x: leftMargin, y: copyrightY, width: contentWidth, height: 20), withAttributes: titleAttrs)
        }
    }
}

// MARK: - Paginated Document View

/// Container view holding all pages
final class PaginatedDocumentView: NSView {
    private var pageViews: [ScreenplayPageView] = []
    private var titlePageView: ScreenplayTitlePageView?
    private let textStorage: NSTextStorage
    private let layoutManager: ScreenplayLayoutManager
    private var textContainers: [PageTextContainer] = []

    private let pageSpacing: CGFloat = 20
    private let horizontalPadding: CGFloat = 40

    /// Whether to show the title page
    var showTitlePage: Bool = false {
        didSet {
            if showTitlePage != oldValue {
                updateTitlePageVisibility()
                repositionAllPages()
            }
        }
    }

    /// The document for title page rendering
    var titlePageDocument: ScreenplayDocument? {
        didSet {
            titlePageView?.document = titlePageDocument
            showTitlePage = titlePageDocument?.showTitlePage ?? false
        }
    }

    /// Callbacks
    var onContentChanged: (() -> Void)?
    var onElementTypeChanged: ((ScriptElementType) -> Void)?
    var onCurrentElementIndexChanged: ((Int) -> Void)?

    /// Current element type
    private(set) var currentElementType: ScriptElementType = .sceneHeading

    /// Current element index (for tracking cursor position)
    private(set) var currentElementIndex: Int = 0

    override var isFlipped: Bool { true }

    /// Scene number position setting
    var sceneNumberPosition: SceneNumberPosition = .none {
        didSet {
            pageViews.forEach {
                $0.sceneNumberPosition = sceneNumberPosition
                $0.needsDisplay = true
            }
        }
    }

    /// Current revision color for marking edited elements
    /// nil or "White" means no revision tracking
    /// Note: All state modifications must occur on the main thread (enforced by NSView)
    var currentRevisionColor: String? = nil {
        didSet {
            print("[REVISION DEBUG] PaginatedDocumentView.currentRevisionColor SET: oldValue=\(oldValue ?? "nil"), newValue=\(currentRevisionColor ?? "nil")")
            // Propagate revision color to all page views and their text views
            pageViews.forEach {
                $0.textView.currentRevisionColor = currentRevisionColor
                $0.currentRevisionColor = currentRevisionColor
                $0.needsDisplay = true  // Trigger redraw for asterisks/headers
            }
        }
    }

    /// Editor appearance mode - "System", "Light", or "Dark"
    var editorAppearanceMode: String = "System" {
        didSet {
            pageViews.forEach {
                $0.editorAppearanceMode = editorAppearanceMode
            }
            titlePageView?.editorAppearanceMode = editorAppearanceMode
        }
    }

    init() {
        // Create shared text storage
        textStorage = NSTextStorage()

        // Create custom layout manager
        layoutManager = ScreenplayLayoutManager()
        layoutManager.screenplayTextStorage = textStorage
        textStorage.addLayoutManager(layoutManager)

        super.init(frame: .zero)

        self.wantsLayer = true

        // Setup layout change callback
        layoutManager.onLayoutChanged = { [weak self] in
            self?.updatePageCount()
        }

        // Add initial page
        addPage()

        // Observe text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Page Management

    private func addPage() {
        let pageIndex = textContainers.count

        // Create text container for this page
        let container = PageTextContainer(
            size: NSSize(width: ScreenplayFormat.contentWidth, height: ScreenplayFormat.contentHeight),
            pageIndex: pageIndex
        )
        textContainers.append(container)
        layoutManager.addTextContainer(container)

        // Create page view
        let pageView = ScreenplayPageView(
            textContainer: container,
            sharedTextStorage: textStorage,
            layoutManager: layoutManager
        )
        pageView.sceneNumberPosition = sceneNumberPosition
        pageView.editorAppearanceMode = editorAppearanceMode
        pageView.currentRevisionColor = currentRevisionColor
        pageView.textView.currentRevisionColor = currentRevisionColor

        // Wire up text view callbacks
        pageView.textView.onContentChanged = { [weak self] in
            self?.onContentChanged?()
        }
        pageView.textView.onElementTypeChanged = { [weak self] type in
            self?.currentElementType = type
            self?.onElementTypeChanged?(type)
        }

        // Position the page (account for title page if showing)
        let titlePageOffset: CGFloat = showTitlePage ? (ScreenplayFormat.pageHeight + pageSpacing) : 0
        let yPosition = titlePageOffset + CGFloat(pageIndex) * (ScreenplayFormat.pageHeight + pageSpacing) + pageSpacing
        pageView.frame = NSRect(
            x: horizontalPadding,
            y: yPosition,
            width: ScreenplayFormat.pageWidth,
            height: ScreenplayFormat.pageHeight
        )

        pageViews.append(pageView)
        addSubview(pageView)

        // Force the text view to layout its content area
        // This is critical for the first page when content is loaded
        if let tc = pageView.textView.textContainer {
            layoutManager.ensureLayout(for: tc)
        }
        pageView.textView.needsDisplay = true

        // Update our frame to fit all pages
        updateFrameSize()
    }

    private func removePage() {
        guard pageViews.count > 1 else { return }

        if let lastPage = pageViews.popLast() {
            lastPage.removeFromSuperview()
        }

        if textContainers.popLast() != nil {
            layoutManager.removeTextContainer(at: textContainers.count)
        }

        updateFrameSize()
    }

    private func updateFrameSize() {
        let titlePageHeight: CGFloat = showTitlePage ? (ScreenplayFormat.pageHeight + pageSpacing) : 0
        let totalHeight = titlePageHeight + CGFloat(pageViews.count) * (ScreenplayFormat.pageHeight + pageSpacing) + pageSpacing
        let totalWidth = ScreenplayFormat.pageWidth + horizontalPadding * 2
        frame = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
    }

    private func updateTitlePageVisibility() {
        if showTitlePage {
            if titlePageView == nil {
                let tpView = ScreenplayTitlePageView()
                tpView.document = titlePageDocument
                tpView.editorAppearanceMode = editorAppearanceMode
                tpView.frame = NSRect(
                    x: horizontalPadding,
                    y: pageSpacing,
                    width: ScreenplayFormat.pageWidth,
                    height: ScreenplayFormat.pageHeight
                )
                titlePageView = tpView
                addSubview(tpView)
            }
        } else {
            titlePageView?.removeFromSuperview()
            titlePageView = nil
        }
        updateFrameSize()
    }

    private func repositionAllPages() {
        let titlePageOffset: CGFloat = showTitlePage ? (ScreenplayFormat.pageHeight + pageSpacing) : 0
        for (index, pageView) in pageViews.enumerated() {
            let yPosition = titlePageOffset + CGFloat(index) * (ScreenplayFormat.pageHeight + pageSpacing) + pageSpacing
            pageView.frame = NSRect(
                x: horizontalPadding,
                y: yPosition,
                width: ScreenplayFormat.pageWidth,
                height: ScreenplayFormat.pageHeight
            )
        }
        updateFrameSize()
    }

    private func updatePageCount() {
        // Force generation of glyphs for all text BEFORE checking page requirements
        if textStorage.length > 0 {
            layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        }

        // Check if we need more pages by seeing if content overflows
        if let lastContainer = textContainers.last {
            layoutManager.ensureLayout(for: lastContainer)
        }

        // Add pages while content overflows
        while needsMorePages() {
            addPage()
        }

        // Remove empty trailing pages (keep at least one)
        while canRemovePage() {
            removePage()
        }
    }

    private func needsMorePages() -> Bool {
        guard let lastContainer = textContainers.last else { return false }

        // Check if the last container has content that doesn't fit
        let glyphRange = layoutManager.glyphRange(for: lastContainer)
        if glyphRange.length == 0 && textContainers.count > 1 {
            return false
        }

        // Check if there's more text after what fits in all containers
        let totalGlyphs = layoutManager.numberOfGlyphs
        var displayedGlyphs = 0
        for container in textContainers {
            displayedGlyphs += layoutManager.glyphRange(for: container).length
        }

        return displayedGlyphs < totalGlyphs
    }

    private func canRemovePage() -> Bool {
        guard pageViews.count > 1, let lastContainer = textContainers.last else { return false }

        // Can remove if last page has no glyphs
        let glyphRange = layoutManager.glyphRange(for: lastContainer)
        return glyphRange.length == 0
    }

    // MARK: - Content Management

    @objc private func textDidChange(_ notification: Notification) {
        // Check if notification is from one of our text views
        guard let textView = notification.object as? NSTextView,
              pageViews.contains(where: { $0.textView === textView }) else {
            return
        }

        print("[REVISION DEBUG] textDidChange: currentRevisionColor=\(currentRevisionColor ?? "nil"), textStorage.length=\(textStorage.length)")

        // Apply revision color to changed paragraphs if revision mode is active
        applyRevisionColorToChanges(in: textView)

        // Redraw page views to update revision asterisks in margins
        pageViews.forEach { $0.needsDisplay = true }

        updatePageCount()
        onContentChanged?()
    }

    /// Industry standard revision color order (for determining if new color is "higher" priority)
    private static let revisionColorOrder: [String] = [
        "white", "blue", "pink", "yellow", "green", "goldenrod", "buff", "salmon", "cherry", "tan", "gray"
    ]

    /// Get the priority index for a revision color (higher = more recent revision)
    private func revisionColorPriority(_ colorName: String) -> Int {
        return Self.revisionColorOrder.firstIndex(of: colorName.lowercased()) ?? 0
    }

    /// Apply revision color to paragraphs that were changed
    /// Industry standard behavior:
    /// - Only NEW text added in revision mode gets marked with the current revision color
    /// - Deletions (backspace/delete) should NOT mark existing text as revised
    /// - A higher revision color (e.g., Pink) can overwrite a lower one (e.g., Blue)
    /// - This allows proper tracking when going through multiple revision passes
    private func applyRevisionColorToChanges(in textView: NSTextView) {
        // Only apply revision color if the last change was an insertion, not a deletion
        guard let paginatedTextView = textView as? PaginatedScreenplayTextView,
              paginatedTextView.lastChangeWasInsertion else {
            print("[REVISION DEBUG] applyRevisionColorToChanges: skipping - last change was deletion, not insertion")
            return
        }

        // Only apply if we have a revision color that isn't white
        guard let revisionColor = currentRevisionColor,
              !revisionColor.isEmpty,
              revisionColor.lowercased() != "white" else {
            print("[REVISION DEBUG] applyRevisionColorToChanges: skipping - no active revision color")
            return
        }

        // Get the selection/cursor position to identify which paragraph was edited
        let cursorPos = textView.selectedRange().location
        print("[REVISION DEBUG] applyRevisionColorToChanges: cursorPos=\(cursorPos), textStorage.length=\(textStorage.length)")

        guard cursorPos > 0 || textStorage.length > 0 else {
            print("[REVISION DEBUG] applyRevisionColorToChanges: skipping - cursor at 0 and empty storage")
            return
        }

        let fullText = textStorage.string as NSString
        let safePos = min(max(0, cursorPos), fullText.length > 0 ? fullText.length - 1 : 0)

        guard safePos < fullText.length else {
            print("[REVISION DEBUG] applyRevisionColorToChanges: skipping - safePos >= fullText.length")
            return
        }

        // Get the paragraph range at cursor
        let paraRange = fullText.paragraphRange(for: NSRange(location: safePos, length: 0))
        let paraText = fullText.substring(with: paraRange)
        print("[REVISION DEBUG] applyRevisionColorToChanges: paraRange=\(paraRange), paraText='\(paraText.prefix(50))...'")

        guard paraRange.location < textStorage.length else {
            print("[REVISION DEBUG] applyRevisionColorToChanges: skipping - paraRange.location >= textStorage.length")
            return
        }

        // Check if this paragraph already has a revision color
        let existingAttrs = textStorage.attributes(at: paraRange.location, effectiveRange: nil)
        if let existingRevisionColor = existingAttrs[.screenplayRevisionColor] as? String,
           !existingRevisionColor.isEmpty,
           existingRevisionColor.lowercased() != "white" {
            // Paragraph already has a revision color - only overwrite if current is higher priority
            let existingPriority = revisionColorPriority(existingRevisionColor)
            let newPriority = revisionColorPriority(revisionColor)

            print("[REVISION DEBUG] applyRevisionColorToChanges: existing=\(existingRevisionColor)(pri=\(existingPriority)), new=\(revisionColor)(pri=\(newPriority))")

            if newPriority <= existingPriority {
                // Don't overwrite with same or lower priority revision
                print("[REVISION DEBUG] applyRevisionColorToChanges: skipping - new priority not higher")
                return
            }
            // Higher priority revision - continue to overwrite
            print("[REVISION DEBUG] applyRevisionColorToChanges: overwriting with higher priority revision")
        }

        print("[REVISION DEBUG] applyRevisionColorToChanges: APPLYING revision color '\(revisionColor)' to range \(paraRange)")
        print("[REVISION DEBUG] applyRevisionColorToChanges: BEFORE - textStorage.length=\(textStorage.length)")

        // Apply revision color to this paragraph
        textStorage.beginEditing()

        // Set the revision color attribute
        textStorage.addAttribute(.screenplayRevisionColor, value: revisionColor, range: paraRange)

        // Apply text color for revision marking
        if let textColor = revisionTextColor(for: revisionColor) {
            textStorage.addAttribute(.foregroundColor, value: textColor, range: paraRange)
            print("[REVISION DEBUG] applyRevisionColorToChanges: applied foregroundColor")
        }

        textStorage.endEditing()
        print("[REVISION DEBUG] applyRevisionColorToChanges: AFTER - textStorage.length=\(textStorage.length)")
    }

    /// Load a document into the editor
    func loadDocument(_ document: ScreenplayDocument) {
        print("🔴 [REVISION DEBUG] loadDocument: START - \(document.elements.count) elements")
        for (i, el) in document.elements.prefix(3).enumerated() {
            print("🔴 [REVISION DEBUG]   element[\(i)]: type=\(el.type.rawValue), text='\(el.text.prefix(30))...'")
        }

        // Build attributed string from document elements
        let attributedString = NSMutableAttributedString()

        for (index, element) in document.elements.enumerated() {
            // Skip omitted non-heading elements (hide scene content when omitted)
            // Only show the scene heading with "OMITTED" text
            if element.isOmitted && element.type != .sceneHeading {
                continue
            }

            var attrs = ScreenplayFormat.typingAttributes(for: element.type)

            // First element should have no space before (it starts at top of page)
            if index == 0, let style = attrs[.paragraphStyle] as? NSParagraphStyle,
               let mutableStyle = style.mutableCopy() as? NSMutableParagraphStyle {
                mutableStyle.paragraphSpacingBefore = 0
                attrs[.paragraphStyle] = mutableStyle
            }

            // Add custom attribute for element type tracking
            attrs[.screenplayElementType] = element.type.rawValue

            // Store element ID for revision tracking
            attrs[.screenplayElementID] = element.id.uuidString

            // Apply revision text color if element has revision marks
            if let revisionColor = element.revisionColor,
               revisionColor.lowercased() != "white" {
                attrs[.screenplayRevisionColor] = revisionColor
                if let textColor = revisionTextColor(for: revisionColor) {
                    attrs[.foregroundColor] = textColor
                }
            }

            // Store revision metadata
            if let revisionID = element.revisionID {
                attrs[.screenplayRevisionID] = revisionID
            }
            if let originalText = element.originalText {
                attrs[.screenplayOriginalText] = originalText
            }
            if element.isNewInRevision {
                attrs[.screenplayIsNewInRevision] = true
            }

            // Store scene number and omitted status
            if let sceneNumber = element.sceneNumber {
                attrs[.screenplaySceneNumber] = sceneNumber
            }
            if element.isOmitted {
                attrs[.screenplayIsOmitted] = true
            }

            // Use displayText which shows "OMITTED" for omitted scene headings
            var text = element.displayText

            // Add newline after each element except the last
            if index < document.elements.count - 1 {
                text += "\n"
            }

            let attrString = NSAttributedString(string: text, attributes: attrs)
            attributedString.append(attrString)
        }

        // Set the content
        textStorage.beginEditing()
        textStorage.setAttributedString(attributedString)
        textStorage.endEditing()

        // Update page count (this may add more pages based on content)
        updatePageCount()

        // Force layout for all text
        if textStorage.length > 0 {
            layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        }

        // Force all page views to redraw
        for pageView in pageViews {
            pageView.textView.needsDisplay = true
            pageView.needsDisplay = true
        }
        needsDisplay = true

        // Set initial element type
        if let firstElement = document.elements.first {
            currentElementType = firstElement.type
        } else {
            currentElementType = .sceneHeading
        }
    }

    /// Extract elements from the text storage
    func extractElements() -> [ScriptElement] {
        var elements: [ScriptElement] = []
        let fullText = textStorage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return elements }

        var currentLocation = 0

        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            let paraText = fullText.substring(with: paraRange).trimmingCharacters(in: .newlines)

            if !paraText.trimmingCharacters(in: .whitespaces).isEmpty {
                // Get attributes from text storage
                let attrs = paraRange.location < fullLength
                    ? textStorage.attributes(at: paraRange.location, effectiveRange: nil)
                    : [:]

                // Get element type from attributes
                let elementType: ScriptElementType
                if let typeRawValue = attrs[.screenplayElementType] as? String,
                   let type = ScriptElementType(rawValue: typeRawValue) {
                    elementType = type
                } else {
                    elementType = .action
                }

                // Extract revision data from attributes
                let elementId: UUID
                if let idString = attrs[.screenplayElementID] as? String,
                   let id = UUID(uuidString: idString) {
                    elementId = id
                } else {
                    elementId = UUID()
                }

                let revisionColor = attrs[.screenplayRevisionColor] as? String
                let revisionID = attrs[.screenplayRevisionID] as? Int
                let originalText = attrs[.screenplayOriginalText] as? String
                let isNewInRevision = attrs[.screenplayIsNewInRevision] as? Bool ?? false
                let sceneNumber = attrs[.screenplaySceneNumber] as? String
                let isOmitted = attrs[.screenplayIsOmitted] as? Bool ?? false

                let element = ScriptElement(
                    id: elementId,
                    type: elementType,
                    text: paraText,
                    sceneNumber: sceneNumber,
                    isOmitted: isOmitted,
                    revisionColor: revisionColor,
                    revisionID: revisionID,
                    originalText: originalText,
                    isNewInRevision: isNewInRevision,
                    isDeletedInRevision: false
                )
                elements.append(element)
            }

            currentLocation = paraRange.location + paraRange.length
        }

        return elements
    }

    /// Convert revision color name to NSColor for text coloring
    private func revisionTextColor(for colorName: String) -> NSColor? {
        let lower = colorName.lowercased()
        if lower == "white" || lower.isEmpty {
            return nil  // No color change for white
        }
        return ScriptRevisionColors.platformColor(for: colorName)
    }

    /// Set the element type for the current paragraph
    func setElementType(_ type: ScriptElementType) {
        currentElementType = type

        // Find the first responder text view
        guard let textView = pageViews.first(where: { $0.textView.window?.firstResponder === $0.textView })?.textView else {
            // If no text view has focus, update the first page's text view
            if let firstTextView = pageViews.first?.textView {
                firstTextView.currentElementType = type
            }
            return
        }

        // Update the text view's current element type
        textView.currentElementType = type

        let selection = textView.selectedRange()
        let text = textStorage.string as NSString
        let paraRange = text.paragraphRange(for: selection)

        // Apply new formatting
        var attrs = ScreenplayFormat.typingAttributes(for: type)
        attrs[.screenplayElementType] = type.rawValue

        textStorage.beginEditing()
        textStorage.addAttributes(attrs, range: paraRange)

        // Auto-capitalize if needed
        if type.isAllCaps {
            let paraText = text.substring(with: paraRange)
            let upper = paraText.uppercased()
            if paraText != upper {
                textStorage.replaceCharacters(in: paraRange, with: upper)
            }
        }

        textStorage.endEditing()

        // Update typing attributes
        textView.typingAttributes = attrs

        onElementTypeChanged?(type)
    }

    /// Update the scene number attribute for an element with the given ID
    func updateSceneNumber(_ sceneNumber: String, forElementID elementID: UUID) {
        let fullText = textStorage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return }

        var currentLocation = 0

        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))

            guard paraRange.location < fullLength else { break }

            // Get attributes for this paragraph
            let attrs = textStorage.attributes(at: paraRange.location, effectiveRange: nil)

            // Check if this is the element we're looking for
            if let idString = attrs[.screenplayElementID] as? String,
               let id = UUID(uuidString: idString),
               id == elementID {
                // Found it - update the scene number attribute
                textStorage.beginEditing()
                textStorage.addAttribute(.screenplaySceneNumber, value: sceneNumber, range: paraRange)
                textStorage.endEditing()
                return
            }

            currentLocation = paraRange.location + paraRange.length
        }
    }

    /// Get the number of pages
    var pageCount: Int {
        return pageViews.count
    }

    /// Make the first page's text view the first responder
    func makeFirstResponder() {
        if let firstPage = pageViews.first {
            firstPage.textView.window?.makeFirstResponder(firstPage.textView)
        }
    }

    /// Scroll to show a specific element (paragraph) at the given index
    func scrollToElement(at elementIndex: Int, in scrollView: NSScrollView) {
        let fullText = textStorage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return }

        // Find the character range for the element at the given index
        var currentLocation = 0
        var currentElementIndex = 0

        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            let paraText = fullText.substring(with: paraRange).trimmingCharacters(in: .newlines)

            // Only count non-empty paragraphs (matching extractElements logic)
            if !paraText.trimmingCharacters(in: .whitespaces).isEmpty {
                if currentElementIndex == elementIndex {
                    // Found the target element - get its layout position
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: paraRange, actualCharacterRange: nil)

                    // Find which container/page this glyph range is in
                    for (pageIndex, container) in textContainers.enumerated() {
                        let containerGlyphRange = layoutManager.glyphRange(for: container)
                        if NSIntersectionRange(glyphRange, containerGlyphRange).length > 0 {
                            // Found the page - get position within page
                            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)

                            // Calculate absolute Y position in document view
                            let pageY = CGFloat(pageIndex) * (ScreenplayFormat.pageHeight + pageSpacing)
                            let elementY = pageY + ScreenplayFormat.marginTop + boundingRect.origin.y

                            // Scroll to show this position (with some padding at top)
                            // Preserve the current X position to maintain horizontal centering
                            let currentX = scrollView.contentView.bounds.origin.x
                            let targetPoint = NSPoint(x: currentX, y: elementY - 50)
                            scrollView.contentView.scroll(to: targetPoint)
                            scrollView.reflectScrolledClipView(scrollView.contentView)
                            break
                        }
                    }
                    return
                }
                currentElementIndex += 1
            }

            currentLocation = paraRange.location + paraRange.length
        }
    }
}

// MARK: - Centering Clip View for Paginated Editor

/// Custom NSClipView that centers the document view horizontally
private final class PaginatedCenteringClipView: NSClipView {
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

// MARK: - SwiftUI Wrapper

struct PaginatedScreenplayEditor: NSViewRepresentable {
    @Binding var document: ScreenplayDocument?
    @Binding var currentElementType: ScriptElementType
    @Binding var pageCount: Int
    @Binding var sceneNumberPosition: SceneNumberPosition
    @Binding var scrollToElementIndex: Int?
    var currentRevisionColor: String?  // nil or "White" means no revision tracking
    var editorAppearanceMode: String = "System"  // "System", "Light", or "Dark"
    var forceReload: UUID = UUID()  // Change this to force document reload
    var onDocumentChanged: ((ScreenplayDocument) -> Void)?

    /// Check if the effective appearance is dark mode
    private var isEffectivelyDarkMode: Bool {
        switch editorAppearanceMode {
        case "Dark":
            return true
        case "Light":
            return false
        default:
            // System mode - check NSApp's effective appearance (SwiftUI context)
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    /// Get the background color for the surrounding area based on appearance mode
    private func surroundingBackgroundColor() -> NSColor {
        if isEffectivelyDarkMode {
            return NSColor(calibratedWhite: 0.20, alpha: 1.0)  // Dark gray for dark mode
        } else {
            return NSColor(calibratedWhite: 0.85, alpha: 1.0)  // Light gray for light mode
        }
    }

    /// Calculate scene number for a new scene inserted between two existing scenes
    /// Uses industry standard: 12A, 12B, etc. for scenes between 12 and 13
    /// For scenes at the end, uses next sequential number
    private func calculateSceneNumber(previousNumber: String?, nextNumber: String?) -> String {
        // Get all existing scene numbers from the document
        let existingNumbers: Set<String> = {
            guard let doc = document else { return [] }
            return SceneNumberUtils.allSceneNumbers(in: doc)
        }()

        // If no previous scene, this is at the start
        guard let prev = previousNumber else {
            if let next = nextNumber {
                // Insert before first scene - use A1, B1 format (prefix)
                return SceneNumberUtils.nextNumberBefore(next, existingNumbers: existingNumbers)
            }
            return "1"
        }

        // If no next scene, append to end
        guard nextNumber != nil else {
            // Extract base number from previous scene and increment
            let (baseNum, _) = SceneNumberUtils.parseSceneNumber(prev)
            return "\(baseNum + 1)"
        }

        // Insert between two scenes - use suffix format (1A, 1B, etc.)
        return SceneNumberUtils.nextNumberAfter(prev, existingNumbers: existingNumbers)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = surroundingBackgroundColor()

        // Use centering clip view
        let clipView = PaginatedCenteringClipView()
        clipView.drawsBackground = true
        clipView.backgroundColor = surroundingBackgroundColor()
        scrollView.contentView = clipView

        let documentView = PaginatedDocumentView()
        documentView.sceneNumberPosition = sceneNumberPosition
        documentView.currentRevisionColor = currentRevisionColor
        documentView.editorAppearanceMode = editorAppearanceMode
        documentView.onContentChanged = { [weak documentView] in
            guard let docView = documentView else { return }

            var doc = self.document ?? ScreenplayDocument(title: "Untitled")
            doc.elements = docView.extractElements()

            // Update document's revision state from current editor revision
            if let revColor = self.currentRevisionColor, revColor.lowercased() != "white" {
                doc.currentRevisionColor = revColor
                doc.isRevisionMode = true
            }

            // Auto-assign scene numbers for new scene headings when document is locked
            if doc.isLocked {
                for i in 0..<doc.elements.count {
                    let element = doc.elements[i]
                    if element.type == .sceneHeading && (element.sceneNumber == nil || element.sceneNumber?.isEmpty == true) {
                        // Find previous and next scene numbers
                        var prevNumber: String? = nil
                        var nextNumber: String? = nil

                        // Look for previous scene
                        for j in stride(from: i - 1, through: 0, by: -1) {
                            if doc.elements[j].type == .sceneHeading, let num = doc.elements[j].sceneNumber, !num.isEmpty {
                                prevNumber = num
                                break
                            }
                        }

                        // Look for next scene
                        for j in (i + 1)..<doc.elements.count {
                            if doc.elements[j].type == .sceneHeading, let num = doc.elements[j].sceneNumber, !num.isEmpty {
                                nextNumber = num
                                break
                            }
                        }

                        // Calculate and assign new scene number
                        let newSceneNumber = self.calculateSceneNumber(previousNumber: prevNumber, nextNumber: nextNumber)
                        doc.elements[i].sceneNumber = newSceneNumber

                        // Update text storage attribute
                        docView.updateSceneNumber(newSceneNumber, forElementID: element.id)
                    }
                }
            }

            DispatchQueue.main.async {
                self.pageCount = docView.pageCount
                self.onDocumentChanged?(doc)
            }
        }

        documentView.onElementTypeChanged = { type in
            DispatchQueue.main.async {
                self.currentElementType = type
            }
        }

        scrollView.documentView = documentView
        context.coordinator.documentView = documentView
        context.coordinator.lastReloadId = forceReload  // Initialize to prevent double-load
        context.coordinator.lastDocumentId = document?.id  // Track which document is loaded

        // Load document immediately - the view hierarchy is set up at this point
        if let doc = document {
            print("[LOAD DEBUG] makeNSView: Loading document '\(doc.title)' with \(doc.elements.count) elements")
            documentView.titlePageDocument = doc  // Set for title page rendering
            documentView.loadDocument(doc)
            // Update page count on next run loop to avoid modifying state during view update
            DispatchQueue.main.async {
                self.pageCount = documentView.pageCount
            }
        }

        // Make text view first responder on next run loop
        DispatchQueue.main.async {
            documentView.makeFirstResponder()
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let documentView = context.coordinator.documentView else { return }

        // Check if document changed (different document selected)
        let currentDocId = document?.id
        let needsDocumentReload = context.coordinator.lastDocumentId != currentDocId ||
                                   context.coordinator.lastReloadId != forceReload

        if needsDocumentReload {
            context.coordinator.lastReloadId = forceReload
            context.coordinator.lastDocumentId = currentDocId
            print("[LOAD DEBUG] updateNSView: Document reload triggered - docId changed: \(context.coordinator.lastDocumentId != currentDocId), forceReload changed: \(context.coordinator.lastReloadId != forceReload)")
            if let doc = document {
                print("[LOAD DEBUG] updateNSView: loading document '\(doc.title)' with \(doc.elements.count) elements")
                documentView.titlePageDocument = doc  // Update title page document
                documentView.loadDocument(doc)
                DispatchQueue.main.async {
                    self.pageCount = documentView.pageCount
                }
            }
        }

        // Update title page visibility if document's showTitlePage changed
        if let doc = document {
            if documentView.showTitlePage != doc.showTitlePage {
                documentView.titlePageDocument = doc
            }
        }

        // Update element type if changed externally
        if documentView.currentElementType != currentElementType {
            documentView.setElementType(currentElementType)
        }

        // Update scene numbers position
        if documentView.sceneNumberPosition != sceneNumberPosition {
            documentView.sceneNumberPosition = sceneNumberPosition
        }

        // Update revision color if changed
        if documentView.currentRevisionColor != currentRevisionColor {
            print("[REVISION DEBUG] updateNSView: revision color changed from '\(documentView.currentRevisionColor ?? "nil")' to '\(currentRevisionColor ?? "nil")'")
            documentView.currentRevisionColor = currentRevisionColor
        }

        // Update appearance mode on page views AND surrounding area
        if documentView.editorAppearanceMode != editorAppearanceMode {
            documentView.editorAppearanceMode = editorAppearanceMode
            // Also update scroll view and clip view backgrounds
            let bgColor = surroundingBackgroundColor()
            nsView.backgroundColor = bgColor
            nsView.contentView.backgroundColor = bgColor
        }

        // Scroll to element if requested
        if let elementIndex = scrollToElementIndex {
            documentView.scrollToElement(at: elementIndex, in: nsView)
            DispatchQueue.main.async {
                self.scrollToElementIndex = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var documentView: PaginatedDocumentView?
        var lastReloadId: UUID?
        var lastDocumentId: UUID?
    }
}

#endif

// MARK: - iOS Implementation
#if os(iOS)
import UIKit

// MARK: - iOS Paginated Document View

/// iOS container view holding all pages - simplified version using UIScrollView
final class PaginatedDocumentViewiOS: UIView {

    /// Text storage for the screenplay content
    private let textStorage: NSTextStorage
    private let layoutManager: NSLayoutManager
    private var textContainers: [NSTextContainer] = []
    private var pageViews: [ScreenplayPageViewiOS] = []

    private let pageSpacing: CGFloat = 20
    private let horizontalPadding: CGFloat = 20

    /// Current element type
    private(set) var currentElementType: ScriptElementType = .sceneHeading

    /// Scene number position setting
    var sceneNumberPosition: SceneNumberPosition = .none

    /// Current revision color
    var currentRevisionColor: String?

    /// Callbacks
    var onContentChanged: (() -> Void)?
    var onElementTypeChanged: ((ScriptElementType) -> Void)?

    override init(frame: CGRect) {
        textStorage = NSTextStorage()
        layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        super.init(frame: frame)

        backgroundColor = UIColor.systemGray5

        // Add initial page
        addPage()

        // Observe text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: UITextView.textDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Page Management

    private func addPage() {
        let pageIndex = textContainers.count

        // Create text container for this page
        let container = NSTextContainer(size: CGSize(
            width: ScreenplayFormatiOS.contentWidth,
            height: ScreenplayFormatiOS.contentHeight
        ))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        textContainers.append(container)
        layoutManager.addTextContainer(container)

        // Create page view
        let pageView = ScreenplayPageViewiOS(
            textContainer: container,
            sharedTextStorage: textStorage,
            layoutManager: layoutManager,
            pageIndex: pageIndex
        )
        pageView.sceneNumberPosition = sceneNumberPosition
        pageView.currentRevisionColor = currentRevisionColor

        // Wire up callbacks
        pageView.textView.onContentChanged = { [weak self] in
            self?.onContentChanged?()
        }
        pageView.textView.onElementTypeChanged = { [weak self] type in
            self?.currentElementType = type
            self?.onElementTypeChanged?(type)
        }

        // Position the page
        let yPosition = CGFloat(pageIndex) * (ScreenplayFormatiOS.pageHeight + pageSpacing) + pageSpacing
        pageView.frame = CGRect(
            x: horizontalPadding,
            y: yPosition,
            width: ScreenplayFormatiOS.pageWidth,
            height: ScreenplayFormatiOS.pageHeight
        )

        pageViews.append(pageView)
        addSubview(pageView)

        updateFrameSize()
    }

    private func updateFrameSize() {
        let totalHeight = CGFloat(pageViews.count) * (ScreenplayFormatiOS.pageHeight + pageSpacing) + pageSpacing
        let totalWidth = ScreenplayFormatiOS.pageWidth + horizontalPadding * 2
        frame.size = CGSize(width: totalWidth, height: totalHeight)
    }

    private func updatePageCount() {
        // Check if we need more pages
        while needsMorePages() && pageViews.count < 100 {  // Safety limit
            addPage()
        }

        // Remove empty trailing pages
        while canRemovePage() {
            removePage()
        }
    }

    private func needsMorePages() -> Bool {
        guard let lastContainer = textContainers.last else { return false }

        let glyphRange = layoutManager.glyphRange(for: lastContainer)
        if glyphRange.length == 0 && textContainers.count > 1 {
            return false
        }

        let totalGlyphs = layoutManager.numberOfGlyphs
        var displayedGlyphs = 0
        for container in textContainers {
            displayedGlyphs += layoutManager.glyphRange(for: container).length
        }

        return displayedGlyphs < totalGlyphs
    }

    private func canRemovePage() -> Bool {
        guard pageViews.count > 1, let lastContainer = textContainers.last else { return false }
        let glyphRange = layoutManager.glyphRange(for: lastContainer)
        return glyphRange.length == 0
    }

    private func removePage() {
        guard pageViews.count > 1 else { return }

        if let lastPage = pageViews.popLast() {
            lastPage.removeFromSuperview()
        }

        if textContainers.popLast() != nil {
            layoutManager.removeTextContainer(at: textContainers.count)
        }

        updateFrameSize()
    }

    // MARK: - Content Management

    @objc private func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? UITextView,
              pageViews.contains(where: { $0.textView === textView }) else {
            return
        }

        updatePageCount()
        pageViews.forEach { $0.setNeedsDisplay() }
        onContentChanged?()
    }

    /// Load a document into the editor
    func loadDocument(_ document: ScreenplayDocument) {
        let attributedString = NSMutableAttributedString()

        for (index, element) in document.elements.enumerated() {
            var attrs = ScreenplayFormatiOS.typingAttributes(for: element.type)
            attrs[.screenplayElementType] = element.type.rawValue

            // Apply revision color if present
            if let revisionColor = element.revisionColor,
               revisionColor.lowercased() != "white" {
                attrs[.screenplayRevisionColor] = revisionColor
                if let textColor = revisionTextColor(for: revisionColor) {
                    attrs[.foregroundColor] = textColor
                }
            }

            var text = element.displayText
            if index < document.elements.count - 1 {
                text += "\n"
            }

            let attrString = NSAttributedString(string: text, attributes: attrs)
            attributedString.append(attrString)
        }

        textStorage.beginEditing()
        textStorage.setAttributedString(attributedString)
        textStorage.endEditing()

        updatePageCount()

        if let firstElement = document.elements.first {
            currentElementType = firstElement.type
        } else {
            currentElementType = .sceneHeading
        }
    }

    /// Extract elements from the text storage
    func extractElements() -> [ScriptElement] {
        var elements: [ScriptElement] = []
        let fullText = textStorage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return elements }

        var currentLocation = 0

        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            let paraText = fullText.substring(with: paraRange).trimmingCharacters(in: .newlines)

            if !paraText.trimmingCharacters(in: .whitespaces).isEmpty {
                let attrs = paraRange.location < fullLength
                    ? textStorage.attributes(at: paraRange.location, effectiveRange: nil)
                    : [:]

                let elementType: ScriptElementType
                if let typeRawValue = attrs[.screenplayElementType] as? String,
                   let type = ScriptElementType(rawValue: typeRawValue) {
                    elementType = type
                } else {
                    elementType = .action
                }

                let revisionColor = attrs[.screenplayRevisionColor] as? String

                let element = ScriptElement(
                    type: elementType,
                    text: paraText,
                    revisionColor: revisionColor
                )
                elements.append(element)
            }

            currentLocation = paraRange.location + paraRange.length
        }

        return elements
    }

    /// Set the element type for the current paragraph
    func setElementType(_ type: ScriptElementType) {
        currentElementType = type

        guard let textView = pageViews.first?.textView else { return }

        let selection = textView.selectedRange
        let text = textStorage.string as NSString
        let paraRange = text.paragraphRange(for: selection)

        var attrs = ScreenplayFormatiOS.typingAttributes(for: type)
        attrs[.screenplayElementType] = type.rawValue

        textStorage.beginEditing()
        textStorage.addAttributes(attrs, range: paraRange)

        if type.isAllCaps {
            let paraText = text.substring(with: paraRange)
            let upper = paraText.uppercased()
            if paraText != upper {
                textStorage.replaceCharacters(in: paraRange, with: upper)
            }
        }

        textStorage.endEditing()

        textView.typingAttributes = attrs
        onElementTypeChanged?(type)
    }

    private func revisionTextColor(for colorName: String) -> UIColor? {
        let lower = colorName.lowercased()
        if lower == "white" || lower.isEmpty {
            return nil
        }

        switch lower {
        case "blue": return UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        case "pink": return UIColor(red: 0.85, green: 0.2, blue: 0.5, alpha: 1.0)
        case "yellow": return UIColor(red: 0.7, green: 0.55, blue: 0.0, alpha: 1.0)
        case "green": return UIColor(red: 0.0, green: 0.6, blue: 0.3, alpha: 1.0)
        case "goldenrod": return UIColor(red: 0.72, green: 0.53, blue: 0.04, alpha: 1.0)
        case "buff": return UIColor(red: 0.6, green: 0.45, blue: 0.2, alpha: 1.0)
        case "salmon": return UIColor(red: 0.9, green: 0.35, blue: 0.25, alpha: 1.0)
        case "cherry": return UIColor(red: 0.75, green: 0.15, blue: 0.4, alpha: 1.0)
        case "tan": return UIColor(red: 0.55, green: 0.4, blue: 0.25, alpha: 1.0)
        case "gray", "grey": return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        default: return nil
        }
    }

    /// Get the number of pages
    var pageCount: Int {
        return pageViews.count
    }

    /// Make the first page's text view the first responder
    func makeFirstResponder() {
        pageViews.first?.textView.becomeFirstResponder()
    }
}

// MARK: - iOS Page View

/// UIView representing a single page
final class ScreenplayPageViewiOS: UIView {
    let textView: PaginatedScreenplayTextViewiOS
    let pageIndex: Int
    private weak var layoutManager: NSLayoutManager?
    private weak var textContainer: NSTextContainer?

    var sceneNumberPosition: SceneNumberPosition = .none {
        didSet { setNeedsDisplay() }
    }

    var currentRevisionColor: String? {
        didSet { setNeedsDisplay() }
    }

    init(textContainer: NSTextContainer, sharedTextStorage: NSTextStorage, layoutManager: NSLayoutManager, pageIndex: Int) {
        self.pageIndex = pageIndex
        self.layoutManager = layoutManager
        self.textContainer = textContainer

        let contentFrame = CGRect(
            x: ScreenplayFormatiOS.leftMargin,
            y: ScreenplayFormatiOS.topMargin,
            width: ScreenplayFormatiOS.contentWidth,
            height: ScreenplayFormatiOS.contentHeight
        )

        textView = PaginatedScreenplayTextViewiOS(frame: contentFrame, textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = ScreenplayFormatiOS.font()
        textView.textColor = .label
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no

        super.init(frame: CGRect(x: 0, y: 0, width: ScreenplayFormatiOS.pageWidth, height: ScreenplayFormatiOS.pageHeight))

        backgroundColor = .white
        layer.cornerRadius = 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        // Draw page number (except page 1)
        if pageIndex > 0 {
            let courierFont = UIFont(name: "Courier", size: 12) ?? UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let pageNumberString = "\(pageIndex + 1)."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: courierFont,
                .foregroundColor: UIColor.label
            ]
            let attrString = NSAttributedString(string: pageNumberString, attributes: attrs)
            let stringSize = attrString.size()
            let pageNumberRect = CGRect(
                x: bounds.width - ScreenplayFormatiOS.rightMargin - stringSize.width,
                y: ScreenplayFormatiOS.topMargin / 2 - stringSize.height / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            attrString.draw(in: pageNumberRect)
        }
    }
}

// MARK: - iOS Paginated Text View

final class PaginatedScreenplayTextViewiOS: UITextView {

    var currentElementType: ScriptElementType = .sceneHeading
    var currentRevisionColor: String?

    var onElementTypeChanged: ((ScriptElementType) -> Void)?
    var onContentChanged: (() -> Void)?

    private var isProgrammaticChange = false

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isEditable = true
        isSelectable = true
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .yes
        smartQuotesType = .no
        smartDashesType = .no

        font = ScreenplayFormatiOS.font()
        textColor = .label
        backgroundColor = .clear

        textContainer.lineFragmentPadding = 0

        let initialAttrs = ScreenplayFormatiOS.typingAttributes(for: .action)
        typingAttributes = initialAttrs

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: UITextView.textDidChangeNotification,
            object: self
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        guard !isProgrammaticChange else { return }
        onContentChanged?()
    }

    func setElementType(_ type: ScriptElementType) {
        currentElementType = type

        let attrs = ScreenplayFormatiOS.typingAttributes(for: type)
        typingAttributes = attrs

        if selectedRange.length > 0 {
            reformatRange(selectedRange, with: type)
        } else {
            reformatCurrentParagraph()
        }
    }

    private func reformatRange(_ range: NSRange, with type: ScriptElementType) {
        let storage = textStorage

        isProgrammaticChange = true

        let attrs = ScreenplayFormatiOS.typingAttributes(for: type)
        let text = storage.string as NSString
        let fullRange = text.paragraphRange(for: range)

        storage.addAttributes(attrs, range: fullRange)

        if type.isAllCaps {
            let rangeText = text.substring(with: fullRange)
            let upper = rangeText.uppercased()
            if rangeText != upper {
                storage.replaceCharacters(in: fullRange, with: upper)
                storage.addAttributes(attrs, range: NSRange(location: fullRange.location, length: upper.count))
            }
        }

        isProgrammaticChange = false
        onContentChanged?()
    }

    private func reformatCurrentParagraph() {
        let storage = textStorage

        let cursor = selectedRange.location
        guard cursor > 0 else { return }

        let text = storage.string as NSString
        let paraRange = text.paragraphRange(for: NSRange(location: cursor - 1, length: 0))

        isProgrammaticChange = true

        let attrs = ScreenplayFormatiOS.typingAttributes(for: currentElementType)
        storage.addAttributes(attrs, range: paraRange)

        if currentElementType.isAllCaps {
            let paraText = text.substring(with: paraRange)
            let upper = paraText.uppercased()
            if paraText != upper {
                storage.replaceCharacters(in: paraRange, with: upper)
                storage.addAttributes(attrs, range: NSRange(location: paraRange.location, length: upper.count))
            }
        }

        isProgrammaticChange = false
    }
}

// MARK: - iOS SwiftUI Wrapper

struct PaginatedScreenplayEditoriOS: UIViewRepresentable {
    @Binding var document: ScreenplayDocument?
    @Binding var currentElementType: ScriptElementType
    @Binding var pageCount: Int
    @Binding var sceneNumberPosition: SceneNumberPosition
    @Binding var scrollToElementIndex: Int?
    var currentRevisionColor: String?
    var editorAppearanceMode: String = "System"
    var forceReload: UUID = UUID()
    var onDocumentChanged: ((ScreenplayDocument) -> Void)?

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.backgroundColor = UIColor.systemGray5

        let documentView = PaginatedDocumentViewiOS()
        documentView.sceneNumberPosition = sceneNumberPosition
        documentView.currentRevisionColor = currentRevisionColor

        documentView.onContentChanged = { [weak documentView] in
            guard let docView = documentView else { return }

            var doc = self.document ?? ScreenplayDocument(title: "Untitled")
            doc.elements = docView.extractElements()

            DispatchQueue.main.async {
                self.pageCount = docView.pageCount
                self.onDocumentChanged?(doc)
            }
        }

        documentView.onElementTypeChanged = { type in
            DispatchQueue.main.async {
                self.currentElementType = type
            }
        }

        scrollView.addSubview(documentView)
        context.coordinator.documentView = documentView
        context.coordinator.lastReloadId = forceReload
        context.coordinator.lastDocumentId = document?.id

        // Load document
        if let doc = document {
            documentView.loadDocument(doc)
            DispatchQueue.main.async {
                self.pageCount = documentView.pageCount
            }
        }

        // Update scroll view content size
        scrollView.contentSize = documentView.frame.size

        // Make first responder
        DispatchQueue.main.async {
            documentView.makeFirstResponder()
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let documentView = context.coordinator.documentView else { return }

        let currentDocId = document?.id
        let needsDocumentReload = context.coordinator.lastDocumentId != currentDocId ||
                                   context.coordinator.lastReloadId != forceReload

        if needsDocumentReload {
            context.coordinator.lastReloadId = forceReload
            context.coordinator.lastDocumentId = currentDocId
            if let doc = document {
                documentView.loadDocument(doc)
                DispatchQueue.main.async {
                    self.pageCount = documentView.pageCount
                }
            }
        }

        if documentView.currentElementType != currentElementType {
            documentView.setElementType(currentElementType)
        }

        if documentView.sceneNumberPosition != sceneNumberPosition {
            documentView.sceneNumberPosition = sceneNumberPosition
        }

        if documentView.currentRevisionColor != currentRevisionColor {
            documentView.currentRevisionColor = currentRevisionColor
        }

        // Update content size
        uiView.contentSize = documentView.frame.size
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var documentView: PaginatedDocumentViewiOS?
        var lastReloadId: UUID?
        var lastDocumentId: UUID?
    }
}

#endif
