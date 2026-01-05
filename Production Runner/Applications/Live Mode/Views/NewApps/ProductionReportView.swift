import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct ProductionReportView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: LiveModeStore

    @State private var reportData = ProductionReportData(
        id: UUID(),
        shootDate: Date(),
        dayNumber: 1,
        reportNumber: 1
    )
    @State private var selectedTab: ProductionReportTab = .header

    enum ProductionReportTab: String, CaseIterable {
        case header = "Header"
        case times = "Times"
        case scenes = "Scenes"
        case cast = "Cast"
        case notes = "Notes"

        var icon: String {
            switch self {
            case .header: return "doc.text.fill"
            case .times: return "clock.fill"
            case .scenes: return "film.fill"
            case .cast: return "person.2.fill"
            case .notes: return "note.text"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            Divider()

            #if os(macOS)
            HSplitView {
                // Left: Form
                formPanel
                    .frame(minWidth: 450, idealWidth: 500, maxWidth: 600)

                // Right: Preview
                previewPanel
                    .frame(minWidth: 400)
            }
            #else
            NavigationSplitView {
                formPanel
            } detail: {
                previewPanel
            }
            #endif
        }
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProductionReportTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

    // MARK: - Form Panel

    @ViewBuilder
    private var formPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedTab {
                case .header:
                    headerForm
                case .times:
                    timesForm
                case .scenes:
                    scenesForm
                case .cast:
                    castForm
                case .notes:
                    notesForm
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

    // MARK: - Header Form

    @ViewBuilder
    private var headerForm: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Production Info", systemImage: "info.circle.fill")
                    .font(.headline)

                TextField("Project Name", text: $reportData.projectName)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day Number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("\(reportData.dayNumber)", value: $reportData.dayNumber, in: 1...365)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Report Number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("\(reportData.reportNumber)", value: $reportData.reportNumber, in: 1...999)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $reportData.shootDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
            .padding(4)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Key Personnel", systemImage: "person.3.fill")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Director")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Director name", text: $reportData.director)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Producer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Producer name", text: $reportData.producer)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("1st AD")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("1st AD name", text: $reportData.firstAD)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("UPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("UPM name", text: $reportData.unitProductionManager)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(4)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Script Info", systemImage: "doc.text.fill")
                    .font(.headline)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Script Dated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(
                            get: { reportData.scriptDated ?? Date() },
                            set: { reportData.scriptDated = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Revision Color")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Blue", text: $reportData.scriptColor)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Times Form

    @ViewBuilder
    private var timesForm: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Call Times", systemImage: "alarm.fill")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ProductionTimePicker(label: "Crew Call", time: $reportData.crewCall)
                    ProductionTimePicker(label: "Shooting Call", time: $reportData.shootingCall)
                    ProductionTimePicker(label: "First Shot", time: $reportData.firstShotTime)
                    ProductionTimePicker(label: "Lunch", time: $reportData.lunchCall)
                    ProductionTimePicker(label: "1st Shot After Lunch", time: $reportData.firstShotAfterLunch)
                    ProductionTimePicker(label: "Camera Wrap", time: $reportData.cameraWrap)
                    ProductionTimePicker(label: "Last Man Out", time: $reportData.lastManOut)
                }
            }
            .padding(4)
        }
    }

    // MARK: - Scenes Form

    @ViewBuilder
    private var scenesForm: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Scene Progress", systemImage: "list.bullet.clipboard.fill")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Scheduled Scenes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g., 1, 2, 3A", text: Binding(
                        get: { reportData.scenesScheduled.joined(separator: ", ") },
                        set: { reportData.scenesScheduled = parseScenes($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Scenes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g., 1, 2", text: Binding(
                        get: { reportData.scenesCompleted.joined(separator: ", ") },
                        set: { reportData.scenesCompleted = parseScenes($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Partial Scenes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g., 3A", text: Binding(
                        get: { reportData.scenesPartial.joined(separator: ", ") },
                        set: { reportData.scenesPartial = parseScenes($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
            .padding(4)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Page Count", systemImage: "doc.fill")
                    .font(.headline)

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scheduled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", value: $reportData.pagesScheduled, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", value: $reportData.pagesCompleted, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Cast Form

    @ViewBuilder
    private var castForm: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Cast", systemImage: "person.2.fill")
                        .font(.headline)
                    Spacer()
                    Button {
                        addCastEntry()
                    } label: {
                        Label("Add Cast", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if reportData.castEntries.isEmpty {
                    Text("No cast entries. Click 'Add Cast' to add cast members.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach($reportData.castEntries) { $entry in
                        CastEntryRow(entry: $entry) {
                            reportData.castEntries.removeAll { $0.id == entry.id }
                        }
                        Divider()
                    }
                }
            }
            .padding(4)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Background", systemImage: "person.3.fill")
                    .font(.headline)

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stand-Ins")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("\(reportData.standInsCount)", value: $reportData.standInsCount, in: 0...100)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Atmosphere")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("\(reportData.atmosphereCount)", value: $reportData.atmosphereCount, in: 0...1000)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Special Ability")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("\(reportData.specialAbilityCount)", value: $reportData.specialAbilityCount, in: 0...100)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Notes Form

    @ViewBuilder
    private var notesForm: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Production Notes", systemImage: "note.text")
                    .font(.headline)

                TextEditor(text: $reportData.productionNotes)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(4)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Equipment Issues", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                TextEditor(text: $reportData.equipmentIssues)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(4)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Accident Report", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                TextEditor(text: $reportData.accidentReport)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(4)
        }

        // Actions
        HStack {
            Button("Save Draft") {
                reportData.status = .draft
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                // Export
            } label: {
                Label("Export PDF", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)

            Button("Submit for Review") {
                reportData.status = .review
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 8)
    }

    // MARK: - Preview Panel

    @ViewBuilder
    private var previewPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                Text(reportData.status.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(reportData.status.color)
                    )
            }
            .padding(16)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(spacing: 4) {
                        Text("DAILY PRODUCTION REPORT")
                            .font(.title3.bold())
                        Text(reportData.projectName.isEmpty ? "Project Name" : reportData.projectName)
                            .font(.headline)
                        Text("Day \(reportData.dayNumber) • Report #\(reportData.reportNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(reportData.shootDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)

                    // Content based on what's filled
                    if !reportData.director.isEmpty || !reportData.producer.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            if !reportData.director.isEmpty {
                                Text("Director: \(reportData.director)")
                            }
                            if !reportData.producer.isEmpty {
                                Text("Producer: \(reportData.producer)")
                            }
                            if !reportData.firstAD.isEmpty {
                                Text("1st AD: \(reportData.firstAD)")
                            }
                        }
                        .font(.subheadline)
                    }

                    // Times preview
                    if reportData.crewCall != nil {
                        Divider()
                        Text("TIMES")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        // Times would be listed here
                    }
                }
                .padding(20)
            }
            .background(Color.white)
        }
    }

    // MARK: - Helpers

    private func parseScenes(_ text: String) -> [String] {
        text.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func addCastEntry() {
        let entry = CastReportEntry(
            id: UUID(),
            castNumber: reportData.castEntries.count + 1,
            name: "",
            role: ""
        )
        reportData.castEntries.append(entry)
    }
}

// MARK: - Supporting Views

struct ProductionTimePicker: View {
    let label: String
    @Binding var time: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if let time = time {
                    DatePicker("", selection: Binding(
                        get: { time },
                        set: { self.time = $0 }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()

                    Button {
                        self.time = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Set") {
                        time = Date()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

struct CastEntryRow: View {
    @Binding var entry: CastReportEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.castNumber)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.purple)
                .frame(width: 30)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Name", text: $entry.name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Role", text: $entry.role)
                    .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 8) {
                    SmallTimePicker(label: "Call", time: $entry.callTime)
                    SmallTimePicker(label: "Wrap", time: $entry.wrap)
                }
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

struct SmallTimePicker: View {
    let label: String
    @Binding var time: Date?

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let time = time {
                DatePicker("", selection: Binding(
                    get: { time },
                    set: { self.time = $0 }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .controlSize(.small)
            } else {
                Button("—") {
                    self.time = Date()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }
}

#Preview {
    ProductionReportView()
        .environmentObject(LiveModeStore())
}
