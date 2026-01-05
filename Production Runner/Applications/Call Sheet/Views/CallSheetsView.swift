// MARK: - Call Sheets View
// Production Runner - Call Sheet Module
// Main list view and management interface

import SwiftUI
import CoreData

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Main Entry Point

// Scheduler Tab enum (matching SchedulerView)
enum SchedulerTab: String, CaseIterable {
    case stripboard = "Stripboard"
    case dood = "Day Out of Days"
    case callSheets = "Call Sheets"
}

#if os(macOS)
struct CallSheetsView: View {
    @Environment(\.managedObjectContext) private var moc
    let projectID: NSManagedObjectID
    var selectedTab: Binding<SchedulerTab>?

    @State private var internalSelectedTab: SchedulerTab = .callSheets

    var body: some View {
        CallSheetsListView(projectID: projectID, selectedTab: selectedTab ?? $internalSelectedTab)
            .callSheetBackground()
    }
}
#else
// iOS Placeholder
struct CallSheetsView: View {
    let projectID: NSManagedObjectID
    var selectedTab: Binding<SchedulerTab>?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Call Sheets")
                .font(.title.bold())

            Text("Coming Soon on iOS")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

// MARK: - Call Sheets List View

#if os(macOS)
struct CallSheetsListView: View {
    @Environment(\.managedObjectContext) private var moc
    let projectID: NSManagedObjectID
    @Binding var selectedTab: SchedulerTab

    @State private var callSheets: [CallSheet] = []
    @State private var selectedSheet: CallSheet?
    @State private var isEditing = false
    @State private var editingSheet: CallSheet?
    @State private var searchText = ""
    @State private var showNewSheet = false
    @State private var showDeleteConfirm = false
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var viewMode: ViewMode = .grid

    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case dayNumber = "By Day Number"
        case title = "By Title"
    }

    enum ViewMode {
        case grid, list
    }

    private var projectName: String {
        guard let project = try? moc.existingObject(with: projectID) else { return "" }
        return (project.value(forKey: "name") as? String) ?? ""
    }

    private var filteredSheets: [CallSheet] {
        var sheets = callSheets

        // Filter by search
        if !searchText.isEmpty {
            sheets = sheets.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.projectName.localizedCaseInsensitiveContains(searchText) ||
                $0.shootingLocation.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOrder {
        case .dateDescending:
            sheets.sort { $0.shootDate > $1.shootDate }
        case .dateAscending:
            sheets.sort { $0.shootDate < $1.shootDate }
        case .dayNumber:
            sheets.sort { $0.dayNumber < $1.dayNumber }
        case .title:
            sheets.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        }

        return sheets
    }

    var body: some View {
        if isEditing, let sheet = editingSheet {
            CallSheetEditorView(
                callSheet: Binding(
                    get: { sheet },
                    set: { updated in
                        if let idx = callSheets.firstIndex(where: { $0.id == updated.id }) {
                            callSheets[idx] = updated
                            selectedSheet = updated
                        }
                        editingSheet = updated
                    }
                ),
                onClose: { isEditing = false },
                onSave: { saved in
                    if let idx = callSheets.firstIndex(where: { $0.id == saved.id }) {
                        callSheets[idx] = saved
                        selectedSheet = saved
                    }
                    isEditing = false
                    saveCallSheet(saved)
                }
            )
        } else {
            VStack(spacing: 0) {
                // Top Toolbar
                ListToolbar(
                    searchText: $searchText,
                    sortOrder: $sortOrder,
                    viewMode: $viewMode,
                    selectedSheet: selectedSheet,
                    selectedTab: $selectedTab,
                    onCreate: { showNewSheet = true },
                    onEdit: {
                        guard let sheet = selectedSheet else { return }
                        editingSheet = sheet
                        isEditing = true
                    },
                    onDuplicate: duplicateSelected,
                    onDelete: { showDeleteConfirm = true },
                    onExport: exportSelected
                )

                Divider()

                // Content
                if filteredSheets.isEmpty {
                    CallSheetEmptyStateView(
                        hasSheets: !callSheets.isEmpty,
                        onCreate: { showNewSheet = true }
                    )
                } else {
                    ScrollView {
                        switch viewMode {
                        case .grid:
                            gridView
                        case .list:
                            listView
                        }
                    }
                    .padding(CallSheetDesign.cardPadding)
                }
            }
            .sheet(isPresented: $showNewSheet) {
                NewCallSheetSheet(isPresented: $showNewSheet) { newSheet in
                    // Note: projectName is left blank by default - user can fill it in manually
                    callSheets.insert(newSheet, at: 0)
                    selectedSheet = newSheet
                    saveCallSheet(newSheet)
                    editingSheet = newSheet
                    isEditing = true
                }
            }
            .alert("Delete Call Sheet", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelected()
                }
            } message: {
                Text("Are you sure you want to delete \"\(selectedSheet?.title ?? "")\"? This cannot be undone.")
            }
            .onAppear {
                loadCallSheets()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
                performDeleteCommand()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
                performSelectAllCommand()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
                performCutCommand()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
                performCopyCommand()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
                performPasteCommand()
            }
        }
    }

    // MARK: - Global Keyboard Shortcut Handlers

    private func performDeleteCommand() {
        // Check if text field has focus - let system handle delete
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text delete
            }
        }
        guard selectedSheet != nil else { return }
        showDeleteConfirm = true
    }

    private func performSelectAllCommand() {
        // Check if text field has focus - let system handle select all
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text select all
            }
        }
        // Single selection view - no-op
    }

    private func performCutCommand() {
        // Check if text field has focus - let system handle cut
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text cut
            }
        }
        // No clipboard support for call sheets yet
    }

    private func performCopyCommand() {
        // Check if text field has focus - let system handle copy
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text copy
            }
        }
        // No clipboard support for call sheets yet
    }

    private func performPasteCommand() {
        // Check if text field has focus - let system handle paste
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text paste
            }
        }
        // No clipboard support for call sheets yet
    }

    // MARK: - Grid View

    private var gridView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
        ], spacing: 16) {
            ForEach(filteredSheets) { sheet in
                CallSheetGridCard(
                    sheet: sheet,
                    isSelected: selectedSheet?.id == sheet.id,
                    onTap: { selectedSheet = sheet },
                    onDoubleTap: {
                        selectedSheet = sheet
                        editingSheet = sheet
                        isEditing = true
                    }
                )
                .padding(4) // Allow room for selection border and shadow
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("TITLE")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("DATE")
                    .frame(width: 120)
                Text("DAY")
                    .frame(width: 60)
                Text("STATUS")
                    .frame(width: 80)
                Text("LOCATION")
                    .frame(width: 150)
            }
            .font(CallSheetDesign.labelFont)
            .foregroundColor(CallSheetDesign.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CallSheetDesign.sectionHeader)

            Divider()

            ForEach(filteredSheets) { sheet in
                CallSheetListRow(
                    sheet: sheet,
                    isSelected: selectedSheet?.id == sheet.id,
                    onTap: { selectedSheet = sheet },
                    onDoubleTap: {
                        selectedSheet = sheet
                        editingSheet = sheet
                        isEditing = true
                    }
                )
                Divider()
                    .background(CallSheetDesign.divider)
            }
        }
        .callSheetCard()
    }

    // MARK: - Data Operations

    private func loadCallSheets() {
        callSheets = CallSheetDataService.shared.loadCallSheets(projectID: projectID, in: moc)
    }

    private func saveCallSheet(_ sheet: CallSheet) {
        CallSheetDataService.shared.saveCallSheet(sheet, projectID: projectID, in: moc)
    }

    private func duplicateSelected() {
        guard let sheet = selectedSheet else { return }
        var duplicate = sheet
        duplicate.id = UUID()
        duplicate.title = sheet.title + " (Copy)"
        duplicate.status = .draft
        duplicate.createdDate = Date()
        duplicate.lastModified = Date()
        callSheets.insert(duplicate, at: 0)
        selectedSheet = duplicate
        saveCallSheet(duplicate)
    }

    private func deleteSelected() {
        guard let sheet = selectedSheet else { return }
        CallSheetDataService.shared.deleteCallSheet(sheet, in: moc)
        callSheets.removeAll { $0.id == sheet.id }
        selectedSheet = nil
    }

    private func exportSelected() {
        guard let sheet = selectedSheet else { return }
        let pageSize = CGSize(width: 612, height: 792)
        let printLayout = CallSheetPrintLayout(callSheet: sheet)

        let hosting = NSHostingView(rootView: printLayout.frame(width: pageSize.width, height: pageSize.height))
        hosting.frame = CGRect(origin: .zero, size: pageSize)
        let data = hosting.dataWithPDF(inside: hosting.bounds)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = sanitizedFileName(from: sheet.title) + ".pdf"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private func sanitizedFileName(from string: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return string.components(separatedBy: invalid).joined().replacingOccurrences(of: "\n", with: " ")
    }
}

// MARK: - List Toolbar

struct ListToolbar: View {
    @Binding var searchText: String
    @Binding var sortOrder: CallSheetsListView.SortOrder
    @Binding var viewMode: CallSheetsListView.ViewMode
    let selectedSheet: CallSheet?
    @Binding var selectedTab: SchedulerTab
    let onCreate: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    private func tabIcon(for tab: SchedulerTab) -> String {
        switch tab {
        case .stripboard: return "calendar.day.timeline.left"
        case .dood: return "calendar.badge.clock"
        case .callSheets: return "doc.text.fill"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Search
            CallSheetSearchField(text: $searchText, placeholder: "Search call sheets...")
                .frame(maxWidth: 300)
                .customTooltip(Tooltips.CallSheet.searchCallSheets)

            Spacer()

            // Sort
            Picker("Sort", selection: $sortOrder) {
                ForEach(CallSheetsListView.SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .labelsHidden()
            .frame(width: 140)
            .customTooltip(Tooltips.CallSheet.sortOrder)

            // View Mode
            Picker("View", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(CallSheetsListView.ViewMode.grid)
                Image(systemName: "list.bullet").tag(CallSheetsListView.ViewMode.list)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 80)

            Divider()
                .frame(height: 24)

            // Actions
            HStack(spacing: 8) {
                CallSheetButton(title: "New", icon: "plus", style: .primary, action: onCreate)
                    .keyboardShortcut("n", modifiers: [.command])
                    .customTooltip(Tooltips.CallSheet.newCallSheet)

                CallSheetButton(title: "Edit", icon: "pencil", isDisabled: selectedSheet == nil, action: onEdit)
                    .keyboardShortcut(.return, modifiers: [])
                    .customTooltip(Tooltips.CallSheet.editCallSheet)

                CallSheetButton(title: "Duplicate", icon: "doc.on.doc", isDisabled: selectedSheet == nil, action: onDuplicate)
                    .keyboardShortcut("d", modifiers: [.command])
                    .customTooltip(Tooltips.CallSheet.duplicateCallSheet)

                CallSheetButton(title: "Export", icon: "arrow.down.doc", isDisabled: selectedSheet == nil, action: onExport)
                    .keyboardShortcut("e", modifiers: [.command])
                    .customTooltip(Tooltips.CallSheet.exportCallSheet)

                CallSheetButton(title: "Delete", icon: "trash", style: .destructive, isDisabled: selectedSheet == nil, action: onDelete)
                    .keyboardShortcut(.delete, modifiers: [])
                    .customTooltip(Tooltips.CallSheet.deleteCallSheet)
            }

            Spacer()

            // Navigation Tab Buttons
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
                    .shadow(color: Color.indigo.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(CallSheetDesign.cardBackground)
    }
}

// MARK: - Grid Card

struct CallSheetGridCard: View {
    let sheet: CallSheet
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with gradient
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CallSheetStatusBadge(status: sheet.status)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }

                Text(sheet.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if !sheet.projectName.isEmpty {
                    Text(sheet.projectName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [CallSheetDesign.accent, CallSheetDesign.accent.opacity(0.8)]
                        : [CallSheetDesign.textSecondary.opacity(0.8), CallSheetDesign.textSecondary.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Body
            VStack(alignment: .leading, spacing: 10) {
                InfoRow(icon: "calendar", label: "Date", value: dateFormatter.string(from: sheet.shootDate))
                InfoRow(icon: "film", label: "Day", value: "\(sheet.dayNumber) of \(sheet.totalDays)")

                if !sheet.shootingLocation.isEmpty {
                    InfoRow(icon: "mappin", label: "Location", value: sheet.shootingLocation)
                }

                if let crewCall = sheet.crewCall {
                    InfoRow(icon: "clock", label: "Crew Call", value: crewCall.formatted(date: .omitted, time: .shortened))
                }
            }
            .padding(16)
        }
        .background(CallSheetDesign.cardBackground)
        .cornerRadius(CallSheetDesign.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CallSheetDesign.cardCornerRadius)
                .stroke(isSelected ? CallSheetDesign.accent : CallSheetDesign.border, lineWidth: isSelected ? 2 : 1)
        )
        .shadow(
            color: isSelected ? CallSheetDesign.accent.opacity(0.2) : Color.black.opacity(0.05),
            radius: isSelected ? 8 : 4,
            x: 0, y: 2
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
        .onTapGesture(perform: onTap)
        .onTapGesture(count: 2, perform: onDoubleTap)
    }
}

// MARK: - List Row

struct CallSheetListRow: View {
    let sheet: CallSheet
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Title
            HStack(spacing: 10) {
                if isSelected {
                    Circle()
                        .fill(CallSheetDesign.accent)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sheet.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(CallSheetDesign.textPrimary)

                    if !sheet.projectName.isEmpty {
                        Text(sheet.projectName)
                            .font(.system(size: 11))
                            .foregroundColor(CallSheetDesign.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Date
            Text(dateFormatter.string(from: sheet.shootDate))
                .font(CallSheetDesign.bodyFont)
                .foregroundColor(CallSheetDesign.textSecondary)
                .frame(width: 120)

            // Day
            Text("\(sheet.dayNumber)/\(sheet.totalDays)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CallSheetDesign.textPrimary)
                .frame(width: 60)

            // Status
            CallSheetStatusBadge(status: sheet.status)
                .frame(width: 80)

            // Location
            Text(sheet.shootingLocation.isEmpty ? "—" : sheet.shootingLocation)
                .font(CallSheetDesign.bodyFont)
                .foregroundColor(CallSheetDesign.textSecondary)
                .lineLimit(1)
                .frame(width: 150)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? CallSheetDesign.accent.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onTapGesture(count: 2, perform: onDoubleTap)
    }
}

// MARK: - Empty State View

struct CallSheetEmptyStateView: View {
    let hasSheets: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasSheets ? "magnifyingglass" : "doc.text")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(CallSheetDesign.textTertiary)

            VStack(spacing: 6) {
                Text(hasSheets ? "No Results Found" : "No Call Sheets Yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(CallSheetDesign.textPrimary)

                Text(hasSheets ? "Try adjusting your search terms" : "Create your first call sheet to get started")
                    .font(CallSheetDesign.bodyFont)
                    .foregroundColor(CallSheetDesign.textSecondary)
            }

            if !hasSheets {
                CallSheetButton(title: "Create Call Sheet", icon: "plus", style: .primary, action: onCreate)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
    }
}

#endif
