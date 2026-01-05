//
//  ScriptSidesGenerator.swift
//  Production Runner
//
//  Generates script sides (filtered screenplay excerpts) for production use.
//  Supports filtering by scenes, character, or shoot day.
//

import Foundation
import SwiftUI
import PDFKit
import CoreData

#if os(macOS)
import AppKit

// MARK: - Filter Types

/// Types of filters for generating script sides
public enum ScriptSidesFilterType: String, CaseIterable, Identifiable {
    case scenes = "By Scenes"
    case character = "By Character"
    case shootDay = "By Shoot Day"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .scenes: return "film"
        case .character: return "person"
        case .shootDay: return "calendar"
        }
    }

    public var description: String {
        switch self {
        case .scenes: return "Select specific scenes to include"
        case .character: return "Include all scenes with a specific character"
        case .shootDay: return "Include all scenes scheduled for a shoot day"
        }
    }
}

// MARK: - Options

/// Options for generating script sides
struct ScriptSidesOptions {
    var filterType: ScriptSidesFilterType = .scenes
    var sceneNumbers: [String] = []        // For scene filter
    var characterName: String?             // For character filter
    var shootDayID: UUID?                  // For shoot day filter
    var includeSceneNumbers: Bool = true
    var includePageNumbers: Bool = true
    var headerText: String = ""            // e.g., "DAY 3 SIDES"
    var showRevisionMarks: Bool = true

    init() {}
}

// MARK: - Script Sides Generator

/// Generates script sides PDF from a screenplay document
class ScriptSidesGenerator {

    // MARK: - Page Configuration

    private static let pageWidth: CGFloat = 612     // 8.5 inches at 72 dpi
    private static let pageHeight: CGFloat = 792    // 11 inches at 72 dpi
    private static let topMargin: CGFloat = 72      // 1 inch
    private static let bottomMargin: CGFloat = 72   // 1 inch
    private static let leftMargin: CGFloat = 108    // 1.5 inches
    private static let rightMargin: CGFloat = 72    // 1 inch
    private static let contentWidth: CGFloat = pageWidth - leftMargin - rightMargin

    // MARK: - Fonts

    private static let titleFont = NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let bodyFont = NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let boldFont = NSFont(name: "Courier-Bold", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)

    // MARK: - Public API

    /// Generate script sides from a screenplay document
    /// - Parameters:
    ///   - document: The screenplay document
    ///   - options: Filtering and formatting options
    ///   - context: Core Data context (needed for shoot day lookup)
    /// - Returns: PDF data if successful
    static func generateSides(
        document: ScreenplayDocument,
        options: ScriptSidesOptions,
        context: NSManagedObjectContext? = nil
    ) -> Data? {
        // Filter elements based on options
        let filteredElements = filterElements(
            from: document,
            options: options,
            context: context
        )

        guard !filteredElements.isEmpty else {
            return nil
        }

        // Generate PDF
        return generatePDF(
            elements: filteredElements,
            options: options,
            documentTitle: document.title
        )
    }

    /// Get scene numbers for a shoot day
    static func scenesForShootDay(
        shootDayID: UUID,
        context: NSManagedObjectContext
    ) -> [String] {
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ShootDayEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", shootDayID as CVarArg)

        do {
            guard let shootDay = try context.fetch(fetchRequest).first else {
                return []
            }

            // Get scenes from the shoot day
            if let scenes = shootDay.value(forKey: "scenes") as? Set<NSManagedObject> {
                let numbers = scenes.compactMap { scene -> String? in
                    scene.value(forKey: "number") as? String
                }
                return numbers.sorted { lhs, rhs in
                    // Sort scene numbers properly (1, 2, 10, 10A, 10B, etc.)
                    let lhsNum = Int(lhs.filter { $0.isNumber }) ?? 0
                    let rhsNum = Int(rhs.filter { $0.isNumber }) ?? 0
                    if lhsNum != rhsNum { return lhsNum < rhsNum }
                    return lhs < rhs
                }
            }
        } catch {
            print("Failed to fetch shoot day: \(error)")
        }

        return []
    }

    /// Get all characters from a screenplay document
    static func characters(from document: ScreenplayDocument) -> [String] {
        var characterSet = Set<String>()

        for element in document.elements where element.type == .character {
            let name = element.text.uppercased()
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "(V.O.)", with: "")
                .replacingOccurrences(of: "(O.S.)", with: "")
                .replacingOccurrences(of: "(O.C.)", with: "")
                .replacingOccurrences(of: "(CONT'D)", with: "")
                .trimmingCharacters(in: .whitespaces)

            if !name.isEmpty {
                characterSet.insert(name)
            }
        }

        return characterSet.sorted()
    }

    /// Get all scenes from a screenplay document
    static func scenes(from document: ScreenplayDocument) -> [(number: String, heading: String)] {
        var scenes: [(number: String, heading: String)] = []

        for element in document.elements where element.type == .sceneHeading {
            let number = element.sceneNumber ?? ""
            let heading = element.text
            scenes.append((number, heading))
        }

        return scenes
    }

    // MARK: - Private Filtering

    private static func filterElements(
        from document: ScreenplayDocument,
        options: ScriptSidesOptions,
        context: NSManagedObjectContext?
    ) -> [ScriptElement] {
        switch options.filterType {
        case .scenes:
            return filterByScenes(document.elements, sceneNumbers: options.sceneNumbers)
        case .character:
            guard let character = options.characterName else { return [] }
            return filterByCharacter(document.elements, character: character)
        case .shootDay:
            guard let shootDayID = options.shootDayID, let ctx = context else { return [] }
            let sceneNumbers = scenesForShootDay(shootDayID: shootDayID, context: ctx)
            return filterByScenes(document.elements, sceneNumbers: sceneNumbers)
        }
    }

    /// Filter elements to only include specified scenes
    private static func filterByScenes(_ elements: [ScriptElement], sceneNumbers: [String]) -> [ScriptElement] {
        guard !sceneNumbers.isEmpty else { return [] }

        let sceneSet = Set(sceneNumbers.map { $0.uppercased().trimmingCharacters(in: .whitespaces) })
        var result: [ScriptElement] = []
        var includeCurrentScene = false

        for element in elements {
            if element.type == .sceneHeading {
                // Check if this scene should be included
                let sceneNum = (element.sceneNumber ?? "").uppercased().trimmingCharacters(in: .whitespaces)
                includeCurrentScene = sceneSet.contains(sceneNum)
            }

            if includeCurrentScene {
                result.append(element)
            }
        }

        return result
    }

    /// Filter elements to only include scenes containing a specific character
    private static func filterByCharacter(_ elements: [ScriptElement], character: String) -> [ScriptElement] {
        let searchCharacter = character.uppercased().trimmingCharacters(in: .whitespaces)

        // First pass: find all scene numbers that contain this character
        var scenesWithCharacter = Set<String>()
        var currentSceneNumber: String?

        for element in elements {
            if element.type == .sceneHeading {
                currentSceneNumber = element.sceneNumber
            } else if element.type == .character {
                let charName = element.text.uppercased()
                    .replacingOccurrences(of: "(V.O.)", with: "")
                    .replacingOccurrences(of: "(O.S.)", with: "")
                    .replacingOccurrences(of: "(O.C.)", with: "")
                    .replacingOccurrences(of: "(CONT'D)", with: "")
                    .trimmingCharacters(in: .whitespaces)

                if charName == searchCharacter, let sceneNum = currentSceneNumber {
                    scenesWithCharacter.insert(sceneNum)
                }
            }
        }

        // Second pass: include all elements from scenes with this character
        return filterByScenes(elements, sceneNumbers: Array(scenesWithCharacter))
    }

    // MARK: - PDF Generation

    private static func generatePDF(
        elements: [ScriptElement],
        options: ScriptSidesOptions,
        documentTitle: String
    ) -> Data? {
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfInfo: [String: Any] = [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "\(documentTitle) - Sides"
        ]

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, pdfInfo as CFDictionary) else {
            return nil
        }

        // Paginate and draw
        let pages = paginateElements(elements)
        let headerText = options.headerText.isEmpty ? "SIDES - \(documentTitle)" : options.headerText

        for (pageIndex, pageElements) in pages.enumerated() {
            pdfContext.beginPage(mediaBox: &pageRect)

            let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
            NSGraphicsContext.current = nsContext

            // Draw header
            var yPosition = pageHeight - topMargin + 30
            if !headerText.isEmpty {
                drawHeader(headerText, at: &yPosition, pageNumber: pageIndex + 1, totalPages: pages.count)
            }

            yPosition = pageHeight - topMargin

            // Draw elements
            for element in pageElements {
                yPosition = drawElement(element, at: yPosition, options: options)
            }

            // Draw page number
            if options.includePageNumbers {
                drawPageNumber(pageIndex + 1, totalPages: pages.count)
            }

            NSGraphicsContext.current = nil
            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()

        return pdfData as Data
    }

    /// Paginate elements into pages
    private static func paginateElements(_ elements: [ScriptElement]) -> [[ScriptElement]] {
        var pages: [[ScriptElement]] = []
        var currentPage: [ScriptElement] = []
        var currentY = pageHeight - topMargin

        let lineHeight: CGFloat = 14
        let elementSpacing: CGFloat = 14

        for element in elements {
            let elementHeight = estimateElementHeight(element, lineHeight: lineHeight)

            // Check if we need a new page
            if currentY - elementHeight < bottomMargin {
                if !currentPage.isEmpty {
                    pages.append(currentPage)
                }
                currentPage = []
                currentY = pageHeight - topMargin
            }

            currentPage.append(element)
            currentY -= elementHeight + elementSpacing
        }

        // Don't forget the last page
        if !currentPage.isEmpty {
            pages.append(currentPage)
        }

        return pages
    }

    /// Estimate the height of an element
    private static func estimateElementHeight(_ element: ScriptElement, lineHeight: CGFloat) -> CGFloat {
        let text = element.displayText
        let maxWidth = widthForElement(element)
        let charWidth: CGFloat = 7.2 // Approximate for Courier 12pt

        let charsPerLine = Int(maxWidth / charWidth)
        let lineCount = max(1, (text.count + charsPerLine - 1) / charsPerLine)

        return CGFloat(lineCount) * lineHeight
    }

    /// Get the width for an element type
    private static func widthForElement(_ element: ScriptElement) -> CGFloat {
        switch element.type {
        case .sceneHeading, .action, .transition, .shot:
            return contentWidth
        case .character:
            return 200
        case .parenthetical:
            return 180
        case .dialogue:
            return 250
        case .general, .titlePage:
            return contentWidth
        }
    }

    /// Get the left margin for an element type
    private static func leftMarginForElement(_ element: ScriptElement) -> CGFloat {
        switch element.type {
        case .sceneHeading, .action, .transition, .shot, .general:
            return leftMargin
        case .character:
            return leftMargin + 144  // Character names are centered-ish
        case .parenthetical:
            return leftMargin + 108
        case .dialogue:
            return leftMargin + 72
        case .titlePage:
            return leftMargin
        }
    }

    // MARK: - Drawing

    private static func drawHeader(_ text: String, at y: inout CGFloat, pageNumber: Int, totalPages: Int) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: boldFont,
            .foregroundColor: NSColor.black
        ]

        let headerStr = NSAttributedString(string: text.uppercased(), attributes: attrs)
        headerStr.draw(at: CGPoint(x: leftMargin, y: pageHeight - 50))
    }

    private static func drawElement(_ element: ScriptElement, at y: CGFloat, options: ScriptSidesOptions) -> CGFloat {
        var currentY = y
        let lineHeight: CGFloat = 14

        // Scene number in margin
        if element.type == .sceneHeading && options.includeSceneNumbers {
            if let sceneNum = element.sceneNumber {
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: boldFont,
                    .foregroundColor: NSColor.black
                ]
                let numStr = NSAttributedString(string: sceneNum, attributes: numAttrs)

                // Left margin
                numStr.draw(at: CGPoint(x: leftMargin - 50, y: currentY - lineHeight))

                // Right margin
                numStr.draw(at: CGPoint(x: pageWidth - rightMargin + 10, y: currentY - lineHeight))
            }
        }

        // Element text
        let font = element.type == .sceneHeading ? boldFont : bodyFont
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let text = element.displayText
        let x = leftMarginForElement(element)
        let maxWidth = widthForElement(element)

        // Word wrap the text
        let lines = wordWrap(text, maxWidth: maxWidth, font: font)

        for line in lines {
            let lineStr = NSAttributedString(string: line, attributes: attrs)
            lineStr.draw(at: CGPoint(x: x, y: currentY - lineHeight))
            currentY -= lineHeight
        }

        // Add spacing after element
        let spacing: CGFloat
        switch element.type {
        case .sceneHeading:
            spacing = 14
        case .character:
            spacing = 0
        case .parenthetical:
            spacing = 0
        case .dialogue:
            spacing = 14
        case .action:
            spacing = 14
        default:
            spacing = 14
        }

        return currentY - spacing
    }

    private static func drawPageNumber(_ pageNumber: Int, totalPages: Int) {
        let text = "\(pageNumber)."
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]
        let pageStr = NSAttributedString(string: text, attributes: attrs)

        // Top right corner
        let x = pageWidth - rightMargin - 20
        pageStr.draw(at: CGPoint(x: x, y: pageHeight - 50))
    }

    /// Word wrap text to fit within a width
    private static func wordWrap(_ text: String, maxWidth: CGFloat, font: NSFont) -> [String] {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var lines: [String] = []
        var currentLine = ""

        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)

        for word in words {
            let testLine = currentLine.isEmpty ? word : currentLine + " " + word
            let testWidth = NSAttributedString(string: testLine, attributes: attrs).size().width

            if testWidth > maxWidth && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = word
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [""] : lines
    }

    // MARK: - Export with Panel

    /// Show save panel and export sides to PDF
    static func exportWithPanel(
        document: ScreenplayDocument,
        options: ScriptSidesOptions,
        context: NSManagedObjectContext? = nil
    ) {
        guard let pdfData = generateSides(document: document, options: options, context: context) else {
            print("[ScriptSidesGenerator] Failed to generate sides PDF")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export Script Sides"

        let filename: String
        switch options.filterType {
        case .scenes:
            filename = "\(document.title) - Sides (Scenes).pdf"
        case .character:
            filename = "\(document.title) - Sides (\(options.characterName ?? "Character")).pdf"
        case .shootDay:
            filename = "\(document.title) - Sides (Shoot Day).pdf"
        }

        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = [.pdf]

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try pdfData.write(to: url)
                    NSWorkspace.shared.open(url)
                } catch {
                    print("[ScriptSidesGenerator] Failed to write PDF: \(error)")
                }
            }
        }
    }
}

#endif
