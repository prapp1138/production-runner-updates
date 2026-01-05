//
//  OneLinerPDF.swift
//  Production Runner
//
//  PDF generator for One-Liner Schedule reports.
//  Generates a landscape PDF with condensed scene information grouped by shoot day.
//

import SwiftUI
import PDFKit
import CoreGraphics

#if os(macOS)
import AppKit

/// Generates PDF reports for One-Liner Schedules
public struct OneLinerPDF {

    // MARK: - Page Configuration (Landscape)

    private static let pageWidth: CGFloat = 11 * 72   // 792 points (11 inches)
    private static let pageHeight: CGFloat = 8.5 * 72 // 612 points (8.5 inches)
    private static let margin: CGFloat = 36           // 0.5 inch margins
    private static let contentWidth: CGFloat = pageWidth - (margin * 2)
    private static let contentHeight: CGFloat = pageHeight - (margin * 2)

    // MARK: - Grid Configuration

    private static let headerHeight: CGFloat = 24
    private static let rowHeight: CGFloat = 18
    private static let dayHeaderHeight: CGFloat = 26

    // Column widths
    private static let sceneColumnWidth: CGFloat = 50
    private static let intExtColumnWidth: CGFloat = 40
    private static let setColumnWidth: CGFloat = 200
    private static let dayNightColumnWidth: CGFloat = 50
    private static let pagesColumnWidth: CGFloat = 50
    private static let castColumnWidth: CGFloat = 100
    private static let locationColumnWidth: CGFloat = 180  // Remaining space

    // MARK: - Colors

    private static let headerBackground = NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)  // Blue
    private static let dayHeaderBackground = NSColor(white: 0.9, alpha: 1.0)
    private static let alternateRowBackground = NSColor(white: 0.97, alpha: 1.0)
    private static let borderColor = NSColor(white: 0.7, alpha: 1.0)
    private static let textColor = NSColor.black
    private static let secondaryTextColor = NSColor.darkGray

    // MARK: - Fonts

    private static let titleFont = NSFont.boldSystemFont(ofSize: 14)
    private static let subtitleFont = NSFont.systemFont(ofSize: 9)
    private static let headerFont = NSFont.boldSystemFont(ofSize: 8)
    private static let dayHeaderFont = NSFont.boldSystemFont(ofSize: 10)
    private static let bodyFont = NSFont.systemFont(ofSize: 8)
    private static let sceneFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .medium)

    // MARK: - Public API

    /// Generate a PDF document from a one-liner schedule
    public static func generatePDF(from schedule: OneLinerSchedule) -> PDFDocument? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = pageRect
        let pdfInfo: [String: Any] = [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "One-Liner Schedule - \(schedule.productionName)"
        ]

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfInfo as CFDictionary) else {
            return nil
        }

        // Flatten all items with day headers for pagination
        var allRows: [(type: RowType, data: Any)] = []
        for day in schedule.days {
            allRows.append((.dayHeader, day))
            for item in day.items {
                allRows.append((.scene, item))
            }
        }

        // Calculate rows per page
        let availableHeight = contentHeight - 60 // Title area
        let rowsPerPage = Int((availableHeight - headerHeight) / rowHeight)

        // Paginate
        var currentRow = 0
        var pageNumber = 1
        let totalPages = max(1, (allRows.count + rowsPerPage - 1) / rowsPerPage)

        while currentRow < allRows.count {
            pdfContext.beginPDFPage(nil)

            let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
            NSGraphicsContext.current = nsContext

            let endRow = min(currentRow + rowsPerPage, allRows.count)
            let pageRows = Array(allRows[currentRow..<endRow])

            drawPage(
                context: pdfContext,
                schedule: schedule,
                rows: pageRows,
                pageNumber: pageNumber,
                totalPages: totalPages
            )

            NSGraphicsContext.current = nil
            pdfContext.endPDFPage()

            currentRow = endRow
            pageNumber += 1
        }

        pdfContext.closePDF()

        return PDFDocument(data: pdfData as Data)
    }

    // MARK: - Row Type

    private enum RowType {
        case dayHeader
        case scene
    }

    // MARK: - Page Drawing

    private static func drawPage(
        context: CGContext,
        schedule: OneLinerSchedule,
        rows: [(type: RowType, data: Any)],
        pageNumber: Int,
        totalPages: Int
    ) {
        var yPosition = pageHeight - margin

        // Draw title area
        yPosition = drawTitle(
            context: context,
            productionName: schedule.productionName,
            generatedDate: schedule.generatedDate,
            pageNumber: pageNumber,
            totalPages: totalPages,
            at: yPosition
        )

        yPosition -= 10

        // Draw column headers
        yPosition = drawColumnHeaders(context: context, at: yPosition)

        // Draw rows
        var rowIndex = 0
        for row in rows {
            switch row.type {
            case .dayHeader:
                if let day = row.data as? OneLinerDay {
                    yPosition = drawDayHeader(context: context, day: day, at: yPosition)
                }
            case .scene:
                if let item = row.data as? OneLinerItem {
                    let isAlternate = rowIndex % 2 == 1
                    yPosition = drawSceneRow(context: context, item: item, at: yPosition, isAlternate: isAlternate)
                    rowIndex += 1
                }
            }
        }
    }

    // MARK: - Title Drawing

    private static func drawTitle(
        context: CGContext,
        productionName: String,
        generatedDate: Date,
        pageNumber: Int,
        totalPages: Int,
        at yPosition: CGFloat
    ) -> CGFloat {
        // "ONE-LINER SCHEDULE" (left)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor
        ]
        let titleString = NSAttributedString(string: "ONE-LINER SCHEDULE", attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: margin, y: yPosition - 16))

        // Production name (center)
        let prodAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor
        ]
        let prodString = NSAttributedString(string: productionName, attributes: prodAttributes)
        let prodWidth = prodString.size().width
        prodString.draw(at: CGPoint(x: (pageWidth - prodWidth) / 2, y: yPosition - 16))

        // Page number (right)
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: secondaryTextColor
        ]
        let pageString = NSAttributedString(string: "Page \(pageNumber) of \(totalPages)", attributes: pageAttributes)
        let pageWidth = pageString.size().width
        pageString.draw(at: CGPoint(x: self.pageWidth - margin - pageWidth, y: yPosition - 14))

        // Date (right, below page)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = NSAttributedString(string: dateFormatter.string(from: generatedDate), attributes: pageAttributes)
        let dateWidth = dateString.size().width
        dateString.draw(at: CGPoint(x: self.pageWidth - margin - dateWidth, y: yPosition - 26))

        return yPosition - 35
    }

    // MARK: - Column Headers

    private static func drawColumnHeaders(context: CGContext, at yPosition: CGFloat) -> CGFloat {
        let headerY = yPosition - headerHeight

        // Background
        context.setFillColor(headerBackground.cgColor)
        context.fill(CGRect(x: margin, y: headerY, width: contentWidth, height: headerHeight))

        // Text
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor.white
        ]

        var x = margin + 4

        // SC #
        NSAttributedString(string: "SC #", attributes: headerAttrs)
            .draw(at: CGPoint(x: x, y: headerY + 7))
        x += sceneColumnWidth

        // I/E
        NSAttributedString(string: "I/E", attributes: headerAttrs)
            .draw(at: CGPoint(x: x, y: headerY + 7))
        x += intExtColumnWidth

        // SET DESCRIPTION
        NSAttributedString(string: "SET DESCRIPTION", attributes: headerAttrs)
            .draw(at: CGPoint(x: x, y: headerY + 7))
        x += setColumnWidth

        // D/N
        NSAttributedString(string: "D/N", attributes: headerAttrs)
            .draw(at: CGPoint(x: x, y: headerY + 7))
        x += dayNightColumnWidth

        // PAGES
        NSAttributedString(string: "PAGES", attributes: headerAttrs)
            .draw(at: CGPoint(x: x, y: headerY + 7))
        x += pagesColumnWidth

        // CAST
        NSAttributedString(string: "CAST", attributes: headerAttrs)
            .draw(at: CGPoint(x: x, y: headerY + 7))
        x += castColumnWidth

        // LOCATION
        NSAttributedString(string: "LOCATION", attributes: headerAttrs)
            .draw(at: CGPoint(x: x, y: headerY + 7))

        return headerY
    }

    // MARK: - Day Header

    private static func drawDayHeader(context: CGContext, day: OneLinerDay, at yPosition: CGFloat) -> CGFloat {
        let headerY = yPosition - dayHeaderHeight

        // Background
        context.setFillColor(dayHeaderBackground.cgColor)
        context.fill(CGRect(x: margin, y: headerY, width: contentWidth, height: dayHeaderHeight))

        // Border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1)
        context.stroke(CGRect(x: margin, y: headerY, width: contentWidth, height: dayHeaderHeight))

        // Day info (left)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let dayText = "DAY \(day.dayNumber) - \(dateFormatter.string(from: day.date))"

        let dayAttrs: [NSAttributedString.Key: Any] = [
            .font: dayHeaderFont,
            .foregroundColor: textColor
        ]
        NSAttributedString(string: dayText, attributes: dayAttrs)
            .draw(at: CGPoint(x: margin + 8, y: headerY + 8))

        // Total (right)
        let totalAttrs: [NSAttributedString.Key: Any] = [
            .font: dayHeaderFont,
            .foregroundColor: NSColor.systemBlue
        ]
        let totalText = "TOTAL: \(day.totalPagesString)"
        let totalString = NSAttributedString(string: totalText, attributes: totalAttrs)
        let totalWidth = totalString.size().width
        totalString.draw(at: CGPoint(x: pageWidth - margin - totalWidth - 8, y: headerY + 8))

        return headerY
    }

    // MARK: - Scene Row

    private static func drawSceneRow(
        context: CGContext,
        item: OneLinerItem,
        at yPosition: CGFloat,
        isAlternate: Bool
    ) -> CGFloat {
        let rowY = yPosition - rowHeight

        // Alternate background
        if isAlternate {
            context.setFillColor(alternateRowBackground.cgColor)
            context.fill(CGRect(x: margin, y: rowY, width: contentWidth, height: rowHeight))
        }

        // Bottom border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: rowY))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: rowY))
        context.strokePath()

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: textColor
        ]

        let sceneAttrs: [NSAttributedString.Key: Any] = [
            .font: sceneFont,
            .foregroundColor: textColor
        ]

        var x = margin + 4

        // Scene number
        NSAttributedString(string: item.sceneNumber, attributes: sceneAttrs)
            .draw(at: CGPoint(x: x, y: rowY + 5))
        x += sceneColumnWidth

        // INT/EXT
        NSAttributedString(string: item.intExt, attributes: bodyAttrs)
            .draw(at: CGPoint(x: x, y: rowY + 5))
        x += intExtColumnWidth

        // Set description (truncate if needed)
        let setDesc = truncateString(item.setDescription, toWidth: setColumnWidth - 8, font: bodyFont)
        NSAttributedString(string: setDesc, attributes: bodyAttrs)
            .draw(at: CGPoint(x: x, y: rowY + 5))
        x += setColumnWidth

        // Day/Night
        NSAttributedString(string: item.dayNight, attributes: bodyAttrs)
            .draw(at: CGPoint(x: x, y: rowY + 5))
        x += dayNightColumnWidth

        // Pages
        NSAttributedString(string: item.pages, attributes: bodyAttrs)
            .draw(at: CGPoint(x: x, y: rowY + 5))
        x += pagesColumnWidth

        // Cast
        let castStr = truncateString(item.cast, toWidth: castColumnWidth - 8, font: bodyFont)
        NSAttributedString(string: castStr, attributes: bodyAttrs)
            .draw(at: CGPoint(x: x, y: rowY + 5))
        x += castColumnWidth

        // Location
        let locStr = truncateString(item.location, toWidth: locationColumnWidth - 8, font: bodyFont)
        NSAttributedString(string: locStr, attributes: bodyAttrs)
            .draw(at: CGPoint(x: x, y: rowY + 5))

        return rowY
    }

    // MARK: - Helpers

    private static func truncateString(_ string: String, toWidth maxWidth: CGFloat, font: NSFont) -> String {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var result = string

        while NSAttributedString(string: result, attributes: attrs).size().width > maxWidth && result.count > 3 {
            result = String(result.dropLast(4)) + "..."
        }

        return result
    }
}

#endif
