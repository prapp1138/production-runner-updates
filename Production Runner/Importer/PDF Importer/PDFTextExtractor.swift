//
//  PDFTextExtractor.swift
//  Production Runner
//
//  Core text extraction engine for screenplay PDFs.
//  Extracts text with position data for element classification.
//

import Foundation
import PDFKit

// MARK: - Extracted Text Line

/// Represents a single line of text extracted from a PDF with position metadata
public struct PDFTextLine: Identifiable, Equatable {
    public let id = UUID()

    /// The text content of this line
    public let text: String

    /// X position from left edge of page (in points)
    public let x: CGFloat

    /// Y position from top of page (in points)
    public let y: CGFloat

    /// Width of the text bounds
    public let width: CGFloat

    /// Height of the text bounds
    public let height: CGFloat

    /// Page number (1-indexed)
    public let pageNumber: Int

    /// Font size detected (approximate)
    public let fontSize: CGFloat

    /// Whether this text appears to be bold
    public let isBold: Bool

    /// Whether this text is ALL CAPS
    public var isAllCaps: Bool {
        let letters = text.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { $0.isUppercase }
    }

    /// Left indent from standard screenplay left margin (108pt)
    public var leftIndent: CGFloat {
        max(0, x - 108)
    }

    /// Trimmed text content
    public var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(
        text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        pageNumber: Int,
        fontSize: CGFloat = 12,
        isBold: Bool = false
    ) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.pageNumber = pageNumber
        self.fontSize = fontSize
        self.isBold = isBold
    }
}

// MARK: - Page Extraction Result

/// Result of extracting text from a single PDF page
public struct PDFPageExtractionResult {
    /// Page number (1-indexed)
    public let pageNumber: Int

    /// All text lines extracted from this page
    public let lines: [PDFTextLine]

    /// Page width in points
    public let pageWidth: CGFloat

    /// Page height in points
    public let pageHeight: CGFloat

    /// Detected page number text (if found in header/footer)
    public let detectedPageNumberText: String?

    public init(
        pageNumber: Int,
        lines: [PDFTextLine],
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        detectedPageNumberText: String? = nil
    ) {
        self.pageNumber = pageNumber
        self.lines = lines
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.detectedPageNumberText = detectedPageNumberText
    }
}

// MARK: - Full Extraction Result

/// Complete result of extracting text from a PDF
public struct PDFExtractionResult {
    /// Source file URL
    public let sourceURL: URL?

    /// Total page count
    public let pageCount: Int

    /// Results for each page
    public let pages: [PDFPageExtractionResult]

    /// All lines across all pages, in reading order
    public var allLines: [PDFTextLine] {
        pages.flatMap { $0.lines }
    }

    /// Document title (from PDF metadata if available)
    public let title: String?

    /// Document author (from PDF metadata if available)
    public let author: String?

    public init(
        sourceURL: URL?,
        pageCount: Int,
        pages: [PDFPageExtractionResult],
        title: String? = nil,
        author: String? = nil
    ) {
        self.sourceURL = sourceURL
        self.pageCount = pageCount
        self.pages = pages
        self.title = title
        self.author = author
    }
}

// MARK: - PDF Text Extractor

/// Main extractor class for getting text with position data from screenplay PDFs
public final class PDFTextExtractor {

    public static let shared = PDFTextExtractor()

    // MARK: - Configuration

    /// Standard screenplay page dimensions
    private let standardPageWidth: CGFloat = 612   // 8.5"
    private let standardPageHeight: CGFloat = 792  // 11"

    /// Margin thresholds for detecting page numbers
    private let headerFooterMargin: CGFloat = 72   // 1 inch

    /// Minimum line height to consider (filters out noise)
    private let minLineHeight: CGFloat = 6

    /// Maximum characters to consider as a page number
    private let maxPageNumberLength = 6

    // MARK: - Public API

    /// Extract text with position data from a PDF file
    /// - Parameter url: URL of the PDF file
    /// - Returns: Extraction result with all text lines and metadata
    public func extract(from url: URL) throws -> PDFExtractionResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw PDFExtractionError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else {
            throw PDFExtractionError.invalidPDF
        }

        return try extract(from: document, sourceURL: url)
    }

    /// Extract text with position data from a PDFDocument
    /// - Parameters:
    ///   - document: The PDFDocument to extract from
    ///   - sourceURL: Optional source URL for metadata
    /// - Returns: Extraction result with all text lines and metadata
    public func extract(from document: PDFDocument, sourceURL: URL? = nil) throws -> PDFExtractionResult {
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw PDFExtractionError.emptyDocument
        }

        var pages: [PDFPageExtractionResult] = []
        pages.reserveCapacity(pageCount)

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let pageResult = extractPage(page, pageNumber: pageIndex + 1)
            pages.append(pageResult)
        }

        // Extract metadata
        let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        let author = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        return PDFExtractionResult(
            sourceURL: sourceURL,
            pageCount: pageCount,
            pages: pages,
            title: title,
            author: author
        )
    }

    // MARK: - Page Extraction

    private func extractPage(_ page: PDFPage, pageNumber: Int) -> PDFPageExtractionResult {
        let bounds = page.bounds(for: .mediaBox)
        var lines: [PDFTextLine] = []
        var detectedPageNumber: String? = nil

        // Get the full page text and selection
        guard let pageContent = page.string, !pageContent.isEmpty else {
            return PDFPageExtractionResult(
                pageNumber: pageNumber,
                lines: [],
                pageWidth: bounds.width,
                pageHeight: bounds.height,
                detectedPageNumberText: nil
            )
        }

        // Strategy 1: Line-by-line extraction using selections
        let extractedLines = extractLinesUsingSelection(from: page, bounds: bounds)

        // Strategy 2: If selection-based extraction fails, fall back to text parsing
        if extractedLines.isEmpty {
            let fallbackLines = extractLinesUsingTextParsing(
                pageContent,
                pageNumber: pageNumber,
                bounds: bounds
            )
            lines = fallbackLines
        } else {
            lines = extractedLines.map { selectionLine in
                PDFTextLine(
                    text: selectionLine.text,
                    x: selectionLine.bounds.origin.x,
                    y: bounds.height - selectionLine.bounds.maxY, // Convert to top-origin
                    width: selectionLine.bounds.width,
                    height: selectionLine.bounds.height,
                    pageNumber: pageNumber,
                    fontSize: estimateFontSize(from: selectionLine.bounds.height),
                    isBold: false
                )
            }
        }

        // Sort lines by Y position (top to bottom), then X (left to right)
        lines.sort { a, b in
            if abs(a.y - b.y) < 5 { // Same line threshold
                return a.x < b.x
            }
            return a.y < b.y
        }

        // Detect page number from header/footer
        detectedPageNumber = detectPageNumber(in: lines, pageHeight: bounds.height)

        return PDFPageExtractionResult(
            pageNumber: pageNumber,
            lines: lines,
            pageWidth: bounds.width,
            pageHeight: bounds.height,
            detectedPageNumberText: detectedPageNumber
        )
    }

    // MARK: - Selection-Based Extraction

    private struct SelectionLine {
        let text: String
        let bounds: CGRect
    }

    private func extractLinesUsingSelection(from page: PDFPage, bounds: CGRect) -> [SelectionLine] {
        var lines: [SelectionLine] = []

        guard let pageContent = page.string else { return [] }

        // Split content into lines
        let textLines = pageContent.components(separatedBy: .newlines)

        var searchStart = pageContent.startIndex

        for lineText in textLines {
            let trimmed = lineText.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Find this text in the page
            if let range = pageContent.range(of: lineText, range: searchStart..<pageContent.endIndex) {
                // Get selection for this range
                let nsRange = NSRange(range, in: pageContent)
                if let selection = page.selection(for: nsRange) {
                    let selBounds = selection.bounds(for: page)
                    if selBounds.height >= minLineHeight {
                        lines.append(SelectionLine(text: trimmed, bounds: selBounds))
                    }
                }
                searchStart = range.upperBound
            }
        }

        return lines
    }

    // MARK: - Text Parsing Fallback

    private func extractLinesUsingTextParsing(
        _ content: String,
        pageNumber: Int,
        bounds: CGRect
    ) -> [PDFTextLine] {
        var lines: [PDFTextLine] = []
        let textLines = content.components(separatedBy: .newlines)

        // Estimate line positions based on standard screenplay formatting
        let lineHeight: CGFloat = 12
        var currentY: CGFloat = 72 // Start after top margin

        for lineText in textLines {
            let trimmed = lineText.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                currentY += lineHeight
                continue
            }

            // Estimate X position based on leading spaces
            let leadingSpaces = lineText.prefix(while: { $0 == " " }).count
            let estimatedX: CGFloat = 108 + CGFloat(leadingSpaces) * 7.2 // Approx char width in Courier 12pt

            lines.append(PDFTextLine(
                text: trimmed,
                x: estimatedX,
                y: currentY,
                width: CGFloat(trimmed.count) * 7.2,
                height: lineHeight,
                pageNumber: pageNumber,
                fontSize: 12,
                isBold: false
            ))

            currentY += lineHeight
        }

        return lines
    }

    // MARK: - Utilities

    private func estimateFontSize(from height: CGFloat) -> CGFloat {
        // Standard screenplay uses Courier 12pt which renders at ~12pt height
        if height >= 10 && height <= 14 {
            return 12
        }
        return max(8, min(24, height))
    }

    private func detectPageNumber(in lines: [PDFTextLine], pageHeight: CGFloat) -> String? {
        // Page numbers typically appear in top-right corner
        // Look for short numeric text near the top of the page

        for line in lines {
            // Check if in header area (top 1 inch)
            guard line.y < headerFooterMargin else { continue }

            let text = line.trimmedText

            // Check if it looks like a page number
            guard text.count <= maxPageNumberLength else { continue }

            // Must contain at least one digit
            guard text.rangeOfCharacter(from: .decimalDigits) != nil else { continue }

            // Common page number patterns: "1", "1.", "Page 1", "1 of 120"
            let pageNumPatterns = [
                #"^\d+\.?$"#,                    // "1" or "1."
                #"^Page\s*\d+$"#,                // "Page 1"
                #"^\d+\s*of\s*\d+$"#,            // "1 of 120"
                #"^\d+[A-Z]?\.?$"#               // "12A" or "12A."
            ]

            for pattern in pageNumPatterns {
                if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    // Extract just the number
                    let digits = text.filter { $0.isNumber || $0.isLetter }
                    if !digits.isEmpty {
                        return digits
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - Errors

public enum PDFExtractionError: Error, LocalizedError {
    case accessDenied
    case invalidPDF
    case emptyDocument
    case extractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to PDF file."
        case .invalidPDF:
            return "The file is not a valid PDF document."
        case .emptyDocument:
            return "The PDF document is empty."
        case .extractionFailed(let reason):
            return "Text extraction failed: \(reason)"
        }
    }
}
