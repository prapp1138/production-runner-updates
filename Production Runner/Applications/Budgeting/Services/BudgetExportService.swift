import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Handles exporting budget data to various formats (CSV, PDF, JSON)
struct BudgetExportService {

    // MARK: - Export Formats

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case pdf = "PDF"
        case json = "JSON"

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .pdf: return "pdf"
            case .json: return "json"
            }
        }

        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .pdf: return "application/pdf"
            case .json: return "application/json"
            }
        }
    }

    // MARK: - Export Options

    struct ExportOptions {
        var includeHeader: Bool = true
        var includeNotes: Bool = true
        var includeSummary: Bool = true
        var includeTransactions: Bool = false
        var currency: String = "USD"
        var dateFormat: String = "yyyy-MM-dd"
        var groupByCategory: Bool = true
        var groupBySection: Bool = true
    }

    // MARK: - CSV Export

    /// Export budget line items to CSV format
    static func exportToCSV(
        items: [BudgetLineItem],
        summary: BudgetSummary,
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        var csv = ""

        // Header
        if options.includeHeader {
            csv += "Account,Name,Category,Section,Quantity,Days,Unit Cost,Total"
            if options.includeNotes {
                csv += ",Notes"
            }
            csv += "\n"
        }

        // Group items if requested
        let sortedItems: [BudgetLineItem]
        if options.groupByCategory {
            sortedItems = items.sorted { ($0.category, $0.section ?? "") < ($1.category, $1.section ?? "") }
        } else {
            sortedItems = items
        }

        // Line items
        for item in sortedItems {
            let row = [
                escapeCSV(item.account),
                escapeCSV(item.name),
                escapeCSV(item.category),
                escapeCSV(item.section ?? ""),
                String(format: "%.2f", item.quantity),
                String(format: "%.2f", item.days),
                String(format: "%.2f", item.unitCost),
                String(format: "%.2f", item.total)
            ]

            csv += row.joined(separator: ",")

            if options.includeNotes {
                csv += ",\(escapeCSV(item.notes))"
            }
            csv += "\n"
        }

        // Summary section
        if options.includeSummary {
            csv += "\n"
            csv += "Summary\n"
            csv += "Category,Amount,Percentage\n"
            csv += "Above the Line,\(summary.aboveTheLineTotal),\(String(format: "%.1f", summary.percentage(for: .aboveTheLine)))%\n"
            csv += "Below the Line,\(summary.belowTheLineTotal),\(String(format: "%.1f", summary.percentage(for: .belowTheLine)))%\n"
            csv += "Post-Production,\(summary.postProductionTotal),\(String(format: "%.1f", summary.percentage(for: .postProduction)))%\n"
            csv += "Other,\(summary.otherTotal),\(String(format: "%.1f", summary.percentage(for: .other)))%\n"
            csv += "\n"
            csv += "Total Budget,\(summary.totalBudget)\n"
        }

        BudgetLogger.logExport(format: .csv, itemCount: items.count, success: true)
        return csv.data(using: .utf8)
    }

    /// Export transactions to CSV
    static func exportTransactionsToCSV(
        transactions: [BudgetTransaction],
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        var csv = ""

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = options.dateFormat

        // Header
        if options.includeHeader {
            csv += "Date,Amount,Category,Type,Description,Payee"
            if options.includeNotes {
                csv += ",Notes"
            }
            csv += "\n"
        }

        // Transactions
        for transaction in transactions.sorted(by: { $0.date > $1.date }) {
            let row = [
                dateFormatter.string(from: transaction.date),
                String(format: "%.2f", transaction.amount),
                escapeCSV(transaction.category),
                escapeCSV(transaction.transactionType),
                escapeCSV(transaction.descriptionText),
                escapeCSV(transaction.payee)
            ]

            csv += row.joined(separator: ",")

            if options.includeNotes {
                csv += ",\(escapeCSV(transaction.notes))"
            }
            csv += "\n"
        }

        BudgetLogger.logExport(format: .csv, itemCount: transactions.count, success: true)
        return csv.data(using: .utf8)
    }

    // MARK: - JSON Export

    /// Export budget to JSON format
    static func exportToJSON(
        version: BudgetVersion,
        summary: BudgetSummary,
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        let exportData = BudgetExportData(
            version: version,
            summary: summary,
            exportDate: Date(),
            currency: options.currency
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(exportData)
            BudgetLogger.logExport(format: .json, itemCount: version.lineItems.count, success: true)
            return data
        } catch {
            BudgetLogger.error("Failed to export to JSON: \(error.localizedDescription)", category: BudgetLogger.export)
            return nil
        }
    }

    // MARK: - PDF Export

    /// Generate PDF report for budget
    static func exportToPDF(
        version: BudgetVersion,
        summary: BudgetSummary,
        options: ExportOptions = ExportOptions()
    ) -> Data? {
        #if canImport(AppKit)
        return generatePDFMacOS(version: version, summary: summary, options: options)
        #elseif canImport(UIKit)
        return generatePDFiOS(version: version, summary: summary, options: options)
        #else
        BudgetLogger.error("PDF export not supported on this platform", category: BudgetLogger.export)
        return nil
        #endif
    }

    #if canImport(AppKit)
    private static func generatePDFMacOS(
        version: BudgetVersion,
        summary: BudgetSummary,
        options: ExportOptions
    ) -> Data? {
        let pageWidth: CGFloat = 612 // Letter size
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return nil
        }

        var currentY: CGFloat = pageHeight - margin
        _ = pageWidth - (margin * 2)  // contentWidth reserved for future use

        func startNewPage() {
            _ = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)  // pageRect reserved for future use
            context.beginPDFPage(nil)
            currentY = pageHeight - margin
        }

        func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat = 12, bold: Bool = false) {
            let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)

            let line = CTLineCreateWithAttributedString(attributedString)
            context.saveGState()
            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            context.textPosition = point
            CTLineDraw(line, context)
            context.restoreGState()
        }

        // Start first page
        startNewPage()

        // Title
        drawText("Budget Report: \(version.name)", at: CGPoint(x: margin, y: currentY), fontSize: 24, bold: true)
        currentY -= 30

        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        drawText("Generated: \(dateFormatter.string(from: Date()))", at: CGPoint(x: margin, y: currentY), fontSize: 10)
        currentY -= 40

        // Summary section
        drawText("Budget Summary", at: CGPoint(x: margin, y: currentY), fontSize: 16, bold: true)
        currentY -= 25

        let summaryItems = [
            ("Total Budget:", summary.totalBudget.asCurrency()),
            ("Above the Line:", summary.aboveTheLineTotal.asCurrency()),
            ("Below the Line:", summary.belowTheLineTotal.asCurrency()),
            ("Post-Production:", summary.postProductionTotal.asCurrency()),
            ("Other:", summary.otherTotal.asCurrency())
        ]

        for (label, value) in summaryItems {
            drawText(label, at: CGPoint(x: margin, y: currentY))
            drawText(value, at: CGPoint(x: margin + 150, y: currentY))
            currentY -= 18
        }

        currentY -= 20

        // Line items by category
        if options.groupByCategory {
            for category in BudgetCategory.allCases {
                let categoryItems = version.lineItems.filter { $0.category == category.rawValue }
                guard !categoryItems.isEmpty else { continue }

                // Check if we need a new page
                if currentY < 100 {
                    context.endPDFPage()
                    startNewPage()
                }

                drawText(category.rawValue, at: CGPoint(x: margin, y: currentY), fontSize: 14, bold: true)
                currentY -= 22

                for item in categoryItems {
                    if currentY < 60 {
                        context.endPDFPage()
                        startNewPage()
                    }

                    drawText(item.name, at: CGPoint(x: margin + 20, y: currentY))
                    drawText(item.total.asCurrency(), at: CGPoint(x: pageWidth - margin - 80, y: currentY))
                    currentY -= 16
                }

                currentY -= 10
            }
        }

        context.endPDFPage()
        context.closePDF()

        BudgetLogger.logExport(format: .pdf, itemCount: version.lineItems.count, success: true)
        return pdfData as Data
    }
    #endif

    #if canImport(UIKit)
    private static func generatePDFiOS(
        version: BudgetVersion,
        summary: BudgetSummary,
        options: ExportOptions
    ) -> Data? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = margin

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let title = "Budget Report: \(version.name)"
            title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
            currentY += 40

            // Summary
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            let summaryItems = [
                ("Total Budget:", summary.totalBudget.asCurrency()),
                ("Above the Line:", summary.aboveTheLineTotal.asCurrency()),
                ("Below the Line:", summary.belowTheLineTotal.asCurrency()),
                ("Post-Production:", summary.postProductionTotal.asCurrency()),
                ("Other:", summary.otherTotal.asCurrency())
            ]

            for (label, value) in summaryItems {
                label.draw(at: CGPoint(x: margin, y: currentY), withAttributes: labelAttributes)
                value.draw(at: CGPoint(x: margin + 150, y: currentY), withAttributes: labelAttributes)
                currentY += 20
            }
        }

        BudgetLogger.logExport(format: .pdf, itemCount: version.lineItems.count, success: true)
        return data
    }
    #endif

    // MARK: - Helper Methods

    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }

    // MARK: - File Saving

    /// Get suggested filename for export
    static func suggestedFilename(
        for versionName: String,
        format: ExportFormat
    ) -> String {
        let sanitizedName = versionName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        return "\(sanitizedName)_\(dateString).\(format.fileExtension)"
    }

    #if canImport(AppKit)
    /// Show save panel and save exported data (macOS)
    static func saveWithPanel(
        data: Data,
        suggestedFilename: String,
        format: ExportFormat
    ) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.allowedContentTypes = [.data]

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    BudgetLogger.success("Saved export to \(url.path)", category: BudgetLogger.export)
                } catch {
                    BudgetLogger.error("Failed to save export: \(error.localizedDescription)", category: BudgetLogger.export)
                }
            }
        }
    }
    #endif
}

// MARK: - Export Data Model

struct BudgetExportData: Codable {
    let version: BudgetVersion
    let summary: BudgetSummaryExport
    let exportDate: Date
    let currency: String

    init(version: BudgetVersion, summary: BudgetSummary, exportDate: Date, currency: String) {
        self.version = version
        self.summary = BudgetSummaryExport(from: summary)
        self.exportDate = exportDate
        self.currency = currency
    }
}

struct BudgetSummaryExport: Codable {
    let totalBudget: Double
    let aboveTheLineTotal: Double
    let belowTheLineTotal: Double
    let postProductionTotal: Double
    let otherTotal: Double

    init(from summary: BudgetSummary) {
        self.totalBudget = summary.totalBudget
        self.aboveTheLineTotal = summary.aboveTheLineTotal
        self.belowTheLineTotal = summary.belowTheLineTotal
        self.postProductionTotal = summary.postProductionTotal
        self.otherTotal = summary.otherTotal
    }
}
