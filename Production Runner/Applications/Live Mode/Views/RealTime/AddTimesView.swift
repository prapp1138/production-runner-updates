import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct AddTimesView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: LiveModeStore

    @State private var showingAddEntry: Bool = false
    @State private var selectedCategory: TimeEntryCategory = .crewCall
    @State private var entryTime: Date = Date()
    @State private var entryNotes: String = ""

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Left: Quick entry panel
            quickEntryPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)

            // Right: Today's timeline
            timelinePanel
                .frame(minWidth: 400)
        }
        #else
        NavigationSplitView {
            quickEntryPanel
        } detail: {
            timelinePanel
        }
        #endif
    }

    // MARK: - Quick Entry Panel

    @ViewBuilder
    private var quickEntryPanel: some View {
        VStack(spacing: 0) {
            // Header with current time
            VStack(spacing: 8) {
                Text(store.currentTimeString)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)

                if let dayNumber = store.currentShootDay {
                    Text("Shoot Day \(dayNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Quick time buttons
            ScrollView {
                VStack(spacing: 12) {
                    Text("Log Time")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        ForEach(TimeEntryCategory.allCases.filter { $0 != .custom }.sorted { $0.sortOrder < $1.sortOrder }) { category in
                            QuickTimeButton(
                                category: category,
                                isLogged: isTimeLogged(for: category),
                                loggedTime: loggedTime(for: category)
                            ) {
                                logTime(for: category)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.vertical, 12)

                    // Custom entry button
                    Button {
                        showingAddEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Custom Entry")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 20)
                }
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .sheet(isPresented: $showingAddEntry) {
            CustomTimeEntrySheet(
                isPresented: $showingAddEntry,
                onSave: { entry in
                    store.addTimeEntry(entry)
                }
            )
        }
    }

    // MARK: - Timeline Panel

    @ViewBuilder
    private var timelinePanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Today's Timeline")
                    .font(.headline)

                Spacer()

                if !store.todayTimeEntries.isEmpty {
                    Text("\(store.todayTimeEntries.count) entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Timeline
            if store.todayTimeEntries.isEmpty {
                EmptyStateView(
                    "No Times Logged",
                    systemImage: "clock",
                    description: "Use the quick buttons to log production times"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.todayTimeEntries.sorted { $0.startTime < $1.startTime }) { entry in
                            TimelineEntryRow(entry: entry) {
                                store.removeTimeEntry(entry)
                            }
                        }
                    }
                    .padding(16)
                }
            }

            Divider()

            // Summary footer
            summaryFooter
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    // MARK: - Summary Footer

    @ViewBuilder
    private var summaryFooter: some View {
        HStack(spacing: 24) {
            // Total hours
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1fh", store.totalWorkingHours))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
            }

            Divider()
                .frame(height: 30)

            // Meal break
            VStack(alignment: .leading, spacing: 2) {
                Text("Meal Break")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0fm", store.totalMealBreakTime))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
            }

            Spacer()

            // Export button
            Button {
                exportTimesToCSV()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(store.todayTimeEntries.isEmpty)
        }
        .padding(16)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

    // MARK: - Helpers

    private func isTimeLogged(for category: TimeEntryCategory) -> Bool {
        store.todayTimeEntries.contains { $0.category == category }
    }

    private func loggedTime(for category: TimeEntryCategory) -> String? {
        store.todayTimeEntries.first { $0.category == category }?.formattedStartTime
    }

    private func exportTimesToCSV() {
        let csvContent = generateCSV(from: store.todayTimeEntries)

        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "time_entries_\(Date().ISO8601Format()).csv"
        savePanel.message = "Choose where to save the time entries"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                    print("[Export] Time entries exported successfully to: \(url.path)")
                } catch {
                    print("[Export] Failed to write CSV: \(error)")
                }
            }
        }
        #else
        // iOS: Use share sheet
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("time_entries.csv")
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        } catch {
            print("[Export] Failed to create CSV: \(error)")
        }
        #endif
    }

    private func generateCSV(from entries: [TimeEntry]) -> String {
        var csv = "Category,Start Time,End Time,Duration (minutes),Notes\n"

        let sortedEntries = entries.sorted { $0.startTime < $1.startTime }

        for entry in sortedEntries {
            let category = entry.category.rawValue.replacingOccurrences(of: ",", with: ";")
            let startTime = ISO8601DateFormatter().string(from: entry.startTime)
            let endTime = entry.endTime != nil ? ISO8601DateFormatter().string(from: entry.endTime!) : "Ongoing"

            let duration: String
            if let end = entry.endTime {
                let diff = end.timeIntervalSince(entry.startTime) / 60.0
                duration = String(format: "%.0f", diff)
            } else {
                duration = "N/A"
            }

            let notes = (entry.notes ?? "").replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")

            let row = "\(category),\(startTime),\(endTime),\(duration),\(notes)\n"
            csv += row
        }

        return csv
    }

    private func logTime(for category: TimeEntryCategory) {
        let entry = TimeEntry(
            id: UUID(),
            category: category,
            startTime: Date(),
            endTime: nil,
            notes: nil
        )
        store.addTimeEntry(entry)
    }
}

// MARK: - Quick Time Button

struct QuickTimeButton: View {
    let category: TimeEntryCategory
    let isLogged: Bool
    let loggedTime: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isLogged ? category.color.opacity(0.15) : Color.clear)
                        .frame(width: 44, height: 44)

                    Image(systemName: isLogged ? "checkmark.circle.fill" : category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isLogged ? .green : category.color)
                }

                VStack(spacing: 2) {
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isLogged ? .primary : .secondary)
                        .lineLimit(1)

                    if let time = loggedTime {
                        Text(time)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(category.color)
                    } else {
                        Text("Tap to log")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    #if os(macOS)
                    .fill(isLogged ? category.color.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
                    #else
                    .fill(isLogged ? category.color.opacity(0.05) : Color(uiColor: .secondarySystemBackground))
                    #endif
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isLogged ? category.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLogged)
    }
}

// MARK: - Timeline Entry Row

struct TimelineEntryRow: View {
    let entry: TimeEntry
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Time indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(entry.category.color)
                    .frame(width: 12, height: 12)

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.category.rawValue)
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text(entry.formattedStartTime)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(entry.category.color)
                }

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Delete button (on hover)
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Custom Time Entry Sheet

struct CustomTimeEntrySheet: View {
    @Binding var isPresented: Bool
    let onSave: (TimeEntry) -> Void

    @State private var selectedCategory: TimeEntryCategory = .custom
    @State private var entryTime: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Custom Time Entry")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(TimeEntryCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }

                DatePicker("Time", selection: $entryTime, displayedComponents: .hourAndMinute)

                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3)
            }
            .formStyle(.grouped)
            .frame(minHeight: 200)

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    let entry = TimeEntry(
                        id: UUID(),
                        category: selectedCategory,
                        startTime: entryTime,
                        endTime: nil,
                        notes: notes.isEmpty ? nil : notes
                    )
                    onSave(entry)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}

#Preview {
    AddTimesView()
        .environmentObject(LiveModeStore())
}
