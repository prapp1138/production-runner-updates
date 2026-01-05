import SwiftUI
import PDFKit
import CoreData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// PDF Generator for Scene Breakdown Reports
/// Generates a printable 8.5 x 11 inch breakdown sheet for individual scenes
struct BreakdownScenePDF {

    // MARK: - Page Configuration
    private static let pageWidth: CGFloat = 8.5 * 72  // 612 points
    private static let pageHeight: CGFloat = 11 * 72  // 792 points
    private static let margin: CGFloat = 36  // 0.5 inch margins
    private static let contentWidth: CGFloat = pageWidth - (margin * 2)

    // MARK: - Platform Colors
    #if os(macOS)
    private static let labelColor = NSColor.labelColor
    private static let secondaryLabelColor = NSColor.secondaryLabelColor
    private static let separatorColor = NSColor.separatorColor
    #else
    private static let labelColor = UIColor.label
    private static let secondaryLabelColor = UIColor.secondaryLabel
    private static let separatorColor = UIColor.separator
    #endif

    // MARK: - Category Colors
    private static func colorForCategory(_ title: String) -> PlatformColor {
        #if os(macOS)
        switch title.uppercased() {
        case "CAST": return NSColor.systemBlue
        case "EXTRAS": return NSColor.systemMint
        case "PROPS": return NSColor.systemPurple
        case "WARDROBE": return NSColor.systemPink
        case "VEHICLES": return NSColor.systemTeal
        case "MAKEUP": return NSColor.systemGreen
        case "SPFX": return NSColor.systemRed
        case "ART / SET DRESSING": return NSColor.systemBrown
        case "SOUND FX": return NSColor.systemGray
        case "VISUAL EFFECTS": return NSColor.systemCyan
        default: return NSColor.systemGray
        }
        #else
        switch title.uppercased() {
        case "CAST": return UIColor.systemBlue
        case "EXTRAS": return UIColor.systemMint
        case "PROPS": return UIColor.systemPurple
        case "WARDROBE": return UIColor.systemPink
        case "VEHICLES": return UIColor.systemTeal
        case "MAKEUP": return UIColor.systemGreen
        case "SPFX": return UIColor.systemRed
        case "ART / SET DRESSING": return UIColor.systemBrown
        case "SOUND FX": return UIColor.systemGray
        case "VISUAL EFFECTS": return UIColor.systemCyan
        default: return UIColor.systemGray
        }
        #endif
    }

    // MARK: - Public API

    /// Generate a PDF for a scene breakdown
    static func generatePDF(for scene: SceneEntity, context: NSManagedObjectContext) -> PDFDocument? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()

        #if os(macOS)
        // macOS PDF generation using data consumer
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = pageRect
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "Scene \(scene.number ?? "") Breakdown"
        ] as CFDictionary) else { return nil }

        pdfContext.beginPDFPage(nil)

        // Create NSGraphicsContext without flipping - use natural PDF coordinates (bottom-left origin)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition: CGFloat = pageHeight - margin  // Start from top in bottom-up coordinates

        // Draw header
        yPosition = drawHeaderMacOS(scene: scene, at: yPosition, in: pdfContext)
        yPosition -= 20

        // Draw scene information
        yPosition = drawSceneInfoMacOS(scene: scene, at: yPosition, in: pdfContext)
        yPosition -= 20

        // Draw breakdown categories
        if let breakdown = scene.breakdown {
            yPosition = drawBreakdownCategoriesMacOS(breakdown: breakdown, scene: scene, at: yPosition, in: pdfContext)
        }

        NSGraphicsContext.current = nil
        pdfContext.endPDFPage()
        pdfContext.closePDF()

        #else
        // iOS PDF generation
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "Scene \(scene.number ?? "") Breakdown"
        ])

        guard let pdfContext = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            return nil
        }

        UIGraphicsBeginPDFPage()

        var yPosition: CGFloat = margin

        // Draw header
        yPosition = drawHeader(scene: scene, at: yPosition, in: pdfContext)
        yPosition += 20

        // Draw scene information
        yPosition = drawSceneInfo(scene: scene, at: yPosition, in: pdfContext)
        yPosition += 20

        // Draw breakdown categories
        if let breakdown = scene.breakdown {
            yPosition = drawBreakdownCategories(breakdown: breakdown, scene: scene, at: yPosition, in: pdfContext)
        }

        UIGraphicsEndPDFContext()
        #endif

        return PDFDocument(data: pdfData as Data)
    }

    /// Generate a multi-page PDF for all scenes in the script
    static func generateMultiScenePDF(for scenes: [SceneEntity], context: NSManagedObjectContext) -> PDFDocument? {
        guard !scenes.isEmpty else { return nil }

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()

        #if os(macOS)
        // macOS PDF generation using data consumer
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = pageRect
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "Script Breakdown"
        ] as CFDictionary) else { return nil }

        // Generate a page for each scene
        for scene in scenes {
            pdfContext.beginPDFPage(nil)

            // Create NSGraphicsContext without flipping - use natural PDF coordinates (bottom-left origin)
            let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
            NSGraphicsContext.current = nsContext

            var yPosition: CGFloat = pageHeight - margin  // Start from top in bottom-up coordinates

            // Draw header
            yPosition = drawHeaderMacOS(scene: scene, at: yPosition, in: pdfContext)
            yPosition -= 20

            // Draw scene information
            yPosition = drawSceneInfoMacOS(scene: scene, at: yPosition, in: pdfContext)
            yPosition -= 20

            // Draw breakdown categories
            if let breakdown = scene.breakdown {
                yPosition = drawBreakdownCategoriesMacOS(breakdown: breakdown, scene: scene, at: yPosition, in: pdfContext)
            }

            NSGraphicsContext.current = nil
            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()

        #else
        // iOS PDF generation
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, [
            kCGPDFContextCreator as String: "Production Runner",
            kCGPDFContextAuthor as String: "Production Runner",
            kCGPDFContextTitle as String: "Script Breakdown"
        ])

        guard let pdfContext = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            return nil
        }

        // Generate a page for each scene
        for scene in scenes {
            UIGraphicsBeginPDFPage()

            var yPosition: CGFloat = margin

            // Draw header
            yPosition = drawHeader(scene: scene, at: yPosition, in: pdfContext)
            yPosition += 20

            // Draw scene information
            yPosition = drawSceneInfo(scene: scene, at: yPosition, in: pdfContext)
            yPosition += 20

            // Draw breakdown categories
            if let breakdown = scene.breakdown {
                yPosition = drawBreakdownCategories(breakdown: breakdown, scene: scene, at: yPosition, in: pdfContext)
            }
        }

        UIGraphicsEndPDFContext()
        #endif

        return PDFDocument(data: pdfData as Data)
    }

    // MARK: - Drawing Functions

    private static func drawHeader(scene: SceneEntity, at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: PlatformFont.boldSystemFont(ofSize: 24),
            .foregroundColor: labelColor
        ]
        let title = "SCENE BREAKDOWN"
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleX = (pageWidth - titleSize.width) / 2
        titleString.draw(at: CGPoint(x: titleX, y: y))
        y += titleSize.height + 8

        // Scene number
        let sceneNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: PlatformFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: labelColor
        ]
        let sceneNumber = "Scene \(scene.number ?? "—")"
        let sceneNumberString = NSAttributedString(string: sceneNumber, attributes: sceneNumberAttributes)
        let sceneNumberSize = sceneNumberString.size()
        let sceneNumberX = (pageWidth - sceneNumberSize.width) / 2
        sceneNumberString.draw(at: CGPoint(x: sceneNumberX, y: y))
        y += sceneNumberSize.height + 12

        // Divider line
        context.setStrokeColor(separatorColor.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        context.strokePath()
        y += 2

        return y
    }

    private static func drawSceneInfo(scene: SceneEntity, at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition + 12

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: PlatformFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: secondaryLabelColor
        ]

        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: PlatformFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: labelColor
        ]

        // Scene heading
        let locType = scene.locationType ?? "INT."
        let location = scene.scriptLocation ?? "Untitled Scene"
        let tod = scene.timeOfDay ?? "DAY"
        let heading = "\(locType) \(location) - \(tod)"

        y = drawInfoRow(label: "SCENE HEADING:", value: heading, labelAttributes: labelAttributes, valueAttributes: valueAttributes, at: y, in: context)
        y += 6

        // Script Day
        if let scriptDay = scene.scriptDay, !scriptDay.isEmpty {
            y = drawInfoRow(label: "SCRIPT DAY:", value: scriptDay, labelAttributes: labelAttributes, valueAttributes: valueAttributes, at: y, in: context)
            y += 6
        }

        // Page Length
        if let pageEighthsString = scene.pageEighthsString, !pageEighthsString.isEmpty {
            y = drawInfoRow(label: "PAGE LENGTH:", value: pageEighthsString, labelAttributes: labelAttributes, valueAttributes: valueAttributes, at: y, in: context)
            y += 6
        }

        // Description
        if let description = scene.descriptionText, !description.isEmpty {
            y = drawInfoRow(label: "DESCRIPTION:", value: description, labelAttributes: labelAttributes, valueAttributes: valueAttributes, at: y, in: context)
            y += 6
        }

        return y
    }

    private static func drawInfoRow(label: String, value: String, labelAttributes: [NSAttributedString.Key: Any], valueAttributes: [NSAttributedString.Key: Any], at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        let labelWidth: CGFloat = 140

        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        labelString.draw(at: CGPoint(x: margin, y: yPosition))

        // Calculate available width for value
        let valueX = margin + labelWidth
        let valueWidth = contentWidth - labelWidth

        // Draw value with wrapping if needed
        let valueRect = CGRect(x: valueX, y: yPosition, width: valueWidth, height: 1000)
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        let valueBoundingRect = valueString.boundingRect(with: CGSize(width: valueWidth, height: 1000),
                                                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                          context: nil)
        valueString.draw(in: valueRect)

        return yPosition + max(labelString.size().height, valueBoundingRect.height) + 2
    }

    private static func drawBreakdownCategories(breakdown: BreakdownEntity, scene: SceneEntity, at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition + 8

        // Divider line
        context.setStrokeColor(separatorColor.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        context.strokePath()
        y += 16

        // Two-column layout for categories
        let columnWidth = (contentWidth - 16) / 2
        var leftColumnY = y
        var rightColumnY = y
        var isLeftColumn = true

        // Cast Members - always show
        // Load cast members from scene's castMembersJSON
        var castItems: [String] = []
        if let castData = scene.value(forKey: "castMembersJSON") as? String,
           let data = castData.data(using: .utf8),
           let members = try? JSONDecoder().decode([BreakdownCastMember].self, from: data) {
            castItems = members.map { "\($0.castID) - \($0.name)" }
        }
        leftColumnY = drawCategory(title: "CAST", items: castItems, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Extras - always show
        let extras = breakdown.getExtras()
        rightColumnY = drawCategory(title: "EXTRAS", items: extras, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Props - always show
        let props = breakdown.getProps()
        leftColumnY = drawCategory(title: "PROPS", items: props, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Wardrobe - always show
        let wardrobe = breakdown.getWardrobe()
        rightColumnY = drawCategory(title: "WARDROBE", items: wardrobe, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Vehicles - always show
        let vehicles = breakdown.getVehicles()
        leftColumnY = drawCategory(title: "VEHICLES", items: vehicles, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Makeup - always show
        let makeup = breakdown.getMakeup()
        rightColumnY = drawCategory(title: "MAKEUP", items: makeup, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // SPFX - always show
        let spfx = breakdown.getSPFX()
        leftColumnY = drawCategory(title: "SPFX", items: spfx, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Art/Set Dressing - always show
        let art = breakdown.getArt()
        rightColumnY = drawCategory(title: "ART / SET DRESSING", items: art, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Sound FX - always show
        let soundfx = breakdown.getSoundFX()
        leftColumnY = drawCategory(title: "SOUND FX", items: soundfx, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Visual Effects - always show
        let vfx = breakdown.getVisualEffects()
        rightColumnY = drawCategory(title: "VISUAL EFFECTS", items: vfx, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Custom categories
        let customCategories = breakdown.getCustomCategories()
        for category in customCategories {
            if !category.items.isEmpty {
                if isLeftColumn {
                    leftColumnY = drawCategory(title: category.name.uppercased(), items: category.items, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
                    isLeftColumn = false
                } else {
                    rightColumnY = drawCategory(title: category.name.uppercased(), items: category.items, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
                    isLeftColumn = true
                }
            }
        }

        return max(leftColumnY, rightColumnY)
    }

    private static func drawCategory(title: String, items: [String], at yPosition: CGFloat, columnX: CGFloat, columnWidth: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition

        // Category header with background
        let headerHeight: CGFloat = 24
        let categoryColor = colorForCategory(title)
        context.setFillColor(categoryColor.withAlphaComponent(0.2).cgColor)
        context.fill(CGRect(x: columnX, y: y, width: columnWidth, height: headerHeight))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: PlatformFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: categoryColor
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: columnX + 8, y: y + 6))
        y += headerHeight + 4

        // Items
        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: PlatformFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: labelColor
        ]

        for item in items {
            let bullet = "• "
            let itemText = bullet + item
            let itemString = NSAttributedString(string: itemText, attributes: itemAttributes)
            let itemRect = CGRect(x: columnX + 8, y: y, width: columnWidth - 16, height: 1000)
            let boundingRect = itemString.boundingRect(with: CGSize(width: columnWidth - 16, height: 1000),
                                                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                        context: nil)
            itemString.draw(in: itemRect)
            y += boundingRect.height + 2
        }

        y += 12  // Space after category

        return y
    }

    // MARK: - macOS-Specific Drawing Functions (Handle PDF Coordinate System)

    #if os(macOS)
    private static func drawHeaderMacOS(scene: SceneEntity, at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition

        // Title
        let title = "SCENE BREAKDOWN"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.labelColor
        ]
        let titleSize = title.size(withAttributes: titleAttrs)
        let titleX = (pageWidth - titleSize.width) / 2
        title.draw(at: CGPoint(x: titleX, y: y), withAttributes: titleAttrs)
        y -= titleSize.height + 8

        // Scene number
        let sceneNumber = "Scene \(scene.number ?? "—")"
        let sceneNumberAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let sceneNumberSize = sceneNumber.size(withAttributes: sceneNumberAttrs)
        let sceneNumberX = (pageWidth - sceneNumberSize.width) / 2
        sceneNumber.draw(at: CGPoint(x: sceneNumberX, y: y), withAttributes: sceneNumberAttrs)
        y -= sceneNumberSize.height + 12

        // Divider line
        let linePath = NSBezierPath()
        linePath.move(to: CGPoint(x: margin, y: y))
        linePath.line(to: CGPoint(x: pageWidth - margin, y: y))
        NSColor.separatorColor.setStroke()
        linePath.lineWidth = 2
        linePath.stroke()
        y -= 2

        return y
    }

    private static func drawSceneInfoMacOS(scene: SceneEntity, at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition - 12

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]

        // Scene heading
        let locType = scene.locationType ?? "INT."
        let location = scene.scriptLocation ?? "Untitled Scene"
        let tod = scene.timeOfDay ?? "DAY"
        let heading = "\(locType) \(location) - \(tod)"

        y = drawInfoRowMacOS(label: "SCENE HEADING:", value: heading, labelAttrs: labelAttrs, valueAttrs: valueAttrs, at: y, in: context)
        y -= 6

        // Script Day
        if let scriptDay = scene.scriptDay, !scriptDay.isEmpty {
            y = drawInfoRowMacOS(label: "SCRIPT DAY:", value: scriptDay, labelAttrs: labelAttrs, valueAttrs: valueAttrs, at: y, in: context)
            y -= 6
        }

        // Page Length
        if let pageEighthsString = scene.pageEighthsString, !pageEighthsString.isEmpty {
            y = drawInfoRowMacOS(label: "PAGE LENGTH:", value: pageEighthsString, labelAttrs: labelAttrs, valueAttrs: valueAttrs, at: y, in: context)
            y -= 6
        }

        // Description
        if let description = scene.descriptionText, !description.isEmpty {
            y = drawInfoRowMacOS(label: "DESCRIPTION:", value: description, labelAttrs: labelAttrs, valueAttrs: valueAttrs, at: y, in: context)
            y -= 6
        }

        return y
    }

    private static func drawInfoRowMacOS(label: String, value: String, labelAttrs: [NSAttributedString.Key: Any], valueAttrs: [NSAttributedString.Key: Any], at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        let labelWidth: CGFloat = 140

        label.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttrs)

        // Calculate available width for value
        let valueX = margin + labelWidth
        let valueWidth = contentWidth - labelWidth

        // Draw value at specific position (not in a rect, as that doesn't work well with bottom-up coords)
        let valueBoundingRect = value.boundingRect(with: CGSize(width: valueWidth, height: 1000),
                                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                     attributes: valueAttrs,
                                                     context: nil)
        value.draw(at: CGPoint(x: valueX, y: yPosition), withAttributes: valueAttrs)

        let labelSize = label.size(withAttributes: labelAttrs)
        return yPosition - max(labelSize.height, valueBoundingRect.height) - 2
    }

    private static func drawBreakdownCategoriesMacOS(breakdown: BreakdownEntity, scene: SceneEntity, at yPosition: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition - 8

        // Divider line
        let linePath = NSBezierPath()
        linePath.move(to: CGPoint(x: margin, y: y))
        linePath.line(to: CGPoint(x: pageWidth - margin, y: y))
        NSColor.separatorColor.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()
        y -= 16

        // Two-column layout for categories
        let columnWidth = (contentWidth - 16) / 2
        var leftColumnY = y
        var rightColumnY = y
        var isLeftColumn = true

        // Cast Members - always show
        // Load cast members from scene's castMembersJSON
        var castItems: [String] = []
        if let castData = scene.value(forKey: "castMembersJSON") as? String,
           let data = castData.data(using: .utf8),
           let members = try? JSONDecoder().decode([BreakdownCastMember].self, from: data) {
            castItems = members.map { "\($0.castID) - \($0.name)" }
        }
        leftColumnY = drawCategoryMacOS(title: "CAST", items: castItems, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Extras - always show
        let extras = breakdown.getExtras()
        rightColumnY = drawCategoryMacOS(title: "EXTRAS", items: extras, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Props - always show
        let props = breakdown.getProps()
        leftColumnY = drawCategoryMacOS(title: "PROPS", items: props, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Wardrobe - always show
        let wardrobe = breakdown.getWardrobe()
        rightColumnY = drawCategoryMacOS(title: "WARDROBE", items: wardrobe, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Vehicles - always show
        let vehicles = breakdown.getVehicles()
        leftColumnY = drawCategoryMacOS(title: "VEHICLES", items: vehicles, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Makeup - always show
        let makeup = breakdown.getMakeup()
        rightColumnY = drawCategoryMacOS(title: "MAKEUP", items: makeup, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // SPFX - always show
        let spfx = breakdown.getSPFX()
        leftColumnY = drawCategoryMacOS(title: "SPFX", items: spfx, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Art/Set Dressing - always show
        let art = breakdown.getArt()
        rightColumnY = drawCategoryMacOS(title: "ART / SET DRESSING", items: art, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Sound FX - always show
        let soundfx = breakdown.getSoundFX()
        leftColumnY = drawCategoryMacOS(title: "SOUND FX", items: soundfx, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
        isLeftColumn = false

        // Visual Effects - always show
        let vfx = breakdown.getVisualEffects()
        rightColumnY = drawCategoryMacOS(title: "VISUAL EFFECTS", items: vfx, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
        isLeftColumn = true

        // Custom categories
        let customCategories = breakdown.getCustomCategories()
        for category in customCategories {
            if !category.items.isEmpty {
                if isLeftColumn {
                    leftColumnY = drawCategoryMacOS(title: category.name.uppercased(), items: category.items, at: leftColumnY, columnX: margin, columnWidth: columnWidth, in: context)
                    isLeftColumn = false
                } else {
                    rightColumnY = drawCategoryMacOS(title: category.name.uppercased(), items: category.items, at: rightColumnY, columnX: margin + columnWidth + 16, columnWidth: columnWidth, in: context)
                    isLeftColumn = true
                }
            }
        }

        return min(leftColumnY, rightColumnY)
    }

    private static func drawCategoryMacOS(title: String, items: [String], at yPosition: CGFloat, columnX: CGFloat, columnWidth: CGFloat, in context: CGContext) -> CGFloat {
        var y = yPosition

        // Category header with background
        let headerHeight: CGFloat = 24
        let headerBottom = y - headerHeight
        let categoryColor = colorForCategory(title)

        categoryColor.withAlphaComponent(0.2).setFill()
        NSRect(x: columnX, y: headerBottom, width: columnWidth, height: headerHeight).fill()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: categoryColor
        ]

        title.draw(at: CGPoint(x: columnX + 8, y: headerBottom + 6), withAttributes: titleAttrs)
        y -= headerHeight + 4

        // Items
        let itemAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]

        for item in items {
            let bullet = "• "
            let itemText = bullet + item
            let boundingRect = itemText.boundingRect(with: CGSize(width: columnWidth - 16, height: 1000),
                                                       options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                       attributes: itemAttrs,
                                                       context: nil)

            // Calculate where to draw (bottom of rect)
            let drawY = y - boundingRect.height
            itemText.draw(at: CGPoint(x: columnX + 8, y: drawY), withAttributes: itemAttrs)
            y -= boundingRect.height + 2
        }

        y -= 12  // Space after category

        return y
    }
    #endif
}

