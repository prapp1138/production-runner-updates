//
//  StripboardPDF.swift
//  Production Runner
//
//  PDF generator for Stripboard exports.
//  Generates a visual stripboard PDF with colored strips representing scenes.
//

import SwiftUI
import PDFKit
import CoreGraphics
import CoreData

#if os(macOS)
import AppKit

/// Generates PDF exports of the stripboard
public struct StripboardPDF {

    // MARK: - Orientation

    public enum Orientation {
        case landscape
        case portrait
    }

    // MARK: - Page Configuration

    private static let margin: CGFloat = 36           // 0.5 inch margins

    // MARK: - Strip Configuration

    private static let stripHeight: CGFloat = 24
    private static let stripSpacing: CGFloat = 2
    private static let headerHeight: CGFloat = 40

    // MARK: - Colors

    private static let borderColor = NSColor(white: 0.7, alpha: 1.0)
    private static let textColor = NSColor.black

    // MARK: - Fonts

    private static let titleFont = NSFont.boldSystemFont(ofSize: 16)
    private static let headerFont = NSFont.boldSystemFont(ofSize: 10)
    private static let stripFont = NSFont.systemFont(ofSize: 9)
    private static let sceneNumberFont = NSFont.boldSystemFont(ofSize: 10)

    // MARK: - Public API

    /// Generate a stripboard PDF from scenes
    public static func generatePDF(
        from scenes: [NSManagedObject],
        productionName: String,
        productionStartDate: Date?,
        orientation: Orientation = .landscape
    ) -> PDFDocument? {
        // Calculate page dimensions based on orientation
        let pageWidth: CGFloat
        let pageHeight: CGFloat

        if orientation == .landscape {
            pageWidth = 11 * 72   // 792 points (11 inches)
            pageHeight = 8.5 * 72 // 612 points (8.5 inches)
        } else {
            pageWidth = 8.5 * 72  // 612 points (8.5 inches)
            pageHeight = 11 * 72  // 792 points (11 inches)
        }

        let contentWidth = pageWidth - (margin * 2)
        let contentHeight = pageHeight - (margin * 2)
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = pageRect
        let pdfInfo: [String: Any] = [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "Stripboard - \(productionName)"
        ]

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfInfo as CFDictionary) else {
            return nil
        }

        // Calculate strips per page
        let stripsPerPage = Int((contentHeight - headerHeight) / (stripHeight + stripSpacing))
        let totalPages = (scenes.count + stripsPerPage - 1) / stripsPerPage

        // Generate pages
        for pageNum in 0..<totalPages {
            pdfContext.beginPDFPage(nil)

            // Draw header
            drawHeader(
                context: pdfContext,
                productionName: productionName,
                pageNumber: pageNum + 1,
                totalPages: totalPages,
                pageWidth: pageWidth,
                pageHeight: pageHeight
            )

            // Draw strips for this page
            let startIndex = pageNum * stripsPerPage
            let endIndex = min(startIndex + stripsPerPage, scenes.count)
            let pageScenes = Array(scenes[startIndex..<endIndex])

            drawStrips(
                context: pdfContext,
                scenes: pageScenes,
                startY: margin + headerHeight,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                contentWidth: contentWidth
            )

            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()

        // Convert to PDFDocument
        return PDFDocument(data: pdfData as Data)
    }

    // MARK: - Text Drawing Helper

    private static func drawText(
        _ text: String,
        at point: CGPoint,
        font: NSFont,
        color: NSColor,
        context: CGContext,
        centered: Bool = false
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        var drawPoint = point
        if centered {
            let bounds = CTLineGetBoundsWithOptions(line, [])
            drawPoint.x -= bounds.width / 2
        }

        // Draw using Core Text
        context.textMatrix = CGAffineTransform.identity
        context.textPosition = drawPoint
        CTLineDraw(line, context)
    }

    // MARK: - Color Helpers

    private static func getStripColor(intExt: String, dayNight: String) -> NSColor {
        let ie = intExt.uppercased()
        let t = dayNight.uppercased()

        let isINT = ie.contains("INT") && !ie.contains("EXT")
        let isEXT = ie.contains("EXT")

        // Simplified color scheme
        if isINT {
            if t.contains("NIGHT") { return NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0) } // Blue
            return NSColor(red: 0.95, green: 0.85, blue: 0.7, alpha: 1.0) // Cream
        }
        if isEXT {
            if t.contains("NIGHT") { return NSColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0) } // Dark Blue
            return NSColor(red: 0.95, green: 0.95, blue: 0.7, alpha: 1.0) // Light Yellow
        }

        return NSColor.white
    }

    // MARK: - Drawing Methods

    private static func drawHeader(
        context: CGContext,
        productionName: String,
        pageNumber: Int,
        totalPages: Int,
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) {
        let headerY = pageHeight - margin - headerHeight

        // Production name (larger, centered)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textColor
        ]
        let title = productionName.uppercased() as NSString
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: headerY + 22), withAttributes: titleAttrs)

        // Subtitle "STRIPBOARD" (smaller, centered below)
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: textColor
        ]
        let subtitle = "STRIPBOARD" as NSString
        let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
        subtitle.draw(at: CGPoint(x: (pageWidth - subtitleSize.width) / 2, y: headerY + 8), withAttributes: subtitleAttrs)

        // Page number (right side)
        let pageText = "Page \(pageNumber) of \(totalPages)" as NSString
        let pageAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: textColor
        ]
        let pageSize = pageText.size(withAttributes: pageAttrs)
        pageText.draw(
            at: CGPoint(x: pageWidth - margin - pageSize.width, y: headerY + 18),
            withAttributes: pageAttrs
        )

        // Date (left side)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateText = dateFormatter.string(from: Date()) as NSString
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: textColor
        ]
        dateText.draw(at: CGPoint(x: margin, y: headerY + 18), withAttributes: dateAttrs)

        // Separator line
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: margin, y: headerY))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: headerY))
        context.strokePath()
    }

    private static func drawStrips(
        context: CGContext,
        scenes: [NSManagedObject],
        startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        contentWidth: CGFloat
    ) {
        var currentY = pageHeight - startY - stripHeight

        for scene in scenes {
            // Get scene data
            let sceneNumber = scene.value(forKey: "number") as? String ?? ""
            let sceneHeading = scene.value(forKey: "sceneSlug") as? String ?? ""
            let intExt = scene.value(forKey: "locationType") as? String ?? ""
            let dayNight = scene.value(forKey: "timeOfDay") as? String ?? ""

            // Calculate pages from eighths
            let eighths = (scene.value(forKey: "pageEighths") as? Int16).map(Int.init) ?? 0
            let pages = Double(eighths) / 8.0

            // Determine strip color based on INT/EXT and time of day
            let stripColor = getStripColor(intExt: intExt, dayNight: dayNight)

            // Check if it's a special strip type (day break)
            let isDayBreak = sceneNumber.isEmpty && sceneHeading.isEmpty

            // Draw strip background
            context.setFillColor(stripColor.cgColor)
            let stripRect = CGRect(x: margin, y: currentY, width: contentWidth, height: stripHeight)
            context.fill(stripRect)

            // Draw border
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(0.5)
            context.stroke(stripRect)

            // Draw text (no coordinate transformation needed)
            let baseY = currentY + 6 // Text baseline position

            if isDayBreak {
                // Day break strip - centered text
                drawText("DAY BREAK", at: CGPoint(x: margin + contentWidth / 2, y: baseY),
                        font: NSFont.boldSystemFont(ofSize: 11), color: textColor, context: context, centered: true)
            } else {
                // Regular scene strip
                var xOffset: CGFloat = margin + 8

                // Scene number
                drawText(sceneNumber, at: CGPoint(x: xOffset, y: baseY),
                        font: sceneNumberFont, color: textColor, context: context)
                xOffset += 50

                // INT/EXT
                drawText(intExt, at: CGPoint(x: xOffset, y: baseY),
                        font: stripFont, color: textColor, context: context)
                xOffset += 40

                // Scene Heading
                drawText(sceneHeading, at: CGPoint(x: xOffset, y: baseY),
                        font: stripFont, color: textColor, context: context)
                xOffset += 300

                // Day/Night
                drawText(dayNight, at: CGPoint(x: xOffset, y: baseY),
                        font: stripFont, color: textColor, context: context)
                xOffset += 50

                // Pages
                let pagesText = String(format: "%.1f pgs", pages)
                drawText(pagesText, at: CGPoint(x: xOffset, y: baseY),
                        font: stripFont, color: textColor, context: context)
            }

            currentY -= (stripHeight + stripSpacing)
        }
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }
}

#endif
