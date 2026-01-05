//
//  ScreenplayTextView.swift
//  Production Runner
//
//  Custom NSTextView for screenplay editing with Final Draft-style formatting.
//

import SwiftUI
#if canImport(AppKit)
import AppKit

// MARK: - Custom Attribute Keys for Element Type and Revisions

extension NSAttributedString.Key {
    static let screenplayElementType = NSAttributedString.Key("screenplayElementType")
    static let screenplayRevisionColor = NSAttributedString.Key("screenplayRevisionColor")
    static let screenplayRevisionID = NSAttributedString.Key("screenplayRevisionID")
    static let screenplayElementID = NSAttributedString.Key("screenplayElementID")
    static let screenplayOriginalText = NSAttributedString.Key("screenplayOriginalText")
    static let screenplayIsNewInRevision = NSAttributedString.Key("screenplayIsNewInRevision")
    static let screenplaySceneNumber = NSAttributedString.Key("screenplaySceneNumber")
    static let screenplayIsOmitted = NSAttributedString.Key("screenplayIsOmitted")
}

// MARK: - Screenplay Text View

final class ScreenplayTextView: NSTextView {

    /// Current element type at cursor position
    private(set) var currentElementType: ScriptElementType = .action {
        didSet {
            if oldValue != currentElementType {
                print("[ScreenplayTextView] ⚠️ ELEMENT TYPE CHANGED: \(oldValue.rawValue) -> \(currentElementType.rawValue)")
                // Print stack trace to find what's changing it
                Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
                onElementTypeChanged?(currentElementType)
            }
        }
    }

    /// Callbacks
    var onElementTypeChanged: ((ScriptElementType) -> Void)?
    var onContentChanged: (() -> Void)?


    /// Track programmatic changes
    private var isProgrammaticChange = false

    /// Track if we're actively typing (to prevent style detection from overriding)
    private var isTyping = false

    /// Track if we're deleting (backspace/delete key)
    private var isDeleting = false

    // MARK: - Setup

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        print("[ScreenplayTextView] commonInit called")

        // Editor settings
        isRichText = true
        isEditable = true  // Explicitly enable editing
        isSelectable = true
        allowsUndo = true
        usesFindBar = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = true

        // Appearance - use system colors that adapt to dark mode
        font = ScreenplayFormat.font()
        textColor = .textColor
        backgroundColor = .textBackgroundColor
        insertionPointColor = .textColor

        // Text container
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = false

        // Initial attributes (without spacing for live editing)
        let initialStyle = ScreenplayFormat.paragraphStyle(for: .action)
        initialStyle.paragraphSpacingBefore = 0
        var initialAttrs = ScreenplayFormat.typingAttributes(for: .action)
        initialAttrs[.paragraphStyle] = initialStyle
        typingAttributes = initialAttrs

        print("[ScreenplayTextView] commonInit complete - isEditable: \(isEditable), isSelectable: \(isSelectable)")
        print("[ScreenplayTextView] font: \(String(describing: font))")
        print("[ScreenplayTextView] textContainer size: \(String(describing: textContainer?.size))")
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool {
        print("[ScreenplayTextView] acceptsFirstResponder called, returning true")
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        print("[ScreenplayTextView] becomeFirstResponder: \(result)")
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        print("[ScreenplayTextView] resignFirstResponder: \(result)")
        return result
    }

    // MARK: - Custom Pasteboard Type

    /// Custom pasteboard type for screenplay-formatted content
    static let screenplayPasteboardType = NSPasteboard.PasteboardType("com.productionrunner.screenplay")

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
            pasteboard.setData(jsonData, forType: Self.screenplayPasteboardType)
        }

        // Also write plain text for external apps
        pasteboard.setString(selectedAttrString.string, forType: .string)

        print("[ScreenplayTextView] Copied \(selection.length) characters with screenplay formatting")
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
        if let screenplayData = pasteboard.data(forType: Self.screenplayPasteboardType),
           let jsonArray = try? JSONSerialization.jsonObject(with: screenplayData) as? [[String: Any]] {

            pasteScreenplayData(jsonArray)
            return
        }

        // Fall back to plain text with current element formatting
        if let plainText = pasteboard.string(forType: .string), !plainText.isEmpty {
            let attrs = ScreenplayFormat.typingAttributes(for: currentElementType)
            let attrString = NSAttributedString(string: plainText, attributes: attrs)

            let insertLocation = selectedRange().location
            let insertLength = selectedRange().length

            isProgrammaticChange = true

            if insertLength > 0 {
                textStorage?.replaceCharacters(in: selectedRange(), with: attrString)
            } else {
                textStorage?.insert(attrString, at: insertLocation)
            }

            let newCursorPos = insertLocation + plainText.count
            setSelectedRange(NSRange(location: newCursorPos, length: 0))

            isProgrammaticChange = false
            onContentChanged?()

            print("[ScreenplayTextView] Pasted \(plainText.count) characters with screenplay formatting")
        } else {
            super.paste(sender)
        }
    }

    /// Paste screenplay-formatted data preserving all attributes
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

            if let revisionColor = elementData["revisionColor"] as? String {
                attrs[.screenplayRevisionColor] = revisionColor
                // Apply background color for revision
                if let bgColor = revisionBackgroundColor(for: revisionColor) {
                    attrs[.backgroundColor] = bgColor
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

        print("[ScreenplayTextView] Pasted screenplay data with \(data.count) formatted segments")
    }

    /// Get background color for revision color name
    private func revisionBackgroundColor(for colorName: String) -> NSColor? {
        switch colorName.lowercased() {
        case "blue": return NSColor.systemBlue.withAlphaComponent(0.2)
        case "pink": return NSColor.systemPink.withAlphaComponent(0.2)
        case "yellow": return NSColor.systemYellow.withAlphaComponent(0.2)
        case "green": return NSColor.systemGreen.withAlphaComponent(0.2)
        case "goldenrod": return NSColor.orange.withAlphaComponent(0.2)
        case "buff": return NSColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 0.3)
        case "salmon": return NSColor(red: 1.0, green: 0.55, blue: 0.41, alpha: 0.3)
        case "cherry": return NSColor(red: 0.87, green: 0.19, blue: 0.39, alpha: 0.2)
        case "tan": return NSColor.brown.withAlphaComponent(0.2)
        case "gray", "grey": return NSColor.gray.withAlphaComponent(0.2)
        default: return nil
        }
    }

    /// Also handle pasteAsPlainText for Cmd+Shift+V
    override func pasteAsPlainText(_ sender: Any?) {
        // For paste as plain text, ignore screenplay data and use plain text only
        let pasteboard = NSPasteboard.general
        if let plainText = pasteboard.string(forType: .string), !plainText.isEmpty {
            let attrs = ScreenplayFormat.typingAttributes(for: currentElementType)
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

    // MARK: - Element Type

    /// Change the current element type
    func setElementType(_ type: ScriptElementType) {
        currentElementType = type

        // Set typing attributes without spacing for live editing
        let newStyle = ScreenplayFormat.paragraphStyle(for: type)
        newStyle.paragraphSpacingBefore = 0  // No extra space during live typing
        var attrs = ScreenplayFormat.typingAttributes(for: type)
        attrs[.paragraphStyle] = newStyle
        typingAttributes = attrs

        // If there's a selection, reformat the selected text
        let selection = selectedRange()
        if selection.length > 0 {
            reformatRange(selection, with: type)
        } else {
            // Reformat current paragraph
            reformatCurrentParagraph()
        }
    }

    /// Reformat a range of text with the specified element type
    private func reformatRange(_ range: NSRange, with type: ScriptElementType) {
        guard let storage = textStorage else { return }

        isProgrammaticChange = true

        let newStyle = ScreenplayFormat.paragraphStyle(for: type)
        newStyle.paragraphSpacingBefore = 0
        var attrs = ScreenplayFormat.typingAttributes(for: type)
        attrs[.paragraphStyle] = newStyle

        // Get the full paragraph range(s) that contain the selection
        let text = storage.string as NSString
        let fullRange = text.paragraphRange(for: range)

        // Apply formatting to the full paragraph range
        storage.addAttributes(attrs, range: fullRange)

        // Auto-capitalize if needed
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

    /// Get element type at a location
    func elementTypeAt(_ location: Int) -> ScriptElementType {
        guard let storage = textStorage, location < storage.length else {
            return currentElementType
        }

        let attrs = storage.attributes(at: location, effectiveRange: nil)

        // First check for custom attribute (most reliable)
        if let typeRawValue = attrs[.screenplayElementType] as? String,
           let type = ScriptElementType(rawValue: typeRawValue) {
            return type
        }

        // Fallback to style detection (less reliable for elements with same indent)
        if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
            return elementTypeFromStyle(style)
        }
        return .action
    }

    private func elementTypeFromStyle(_ style: NSParagraphStyle) -> ScriptElementType {
        let indent = style.firstLineHeadIndent

        if style.alignment == .right {
            return .transition
        }

        // Match indent to element type
        if indent >= ScreenplayFormat.characterLeftIndent - 5 {
            return .character
        } else if indent >= ScreenplayFormat.parentheticalLeftIndent - 5 {
            return .parenthetical
        } else if indent >= ScreenplayFormat.dialogueLeftIndent - 5 {
            return .dialogue
        }

        return .action
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        print("[ScreenplayTextView] keyDown: keyCode=\(event.keyCode), chars=\(event.characters ?? "nil")")

        // Cmd+number shortcuts
        if event.modifierFlags.contains(.command) {
            if let char = event.charactersIgnoringModifiers {
                for type in ScriptElementType.allCases {
                    if char == type.shortcutKey {
                        setElementType(type)
                        return
                    }
                }
            }
        }

        // Tab key
        if event.keyCode == 48 {
            handleTab(shift: event.modifierFlags.contains(.shift))
            return
        }

        // Return key
        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.contains(.shift) {
                // Shift+Enter: soft return - just line break, same element type
                handleSoftReturn()
            } else {
                // Regular Enter: element transition with spacing
                handleReturn()
            }
            return
        }

        // Backspace (51) or Delete (117)
        if event.keyCode == 51 || event.keyCode == 117 {
            isDeleting = true
            super.keyDown(with: event)
            isDeleting = false

            // After deletion, check if we've moved into a different element type
            // This handles backspacing from one element into another
            let cursorPos = selectedRange().location
            if cursorPos > 0, textStorage != nil {
                let type = elementTypeAt(cursorPos - 1)
                if type != currentElementType {
                    print("[ScreenplayTextView] Backspace moved into \(type.rawValue) element")
                    currentElementType = type
                    // Set typing attributes without spacing
                    let newStyle = ScreenplayFormat.paragraphStyle(for: type)
                    newStyle.paragraphSpacingBefore = 0
                    var attrs = ScreenplayFormat.typingAttributes(for: type)
                    attrs[.paragraphStyle] = newStyle
                    typingAttributes = attrs
                    onElementTypeChanged?(type)
                }
            } else if cursorPos == 0 {
                // At start of document, detect from position 0 if there's content
                if let storage = textStorage, storage.length > 0 {
                    let type = elementTypeAt(0)
                    if type != currentElementType {
                        currentElementType = type
                        // Set typing attributes without spacing
                        let newStyle = ScreenplayFormat.paragraphStyle(for: type)
                        newStyle.paragraphSpacingBefore = 0
                        var attrs = ScreenplayFormat.typingAttributes(for: type)
                        attrs[.paragraphStyle] = newStyle
                        typingAttributes = attrs
                        onElementTypeChanged?(type)
                    }
                }
            }

            onContentChanged?()
            return
        }

        super.keyDown(with: event)
    }

    private func handleTab(shift: Bool) {
        let cycle = currentElementType.tabCycleElements
        guard !cycle.isEmpty else {
            super.insertTab(nil)
            return
        }

        if shift {
            // Previous element type
            if let idx = cycle.firstIndex(of: currentElementType) {
                let prev = idx == 0 ? cycle.count - 1 : idx - 1
                setElementType(cycle[prev])
            } else {
                setElementType(cycle.last ?? .action)
            }
        } else {
            // Next element type
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

        // Get the CURRENT paragraph (at cursor position, not cursor-1)
        // This correctly detects if we're on an empty line
        let paraRange = text.paragraphRange(for: NSRange(location: cursor, length: 0))
        let paraText = text.substring(with: paraRange).trimmingCharacters(in: .newlines)

        // Check if current line is empty
        let isEmpty = paraText.trimmingCharacters(in: .whitespaces).isEmpty

        if isEmpty {
            // Empty line: just cycle element type, don't add another line
            let nextType = currentElementType.nextElementOnDoubleEnter
            isProgrammaticChange = true
            currentElementType = nextType

            // Create style without spacing for live editing
            let newStyle = ScreenplayFormat.paragraphStyle(for: nextType)
            newStyle.paragraphSpacingBefore = 0  // No extra space during live typing
            var newAttrs = ScreenplayFormat.typingAttributes(for: nextType)
            newAttrs[.paragraphStyle] = newStyle
            typingAttributes = newAttrs

            // Reformat the current empty paragraph with new style
            if paraRange.length > 0 {
                storage.addAttributes(newAttrs, range: paraRange)
            }
            isProgrammaticChange = false
            onElementTypeChanged?(nextType)
        } else {
            // Line has content: insert newline and transition to next element
            let nextType = currentElementType.nextElementOnEnter

            isProgrammaticChange = true

            // Create paragraph style for new element with no extra spacing
            let newStyle = ScreenplayFormat.paragraphStyle(for: nextType)
            newStyle.paragraphSpacingBefore = 0

            // Set typing attributes BEFORE inserting newlines
            var newAttrs = ScreenplayFormat.typingAttributes(for: nextType)
            newAttrs[.paragraphStyle] = newStyle
            typingAttributes = newAttrs

            // Insert two newlines: one to end current line, one for blank line between elements
            let newlineAttr = NSAttributedString(string: "\n\n", attributes: newAttrs)
            let insertLocation = selectedRange().location
            storage.insert(newlineAttr, at: insertLocation)
            setSelectedRange(NSRange(location: insertLocation + 2, length: 0))

            // Apply new element type
            currentElementType = nextType

            isProgrammaticChange = false
        }

        onContentChanged?()
    }

    /// Shift+Enter: Insert a simple line break without changing element type
    private func handleSoftReturn() {
        guard let storage = textStorage else {
            super.insertNewline(nil)
            return
        }

        isProgrammaticChange = true

        // Insert single newline with current element's attributes (no element change)
        let newlineAttr = NSAttributedString(string: "\n", attributes: typingAttributes)
        let insertLocation = selectedRange().location
        storage.insert(newlineAttr, at: insertLocation)
        setSelectedRange(NSRange(location: insertLocation + 1, length: 0))

        isProgrammaticChange = false
        onContentChanged?()
    }

    // MARK: - Text Input

    override func insertText(_ string: Any, replacementRange: NSRange) {
        isTyping = true
        defer { isTyping = false }

        // Convert input to string for processing
        var textToInsert: String
        if let str = string as? String {
            textToInsert = str
        } else if let attrStr = string as? NSAttributedString {
            textToInsert = attrStr.string
        } else {
            textToInsert = String(describing: string)
        }

        print("[ScreenplayTextView] insertText: \(textToInsert), range: \(replacementRange), elementType: \(currentElementType.rawValue)")

        // Auto-capitalize BEFORE inserting for uppercase elements
        if currentElementType.isAllCaps {
            textToInsert = textToInsert.uppercased()
        }

        // Insert with proper attributes (use typingAttributes which has no spacing)
        let attrString = NSAttributedString(string: textToInsert, attributes: typingAttributes)
        super.insertText(attrString, replacementRange: replacementRange)

        print("[ScreenplayTextView] insertText complete, string length now: \(self.string.count)")

        guard !isProgrammaticChange else { return }

        onContentChanged?()
    }

    private func autoDetectElementType() {
        guard let storage = textStorage else { return }

        let cursor = selectedRange().location
        let text = storage.string as NSString
        let paraRange = text.paragraphRange(for: NSRange(location: max(0, cursor - 1), length: 0))
        let paraText = text.substring(with: paraRange)

        // Only auto-detect for short text at start of typing
        guard paraText.count < 15 else { return }

        if let detected = ScriptElementType.detect(from: paraText), detected != currentElementType {
            isProgrammaticChange = true
            currentElementType = detected
            typingAttributes = ScreenplayFormat.typingAttributes(for: detected)
            // Reformat paragraph
            storage.addAttributes(ScreenplayFormat.typingAttributes(for: detected), range: paraRange)
            isProgrammaticChange = false
        }
    }

    // MARK: - Formatting

    private func reformatCurrentParagraph() {
        guard let storage = textStorage else { return }

        let cursor = selectedRange().location
        guard cursor > 0 else { return }

        let text = storage.string as NSString
        let paraRange = text.paragraphRange(for: NSRange(location: cursor - 1, length: 0))

        isProgrammaticChange = true

        // Apply formatting without spacing for live editing
        let newStyle = ScreenplayFormat.paragraphStyle(for: currentElementType)
        newStyle.paragraphSpacingBefore = 0  // No extra space during live typing
        var attrs = ScreenplayFormat.typingAttributes(for: currentElementType)
        attrs[.paragraphStyle] = newStyle
        storage.addAttributes(attrs, range: paraRange)

        // Auto-capitalize if needed
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

    // MARK: - Element Extraction

    /// Extract all elements from the text view content
    func extractElements() -> [ScriptElement] {
        guard let storage = textStorage else { return [] }

        var elements: [ScriptElement] = []
        let fullText = storage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return [] }

        // Enumerate paragraphs and extract element type from attributes
        var currentLocation = 0
        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))

            // Get the text for this paragraph
            let paraText = fullText.substring(with: paraRange).trimmingCharacters(in: .newlines)

            // Skip empty paragraphs
            if !paraText.trimmingCharacters(in: .whitespaces).isEmpty {
                // Get element type from custom attribute (preferred) or fallback to style detection
                let elementType: ScriptElementType
                if paraRange.location < fullLength {
                    let attrs = storage.attributes(at: paraRange.location, effectiveRange: nil)
                    // First try to get from custom attribute
                    if let typeRawValue = attrs[.screenplayElementType] as? String,
                       let type = ScriptElementType(rawValue: typeRawValue) {
                        elementType = type
                    } else if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
                        // Fallback to style detection
                        elementType = elementTypeFromStyle(style)
                    } else {
                        elementType = .action
                    }
                } else {
                    elementType = .action
                }

                // Create element
                let element = ScriptElement(
                    type: elementType,
                    text: paraText
                )
                elements.append(element)
            }

            // Move to next paragraph
            currentLocation = paraRange.location + paraRange.length
        }

        return elements
    }

    // MARK: - Selection

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)

        // Don't detect element type while actively typing or deleting - it would override the current type
        if isTyping || isProgrammaticChange || isDeleting {
            print("[ScreenplayTextView] setSelectedRange SKIPPED - isTyping:\(isTyping) isProgrammatic:\(isProgrammaticChange) isDeleting:\(isDeleting)")
            return
        }

        // Update current element type based on cursor position (only when clicking/navigating)
        if !stillSelectingFlag && charRange.length == 0 && charRange.location > 0 {
            let type = elementTypeAt(charRange.location - 1)
            print("[ScreenplayTextView] setSelectedRange - detected type: \(type.rawValue), current: \(currentElementType.rawValue)")
            if type != currentElementType {
                print("[ScreenplayTextView] setSelectedRange CHANGING element type from \(currentElementType.rawValue) to \(type.rawValue)")
                currentElementType = type
                // Set typing attributes without spacing
                let newStyle = ScreenplayFormat.paragraphStyle(for: type)
                newStyle.paragraphSpacingBefore = 0
                var attrs = ScreenplayFormat.typingAttributes(for: type)
                attrs[.paragraphStyle] = newStyle
                typingAttributes = attrs
            }
        }
    }

    // MARK: - Scene Number Positioning

    /// Get Y positions for all scene headings based on actual layout
    /// Returns array of (sceneNumber, yPosition, height) tuples
    func getSceneHeadingPositions() -> [(sceneNumber: String, y: CGFloat, height: CGFloat)] {
        guard let storage = textStorage,
              let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return []
        }

        var positions: [(sceneNumber: String, y: CGFloat, height: CGFloat)] = []
        let fullText = storage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return positions }

        var currentLocation = 0
        var sceneIndex = 1

        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            let paraText = fullText.substring(with: paraRange).trimmingCharacters(in: .newlines)

            // Check if this paragraph is a scene heading
            if !paraText.trimmingCharacters(in: .whitespaces).isEmpty && paraRange.location < fullLength {
                let attrs = storage.attributes(at: paraRange.location, effectiveRange: nil)

                var isSceneHeading = false
                if let typeRawValue = attrs[.screenplayElementType] as? String,
                   typeRawValue == ScriptElementType.sceneHeading.rawValue {
                    isSceneHeading = true
                } else if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
                    isSceneHeading = elementTypeFromStyle(style) == .sceneHeading
                }

                if isSceneHeading {
                    // Get the actual Y position and height from the layout manager
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: paraRange, actualCharacterRange: nil)
                    let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                    let sceneNumber = "\(sceneIndex)"
                    positions.append((sceneNumber: sceneNumber, y: boundingRect.origin.y, height: boundingRect.height))
                    sceneIndex += 1
                }
            }

            currentLocation = paraRange.location + paraRange.length
        }

        return positions
    }
}

// MARK: - SwiftUI Wrapper

struct ScreenplayTextViewWrapper: NSViewRepresentable {
    @Binding var document: ScreenplayDocument?
    @Binding var currentElementType: ScriptElementType
    @Binding var sceneHeadingPositions: [(sceneNumber: String, y: CGFloat, height: CGFloat)]
    var onDocumentChanged: ((ScreenplayDocument) -> Void)?

    func makeNSView(context: Context) -> ScreenplayTextView {
        print("[ScreenplayTextViewWrapper] makeNSView called")

        // Text container with fixed width
        let textContainer = NSTextContainer(size: NSSize(
            width: ScreenplayFormat.contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 0

        print("[ScreenplayTextViewWrapper] textContainer created, width: \(ScreenplayFormat.contentWidth)")

        // Layout manager
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        // Text storage
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        // Text view - no wrapping scroll view, let SwiftUI handle scrolling
        let textView = ScreenplayTextView(frame: NSRect(x: 0, y: 0, width: ScreenplayFormat.contentWidth, height: ScreenplayFormat.contentHeight), textContainer: textContainer)
        textView.minSize = NSSize(width: ScreenplayFormat.contentWidth, height: ScreenplayFormat.contentHeight)
        textView.maxSize = NSSize(width: ScreenplayFormat.contentWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.height]
        textView.drawsBackground = false

        // Ensure editable
        textView.isEditable = true
        textView.isSelectable = true

        print("[ScreenplayTextViewWrapper] textView created - isEditable: \(textView.isEditable), isSelectable: \(textView.isSelectable)")
        print("[ScreenplayTextViewWrapper] textView frame: \(textView.frame)")

        // Callbacks
        textView.onElementTypeChanged = { type in
            DispatchQueue.main.async {
                self.currentElementType = type
            }
        }

        // Content changed callback - extract elements and update document
        textView.onContentChanged = { [weak textView] in
            guard let textView = textView,
                  var doc = self.document else { return }

            // Extract elements from the text view
            let elements = textView.extractElements()
            doc.elements = elements

            // Get scene heading positions from layout
            let positions = textView.getSceneHeadingPositions()

            // Notify parent of document change
            DispatchQueue.main.async {
                self.sceneHeadingPositions = positions
                self.onDocumentChanged?(doc)
            }
        }

        context.coordinator.textView = textView
        context.coordinator.loadedDocumentId = nil

        // Load document if available
        if let doc = document {
            loadDocument(doc, into: textView)
            context.coordinator.loadedDocumentId = doc.id
            // Update scene positions after loading
            DispatchQueue.main.async {
                self.sceneHeadingPositions = textView.getSceneHeadingPositions()
            }
        } else {
            // Initialize with empty content for new script
            textView.string = ""
            textView.setElementType(.sceneHeading)
        }

        print("[ScreenplayTextViewWrapper] makeNSView complete")
        return textView
    }

    func updateNSView(_ nsView: ScreenplayTextView, context: Context) {
        let textView = nsView

        // Check if document changed (different document loaded)
        if let doc = document {
            if context.coordinator.loadedDocumentId != doc.id {
                // Different document - reload content
                loadDocument(doc, into: textView)
                context.coordinator.loadedDocumentId = doc.id
                // Update scene positions after loading
                DispatchQueue.main.async {
                    self.sceneHeadingPositions = textView.getSceneHeadingPositions()
                }
            }
        }

        // Update element type if changed externally
        if textView.currentElementType != currentElementType {
            print("[ScreenplayTextViewWrapper] updateNSView CHANGING element from \(textView.currentElementType.rawValue) to \(currentElementType.rawValue)")
            textView.setElementType(currentElementType)
        }
    }

    private func loadDocument(_ document: ScreenplayDocument, into textView: ScreenplayTextView) {
        print("[ScreenplayTextViewWrapper] Loading document: \(document.title) with \(document.elements.count) elements")

        guard let storage = textView.textStorage else { return }

        // Build attributed string from document elements
        let attributedString = NSMutableAttributedString()
        let font = ScreenplayFormat.font()

        for (index, element) in document.elements.enumerated() {
            let paragraphStyle = ScreenplayFormat.paragraphStyle(for: element.type)

            var elementText = element.displayText

            // Add newline if not last element
            if index < document.elements.count - 1 {
                elementText += "\n"
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle,
                .screenplayElementType: element.type.rawValue  // Store element type for extraction
            ]

            let attrString = NSAttributedString(string: elementText, attributes: attributes)
            attributedString.append(attrString)
        }

        // Replace text storage content
        storage.beginEditing()
        storage.setAttributedString(attributedString)
        storage.endEditing()

        // Set element type based on first element or default to scene heading
        if let firstElement = document.elements.first {
            textView.setElementType(firstElement.type)
        } else {
            textView.setElementType(.sceneHeading)
        }

        print("[ScreenplayTextViewWrapper] Document loaded successfully")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var textView: ScreenplayTextView?
        var loadedDocumentId: UUID?
    }
}

#endif

// MARK: - iOS Implementation
#if os(iOS)
import UIKit

// MARK: - iOS Custom Attribute Keys (shared with macOS)

extension NSAttributedString.Key {
    // Note: These are defined in the macOS section when compiling for macOS
    // For iOS-only compilation, we need these definitions
    #if !os(macOS)
    static let screenplayElementType = NSAttributedString.Key("screenplayElementType")
    static let screenplayRevisionColor = NSAttributedString.Key("screenplayRevisionColor")
    static let screenplayRevisionID = NSAttributedString.Key("screenplayRevisionID")
    static let screenplayElementID = NSAttributedString.Key("screenplayElementID")
    static let screenplayOriginalText = NSAttributedString.Key("screenplayOriginalText")
    static let screenplayIsNewInRevision = NSAttributedString.Key("screenplayIsNewInRevision")
    static let screenplaySceneNumber = NSAttributedString.Key("screenplaySceneNumber")
    static let screenplayIsOmitted = NSAttributedString.Key("screenplayIsOmitted")
    #endif
}

// MARK: - iOS Screenplay Text View

final class ScreenplayTextViewiOS: UITextView {

    /// Current element type at cursor position
    private(set) var currentElementType: ScriptElementType = .action {
        didSet {
            if oldValue != currentElementType {
                onElementTypeChanged?(currentElementType)
            }
        }
    }

    /// Callbacks
    var onElementTypeChanged: ((ScriptElementType) -> Void)?
    var onContentChanged: (() -> Void)?

    /// Track programmatic changes
    private var isProgrammaticChange = false

    // MARK: - Setup

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Editor settings
        isEditable = true
        isSelectable = true
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .yes
        smartQuotesType = .no
        smartDashesType = .no

        // Appearance
        font = ScreenplayFormatiOS.font()
        textColor = .label
        backgroundColor = .systemBackground
        tintColor = .label

        // Text container
        textContainer.lineFragmentPadding = 0

        // Initial attributes
        let initialAttrs = ScreenplayFormatiOS.typingAttributes(for: .action)
        typingAttributes = initialAttrs

        // Add text change observer
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

    // MARK: - Element Type

    /// Change the current element type
    func setElementType(_ type: ScriptElementType) {
        currentElementType = type

        // Set typing attributes
        let attrs = ScreenplayFormatiOS.typingAttributes(for: type)
        typingAttributes = attrs

        // If there's a selection, reformat the selected text
        if selectedRange.length > 0 {
            reformatRange(selectedRange, with: type)
        } else {
            reformatCurrentParagraph()
        }
    }

    /// Reformat a range of text with the specified element type
    private func reformatRange(_ range: NSRange, with type: ScriptElementType) {
        let storage = textStorage

        isProgrammaticChange = true

        let attrs = ScreenplayFormatiOS.typingAttributes(for: type)

        // Get the full paragraph range(s) that contain the selection
        let text = storage.string as NSString
        let fullRange = text.paragraphRange(for: range)

        // Apply formatting to the full paragraph range
        storage.addAttributes(attrs, range: fullRange)

        // Auto-capitalize if needed
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

    /// Get element type at a location
    func elementTypeAt(_ location: Int) -> ScriptElementType {
        let storage = textStorage
        guard location < storage.length else {
            return currentElementType
        }

        let attrs = storage.attributes(at: location, effectiveRange: nil)

        // First check for custom attribute
        if let typeRawValue = attrs[.screenplayElementType] as? String,
           let type = ScriptElementType(rawValue: typeRawValue) {
            return type
        }

        // Fallback to style detection
        if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
            return elementTypeFromStyle(style)
        }
        return .action
    }

    private func elementTypeFromStyle(_ style: NSParagraphStyle) -> ScriptElementType {
        let indent = style.firstLineHeadIndent

        if style.alignment == .right {
            return .transition
        }

        // Match indent to element type
        if indent >= ScreenplayFormatiOS.characterLeftIndent - 5 {
            return .character
        } else if indent >= ScreenplayFormatiOS.parentheticalLeftIndent - 5 {
            return .parenthetical
        } else if indent >= ScreenplayFormatiOS.dialogueLeftIndent - 5 {
            return .dialogue
        }

        return .action
    }

    // MARK: - Formatting

    private func reformatCurrentParagraph() {
        let storage = textStorage

        let cursor = selectedRange.location
        guard cursor > 0 else { return }

        let text = storage.string as NSString
        let paraRange = text.paragraphRange(for: NSRange(location: cursor - 1, length: 0))

        isProgrammaticChange = true

        let attrs = ScreenplayFormatiOS.typingAttributes(for: currentElementType)
        storage.addAttributes(attrs, range: paraRange)

        // Auto-capitalize if needed
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

    // MARK: - Element Extraction

    /// Extract all elements from the text view content
    func extractElements() -> [ScriptElement] {
        let storage = textStorage

        var elements: [ScriptElement] = []
        let fullText = storage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return [] }

        var currentLocation = 0
        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            let paraText = fullText.substring(with: paraRange).trimmingCharacters(in: .newlines)

            if !paraText.trimmingCharacters(in: .whitespaces).isEmpty {
                let elementType: ScriptElementType
                if paraRange.location < fullLength {
                    let attrs = storage.attributes(at: paraRange.location, effectiveRange: nil)
                    if let typeRawValue = attrs[.screenplayElementType] as? String,
                       let type = ScriptElementType(rawValue: typeRawValue) {
                        elementType = type
                    } else if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
                        elementType = elementTypeFromStyle(style)
                    } else {
                        elementType = .action
                    }
                } else {
                    elementType = .action
                }

                let element = ScriptElement(type: elementType, text: paraText)
                elements.append(element)
            }

            currentLocation = paraRange.location + paraRange.length
        }

        return elements
    }

    // MARK: - Scene Number Positioning

    func getSceneHeadingPositions() -> [(sceneNumber: String, y: CGFloat, height: CGFloat)] {
        let storage = textStorage
        let lm = layoutManager
        let tc = textContainer

        var positions: [(sceneNumber: String, y: CGFloat, height: CGFloat)] = []
        let fullText = storage.string as NSString
        let fullLength = fullText.length

        guard fullLength > 0 else { return positions }

        var currentLocation = 0
        var sceneIndex = 1

        while currentLocation < fullLength {
            let paraRange = fullText.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            let paraText = fullText.substring(with: paraRange).trimmingCharacters(in: .newlines)

            if !paraText.trimmingCharacters(in: .whitespaces).isEmpty && paraRange.location < fullLength {
                let attrs = storage.attributes(at: paraRange.location, effectiveRange: nil)

                var isSceneHeading = false
                if let typeRawValue = attrs[.screenplayElementType] as? String,
                   typeRawValue == ScriptElementType.sceneHeading.rawValue {
                    isSceneHeading = true
                } else if let style = attrs[.paragraphStyle] as? NSParagraphStyle {
                    isSceneHeading = elementTypeFromStyle(style) == .sceneHeading
                }

                if isSceneHeading {
                    let glyphRange = lm.glyphRange(forCharacterRange: paraRange, actualCharacterRange: nil)
                    let boundingRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)

                    let sceneNumber = "\(sceneIndex)"
                    positions.append((sceneNumber: sceneNumber, y: boundingRect.origin.y, height: boundingRect.height))
                    sceneIndex += 1
                }
            }

            currentLocation = paraRange.location + paraRange.length
        }

        return positions
    }

    // MARK: - Revision Colors

    private func revisionBackgroundColor(for colorName: String) -> UIColor? {
        switch colorName.lowercased() {
        case "blue": return UIColor.systemBlue.withAlphaComponent(0.2)
        case "pink": return UIColor.systemPink.withAlphaComponent(0.2)
        case "yellow": return UIColor.systemYellow.withAlphaComponent(0.2)
        case "green": return UIColor.systemGreen.withAlphaComponent(0.2)
        case "goldenrod": return UIColor.orange.withAlphaComponent(0.2)
        case "buff": return UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 0.3)
        case "salmon": return UIColor(red: 1.0, green: 0.55, blue: 0.41, alpha: 0.3)
        case "cherry": return UIColor(red: 0.87, green: 0.19, blue: 0.39, alpha: 0.2)
        case "tan": return UIColor.brown.withAlphaComponent(0.2)
        case "gray", "grey": return UIColor.gray.withAlphaComponent(0.2)
        default: return nil
        }
    }
}

// MARK: - iOS Screenplay Format Helper

struct ScreenplayFormatiOS {
    // Standard screenplay dimensions at 72 DPI
    static let pageWidth: CGFloat = 612  // 8.5 inches
    static let pageHeight: CGFloat = 792 // 11 inches

    // Margins
    static let leftMargin: CGFloat = 108  // 1.5 inches
    static let rightMargin: CGFloat = 72  // 1 inch
    static let topMargin: CGFloat = 72    // 1 inch
    static let bottomMargin: CGFloat = 72 // 1 inch

    // Margin aliases for compatibility
    static let marginLeft: CGFloat = leftMargin
    static let marginRight: CGFloat = rightMargin
    static let marginTop: CGFloat = topMargin
    static let marginBottom: CGFloat = bottomMargin

    // Content dimensions
    static let contentWidth: CGFloat = pageWidth - leftMargin - rightMargin  // 432pt
    static let contentHeight: CGFloat = pageHeight - topMargin - bottomMargin // 648pt

    // Element indents (relative to left margin)
    static let sceneHeadingLeftIndent: CGFloat = 0
    static let actionLeftIndent: CGFloat = 0
    static let dialogueLeftIndent: CGFloat = 72   // 1 inch from content edge
    static let parentheticalLeftIndent: CGFloat = 108 // 1.5 inches
    static let characterLeftIndent: CGFloat = 144     // 2 inches
    static let transitionRightIndent: CGFloat = 0

    // Right edge limits
    static let dialogueRightIndent: CGFloat = 72
    static let parentheticalRightIndent: CGFloat = 108

    // Spacing
    static let transitionSpaceBefore: CGFloat = 24
    static let transitionSpaceAfter: CGFloat = 12

    /// Get the standard screenplay font
    static func font() -> UIFont {
        return UIFont(name: "Courier", size: 12) ?? UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    /// Get paragraph style for an element type
    static func paragraphStyle(for type: ScriptElementType) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0
        style.paragraphSpacing = 12 // Standard screenplay line spacing

        switch type {
        case .sceneHeading:
            style.firstLineHeadIndent = actionLeftIndent
            style.headIndent = actionLeftIndent
            style.alignment = .left

        case .action:
            style.firstLineHeadIndent = actionLeftIndent
            style.headIndent = actionLeftIndent
            style.alignment = .left

        case .character:
            style.firstLineHeadIndent = characterLeftIndent
            style.headIndent = characterLeftIndent
            style.alignment = .left

        case .dialogue:
            style.firstLineHeadIndent = dialogueLeftIndent
            style.headIndent = dialogueLeftIndent
            style.tailIndent = -dialogueRightIndent
            style.alignment = .left

        case .parenthetical:
            style.firstLineHeadIndent = parentheticalLeftIndent
            style.headIndent = parentheticalLeftIndent
            style.tailIndent = -parentheticalRightIndent
            style.alignment = .left

        case .transition:
            style.alignment = .right
            style.tailIndent = 0

        case .shot:
            style.firstLineHeadIndent = actionLeftIndent
            style.headIndent = actionLeftIndent
            style.alignment = .left

        case .general, .titlePage:
            style.firstLineHeadIndent = actionLeftIndent
            style.headIndent = actionLeftIndent
            style.alignment = .left
        }

        return style
    }

    /// Get typing attributes for an element type
    static func typingAttributes(for type: ScriptElementType) -> [NSAttributedString.Key: Any] {
        return [
            .font: font(),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle(for: type),
            .screenplayElementType: type.rawValue
        ]
    }
}

// MARK: - iOS SwiftUI Wrapper

struct ScreenplayTextViewWrapperiOS: UIViewRepresentable {
    @Binding var document: ScreenplayDocument?
    @Binding var currentElementType: ScriptElementType
    @Binding var sceneHeadingPositions: [(sceneNumber: String, y: CGFloat, height: CGFloat)]
    var onDocumentChanged: ((ScreenplayDocument) -> Void)?

    func makeUIView(context: Context) -> ScreenplayTextViewiOS {
        // Text container with fixed width
        let textContainer = NSTextContainer(size: CGSize(
            width: ScreenplayFormatiOS.contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 0

        // Layout manager
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        // Text storage
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        // Text view
        let textView = ScreenplayTextViewiOS(frame: CGRect(
            x: 0, y: 0,
            width: ScreenplayFormatiOS.contentWidth,
            height: ScreenplayFormatiOS.contentHeight
        ), textContainer: textContainer)

        textView.isScrollEnabled = false // Let SwiftUI handle scrolling
        textView.backgroundColor = .clear

        // Callbacks
        textView.onElementTypeChanged = { type in
            DispatchQueue.main.async {
                self.currentElementType = type
            }
        }

        textView.onContentChanged = { [weak textView] in
            guard let textView = textView,
                  var doc = self.document else { return }

            let elements = textView.extractElements()
            doc.elements = elements

            let positions = textView.getSceneHeadingPositions()

            DispatchQueue.main.async {
                self.sceneHeadingPositions = positions
                self.onDocumentChanged?(doc)
            }
        }

        context.coordinator.textView = textView
        context.coordinator.loadedDocumentId = nil

        // Load document if available
        if let doc = document {
            loadDocument(doc, into: textView)
            context.coordinator.loadedDocumentId = doc.id
            DispatchQueue.main.async {
                self.sceneHeadingPositions = textView.getSceneHeadingPositions()
            }
        } else {
            textView.text = ""
            textView.setElementType(.sceneHeading)
        }

        return textView
    }

    func updateUIView(_ uiView: ScreenplayTextViewiOS, context: Context) {
        let textView = uiView

        if let doc = document {
            if context.coordinator.loadedDocumentId != doc.id {
                loadDocument(doc, into: textView)
                context.coordinator.loadedDocumentId = doc.id
                DispatchQueue.main.async {
                    self.sceneHeadingPositions = textView.getSceneHeadingPositions()
                }
            }
        }

        if textView.currentElementType != currentElementType {
            textView.setElementType(currentElementType)
        }
    }

    private func loadDocument(_ document: ScreenplayDocument, into textView: ScreenplayTextViewiOS) {
        let storage = textView.textStorage

        let attributedString = NSMutableAttributedString()
        let font = ScreenplayFormatiOS.font()

        for (index, element) in document.elements.enumerated() {
            let paragraphStyle = ScreenplayFormatiOS.paragraphStyle(for: element.type)

            var elementText = element.displayText

            if index < document.elements.count - 1 {
                elementText += "\n"
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle,
                .screenplayElementType: element.type.rawValue
            ]

            let attrString = NSAttributedString(string: elementText, attributes: attributes)
            attributedString.append(attrString)
        }

        storage.beginEditing()
        storage.setAttributedString(attributedString)
        storage.endEditing()

        if let firstElement = document.elements.first {
            textView.setElementType(firstElement.type)
        } else {
            textView.setElementType(.sceneHeading)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var textView: ScreenplayTextViewiOS?
        var loadedDocumentId: UUID?
    }
}

#endif
