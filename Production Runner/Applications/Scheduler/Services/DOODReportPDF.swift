//
//  DOODReportPDF.swift
//  Production Runner
//
//  PDF generator for Day Out of Days (DOOD) reports.
//  Generates industry-standard landscape PDF with cast/day grid.
//

import SwiftUI
import PDFKit
import CoreGraphics

#if os(macOS)
import AppKit

/// Generates PDF reports for Day Out of Days
public struct DOODReportPDF {

    // MARK: - Page Configuration (Landscape)

    private static let pageWidth: CGFloat = 11 * 72   // 792 points (11 inches)
    private static let pageHeight: CGFloat = 8.5 * 72 // 612 points (8.5 inches)
    private static let margin: CGFloat = 36           // 0.5 inch margins
    private static let contentWidth: CGFloat = pageWidth - (margin * 2)
    private static let contentHeight: CGFloat = pageHeight - (margin * 2)

    // MARK: - Grid Configuration

    private static let headerHeight: CGFloat = 60
    private static let rowHeight: CGFloat = 24
    private static let castColumnWidth: CGFloat = 180
    private static let summaryColumnWidth: CGFloat = 60
    private static let minDayColumnWidth: CGFloat = 36
    private static let maxDayColumnWidth: CGFloat = 50

    // MARK: - Colors

    private static let headerBackground = NSColor(white: 0.95, alpha: 1.0)
    private static let alternateRowBackground = NSColor(white: 0.98, alpha: 1.0)
    private static let borderColor = NSColor(white: 0.7, alpha: 1.0)
    private static let textColor = NSColor.black
    private static let secondaryTextColor = NSColor.darkGray

    // MARK: - Fonts

    private static let titleFont = NSFont.boldSystemFont(ofSize: 16)
    private static let subtitleFont = NSFont.systemFont(ofSize: 10)
    private static let headerFont = NSFont.boldSystemFont(ofSize: 9)
    private static let bodyFont = NSFont.systemFont(ofSize: 8)
    private static let statusFont = NSFont.boldSystemFont(ofSize: 8)
    private static let legendFont = NSFont.systemFont(ofSize: 7)

    // MARK: - Public API

    /// Generate a PDF document from DOOD report data
    public static func generatePDF(from data: DOODReportData) -> PDFDocument? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = pageRect
        let pdfInfo: [String: Any] = [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "Day Out of Days - \(data.productionName)"
        ]

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfInfo as CFDictionary) else {
            return nil
        }

        // Calculate how many days fit per page
        let availableWidth = contentWidth - castColumnWidth - summaryColumnWidth
        let dayColumnWidth = min(maxDayColumnWidth, max(minDayColumnWidth, availableWidth / CGFloat(max(1, data.shootDays.count))))
        let daysPerPage = Int(availableWidth / dayColumnWidth)

        // Calculate how many cast members fit per page
        let availableHeight = contentHeight - headerHeight - 80 // 80 for title + legend
        let castPerPage = Int(availableHeight / rowHeight)

        // Generate pages
        let totalDayPages = (data.shootDays.count + daysPerPage - 1) / daysPerPage
        let totalCastPages = (data.castMembers.count + castPerPage - 1) / castPerPage

        for castPageIndex in 0..<totalCastPages {
            for dayPageIndex in 0..<totalDayPages {
                pdfContext.beginPDFPage(nil)

                let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
                NSGraphicsContext.current = nsContext

                let castStartIndex = castPageIndex * castPerPage
                let castEndIndex = min(castStartIndex + castPerPage, data.castMembers.count)
                let dayStartIndex = dayPageIndex * daysPerPage
                let dayEndIndex = min(dayStartIndex + daysPerPage, data.shootDays.count)

                let castSlice = Array(data.castMembers[castStartIndex..<castEndIndex])
                let daySlice = Array(data.shootDays[dayStartIndex..<dayEndIndex])
                let statsSlice = Array(data.stats[castStartIndex..<castEndIndex])

                // Build status grid slice
                var statusSlice: [[DOODStatus]] = []
                for castIndex in castStartIndex..<castEndIndex {
                    var row: [DOODStatus] = []
                    for dayIndex in dayStartIndex..<dayEndIndex {
                        if castIndex < data.statusGrid.count && dayIndex < data.statusGrid[castIndex].count {
                            row.append(data.statusGrid[castIndex][dayIndex])
                        } else {
                            row.append(.none)
                        }
                    }
                    statusSlice.append(row)
                }

                let pageNumber = castPageIndex * totalDayPages + dayPageIndex + 1
                let totalPages = totalCastPages * totalDayPages

                drawPage(
                    context: pdfContext,
                    data: data,
                    castMembers: castSlice,
                    shootDays: daySlice,
                    statusGrid: statusSlice,
                    stats: statsSlice,
                    castStartIndex: castStartIndex,
                    dayColumnWidth: dayColumnWidth,
                    pageNumber: pageNumber,
                    totalPages: totalPages
                )

                NSGraphicsContext.current = nil
                pdfContext.endPDFPage()
            }
        }

        pdfContext.closePDF()

        return PDFDocument(data: pdfData as Data)
    }

    // MARK: - Page Drawing

    private static func drawPage(
        context: CGContext,
        data: DOODReportData,
        castMembers: [DOODCastMember],
        shootDays: [DOODShootDay],
        statusGrid: [[DOODStatus]],
        stats: [DOODCastStats],
        castStartIndex: Int,
        dayColumnWidth: CGFloat,
        pageNumber: Int,
        totalPages: Int
    ) {
        var yPosition = pageHeight - margin

        // Draw title area
        yPosition = drawTitle(
            context: context,
            productionName: data.productionName,
            generatedDate: data.generatedDate,
            pageNumber: pageNumber,
            totalPages: totalPages,
            at: yPosition
        )

        yPosition -= 15

        // Draw the grid
        let gridWidth = castColumnWidth + (CGFloat(shootDays.count) * dayColumnWidth) + summaryColumnWidth
        let gridStartX = margin

        // Draw header row
        yPosition = drawHeaderRow(
            context: context,
            shootDays: shootDays,
            startX: gridStartX,
            at: yPosition,
            dayColumnWidth: dayColumnWidth
        )

        // Draw data rows
        for (rowIndex, castMember) in castMembers.enumerated() {
            let statusRow = rowIndex < statusGrid.count ? statusGrid[rowIndex] : []
            let stat = rowIndex < stats.count ? stats[rowIndex] : DOODCastStats()
            let castNumber = castStartIndex + rowIndex + 1
            let isAlternate = rowIndex % 2 == 1

            yPosition = drawDataRow(
                context: context,
                castMember: castMember,
                castNumber: castNumber,
                statusRow: statusRow,
                stats: stat,
                startX: gridStartX,
                at: yPosition,
                dayColumnWidth: dayColumnWidth,
                isAlternate: isAlternate
            )
        }

        // Draw bottom border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: gridStartX, y: yPosition))
        context.addLine(to: CGPoint(x: gridStartX + gridWidth, y: yPosition))
        context.strokePath()

        // Draw legend at bottom
        drawLegend(context: context, at: margin + 20)
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
        // Production name (left)
        let prodAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor
        ]
        let prodString = NSAttributedString(string: productionName, attributes: prodAttributes)
        prodString.draw(at: CGPoint(x: margin, y: yPosition - 18))

        // "DAY OUT OF DAYS" (center)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor
        ]
        let titleString = NSAttributedString(string: "DAY OUT OF DAYS", attributes: titleAttributes)
        let titleWidth = titleString.size().width
        titleString.draw(at: CGPoint(x: (pageWidth - titleWidth) / 2, y: yPosition - 18))

        // Date and page (right)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = "Generated: \(dateFormatter.string(from: generatedDate))"
        let pageString = "Page \(pageNumber) of \(totalPages)"

        let rightAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: secondaryTextColor
        ]

        let dateAttr = NSAttributedString(string: dateString, attributes: rightAttributes)
        let pageAttr = NSAttributedString(string: pageString, attributes: rightAttributes)

        dateAttr.draw(at: CGPoint(x: pageWidth - margin - dateAttr.size().width, y: yPosition - 14))
        pageAttr.draw(at: CGPoint(x: pageWidth - margin - pageAttr.size().width, y: yPosition - 26))

        return yPosition - 35
    }

    // MARK: - Header Row Drawing

    private static func drawHeaderRow(
        context: CGContext,
        shootDays: [DOODShootDay],
        startX: CGFloat,
        at yPosition: CGFloat,
        dayColumnWidth: CGFloat
    ) -> CGFloat {
        let headerY = yPosition - headerHeight

        // Background
        context.setFillColor(headerBackground.cgColor)
        let totalWidth = castColumnWidth + (CGFloat(shootDays.count) * dayColumnWidth) + summaryColumnWidth
        context.fill(CGRect(x: startX, y: headerY, width: totalWidth, height: headerHeight))

        // Border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1)
        context.stroke(CGRect(x: startX, y: headerY, width: totalWidth, height: headerHeight))

        // "CAST MEMBER" header
        let castHeaderAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: textColor
        ]
        let castHeader = NSAttributedString(string: "CAST MEMBER", attributes: castHeaderAttrs)
        castHeader.draw(at: CGPoint(x: startX + 10, y: headerY + headerHeight / 2 - 5))

        // Vertical line after cast column
        context.move(to: CGPoint(x: startX + castColumnWidth, y: headerY))
        context.addLine(to: CGPoint(x: startX + castColumnWidth, y: yPosition))
        context.strokePath()

        // Day headers
        var x = startX + castColumnWidth
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E"
        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "M/d"

        for day in shootDays {
            let dayName = String(dateFormatter.string(from: day.date).prefix(2)).uppercased()
            let dateStr = shortDateFormatter.string(from: day.date)

            // Day number
            let dayNumAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 11),
                .foregroundColor: NSColor.systemBlue
            ]
            let dayNumStr = NSAttributedString(string: "\(day.dayNumber)", attributes: dayNumAttrs)
            let dayNumWidth = dayNumStr.size().width
            dayNumStr.draw(at: CGPoint(x: x + (dayColumnWidth - dayNumWidth) / 2, y: headerY + 38))

            // Day name
            let dayNameAttrs: [NSAttributedString.Key: Any] = [
                .font: legendFont,
                .foregroundColor: secondaryTextColor
            ]
            let dayNameStr = NSAttributedString(string: dayName, attributes: dayNameAttrs)
            let dayNameWidth = dayNameStr.size().width
            dayNameStr.draw(at: CGPoint(x: x + (dayColumnWidth - dayNameWidth) / 2, y: headerY + 24))

            // Date
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: legendFont,
                .foregroundColor: textColor
            ]
            let dateAttr = NSAttributedString(string: dateStr, attributes: dateAttrs)
            let dateWidth = dateAttr.size().width
            dateAttr.draw(at: CGPoint(x: x + (dayColumnWidth - dateWidth) / 2, y: headerY + 10))

            // Vertical line
            context.move(to: CGPoint(x: x + dayColumnWidth, y: headerY))
            context.addLine(to: CGPoint(x: x + dayColumnWidth, y: yPosition))
            context.strokePath()

            x += dayColumnWidth
        }

        // Summary header
        let summaryAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: textColor
        ]
        let summaryStr = NSAttributedString(string: "TOTAL", attributes: summaryAttrs)
        let summaryWidth = summaryStr.size().width
        summaryStr.draw(at: CGPoint(x: x + (summaryColumnWidth - summaryWidth) / 2, y: headerY + headerHeight / 2 - 5))

        return headerY
    }

    // MARK: - Data Row Drawing

    private static func drawDataRow(
        context: CGContext,
        castMember: DOODCastMember,
        castNumber: Int,
        statusRow: [DOODStatus],
        stats: DOODCastStats,
        startX: CGFloat,
        at yPosition: CGFloat,
        dayColumnWidth: CGFloat,
        isAlternate: Bool
    ) -> CGFloat {
        let rowY = yPosition - rowHeight
        let totalWidth = castColumnWidth + (CGFloat(statusRow.count) * dayColumnWidth) + summaryColumnWidth

        // Alternate row background
        if isAlternate {
            context.setFillColor(alternateRowBackground.cgColor)
            context.fill(CGRect(x: startX, y: rowY, width: totalWidth, height: rowHeight))
        }

        // Border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: startX, y: rowY, width: totalWidth, height: rowHeight))

        // Cast number + name
        let castAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: textColor
        ]
        let castText = "\(castNumber). \(castMember.name)"
        let castStr = NSAttributedString(string: castText, attributes: castAttrs)
        castStr.draw(at: CGPoint(x: startX + 8, y: rowY + (rowHeight - 10) / 2))

        // Vertical line after cast column
        context.move(to: CGPoint(x: startX + castColumnWidth, y: rowY))
        context.addLine(to: CGPoint(x: startX + castColumnWidth, y: yPosition))
        context.strokePath()

        // Status cells
        var x = startX + castColumnWidth
        for status in statusRow {
            if status != .none {
                // Draw status background
                let cellRect = CGRect(x: x + 2, y: rowY + 2, width: dayColumnWidth - 4, height: rowHeight - 4)
                context.setFillColor(status.nsColor.cgColor)
                context.fill(cellRect)

                // Draw status text
                let statusTextColor = status == .hold || status == .holiday ? NSColor.black : NSColor.white
                let statusAttrs: [NSAttributedString.Key: Any] = [
                    .font: statusFont,
                    .foregroundColor: statusTextColor
                ]
                let statusStr = NSAttributedString(string: status.rawValue, attributes: statusAttrs)
                let statusWidth = statusStr.size().width
                statusStr.draw(at: CGPoint(x: x + (dayColumnWidth - statusWidth) / 2, y: rowY + (rowHeight - 10) / 2))
            }

            // Vertical line
            context.setStrokeColor(borderColor.cgColor)
            context.move(to: CGPoint(x: x + dayColumnWidth, y: rowY))
            context.addLine(to: CGPoint(x: x + dayColumnWidth, y: yPosition))
            context.strokePath()

            x += dayColumnWidth
        }

        // Summary cell
        let totalAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: textColor
        ]
        let totalStr = NSAttributedString(string: "\(stats.total)", attributes: totalAttrs)
        let totalTextWidth = totalStr.size().width
        totalStr.draw(at: CGPoint(x: x + (summaryColumnWidth - totalTextWidth) / 2, y: rowY + (rowHeight - 10) / 2))

        return rowY
    }

    // MARK: - Legend Drawing

    private static func drawLegend(context: CGContext, at yPosition: CGFloat) {
        let legendItems: [(DOODStatus, String)] = [
            (.start, "SW = Start Work"),
            (.work, "W = Work"),
            (.finish, "WF = Work Finish"),
            (.startFinish, "SWF = Start/Finish"),
            (.hold, "H = Hold"),
            (.travel, "T = Travel"),
            (.rehearsal, "R = Rehearsal"),
            (.fitting, "F = Fitting"),
            (.drop, "D = Drop"),
            (.pickup, "P = Pickup")
        ]

        var x = margin
        let y = yPosition

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: legendFont,
            .foregroundColor: secondaryTextColor
        ]

        let legendLabel = NSAttributedString(string: "Legend: ", attributes: labelAttrs)
        legendLabel.draw(at: CGPoint(x: x, y: y))
        x += legendLabel.size().width + 10

        for (status, label) in legendItems {
            // Draw color box
            let boxSize: CGFloat = 10
            context.setFillColor(status.nsColor.cgColor)
            context.fill(CGRect(x: x, y: y, width: boxSize, height: boxSize))
            context.setStrokeColor(borderColor.cgColor)
            context.stroke(CGRect(x: x, y: y, width: boxSize, height: boxSize))
            x += boxSize + 4

            // Draw label
            let itemAttrs: [NSAttributedString.Key: Any] = [
                .font: legendFont,
                .foregroundColor: textColor
            ]
            let itemStr = NSAttributedString(string: label, attributes: itemAttrs)
            itemStr.draw(at: CGPoint(x: x, y: y - 1))
            x += itemStr.size().width + 15

            // Wrap to next line if needed
            if x > pageWidth - margin - 100 {
                x = margin + 50
                // Note: Would need to adjust y for multi-line, but keeping simple for now
            }
        }
    }
}

#endif
