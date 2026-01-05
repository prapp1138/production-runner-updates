import Foundation
import SwiftUI
import CoreData

#if os(macOS)
import AppKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - Notification Extensions
private extension Notification.Name {
    static let fdxImportDidFinish = Notification.Name("fdxImportDidFinish")
}

// MARK: - Unit Data Model
private struct SchedulerUnitData: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var memberIDs: [UUID]
}

// MARK: - Scheduler Card Style
private struct SchedulerCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
    }
}

private extension View {
    func schedulerCard(padding: CGFloat = 16) -> some View {
        self.modifier(SchedulerCard(padding: padding))
    }
}

// MARK: - Scheduler View
struct SchedulerView: View {
    @Environment(\.managedObjectContext) var moc
    let projectID: NSManagedObjectID

    // MARK: - State
    @State private var selectedTab: SchedulerTab = .stripboard
    @State private var scenes: [NSManagedObject] = []
    @State private var sceneDisplay: [NSManagedObjectID: SceneDisplay] = [:]
    @State private var selectedIDs: Set<NSManagedObjectID> = []
    @State private var anchorIndex: Int? = nil
    @State private var productionStartDate: Date = Date()
    @State private var showInspector: Bool = true
    @State private var inspectorWidth: CGFloat = 320
    @State private var inspectorTab: InspectorTab = .sceneData
    @State private var showElements: Bool = false
    @State private var showShots: Bool = false
    @State private var showColorCustomizer: Bool = false
    @State private var showLocationSync: Bool = false
    @State private var selectedLocationID: UUID? = nil
    @State private var showPDFPreview: Bool = false
    @State private var previewPDF: PDFDocument? = nil
    @State private var previewTitle: String = ""
    @State private var previewFilename: String = ""

    // Note: SchedulerTab enum is defined in CallSheetsView.swift for sharing

    private enum InspectorTab: String, CaseIterable {
        case sceneData = "Scene Data"
        case overview = "Overview"
    }

    // Strip Colors (Industry Standard)
    @AppStorage("stripColor_intDay") private var colorIntDay: String = "1.0,1.0,1.0"
    @AppStorage("stripColor_extDay") private var colorExtDay: String = "1.0,0.92,0.23"
    @AppStorage("stripColor_intNight") private var colorIntNight: String = "0.53,0.81,0.98"
    @AppStorage("stripColor_extNight") private var colorExtNight: String = "0.60,0.98,0.60"
    @AppStorage("stripColor_intMorning") private var colorIntMorning: String = "1.0,0.95,0.80"
    @AppStorage("stripColor_extMorning") private var colorExtMorning: String = "1.0,0.85,0.50"
    @AppStorage("stripColor_intDawn") private var colorIntDawn: String = "0.95,0.85,0.95"
    @AppStorage("stripColor_extDawn") private var colorExtDawn: String = "0.98,0.75,0.85"
    @AppStorage("stripColor_intDusk") private var colorIntDusk: String = "0.85,0.75,0.95"
    @AppStorage("stripColor_extDusk") private var colorExtDusk: String = "0.95,0.65,0.75"
    @AppStorage("stripColor_intEvening") private var colorIntEvening: String = "0.75,0.85,0.95"
    @AppStorage("stripColor_extEvening") private var colorExtEvening: String = "0.65,0.75,0.95"
    @State private var searchText: String = ""
    @State private var filterInt: Bool = true
    @State private var filterExt: Bool = true
    @State private var filterDay: Bool = true
    @State private var filterNight: Bool = true
    @State private var filterDawn: Bool = true
    @State private var filterDusk: Bool = true
    @State private var filterLocation: String = ""
    @State private var filterPresets: [String] = []
    @State private var selectedDay: Date = Date()
    @State private var density: Density = .medium
    @State private var dragOverID: NSManagedObjectID? = nil
    @State private var hoveredRowID: NSManagedObjectID? = nil
    @State private var expandedSceneIDs: Set<NSManagedObjectID> = []

    // Save management
    @State private var pendingReload: DispatchWorkItem? = nil
    @State private var pendingSaveWork: DispatchWorkItem? = nil
    @State private var isSaving: Bool = false
    @State private var suppressReloads: Bool = false
    @State private var isProgrammaticDateChange: Bool = false

    // Schedule Versions
    @State private var scheduleVersions: [ScheduleVersion] = []
    @State private var selectedVersion: ScheduleVersion? = nil
    @State private var showingNewVersionDialog = false
    @State private var showingRenameVersionDialog = false
    @State private var showingDeleteVersionAlert = false
    @State private var versionToRename: ScheduleVersion? = nil
    @State private var versionToDelete: ScheduleVersion? = nil

    // Script Revision Sync
    @ObservedObject private var scriptSyncService = ScriptRevisionSyncService.shared
    @State private var showMergeResultAlert = false
    @State private var lastMergeResult: MergeResult? = nil
    @State private var isLoadingScriptRevision = false

    // Set Dates
    @State private var showSetDatesSheet = false

    // Generate Call Sheet
    @State private var selectedShootDayIndex: Int? = nil
    @State private var generatedCallSheet: CallSheet? = nil
    @State private var showCallSheetEditor = false

    // Undo/Redo state - stores scene order and basic properties
    @StateObject private var undoRedoManager = UndoRedoManager<[[String: Any]]>(maxHistorySize: 10)

    private struct SceneDisplay: Equatable {
        let number: String
        let intExtUpper: String
        let heading: String
        let timeUpper: String
        let pageLen: String
        let shootLoc: String
        let tint: Color?
    }

    private enum Density: String, CaseIterable {
        case compact = "Compact"
        case medium = "Medium"
        case comfortable = "Comfortable"

        var rowHeight: CGFloat {
            switch self {
            case .compact: return 60
            case .medium: return 80
            case .comfortable: return 100
            }
        }
        
        var iconName: String {
            switch self {
            case .compact: return "rectangle.compress.vertical"
            case .medium: return "rectangle"
            case .comfortable: return "rectangle.expand.vertical"
            }
        }
    }

    // MARK: - Grid Column Definitions
    private var gridColumns: [GridItem] {
        [
            GridItem(.fixed(50), spacing: 0, alignment: .center),      // Scene #
            GridItem(.flexible(minimum: 200), spacing: 0, alignment: .leading),  // Scene Setting
            GridItem(.fixed(100), spacing: 0, alignment: .center),     // Cast ID
            GridItem(.fixed(70), spacing: 0, alignment: .center),      // Pages
            GridItem(.fixed(100), spacing: 0, alignment: .center),     // Estimation
            GridItem(.fixed(120), spacing: 0, alignment: .center)      // Location
        ]
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .stripboard:
                HStack(spacing: 0) {
                    stripboardContent

                    if showInspector {
                        Divider()
                        inspectorPanel
                    }
                }
            case .dood:
                dayOutOfDaysView
            case .callSheets:
                CallSheetsView(projectID: projectID, selectedTab: $selectedTab)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Tab Content
            tabContent

            Divider()
            productionOverview
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingNewVersionDialog) {
            NewScheduleVersionDialog(isPresented: $showingNewVersionDialog, onCreate: createNewVersion)
        }
        .sheet(isPresented: $showingRenameVersionDialog) {
            if let version = versionToRename {
                RenameScheduleVersionDialog(version: version, isPresented: $showingRenameVersionDialog, onRename: renameVersion)
            }
        }
        .alert("Delete Schedule Version", isPresented: $showingDeleteVersionAlert, presenting: versionToDelete) { version in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteVersion(version)
            }
        } message: { version in
            Text("Are you sure you want to delete '\(version.name)'? This action cannot be undone.")
        }
        .alert("Script Revision Loaded", isPresented: $showMergeResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = lastMergeResult {
                Text(result.summary)
            } else {
                Text("Script revision loaded successfully.")
            }
        }
        .onAppear {
            reload()
            loadVersions()
        }
        .onChange(of: projectID) { _ in scheduleReload() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: moc)) { _ in
            guard !isSaving, !moc.hasChanges, !suppressReloads else { return }
            scheduleReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .breakdownsSceneSynced)) { _ in
            if !suppressReloads && !isSaving { scheduleReload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .breakdownsSceneOrderChanged)) { _ in
            if !suppressReloads && !isSaving { scheduleReload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: nil)) { note in
            guard let ctx = note.object as? NSManagedObjectContext, ctx != moc else { return }
            moc.perform { moc.mergeChanges(fromContextDidSave: note) }
            if !suppressReloads && !isSaving { scheduleReload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fdxImportDidFinish)) { _ in
            if !suppressReloads { scheduleReload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scriptRevisionSent)) { _ in
            // Refresh to show new revision available indicator
            // The @ObservedObject scriptSyncService will update automatically
        }
        .onDeleteCommand(perform: deleteSelected)
        .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
            deleteSelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
            selectAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
            handleCut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
            handleCopy()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
            pasteFromPasteboard()
        }
        .undoRedoSupport(
            canUndo: undoRedoManager.canUndo,
            canRedo: undoRedoManager.canRedo,
            onUndo: performUndo,
            onRedo: performRedo
        )
        .sheet(isPresented: $showColorCustomizer) {
            StripColorCustomizer(
                colorIntDay: $colorIntDay,
                colorExtDay: $colorExtDay,
                colorIntNight: $colorIntNight,
                colorExtNight: $colorExtNight,
                colorIntMorning: $colorIntMorning,
                colorExtMorning: $colorExtMorning,
                colorIntDawn: $colorIntDawn,
                colorExtDawn: $colorExtDawn,
                colorIntDusk: $colorIntDusk,
                colorExtDusk: $colorExtDusk,
                colorIntEvening: $colorIntEvening,
                colorExtEvening: $colorExtEvening
            )
        }
        .sheet(isPresented: $showSetDatesSheet) {
            if let project = try? moc.existingObject(with: projectID) {
                SetDatesSheet(
                    productionStartDate: $productionStartDate,
                    project: project
                )
            }
        }
        .sheet(isPresented: $showPDFPreview) {
            if let pdfDocument = previewPDF {
                PDFPreviewSheet(
                    pdfDocument: pdfDocument,
                    title: previewTitle,
                    defaultFilename: previewFilename,
                    onOrientationChange: { orientation in
                        regenerateStripboardPDF(with: orientation)
                    }
                )
            }
        }
        .sheet(isPresented: $showCallSheetEditor) {
            if generatedCallSheet != nil {
                CallSheetEditorView(
                    callSheet: Binding(
                        get: { generatedCallSheet ?? CallSheet.empty() },
                        set: { generatedCallSheet = $0 }
                    ),
                    onClose: {
                        showCallSheetEditor = false
                        selectedShootDayIndex = nil
                    },
                    onSave: { savedSheet in
                        // Save the call sheet to Core Data
                        CallSheetDataService.shared.saveCallSheet(savedSheet, projectID: projectID, in: moc)
                        showCallSheetEditor = false
                        selectedShootDayIndex = nil
                    }
                )
                .frame(minWidth: 1200, minHeight: 800)
            }
        }
    }

    // MARK: - Action Buttons Toolbar
    private var actionButtonsToolbar: some View {
        HStack(spacing: 8) {
            // Schedule Version Dropdown (left side)
            versionDropdown

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Main Actions
            HStack(spacing: 8) {
                // Add Strip
                toolbarButton(icon: "plus.circle.fill", title: "New Strip", action: addStrip)
                    .keyboardShortcut("n", modifiers: [.command])
                    .customTooltip(Tooltips.Scheduler.newStrip)

                // Day Break
                toolbarButton(icon: "calendar.badge.plus", title: "Day Break", action: addDayBreak)
                    .customTooltip(Tooltips.Scheduler.dayBreak)

                // Off Day
                toolbarButton(icon: "moon.fill", title: "Off Day", action: addOffDay)
                    .customTooltip(Tooltips.Scheduler.offDay)

                // Add Banner
                toolbarButton(icon: "flag.fill", title: "Banner", action: addBanner)
                    .customTooltip(Tooltips.Scheduler.banner)
            }

            // Density Button (cycles through options)
            toolbarButton(
                icon: density.iconName,
                title: "Density",
                action: cycleDensity
            )
            .customTooltip(Tooltips.Scheduler.density)

            // Delete Button
            toolbarButton(
                icon: "trash",
                title: "Delete",
                action: deleteSelected,
                disabled: selectedIDs.isEmpty
            )
            .customTooltip(Tooltips.Scheduler.deleteStrip)

            // Duplicate Button
            toolbarButton(
                icon: "plus.square.on.square",
                title: "Duplicate",
                action: duplicateSelected,
                disabled: selectedIDs.isEmpty
            )
            .customTooltip(Tooltips.Scheduler.duplicateStrip)

            // Sort Menu
            Menu {
                ForEach(StripboardSortOption.allCases) { option in
                    Button {
                        sortStripboard(by: option, direction: .ascending)
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }

                Divider()

                Menu("Sort Descending") {
                    ForEach(StripboardSortOption.allCases) { option in
                        Button {
                            sortStripboard(by: option, direction: .descending)
                        } label: {
                            Label(option.rawValue, systemImage: option.icon)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .frame(width: 32, height: 28)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.025))
                        }
                        .shadow(color: Color.black.opacity(0.04), radius: 1.5, x: 0, y: 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .customTooltip("Sort stripboard scenes")

            // Strip Colors Button
            toolbarButton(
                icon: "paintpalette",
                title: "Colors",
                action: { showColorCustomizer = true }
            )
            .customTooltip(Tooltips.Scheduler.stripColors)

            // Set Dates Button
            toolbarButton(
                icon: "calendar.badge.clock",
                title: "Set Dates",
                action: { showSetDatesSheet = true }
            )
            .customTooltip(Tooltips.Scheduler.setDates)

            // Add Call Time Banner Button
            toolbarButton(
                icon: "bell.badge.clock",
                title: "Call Time",
                action: addCallTimeBanner
            )

            // Add Meals Banner Button
            toolbarButton(
                icon: "fork.knife",
                title: "Meals",
                action: addMealsBanner
            )

            // Generate Call Sheet Button
            toolbarButton(
                icon: "doc.text.fill",
                title: "Call Sheet",
                action: generateCallSheetFromSelectedDay,
                disabled: selectedShootDayIndex == nil
            )
            .customTooltip(Tooltips.Scheduler.generateCallSheet)

            // Export Button (Stripboard PDF)
            Button {
                print("🟢 Export button clicked!")
                exportPDF()
            } label: {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .frame(width: 32, height: 28)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.025))
                        }
                        .shadow(color: Color.black.opacity(0.04), radius: 1.5, x: 0, y: 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .customTooltip("Export stripboard PDF")

            Spacer()

            // MARK: - Navigation Tab Buttons
            navigationTabButtons

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            // Inspector Toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showInspector.toggle()
                }
            } label: {
                Image(systemName: showInspector ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 15))
                    .foregroundColor(showInspector ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .customTooltip(showInspector ? "Hide Inspector" : "Show Inspector")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.02),
                        Color.primary.opacity(0.01)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }
    
    private var hasActiveFilters: Bool {
        !filterInt || !filterExt || !filterDay || !filterNight || !filterDawn || !filterDusk || !filterLocation.isEmpty
    }

    // MARK: - Production Overview
    private var productionOverview: some View {
        HStack(spacing: 24) {
            // Production Days (selectable for call sheet generation)
            if !dayBreakItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(dayBreakItems.enumerated()), id: \.0) { index, item in
                            productionDayChip(
                                title: item.title,
                                date: item.date,
                                pages: item.pages,
                                index: index,
                                isSelected: selectedShootDayIndex == index
                            )
                        }
                    }
                    .padding(6) // Allow room for selection scale effect and shadow
                }
            }

            Spacer()

            // Stats
            HStack(spacing: 24) {
                statItem(icon: "film.stack", label: "Scenes", value: "\(filteredScenes.count)")
                statItem(icon: "doc.plaintext", label: "Pages", value: totalMetricLabel)
                if !selectedIDs.isEmpty {
                    statItem(icon: "checkmark.circle.fill", label: "Selected", value: "\(selectedIDs.count)")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .shadow(color: Color.black.opacity(0.03), radius: 1.5, y: 1)
        )
    }
    
    private func statItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary.opacity(0.85))
            }
        }
    }
    
    private func productionDayChip(title: String, date: String?, pages: String, index: Int, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)

            if let d = date, !d.isEmpty {
                Text(d)
                    .font(.system(size: 9.5, weight: .medium))
                    .opacity(0.9)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Image(systemName: "doc.plaintext")
                    .font(.system(size: 9, weight: .medium))
                Text(pages)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .opacity(0.95)
        }
        .frame(minWidth: 85, maxWidth: 85)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [Color.orange, Color.orange.opacity(0.85)]
                            : [Color.accentColor, Color.accentColor.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: isSelected ? Color.orange.opacity(0.4) : Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(isSelected ? 0.5 : 0), lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if selectedShootDayIndex == index {
                    selectedShootDayIndex = nil
                } else {
                    selectedShootDayIndex = index
                }
            }
        }
    }

    // MARK: - Navigation Tab Buttons (Toolbar)
    private var navigationTabButtons: some View {
        HStack(spacing: 2) {
            ForEach(SchedulerTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Image(systemName: tabIcon(for: tab))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.7))
                        .frame(width: 32, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.25) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(tab.rawValue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo, Color.indigo.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    private func tabIcon(for tab: SchedulerTab) -> String {
        switch tab {
        case .stripboard: return "rectangle.grid.2x2"
        case .dood: return "calendar.badge.clock"
        case .callSheets: return "doc.text"
        }
    }

    // MARK: - Toolbar Button Helper
    private func toolbarButton(icon: String, title: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.4) : Color.primary.opacity(0.75))
                .frame(width: 32, height: 28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(disabled ? 0.015 : 0.025))
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 1.5, x: 0, y: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .customTooltip(title)
    }

    // MARK: - Version Dropdown
    private var versionDropdown: some View {
        Menu {
            // Script Revision Section
            Section("Script Revision") {
                // Current loaded script
                if let scriptName = selectedVersion?.scriptDisplayName {
                    HStack {
                        Circle()
                            .fill(scriptRevisionColor(for: selectedVersion?.scriptColorName))
                            .frame(width: 8, height: 8)
                        Text(scriptName)
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("No script loaded")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Available revisions to load
                if scriptSyncService.sentRevisions.isEmpty {
                    Text("No revisions available")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(scriptSyncService.sentRevisions) { revision in
                        Button(action: {
                            loadScriptRevision(revision)
                        }) {
                            HStack {
                                Circle()
                                    .fill(revision.color)
                                    .frame(width: 8, height: 8)
                                Text(revision.displayName)
                                Spacer()
                                if !revision.loadedInScheduler {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            // Schedule Versions Section
            Section("Schedule Versions") {
                ForEach(scheduleVersions) { version in
                    Button(action: {
                        selectVersion(version)
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.caption)
                            Text(version.name)
                            Spacer()
                            if version.id == selectedVersion?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            Divider()

            // Actions Section
            Section {
                Button(action: {
                    showingNewVersionDialog = true
                }) {
                    Label("New Schedule Version", systemImage: "plus.circle")
                }

                if let selectedVersion = selectedVersion {
                    Button(action: {
                        duplicateVersion(selectedVersion)
                    }) {
                        Label("Duplicate Current", systemImage: "doc.on.doc")
                    }

                    Button(action: {
                        versionToRename = selectedVersion
                        showingRenameVersionDialog = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }

                    if scheduleVersions.count > 1 {
                        Divider()

                        Button(role: .destructive, action: {
                            versionToDelete = selectedVersion
                            showingDeleteVersionAlert = true
                        }) {
                            Label("Delete Version", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                // Version icon with background
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Schedule")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if scriptSyncService.hasUpdatesAvailable(for: .scheduler) {
                            Circle()
                                .fill(.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(selectedVersion?.name ?? "No Version")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .frame(maxWidth: 220)
        .menuStyle(.borderlessButton)
    }

    /// Get color for script revision color name
    private func scriptRevisionColor(for colorName: String?) -> Color {
        guard let name = colorName?.lowercased() else { return .gray }
        switch name {
        case "white": return Color(red: 1.0, green: 1.0, blue: 1.0)
        case "blue": return Color(red: 0.68, green: 0.85, blue: 0.90)
        case "pink": return Color(red: 1.0, green: 0.75, blue: 0.80)
        case "yellow": return Color(red: 1.0, green: 1.0, blue: 0.60)
        case "green": return Color(red: 0.60, green: 0.98, blue: 0.60)
        case "goldenrod": return Color(red: 0.93, green: 0.79, blue: 0.45)
        case "buff": return Color(red: 0.94, green: 0.86, blue: 0.70)
        case "salmon": return Color(red: 1.0, green: 0.63, blue: 0.48)
        case "cherry": return Color(red: 0.87, green: 0.44, blue: 0.63)
        case "tan": return Color(red: 0.82, green: 0.71, blue: 0.55)
        case "gray", "grey": return Color(red: 0.83, green: 0.83, blue: 0.83)
        default: return .gray
        }
    }

    /// Load a script revision into the scheduler
    private func loadScriptRevision(_ revision: SentRevision) {
        guard !isLoadingScriptRevision else { return }
        isLoadingScriptRevision = true

        Task {
            do {
                let result = try await scriptSyncService.loadRevision(
                    revision,
                    into: .scheduler,
                    context: moc
                )

                // Update the selected version with script reference
                if var version = selectedVersion,
                   let index = scheduleVersions.firstIndex(where: { $0.id == version.id }) {
                    version.scriptRevisionId = revision.revisionId
                    version.scriptColorName = revision.colorName
                    version.scriptLoadedDate = Date()
                    scheduleVersions[index] = version
                    selectedVersion = version
                    saveVersions()
                }

                lastMergeResult = result
                showMergeResultAlert = true
                reload()
            } catch {
                print("[SchedulerView] Failed to load script revision: \(error)")
            }

            isLoadingScriptRevision = false
        }
    }

    // MARK: - Stripboard Content
    private var stripboardContent: some View {
        VStack(spacing: 0) {
            // Action Buttons Toolbar
            actionButtonsToolbar

            Divider()

            // Column Headers
            stripboardHeaders
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredScenes.isEmpty {
                        emptyStateView
                            .padding(.top, 60)
                    } else {
                        ForEach(Array(filteredScenes.enumerated()), id: \.1.objectID) { i, scene in
                            let sceneURI = scene.objectID.uriRepresentation()
                            gridRow(scene: scene, index: i)
                                .id(scene.objectID)
                                .draggable(sceneURI)
                                .dropDestination(for: URL.self, action: { urls, _ in
                                    self.handleDrop(urls: urls, before: scene.objectID)
                                }, isTargeted: { isOver in
                                    dragOverID = isOver ? scene.objectID : nil
                                })
                                .overlay(alignment: .top) {
                                    if dragOverID == scene.objectID {
                                        Rectangle()
                                            .frame(height: 2.5)
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 10)
                                    }
                                }
                        }

                        // Drop zone at end
                        Color.clear
                            .frame(height: 50)
                            .dropDestination(for: URL.self, action: { urls, _ in
                                self.handleDrop(urls: urls, before: nil)
                            })
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stripboardHeaders: some View {
        HStack(spacing: 0) {
            // Spacer for disclosure button (24 + 8 padding = 32)
            Spacer()
                .frame(width: 32)

            // Scene # column (matches row's 50pt)
            Text("#")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 50, alignment: .center)

            // Scene Setting column - flexible width to fill available space
            Text("Scene Setting")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

            Text("Cast ID")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 180, alignment: .center)

            Text("Pages")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 120, alignment: .center)

            Text("Prep")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 180, alignment: .center)

            Text("Location")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 120, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.04))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Grid Row (Outputs 6 cells for grid)
    @ViewBuilder
    private func gridRow(scene: NSManagedObject, index: Int) -> some View {
        let d = sceneDisplay[scene.objectID]
        let num = d?.number ?? (firstString(scene, keys: ["number"]) ?? "—")
        let intExt = (d?.intExtUpper ?? firstString(scene, keys: ["locationType", "intExt"]) ?? "")
        let heading = d?.heading ?? (firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "—")
        let time = d?.timeUpper ?? (firstString(scene, keys: ["timeOfDay", "time"]) ?? "")
        let pgLength = d?.pageLen ?? pageLengthString(scene)
        let shootLoc = d?.shootLoc ?? (firstString(scene, keys: ["shootLocation", "shootingLocation", "locationName"]) ?? "—")

        let isSelected = selectedIDs.contains(scene.objectID)
        let isDayBreak = isDayBreakRow(scene)
        let isOffDay = isOffDayRow(scene)
        let isDivider = isDayBreak || isOffDay
        let isHovered = hoveredRowID == scene.objectID

        let description = firstString(scene, keys: ["descriptionText", "sceneDescription", "description"]) ?? ""
        let castIDs = firstString(scene, keys: ["castIDs", "cast"]) ?? ""
        let setupTime = firstString(scene, keys: ["setupTime", "setupMinutes"]) ?? ""

        // Calculate divider data outside ViewBuilder
        let overridePgLen: String? = {
            if isDivider, let idxAll = scenes.firstIndex(where: { $0.objectID == scene.objectID }), isDayBreak {
                let total = totalEighthsForDayEnding(beforeIndex: idxAll)
                return formatEighths(total)
            }
            return nil
        }()

        let dateLabel: String? = {
            if isDivider, let idxAll = scenes.firstIndex(where: { $0.objectID == scene.objectID }) {
                let calculatedDate = calculateDateForStrip(at: idxAll)
                return calculatedDate.map { shortDateFormatter.string(from: $0) }
            }
            return nil
        }()

        let dayNumber: Int? = {
            if isDivider, let idxAll = scenes.firstIndex(where: { $0.objectID == scene.objectID }), isDayBreak {
                return calculateDayNumber(at: idxAll)
            }
            return nil
        }()

        if isDivider {
            // Divider rows span all 6 columns
            dividerRow(
                heading: heading,
                isDayBreak: isDayBreak,
                isOffDay: isOffDay,
                dayNumber: dayNumber,
                pages: overridePgLen,
                date: dateLabel,
                isSelected: isSelected,
                scene: scene
            )
            .gridCellColumns(6)
        } else {
            // Standard row: Single continuous strip spanning all columns
            let isExpanded = expandedSceneIDs.contains(scene.objectID)
            let tint = d?.tint ?? stripTintColor(intExt: intExt, time: time)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Disclosure button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedSceneIDs.contains(scene.objectID) {
                                expandedSceneIDs.remove(scene.objectID)
                            } else {
                                expandedSceneIDs.insert(scene.objectID)
                            }
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)

                    // Column 1: Scene Number
                    Text(num)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary.opacity(0.9))
                        .frame(width: 50, alignment: .center)

                    // Column 2: Scene Setting (heading + description) - flexible width
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 0) {
                            if !intExt.isEmpty {
                                Text(intExt.uppercased())
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundColor(.primary.opacity(0.85))
                                Text(" ")
                                    .font(.system(size: 12.5))
                            }
                            Text(heading.uppercased())
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.85))
                            Text(" - ")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(time.uppercased())
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.85))
                        }
                        .lineLimit(1)

                        if !description.isEmpty {
                            Text(description)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)

                    // Column 3: Cast ID
                    Text(castIDs.isEmpty ? "-" : castIDs)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                        .frame(width: 180, alignment: .center)

                    // Column 4: Pages
                    Text(pgLength)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary.opacity(0.85))
                        .frame(width: 120, alignment: .center)

                    // Column 5: Estimation (Setup + Shoot time combined)
                    Text(setupTime.isEmpty ? "-" : setupTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                        .frame(width: 180, alignment: .center)

                    // Column 6: Location
                    Text(shootLoc.isEmpty ? "-" : shootLoc)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.primary.opacity(0.75))
                        .frame(width: 120, alignment: .center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(height: density.rowHeight)
                .background(
                    ZStack {
                        // Base card background
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))

                        // Tint color overlay
                        if let tint = tint {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(tint.opacity(0.35))
                        }

                        // Hover effect
                        if isHovered && !isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.06))
                        }
                    }
                    .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 4 : 2.5, x: 0, y: 1)
                )

                // Expandable dropdown content
                if isExpanded {
                    sceneStripDropdownContent(scene: scene)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background(
                            ZStack {
                                if let tint = tint {
                                    tint.opacity(0.5)
                                } else {
                                    Color(nsColor: .controlBackgroundColor).opacity(0.5)
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.06),
                        lineWidth: isSelected ? 2.5 : 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                handleSelect(for: scene.objectID, at: index)
            }
            .onHover { hovering in
                hoveredRowID = hovering ? scene.objectID : nil
                if hovering && !isSelected {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .contextMenu {
                Button("Copy") { copySelectedToPasteboard() }
                Button("Cut") { cutSelected() }
                Button("Paste") { pasteFromPasteboard() }
                Divider()
                Button("Duplicate") { duplicateSelected() }
                    .disabled(selectedIDs.isEmpty)
                Divider()
                Button("Delete", role: .destructive) { deleteSelected() }
                    .disabled(selectedIDs.isEmpty)
            }
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
            .gridCellColumns(6)
        }
    }

    // MARK: - Scene Row (Redesigned)
    private func sceneRow(scene: NSManagedObject, index: Int) -> some View {
        let d = sceneDisplay[scene.objectID]
        let num = d?.number ?? (firstString(scene, keys: ["number"]) ?? "—")
        let intExt = (d?.intExtUpper ?? firstString(scene, keys: ["locationType", "intExt"]) ?? "")
        let heading = d?.heading ?? (firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "—")
        let time = d?.timeUpper ?? (firstString(scene, keys: ["timeOfDay", "time"]) ?? "")
        let pgLength = d?.pageLen ?? pageLengthString(scene)
        let shootLoc = d?.shootLoc ?? (firstString(scene, keys: ["shootLocation", "shootingLocation", "locationName"]) ?? "—")
        
        let isSelected = selectedIDs.contains(scene.objectID)
        let isDayBreak = isDayBreakRow(scene)
        let isOffDay = isOffDayRow(scene)
        let isDivider = isDayBreak || isOffDay
        let isHovered = hoveredRowID == scene.objectID
        
        var overridePgLen: String? = nil
        var dateLabel: String? = nil
        var dayNumber: Int? = nil
        
        if isDayBreak || isOffDay {
            if let idxAll = scenes.firstIndex(where: { $0.objectID == scene.objectID }) {
                if isDayBreak {
                    let total = totalEighthsForDayEnding(beforeIndex: idxAll)
                    overridePgLen = formatEighths(total)
                }
                
                // Calculate the date for this day break or off day
                let calculatedDate = calculateDateForStrip(at: idxAll)
                dateLabel = calculatedDate.map { shortDateFormatter.string(from: $0) }
                
                // Calculate day number for day breaks
                if isDayBreak {
                    dayNumber = calculateDayNumber(at: idxAll)
                }
            }
        }
        
        return Group {
            if isDivider {
                dividerRow(
                    heading: heading,
                    isDayBreak: isDayBreak,
                    isOffDay: isOffDay,
                    dayNumber: dayNumber,
                    pages: overridePgLen,
                    date: dateLabel,
                    isSelected: isSelected,
                    scene: scene
                )
            } else {
                standardRow(
                    num: num,
                    intExt: intExt,
                    heading: heading,
                    time: time,
                    pages: pgLength,
                    location: shootLoc,
                    isSelected: isSelected,
                    isHovered: isHovered,
                    tint: d?.tint ?? stripTintColor(intExt: intExt, time: time),
                    scene: scene,
                    index: index
                )
            }
        }
    }
    
    private func standardRow(
        num: String,
        intExt: String,
        heading: String,
        time: String,
        pages: String,
        location: String,
        isSelected: Bool,
        isHovered: Bool,
        tint: Color?,
        scene: NSManagedObject,
        index: Int
    ) -> some View {
        // Get additional scene data
        let description = firstString(scene, keys: ["descriptionText", "sceneDescription", "description"]) ?? ""
        let castIDs = firstString(scene, keys: ["castIDs", "cast"]) ?? ""
        let setupTime = firstString(scene, keys: ["setupTime", "setupMinutes"]) ?? ""
        let isExpanded = expandedSceneIDs.contains(scene.objectID)

        return VStack(spacing: 0) {
            // Main strip row
            HStack(spacing: 0) {
                // Disclosure button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedSceneIDs.contains(scene.objectID) {
                            expandedSceneIDs.remove(scene.objectID)
                        } else {
                            expandedSceneIDs.insert(scene.objectID)
                        }
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)

                // Column 1: Scene Number
                Text(num)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary.opacity(0.9))
                    .frame(width: 50, alignment: .center)

                // Column 2: Scene Setting (heading + description) - flexible width
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 0) {
                        if !intExt.isEmpty {
                            Text(intExt.uppercased())
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.primary.opacity(0.85))
                            Text(" ")
                                .font(.system(size: 12.5))
                        }
                        Text(heading.uppercased())
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.85))
                        Text(" - ")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(time.uppercased())
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.85))
                    }
                    .lineLimit(1)

                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

                // Column 3: Cast ID
                Text(castIDs.isEmpty ? "-" : castIDs)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 180, alignment: .center)

                // Column 4: Pages
                Text(pages)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary.opacity(0.85))
                    .frame(width: 120, alignment: .center)

                // Column 5: Estimation (Setup + Shoot time combined)
                Text(setupTime.isEmpty ? "-" : setupTime)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 180, alignment: .center)

                // Column 6: Location
                Text(location.isEmpty ? "-" : location)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.primary.opacity(0.75))
                    .frame(width: 120, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(height: density.rowHeight)
            .background(
                ZStack {
                    // Base color
                    if let tint = tint {
                        tint
                    } else {
                        Color(nsColor: .controlBackgroundColor)
                    }

                    // Hover state
                    if isHovered && !isSelected {
                        Color.accentColor.opacity(0.05)
                    }
                }
            )

            // Expandable dropdown content
            if isExpanded {
                sceneStripDropdownContent(scene: scene)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(
                        ZStack {
                            if let tint = tint {
                                tint.opacity(0.5)
                            } else {
                                Color(nsColor: .controlBackgroundColor).opacity(0.5)
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            handleSelect(for: scene.objectID, at: index)
        }
        .onHover { hovering in
            hoveredRowID = hovering ? scene.objectID : nil
            if hovering && !isSelected {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .contextMenu {
            Button("Copy") { copySelectedToPasteboard() }
            Button("Cut") { cutSelected() }
            Button("Paste") { pasteFromPasteboard() }
            Divider()
            Button("Duplicate") { duplicateSelected() }
                .disabled(selectedIDs.isEmpty)
            Divider()
            Button("Delete", role: .destructive) { deleteSelected() }
                .disabled(selectedIDs.isEmpty)
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Scene Strip Dropdown Content
    private func sceneStripDropdownContent(scene: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Elements Section
            sceneStripElementsSection(scene: scene)

            Divider()
                .padding(.horizontal, 8)

            // Shots Section
            sceneStripShotsSection(scene: scene)

            Divider()
                .padding(.horizontal, 8)

            // Day Logistics Section
            sceneStripDayLogisticsSection(scene: scene)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func sceneStripElementsSection(scene: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)
                Text("Elements")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            let castIDs = firstString(scene, keys: ["castIDs"]) ?? ""
            let extras = firstString(scene, keys: ["extras"]) ?? ""
            let props = firstString(scene, keys: ["props"]) ?? ""
            let wardrobe = firstString(scene, keys: ["wardrobe"]) ?? ""
            let vehicles = firstString(scene, keys: ["vehicles"]) ?? ""

            let hasElements = !castIDs.isEmpty || !extras.isEmpty || !props.isEmpty ||
                             !wardrobe.isEmpty || !vehicles.isEmpty

            if hasElements {
                // Horizontal flow layout for all element badges
                WrappingHStack(alignment: .leading, spacing: 6) {
                    if !castIDs.isEmpty {
                        ForEach(parseCSV(castIDs).prefix(5), id: \.self) { item in
                            dropdownElementBadge(icon: "person.fill", text: item, color: .blue)
                        }
                        if parseCSV(castIDs).count > 5 {
                            dropdownElementBadge(icon: "person.2.fill", text: "+\(parseCSV(castIDs).count - 5)", color: .blue.opacity(0.7))
                        }
                    }
                    if !extras.isEmpty {
                        ForEach(parseCSV(extras).prefix(3), id: \.self) { item in
                            dropdownElementBadge(icon: "person.3.fill", text: item, color: .cyan)
                        }
                        if parseCSV(extras).count > 3 {
                            dropdownElementBadge(icon: "person.3.fill", text: "+\(parseCSV(extras).count - 3)", color: .cyan.opacity(0.7))
                        }
                    }
                    if !props.isEmpty {
                        ForEach(parseCSV(props).prefix(3), id: \.self) { item in
                            dropdownElementBadge(icon: "cube.fill", text: item, color: .orange)
                        }
                        if parseCSV(props).count > 3 {
                            dropdownElementBadge(icon: "cube.fill", text: "+\(parseCSV(props).count - 3)", color: .orange.opacity(0.7))
                        }
                    }
                    if !wardrobe.isEmpty {
                        ForEach(parseCSV(wardrobe).prefix(3), id: \.self) { item in
                            dropdownElementBadge(icon: "tshirt.fill", text: item, color: .pink)
                        }
                        if parseCSV(wardrobe).count > 3 {
                            dropdownElementBadge(icon: "tshirt.fill", text: "+\(parseCSV(wardrobe).count - 3)", color: .pink.opacity(0.7))
                        }
                    }
                    if !vehicles.isEmpty {
                        ForEach(parseCSV(vehicles).prefix(3), id: \.self) { item in
                            dropdownElementBadge(icon: "car.fill", text: item, color: .green)
                        }
                        if parseCSV(vehicles).count > 3 {
                            dropdownElementBadge(icon: "car.fill", text: "+\(parseCSV(vehicles).count - 3)", color: .green.opacity(0.7))
                        }
                    }
                }
            } else {
                Text("No elements")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func dropdownElementBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func sceneStripShotsSection(scene: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                Text("Shots")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                let shots = getShotsForScene(scene)
                if !shots.isEmpty {
                    Text("\(shots.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.12))
                        )
                }
            }

            let shots = getShotsForScene(scene)
            if !shots.isEmpty {
                // Horizontal flow layout for shot badges
                WrappingHStack(alignment: .leading, spacing: 6) {
                    ForEach(shots.prefix(8), id: \.objectID) { shot in
                        dropdownShotBadge(shot: shot)
                    }
                    if shots.count > 8 {
                        Text("+\(shots.count - 8)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.red.opacity(0.08))
                            )
                    }
                }
            } else {
                Text("No shots")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func dropdownShotBadge(shot: NSManagedObject) -> some View {
        let shotCode = firstString(shot, keys: ["code", "shotCode", "title"]) ?? "—"
        let shotNumber = firstString(shot, keys: ["number", "shotNumber"]) ?? ""
        let shotType = firstString(shot, keys: ["type", "shotType"]) ?? ""

        return HStack(spacing: 4) {
            if !shotNumber.isEmpty {
                Text(shotNumber)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.indigo)
                    )
            }

            Text(shotCode)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if !shotType.isEmpty {
                Text(shotType)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
        )
    }

    private func sceneStripDayLogisticsSection(scene: NSManagedObject) -> some View {
        let shootLoc = firstString(scene, keys: ["shootLocation", "actualLocation", "locationName"]) ?? ""
        let setupTime = firstString(scene, keys: ["setupTime", "setupMinutes"]) ?? ""
        let callTime = firstString(scene, keys: ["callTime"]) ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text("Day Logistics")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Location
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text("Location:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(shootLoc.isEmpty ? "Not set" : shootLoc)
                        .font(.system(size: 11))
                        .foregroundStyle(shootLoc.isEmpty ? .tertiary : .primary)
                }

                // Setup Time
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text("Setup Time:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(setupTime.isEmpty ? "Not set" : setupTime)
                        .font(.system(size: 11))
                        .foregroundStyle(setupTime.isEmpty ? .tertiary : .primary)
                }

                // Call Time
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text("Call Time:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(callTime.isEmpty ? "Not set" : callTime)
                        .font(.system(size: 11))
                        .foregroundStyle(callTime.isEmpty ? .tertiary : .primary)
                }
            }
        }
    }

    private func dividerRow(
        heading: String,
        isDayBreak: Bool,
        isOffDay: Bool,
        dayNumber: Int?,
        pages: String?,
        date: String?,
        isSelected: Bool,
        scene: NSManagedObject
    ) -> some View {
        let displayHeading: String = {
            if isDayBreak, let dayNum = dayNumber {
                let totalDays = scenes.filter { isDayBreakRow($0) }.count
                return "END OF DAY \(dayNum) of \(totalDays)"
            } else if isOffDay {
                return "OFF DAY"
            }
            return heading
        }()

        // Get full date string for day breaks
        let fullDateString: String? = {
            guard isDayBreak else { return nil }
            // Try to parse the date and format it
            if let dateStr = date,
               let parsedDate = shortDateFormatter.date(from: dateStr) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d, yyyy"
                return formatter.string(from: parsedDate)
            }
            return nil
        }()

        return HStack {
            Spacer()

            if isDayBreak {
                // Centered text with dash and full date
                HStack(spacing: 8) {
                    Text(displayHeading)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    if let fullDate = fullDateString {
                        Text("-")
                            .foregroundColor(.white.opacity(0.7))
                        Text(fullDate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            } else if isOffDay {
                // OFF DAY with icon
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayHeading)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        if let date = date {
                            Text(date)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            } else {
                // Generic divider
                Text(heading)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isDayBreak ? Color.black : (isOffDay ? Color.orange : Color.accentColor)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            if let index = scenes.firstIndex(where: { $0.objectID == scene.objectID }) {
                handleSelect(for: scene.objectID, at: index)
            }
        }
        .contextMenu {
            Button("Copy") { copySelectedToPasteboard() }
            Button("Cut") { cutSelected() }
            Button("Paste") { pasteFromPasteboard() }
            Divider()
            Button("Duplicate") { duplicateSelected() }
                .disabled(selectedIDs.isEmpty)
            Divider()
            Button("Delete", role: .destructive) { deleteSelected() }
                .disabled(selectedIDs.isEmpty)
        }
    }
    
    private func timeIcon(for time: String) -> String {
        let t = time.uppercased()
        if t.contains("DAY") { return "sun.max.fill" }
        if t.contains("NIGHT") { return "moon.fill" }
        if t.contains("DAWN") { return "sunrise.fill" }
        if t.contains("DUSK") { return "sunset.fill" }
        return "clock.fill"
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 6) {
                Text("No Scenes Yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Add scene strips in Breakdowns or use the + button above")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                addStrip()
            } label: {
                Label("Add Your First Strip", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: 400)
        .padding(40)
    }

    // MARK: - Inspector Panel (Redesigned)
    private var inspectorPanel: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("", selection: $inspectorTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Tab Content
            switch inspectorTab {
            case .sceneData:
                sceneDataTabContent
            case .overview:
                overviewTabContent
            }
        }
        .frame(width: inspectorWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Scene Data Tab
    private var sceneDataTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Selected Scene Card
                if let firstSelected = selectedIDs.first,
                   let scene = scenes.first(where: { $0.objectID == firstSelected }) {
                    selectedSceneCard(scene: scene)
                } else {
                    noSelectionCard
                }

                // Shoot Dates Card
                shootDatesCard

                // Shots Card (dedicated panel)
                if let firstSelected = selectedIDs.first,
                   let scene = scenes.first(where: { $0.objectID == firstSelected }) {
                    shotsCard(scene: scene)
                }

                // Locations Card
                locationsCard

                // Cast Card
                castCard

                // Crew Card
                crewCard
            }
            .padding(20)
        }
    }

    // MARK: - Overview Tab
    private var overviewTabContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(scenes, id: \.objectID) { scene in
                    compactSceneStrip(scene: scene)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Cast & Crew State
    @State private var showAddCastSheet = false
    @State private var showAddCrewSheet = false
    @State private var showAddUnitSheet = false
    @State private var expandedUnits: Set<UUID> = []

    private func fetchCastContacts() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        request.predicate = NSPredicate(format: "category == %@", "cast")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        let allCast = (try? moc.fetch(request)) ?? []

        // Filter by selected scene's castIDs
        guard let firstSelected = selectedIDs.first,
              let scene = scenes.first(where: { $0.objectID == firstSelected }),
              let castIDsString = firstString(scene, keys: ["castIDs", "cast"]),
              !castIDsString.isEmpty else {
            return []
        }

        // Parse cast IDs - format is "1: Name, 2: Name" or just "1, 2"
        // Extract the numeric IDs before the colon (if present)
        let castIDs: [Int32] = castIDsString.split(separator: ",").compactMap { part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            // Handle "1: Name" format - extract number before colon
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let idPart = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
                return Int32(idPart)
            }
            // Handle plain number format
            return Int32(trimmed)
        }

        // Filter cast members whose sortOrder matches the scene's cast IDs
        return allCast.filter { contact in
            if let sortOrder = contact.value(forKey: "sortOrder") as? Int32 {
                return castIDs.contains(sortOrder)
            }
            return false
        }
    }

    private func fetchCrewContacts() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        request.predicate = NSPredicate(format: "category == %@", "crew")
        request.sortDescriptors = [NSSortDescriptor(key: "department", ascending: true), NSSortDescriptor(key: "sortOrder", ascending: true)]
        return (try? moc.fetch(request)) ?? []
    }

    private func fetchUnits() -> [SchedulerUnitData] {
        guard let data = UserDefaults.standard.data(forKey: "production_units"),
              let units = try? JSONDecoder().decode([SchedulerUnitData].self, from: data) else {
            return []
        }
        return units.sorted { $0.name < $1.name }
    }

    private func crewMemberRow(contact: NSManagedObject) -> some View {
        let name = contact.value(forKey: "name") as? String ?? "Unknown"
        let role = contact.value(forKey: "role") as? String ?? ""
        let department = contact.value(forKey: "department") as? String ?? ""

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                if !role.isEmpty {
                    Text(role)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !department.isEmpty {
                let cleanDept = department
                    .replacingOccurrences(of: "📋 ", with: "")
                    .replacingOccurrences(of: "🎥 ", with: "")
                    .replacingOccurrences(of: "💡 ", with: "")
                    .replacingOccurrences(of: "🔈 ", with: "")
                    .replacingOccurrences(of: "👗 ", with: "")
                    .replacingOccurrences(of: "💄 ", with: "")
                    .replacingOccurrences(of: "⚡ ", with: "")
                Text(String(cleanDept.prefix(12)) + (cleanDept.count > 12 ? "…" : ""))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func unitRow(unit: SchedulerUnitData) -> some View {
        let isExpanded = expandedUnits.contains(unit.id)

        return VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedUnits.remove(unit.id)
                    } else {
                        expandedUnits.insert(unit.id)
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)

                    Text(unit.name)
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text("\(unit.memberIDs.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.08))
            )

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(unit.memberIDs, id: \.self) { memberID in
                        if let contact = fetchContact(by: memberID) {
                            crewMemberRow(contact: contact)
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func fetchContact(by id: UUID) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? moc.fetch(request))?.first
    }

    // MARK: - Compact Scene Strip for Overview
    private func compactSceneStrip(scene: NSManagedObject) -> some View {
        let d = sceneDisplay[scene.objectID]
        let num = d?.number ?? (firstString(scene, keys: ["number"]) ?? "—")
        let intExt = (d?.intExtUpper ?? firstString(scene, keys: ["locationType", "intExt"]) ?? "")
        let heading = d?.heading ?? (firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "—")
        let time = d?.timeUpper ?? (firstString(scene, keys: ["timeOfDay", "time"]) ?? "")
        let pgLength = d?.pageLen ?? pageLengthString(scene)

        let isSelected = selectedIDs.contains(scene.objectID)
        let isDayBreak = isDayBreakRow(scene)
        let isOffDay = isOffDayRow(scene)

        return Group {
            if isDayBreak {
                compactDayBreakStrip(scene: scene, heading: heading)
            } else if isOffDay {
                compactOffDayStrip(heading: heading)
            } else {
                compactStandardStrip(
                    num: num,
                    intExt: intExt,
                    heading: heading,
                    time: time,
                    pages: pgLength,
                    isSelected: isSelected,
                    tint: d?.tint ?? stripTintColor(intExt: intExt, time: time),
                    scene: scene
                )
            }
        }
    }

    private func compactStandardStrip(
        num: String,
        intExt: String,
        heading: String,
        time: String,
        pages: String,
        isSelected: Bool,
        tint: Color?,
        scene: NSManagedObject
    ) -> some View {
        HStack(spacing: 6) {
            // Scene number badge
            Text(num)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor)
                )

            // Scene info
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    if !intExt.isEmpty {
                        Text(intExt.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.8))
                        Text(" ")
                    }
                    Text(heading.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    if !time.isEmpty {
                        Text(time.uppercased())
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(pages)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint ?? Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedIDs = [scene.objectID]
            inspectorTab = .sceneData
        }
    }

    private func compactDayBreakStrip(scene: NSManagedObject, heading: String) -> some View {
        var dayNumber: Int? = nil
        var dateLabel: String? = nil

        if let idxAll = scenes.firstIndex(where: { $0.objectID == scene.objectID }) {
            dayNumber = calculateDayNumber(at: idxAll)
            let calculatedDate = calculateDateForStrip(at: idxAll)
            dateLabel = calculatedDate.map { shortDateFormatter.string(from: $0) }
        }

        return HStack(spacing: 6) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)

            if let day = dayNumber {
                Text("Day \(day)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
            } else {
                Text(heading)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            if let date = dateLabel {
                Text(date)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.orange.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func compactOffDayStrip(heading: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 10))
                .foregroundStyle(.purple)

            Text(heading.isEmpty ? "Off Day" : heading)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.purple.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func selectedSceneCard(scene: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with scene info
            VStack(alignment: .leading, spacing: 8) {
                let num = firstString(scene, keys: ["number"]) ?? "—"
                let heading = firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "—"
                let intExt = firstString(scene, keys: ["locationType", "intExt"]) ?? ""
                let time = firstString(scene, keys: ["timeOfDay", "time"]) ?? ""
                let pages = pageLengthString(scene)

                // Scene Number and Heading
                HStack(spacing: 10) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scene \(num)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(heading)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                // Metadata
                HStack(spacing: 8) {
                    if !intExt.isEmpty {
                        metadataItem(icon: "building.2", text: intExt)
                    }
                    if !time.isEmpty {
                        metadataItem(icon: "clock", text: time)
                    }
                    metadataItem(icon: "doc.plaintext", text: pages)
                }
            }

            Divider()

            // Elements Disclosure
            VStack(alignment: .leading, spacing: 12) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showElements.toggle() } }) {
                    HStack {
                        Text("Elements")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Image(systemName: showElements ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showElements {
                    sceneElementsView(scene: scene)
                }
            }
        }
        .schedulerCard()
    }
    
    private var noSelectionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Selection")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Select a scene to view details")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .schedulerCard()
    }

    private func shotsCard(scene: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with toggle
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showShots.toggle() } }) {
                HStack {
                    Image(systemName: "video.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)

                    Text("Shots")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    let shots = getShotsForScene(scene)
                    if !shots.isEmpty {
                        Text("\(shots.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.12))
                            )
                    }

                    Image(systemName: showShots ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showShots {
                let shots = getShotsForScene(scene)
                if !shots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(shots, id: \.objectID) { shot in
                            shotRowItem(shot: shot)
                        }
                    }
                } else {
                    Text("No shots added")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                }
            }
        }
        .schedulerCard()
    }
    
    private func metadataBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func sceneElementsView(scene: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let castIDs = firstString(scene, keys: ["castIDs"]) ?? ""
            let extras = firstString(scene, keys: ["extras"]) ?? ""
            let props = firstString(scene, keys: ["props"]) ?? ""
            let wardrobe = firstString(scene, keys: ["wardrobe"]) ?? ""
            let vehicles = firstString(scene, keys: ["vehicles"]) ?? ""
            let customCategoriesStr = firstString(scene, keys: ["customCategories"]) ?? ""

            let hasProductionElements = !castIDs.isEmpty || !extras.isEmpty || !props.isEmpty ||
                                       !wardrobe.isEmpty || !vehicles.isEmpty
            let hasCustomElements = !customCategoriesStr.isEmpty

            // Production Elements Section
            if hasProductionElements {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Production Elements")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                        .textCase(.uppercase)

                    // Two-column grid layout
                    let elements: [(title: String, icon: String, items: [String])] = [
                        !castIDs.isEmpty ? ("Cast", "person.2.fill", parseCSV(castIDs)) : nil,
                        !extras.isEmpty ? ("Extras", "person.3.fill", parseCSV(extras)) : nil,
                        !props.isEmpty ? ("Props", "cube.fill", parseCSV(props)) : nil,
                        !wardrobe.isEmpty ? ("Wardrobe", "tshirt.fill", parseCSV(wardrobe)) : nil,
                        !vehicles.isEmpty ? ("Vehicles", "car.fill", parseCSV(vehicles)) : nil
                    ].compactMap { $0 }

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], alignment: .leading, spacing: 16) {
                        ForEach(elements.indices, id: \.self) { index in
                            let element = elements[index]
                            elementSection(title: element.title, icon: element.icon, items: element.items)
                        }
                    }
                }
            }

            // Custom Elements Section
            if hasCustomElements {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Elements")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                        .textCase(.uppercase)

                    // Two-column grid layout for custom elements
                    let categories = parseCustomCategories(customCategoriesStr)
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], alignment: .leading, spacing: 16) {
                        ForEach(categories.indices, id: \.self) { index in
                            let category = categories[index]
                            elementSection(title: category.name, icon: "folder.fill", items: category.items)
                        }
                    }
                }
            }

            // Show message if no elements
            if !hasProductionElements && !hasCustomElements {
                Text("No elements added")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            }
        }
    }

    private func getShotsForScene(_ scene: NSManagedObject) -> [NSManagedObject] {
        // Try multiple relationship names
        let relationshipNames = ["shots", "shotItems", "sceneShots", "shotsSet"]
        for relName in relationshipNames {
            if scene.entity.relationshipsByName.keys.contains(relName),
               let shotsSet = scene.value(forKey: relName) as? NSSet {
                let shotsArray = shotsSet.allObjects as? [NSManagedObject] ?? []
                // Sort by index if available
                return shotsArray.sorted { shot1, shot2 in
                    let index1 = (shot1.value(forKey: "index") as? Int16) ?? 0
                    let index2 = (shot2.value(forKey: "index") as? Int16) ?? 0
                    return index1 < index2
                }
            }
        }
        return []
    }

    private func shotRowItem(shot: NSManagedObject) -> some View {
        let shotCode = firstString(shot, keys: ["code", "shotCode", "title"]) ?? "—"
        let shotNumber = firstString(shot, keys: ["number", "shotNumber"]) ?? ""
        let shotType = firstString(shot, keys: ["type", "shotType"]) ?? ""
        let shotCam = firstString(shot, keys: ["cam", "camera"]) ?? ""
        let shotLens = firstString(shot, keys: ["lens", "lensType"]) ?? ""
        let shotRig = firstString(shot, keys: ["rig", "rigType"]) ?? ""
        let shotStoryboard = firstString(shot, keys: ["screenReference", "screenRef", "reference", "ref"]) ?? ""
        let shotDescription = firstString(shot, keys: ["descriptionText", "shotDescription", "description"]) ?? ""

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // Shot number badge
                if !shotNumber.isEmpty {
                    Text("#\(shotNumber)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.indigo)
                        )
                }

                // Shot code
                Text(shotCode)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()
            }

            // Metadata badges (Type, Cam, Lens, Rig)
            HStack(spacing: 6) {
                if !shotType.isEmpty {
                    CompactBadge(text: shotType, color: .blue)
                }
                if !shotCam.isEmpty {
                    CompactBadge(text: shotCam, color: .green)
                }
                if !shotLens.isEmpty {
                    CompactBadge(text: shotLens, color: .orange)
                }
                if !shotRig.isEmpty {
                    CompactBadge(text: shotRig, color: .purple)
                }
            }

            // Storyboard reference
            if !shotStoryboard.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Reference Shot: \(shotStoryboard)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Shot description
            if !shotDescription.isEmpty {
                Text(shotDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    // Helper badge view for shot metadata
    private struct CompactBadge: View {
        let text: String
        let color: Color

        var body: some View {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.12))
                )
        }
    }

    private func elementSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private func parseCSV(_ csv: String) -> [String] {
        csv.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func parseCustomCategories(_ json: String) -> [(name: String, items: [String])] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return []
        }
        return dict.map { (name: $0.key, items: parseCSV($0.value)) }
    }

    private func hasAnyElements(_ scene: NSManagedObject) -> Bool {
        let cast = firstString(scene, keys: ["castIDs"]) ?? ""
        let extras = firstString(scene, keys: ["extras"]) ?? ""
        let props = firstString(scene, keys: ["props"]) ?? ""
        let wardrobe = firstString(scene, keys: ["wardrobe"]) ?? ""
        let vehicles = firstString(scene, keys: ["vehicles"]) ?? ""
        let custom = firstString(scene, keys: ["customCategories"]) ?? ""
        return !cast.isEmpty || !extras.isEmpty || !props.isEmpty ||
               !wardrobe.isEmpty || !vehicles.isEmpty || !custom.isEmpty
    }
    
    private var locationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.25), Color.green.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.4), lineWidth: 1)
                        )

                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.green)
                }

                Text("Locations")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                // Show synced location info if available
                if let firstSelected = selectedIDs.first,
                   let _ = scenes.first(where: { $0.objectID == firstSelected }),
                   let syncedLocationID = selectedLocationID,
                   let location = LocationDataManager.shared.getLocation(by: syncedLocationID) {
                    // Synced Location Display
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                            Text("Synced Location")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(location.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)

                            if !location.address.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "location")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text(location.address)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            if !location.locationInFilm.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "film")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.blue)
                                    Text(location.locationInFilm)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.blue)
                                }
                            }

                            if !location.contact.isEmpty || !location.phone.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)

                                if !location.contact.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        Text(location.contact)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if !location.phone.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "phone")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        Text(location.phone)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.green.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                // Sync Location button
                Button(action: { showLocationSync = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedLocationID != nil ? "arrow.triangle.2.circlepath" : "plus.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)

                        Text(selectedLocationID != nil ? "Change Location" : "Sync from Locations App")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.green.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Clear synced location button (only show if a location is synced)
                if selectedLocationID != nil {
                    Button(action: { selectedLocationID = nil }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("Clear Synced Location")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .schedulerCard()
        .sheet(isPresented: $showLocationSync) {
            locationSyncSheet
        }
    }

    // MARK: - Shoot Dates Card
    @State private var showDatePicker = false

    private var shootDatesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon box
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1)
                        )

                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                Text("Shoot Dates")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Production Start Date - Modern Button
            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 12) {
                    // Calendar icon with gradient background
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Production Start")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(formatProductionDate(productionStartDate))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.blue.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDatePicker) {
                ModernDatePickerSheet(
                    selectedDate: $productionStartDate,
                    onDateSelected: { newDate in
                        moc.perform {
                            if let project = try? moc.existingObject(with: projectID),
                               project.entity.attributesByName.keys.contains("startDate") {
                                project.setValue(newDate, forKey: "startDate")
                                scheduleCoalescedSave()
                            }
                        }
                        // Recalculate all day break dates when production start changes
                        recalculateAllDayBreakDates()
                        showDatePicker = false
                    }
                )
            }
        }
        .schedulerCard()
    }

    private func formatProductionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Cast Card
    @State private var showCast = true

    private var castCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon box
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.25), Color.purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.purple.opacity(0.4), lineWidth: 1)
                        )

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                }

                Text("Cast")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Spacer()

                let castCount = fetchCastContacts().count
                if castCount > 0 {
                    Text("\(castCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.12))
                        )
                }

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showCast.toggle() } }) {
                    Image(systemName: showCast ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: { showAddCastSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .customTooltip("Add Cast Member")
            }

            if showCast {
                let castContacts = fetchCastContacts()
                if castContacts.isEmpty {
                    VStack(spacing: 8) {
                        Text("No cast members")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 6) {
                        ForEach(castContacts, id: \.self) { contact in
                            castMemberRowCompact(contact: contact)
                        }
                    }
                }
            }
        }
        .schedulerCard()
        .sheet(isPresented: $showAddCastSheet) {
            SchedulerAddCastSheet(context: moc)
        }
    }

    private func castMemberRowCompact(contact: NSManagedObject) -> some View {
        let name = contact.value(forKey: "name") as? String ?? "Unknown"
        let role = contact.value(forKey: "role") as? String ?? ""

        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if !role.isEmpty {
                    Text(role)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.purple.opacity(0.04))
        )
    }

    // MARK: - Crew Card
    @State private var showCrewCard = true

    private var crewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon box
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                        )

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                Text("Crew")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Spacer()

                let crewCount = fetchCrewContacts().count
                let unitCount = fetchUnits().count
                let totalCount = crewCount + unitCount
                if totalCount > 0 {
                    Text("\(totalCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.12))
                        )
                }

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showCrewCard.toggle() } }) {
                    Image(systemName: showCrewCard ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Menu {
                    Button(action: { showAddCrewSheet = true }) {
                        Label("Add Crew Member", systemImage: "person.badge.plus")
                    }
                    Button(action: { showAddUnitSheet = true }) {
                        Label("Add Unit", systemImage: "person.3.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
                .customTooltip("Add Crew or Unit")
            }

            if showCrewCard {
                let units = fetchUnits()
                let crewContacts = fetchCrewContacts()

                if units.isEmpty && crewContacts.isEmpty {
                    VStack(spacing: 8) {
                        Text("No crew or units")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 10) {
                        // Units
                        if !units.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("UNITS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.leading, 4)

                                ForEach(units, id: \.self) { unit in
                                    unitRowCompact(unit: unit)
                                }
                            }
                        }

                        // Crew Members
                        if !crewContacts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("MEMBERS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.leading, 4)

                                ForEach(crewContacts, id: \.self) { contact in
                                    crewMemberRowCompact(contact: contact)
                                }
                            }
                        }
                    }
                }
            }
        }
        .schedulerCard()
        .sheet(isPresented: $showAddCrewSheet) {
            SchedulerAddCrewSheet(context: moc)
        }
        .sheet(isPresented: $showAddUnitSheet) {
            SchedulerAddUnitSheet(context: moc)
        }
    }

    private func crewMemberRowCompact(contact: NSManagedObject) -> some View {
        let name = contact.value(forKey: "name") as? String ?? "Unknown"
        let role = contact.value(forKey: "role") as? String ?? ""

        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if !role.isEmpty {
                    Text(role)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.04))
        )
    }

    private func unitRowCompact(unit: SchedulerUnitData) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 26, height: 26)
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(unit.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("\(unit.memberIDs.count) member\(unit.memberIDs.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.06))
        )
    }

    private var locationSyncSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync Location")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Select a location from the Locations app")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel") {
                        showLocationSync = false
                    }
                }
                .padding(20)

                Divider()

                // Location List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(LocationDataManager.shared.locations) { location in
                            LocationSyncRow(
                                location: location,
                                isSelected: selectedLocationID == location.id,
                                onSelect: {
                                    selectedLocationID = location.id
                                    syncLocationToScene(location)
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .frame(width: 500, height: 600)
        }
    }

    private func syncLocationToScene(_ location: LocationItem) {
        guard let firstSelected = selectedIDs.first,
              let scene = scenes.first(where: { $0.objectID == firstSelected }) else {
            return
        }

        // Sync location data to scene
        if scene.entity.attributesByName.keys.contains("scriptLocation") {
            scene.setValue(location.locationInFilm.isEmpty ? location.name : location.locationInFilm, forKey: "scriptLocation")
        }
        if scene.entity.attributesByName.keys.contains("sceneHeading") {
            let currentHeading = firstString(scene, keys: ["sceneHeading"]) ?? ""
            if currentHeading.isEmpty {
                scene.setValue(location.name, forKey: "sceneHeading")
            }
        }
        if scene.entity.attributesByName.keys.contains("address") {
            scene.setValue(location.address, forKey: "address")
        }
        if scene.entity.attributesByName.keys.contains("locationContact") {
            scene.setValue(location.contact, forKey: "locationContact")
        }
        if scene.entity.attributesByName.keys.contains("locationPhone") {
            scene.setValue(location.phone, forKey: "locationPhone")
        }

        scheduleCoalescedSave()
        showLocationSync = false
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.accentColor)
                Text("Quick Actions")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                Spacer()
            }

            VStack(spacing: 8) {
                actionButton(icon: "doc.on.doc", title: "Copy", action: copySelectedToPasteboard)
                    .disabled(selectedIDs.isEmpty)
                actionButton(icon: "scissors", title: "Cut", action: cutSelected)
                    .disabled(selectedIDs.isEmpty)
                actionButton(icon: "doc.on.clipboard", title: "Paste", action: pasteFromPasteboard)
                actionButton(icon: "square.on.square", title: "Duplicate", action: duplicateSelected)
                    .disabled(selectedIDs.isEmpty)
                actionButton(icon: "trash", title: "Delete", action: deleteSelected, isDestructive: true)
                    .disabled(selectedIDs.isEmpty)
            }
        }
        .schedulerCard()
    }
    
    private func actionButton(icon: String, title: String, action: @escaping () -> Void, isDestructive: Bool = false) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Strip Tint Colors
    private func stripTintColor(intExt: String, time: String) -> Color? {
        let ie = intExt.uppercased().replacingOccurrences(of: "[./ \\-_]", with: "", options: .regularExpression)
        let t = time.uppercased().replacingOccurrences(of: "[. ]", with: "", options: .regularExpression)

        let hasINT = ie.contains("INT")
        let hasEXT = ie.contains("EXT")
        let isEXT = hasEXT
        let isINT = hasINT && !hasEXT

        // Check for specific time periods (order matters - check specific times before DAY)
        let isMORNING = t.contains("MORNING")
        let isDAWN = t.contains("DAWN")
        let isDUSK = t.contains("DUSK")
        let isEVENING = t.contains("EVENING")
        let isDAY = t.contains("DAY") && !isMORNING // DAY but not MORNING
        let isNIGHT = t.contains("NIGHT")

        // INT/EXT + Time combinations
        if isINT {
            if isMORNING { return colorFromString(colorIntMorning) }
            if isDAWN { return colorFromString(colorIntDawn) }
            if isDUSK { return colorFromString(colorIntDusk) }
            if isEVENING { return colorFromString(colorIntEvening) }
            if isDAY { return colorFromString(colorIntDay) }
            if isNIGHT { return colorFromString(colorIntNight) }
        }
        if isEXT {
            if isMORNING { return colorFromString(colorExtMorning) }
            if isDAWN { return colorFromString(colorExtDawn) }
            if isDUSK { return colorFromString(colorExtDusk) }
            if isEVENING { return colorFromString(colorExtEvening) }
            if isDAY { return colorFromString(colorExtDay) }
            if isNIGHT { return colorFromString(colorExtNight) }
        }

        return nil
    }

    private func colorFromString(_ str: String) -> Color {
        let components = str.split(separator: ",").compactMap { Double($0) }
        guard components.count == 3 else {
            return Color(red: 0.98, green: 0.97, blue: 0.95)
        }
        return Color(red: components[0], green: components[1], blue: components[2])
    }

    private func colorToString(_ color: Color) -> String {
        #if os(macOS)
        if let nsColor = NSColor(color).usingColorSpace(.deviceRGB) {
            return "\(nsColor.redComponent),\(nsColor.greenComponent),\(nsColor.blueComponent)"
        }
        #endif
        return "1.0,1.0,1.0"
    }

    // MARK: - Selection & Context Menu
    private func handleSelect(for id: NSManagedObjectID, at index: Int) {
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []
        if modifiers.contains(.command) {
            if selectedIDs.contains(id) { selectedIDs.remove(id) }
            else { selectedIDs.insert(id) }
            anchorIndex = index
        } else if modifiers.contains(.shift), let anchor = anchorIndex {
            let lower = min(anchor, index)
            let upper = max(anchor, index)
            let rangeIDs = scenes[lower...upper].map { $0.objectID }
            selectedIDs.formUnion(rangeIDs)
        } else {
            selectedIDs = [id]
            anchorIndex = index
        }
    }

    // MARK: - Filtering
    private var filteredScenes: [NSManagedObject] {
        var items = scenes
        
        let allIntExtOn = (filterInt && filterExt)
        if !allIntExtOn {
            items = items.filter { s in
                let intExt = sceneDisplay[s.objectID]?.intExtUpper ?? (firstString(s, keys: ["locationType", "intExt"])?.uppercased() ?? "")
                let matches = (filterInt && intExt.contains("INT")) || (filterExt && intExt.contains("EXT"))
                return matches || intExt.isEmpty
            }
        }
        
        let anyTimeOn = (filterDay || filterNight || filterDawn || filterDusk)
        let allTimesOn = (filterDay && filterNight && filterDawn && filterDusk)
        if anyTimeOn && !allTimesOn {
            items = items.filter { s in
                let t = sceneDisplay[s.objectID]?.timeUpper ?? (firstString(s, keys: ["timeOfDay", "time"])?.uppercased() ?? "")
                let matches =
                    (filterDay && t.contains("DAY")) ||
                    (filterNight && t.contains("NIGHT")) ||
                    (filterDawn && t.contains("DAWN")) ||
                    (filterDusk && t.contains("DUSK"))
                return matches || t.isEmpty
            }
        }
        
        if !filterLocation.trimmingCharacters(in: .whitespaces).isEmpty {
            let needle = filterLocation.lowercased()
            items = items.filter { s in
                let loc = (sceneDisplay[s.objectID]?.shootLoc ?? firstString(s, keys: ["scriptLocation", "shootLocation", "locationName", "shootingLocation"]) ?? "").lowercased()
                return loc.contains(needle)
            }
        }
        
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            items = items.filter { s in
                let d = sceneDisplay[s.objectID]
                let hay = [
                    d?.number ?? firstString(s, keys: ["number"]) ?? "",
                    d?.heading ?? firstString(s, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "",
                    d?.timeUpper ?? firstString(s, keys: ["timeOfDay", "time"]) ?? "",
                    d?.shootLoc ?? firstString(s, keys: ["shootLocation", "locationName", "shootingLocation"]) ?? ""
                ].joined(separator: " ").lowercased()
                return hay.contains(q)
            }
        }
        
        return items
    }

    // MARK: - Production Days & Date Calculation
    private var dayBreakItems: [(title: String, date: String?, pages: String)] {
        var items: [(String, String?, String)] = []
        
        for (idx, s) in scenes.enumerated() {
            if isDayBreakRow(s) {
                let dayNum = calculateDayNumber(at: idx)
                let title = "D\(dayNum)"
                
                // Calculate date
                let calculatedDate = calculateDateForStrip(at: idx)
                let dateString = calculatedDate.map { shortDateFormatter.string(from: $0) }
                
                // Calculate page count for this day
                let pageCount = totalEighthsForDayEnding(beforeIndex: idx)
                let pagesString = formatEighths(pageCount)
                
                items.append((title, dateString, pagesString))
            }
        }
        return items
    }
    
    // Calculate the day number for a day break at the given index
    private func calculateDayNumber(at index: Int) -> Int {
        var dayCount = 0
        for i in 0...index {
            if isDayBreakRow(scenes[i]) {
                dayCount += 1
            }
        }
        return dayCount
    }
    
    // Calculate the date for a strip (day break or off day) at the given index
    private func calculateDateForStrip(at index: Int) -> Date? {
        let calendar = Calendar.current
        var currentDate = productionStartDate
        
        // Walk through all scenes up to this index
        for i in 0..<index {
            let scene = scenes[i]
            
            if isDayBreakRow(scene) {
                // This day break represents the end of a shooting day
                // Move to next calendar day
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDate
                }
            } else if isOffDayRow(scene) {
                // This is a skipped day, move forward one calendar day
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDate
                }
            }
        }
        
        // Return the current date for this strip
        return currentDate
    }
    
    // Recalculate all day break dates and numbers after rearrangement
    private func recalculateAllDayBreakDates() {
        moc.perform {
            let totalDays = scenes.filter { isDayBreakRow($0) }.count
            
            for (idx, scene) in scenes.enumerated() {
                if isDayBreakRow(scene) {
                    let dayNum = calculateDayNumber(at: idx)
                    
                    // Update the heading with correct day numbers
                    let heading = "End of Day \(dayNum) of \(totalDays)"
                    if scene.entity.attributesByName.keys.contains("sceneHeading") {
                        scene.setValue(heading, forKey: "sceneHeading")
                    } else if scene.entity.attributesByName.keys.contains("heading") {
                        scene.setValue(heading, forKey: "heading")
                    } else if scene.entity.attributesByName.keys.contains("scriptLocation") {
                        scene.setValue(heading, forKey: "scriptLocation")
                    }
                }
            }
            
            scheduleCoalescedSave()
        }
    }
    
    private var shortDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "M/d/yyyy"
        return df
    }

    // MARK: - Save Management
    private func scheduleReload(delay: TimeInterval = 0.15) {
        pendingReload?.cancel()
        let work = DispatchWorkItem { self.reload() }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func scheduleCoalescedSave(delay: TimeInterval = 0.2) {
        if isSaving {
            pendingSaveWork?.cancel()
            let work = DispatchWorkItem { self.scheduleCoalescedSave(delay: 0.1) }
            pendingSaveWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
            return
        }

        DispatchQueue.main.async { self.suppressReloads = true }

        pendingSaveWork?.cancel()
        let work = DispatchWorkItem {
            self.isSaving = true
            moc.perform {
                if moc.hasChanges {
                    do {
                        try moc.save()
                        // Refresh scenes to update UI in real-time
                        DispatchQueue.main.async {
                            self.reload()
                        }
                    } catch {
                        NSLog("❌ Scheduler save error: \(error.localizedDescription)")
                        if let detailedError = error as NSError? {
                            NSLog("❌ Error details: \(detailedError.userInfo)")
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.suppressReloads = false
                }
            }
        }
        pendingSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Data Loading
    private func reload() {
        moc.perform {
            moc.refreshAllObjects()
            
            if let project = try? moc.existingObject(with: projectID),
               project.entity.attributesByName.keys.contains("startDate"),
               let sd = project.value(forKey: "startDate") as? Date {
                DispatchQueue.main.async {
                    self.productionStartDate = sd
                }
            }

            let entityNames = sceneEntityCandidates()
            guard !entityNames.isEmpty else {
                DispatchQueue.main.async { self.scenes = [] }
                return
            }

            var fetched: [NSManagedObject] = []
            for name in entityNames {
                fetched.append(contentsOf: fetchScenes(entityName: name))
            }

            var seen: Set<NSManagedObjectID> = []
            fetched = fetched.filter { obj in
                if seen.contains(obj.objectID) { return false }
                seen.insert(obj.objectID)
                return true
            }

            let sorted = fetched.sorted { a, b in
                func orderVal(_ obj: NSManagedObject) -> Int {
                    let attrs = obj.entity.attributesByName
                    // Check scheduleOrder first (Scheduler-specific ordering)
                    if attrs.keys.contains("scheduleOrder"),
                       let n = obj.value(forKey: "scheduleOrder") as? NSNumber,
                       n.intValue > 0 {
                        return n.intValue
                    }
                    // Fall back to displayOrder to match StripStore/Breakdowns
                    if attrs.keys.contains("displayOrder"),
                       let n = obj.value(forKey: "displayOrder") as? NSNumber {
                        return n.intValue
                    }
                    return Int.max
                }

                func createdAtVal(_ obj: NSManagedObject) -> Date {
                    if obj.entity.attributesByName.keys.contains("createdAt"),
                       let d = obj.value(forKey: "createdAt") as? Date {
                        return d
                    }
                    return Date.distantPast
                }

                let ai = orderVal(a)
                let bi = orderVal(b)
                if ai != bi { return ai < bi }
                // Match StripStore: use createdAt as secondary sort instead of number
                let aDate = createdAtVal(a)
                let bDate = createdAtVal(b)
                return aDate < bDate
            }

            var newDisplay: [NSManagedObjectID: SceneDisplay] = [:]
            for s in sorted {
                let num = firstString(s, keys: ["number"]) ?? "—"
                let intExt = firstString(s, keys: ["locationType", "intExt"]) ?? ""
                let heading = firstString(s, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "—"
                let time = firstString(s, keys: ["timeOfDay", "time"]) ?? ""
                let pgLen = pageLengthString(s)
                let shootLoc = firstString(s, keys: ["shootLocation", "shootingLocation", "locationName"]) ?? "—"
                let tint = stripTintColor(intExt: intExt, time: time)
                newDisplay[s.objectID] = SceneDisplay(
                    number: num,
                    intExtUpper: intExt.uppercased(),
                    heading: heading,
                    timeUpper: time.uppercased(),
                    pageLen: pgLen,
                    shootLoc: shootLoc,
                    tint: tint
                )
            }

            DispatchQueue.main.async {
                self.sceneDisplay = newDisplay
                self.scenes = sorted
            }
        }
    }

    private func sceneEntityCandidates() -> [String] {
        guard let model = moc.persistentStoreCoordinator?.managedObjectModel else { return [] }
        let candidates = ["SceneEntity", "StripEntity", "Scene", "SceneRecord"]
        return candidates.filter { model.entitiesByName.keys.contains($0) }
    }

    private func fetchScenes(entityName: String) -> [NSManagedObject] {
        let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
        req.includesPendingChanges = true
        req.includesSubentities = true
        req.fetchBatchSize = 400
        req.returnsObjectsAsFaults = false
        req.relationshipKeyPathsForPrefetching = ["project"]

        // Use StripStore-compatible sort descriptors: displayOrder then createdAt
        if let model = moc.persistentStoreCoordinator?.managedObjectModel,
           let entity = model.entitiesByName[entityName] {
            let attrs = Set(entity.attributesByName.keys)
            if attrs.contains("displayOrder") {
                if attrs.contains("createdAt") {
                    req.sortDescriptors = [
                        NSSortDescriptor(key: "displayOrder", ascending: true),
                        NSSortDescriptor(key: "createdAt", ascending: true)
                    ]
                } else {
                    req.sortDescriptors = [
                        NSSortDescriptor(key: "displayOrder", ascending: true)
                    ]
                }
            } else {
                req.sortDescriptors = []
            }
        } else {
            req.sortDescriptors = []
        }
        return (try? moc.fetch(req)) ?? []
    }

    private func preferredSceneEntityName() -> String? {
        guard let model = moc.persistentStoreCoordinator?.managedObjectModel else { return nil }
        for name in ["SceneEntity", "StripEntity", "Scene", "SceneRecord"] {
            if model.entitiesByName.keys.contains(name) { return name }
        }
        return nil
    }

    // MARK: - Actions
    private func copySelectedToPasteboard() {
        let rows = scenes.filter { selectedIDs.contains($0.objectID) }
        let lines: [String] = rows.map { s in
            let num = firstString(s, keys: ["number"]) ?? "—"
            let intExt = firstString(s, keys: ["locationType", "intExt"]) ?? ""
            let heading = firstString(s, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "—"
            let time = firstString(s, keys: ["timeOfDay", "time"]) ?? ""
            let pgLength = pageLengthString(s)
            let shootLoc = firstString(s, keys: ["shootLocation", "shootingLocation", "locationName"]) ?? ""
            return "\(num)\t\(intExt)\t\(heading)\t\(time)\t\(pgLength)\t\(shootLoc)"
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func cutSelected() {
        copySelectedToPasteboard()
        deleteSelected()
    }

    private func cycleDensity() {
        let allCases = Density.allCases
        if let currentIndex = allCases.firstIndex(of: density) {
            let nextIndex = (currentIndex + 1) % allCases.count
            density = allCases[nextIndex]
        }
    }

    // MARK: - Schedule Version Management

    private func selectVersion(_ version: ScheduleVersion) {
        selectedVersion = version
        productionStartDate = version.productionStartDate
        // Note: scene order restoration would happen here when implementing full version switching
        saveVersions()
    }

    private func createNewVersion(name: String) {
        let sceneUUIDs = scenes.compactMap { scene -> UUID? in
            guard let id = scene.value(forKey: "id") as? UUID else { return nil }
            return id
        }

        let newVersion = ScheduleVersion(
            name: name,
            sceneOrder: sceneUUIDs,
            productionStartDate: productionStartDate
        )

        scheduleVersions.append(newVersion)
        selectVersion(newVersion)
    }

    private func renameVersion(_ version: ScheduleVersion, to newName: String) {
        if let index = scheduleVersions.firstIndex(where: { $0.id == version.id }) {
            scheduleVersions[index].name = newName
            if selectedVersion?.id == version.id {
                selectedVersion?.name = newName
            }
            saveVersions()
        }
    }

    private func deleteVersion(_ version: ScheduleVersion) {
        scheduleVersions.removeAll { $0.id == version.id }

        // If we deleted the selected version, select another
        if selectedVersion?.id == version.id {
            if let first = scheduleVersions.first {
                selectVersion(first)
            } else {
                // Create a new default version if all were deleted
                let defaultVersion = ScheduleVersion(name: "Schedule v1.0")
                scheduleVersions = [defaultVersion]
                selectVersion(defaultVersion)
            }
        }

        saveVersions()
    }

    private func duplicateVersion(_ version: ScheduleVersion) {
        let newVersion = version.duplicate()
        scheduleVersions.append(newVersion)
        selectVersion(newVersion)
    }

    private func saveVersions() {
        guard let project = try? moc.existingObject(with: projectID) else { return }

        if let encoded = try? JSONEncoder().encode(scheduleVersions) {
            project.setValue(encoded, forKey: "scheduleVersionsData")
        }
        if let selectedEncoded = try? JSONEncoder().encode(selectedVersion) {
            project.setValue(selectedEncoded, forKey: "selectedScheduleVersionData")
        }

        do {
            try moc.save()
        } catch {
            NSLog("❌ Failed to save schedule versions: \(error)")
        }
    }

    private func loadVersions() {
        guard let project = try? moc.existingObject(with: projectID) else { return }

        // Load versions
        if let data = project.value(forKey: "scheduleVersionsData") as? Data,
           let decoded = try? JSONDecoder().decode([ScheduleVersion].self, from: data) {
            scheduleVersions = decoded
        }

        // Load selected version
        if let selectedData = project.value(forKey: "selectedScheduleVersionData") as? Data,
           let decoded = try? JSONDecoder().decode(ScheduleVersion.self, from: selectedData) {
            selectedVersion = decoded
            productionStartDate = decoded.productionStartDate
        }

        // Create default version if none exist
        if scheduleVersions.isEmpty {
            let defaultVersion = ScheduleVersion(name: "Schedule v1.0")
            scheduleVersions = [defaultVersion]
            selectVersion(defaultVersion)
        } else if selectedVersion == nil {
            selectVersion(scheduleVersions[0])
        }
    }

    // MARK: - Undo/Redo Functions
    private func saveToUndoStack() {
        let state = scenes.map { scene -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["objectID"] = scene.objectID.uriRepresentation().absoluteString
            for attr in scene.entity.attributesByName.keys {
                if let value = scene.value(forKey: attr) {
                    dict[attr] = value
                }
            }
            return dict
        }
        undoRedoManager.saveState(state)
    }

    private func getCurrentState() -> [[String: Any]] {
        return scenes.map { scene -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["objectID"] = scene.objectID.uriRepresentation().absoluteString
            for attr in scene.entity.attributesByName.keys {
                if let value = scene.value(forKey: attr) {
                    dict[attr] = value
                }
            }
            return dict
        }
    }

    private func performUndo() {
        guard let previousState = undoRedoManager.undo(currentState: getCurrentState()) else { return }
        restoreState(previousState)
    }

    private func performRedo() {
        guard let nextState = undoRedoManager.redo(currentState: getCurrentState()) else { return }
        restoreState(nextState)
    }

    private func restoreState(_ state: [[String: Any]]) {
        suppressReloads = true

        // Restore scene order and attributes from state
        moc.performAndWait {
            // First, find the URIs in the state
            _ = state.compactMap { $0["objectID"] as? String }

            // Match scenes to state by their stored URI
            var newSceneOrder: [NSManagedObject] = []
            for stateItem in state {
                guard let uriString = stateItem["objectID"] as? String,
                      let uri = URL(string: uriString),
                      let objectID = moc.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri),
                      let scene = try? moc.existingObject(with: objectID) else {
                    continue
                }

                // Restore attributes
                for (key, value) in stateItem where key != "objectID" {
                    if scene.entity.attributesByName.keys.contains(key) {
                        scene.setValue(value, forKey: key)
                    }
                }
                newSceneOrder.append(scene)
            }

            // Update order
            scenes = newSceneOrder
            persistOrder()

            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler undo/redo error: \(error.localizedDescription)")
            }
        }

        selectedIDs.removeAll()
        suppressReloads = false
        scheduleReload(delay: 0.05)
    }

    // MARK: - Edit Operations
    private func selectAll() {
        selectedIDs = Set(scenes.map { $0.objectID })
    }

    private func handleCut() {
        guard !selectedIDs.isEmpty else { return }
        handleCopy()
        deleteSelected()
    }

    private func handleCopy() {
        guard !selectedIDs.isEmpty else { return }
        let selectedScenes = scenes.filter { selectedIDs.contains($0.objectID) }
        var copyText = ""
        for scene in selectedScenes {
            let number = (scene.value(forKey: "number") as? String) ?? ""
            let heading = (scene.value(forKey: "sceneHeading") as? String) ?? (scene.value(forKey: "heading") as? String) ?? ""
            copyText += "\(number)\t\t\(heading)\n"
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(copyText, forType: .string)
    }

    private func deleteSelected() {
        guard !selectedIDs.isEmpty else { return }
        saveToUndoStack()
        moc.perform {
            let doomed = self.scenes.filter { self.selectedIDs.contains($0.objectID) }
            doomed.forEach { self.moc.delete($0) }
            do {
                try self.moc.save()
            } catch {
                NSLog("❌ Scheduler delete error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            DispatchQueue.main.async {
                self.selectedIDs.removeAll()
                self.reload()
            }
        }
    }

    private func pasteFromPasteboard() {
        guard let raw = NSPasteboard.general.string(forType: .string),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let lines = raw.split(whereSeparator: \.isNewline).map { String($0) }
        guard !lines.isEmpty,
              let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        saveToUndoStack()

        let insertAfterIndex = scenes.firstIndex { selectedIDs.contains($0.objectID) }
        var insertAt = insertAfterIndex.map { min($0 + 1, scenes.count) } ?? scenes.count
        var newObjects: [NSManagedObject] = []

        moc.performAndWait {
            for line in lines {
                let cols = line.components(separatedBy: "\t")
                let obj = NSManagedObject(entity: entity, insertInto: moc)
                
                if obj.entity.attributesByName.keys.contains("id") {
                    obj.setValue(UUID(), forKey: "id")
                }
                if cols.indices.contains(0), obj.entity.attributesByName.keys.contains("number") {
                    obj.setValue(cols[0], forKey: "number")
                }
                if cols.indices.contains(2) {
                    if obj.entity.attributesByName.keys.contains("sceneHeading") {
                        obj.setValue(cols[2], forKey: "sceneHeading")
                    } else if obj.entity.attributesByName.keys.contains("heading") {
                        obj.setValue(cols[2], forKey: "heading")
                    }
                }
                
                newObjects.append(obj)
                scenes.insert(obj, at: min(insertAt, scenes.count))
                insertAt += 1
            }
            
            persistOrder()
            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler paste error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
        }

        selectedIDs = Set(newObjects.map { $0.objectID })
        scheduleReload(delay: 0.05)
    }

    private func persistOrder() {
        for (i, s) in scenes.enumerated() {
            let idx = i + 1
            // Use scheduleOrder for Scheduler ordering (separate from script order)
            if s.entity.attributesByName.keys.contains("scheduleOrder") {
                s.setValue(idx, forKey: "scheduleOrder")
            }
            // Note: We no longer modify sortIndex or displayOrder here
            // Those are for script order used by Shot List and Breakdowns
        }
    }

    private func addStrip() {
        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }
        
        moc.perform {
            let obj = NSManagedObject(entity: entity, insertInto: moc)
            if obj.entity.attributesByName.keys.contains("number") {
                obj.setValue("", forKey: "number")
            }
            if obj.entity.attributesByName.keys.contains("locationType") {
                obj.setValue("INT.", forKey: "locationType")
            }
            if obj.entity.attributesByName.keys.contains("timeOfDay") {
                obj.setValue("DAY", forKey: "timeOfDay")
            }
            if obj.entity.attributesByName.keys.contains("sceneHeading") {
                obj.setValue("New Scene", forKey: "sceneHeading")
            }
            if obj.entity.attributesByName.keys.contains("pageEighths") {
                obj.setValue(4, forKey: "pageEighths")
            }
            
            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler add strip error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            reload()
        }
    }

    // MARK: - Sort Stripboard

    private func sortStripboard(by option: StripboardSortOption, direction: SortDirection) {
        // Save undo state first
        saveToUndoStack()

        // Sort scenes using StripboardSorter
        let sortedScenes = StripboardSorter.sort(
            scenes: scenes,
            by: option,
            direction: direction,
            isDayBreak: { isDayBreakRow($0) },
            isOffDay: { isOffDayRow($0) }
        )

        // Update scheduleOrder for each scene
        moc.performAndWait {
            for (index, scene) in sortedScenes.enumerated() {
                if scene.entity.attributesByName.keys.contains("scheduleOrder") {
                    scene.setValue(Int32(index + 1), forKey: "scheduleOrder")
                }
            }

            do {
                try moc.save()
            } catch {
                NSLog("❌ Failed to save sorted stripboard: \(error.localizedDescription)")
            }
        }

        // Update local scenes array and reload
        scenes = sortedScenes
        reload()

        // Recalculate day break dates
        recalculateAllDayBreakDates()
    }

    private func addDayBreak() {
        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        let insertAfterIndex: Int? = {
            if let firstSelected = selectedIDs.first,
               let idx = scenes.firstIndex(where: { $0.objectID == firstSelected }) {
                return idx
            }
            return nil
        }()

        moc.performAndWait {
            let obj = NSManagedObject(entity: entity, insertInto: moc)
            
            if obj.entity.attributesByName.keys.contains("id") {
                obj.setValue(UUID(), forKey: "id")
            }
            if obj.entity.attributesByName.keys.contains("number") {
                obj.setValue("—", forKey: "number")
            }
            
            if let afterIdx = insertAfterIndex {
                scenes.insert(obj, at: afterIdx + 1)
            } else {
                scenes.append(obj)
            }
            
            let totalDays = scenes.filter { isDayBreakRow($0) }.count
            let dayNumber = calculateDayNumber(at: scenes.firstIndex(where: { $0.objectID == obj.objectID })!)
            
            let heading = "End of Day \(dayNumber) of \(totalDays)"
            if obj.entity.attributesByName.keys.contains("sceneHeading") {
                obj.setValue(heading, forKey: "sceneHeading")
            } else if obj.entity.attributesByName.keys.contains("heading") {
                obj.setValue(heading, forKey: "heading")
            } else if obj.entity.attributesByName.keys.contains("scriptLocation") {
                obj.setValue(heading, forKey: "scriptLocation")
            }
            
            if obj.entity.attributesByName.keys.contains("pageEighths") {
                obj.setValue(0, forKey: "pageEighths")
            }
            if obj.entity.attributesByName.keys.contains("isDivider") {
                obj.setValue(true, forKey: "isDivider")
            }
            if obj.entity.attributesByName.keys.contains("locationType") {
                obj.setValue("", forKey: "locationType")
            }
            if obj.entity.attributesByName.keys.contains("timeOfDay") {
                obj.setValue("", forKey: "timeOfDay")
            }
            
            recalculateAllDayBreakDates()
            persistOrder()

            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler add day break error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            selectedIDs = [obj.objectID]
        }
        
        scheduleReload(delay: 0.05)
    }

    private func addOffDay() {
        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        let insertAfterIndex: Int? = {
            if let firstSelected = selectedIDs.first,
               let idx = scenes.firstIndex(where: { $0.objectID == firstSelected }) {
                return idx
            }
            return nil
        }()

        moc.performAndWait {
            let obj = NSManagedObject(entity: entity, insertInto: moc)

            if obj.entity.attributesByName.keys.contains("id") {
                obj.setValue(UUID(), forKey: "id")
            }
            if obj.entity.attributesByName.keys.contains("number") {
                obj.setValue("—", forKey: "number")
            }
            if obj.entity.attributesByName.keys.contains("sceneHeading") {
                obj.setValue("OFF DAY", forKey: "sceneHeading")
            } else if obj.entity.attributesByName.keys.contains("heading") {
                obj.setValue("OFF DAY", forKey: "heading")
            } else if obj.entity.attributesByName.keys.contains("scriptLocation") {
                obj.setValue("OFF DAY", forKey: "scriptLocation")
            }

            if obj.entity.attributesByName.keys.contains("pageEighths") {
                obj.setValue(0, forKey: "pageEighths")
            }
            if obj.entity.attributesByName.keys.contains("isDivider") {
                obj.setValue(true, forKey: "isDivider")
            }
            if obj.entity.attributesByName.keys.contains("locationType") {
                obj.setValue("", forKey: "locationType")
            }
            if obj.entity.attributesByName.keys.contains("timeOfDay") {
                obj.setValue("", forKey: "timeOfDay")
            }

            if let afterIdx = insertAfterIndex {
                scenes.insert(obj, at: afterIdx + 1)
            } else {
                scenes.append(obj)
            }

            persistOrder()

            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler add off day error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            selectedIDs = [obj.objectID]
        }

        scheduleReload(delay: 0.05)
    }

    private func addBanner() {
        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        let insertAfterIndex: Int? = {
            if let firstSelected = selectedIDs.first,
               let idx = scenes.firstIndex(where: { $0.objectID == firstSelected }) {
                return idx
            }
            return nil
        }()

        moc.performAndWait {
            let obj = NSManagedObject(entity: entity, insertInto: moc)

            if obj.entity.attributesByName.keys.contains("id") {
                obj.setValue(UUID(), forKey: "id")
            }
            if obj.entity.attributesByName.keys.contains("number") {
                obj.setValue("", forKey: "number")
            }
            if obj.entity.attributesByName.keys.contains("sceneHeading") {
                obj.setValue("", forKey: "sceneHeading")
            } else if obj.entity.attributesByName.keys.contains("heading") {
                obj.setValue("", forKey: "heading")
            } else if obj.entity.attributesByName.keys.contains("scriptLocation") {
                obj.setValue("", forKey: "scriptLocation")
            }
            if obj.entity.attributesByName.keys.contains("descriptionText") {
                obj.setValue("", forKey: "descriptionText")
            }
            if obj.entity.attributesByName.keys.contains("scriptText") {
                obj.setValue("", forKey: "scriptText")
            }

            if obj.entity.attributesByName.keys.contains("pageEighths") {
                obj.setValue(0, forKey: "pageEighths")
            }
            if obj.entity.attributesByName.keys.contains("isDivider") {
                obj.setValue(true, forKey: "isDivider")
            }
            if obj.entity.attributesByName.keys.contains("locationType") {
                obj.setValue("", forKey: "locationType")
            }
            if obj.entity.attributesByName.keys.contains("timeOfDay") {
                obj.setValue("", forKey: "timeOfDay")
            }

            if let afterIdx = insertAfterIndex {
                scenes.insert(obj, at: afterIdx + 1)
            } else {
                scenes.append(obj)
            }

            persistOrder()

            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler add banner error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            selectedIDs = [obj.objectID]
        }

        scheduleReload(delay: 0.05)
    }

    private func addCallTimeBanner() {
        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        let insertAfterIndex: Int? = {
            if let firstSelected = selectedIDs.first,
               let idx = scenes.firstIndex(where: { $0.objectID == firstSelected }) {
                return idx
            }
            return nil
        }()

        // Default call time: 7:00 AM
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        let defaultTime = Calendar.current.date(from: components) ?? Date()
        let timeString = formatter.string(from: defaultTime)

        moc.performAndWait {
            let obj = NSManagedObject(entity: entity, insertInto: moc)

            if obj.entity.attributesByName.keys.contains("id") {
                obj.setValue(UUID(), forKey: "id")
            }
            if obj.entity.attributesByName.keys.contains("number") {
                obj.setValue("", forKey: "number")
            }
            if obj.entity.attributesByName.keys.contains("sceneHeading") {
                obj.setValue("CALL TIME: \(timeString)", forKey: "sceneHeading")
            } else if obj.entity.attributesByName.keys.contains("heading") {
                obj.setValue("CALL TIME: \(timeString)", forKey: "heading")
            } else if obj.entity.attributesByName.keys.contains("scriptLocation") {
                obj.setValue("CALL TIME: \(timeString)", forKey: "scriptLocation")
            }

            if obj.entity.attributesByName.keys.contains("pageEighths") {
                obj.setValue(0, forKey: "pageEighths")
            }
            if obj.entity.attributesByName.keys.contains("isDivider") {
                obj.setValue(true, forKey: "isDivider")
            }
            if obj.entity.attributesByName.keys.contains("locationType") {
                obj.setValue("", forKey: "locationType")
            }
            if obj.entity.attributesByName.keys.contains("timeOfDay") {
                obj.setValue("", forKey: "timeOfDay")
            }

            if let afterIdx = insertAfterIndex {
                scenes.insert(obj, at: afterIdx + 1)
            } else {
                scenes.append(obj)
            }

            persistOrder()

            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler add call time banner error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            selectedIDs = [obj.objectID]
        }

        scheduleReload(delay: 0.05)
    }

    private func addMealsBanner() {
        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        let insertAfterIndex: Int? = {
            if let firstSelected = selectedIDs.first,
               let idx = scenes.firstIndex(where: { $0.objectID == firstSelected }) {
                return idx
            }
            return nil
        }()

        // Default lunch time: 6 hours after call time (1:00 PM assuming 7:00 AM call)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 13
        components.minute = 0
        let defaultTime = Calendar.current.date(from: components) ?? Date()
        let timeString = formatter.string(from: defaultTime)

        moc.performAndWait {
            let obj = NSManagedObject(entity: entity, insertInto: moc)

            if obj.entity.attributesByName.keys.contains("id") {
                obj.setValue(UUID(), forKey: "id")
            }
            if obj.entity.attributesByName.keys.contains("number") {
                obj.setValue("", forKey: "number")
            }
            if obj.entity.attributesByName.keys.contains("sceneHeading") {
                obj.setValue("LUNCH: \(timeString)", forKey: "sceneHeading")
            } else if obj.entity.attributesByName.keys.contains("heading") {
                obj.setValue("LUNCH: \(timeString)", forKey: "heading")
            } else if obj.entity.attributesByName.keys.contains("scriptLocation") {
                obj.setValue("LUNCH: \(timeString)", forKey: "scriptLocation")
            }

            if obj.entity.attributesByName.keys.contains("pageEighths") {
                obj.setValue(0, forKey: "pageEighths")
            }
            if obj.entity.attributesByName.keys.contains("isDivider") {
                obj.setValue(true, forKey: "isDivider")
            }
            if obj.entity.attributesByName.keys.contains("locationType") {
                obj.setValue("", forKey: "locationType")
            }
            if obj.entity.attributesByName.keys.contains("timeOfDay") {
                obj.setValue("", forKey: "timeOfDay")
            }

            if let afterIdx = insertAfterIndex {
                scenes.insert(obj, at: afterIdx + 1)
            } else {
                scenes.append(obj)
            }

            persistOrder()

            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler add meals banner error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            selectedIDs = [obj.objectID]
        }

        scheduleReload(delay: 0.05)
    }

    private func duplicateSelected() {
        guard !selectedIDs.isEmpty else { return }
        moc.perform {
            for id in selectedIDs {
                guard let src = scenes.first(where: { $0.objectID == id }) else { continue }
                let copy = NSManagedObject(entity: src.entity, insertInto: moc)
                for (k, prop) in src.entity.propertiesByName {
                    if let _ = prop as? NSAttributeDescription, k != "objectID" {
                        copy.setValue(src.value(forKey: k), forKey: k)
                    }
                }
            }
            do {
                try moc.save()
            } catch {
                NSLog("❌ Scheduler duplicate error: \(error.localizedDescription)")
                if let detailedError = error as NSError? {
                    NSLog("❌ Error details: \(detailedError.userInfo)")
                }
            }
            reload()
        }
    }

    private func exportPDF() {
        print("🔵 exportPDF() called")
        #if os(macOS)
        // Get project name
        var projectName = "Production"
        if let project = try? moc.existingObject(with: projectID) as? ProjectEntity {
            projectName = project.name ?? "Production"
        }

        // Generate stripboard PDF
        guard let pdfDocument = StripboardPDF.generatePDF(
            from: scenes,
            productionName: projectName,
            productionStartDate: productionStartDate
        ) else {
            print("❌ Failed to generate stripboard PDF")
            return
        }

        // Show preview
        previewPDF = pdfDocument
        previewTitle = "Stripboard Preview"
        previewFilename = "\(projectName) - Stripboard.pdf"
        showPDFPreview = true
        print("✅ Showing stripboard preview")
        #endif
    }

    private func printSchedule() {
        print("🖨️ printSchedule() called")
        #if os(macOS)
        // Get project name
        var projectName = "Production"
        if let project = try? moc.existingObject(with: projectID) as? ProjectEntity {
            projectName = project.name ?? "Production"
        }

        // Generate stripboard PDF
        guard let pdfDocument = StripboardPDF.generatePDF(
            from: scenes,
            productionName: projectName,
            productionStartDate: productionStartDate
        ) else {
            print("❌ Failed to generate stripboard PDF for printing")
            return
        }

        // Show preview (user can print from there)
        previewPDF = pdfDocument
        previewTitle = "Stripboard Preview"
        previewFilename = "\(projectName) - Stripboard.pdf"
        showPDFPreview = true
        print("✅ Showing stripboard preview for printing")
        #endif
    }

    private func regenerateStripboardPDF(with orientation: PDFPreviewSheet.Orientation) -> PDFDocument? {
        #if os(macOS)
        print("🔄 Regenerating stripboard PDF with orientation: \(orientation)")

        // Get project name
        var projectName = "Production"
        if let project = try? moc.existingObject(with: projectID) as? ProjectEntity {
            projectName = project.name ?? "Production"
        }

        // Convert PDFPreviewSheet.Orientation to StripboardPDF.Orientation
        let stripboardOrientation: StripboardPDF.Orientation = orientation == .landscape ? .landscape : .portrait

        // Generate stripboard PDF with specified orientation
        guard let pdfDocument = StripboardPDF.generatePDF(
            from: scenes,
            productionName: projectName,
            productionStartDate: productionStartDate,
            orientation: stripboardOrientation
        ) else {
            print("❌ Failed to regenerate stripboard PDF")
            return nil
        }

        print("✅ Stripboard PDF regenerated")
        return pdfDocument
        #else
        return nil
        #endif
    }

    private func exportCSV() { NSLog("Export CSV") }
    private func openReports() { NSLog("Open Reports") }
    private func pregenCallSheet() { NSLog("Call Sheet") }

    @discardableResult
    private func handleDrop(urls: [URL], before destinationID: NSManagedObjectID?) -> Bool {
        guard let first = urls.first,
              let fromID = moc.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: first),
              let fromIndex = scenes.firstIndex(where: { $0.objectID == fromID }) else {
            dragOverID = nil
            return false
        }

        let absoluteDest: Int
        if let destinationID,
           let idx = scenes.firstIndex(where: { $0.objectID == destinationID }) {
            absoluteDest = idx
        } else {
            absoluteDest = scenes.count
        }

        let insertAt: Int = (fromIndex < absoluteDest) ? max(0, absoluteDest - 1) : absoluteDest

        let moving = scenes.remove(at: fromIndex)
        scenes.insert(moving, at: min(max(0, insertAt), scenes.count))
        persistOrder()
        recalculateAllDayBreakDates()
        scheduleCoalescedSave()
        dragOverID = nil
        return true
    }

    private var totalMetricLabel: String {
        let total = filteredScenes.reduce(0) { acc, s in
            if let n = (s.value(forKey: "pageEighths") as? NSNumber)?.intValue {
                return acc + max(0, n)
            }
            return acc
        }
        return formatEighths(total)
    }

    private func formatEighths(_ v: Int) -> String {
        guard v > 0 else { return "0" }
        let whole = v / 8
        let rem = v % 8
        if whole == 0 { return "\(rem)/8" }
        if rem == 0 { return "\(whole)" }
        return "\(whole) \(rem)/8"
    }

    private func firstString(_ scene: NSManagedObject, keys: [String]) -> String? {
        // First check the scene entity itself
        for k in keys {
            if scene.entity.attributesByName.keys.contains(k),
               let s = scene.value(forKey: k) as? String {
                let t = s.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { return t }
            }
        }

        // Then check the related BreakdownEntity for element data (only for SceneEntity)
        if scene.entity.relationshipsByName.keys.contains("breakdown"),
           let breakdown = scene.value(forKey: "breakdown") as? NSManagedObject {
            for k in keys {
                if breakdown.entity.attributesByName.keys.contains(k),
                   let s = breakdown.value(forKey: k) as? String {
                    let t = s.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { return t }
                }
            }
        }

        return nil
    }

    private func pageLengthString(_ scene: NSManagedObject) -> String {
        if scene.entity.attributesByName.keys.contains("pageEighths"),
           let n = scene.value(forKey: "pageEighths") as? NSNumber {
            return formatEighths(n.intValue)
        }
        return "—"
    }

    private func isDayBreakRow(_ obj: NSManagedObject) -> Bool {
        let heading = (firstString(obj, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "").uppercased()
        return heading.contains("END OF DAY") || heading.contains("DAY BREAK")
    }
    
    private func isOffDayRow(_ obj: NSManagedObject) -> Bool {
        let heading = (firstString(obj, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "").uppercased()
        return heading.contains("OFF DAY")
    }

    private func totalEighthsForDayEnding(beforeIndex idxInAll: Int) -> Int {
        var j = idxInAll - 1
        var total = 0

        while j >= 0 {
            let obj = scenes[j]
            if isDayBreakRow(obj) || isOffDayRow(obj) {
                break
            }
            if let n = (obj.value(forKey: "pageEighths") as? NSNumber)?.intValue {
                total += n
            }
            j -= 1
        }

        return total
    }

    // MARK: - Day Out of Days View

    @State private var doodHoveredCell: (cast: String, day: Date)? = nil
    @State private var doodSelectedCast: String? = nil
    @State private var showDOODLegend: Bool = true

    private var dayOutOfDaysView: some View {
        VStack(spacing: 0) {
            // DOOD Header/Toolbar
            doodToolbar

            Divider()

            // Main DOOD Grid
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(spacing: 0) {
                    // Header Row: Corner + Date Headers + Summary Header
                    HStack(spacing: 0) {
                        // Corner cell (Cast Member header)
                        doodCornerCell

                        // Date header cells
                        ForEach(Array(doodShootDays.enumerated()), id: \.offset) { index, day in
                            doodDateHeaderCell(day: day, index: index + 1)
                        }

                        // Summary header
                        doodSummaryHeaderCell
                    }

                    // Data Rows: Cast Name + Status Cells + Summary
                    ForEach(Array(doodCastMembers.enumerated()), id: \.offset) { rowIndex, castMember in
                        HStack(spacing: 0) {
                            // Cast member name cell (left)
                            doodCastNameCell(castMember: castMember, index: rowIndex + 1)

                            // Status cells for each day
                            ForEach(Array(doodShootDays.enumerated()), id: \.offset) { dayIndex, day in
                                doodStatusCell(
                                    castMember: castMember,
                                    day: day,
                                    dayIndex: dayIndex,
                                    rowIndex: rowIndex
                                )
                            }

                            // Summary cell (right)
                            doodSummaryCellForCast(castMember: castMember, rowIndex: rowIndex)
                        }
                    }

                    // Footer Row: Totals per day
                    doodFooterRow
                }
            }

            // Legend (collapsible)
            if showDOODLegend {
                doodLegend
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - DOOD Grid Components

    private let doodCellWidth: CGFloat = 100
    private let doodCellHeight: CGFloat = 72
    private let doodCastColumnWidth: CGFloat = 480
    private let doodSummaryColumnWidth: CGFloat = 200
    private let doodHeaderHeight: CGFloat = 120

    private var doodCornerCell: some View {
        VStack(spacing: 8) {
            Text("CAST")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.secondary)
            Text("MEMBER")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(width: doodCastColumnWidth, height: doodHeaderHeight)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    private func doodDateHeaderCell(day: DOODShootDay, index: Int) -> some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E"
        let dayName = dateFormatter.string(from: day.date).prefix(2).uppercased()
        dateFormatter.dateFormat = "M/d"
        let dateString = dateFormatter.string(from: day.date)

        return VStack(spacing: 4) {
            Text("\(index)")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(.blue)
            Text(dayName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
            Text(dateString)
                .font(.system(size: 20, weight: .medium))
        }
        .frame(width: doodCellWidth, height: doodHeaderHeight)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    private var doodSummaryHeaderCell: some View {
        VStack(spacing: 8) {
            Text("TOTAL")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.secondary)
            Text("DAYS")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: doodSummaryColumnWidth, height: doodHeaderHeight)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    private func doodCastNameCell(castMember: DOODCastMember, index: Int) -> some View {
        HStack(spacing: 16) {
            // Cast number badge
            Text("\(index)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 52, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange)
                )

            // Cast name
            Text(castMember.name)
                .font(.system(size: 26, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(width: doodCastColumnWidth, height: doodCellHeight)
        .background(index % 2 == 0 ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func doodStatusCell(castMember: DOODCastMember, day: DOODShootDay, dayIndex: Int, rowIndex: Int) -> some View {
        let status = doodStatusFor(cast: castMember.id, on: day.date, dayIndex: dayIndex)

        return ZStack {
            // Background
            Rectangle()
                .fill(rowIndex % 2 == 0 ? Color(NSColor.controlBackgroundColor).opacity(0.3) : Color.clear)

            // Status indicator
            if status != .none {
                RoundedRectangle(cornerRadius: 8)
                    .fill(status.color)
                    .padding(8)
                    .overlay(
                        Text(status.rawValue)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(status.textColor)
                    )
            }
        }
        .frame(width: doodCellWidth, height: doodCellHeight)
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func doodSummaryCellForCast(castMember: DOODCastMember, rowIndex: Int) -> some View {
        let stats = doodStatsFor(cast: castMember.id)

        return HStack(spacing: 4) {
            Text("\(stats.total)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(stats.total > 0 ? .primary : Color.secondary.opacity(0.4))
        }
        .frame(width: doodSummaryColumnWidth, height: doodCellHeight)
        .background(rowIndex % 2 == 0 ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var doodFooterRow: some View {
        HStack(spacing: 0) {
            // Footer label
            HStack {
                Text("CAST PER DAY")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(width: doodCastColumnWidth, height: doodCellHeight)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            // Count per day
            ForEach(Array(doodShootDays.enumerated()), id: \.offset) { dayIndex, day in
                let count = castCountForDay(day: day)
                Text("\(count)")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(count > 0 ? .blue : Color.secondary.opacity(0.4))
                    .frame(width: doodCellWidth, height: doodCellHeight)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            // Grand total
            let grandTotal = totalWorkDays
            Text("\(grandTotal)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: doodSummaryColumnWidth, height: doodCellHeight)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Rectangle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private func castCountForDay(day: DOODShootDay) -> Int {
        var count = 0
        for cast in doodCastMembers {
            let status = doodStatusFor(cast: cast.id, on: day.date, dayIndex: 0)
            if status != .none {
                count += 1
            }
        }
        return count
    }

    // MARK: - DOOD Toolbar
    private var doodToolbar: some View {
        HStack(spacing: 16) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Day out of Days")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            // Stats
            HStack(spacing: 16) {
                doodStatPill(label: "Cast", value: "\(doodCastMembers.count)", color: .blue)
                doodStatPill(label: "Shoot Days", value: "\(doodShootDays.count)", color: .green)
                doodStatPill(label: "Total Work Days", value: "\(totalWorkDays)", color: .orange)
            }

            Spacer()

            // Navigation Tab Buttons
            navigationTabButtons

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            // Legend toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showDOODLegend.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showDOODLegend ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 12))
                    Text("Legend")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(showDOODLegend ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1))
                )
                .foregroundStyle(showDOODLegend ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            // Export menu
            Menu {
                Button {
                    exportDOODPDF()
                } label: {
                    Label("Export as PDF", systemImage: "doc.richtext")
                }

                Button {
                    exportDOOD()
                } label: {
                    Label("Export as CSV", systemImage: "tablecells")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                    Text("Export")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.blue)
                )
                .foregroundStyle(.white)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func doodStatPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.15))
                )
        }
    }

    // MARK: - DOOD Legend
    private var doodLegend: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach([DOODStatus.start, .work, .finish, .startFinish, .hold, .travel, .rehearsal, .fitting, .drop, .pickup], id: \.rawValue) { status in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(status.color)
                                .frame(width: 24, height: 18)
                                .overlay(
                                    Text(status.rawValue)
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundStyle(status.textColor)
                                )

                            Text(legendLabelFor(status))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }

    private func legendLabelFor(_ status: DOODStatus) -> String {
        status.displayName
    }

    // MARK: - DOOD Computed Properties

    /// Get shoot days based on day breaks in the stripboard
    private var doodShootDays: [DOODShootDay] {
        var days: [DOODShootDay] = []
        var dayNumber = 0

        for (idx, scene) in scenes.enumerated() {
            if isDayBreakRow(scene) {
                dayNumber += 1
                // Calculate the date for this day
                if let date = calculateDateForStrip(at: idx) {
                    days.append(DOODShootDay(id: UUID(), date: date, dayNumber: dayNumber))
                }
            }
        }

        // If there are scenes but no day breaks yet, treat all scenes as Day 1
        if days.isEmpty && !scenes.isEmpty {
            days.append(DOODShootDay(id: UUID(), date: productionStartDate, dayNumber: 1))
        }

        return days
    }

    /// Get scenes for a specific production day number (1-indexed)
    private func scenesForProductionDay(_ dayNumber: Int) -> [NSManagedObject] {
        var currentDay = 0
        var dayStartIndex = 0
        var result: [NSManagedObject] = []

        for (idx, scene) in scenes.enumerated() {
            if isDayBreakRow(scene) {
                currentDay += 1
                if currentDay == dayNumber {
                    // Collect scenes from dayStartIndex to idx (exclusive)
                    for i in dayStartIndex..<idx {
                        let s = scenes[i]
                        if !isDayBreakRow(s) && !isOffDayRow(s) {
                            result.append(s)
                        }
                    }
                    return result
                }
                dayStartIndex = idx + 1
            }
        }

        // If dayNumber is 1 and no day breaks, return all non-divider scenes
        if dayNumber == 1 && result.isEmpty {
            for scene in scenes {
                if !isDayBreakRow(scene) && !isOffDayRow(scene) {
                    result.append(scene)
                }
            }
        }

        return result
    }

    /// Get all unique cast members from all scenes
    private var doodCastMembers: [DOODCastMember] {
        var castDict: [String: DOODCastMember] = [:]

        for scene in scenes {
            // Skip day breaks and off days
            if isDayBreakRow(scene) || isOffDayRow(scene) { continue }

            if let castIDs = firstString(scene, keys: ["castIDs", "cast"]) {
                let members = castIDs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for member in members where !member.isEmpty {
                    if castDict[member] == nil {
                        castDict[member] = DOODCastMember(id: member, name: member, role: "")
                    }
                }
            }
        }

        // Sort by cast ID (often numeric like "1", "2", etc.)
        return castDict.values.sorted { lhs, rhs in
            if let lhsNum = Int(lhs.id), let rhsNum = Int(rhs.id) {
                return lhsNum < rhsNum
            }
            return lhs.id < rhs.id
        }
    }

    private var totalWorkDays: Int {
        var total = 0
        for cast in doodCastMembers {
            let stats = doodStatsFor(cast: cast.id)
            total += stats.total
        }
        return total
    }

    // MARK: - DOOD Status Logic

    /// Check if a cast member works on a specific day number
    private func castWorksOnDay(_ castID: String, dayNumber: Int) -> Bool {
        let dayScenes = scenesForProductionDay(dayNumber)
        for scene in dayScenes {
            if let castIDs = firstString(scene, keys: ["castIDs", "cast"]) {
                let members = castIDs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if members.contains(castID) {
                    return true
                }
            }
        }
        return false
    }

    /// Get all day numbers where a cast member works
    private func workingDayNumbers(for castID: String) -> [Int] {
        var days: [Int] = []
        for day in doodShootDays {
            if castWorksOnDay(castID, dayNumber: day.dayNumber) {
                days.append(day.dayNumber)
            }
        }
        return days.sorted()
    }

    private func doodStatusFor(cast castID: String, on date: Date, dayIndex: Int) -> DOODStatus {
        // dayIndex is 0-based, dayNumber is 1-based
        let dayNumber = dayIndex + 1

        // Check if cast works on this day
        guard castWorksOnDay(castID, dayNumber: dayNumber) else {
            return .none
        }

        // Get all days this cast member works
        let workingDays = workingDayNumbers(for: castID)

        guard !workingDays.isEmpty else { return .none }

        // Determine status based on position in working days
        let isFirstDay = dayNumber == workingDays.first
        let isLastDay = dayNumber == workingDays.last

        if isFirstDay && isLastDay {
            return .startFinish
        } else if isFirstDay {
            return .start
        } else if isLastDay {
            return .finish
        } else {
            return .work
        }
    }

    private func doodStatsFor(cast castID: String) -> DOODCastStats {
        var stats = DOODCastStats()

        for (index, _) in doodShootDays.enumerated() {
            let status = doodStatusFor(cast: castID, on: Date(), dayIndex: index)
            switch status {
            case .start, .startFinish:
                stats.startDays += 1
                stats.total += 1
            case .work:
                stats.workDays += 1
                stats.total += 1
            case .finish:
                stats.workDays += 1
                stats.total += 1
            case .hold:
                stats.holdDays += 1
                stats.total += 1
            default:
                break
            }
        }

        return stats
    }

    // MARK: - DOOD Export
    private func exportDOOD() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "day_out_of_days.csv"
        panel.message = "Export Day out of Days Report"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            var csv = "Cast #,Cast Member,Role"
            for (index, day) in doodShootDays.enumerated() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M/d"
                csv += ",D\(index + 1) (\(dateFormatter.string(from: day.date)))"
            }
            csv += ",Total,SW,W,H\n"

            for (castIndex, cast) in doodCastMembers.enumerated() {
                csv += "\(castIndex + 1),\"\(cast.name)\",\"\(cast.role)\""

                for (dayIndex, day) in doodShootDays.enumerated() {
                    let status = doodStatusFor(cast: cast.id, on: day.date, dayIndex: dayIndex)
                    csv += ",\(status.rawValue)"
                }

                let stats = doodStatsFor(cast: cast.id)
                csv += ",\(stats.total),\(stats.startDays),\(stats.workDays),\(stats.holdDays)\n"
            }

            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to export DOOD: \(error)")
            }
        }
    }

    private func exportDOODPDF() {
        // Get project name
        var projectName = "Production"
        if let project = try? moc.existingObject(with: projectID) as? ProjectEntity {
            projectName = project.name ?? "Production"
        }

        // Build status grid
        var statusGrid: [[DOODStatus]] = []
        var stats: [DOODCastStats] = []

        for cast in doodCastMembers {
            var row: [DOODStatus] = []
            for (dayIndex, day) in doodShootDays.enumerated() {
                let status = doodStatusFor(cast: cast.id, on: day.date, dayIndex: dayIndex)
                row.append(status)
            }
            statusGrid.append(row)
            stats.append(doodStatsFor(cast: cast.id))
        }

        // Create report data
        let reportData = DOODReportData(
            productionName: projectName,
            castMembers: doodCastMembers,
            shootDays: doodShootDays,
            statusGrid: statusGrid,
            stats: stats
        )

        // Generate PDF
        guard let pdfDocument = DOODReportPDF.generatePDF(from: reportData) else {
            print("Failed to generate DOOD PDF")
            return
        }

        // Show save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "Day_Out_of_Days_\(projectName.replacingOccurrences(of: " ", with: "_")).pdf"
        panel.message = "Export Day Out of Days PDF Report"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            if pdfDocument.write(to: url) {
                NSWorkspace.shared.open(url)
            } else {
                print("Failed to write DOOD PDF to file")
            }
        }
    }

    // MARK: - One-Liner Schedule Export

    private func exportOneLinerPDF() {
        print("📋 exportOneLinerPDF() called")
        // Get project name
        var projectName = "Production"
        if let project = try? moc.existingObject(with: projectID) as? ProjectEntity {
            projectName = project.name ?? "Production"
        }

        // Build one-liner schedule from scenes
        let schedule = OneLinerSchedule.build(
            from: scenes,
            productionStartDate: productionStartDate,
            projectName: projectName,
            isDayBreak: { isDayBreakRow($0) },
            isOffDay: { isOffDayRow($0) }
        )

        // Generate PDF
        guard let pdfDocument = OneLinerPDF.generatePDF(from: schedule) else {
            print("❌ Failed to generate One-Liner PDF")
            return
        }

        // Show preview
        previewPDF = pdfDocument
        previewTitle = "One-Liner Schedule Preview"
        previewFilename = "One_Liner_Schedule_\(projectName.replacingOccurrences(of: " ", with: "_")).pdf"
        showPDFPreview = true
        print("✅ Showing one-liner preview")
    }

    // Legacy helper properties (kept for compatibility)
    private var scheduledDays: [Date] {
        doodShootDays.map { $0.date }
    }

    private var allCastMembers: [String] {
        doodCastMembers.map { $0.id }
    }

    private func workStatusForCast(_ castMember: String, on day: Date) -> String {
        let status = doodStatusFor(cast: castMember, on: day, dayIndex: 0)
        return status.rawValue
    }

    // MARK: - Generate Call Sheet from Selected Day

    /// Get scenes for a specific production day (day number, 1-indexed)
    private func scenesForDay(_ dayNumber: Int) -> [NSManagedObject] {
        var dayCount = 0
        var dayStartIndex = 0
        var dayEndIndex = scenes.count

        // Find the start and end indices for this day
        for (idx, scene) in scenes.enumerated() {
            if isDayBreakRow(scene) {
                dayCount += 1
                if dayCount == dayNumber {
                    // This day break marks the end of our target day
                    dayEndIndex = idx
                    break
                } else {
                    // Previous day break marks the start of next day
                    dayStartIndex = idx + 1
                }
            }
        }

        // If dayNumber is 1, dayStartIndex should be 0
        if dayNumber == 1 {
            dayStartIndex = 0
        }

        // Collect scenes between start and end, excluding day breaks and off days
        var result: [NSManagedObject] = []
        for idx in dayStartIndex..<dayEndIndex {
            let scene = scenes[idx]
            if !isDayBreakRow(scene) && !isOffDayRow(scene) {
                result.append(scene)
            }
        }

        return result
    }

    /// Generate a call sheet from the selected shoot day
    private func generateCallSheetFromSelectedDay() {
        guard let dayIndex = selectedShootDayIndex else { return }

        // dayBreakItems is 0-indexed, but production days are 1-indexed
        let dayNumber = dayIndex + 1
        let dayScenes = scenesForDay(dayNumber)

        // Get project info
        guard let project = try? moc.existingObject(with: projectID) else { return }
        let projectName = (project.value(forKey: "name") as? String) ?? "Untitled Project"

        // Calculate the date for this day
        let shootDate = calculateDateForDayNumber(dayNumber) ?? Date()

        // Get total number of shoot days
        let totalDays = scenes.filter { isDayBreakRow($0) }.count

        // Create schedule items from scenes
        var scheduleItems: [ScheduleItem] = []
        var allCastIds: Set<String> = []

        for (idx, scene) in dayScenes.enumerated() {
            let sceneNumber = firstString(scene, keys: ["number", "sceneNumber"]) ?? ""
            let heading = firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? ""
            let locationType = (firstString(scene, keys: ["locationType", "intExt"]) ?? "INT").uppercased()
            let timeOfDay = (firstString(scene, keys: ["timeOfDay", "dayNight"]) ?? "DAY").uppercased()
            let castIDsStr = firstString(scene, keys: ["castIDs", "cast"]) ?? ""
            let pageEighths = (scene.value(forKey: "pageEighths") as? NSNumber)?.intValue ?? 0

            // Parse INT/EXT
            let intExt: ScheduleItem.IntExt
            if locationType.contains("EXT") && locationType.contains("INT") {
                intExt = .intExt
            } else if locationType.contains("EXT") {
                intExt = .ext
            } else {
                intExt = .int
            }

            // Parse Day/Night
            let dayNight: ScheduleItem.DayNight
            switch timeOfDay {
            case "NIGHT": dayNight = .night
            case "DAWN": dayNight = .dawn
            case "DUSK": dayNight = .dusk
            case "MORNING": dayNight = .morning
            case "AFTERNOON": dayNight = .afternoon
            case "EVENING": dayNight = .evening
            case "CONTINUOUS": dayNight = .continuous
            case "LATER": dayNight = .later
            case "MOMENTS LATER": dayNight = .momentsLater
            case "SAME TIME": dayNight = .sameTime
            default: dayNight = .day
            }

            // Parse cast IDs
            let castIds = castIDsStr.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            allCastIds.formUnion(castIds)

            // Convert page eighths to decimal pages
            let pages = Double(pageEighths) / 8.0

            let item = ScheduleItem(
                sceneNumber: sceneNumber,
                setDescription: heading,
                intExt: intExt,
                dayNight: dayNight,
                pages: pages,
                estimatedTime: "",
                castIds: castIds,
                location: "",
                notes: "",
                specialRequirements: "",
                sortOrder: idx
            )
            scheduleItems.append(item)
        }

        // Create cast members from cast IDs
        var castMembers: [CastMember] = []
        let sortedCastIds = allCastIds.sorted { lhs, rhs in
            // Try to sort numerically if possible
            if let lhsNum = Int(lhs), let rhsNum = Int(rhs) {
                return lhsNum < rhsNum
            }
            return lhs < rhs
        }

        for (idx, castId) in sortedCastIds.enumerated() {
            let member = CastMember(
                castNumber: Int(castId) ?? (idx + 1),
                role: "Character \(castId)",
                actorName: "",
                status: .work,
                pickupTime: "",
                reportToMakeup: "",
                reportToSet: "",
                remarks: "",
                phone: "",
                email: "",
                daysWorked: 1,
                isStunt: false,
                isPhotoDouble: false
            )
            castMembers.append(member)
        }

        // Create the call sheet
        var callSheet = CallSheet.empty(template: .featureFilm)
        callSheet.title = "Day \(dayNumber) Call Sheet"
        callSheet.projectName = projectName
        callSheet.shootDate = shootDate
        callSheet.dayNumber = dayNumber
        callSheet.totalDays = totalDays
        callSheet.scheduleItems = scheduleItems
        callSheet.castMembers = castMembers
        callSheet.createdDate = Date()
        callSheet.lastModified = Date()

        // Set the generated call sheet and show the editor
        generatedCallSheet = callSheet
        showCallSheetEditor = true
    }

    /// Calculate the date for a given production day number
    private func calculateDateForDayNumber(_ dayNumber: Int) -> Date? {
        let calendar = Calendar.current
        var currentDate = productionStartDate
        var currentDayNumber = 1

        for scene in scenes {
            if isDayBreakRow(scene) {
                if currentDayNumber == dayNumber {
                    return currentDate
                }
                currentDayNumber += 1
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDate
                }
            } else if isOffDayRow(scene) {
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDate
                }
            }
        }

        // If we reach here and dayNumber matches, return current date
        if currentDayNumber == dayNumber {
            return currentDate
        }

        return nil
    }
}
// MARK: - Preview
#Preview("Scheduler with Sample Data") {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext

    // Create a sample project
    let project = ProjectEntity(context: context)
    project.id = UUID()
    project.name = "Preview Project"
    project.startDate = Date()

    // Create some sample scenes
    let scene1 = SceneEntity(context: context)
    scene1.id = UUID()
    scene1.number = "1"
    scene1.locationType = "INT"
    scene1.scriptLocation = "OFFICE"
    scene1.timeOfDay = "NIGHT"
    scene1.pageEighths = 2
    scene1.castIDs = "1, 2, 3"
    scene1.descriptionText = "Sample scene description for scene 1"
    scene1.project = project

    let scene2 = SceneEntity(context: context)
    scene2.id = UUID()
    scene2.number = "2"
    scene2.locationType = "EXT"
    scene2.scriptLocation = "PARKING LOT"
    scene2.timeOfDay = "DAY"
    scene2.pageEighths = 4
    scene2.castIDs = "1, 4"
    scene2.descriptionText = "Sample scene description for scene 2"
    scene2.project = project

    let scene3 = SceneEntity(context: context)
    scene3.id = UUID()
    scene3.number = "3"
    scene3.locationType = "INT"
    scene3.scriptLocation = "CONFERENCE ROOM"
    scene3.timeOfDay = "DAY"
    scene3.pageEighths = 6
    scene3.castIDs = "1, 2, 3, 5"
    scene3.descriptionText = "Sample scene description for scene 3"
    scene3.project = project

    try? context.save()

    return SchedulerView(projectID: project.objectID)
        .environment(\.managedObjectContext, context)
        .frame(minWidth: 1000, minHeight: 600)
}

// MARK: - Modern Date Picker Sheet

struct ModernDatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var tempDate: Date
    @State private var displayedMonth: Date

    init(selectedDate: Binding<Date>, onDateSelected: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
        self._displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Production Start Date")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Choose when your production begins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            // Selected Date Display
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatFullDate(tempDate))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.blue.opacity(0.03))

            // Calendar View
            VStack(spacing: 20) {
                // Month Navigation
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(dateFormatter.string(from: displayedMonth))
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Week Day Headers
                HStack(spacing: 0) {
                    ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date = date {
                            DayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: tempDate),
                                isToday: calendar.isDateInToday(date),
                                isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                            ) {
                                tempDate = date
                            }
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
            }
            .padding(24)

            Divider()

            // Footer Actions
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button {
                    tempDate = Date()
                } label: {
                    Text("Today")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button {
                    onDateSelected(tempDate)
                } label: {
                    Text("Set Date")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(24)
        }
        .frame(width: 500, height: 650)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let days = calendar.generateDates(
            inside: monthInterval,
            matching: DateComponents(hour: 0, minute: 0, second: 0)
        )

        return days
    }

    struct DayCell: View {
        let date: Date
        let isSelected: Bool
        let isToday: Bool
        let isCurrentMonth: Bool
        let action: () -> Void

        private let calendar = Calendar.current

        var body: some View {
            Button {
                action()
            } label: {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? .white :
                        isCurrentMonth ? .primary : .secondary.opacity(0.5)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            } else if isToday {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.blue, lineWidth: 1.5)
                                    )
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

extension Calendar {
    func generateDates(
        inside interval: DateInterval,
        matching components: DateComponents
    ) -> [Date?] {
        var dates: [Date?] = []

        // Get the first day of the month
        guard let monthStart = interval.start as Date?,
              let monthFirstWeek = dateInterval(of: .weekOfMonth, for: monthStart) else {
            return []
        }

        // Start from the first day of the week containing the first day of the month
        var currentDate = monthFirstWeek.start

        // Generate dates for 6 weeks (42 days) to cover all possible month layouts
        for _ in 0..<42 {
            if currentDate < interval.start || currentDate >= interval.end {
                dates.append(nil)
            } else {
                dates.append(currentDate)
            }
            guard let nextDate = self.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }
}

#Preview("Empty Scheduler") {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext

    let project = ProjectEntity(context: context)
    project.id = UUID()
    project.name = "Empty Project"
    project.startDate = Date()

    try? context.save()

    return SchedulerView(projectID: project.objectID)
        .environment(\.managedObjectContext, context)
        .frame(minWidth: 1000, minHeight: 600)
}


#endif
