import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct WrapReportView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: LiveModeStore

    @State private var reportData = WrapReportData(
        id: UUID(),
        shootDate: Date(),
        dayNumber: 1
    )
    @State private var showingExport: Bool = false
    @State private var showingSaveSuccess: Bool = false
    @State private var existingReportEntity: WrapReportEntity?

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Left: Report form
            reportFormPanel
                .frame(minWidth: 400, idealWidth: 500, maxWidth: 600)

            // Right: Preview
            reportPreviewPanel
                .frame(minWidth: 400)
        }
        .onAppear {
            loadExistingReport()
            populateFromTimeEntries()
        }
        .alert("Wrap Report Saved", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The wrap report has been saved successfully.")
        }
        #else
        NavigationSplitView {
            reportFormPanel
        } detail: {
            reportPreviewPanel
        }
        .onAppear {
            loadExistingReport()
            populateFromTimeEntries()
        }
        .alert("Wrap Report Saved", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The wrap report has been saved successfully.")
        }
        #endif
    }

    // MARK: - Report Form Panel

    @ViewBuilder
    private var reportFormPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wrap Report")
                        .font(.title.bold())
                    Text("Day \(reportData.dayNumber) • \(reportData.shootDate, style: .date)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Times section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Times", systemImage: "clock.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            WrapTimePickerField(label: "Call Time", time: $reportData.callTime)
                            WrapTimePickerField(label: "First Shot", time: $reportData.firstShotTime)
                            WrapTimePickerField(label: "Lunch In", time: $reportData.lunchStart)
                            WrapTimePickerField(label: "Lunch Out", time: $reportData.lunchEnd)
                            WrapTimePickerField(label: "Wrap Time", time: $reportData.wrapTime)
                        }

                        // Total hours calculated
                        HStack {
                            Text("Total Hours:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f hours", reportData.totalHours))
                                .font(.headline)
                                .foregroundStyle(.blue)

                            Spacer()

                            if reportData.mealPenaltyMinutes > 0 {
                                Label("\(reportData.mealPenaltyMinutes) min meal penalty", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(4)
                }

                // Scenes section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Scenes", systemImage: "film.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        // Scheduled scenes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scheduled")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Enter scene numbers (comma separated)", text: Binding(
                                get: { reportData.scheduledScenes.joined(separator: ", ") },
                                set: { reportData.scheduledScenes = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        // Completed scenes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Completed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Enter completed scene numbers", text: Binding(
                                get: { reportData.completedScenes.joined(separator: ", ") },
                                set: { reportData.completedScenes = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        // Partial scenes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Partial")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Enter partial scene numbers", text: Binding(
                                get: { reportData.partialScenes.joined(separator: ", ") },
                                set: { reportData.partialScenes = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        // Completion percentage
                        HStack {
                            Text("Completion:")
                                .foregroundStyle(.secondary)
                            ProgressView(value: reportData.completionPercentage / 100)
                                .frame(width: 100)
                            Text(String(format: "%.0f%%", reportData.completionPercentage))
                                .font(.headline)
                                .foregroundStyle(reportData.completionPercentage >= 100 ? .green : .orange)
                        }
                    }
                    .padding(4)
                }

                // Notes section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)
                            .foregroundStyle(.purple)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("General Notes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $reportData.notes)
                                .frame(minHeight: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weather")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Weather conditions", text: $reportData.weatherConditions)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Delays")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $reportData.delayNotes)
                                .frame(minHeight: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Accidents/Incidents")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                            }
                            TextEditor(text: $reportData.accidents)
                                .frame(minHeight: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(4)
                }

                // Actions
                HStack {
                    Button("Save Draft") {
                        saveReport(as: .draft)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        exportReport()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button("Submit") {
                        saveReport(as: .submitted)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    // MARK: - Report Preview Panel

    @ViewBuilder
    private var reportPreviewPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                StatusBadge(status: reportData.status)
            }
            .padding(16)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Preview content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Report header
                    VStack(alignment: .center, spacing: 8) {
                        Text("WRAP REPORT")
                            .font(.title2.bold())
                        Text("Day \(reportData.dayNumber)")
                            .font(.headline)
                        Text(reportData.shootDate, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)

                    Divider()

                    // Times summary
                    PreviewSection(title: "TIMES") {
                        PreviewRow(label: "Call Time", value: formatTime(reportData.callTime))
                        PreviewRow(label: "First Shot", value: formatTime(reportData.firstShotTime))
                        PreviewRow(label: "Lunch", value: formatTimeRange(reportData.lunchStart, reportData.lunchEnd))
                        PreviewRow(label: "Wrap", value: formatTime(reportData.wrapTime))
                        PreviewRow(label: "Total Hours", value: String(format: "%.1f", reportData.totalHours), highlight: true)
                    }

                    Divider()

                    // Scenes summary
                    PreviewSection(title: "SCENES") {
                        PreviewRow(label: "Scheduled", value: reportData.scheduledScenes.joined(separator: ", "))
                        PreviewRow(label: "Completed", value: reportData.completedScenes.joined(separator: ", "))
                        if !reportData.partialScenes.isEmpty {
                            PreviewRow(label: "Partial", value: reportData.partialScenes.joined(separator: ", "))
                        }
                        PreviewRow(label: "Completion", value: String(format: "%.0f%%", reportData.completionPercentage), highlight: true)
                    }

                    if !reportData.notes.isEmpty || !reportData.weatherConditions.isEmpty {
                        Divider()

                        PreviewSection(title: "NOTES") {
                            if !reportData.weatherConditions.isEmpty {
                                PreviewRow(label: "Weather", value: reportData.weatherConditions)
                            }
                            if !reportData.notes.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notes:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(reportData.notes)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    if !reportData.accidents.isEmpty {
                        Divider()

                        PreviewSection(title: "INCIDENTS", color: .red) {
                            Text(reportData.accidents)
                                .font(.subheadline)
                        }
                    }

                    // Signature area
                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("SIGNATURES")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 40) {
                            SignatureLine(title: "1st AD")
                            SignatureLine(title: "UPM")
                        }
                    }
                }
                .padding(24)
            }
            .background(Color.white)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatTimeRange(_ start: Date?, _ end: Date?) -> String {
        guard let start = start, let end = end else { return "—" }
        return "\(formatTime(start)) - \(formatTime(end))"
    }

    // MARK: - Core Data Operations

    private func loadExistingReport() {
        guard let project = store.currentProject else { return }

        let shootDate = store.currentShootDate ?? Date()
        let startOfDay = Calendar.current.startOfDay(for: shootDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<WrapReportEntity> = WrapReportEntity.fetchRequest()
        request.predicate = NSPredicate(format: "project == %@ AND shootDate >= %@ AND shootDate < %@",
                                         project,
                                         startOfDay as NSDate,
                                         endOfDay as NSDate)
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                existingReportEntity = entity
                reportData = WrapReportData(from: entity)
                print("[WrapReportView] Loaded existing wrap report for day \(reportData.dayNumber)")
            } else {
                // Initialize with current shoot day info
                reportData.dayNumber = store.currentShootDay ?? 1
                reportData.shootDate = shootDate
            }
        } catch {
            print("[WrapReportView] Error loading wrap report: \(error)")
        }
    }

    private func populateFromTimeEntries() {
        // Auto-populate times from today's time entries
        let entries = store.todayTimeEntries

        if reportData.callTime == nil, let crewCall = entries.first(where: { $0.category == .crewCall }) {
            reportData.callTime = crewCall.startTime
        }

        if reportData.firstShotTime == nil, let firstShot = entries.first(where: { $0.category == .firstShot }) {
            reportData.firstShotTime = firstShot.startTime
        }

        if reportData.lunchStart == nil, let lunch = entries.first(where: { $0.category == .lunch }) {
            reportData.lunchStart = lunch.startTime
            reportData.lunchEnd = lunch.endTime
        }

        if reportData.wrapTime == nil, let wrap = entries.first(where: { $0.category == .wrap }) {
            reportData.wrapTime = wrap.startTime
        }
    }

    private func saveReport(as status: WrapReportStatus) {
        reportData.status = status
        if status == .submitted {
            reportData.submittedAt = Date()
        }

        // Save to Core Data
        let entity: WrapReportEntity
        if let existing = existingReportEntity {
            entity = existing
        } else {
            entity = WrapReportEntity(context: context)
            entity.id = reportData.id
            entity.createdAt = Date()
            entity.project = store.currentProject
        }

        // Update entity with reportData
        entity.shootDate = reportData.shootDate
        entity.dayNumber = Int32(reportData.dayNumber)
        entity.callTime = reportData.callTime
        entity.firstShotTime = reportData.firstShotTime
        entity.lunchStart = reportData.lunchStart
        entity.lunchEnd = reportData.lunchEnd
        entity.wrapTime = reportData.wrapTime
        entity.totalHours = reportData.totalHours
        entity.notes = reportData.notes
        entity.weatherConditions = reportData.weatherConditions
        entity.accidents = reportData.accidents
        entity.delayNotes = reportData.delayNotes
        entity.status = status.rawValue

        // Encode scenes as JSON
        if let scheduledData = try? JSONEncoder().encode(reportData.scheduledScenes) {
            entity.scheduledScenesJSON = String(data: scheduledData, encoding: .utf8)
        }
        if let completedData = try? JSONEncoder().encode(reportData.completedScenes) {
            entity.completedScenesJSON = String(data: completedData, encoding: .utf8)
        }
        if let partialData = try? JSONEncoder().encode(reportData.partialScenes) {
            entity.partialScenesJSON = String(data: partialData, encoding: .utf8)
        }

        // Encode signatures as JSON
        if let signatureData = try? JSONEncoder().encode(reportData.signatures) {
            entity.signatureDataJSON = String(data: signatureData, encoding: .utf8)
        }

        if status == .submitted {
            entity.submittedAt = reportData.submittedAt
        }

        do {
            try context.save()
            existingReportEntity = entity
            showingSaveSuccess = true
            print("[WrapReportView] Saved wrap report: Day \(reportData.dayNumber) - \(status.rawValue)")
        } catch {
            print("[WrapReportView] Error saving wrap report: \(error)")
        }
    }

    private func exportReport() {
        // Generate PDF for export
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "WrapReport_Day\(reportData.dayNumber).pdf"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                generatePDF(to: url)
            }
        }
        #endif
    }

    #if os(macOS)
    private func generatePDF(to url: URL) {
        // Create PDF content
        let pdfMetaData = [
            kCGPDFContextCreator: "Production Runner",
            kCGPDFContextTitle: "Wrap Report - Day \(reportData.dayNumber)"
        ]

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            print("[WrapReportView] Failed to create PDF context")
            return
        }

        pdfContext.beginPDFPage(nil)

        // Draw title using Core Text
        let titleFont = NSFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]

        let title = NSAttributedString(string: "WRAP REPORT - Day \(reportData.dayNumber)", attributes: titleAttributes)
        let titleLine = CTLineCreateWithAttributedString(title)
        pdfContext.textPosition = CGPoint(x: 50, y: pageHeight - 50)
        CTLineDraw(titleLine, pdfContext)

        // Draw report details
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]

        var yOffset = pageHeight - 90
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let lines = [
            "Date: \(dateFormatter.string(from: reportData.shootDate))",
            "Call Time: \(reportData.callTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "N/A")",
            "First Shot: \(reportData.firstShotTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "N/A")",
            "Wrap Time: \(reportData.wrapTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "N/A")",
            "",
            "Scheduled Scenes: \(reportData.scheduledScenes.joined(separator: ", "))",
            "Completed Scenes: \(reportData.completedScenes.joined(separator: ", "))",
            "",
            "Notes: \(reportData.notes)"
        ]

        for lineText in lines {
            let attrString = NSAttributedString(string: lineText, attributes: bodyAttributes)
            let line = CTLineCreateWithAttributedString(attrString)
            pdfContext.textPosition = CGPoint(x: 50, y: yOffset)
            CTLineDraw(line, pdfContext)
            yOffset -= 20
        }

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        print("[WrapReportView] PDF exported to \(url.path)")
    }
    #endif
}

// MARK: - Supporting Views

struct WrapTimePickerField: View {
    let label: String
    @Binding var time: Date?

    @State private var isSet: Bool = false
    @State private var tempTime: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if isSet {
                    DatePicker("", selection: $tempTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: tempTime) { newValue in
                            time = newValue
                        }

                    Button {
                        isSet = false
                        time = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Set Time") {
                        isSet = true
                        tempTime = Date()
                        time = tempTime
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: WrapReportStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(status.color)
            )
    }
}

struct PreviewSection<Content: View>: View {
    let title: String
    var color: Color = .primary
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color == .primary ? .secondary : color)

            content()
        }
    }
}

struct PreviewRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .fontWeight(highlight ? .semibold : .regular)
        }
        .font(.subheadline)
    }
}

struct SignatureLine: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
                .frame(width: 150)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WrapReportView()
        .environmentObject(LiveModeStore())
}
