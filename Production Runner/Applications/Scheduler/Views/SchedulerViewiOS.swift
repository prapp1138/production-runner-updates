
// swiftlint:disable all
#if os(iOS)
import SwiftUI
import Foundation
import CoreData
#if os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers

// MARK: - Modern Scheduler View
struct SchedulerView: View {
    @Environment(\.managedObjectContext) fileprivate var moc
    @Environment(\.colorScheme) private var colorScheme
    let projectID: NSManagedObjectID

    // Data
    @State fileprivate var scenes: [NSManagedObject] = []
    @State private var shootDays: [ShootDayEntity] = []

    // Selection
    @State private var selectedIDs: Set<NSManagedObjectID> = []

    // UI State
    @State private var searchText: String = ""
    @State private var showFilters: Bool = false
    @State private var showInspector: Bool = false
    @State private var viewMode: ViewMode = .timeline
    @State private var selectedDay: Date = Date()

    // Filters
    @State private var filterInt: Bool = true
    @State private var filterExt: Bool = true
    @State private var filterDay: Bool = true
    @State private var filterNight: Bool = true

    private enum ViewMode: String, CaseIterable {
        case timeline = "Timeline"
        case list = "List"
        case board = "Board"

        var icon: String {
            switch self {
            case .timeline: return "calendar"
            case .list: return "list.bullet"
            case .board: return "square.grid.2x2"
            }
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Integrated toolbar
                inlineToolbar

                // Main content area
                if filteredScenes.isEmpty {
                    emptyState
                } else {
                    contentView
                }
            }
        }
        .sheet(isPresented: $showInspector) {
            inspectorSheet
        }
        .onAppear(perform: reload)
        .onChange(of: projectID) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: moc)) { _ in reload() }
    }

    // MARK: - Inline Toolbar
    private var inlineToolbar: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                    Text("Scheduler")
                        .font(.system(size: 22, weight: .bold))
                }

                Spacer()

                // Quick action buttons
                HStack(spacing: 8) {
                    Button {
                        addStrip()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("New Scene")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        addDayBreak()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Add Day")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showInspector.toggle()
                        }
                    } label: {
                        Image(systemName: showInspector ? "sidebar.trailing.fill" : "sidebar.trailing")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(showInspector ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1))
                            )
                            .foregroundStyle(showInspector ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button { exportPDF() } label: {
                            Label("Export PDF", systemImage: "doc.fill")
                        }

                        Button { exportCSV() } label: {
                            Label("Export CSV", systemImage: "tablecells")
                        }

                        Button { generateDOOD() } label: {
                            Label("Generate DOOD", systemImage: "calendar.circle")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 13, weight: .semibold))
                            Text("More")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Control bar with view modes and filters
            headerView
        }
        .background(
            Color(uiColor: .systemBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 3, y: 2)
        )
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // View mode picker and filters row
            HStack(spacing: 12) {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showFilters.toggle()
                    }
                } label: {
                    Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(showFilters ? Color.blue.opacity(0.1) : Color.clear)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 16)

            // Filters (when expanded)
            if showFilters {
                filterView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Stats bar
            statsBar
                .padding(.bottom, 8)
        }
    }

    // MARK: - Filter View
    private var filterView: some View {
        VStack(spacing: 12) {
            // INT/EXT toggles
            HStack(spacing: 8) {
                Text("Location Type")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                SchedulerFilterChip(title: "INT", icon: "building", isSelected: $filterInt)
                SchedulerFilterChip(title: "EXT", icon: "tree", isSelected: $filterExt)
                Spacer()
            }

            Divider()

            // Time of Day toggles
            HStack(spacing: 8) {
                Text("Time of Day")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                SchedulerFilterChip(title: "Day", icon: "sun.max", isSelected: $filterDay)
                SchedulerFilterChip(title: "Night", icon: "moon", isSelected: $filterNight)
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack(spacing: 20) {
            SchedulerStatBadge(
                icon: "film",
                value: "\(filteredScenes.count)",
                label: "Scenes",
                color: .blue
            )

            SchedulerStatBadge(
                icon: "doc.text",
                value: totalPages,
                label: "Pages",
                color: .green
            )

            SchedulerStatBadge(
                icon: "calendar",
                value: "\(shootDays.count)",
                label: "Days",
                color: .orange
            )

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .timeline:
            timelineView
        case .list:
            listView
        case .board:
            boardView
        }
    }

    // MARK: - Timeline View
    private var timelineView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedByShootDay, id: \.day?.objectID) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        // Day header
                        if let day = group.day {
                            dayHeaderView(day: day)
                        }

                        // Scenes for this day
                        ForEach(group.scenes, id: \.objectID) { scene in
                            sceneCardView(scene: scene)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        if selectedIDs.contains(scene.objectID) {
                                            selectedIDs.remove(scene.objectID)
                                        } else {
                                            selectedIDs.insert(scene.objectID)
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - List View
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredScenes, id: \.objectID) { scene in
                    sceneListRow(scene: scene)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                if selectedIDs.contains(scene.objectID) {
                                    selectedIDs.remove(scene.objectID)
                                } else {
                                    selectedIDs.insert(scene.objectID)
                                }
                            }
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Board View
    private var boardView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredScenes, id: \.objectID) { scene in
                    compactSceneCard(scene: scene)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                if selectedIDs.contains(scene.objectID) {
                                    selectedIDs.remove(scene.objectID)
                                } else {
                                    selectedIDs.insert(scene.objectID)
                                }
                            }
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Day Header View
    private func dayHeaderView(day: ShootDayEntity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)

                Text("D\(day.dayNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(day.dayNumber)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                if let date = day.date {
                    Text(date, style: .date)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Day stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(scenesForDay(day).count) scenes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)

                Text(pagesForDay(day))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
        )
    }

    // MARK: - Scene Card View
    private func sceneCardView(scene: NSManagedObject) -> some View {
        let isSelected = selectedIDs.contains(scene.objectID)
        let num = firstString(scene, keys: ["number"]) ?? "—"
        let heading = firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "Untitled Scene"
        let intExt = firstString(scene, keys: ["locationType", "intExt"]) ?? ""
        let time = firstString(scene, keys: ["timeOfDay", "time"]) ?? ""
        let pages = pageLengthString(scene)
        let stripColor = stripTintColor(intExt: intExt, time: time)

        return VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 12) {
                // Scene number badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(stripColor)
                        .frame(width: 48, height: 48)

                    Text(num)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        if !intExt.isEmpty {
                            Label(intExt, systemImage: intExt.uppercased().contains("INT") ? "building" : "tree")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        if !time.isEmpty {
                            Label(time, systemImage: time.uppercased().contains("DAY") ? "sun.max" : "moon")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Label(pages, systemImage: "doc.text")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }

            // Description (if available)
            if let desc = firstString(scene, keys: ["descriptionText", "sceneDescription"]), !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.05), radius: isSelected ? 12 : 4, y: 2)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Scene List Row
    private func sceneListRow(scene: NSManagedObject) -> some View {
        let isSelected = selectedIDs.contains(scene.objectID)
        let num = firstString(scene, keys: ["number"]) ?? "—"
        let heading = firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "Untitled Scene"
        let intExt = firstString(scene, keys: ["locationType", "intExt"]) ?? ""
        let time = firstString(scene, keys: ["timeOfDay", "time"]) ?? ""
        let pages = pageLengthString(scene)
        let stripColor = stripTintColor(intExt: intExt, time: time)

        return HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(stripColor)
                .frame(width: 6)

            // Scene number
            Text(num)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 48, alignment: .leading)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(heading)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(intExt)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(time)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(pages)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Compact Scene Card
    private func compactSceneCard(scene: NSManagedObject) -> some View {
        let isSelected = selectedIDs.contains(scene.objectID)
        let num = firstString(scene, keys: ["number"]) ?? "—"
        let heading = firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "Untitled Scene"
        let intExt = firstString(scene, keys: ["locationType", "intExt"]) ?? ""
        let time = firstString(scene, keys: ["timeOfDay", "time"]) ?? ""
        let pages = pageLengthString(scene)
        let stripColor = stripTintColor(intExt: intExt, time: time)

        return VStack(alignment: .leading, spacing: 12) {
            // Header with color
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(stripColor)
                    .frame(height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text(num)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(pages)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(heading)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if !intExt.isEmpty {
                        CompactBadge(text: intExt, color: .blue)
                    }
                    if !time.isEmpty {
                        CompactBadge(text: time, color: .orange)
                    }
                }
            }
            .padding(12)

            if isSelected {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Scenes Scheduled")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Add scenes from Breakdowns or create new scenes to build your shooting schedule")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                addStrip()
            } label: {
                Label("Add Scene", systemImage: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Inspector Sheet
    private var inspectorSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Selected scenes section
                    if !selectedIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Selection")
                                .font(.system(size: 20, weight: .bold))

                            Text("\(selectedIDs.count) scene(s) selected")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)

                            // Quick actions
                            VStack(spacing: 12) {
                                InspectorButton(title: "Duplicate", icon: "square.on.square", color: .blue) {
                                    duplicateSelected()
                                }

                                InspectorButton(title: "Move to Day", icon: "calendar", color: .green) {
                                    // Show day picker
                                }

                                InspectorButton(title: "Delete", icon: "trash", color: .red) {
                                    deleteSelected()
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }

                    // Day logistics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day Planning")
                            .font(.system(size: 20, weight: .bold))

                        DatePicker("Selected Day", selection: $selectedDay, displayedComponents: .date)
                            .datePickerStyle(.compact)

                        Button {
                            addDayBreak()
                        } label: {
                            Label("Create Shoot Day", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )

                    // Export options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export")
                            .font(.system(size: 20, weight: .bold))

                        VStack(spacing: 12) {
                            InspectorButton(title: "Export PDF", icon: "doc.fill", color: .orange) {
                                exportPDF()
                            }

                            InspectorButton(title: "Export CSV", icon: "tablecells", color: .green) {
                                exportCSV()
                            }

                            InspectorButton(title: "Generate DOOD", icon: "calendar.circle", color: .purple) {
                                generateDOOD()
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showInspector = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Data Helpers

    private var filteredScenes: [NSManagedObject] {
        var items = scenes

        // INT/EXT filter
        items = items.filter { s in
            let intExt = firstString(s, keys: ["locationType", "intExt"])?.uppercased() ?? ""
            let passInt = filterInt && intExt.contains("INT")
            let passExt = filterExt && intExt.contains("EXT")
            return (passInt || passExt) || (filterInt && filterExt)
        }

        // Time filter
        items = items.filter { s in
            let time = firstString(s, keys: ["timeOfDay", "time"])?.uppercased() ?? ""
            var allowed = false
            if filterDay { allowed = allowed || time.contains("DAY") }
            if filterNight { allowed = allowed || time.contains("NIGHT") }
            if !(filterDay || filterNight) { allowed = true }
            return allowed
        }

        // Search
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            items = items.filter { s in
                let searchable = [
                    firstString(s, keys: ["number"]) ?? "",
                    firstString(s, keys: ["scriptLocation", "sceneHeading", "heading"]) ?? "",
                    firstString(s, keys: ["timeOfDay", "time"]) ?? ""
                ].joined(separator: " ").lowercased()
                return searchable.contains(query)
            }
        }

        return items
    }

    private var groupedByShootDay: [(day: ShootDayEntity?, scenes: [NSManagedObject])] {
        var groups: [(day: ShootDayEntity?, scenes: [NSManagedObject])] = []
        var unscheduled: [NSManagedObject] = []

        for scene in filteredScenes {
            if let day = scene.value(forKey: "shootDay") as? ShootDayEntity {
                if let index = groups.firstIndex(where: { $0.day?.objectID == day.objectID }) {
                    groups[index].scenes.append(scene)
                } else {
                    groups.append((day: day, scenes: [scene]))
                }
            } else {
                unscheduled.append(scene)
            }
        }

        // Sort groups by day number
        groups.sort { ($0.day?.dayNumber ?? 0) < ($1.day?.dayNumber ?? 0) }

        // Add unscheduled scenes
        if !unscheduled.isEmpty {
            groups.append((day: nil, scenes: unscheduled))
        }

        return groups
    }

    private func scenesForDay(_ day: ShootDayEntity) -> [NSManagedObject] {
        filteredScenes.filter { scene in
            if let sceneDay = scene.value(forKey: "shootDay") as? ShootDayEntity {
                return sceneDay.objectID == day.objectID
            }
            return false
        }
    }

    private func pagesForDay(_ day: ShootDayEntity) -> String {
        let scenes = scenesForDay(day)
        let totalEighths = scenes.reduce(0) { acc, scene in
            if let eighths = (scene.value(forKey: "pageEighths") as? NSNumber)?.intValue {
                return acc + eighths
            }
            return acc
        }
        return formatEighths(totalEighths)
    }

    private var totalPages: String {
        let totalEighths = filteredScenes.reduce(0) { acc, scene in
            if let eighths = (scene.value(forKey: "pageEighths") as? NSNumber)?.intValue {
                return acc + eighths
            }
            return acc
        }
        return formatEighths(totalEighths)
    }

    private func stripTintColor(intExt: String, time: String) -> Color {
        let ie = intExt.uppercased()
        let t = time.uppercased()

        let isINT = ie.contains("INT")
        let isEXT = ie.contains("EXT")
        let isDAY = t.contains("DAY")
        let isNGT = t.contains("NIGHT")

        // Modern, subtle colors
        switch (isINT, isEXT, isDAY, isNGT) {
        case (true, false, true, false):
            return Color(red: 0.95, green: 0.95, blue: 0.97) // Light gray-blue
        case (false, true, true, false):
            return Color(red: 1.0, green: 0.98, blue: 0.85) // Soft yellow
        case (true, false, false, true):
            return Color(red: 0.88, green: 0.92, blue: 1.0) // Light blue
        case (false, true, false, true):
            return Color(red: 0.88, green: 0.96, blue: 0.90) // Light green
        default:
            return Color(uiColor: .tertiarySystemBackground)
        }
    }

    // MARK: - Data Loading

    private func reload() {
        moc.perform {
            let project = try? moc.existingObject(with: projectID)

            // Load scenes
            guard let entityName = preferredSceneEntityName() else {
                DispatchQueue.main.async { self.scenes = [] }
                return
            }

            let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let project {
                req.predicate = NSPredicate(format: "project == %@", project)
            }
            req.returnsObjectsAsFaults = false

            let fetched = (try? moc.fetch(req)) ?? []
            let sorted = fetched.sorted { a, b in
                let aOrder = (a.value(forKey: "sortIndex") as? NSNumber)?.intValue ?? Int.max
                let bOrder = (b.value(forKey: "sortIndex") as? NSNumber)?.intValue ?? Int.max
                if aOrder != bOrder { return aOrder < bOrder }
                let aNum = firstString(a, keys: ["number"]) ?? ""
                let bNum = firstString(b, keys: ["number"]) ?? ""
                return aNum.localizedStandardCompare(bNum) == .orderedAscending
            }

            // Load shoot days
            let dayReq = NSFetchRequest<ShootDayEntity>(entityName: "ShootDayEntity")
            if let project = project as? ProjectEntity {
                dayReq.predicate = NSPredicate(format: "project == %@", project)
            }
            dayReq.sortDescriptors = [NSSortDescriptor(key: "dayNumber", ascending: true)]
            let days = (try? moc.fetch(dayReq)) ?? []

            DispatchQueue.main.async {
                self.scenes = sorted
                self.shootDays = days
            }
        }
    }

    private func preferredSceneEntityName() -> String? {
        guard let model = moc.persistentStoreCoordinator?.managedObjectModel else { return nil }
        if model.entitiesByName.keys.contains("SceneEntity") { return "SceneEntity" }
        if model.entitiesByName.keys.contains("StripEntity") { return "StripEntity" }
        return nil
    }

    // MARK: - Actions

    private func addStrip() {
        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        moc.perform {
            let obj = NSManagedObject(entity: entity, insertInto: moc)
            obj.setValue("", forKey: "number")
            obj.setValue("INT.", forKey: "locationType")
            obj.setValue("DAY", forKey: "timeOfDay")
            obj.setValue("New Scene", forKey: "sceneHeading")
            obj.setValue(4, forKey: "pageEighths")

            do {
                try moc.save()
                DispatchQueue.main.async { reload() }
            } catch {
                NSLog("Failed to add scene: \(error)")
            }
        }
    }

    private func addDayBreak() {
        guard let project = try? moc.existingObject(with: projectID) as? ProjectEntity else { return }
        let day = project.createShootDay(type: .shoot, date: selectedDay, in: moc)

        guard let name = preferredSceneEntityName(),
              let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] else { return }

        moc.perform {
            let obj = NSManagedObject(entity: entity, insertInto: moc)
            obj.setValue("—", forKey: "number")
            obj.setValue("DAY BREAK — D\(day.dayNumber)", forKey: "sceneHeading")
            obj.setValue(0, forKey: "pageEighths")
            if obj.entity.relationshipsByName.keys.contains("shootDay") {
                obj.setValue(day, forKey: "shootDay")
            }

            do {
                try moc.save()
                DispatchQueue.main.async { reload() }
            } catch {
                NSLog("Failed to add day break: \(error)")
            }
        }
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
                DispatchQueue.main.async {
                    selectedIDs.removeAll()
                    reload()
                }
            } catch {
                NSLog("Failed to duplicate: \(error)")
            }
        }
    }

    private func deleteSelected() {
        guard !selectedIDs.isEmpty else { return }
        moc.perform {
            let toDelete = scenes.filter { selectedIDs.contains($0.objectID) }
            toDelete.forEach { moc.delete($0) }
            do {
                try moc.save()
                DispatchQueue.main.async {
                    selectedIDs.removeAll()
                    reload()
                }
            } catch {
                NSLog("Failed to delete: \(error)")
            }
        }
    }

    private func exportPDF() {
        NSLog("[Scheduler] Export PDF")
    }

    private func exportCSV() {
        NSLog("[Scheduler] Export CSV")
    }

    private func generateDOOD() {
        NSLog("[Scheduler] Generate Day-out-of-Days")
    }

    // MARK: - Utilities

    fileprivate func firstString(_ scene: NSManagedObject, keys: [String]) -> String? {
        for k in keys {
            if scene.entity.attributesByName.keys.contains(k),
               let s = scene.value(forKey: k) as? String {
                let t = s.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { return t }
            }
        }
        return nil
    }

    private func pageLengthString(_ scene: NSManagedObject) -> String {
        if let eighths = (scene.value(forKey: "pageEighths") as? NSNumber)?.intValue {
            return formatEighths(eighths)
        }
        return "—"
    }

    private func formatEighths(_ v: Int) -> String {
        guard v > 0 else { return "0" }
        let whole = v / 8
        let rem = v % 8
        if whole == 0 { return "\(rem)/8" }
        if rem == 0 { return "\(whole)" }
        return "\(whole) \(rem)/8"
    }
}

// MARK: - Supporting Views

private struct SchedulerFilterChip: View {
    let title: String
    let icon: String
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isSelected.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(uiColor: .tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SchedulerStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CompactBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .textCase(.uppercase)
    }
}

private struct InspectorButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

#endif
