//
//  ScreenplayExporter.swift
//  Production Runner
//
//  Handles exporting screenplays to PDF, FDX, Fountain, and printing.
//  Follows industry-standard formatting and revision marking.
//

import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
import PDFKit
#endif

// MARK: - Export Options

struct ScreenplayExportOptions {
    var includeTitlePage: Bool = true
    var includeRevisionMarks: Bool = true  // Asterisks in margins
    var includeRevisionHeaders: Bool = true  // "BLUE REVISIONS - 12/10/24"
    var sceneNumbers: SceneNumberPosition = .both
    var startingPageNumber: Int = 1
    var watermarkText: String? = nil
    var paperSize: PaperSize = .usLetter

    enum PaperSize: String, CaseIterable {
        case usLetter = "US Letter"
        case a4 = "A4"

        var size: CGSize {
            switch self {
            case .usLetter:
                return CGSize(width: 612, height: 792)  // 8.5" x 11" at 72 dpi
            case .a4:
                return CGSize(width: 595, height: 842)  // 210mm x 297mm at 72 dpi
            }
        }
    }
}

// MARK: - Title Page Info

struct ScreenplayTitlePage {
    var title: String
    var writtenBy: String
    var basedOn: String?
    var contactName: String?
    var contactEmail: String?
    var contactPhone: String?
    var contactAddress: String?
    var draftDate: Date
    var revisionColor: String?
    var revisionDate: Date?
    var copyright: String?

    init(from document: ScreenplayDocument) {
        self.title = document.title
        self.writtenBy = document.author.isEmpty ? "Unknown Author" : document.author
        self.basedOn = nil
        self.contactName = nil
        self.contactEmail = nil
        self.contactPhone = nil
        self.contactAddress = nil
        self.draftDate = document.createdAt
        self.revisionColor = document.currentRevisionColor
        self.revisionDate = document.updatedAt
        self.copyright = nil
    }
}

// MARK: - Screenplay Exporter

#if os(macOS)
class ScreenplayExporter {

    // MARK: - PDF Export

    /// Export screenplay to PDF file
    static func exportToPDF(
        document: ScreenplayDocument,
        options: ScreenplayExportOptions = ScreenplayExportOptions(),
        titlePage: ScreenplayTitlePage? = nil
    ) -> Data? {
        let pageSize = options.paperSize.size

        // Create PDF context
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return nil
        }

        var pageRect = CGRect(origin: .zero, size: pageSize)

        // Draw title page if included
        if options.includeTitlePage {
            let titleInfo = titlePage ?? ScreenplayTitlePage(from: document)
            pdfContext.beginPage(mediaBox: &pageRect)
            drawTitlePage(context: pdfContext, titlePage: titleInfo, pageSize: pageSize)
            pdfContext.endPage()
        }

        // Draw script pages
        let pages = paginateDocument(document, pageSize: pageSize, options: options)

        for (pageIndex, page) in pages.enumerated() {
            pdfContext.beginPage(mediaBox: &pageRect)

            let pageNumber = options.startingPageNumber + pageIndex
            drawScriptPage(
                context: pdfContext,
                page: page,
                pageNumber: pageNumber,
                pageSize: pageSize,
                options: options,
                document: document
            )

            pdfContext.endPage()
        }

        pdfContext.closePDF()

        return pdfData as Data
    }

    /// Show save panel and export to PDF
    static func exportToPDFWithPanel(
        document: ScreenplayDocument,
        options: ScreenplayExportOptions = ScreenplayExportOptions(),
        titlePage: ScreenplayTitlePage? = nil
    ) {
        guard let pdfData = exportToPDF(document: document, options: options, titlePage: titlePage) else {
            Swift.print("[ScreenplayExporter] Failed to generate PDF data")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export Screenplay as PDF"
        savePanel.nameFieldStringValue = "\(document.title).pdf"
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try pdfData.write(to: url)
                    Swift.print("[ScreenplayExporter] PDF exported to: \(url.path)")

                    // Open the PDF
                    NSWorkspace.shared.open(url)
                } catch {
                    Swift.print("[ScreenplayExporter] Failed to write PDF: \(error)")
                }
            }
        }
    }

    // MARK: - Print

    /// Print the screenplay
    static func printScreenplay(
        document: ScreenplayDocument,
        options: ScreenplayExportOptions = ScreenplayExportOptions(),
        titlePage: ScreenplayTitlePage? = nil
    ) {
        guard let pdfData = exportToPDF(document: document, options: options, titlePage: titlePage) else {
            Swift.print("[ScreenplayExporter] Failed to generate PDF for printing")
            return
        }

        guard let pdfDocument = PDFDocument(data: pdfData) else {
            Swift.print("[ScreenplayExporter] Failed to create PDF document for printing")
            return
        }

        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = options.paperSize.size
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72

        let printOperation = pdfDocument.printOperation(for: printInfo, scalingMode: .pageScaleNone, autoRotate: false)
        printOperation?.showsPrintPanel = true
        printOperation?.showsProgressPanel = true

        printOperation?.run()
    }

    // MARK: - FDX Export

    /// Export screenplay to Final Draft FDX format
    static func exportToFDX(document: ScreenplayDocument) -> Data? {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="5">
        <Content>

        """

        for element in document.elements {
            let fdxType = fdxElementType(for: element.type)
            let escapedText = escapeXML(element.text)

            xml += "<Paragraph Type=\"\(fdxType)\""

            // Add revision attributes if present
            if let revColor = element.revisionColor, revColor.lowercased() != "white" {
                xml += " RevisionID=\"\(element.revisionID ?? 1)\""
            }

            xml += ">\n"
            xml += "  <Text>\(escapedText)</Text>\n"
            xml += "</Paragraph>\n"
        }

        let authorText = escapeXML(document.author)
        xml += """
        </Content>
        <TitlePage>
        <Content>
        <Paragraph Type="Title"><Text>\(escapeXML(document.title))</Text></Paragraph>
        <Paragraph Type="Author"><Text>\(authorText)</Text></Paragraph>
        </Content>
        </TitlePage>
        </FinalDraft>
        """

        return xml.data(using: .utf8)
    }

    /// Show save panel and export to FDX
    static func exportToFDXWithPanel(document: ScreenplayDocument) {
        guard let fdxData = exportToFDX(document: document) else {
            Swift.print("[ScreenplayExporter] Failed to generate FDX data")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export Screenplay as Final Draft"
        savePanel.nameFieldStringValue = "\(document.title).fdx"
        savePanel.allowedContentTypes = [.xml]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try fdxData.write(to: url)
                    Swift.print("[ScreenplayExporter] FDX exported to: \(url.path)")
                } catch {
                    Swift.print("[ScreenplayExporter] Failed to write FDX: \(error)")
                }
            }
        }
    }

    // MARK: - Fountain Export

    /// Export screenplay to Fountain format (plain text markup)
    static func exportToFountain(document: ScreenplayDocument) -> Data? {
        var fountain = ""

        // Title page
        fountain += "Title: \(document.title)\n"
        if !document.author.isEmpty {
            fountain += "Author: \(document.author)\n"
        }
        fountain += "Draft date: \(formatDate(document.updatedAt))\n"
        fountain += "\n===\n\n"  // Page break after title page

        for element in document.elements {
            switch element.type {
            case .sceneHeading:
                // Scene headings are auto-detected if they start with INT./EXT.
                // Otherwise force with a leading period
                let text = element.text.uppercased()
                if text.hasPrefix("INT.") || text.hasPrefix("EXT.") || text.hasPrefix("INT/EXT") || text.hasPrefix("I/E") {
                    fountain += "\(text)\n\n"
                } else {
                    fountain += ".\(text)\n\n"
                }

            case .action:
                fountain += "\(element.text)\n\n"

            case .character:
                // Character names in ALL CAPS
                fountain += "\(element.text.uppercased())\n"

            case .parenthetical:
                // Parentheticals wrapped in parens
                let text = element.text.hasPrefix("(") ? element.text : "(\(element.text))"
                fountain += "\(text)\n"

            case .dialogue:
                fountain += "\(element.text)\n\n"

            case .transition:
                // Transitions end with TO: or are forced with >
                let text = element.text.uppercased()
                if text.hasSuffix("TO:") {
                    fountain += "\(text)\n\n"
                } else {
                    fountain += "> \(text)\n\n"
                }

            case .shot:
                // Shots are like scene headings but for camera directions
                fountain += ".\(element.text.uppercased())\n\n"

            case .general, .titlePage:
                fountain += "\(element.text)\n\n"
            }
        }

        return fountain.data(using: .utf8)
    }

    /// Show save panel and export to Fountain
    static func exportToFountainWithPanel(document: ScreenplayDocument) {
        guard let fountainData = exportToFountain(document: document) else {
            Swift.print("[ScreenplayExporter] Failed to generate Fountain data")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export Screenplay as Fountain"
        savePanel.nameFieldStringValue = "\(document.title).fountain"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try fountainData.write(to: url)
                    Swift.print("[ScreenplayExporter] Fountain exported to: \(url.path)")
                } catch {
                    Swift.print("[ScreenplayExporter] Failed to write Fountain: \(error)")
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Paginate document into pages using the same layout as the UI editor
    private static func paginateDocument(
        _ document: ScreenplayDocument,
        pageSize: CGSize,
        options: ScreenplayExportOptions
    ) -> [[ScriptElement]] {
        var pages: [[ScriptElement]] = []
        var currentPage: [ScriptElement] = []
        var currentHeight: CGFloat = 0

        // Use the same content height as the UI editor
        let contentHeight = ScreenplayFormat.contentHeight
        let lineHeight = ScreenplayFormat.lineHeight

        for element in document.elements {
            // Skip title page elements - they're rendered separately
            if element.type == .titlePage {
                continue
            }

            let elementHeight = estimateElementHeight(element, lineHeight: lineHeight)

            // Check if we need to start a new page
            if currentHeight + elementHeight > contentHeight && !currentPage.isEmpty {
                // Apply industry-standard page break rules
                // Scene headings should have at least one line of following content
                // Character names should have at least one line of dialogue
                pages.append(currentPage)
                currentPage = []
                currentHeight = 0
            }

            currentPage.append(element)
            currentHeight += elementHeight
        }

        // Add final page
        if !currentPage.isEmpty {
            pages.append(currentPage)
        }

        return pages
    }

    /// Estimate height of an element using the same spacing as the UI editor
    private static func estimateElementHeight(_ element: ScriptElement, lineHeight: CGFloat) -> CGFloat {
        let text = element.text

        // Calculate width for text wrapping based on element type (matching UI layout)
        let elementWidth: CGFloat
        switch element.type {
        case .sceneHeading:
            elementWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.sceneHeadingLeftIndent - ScreenplayFormat.sceneHeadingRightIndent
        case .action, .general:
            elementWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.actionLeftIndent - ScreenplayFormat.actionRightIndent
        case .character:
            elementWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.characterLeftIndent - ScreenplayFormat.characterRightIndent
        case .dialogue:
            elementWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.dialogueLeftIndent - ScreenplayFormat.dialogueRightIndent
        case .parenthetical:
            elementWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.parentheticalLeftIndent - ScreenplayFormat.parentheticalRightIndent
        case .transition:
            elementWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.transitionLeftIndent - ScreenplayFormat.transitionRightIndent
        case .shot, .titlePage:
            elementWidth = ScreenplayFormat.contentWidth
        }

        // Approximate chars per line for Courier 12pt (7.2 points per character)
        let charsPerLine = max(1, Int(elementWidth / 7.2))
        let lineCount = max(1, (text.count + charsPerLine - 1) / charsPerLine)

        // Calculate spacing before and after (matching UI)
        var height: CGFloat = CGFloat(lineCount) * lineHeight

        switch element.type {
        case .sceneHeading:
            height += ScreenplayFormat.sceneHeadingSpaceBefore + ScreenplayFormat.sceneHeadingSpaceAfter
        case .action, .general:
            height += ScreenplayFormat.actionSpaceBefore + ScreenplayFormat.actionSpaceAfter
        case .character:
            height += ScreenplayFormat.characterSpaceBefore + ScreenplayFormat.characterSpaceAfter
        case .dialogue:
            height += ScreenplayFormat.dialogueSpaceBefore + ScreenplayFormat.dialogueSpaceAfter
        case .parenthetical:
            height += ScreenplayFormat.parentheticalSpaceBefore + ScreenplayFormat.parentheticalSpaceAfter
        case .transition:
            height += ScreenplayFormat.transitionSpaceBefore + ScreenplayFormat.transitionSpaceAfter
        case .shot, .titlePage:
            height += lineHeight
        }

        return height
    }

    /// Draw title page matching the UI layout
    private static func drawTitlePage(
        context: CGContext,
        titlePage: ScreenplayTitlePage,
        pageSize: CGSize
    ) {
        let courierFont = CTFontCreateWithName("Courier" as CFString, ScreenplayFormat.fontSize, nil)
        let courierBold = CTFontCreateWithName("Courier-Bold" as CFString, ScreenplayFormat.fontSize, nil)
        let lineHeight = ScreenplayFormat.lineHeight

        // Title - centered, about 1/3 down the page (matching UI)
        let titleY = pageSize.height * 0.65
        drawCenteredText(
            context: context,
            text: titlePage.title.uppercased(),
            y: titleY,
            pageWidth: pageSize.width,
            font: courierBold
        )

        // "written by" - centered, below title
        drawCenteredText(
            context: context,
            text: "written by",
            y: titleY - lineHeight * 3,
            pageWidth: pageSize.width,
            font: courierFont
        )

        // Author name - centered, below "written by"
        drawCenteredText(
            context: context,
            text: titlePage.writtenBy,
            y: titleY - lineHeight * 5,
            pageWidth: pageSize.width,
            font: courierFont
        )

        // Contact info - bottom left (matching UI margin)
        var contactY: CGFloat = ScreenplayFormat.marginBottom + lineHeight * 6
        if let name = titlePage.contactName {
            drawText(context: context, text: name, x: ScreenplayFormat.marginLeft, y: contactY, font: courierFont)
            contactY -= lineHeight
        }
        if let email = titlePage.contactEmail {
            drawText(context: context, text: email, x: ScreenplayFormat.marginLeft, y: contactY, font: courierFont)
            contactY -= lineHeight
        }
        if let phone = titlePage.contactPhone {
            drawText(context: context, text: phone, x: ScreenplayFormat.marginLeft, y: contactY, font: courierFont)
        }

        // Draft date - bottom right
        let dateStr = formatDate(titlePage.draftDate)
        drawText(context: context, text: dateStr, x: pageSize.width - ScreenplayFormat.marginRight - 150, y: ScreenplayFormat.marginBottom + lineHeight * 6, font: courierFont)

        // Revision info if present
        if let revColor = titlePage.revisionColor, revColor.lowercased() != "white" {
            let revDateStr = titlePage.revisionDate.map { formatDate($0) } ?? ""
            let revText = "\(revColor) Revisions - \(revDateStr)"
            drawText(context: context, text: revText, x: pageSize.width - ScreenplayFormat.marginRight - 180, y: ScreenplayFormat.marginBottom + lineHeight * 4, font: courierFont)
        }
    }

    /// Draw a script page using the exact same layout as the UI editor
    private static func drawScriptPage(
        context: CGContext,
        page: [ScriptElement],
        pageNumber: Int,
        pageSize: CGSize,
        options: ScreenplayExportOptions,
        document: ScreenplayDocument
    ) {
        let courierFont = CTFontCreateWithName("Courier" as CFString, ScreenplayFormat.fontSize, nil)
        let lineHeight = ScreenplayFormat.lineHeight

        // Use the same margins as the UI editor
        let marginLeft = ScreenplayFormat.marginLeft
        let marginTop = ScreenplayFormat.marginTop
        let marginRight = ScreenplayFormat.marginRight

        var y = pageSize.height - marginTop

        // Draw revision header if needed
        if options.includeRevisionHeaders {
            if let revColor = findPageRevisionColor(page), revColor.lowercased() != "white" {
                let dateStr = formatDate(Date())
                let headerText = "\(revColor.uppercased()) REVISIONS - \(dateStr)"
                drawCenteredText(context: context, text: headerText, y: pageSize.height - marginTop / 2, pageWidth: pageSize.width, font: courierFont)
            }
        }

        // Draw page number (skip page 1) - right aligned in header area
        if pageNumber > 1 {
            let pageNumText = "\(pageNumber)."
            drawText(context: context, text: pageNumText, x: pageSize.width - marginRight - 30, y: pageSize.height - marginTop / 2, font: courierFont)
        }

        // Draw scene numbers if enabled
        let showLeftSceneNum = options.sceneNumbers.showLeft
        let showRightSceneNum = options.sceneNumbers.showRight

        // Draw elements using the exact same positioning as the UI
        for element in page {
            var x: CGFloat
            var maxWidth: CGFloat

            // Calculate x position and width matching UI layout
            switch element.type {
            case .sceneHeading:
                y -= ScreenplayFormat.sceneHeadingSpaceBefore
                x = marginLeft + ScreenplayFormat.sceneHeadingLeftIndent
                maxWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.sceneHeadingLeftIndent - ScreenplayFormat.sceneHeadingRightIndent

                // Draw scene numbers in margins
                if let sceneNum = element.sceneNumber {
                    if showLeftSceneNum {
                        drawText(context: context, text: sceneNum, x: marginLeft / 2 - 10, y: y, font: courierFont)
                    }
                    if showRightSceneNum {
                        drawText(context: context, text: sceneNum, x: pageSize.width - marginRight / 2 - 10, y: y, font: courierFont)
                    }
                }

            case .action, .general:
                y -= ScreenplayFormat.actionSpaceBefore
                x = marginLeft + ScreenplayFormat.actionLeftIndent
                maxWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.actionLeftIndent - ScreenplayFormat.actionRightIndent

            case .character:
                y -= ScreenplayFormat.characterSpaceBefore
                x = marginLeft + ScreenplayFormat.characterLeftIndent
                maxWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.characterLeftIndent - ScreenplayFormat.characterRightIndent

            case .dialogue:
                y -= ScreenplayFormat.dialogueSpaceBefore
                x = marginLeft + ScreenplayFormat.dialogueLeftIndent
                maxWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.dialogueLeftIndent - ScreenplayFormat.dialogueRightIndent

            case .parenthetical:
                y -= ScreenplayFormat.parentheticalSpaceBefore
                x = marginLeft + ScreenplayFormat.parentheticalLeftIndent
                maxWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.parentheticalLeftIndent - ScreenplayFormat.parentheticalRightIndent

            case .transition:
                y -= ScreenplayFormat.transitionSpaceBefore
                // Transition is right-aligned
                x = marginLeft + ScreenplayFormat.transitionLeftIndent
                maxWidth = ScreenplayFormat.contentWidth - ScreenplayFormat.transitionLeftIndent - ScreenplayFormat.transitionRightIndent

            case .shot, .titlePage:
                y -= lineHeight
                x = marginLeft
                maxWidth = ScreenplayFormat.contentWidth
            }

            // Draw the text
            let text = element.type.isAllCaps ? element.text.uppercased() : element.text
            let lines = wrapText(text, maxWidth: maxWidth, font: courierFont)

            // For transitions, right-align the text
            let isRightAligned = element.type == .transition

            for line in lines {
                if isRightAligned {
                    // Calculate text width for right alignment
                    let attributes: [NSAttributedString.Key: Any] = [.font: courierFont]
                    let attrString = NSAttributedString(string: line, attributes: attributes)
                    let ctLine = CTLineCreateWithAttributedString(attrString)
                    let textWidth = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
                    drawText(context: context, text: line, x: pageSize.width - marginRight - CGFloat(textWidth), y: y, font: courierFont)
                } else {
                    drawText(context: context, text: line, x: x, y: y, font: courierFont)
                }
                y -= lineHeight
            }

            // Draw revision asterisk in right margin if needed
            if options.includeRevisionMarks,
               let revColor = element.revisionColor,
               revColor.lowercased() != "white" {
                drawText(context: context, text: "*", x: pageSize.width - marginRight / 2, y: y + lineHeight, font: courierFont)
            }

            // Add space after element (matching UI)
            switch element.type {
            case .sceneHeading:
                y -= ScreenplayFormat.sceneHeadingSpaceAfter
            case .action, .general:
                y -= ScreenplayFormat.actionSpaceAfter
            case .character:
                y -= ScreenplayFormat.characterSpaceAfter
            case .dialogue:
                y -= ScreenplayFormat.dialogueSpaceAfter
            case .parenthetical:
                y -= ScreenplayFormat.parentheticalSpaceAfter
            case .transition:
                y -= ScreenplayFormat.transitionSpaceAfter
            case .shot, .titlePage:
                break
            }
        }

        // Draw watermark if specified
        if let watermark = options.watermarkText {
            drawWatermark(context: context, text: watermark, pageSize: pageSize)
        }
    }

    /// Find the revision color for a page
    private static func findPageRevisionColor(_ page: [ScriptElement]) -> String? {
        for element in page {
            if let color = element.revisionColor, color.lowercased() != "white" {
                return color
            }
        }
        return nil
    }

    /// Draw text at position
    private static func drawText(context: CGContext, text: String, x: CGFloat, y: CGFloat, font: CTFont) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)

        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    /// Draw centered text
    private static func drawCenteredText(context: CGContext, text: String, y: CGFloat, pageWidth: CGFloat, font: CTFont) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let x = (pageWidth - textWidth) / 2

        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    /// Draw watermark diagonally across page
    private static func drawWatermark(context: CGContext, text: String, pageSize: CGSize) {
        context.saveGState()

        let watermarkFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 72, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: watermarkFont,
            .foregroundColor: NSColor.gray.withAlphaComponent(0.15)
        ]
        let attrString = NSAttributedString(string: text.uppercased(), attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)

        // Rotate and position
        context.translateBy(x: pageSize.width / 2, y: pageSize.height / 2)
        context.rotate(by: -CGFloat.pi / 4)

        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        context.textPosition = CGPoint(x: -textWidth / 2, y: 0)
        CTLineDraw(line, context)

        context.restoreGState()
    }

    /// Wrap text to fit within max width
    private static func wrapText(_ text: String, maxWidth: CGFloat, font: CTFont) -> [String] {
        let charsPerLine = Int(maxWidth / 7.2)  // Approximate for 12pt Courier
        var lines: [String] = []
        var currentLine = ""

        let words = text.split(separator: " ", omittingEmptySubsequences: false)

        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"

            if testLine.count <= charsPerLine {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = String(word)
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [""] : lines
    }

    /// Convert element type to FDX type
    private static func fdxElementType(for type: ScriptElementType) -> String {
        switch type {
        case .sceneHeading: return "Scene Heading"
        case .action: return "Action"
        case .character: return "Character"
        case .parenthetical: return "Parenthetical"
        case .dialogue: return "Dialogue"
        case .transition: return "Transition"
        case .shot: return "Shot"
        case .general: return "General"
        case .titlePage: return "General"
        }
    }

    /// Escape XML special characters
    private static func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// Format date for display
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
#endif
