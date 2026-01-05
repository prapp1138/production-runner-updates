import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct SoundNotesViewer: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SceneEntity.sortIndex, ascending: true)],
        animation: .default
    )
    private var scenes: FetchedResults<SceneEntity>

    @State private var selectedSceneNumber: String?
    @State private var searchText: String = ""

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Left: Scene list
            sceneListPanel
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)

            // Right: Sound notes display
            notesPanel
                .frame(minWidth: 400)
        }
        #else
        NavigationSplitView {
            sceneListPanel
        } detail: {
            notesPanel
        }
        #endif
    }

    // MARK: - Scene List Panel

    @ViewBuilder
    private var sceneListPanel: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Scenes")
                        .font(.headline)
                    Spacer()
                }

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        #if os(macOS)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        #else
                        .fill(Color(uiColor: .secondarySystemBackground))
                        #endif
                )
            }
            .padding(12)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Scene list
            List(selection: $selectedSceneNumber) {
                ForEach(filteredScenes) { scene in
                    SoundSceneRow(scene: scene, isSelected: selectedSceneNumber == scene.number)
                        .tag(scene.number ?? "")
                }
            }
            .listStyle(.plain)
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    // MARK: - Notes Panel

    @ViewBuilder
    private var notesPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.teal)
                Text("Sound Notes")
                    .font(.headline)
                Spacer()
            }
            .padding(16)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Content
            if let sceneNumber = selectedSceneNumber,
               let scene = scenes.first(where: { $0.number == sceneNumber }) {
                soundNotesContent(for: scene)
            } else {
                EmptyStateView(
                    "Select a Scene",
                    systemImage: "waveform",
                    description: "Choose a scene to view sound notes"
                )
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    @ViewBuilder
    private func soundNotesContent(for scene: SceneEntity) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Scene info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scene \(scene.number ?? "—")")
                        .font(.title2.bold())
                    if let slug = scene.sceneSlug {
                        Text(slug)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Location type (affects sound)
                if let locationType = scene.locationType {
                    SoundInfoCard(
                        title: "Location Type",
                        value: locationType,
                        icon: locationType.lowercased().contains("int") ? "building.fill" : "sun.max.fill",
                        color: locationType.lowercased().contains("int") ? .blue : .orange,
                        note: locationType.lowercased().contains("int") ?
                            "Interior - Controlled sound environment" :
                            "Exterior - Consider ambient noise"
                    )
                }

                // Time of day (affects ambient sound)
                if let timeOfDay = scene.timeOfDay {
                    SoundInfoCard(
                        title: "Time of Day",
                        value: timeOfDay,
                        icon: timeOfDay.lowercased().contains("night") ? "moon.fill" : "sun.max.fill",
                        color: timeOfDay.lowercased().contains("night") ? .indigo : .yellow,
                        note: nil
                    )
                }

                // Dialogue info from script
                if let scriptText = scene.scriptText {
                    let hasDialogue = scriptText.contains("(") || scriptText.count > 100
                    SoundInfoCard(
                        title: "Dialogue",
                        value: hasDialogue ? "Contains dialogue" : "Minimal/No dialogue",
                        icon: hasDialogue ? "person.wave.2.fill" : "speaker.slash.fill",
                        color: hasDialogue ? .green : .gray,
                        note: hasDialogue ? "Plan for boom/lav mic coverage" : nil
                    )
                }

                // Sound effects from breakdown
                if let breakdown = scene.breakdown,
                   let soundfx = breakdown.soundfx,
                   !soundfx.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Sound Effects", systemImage: "speaker.wave.3.fill")
                            .font(.headline)
                            .foregroundStyle(.teal)

                        Text(soundfx)
                            .font(.subheadline)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    #if os(macOS)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    #else
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    #endif
                            )
                    }
                }

                // Placeholder for sound notes
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sound Department Notes", systemImage: "note.text")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Sound notes for this scene will appear here when added in the full app.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                }
            }
            .padding(20)
        }
    }

    // MARK: - Helpers

    private var filteredScenes: [SceneEntity] {
        if searchText.isEmpty {
            return Array(scenes)
        }
        return scenes.filter { scene in
            (scene.number ?? "").localizedCaseInsensitiveContains(searchText) ||
            (scene.sceneSlug ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Sound Scene Row

struct SoundSceneRow: View {
    let scene: SceneEntity
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(scene.number ?? "—")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.teal)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(scene.sceneSlug ?? "Scene")
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let locationType = scene.locationType {
                        Text(locationType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let timeOfDay = scene.timeOfDay {
                        Text("• \(timeOfDay)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sound Info Card

struct SoundInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let note: String?

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))

                if let note = note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }
}

#Preview {
    SoundNotesViewer()
}
