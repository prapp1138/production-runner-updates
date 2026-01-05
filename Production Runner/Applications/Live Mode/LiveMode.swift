import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Live Mode View
struct LiveMode: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var store = LiveModeStore()

    @State private var selectedCategory: LiveModeCategory = .realTime
    @State private var selectedSection: LiveModeSection = .digitalCallSheetShotList

    var body: some View {
        VStack(spacing: 0) {
            // Category tabs toolbar
            categoryTabs
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                #if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
                #else
                .background(Color(uiColor: .secondarySystemBackground))
                #endif

            Divider()

            // Main content with sidebar
            #if os(macOS)
            HSplitView {
                // Left sidebar: Section list
                sidebarView
                    .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)

                // Main content area
                contentView
                    .frame(minWidth: 500)
            }
            #else
            NavigationSplitView {
                sidebarView
            } detail: {
                contentView
            }
            #endif
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                liveModeIndicator
            }
        }
        .navigationTitle("Live Mode")
        .environmentObject(store)
    }

    // MARK: - Sidebar View
    @ViewBuilder
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Section list for selected category
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(LiveModeSection.sections(for: selectedCategory)) { section in
                        LiveModeSectionTile(
                            section: section,
                            isSelected: section == selectedSection
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSection = section
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: .infinity)

            // Live status footer
            liveStatusFooter
        }
        .frame(maxHeight: .infinity)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

    // MARK: - Category Tabs
    @ViewBuilder
    private var categoryTabs: some View {
        HStack(spacing: 4) {
            ForEach(LiveModeCategory.allCases) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                        // Select first section of new category
                        if let firstSection = LiveModeSection.sections(for: category).first {
                            selectedSection = firstSection
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedCategory == category
                                  ? category.color.opacity(0.15)
                                  : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                selectedCategory == category
                                    ? category.color.opacity(0.5)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .foregroundStyle(selectedCategory == category ? category.color : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Read-only banner for view-only sections
            if selectedSection.isReadOnly {
                readOnlyBanner
            }

            // Section content
            sectionContent
        }
    }

    // MARK: - Section Content
    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        // Real Time
        case .digitalCallSheetShotList:
            DigitalCallSheetShotListView()
        case .dayByDayBudget:
            DayByDayBudgetView()
        case .addTimes:
            AddTimesView()
        case .teleprompter:
            TeleprompterView()

        // View Only
        case .directorsNotes:
            DirectorsNotesViewer()
        case .storyboard:
            StoryboardViewer()
        case .scriptSupervising:
            ScriptSupervisingViewer()
        case .cameraNotes:
            CameraNotesViewer()
        case .soundNotes:
            SoundNotesViewer()
        case .projectNotes:
            ProjectNotesViewer()

        // New Apps
        case .wrapReport:
            WrapReportView()
        case .productionReport:
            ProductionReportView()
        case .signatures:
            SignaturesView()
        }
    }

    // MARK: - Read Only Banner
    @ViewBuilder
    private var readOnlyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 12))
            Text("View Only")
                .font(.system(size: 12, weight: .medium))
            Text("—")
                .foregroundStyle(.tertiary)
            Text("Edit in the full app")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.orange)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Live Mode Indicator
    @ViewBuilder
    private var liveModeIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 14, height: 14)
                )

            Text("LIVE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.1))
        )
    }

    // MARK: - Live Status Footer
    @ViewBuilder
    private var liveStatusFooter: some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 12) {
                // Current time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(store.currentTimeString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.secondary)

                Spacer()

                // Shoot day indicator
                if let dayNumber = store.currentShootDay {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text("Day \(dayNumber)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }
}

// MARK: - Section Tile
struct LiveModeSectionTile: View {
    let section: LiveModeSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? section.color.opacity(0.15) : Color.clear)
                        .frame(width: 32, height: 32)

                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? section.color : .secondary)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)

                    if isSelected {
                        Text(section.description)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Read-only indicator
                if section.isReadOnly {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                // Chevron
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(section.color.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                            ? section.color.opacity(0.08)
                            : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? section.color.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Note: Real Time views are in Views/RealTime/
// - DigitalCallSheetShotListView.swift
// - DayByDayBudgetView.swift
// - AddTimesView.swift
// - TeleprompterView.swift

// Note: View Only wrappers are in Views/ViewOnly/
// - DirectorsNotesViewer.swift
// - StoryboardViewer.swift
// - ScriptSupervisingViewer.swift
// - CameraNotesViewer.swift
// - SoundNotesViewer.swift
// - ProjectNotesViewer.swift

// Note: New Apps are in Views/NewApps/
// - WrapReportView.swift
// - ProductionReportView.swift
// - SignaturesView.swift

// MARK: - Placeholder View
struct LiveModePlaceholder: View {
    let section: LiveModeSection
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(section.color.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: section.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(section.color)
            }

            VStack(spacing: 8) {
                Text(section.rawValue)
                    .font(.title2.bold())

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if section.isReadOnly {
                Label("View Only", systemImage: "eye.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.1))
                    )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }
}

#Preview {
    LiveMode()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
