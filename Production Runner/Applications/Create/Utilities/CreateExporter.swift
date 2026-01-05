import SwiftUI
import PDFKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Create Exporter
struct CreateExporter {

    // MARK: - Export Options
    struct ExportOptions {
        var includeBackground: Bool = true
        var includeBoardName: Bool = true
        var margin: CGFloat = 40
        var scale: CGFloat = 1.0
    }

    // MARK: - Export to PDF
    static func exportToPDF(
        blocks: [CreateBlockModel],
        connectors: [CreateConnectorModel],
        boardName: String,
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        guard !blocks.isEmpty else { return nil }

        // Calculate bounds
        let bounds = calculateBounds(blocks: blocks, margin: options.margin)
        let pageWidth = bounds.width * options.scale
        let pageHeight = bounds.height * options.scale

        #if os(macOS)
        return exportPDFMacOS(
            blocks: blocks,
            connectors: connectors,
            boardName: boardName,
            bounds: bounds,
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            options: options
        )
        #else
        return exportPDFiOS(
            blocks: blocks,
            connectors: connectors,
            boardName: boardName,
            bounds: bounds,
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            options: options
        )
        #endif
    }

    // MARK: - macOS PDF Export
    #if os(macOS)
    private static func exportPDFMacOS(
        blocks: [CreateBlockModel],
        connectors: [CreateConnectorModel],
        boardName: String,
        bounds: CGRect,
        pageSize: CGSize,
        options: ExportOptions
    ) -> Data? {
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        context.beginPDFPage(nil)

        // Background
        if options.includeBackground {
            context.setFillColor(NSColor.controlBackgroundColor.cgColor)
            context.fill(mediaBox)
        }

        // Board name header
        if options.includeBoardName {
            let font = NSFont.boldSystemFont(ofSize: 18)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
            let title = NSAttributedString(string: boardName, attributes: attributes)
            let titleSize = title.size()
            title.draw(at: CGPoint(x: options.margin, y: pageSize.height - options.margin - titleSize.height))
        }

        // Offset to center content
        let offsetX = options.margin - bounds.minX * options.scale
        let offsetY = options.margin - bounds.minY * options.scale + (options.includeBoardName ? 30 : 0)

        // Draw connectors first (under blocks)
        for connector in connectors {
            drawConnector(context: context, connector: connector, blocks: blocks, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
        }

        // Draw blocks
        for block in blocks.sorted(by: { $0.zIndex < $1.zIndex }) {
            drawBlock(context: context, block: block, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
        }

        context.endPDFPage()
        context.closePDF()

        return pdfData as Data
    }
    #endif

    // MARK: - iOS PDF Export
    #if os(iOS)
    private static func exportPDFiOS(
        blocks: [CreateBlockModel],
        connectors: [CreateConnectorModel],
        boardName: String,
        bounds: CGRect,
        pageSize: CGSize,
        options: ExportOptions
    ) -> Data? {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return pdfRenderer.pdfData { context in
            context.beginPage()

            let cgContext = context.cgContext

            // Background
            if options.includeBackground {
                cgContext.setFillColor(UIColor.systemBackground.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: pageSize))
            }

            // Board name header
            if options.includeBoardName {
                let font = UIFont.boldSystemFont(ofSize: 18)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.label
                ]
                let title = NSAttributedString(string: boardName, attributes: attributes)
                title.draw(at: CGPoint(x: options.margin, y: options.margin))
            }

            // Offset to center content
            let offsetX = options.margin - bounds.minX * options.scale
            let offsetY = options.margin - bounds.minY * options.scale + (options.includeBoardName ? 30 : 0)

            // Draw connectors first
            for connector in connectors {
                drawConnector(context: cgContext, connector: connector, blocks: blocks, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
            }

            // Draw blocks
            for block in blocks.sorted(by: { $0.zIndex < $1.zIndex }) {
                drawBlock(context: cgContext, block: block, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
            }
        }
    }
    #endif

    // MARK: - Export to Image
    static func exportToImage(
        blocks: [CreateBlockModel],
        connectors: [CreateConnectorModel],
        boardName: String,
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        guard !blocks.isEmpty else { return nil }

        let bounds = calculateBounds(blocks: blocks, margin: options.margin)
        let size = CGSize(
            width: bounds.width * options.scale,
            height: bounds.height * options.scale
        )

        #if os(macOS)
        return exportImageMacOS(blocks: blocks, connectors: connectors, bounds: bounds, size: size, options: options)
        #else
        return exportImageiOS(blocks: blocks, connectors: connectors, bounds: bounds, size: size, options: options)
        #endif
    }

    #if os(macOS)
    private static func exportImageMacOS(
        blocks: [CreateBlockModel],
        connectors: [CreateConnectorModel],
        bounds: CGRect,
        size: CGSize,
        options: ExportOptions
    ) -> Data? {
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // Background
        if options.includeBackground {
            context.setFillColor(NSColor.controlBackgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }

        let offsetX = options.margin - bounds.minX * options.scale
        let offsetY = options.margin - bounds.minY * options.scale

        // Draw connectors
        for connector in connectors {
            drawConnector(context: context, connector: connector, blocks: blocks, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
        }

        // Draw blocks
        for block in blocks.sorted(by: { $0.zIndex < $1.zIndex }) {
            drawBlock(context: context, block: block, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
        }

        image.unlockFocus()

        return image.tiffRepresentation?.pngData
    }
    #endif

    #if os(iOS)
    private static func exportImageiOS(
        blocks: [CreateBlockModel],
        connectors: [CreateConnectorModel],
        bounds: CGRect,
        size: CGSize,
        options: ExportOptions
    ) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            let cgContext = context.cgContext

            // Background
            if options.includeBackground {
                cgContext.setFillColor(UIColor.systemBackground.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: size))
            }

            let offsetX = options.margin - bounds.minX * options.scale
            let offsetY = options.margin - bounds.minY * options.scale

            // Draw connectors
            for connector in connectors {
                drawConnector(context: cgContext, connector: connector, blocks: blocks, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
            }

            // Draw blocks
            for block in blocks.sorted(by: { $0.zIndex < $1.zIndex }) {
                drawBlock(context: cgContext, block: block, offset: CGPoint(x: offsetX, y: offsetY), scale: options.scale)
            }
        }

        return image.pngData()
    }
    #endif

    // MARK: - Helpers
    private static func calculateBounds(blocks: [CreateBlockModel], margin: CGFloat) -> CGRect {
        guard !blocks.isEmpty else { return .zero }

        let minX = blocks.map(\.positionX).min()! - margin
        let minY = blocks.map(\.positionY).min()! - margin
        let maxX = blocks.map { $0.positionX + $0.width }.max()! + margin
        let maxY = blocks.map { $0.positionY + $0.height }.max()! + margin

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func drawBlock(context: CGContext, block: CreateBlockModel, offset: CGPoint, scale: CGFloat) {
        let rect = CGRect(
            x: block.positionX * scale + offset.x,
            y: block.positionY * scale + offset.y,
            width: block.width * scale,
            height: block.height * scale
        )

        // Block background
        context.saveGState()

        let backgroundColor = blockBackgroundColor(for: block.blockType)
        context.setFillColor(backgroundColor)

        let path = CGPath(roundedRect: rect, cornerWidth: 8 * scale, cornerHeight: 8 * scale, transform: nil)
        context.addPath(path)
        context.fillPath()

        // Block border
        context.setStrokeColor(CGColor(gray: 0.8, alpha: 1.0))
        context.setLineWidth(1 * scale)
        context.addPath(path)
        context.strokePath()

        context.restoreGState()

        // Draw block type icon/label
        drawBlockLabel(context: context, block: block, rect: rect, scale: scale)
    }

    private static func drawBlockLabel(context: CGContext, block: CreateBlockModel, rect: CGRect, scale: CGFloat) {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 12 * scale)
        let color = NSColor.secondaryLabelColor
        #else
        let font = UIFont.systemFont(ofSize: 12 * scale)
        let color = UIColor.secondaryLabel
        #endif

        let text: String
        switch block.blockType {
        case .note:
            text = block.noteContent?.title ?? "Note"
        case .image:
            text = "Image"
        case .link:
            text = block.linkContent?.title ?? "Link"
        case .file:
            text = block.fileContent?.fileName ?? "File"
        case .color:
            text = block.colorContent?.colorName ?? "Color"
        case .todo:
            text = block.todoContent?.title ?? "Tasks"
        case .boardLink:
            text = block.boardLinkContent?.linkedBoardName ?? "Board"
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attrString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(
            x: rect.minX + 8 * scale,
            y: rect.minY + 8 * scale,
            width: rect.width - 16 * scale,
            height: 20 * scale
        )

        attrString.draw(in: textRect)
    }

    private static func blockBackgroundColor(for type: CreateBlockType) -> CGColor {
        switch type {
        case .note: return CGColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
        case .image: return CGColor(red: 0.9, green: 0.85, blue: 1, alpha: 1)
        case .link: return CGColor(red: 0.85, green: 0.92, blue: 1, alpha: 1)
        case .file: return CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        case .color: return CGColor(red: 1, green: 0.9, blue: 0.95, alpha: 1)
        case .todo: return CGColor(red: 0.85, green: 1, blue: 0.88, alpha: 1)
        case .boardLink: return CGColor(red: 0.85, green: 0.95, blue: 0.95, alpha: 1)
        }
    }

    private static func drawConnector(context: CGContext, connector: CreateConnectorModel, blocks: [CreateBlockModel], offset: CGPoint, scale: CGFloat) {
        guard let sourceBlock = blocks.first(where: { $0.id == connector.sourceBlockID }),
              let targetBlock = blocks.first(where: { $0.id == connector.targetBlockID }) else { return }

        let startPoint = CGPoint(
            x: (sourceBlock.positionX + sourceBlock.width / 2) * scale + offset.x,
            y: (sourceBlock.positionY + sourceBlock.height / 2) * scale + offset.y
        )

        let endPoint = CGPoint(
            x: (targetBlock.positionX + targetBlock.width / 2) * scale + offset.x,
            y: (targetBlock.positionY + targetBlock.height / 2) * scale + offset.y
        )

        context.saveGState()

        // Set line style
        if let color = Color(createHex: connector.colorHex) {
            #if os(macOS)
            context.setStrokeColor(NSColor(color).cgColor)
            #else
            context.setStrokeColor(UIColor(color).cgColor)
            #endif
        } else {
            context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        }

        context.setLineWidth(connector.lineWidth * scale)

        switch connector.lineStyle {
        case .dashed:
            context.setLineDash(phase: 0, lengths: [8 * scale, 4 * scale])
        case .dotted:
            context.setLineDash(phase: 0, lengths: [2 * scale, 4 * scale])
        case .solid:
            break
        }

        // Draw line
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        // Draw arrow head if needed
        if connector.arrowHead == .arrow {
            drawArrowHead(context: context, at: endPoint, from: startPoint, scale: scale)
        }

        context.restoreGState()
    }

    private static func drawArrowHead(context: CGContext, at point: CGPoint, from origin: CGPoint, scale: CGFloat) {
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let length = sqrt(dx * dx + dy * dy)

        guard length > 0 else { return }

        let nx = dx / length
        let ny = dy / length
        let px = -ny
        let py = nx

        let arrowSize = 10 * scale

        let p1 = CGPoint(
            x: point.x - arrowSize * nx + arrowSize * 0.5 * px,
            y: point.y - arrowSize * ny + arrowSize * 0.5 * py
        )
        let p2 = CGPoint(
            x: point.x - arrowSize * nx - arrowSize * 0.5 * px,
            y: point.y - arrowSize * ny - arrowSize * 0.5 * py
        )

        context.move(to: point)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
    }
}

// MARK: - Data Extension for PNG
#if os(macOS)
extension Data {
    var pngData: Data? {
        guard let imageRep = NSBitmapImageRep(data: self) else { return nil }
        return imageRep.representation(using: .png, properties: [:])
    }
}
#endif
