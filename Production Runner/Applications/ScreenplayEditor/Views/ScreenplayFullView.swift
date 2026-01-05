//
//  ScreenplayFullView.swift
//  Production Runner
//
//  Renders a complete screenplay document with industry-standard formatting.
//  Displays continuously with page breaks occurring naturally based on content.
//  Based on Final Draft formatting specifications.
//

import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Screenplay Full View

#if os(macOS)
/// A view that renders a complete screenplay with proper formatting and natural page breaks
struct ScreenplayFullView: View {
    let document: ScreenplayDocument
    let showSceneNumbers: Bool
    let showRevisionMarks: Bool

    @State private var zoomLevel: CGFloat = 1.2

    private let pageWidth: CGFloat = 612   // 8.5 inches
    private let pageHeight: CGFloat = 792  // 11 inches
    private let contentWidth: CGFloat = 432  // 6 inches (8.5 - 1.5 - 1)
    private let contentHeight: CGFloat = 648 // 9 inches (11 - 1 - 1)

    init(document: ScreenplayDocument, showSceneNumbers: Bool = true, showRevisionMarks: Bool = false) {
        self.document = document
        self.showSceneNumbers = showSceneNumbers
        self.showRevisionMarks = showRevisionMarks
    }

    var body: some View {
        VStack(spacing: 0) {
            // Zoom controls
            HStack {
                Spacer()

                Button(action: { zoomLevel = max(0.5, zoomLevel - 0.1) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Zoom Out")

                Text("\(Int(zoomLevel * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 45)

                Button(action: { zoomLevel = min(2.0, zoomLevel + 0.1) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Zoom In")

                Button(action: { zoomLevel = 1.0 }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Reset Zoom")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Script pages
            ScreenplayFullPageView(
                document: document,
                showSceneNumbers: showSceneNumbers,
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                pageWidth: pageWidth,
                pageHeight: pageHeight
            )
            .scaleEffect(zoomLevel, anchor: .top)
        }
        .background(Color(white: 0.9))
    }
}

// MARK: - Screenplay Full Page View (NSViewRepresentable)

struct ScreenplayFullPageView: NSViewRepresentable {
    let document: ScreenplayDocument
    let showSceneNumbers: Bool
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let pageWidth: CGFloat
    let pageHeight: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CenteringScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        updateContent(in: scrollView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        updateContent(in: nsView)
    }

    private func updateContent(in scrollView: NSScrollView) {
        // Remove old content
        if let oldContainer = scrollView.documentView {
            oldContainer.subviews.forEach { $0.removeFromSuperview() }
        }

        let containerView = FlippedView()
        containerView.wantsLayer = true

        // Build attributed string from document
        let attributedText = buildAttributedString(from: document)

        // Paginate the content
        let pages = paginate(
            attributedText: attributedText,
            contentSize: CGSize(width: contentWidth, height: contentHeight)
        )

        print("[ScreenplayFullView] Rendering \(pages.count) pages from \(document.elements.count) elements")

        var yOffset: CGFloat = 20 // Top padding
        for (index, pageContent) in pages.enumerated() {
            let pageView = createPageView(with: pageContent, pageNumber: index + 1)
            pageView.frame = CGRect(x: 0, y: yOffset, width: pageWidth, height: pageHeight)
            containerView.addSubview(pageView)
            yOffset += pageHeight + 20
        }

        let totalHeight = max(yOffset + 20, pageHeight)
        containerView.frame = CGRect(x: 0, y: 0, width: pageWidth, height: totalHeight)
        scrollView.documentView = containerView
    }

    // MARK: - Build Attributed String

    private func buildAttributedString(from document: ScreenplayDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = ScreenplayFormat.font()

        var previousType: ScriptElementType? = nil

        for (index, element) in document.elements.enumerated() {
            // Get context-aware paragraph style based on previous element
            let paragraphStyle = contextAwareParagraphStyle(
                for: element.type,
                previousType: previousType,
                isFirstElement: index == 0
            )

            // Build text for this element
            var elementText = element.displayText

            // Add newline if not last element
            if index < document.elements.count - 1 {
                elementText += "\n"
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle
            ]

            let attrString = NSAttributedString(string: elementText, attributes: attributes)
            result.append(attrString)

            previousType = element.type
        }

        return result
    }

    /// Creates paragraph style with context-aware spacing matching Final Draft exactly
    private func contextAwareParagraphStyle(
        for type: ScriptElementType,
        previousType: ScriptElementType?,
        isFirstElement: Bool
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0

        // Final Draft spacing rules:
        // - Scene Heading: 2 blank lines before (except at start)
        // - Action: 1 blank line before ONLY when following dialogue/parenthetical
        // - Character: 1 blank line before
        // - Dialogue: No space before (follows character/parenthetical)
        // - Parenthetical: No space before (follows character/dialogue)
        // - Transition: 2 blank lines before

        switch type {
        case .sceneHeading:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormat.sceneHeadingLeftIndent
            style.headIndent = ScreenplayFormat.sceneHeadingLeftIndent
            style.tailIndent = 0
            // 2 blank lines before scene headings (except first element)
            style.paragraphSpacingBefore = isFirstElement ? 0 : 24
            style.paragraphSpacing = 0

        case .action, .general:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormat.actionLeftIndent
            style.headIndent = ScreenplayFormat.actionLeftIndent
            style.tailIndent = 0
            // Action paragraphs in Final Draft:
            // - 1 blank line between ALL action paragraphs (including after scene heading)
            // - 1 blank line after dialogue/parenthetical before action
            if isFirstElement {
                style.paragraphSpacingBefore = 0
            } else {
                // All action paragraphs get 1 blank line before them
                style.paragraphSpacingBefore = 12
            }
            style.paragraphSpacing = 0

        case .character:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormat.characterLeftIndent
            style.headIndent = ScreenplayFormat.characterLeftIndent
            style.tailIndent = 0
            // 1 blank line before character
            style.paragraphSpacingBefore = isFirstElement ? 0 : 12
            style.paragraphSpacing = 0

        case .parenthetical:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormat.parentheticalLeftIndent
            style.headIndent = ScreenplayFormat.parentheticalLeftIndent
            style.tailIndent = -ScreenplayFormat.parentheticalRightIndent
            // No space before parenthetical
            style.paragraphSpacingBefore = 0
            style.paragraphSpacing = 0

        case .dialogue:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormat.dialogueLeftIndent
            style.headIndent = ScreenplayFormat.dialogueLeftIndent
            style.tailIndent = -ScreenplayFormat.dialogueRightIndent
            // No space before dialogue
            style.paragraphSpacingBefore = 0
            style.paragraphSpacing = 0

        case .transition:
            style.alignment = .left  // FADE IN: is left-aligned in Final Draft
            style.firstLineHeadIndent = ScreenplayFormat.actionLeftIndent
            style.headIndent = ScreenplayFormat.actionLeftIndent
            style.tailIndent = 0
            // Transitions: 2 blank lines before (except at start of document)
            // FADE IN: at start gets no space before
            // No space after - scene heading provides its own 2 blank lines before
            style.paragraphSpacingBefore = isFirstElement ? 0 : ScreenplayFormat.transitionSpaceBefore
            style.paragraphSpacing = ScreenplayFormat.transitionSpaceAfter

        case .shot:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormat.sceneHeadingLeftIndent
            style.headIndent = ScreenplayFormat.sceneHeadingLeftIndent
            style.tailIndent = 0
            // 2 blank lines before shot (same as scene heading)
            style.paragraphSpacingBefore = isFirstElement ? 0 : 24
            style.paragraphSpacing = 0

        case .titlePage:
            style.alignment = .center
            style.firstLineHeadIndent = 0
            style.headIndent = 0
            style.tailIndent = 0
            style.paragraphSpacingBefore = 12
            style.paragraphSpacing = 0
        }

        return style
    }

    // MARK: - Pagination

    private func paginate(attributedText: NSAttributedString, contentSize: CGSize) -> [NSAttributedString] {
        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var pages: [NSAttributedString] = []
        let maxPages = 1000 // Safety limit to prevent infinite loops

        while pages.count < maxPages {
            let container = NSTextContainer(size: contentSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)

            layoutManager.ensureLayout(for: container)
            let glyphRange = layoutManager.glyphRange(for: container)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            if charRange.length == 0 {
                layoutManager.removeTextContainer(at: layoutManager.textContainers.count - 1)
                break
            }

            let pageContent = storage.attributedSubstring(from: charRange)
            pages.append(pageContent)

            let endLocation = charRange.location + charRange.length
            if endLocation >= storage.length {
                break
            }
        }

        if pages.count >= maxPages {
            print("[ScreenplayFullView] WARNING: Hit max page limit (\(maxPages)), possible layout issue")
        }

        return pages.isEmpty ? [attributedText] : pages
    }

    // MARK: - Create Page View

    private func createPageView(with text: NSAttributedString, pageNumber: Int) -> NSView {
        let pageView = NSView()
        pageView.wantsLayer = true
        pageView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        pageView.layer?.cornerRadius = 6
        pageView.layer?.shadowColor = NSColor.shadowColor.cgColor
        pageView.layer?.shadowOpacity = 0.12
        pageView.layer?.shadowRadius = 8
        pageView.layer?.shadowOffset = CGSize(width: 0, height: 4)

        // Text view for content
        let textView = NSTextView(frame: CGRect(
            x: ScreenplayFormat.marginLeft,
            y: ScreenplayFormat.marginTop,
            width: contentWidth,
            height: contentHeight
        ))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize.zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textStorage?.setAttributedString(text)
        pageView.addSubview(textView)

        // Page number at top right
        let pageNumberLabel = NSTextField(labelWithString: "\(pageNumber).")
        pageNumberLabel.font = NSFont(name: "Courier", size: 12)
        pageNumberLabel.textColor = .textColor
        pageNumberLabel.alignment = .right
        pageNumberLabel.frame = CGRect(
            x: pageWidth - ScreenplayFormat.marginRight - 40,
            y: pageHeight - 50,
            width: 40,
            height: 20
        )
        pageView.addSubview(pageNumberLabel)

        // Add scene numbers in margins if enabled
        if showSceneNumbers {
            addSceneNumbersToPage(pageView, from: text, pageNumber: pageNumber)
        }

        return pageView
    }

    private func addSceneNumbersToPage(_ pageView: NSView, from text: NSAttributedString, pageNumber: Int) {
        // Parse the page content to find scene headings and their positions
        let string = text.string
        let lines = string.components(separatedBy: "\n")

        var yPosition: CGFloat = ScreenplayFormat.marginTop
        let lineHeight: CGFloat = 14 // Approximate line height with spacing

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()

            // Check if this looks like a scene heading
            if trimmed.hasPrefix("INT.") || trimmed.hasPrefix("EXT.") ||
               trimmed.hasPrefix("INT/EXT") || trimmed.hasPrefix("I/E") ||
               trimmed == "OMITTED" {

                // Find the scene number from the document
                if let sceneNumber = findSceneNumber(for: trimmed) {
                    // Left margin scene number
                    let leftLabel = NSTextField(labelWithString: sceneNumber)
                    leftLabel.font = NSFont(name: "Courier-Bold", size: 12)
                    leftLabel.textColor = .textColor
                    leftLabel.alignment = .right
                    leftLabel.frame = CGRect(
                        x: 20,
                        y: pageHeight - yPosition - 14,
                        width: 70,
                        height: 16
                    )
                    pageView.addSubview(leftLabel)

                    // Right margin scene number
                    let rightLabel = NSTextField(labelWithString: sceneNumber)
                    rightLabel.font = NSFont(name: "Courier-Bold", size: 12)
                    rightLabel.textColor = .textColor
                    rightLabel.alignment = .left
                    rightLabel.frame = CGRect(
                        x: pageWidth - ScreenplayFormat.marginRight + 8,
                        y: pageHeight - yPosition - 14,
                        width: 50,
                        height: 16
                    )
                    pageView.addSubview(rightLabel)
                }
            }

            yPosition += lineHeight
        }
    }

    private func findSceneNumber(for headingText: String) -> String? {
        let normalizedHeading = headingText.uppercased().trimmingCharacters(in: .whitespaces)

        for element in document.elements {
            if element.type == .sceneHeading {
                let normalizedElement = element.displayText.uppercased().trimmingCharacters(in: .whitespaces)
                if normalizedElement == normalizedHeading || normalizedHeading.hasPrefix(normalizedElement.prefix(20)) {
                    return element.sceneNumber
                }
            }
        }
        return nil
    }
}

// MARK: - Helper Views

/// Flipped view to ensure pages render top-to-bottom
private class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

/// Custom NSScrollView that centers its document view horizontally
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

/// Custom NSClipView that centers its document view horizontally
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
#endif

// MARK: - Updated Imported Script Content View

#if os(macOS)
/// Displays imported scripts with full rendering
/// Note: Uses the main inspector panel from ScreenplayEditorView for scenes/comments
struct ImportedScriptView: View {
    @StateObject private var dataManager = ScreenplayDataManager.shared
    @Binding var importedDocument: ScreenplayDocument?
    @State private var selectedDraftId: UUID?
    @State private var showImportSheet = false
    @State private var showSceneNumbers = true

    private var selectedDraft: ScreenplayDraftInfo? {
        guard let id = selectedDraftId else { return nil }
        return dataManager.drafts.first { $0.id == id && $0.importedFrom != nil }
    }

    private var importedDrafts: [ScreenplayDraftInfo] {
        dataManager.drafts.filter { $0.importedFrom != nil }
    }

    var body: some View {
        HSplitView {
            // Left sidebar - imported scripts list
            scriptListSidebar

            // Center content - full script display
            if let document = importedDocument {
                VStack(spacing: 0) {
                    // Header bar
                    scriptHeader(document: document)

                    Divider()

                    // Full script view
                    ScreenplayFullView(
                        document: document,
                        showSceneNumbers: showSceneNumbers
                    )
                }
            } else if selectedDraftId != nil {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Script...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.95))
            } else {
                // No selection placeholder
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("Select a Script")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Choose an imported script from the sidebar to view")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.95))
            }
        }
        .onChange(of: selectedDraftId) { newId in
            if let id = newId {
                loadDocument(id: id)
            } else {
                importedDocument = nil
            }
        }
        .onChange(of: importedDrafts) { drafts in
            // Clear selection if the selected draft was deleted
            if let selectedId = selectedDraftId,
               !drafts.contains(where: { $0.id == selectedId }) {
                selectedDraftId = nil
                importedDocument = nil
            }
        }
    }

    // MARK: - Script List Sidebar

    private var scriptListSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Imported Scripts")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showImportSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            if importedDrafts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No Imported Scripts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Import Final Draft or Fountain files to view them here")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: { showImportSheet = true }) {
                        Text("Import Script")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(importedDrafts, selection: $selectedDraftId) { draft in
                    ImportedDraftRow(draft: draft)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Script Header

    private func scriptHeader(document: ScreenplayDocument) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.system(size: 14, weight: .semibold))

                if let draft = selectedDraft {
                    HStack(spacing: 8) {
                        Text("\(draft.pageCount) pages")
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("\(draft.sceneCount) scenes")
                        if let source = draft.importedFrom {
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("from \(source)")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Scene numbers toggle
            Toggle(isOn: $showSceneNumbers) {
                Image(systemName: "number")
                    .font(.system(size: 12))
            }
            .toggleStyle(.button)
            .help(showSceneNumbers ? "Hide Scene Numbers" : "Show Scene Numbers")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Load Document

    private func loadDocument(id: UUID) {
        if let document = dataManager.loadDocument(id: id) {
            importedDocument = document
        }
    }
}

// MARK: - Imported Draft Row

struct ImportedDraftRow: View {
    let draft: ScreenplayDraftInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            HStack(spacing: 8) {
                if let source = draft.importedFrom {
                    Text(source)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Text("\(draft.sceneCount) scenes")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(draft.updatedAt, style: .date)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.vertical, 4)
    }
}
#endif

// MARK: - iOS Implementation
#if os(iOS)
import UIKit

/// A view that renders a complete screenplay with proper formatting and natural page breaks (iOS)
struct ScreenplayFullView: View {
    let document: ScreenplayDocument
    let showSceneNumbers: Bool
    let showRevisionMarks: Bool

    @State private var zoomLevel: CGFloat = 1.0

    private let pageWidth: CGFloat = 612   // 8.5 inches
    private let pageHeight: CGFloat = 792  // 11 inches
    private let contentWidth: CGFloat = 432  // 6 inches (8.5 - 1.5 - 1)
    private let contentHeight: CGFloat = 648 // 9 inches (11 - 1 - 1)

    init(document: ScreenplayDocument, showSceneNumbers: Bool = true, showRevisionMarks: Bool = false) {
        self.document = document
        self.showSceneNumbers = showSceneNumbers
        self.showRevisionMarks = showRevisionMarks
    }

    var body: some View {
        VStack(spacing: 0) {
            // Zoom controls
            HStack {
                Spacer()

                Button(action: { zoomLevel = max(0.5, zoomLevel - 0.1) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Text("\(Int(zoomLevel * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 45)

                Button(action: { zoomLevel = min(2.0, zoomLevel + 0.1) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Button(action: { zoomLevel = 1.0 }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))

            Divider()

            // Script pages
            ScreenplayFullPageViewiOS(
                document: document,
                showSceneNumbers: showSceneNumbers,
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                pageWidth: pageWidth,
                pageHeight: pageHeight
            )
            .scaleEffect(zoomLevel, anchor: .top)
        }
        .background(Color(white: 0.9))
    }
}

// MARK: - Screenplay Full Page View iOS (UIViewRepresentable)

struct ScreenplayFullPageViewiOS: UIViewRepresentable {
    let document: ScreenplayDocument
    let showSceneNumbers: Bool
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let pageWidth: CGFloat
    let pageHeight: CGFloat

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
        updateContent(in: uiView)
    }

    private func updateContent(in scrollView: UIScrollView) {
        // Remove old content
        scrollView.subviews.forEach { $0.removeFromSuperview() }

        let containerView = UIView()
        containerView.backgroundColor = .clear

        // Build attributed string from document
        let attributedText = buildAttributedString(from: document)

        // Paginate the content
        let pages = paginate(
            attributedText: attributedText,
            contentSize: CGSize(width: contentWidth, height: contentHeight)
        )

        print("[ScreenplayFullView-iOS] Rendering \(pages.count) pages from \(document.elements.count) elements")

        var yOffset: CGFloat = 20 // Top padding
        for (index, pageContent) in pages.enumerated() {
            let pageView = createPageView(with: pageContent, pageNumber: index + 1)
            pageView.frame = CGRect(x: 0, y: yOffset, width: pageWidth, height: pageHeight)
            containerView.addSubview(pageView)
            yOffset += pageHeight + 20
        }

        let totalHeight = max(yOffset + 20, pageHeight)
        containerView.frame = CGRect(x: 0, y: 0, width: pageWidth, height: totalHeight)
        scrollView.addSubview(containerView)
        scrollView.contentSize = CGSize(width: pageWidth, height: totalHeight)

        // Center container horizontally
        centerContent(in: scrollView, containerView: containerView)
    }

    private func centerContent(in scrollView: UIScrollView, containerView: UIView) {
        let scrollViewWidth = scrollView.bounds.width
        if containerView.frame.width < scrollViewWidth {
            let xOffset = (scrollViewWidth - containerView.frame.width) / 2
            containerView.frame.origin.x = max(0, xOffset)
        }
    }

    // MARK: - Build Attributed String

    private func buildAttributedString(from document: ScreenplayDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = ScreenplayFormatiOS.font()

        var previousType: ScriptElementType? = nil

        for (index, element) in document.elements.enumerated() {
            // Get context-aware paragraph style based on previous element
            let paragraphStyle = contextAwareParagraphStyle(
                for: element.type,
                previousType: previousType,
                isFirstElement: index == 0
            )

            // Build text for this element
            var elementText = element.displayText

            // Add newline if not last element
            if index < document.elements.count - 1 {
                elementText += "\n"
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]

            let attrString = NSAttributedString(string: elementText, attributes: attributes)
            result.append(attrString)

            previousType = element.type
        }

        return result
    }

    /// Creates paragraph style with context-aware spacing matching Final Draft exactly
    private func contextAwareParagraphStyle(
        for type: ScriptElementType,
        previousType: ScriptElementType?,
        isFirstElement: Bool
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0

        switch type {
        case .sceneHeading:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormatiOS.sceneHeadingLeftIndent
            style.headIndent = ScreenplayFormatiOS.sceneHeadingLeftIndent
            style.tailIndent = 0
            style.paragraphSpacingBefore = isFirstElement ? 0 : 24
            style.paragraphSpacing = 0

        case .action, .general:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormatiOS.actionLeftIndent
            style.headIndent = ScreenplayFormatiOS.actionLeftIndent
            style.tailIndent = 0
            if isFirstElement {
                style.paragraphSpacingBefore = 0
            } else {
                style.paragraphSpacingBefore = 12
            }
            style.paragraphSpacing = 0

        case .character:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormatiOS.characterLeftIndent
            style.headIndent = ScreenplayFormatiOS.characterLeftIndent
            style.tailIndent = 0
            style.paragraphSpacingBefore = isFirstElement ? 0 : 12
            style.paragraphSpacing = 0

        case .parenthetical:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormatiOS.parentheticalLeftIndent
            style.headIndent = ScreenplayFormatiOS.parentheticalLeftIndent
            style.tailIndent = -ScreenplayFormatiOS.parentheticalRightIndent
            style.paragraphSpacingBefore = 0
            style.paragraphSpacing = 0

        case .dialogue:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormatiOS.dialogueLeftIndent
            style.headIndent = ScreenplayFormatiOS.dialogueLeftIndent
            style.tailIndent = -ScreenplayFormatiOS.dialogueRightIndent
            style.paragraphSpacingBefore = 0
            style.paragraphSpacing = 0

        case .transition:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormatiOS.actionLeftIndent
            style.headIndent = ScreenplayFormatiOS.actionLeftIndent
            style.tailIndent = 0
            style.paragraphSpacingBefore = isFirstElement ? 0 : ScreenplayFormatiOS.transitionSpaceBefore
            style.paragraphSpacing = ScreenplayFormatiOS.transitionSpaceAfter

        case .shot:
            style.alignment = .left
            style.firstLineHeadIndent = ScreenplayFormatiOS.sceneHeadingLeftIndent
            style.headIndent = ScreenplayFormatiOS.sceneHeadingLeftIndent
            style.tailIndent = 0
            style.paragraphSpacingBefore = isFirstElement ? 0 : 24
            style.paragraphSpacing = 0

        case .titlePage:
            style.alignment = .center
            style.firstLineHeadIndent = 0
            style.headIndent = 0
            style.tailIndent = 0
            style.paragraphSpacingBefore = 12
            style.paragraphSpacing = 0
        }

        return style
    }

    // MARK: - Pagination

    private func paginate(attributedText: NSAttributedString, contentSize: CGSize) -> [NSAttributedString] {
        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var pages: [NSAttributedString] = []
        let maxPages = 1000 // Safety limit

        while pages.count < maxPages {
            let container = NSTextContainer(size: contentSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)

            layoutManager.ensureLayout(for: container)
            let glyphRange = layoutManager.glyphRange(for: container)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            if charRange.length == 0 {
                layoutManager.removeTextContainer(at: layoutManager.textContainers.count - 1)
                break
            }

            let pageContent = storage.attributedSubstring(from: charRange)
            pages.append(pageContent)

            let endLocation = charRange.location + charRange.length
            if endLocation >= storage.length {
                break
            }
        }

        if pages.count >= maxPages {
            print("[ScreenplayFullView-iOS] WARNING: Hit max page limit (\(maxPages)), possible layout issue")
        }

        return pages.isEmpty ? [attributedText] : pages
    }

    // MARK: - Create Page View

    private func createPageView(with text: NSAttributedString, pageNumber: Int) -> UIView {
        let pageView = UIView()
        pageView.backgroundColor = UIColor.systemBackground
        pageView.layer.cornerRadius = 6
        pageView.layer.shadowColor = UIColor.black.cgColor
        pageView.layer.shadowOpacity = 0.12
        pageView.layer.shadowRadius = 8
        pageView.layer.shadowOffset = CGSize(width: 0, height: 4)

        // Text view for content
        let textView = UITextView(frame: CGRect(
            x: ScreenplayFormatiOS.marginLeft,
            y: ScreenplayFormatiOS.marginTop,
            width: contentWidth,
            height: contentHeight
        ))
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.attributedText = text
        pageView.addSubview(textView)

        // Page number at top right
        let pageNumberLabel = UILabel()
        pageNumberLabel.text = "\(pageNumber)."
        pageNumberLabel.font = UIFont(name: "Courier", size: 12)
        pageNumberLabel.textColor = UIColor.label
        pageNumberLabel.textAlignment = .right
        pageNumberLabel.frame = CGRect(
            x: pageWidth - ScreenplayFormatiOS.marginRight - 40,
            y: 30, // Top of page
            width: 40,
            height: 20
        )
        pageView.addSubview(pageNumberLabel)

        // Add scene numbers in margins if enabled
        if showSceneNumbers {
            addSceneNumbersToPage(pageView, from: text, pageNumber: pageNumber)
        }

        return pageView
    }

    private func addSceneNumbersToPage(_ pageView: UIView, from text: NSAttributedString, pageNumber: Int) {
        let string = text.string
        let lines = string.components(separatedBy: "\n")

        var yPosition: CGFloat = ScreenplayFormatiOS.marginTop
        let lineHeight: CGFloat = 14

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()

            // Check if this looks like a scene heading
            if trimmed.hasPrefix("INT.") || trimmed.hasPrefix("EXT.") ||
               trimmed.hasPrefix("INT/EXT") || trimmed.hasPrefix("I/E") ||
               trimmed == "OMITTED" {

                if let sceneNumber = findSceneNumber(for: trimmed) {
                    // Left margin scene number
                    let leftLabel = UILabel()
                    leftLabel.text = sceneNumber
                    leftLabel.font = UIFont(name: "Courier-Bold", size: 12)
                    leftLabel.textColor = UIColor.label
                    leftLabel.textAlignment = .right
                    leftLabel.frame = CGRect(
                        x: 8,
                        y: yPosition,
                        width: 70,
                        height: 16
                    )
                    pageView.addSubview(leftLabel)

                    // Right margin scene number
                    let rightLabel = UILabel()
                    rightLabel.text = sceneNumber
                    rightLabel.font = UIFont(name: "Courier-Bold", size: 12)
                    rightLabel.textColor = UIColor.label
                    rightLabel.textAlignment = .left
                    rightLabel.frame = CGRect(
                        x: pageWidth - ScreenplayFormatiOS.marginRight + 8,
                        y: yPosition,
                        width: 50,
                        height: 16
                    )
                    pageView.addSubview(rightLabel)
                }
            }

            yPosition += lineHeight
        }
    }

    private func findSceneNumber(for headingText: String) -> String? {
        let normalizedHeading = headingText.uppercased().trimmingCharacters(in: .whitespaces)

        for element in document.elements {
            if element.type == .sceneHeading {
                let normalizedElement = element.displayText.uppercased().trimmingCharacters(in: .whitespaces)
                if normalizedElement == normalizedHeading || normalizedHeading.hasPrefix(String(normalizedElement.prefix(20))) {
                    return element.sceneNumber
                }
            }
        }
        return nil
    }
}

// Note: ScreenplayFormatiOS is defined in ScreenplayTextView.swift

// MARK: - iOS Imported Script View

/// Displays imported scripts with full rendering (iOS)
struct ImportedScriptView: View {
    @StateObject private var dataManager = ScreenplayDataManager.shared
    @Binding var importedDocument: ScreenplayDocument?
    @State private var selectedDraftId: UUID?
    @State private var showImportSheet = false
    @State private var showSceneNumbers = true

    private var selectedDraft: ScreenplayDraftInfo? {
        guard let id = selectedDraftId else { return nil }
        return dataManager.drafts.first { $0.id == id && $0.importedFrom != nil }
    }

    private var importedDrafts: [ScreenplayDraftInfo] {
        dataManager.drafts.filter { $0.importedFrom != nil }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar - imported scripts list
            scriptListSidebar
        } detail: {
            // Detail content - full script display
            if let document = importedDocument {
                VStack(spacing: 0) {
                    // Header bar
                    scriptHeader(document: document)

                    Divider()

                    // Full script view
                    ScreenplayFullView(
                        document: document,
                        showSceneNumbers: showSceneNumbers
                    )
                }
            } else if selectedDraftId != nil {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Script...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
            } else {
                // No selection placeholder
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("Select a Script")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Choose an imported script from the sidebar to view")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
        .onChange(of: selectedDraftId) { newId in
            if let id = newId {
                loadDocument(id: id)
            } else {
                importedDocument = nil
            }
        }
        .onChange(of: importedDrafts.count) { _ in
            // Clear selection if the selected draft was deleted
            if let selectedId = selectedDraftId,
               !importedDrafts.contains(where: { $0.id == selectedId }) {
                selectedDraftId = nil
                importedDocument = nil
            }
        }
    }

    // MARK: - Script List Sidebar

    private var scriptListSidebar: some View {
        List(selection: $selectedDraftId) {
            Section {
                ForEach(importedDrafts) { draft in
                    ImportedDraftRow(draft: draft)
                        .tag(draft.id)
                }
            } header: {
                HStack {
                    Text("Imported Scripts")
                    Spacer()
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Scripts")
        .overlay {
            if importedDrafts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Imported Scripts")
                        .font(.headline)
                    Text("Import Final Draft or Fountain files to view them here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Import Script") {
                        showImportSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    // MARK: - Script Header

    private func scriptHeader(document: ScreenplayDocument) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.system(size: 14, weight: .semibold))

                if let draft = selectedDraft {
                    HStack(spacing: 8) {
                        Text("\(draft.pageCount) pages")
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("\(draft.sceneCount) scenes")
                        if let source = draft.importedFrom {
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("from \(source)")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Scene numbers toggle
            Toggle(isOn: $showSceneNumbers) {
                Image(systemName: "number")
                    .font(.system(size: 12))
            }
            .toggleStyle(.button)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Load Document

    private func loadDocument(id: UUID) {
        if let document = dataManager.loadDocument(id: id) {
            importedDocument = document
        }
    }
}

// MARK: - iOS Imported Draft Row

struct ImportedDraftRow: View {
    let draft: ScreenplayDraftInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            HStack(spacing: 8) {
                if let source = draft.importedFrom {
                    Text(source)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Text("\(draft.sceneCount) scenes")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(draft.updatedAt, style: .date)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.vertical, 4)
    }
}
#endif
