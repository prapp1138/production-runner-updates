import SwiftUI
import CoreData

struct CameraNotesViewer: View {
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

            // Right: Camera notes display
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
                    Text("\(scenesWithCameraNotes.count) with notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        .fill(controlBackgroundColor)
                )
            }
            .padding(12)
            .background(controlBackgroundColor)

            Divider()

            // Scene list
            List(selection: $selectedSceneNumber) {
                ForEach(filteredScenes) { scene in
                    CameraSceneRow(scene: scene, isSelected: selectedSceneNumber == scene.number)
                        .tag(scene.number ?? "")
                }
            }
            .listStyle(.plain)
        }
        .background(textBackgroundColor)
    }

    // MARK: - Notes Panel

    @ViewBuilder
    private var notesPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundStyle(.red)
                Text("Camera Notes")
                    .font(.headline)
                Spacer()
            }
            .padding(16)
            .background(controlBackgroundColor)

            Divider()

            // Content
            if let sceneNumber = selectedSceneNumber,
               let scene = scenes.first(where: { $0.number == sceneNumber }) {
                cameraNotesContent(for: scene)
            } else {
                EmptyStateView(
                    "Select a Scene",
                    systemImage: "camera.fill",
                    description: "Choose a scene to view camera notes"
                )
            }
        }
        .background(textBackgroundColor)
    }

    @ViewBuilder
    private func cameraNotesContent(for scene: SceneEntity) -> some View {
        let shots = (scene.shots as? Set<ShotEntity>)?.sorted { $0.index < $1.index } ?? []

        if shots.isEmpty {
            EmptyStateView(
                "No Shots",
                systemImage: "video.slash",
                description: "Add shots to this scene in Shot List"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(shots) { shot in
                        CameraShotCard(shot: shot, sceneNumber: scene.number ?? "")
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Helpers

    private var filteredScenes: [SceneEntity] {
        let scenesArray = Array(scenes)
        if searchText.isEmpty {
            return scenesArray
        }
        return scenesArray.filter { scene in
            (scene.number ?? "").localizedCaseInsensitiveContains(searchText) ||
            (scene.sceneSlug ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var scenesWithCameraNotes: [SceneEntity] {
        scenes.filter { scene in
            let shots = (scene.shots as? Set<ShotEntity>) ?? []
            return shots.contains { shot in
                (shot.cam != nil && !shot.cam!.isEmpty) ||
                (shot.lens != nil && !shot.lens!.isEmpty) ||
                (shot.rig != nil && !shot.rig!.isEmpty) ||
                (shot.lightingNotes != nil && !shot.lightingNotes!.isEmpty)
            }
        }
    }

    // MARK: - Cross-Platform Colors

    private var controlBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    private var textBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}

// MARK: - Camera Scene Row

struct CameraSceneRow: View {
    let scene: SceneEntity
    let isSelected: Bool

    private var shotCount: Int {
        (scene.shots as? Set<ShotEntity>)?.count ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(scene.number ?? "—")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(scene.sceneSlug ?? "Scene")
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(shotCount) shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Camera Shot Card

struct CameraShotCard: View {
    let shot: ShotEntity
    let sceneNumber: String

    private var controlBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(sceneNumber)-\(shot.code ?? "")")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)

                if let type = shot.type {
                    Text(type)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                        .foregroundStyle(.blue)
                }

                Spacer()
            }

            // Description
            if let description = shot.descriptionText, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Camera details grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                CameraDetailItem(label: "Camera", value: shot.cam, icon: "camera.fill")
                CameraDetailItem(label: "Lens", value: shot.lens, icon: "circle.circle")
                CameraDetailItem(label: "Focal Length", value: shot.focalLength, icon: "ruler")
                CameraDetailItem(label: "Rig/Movement", value: shot.rig, icon: "arrow.up.and.down.and.arrow.left.and.right")
            }

            // Lighting notes
            if let lightingNotes = shot.lightingNotes, !lightingNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Lighting Notes", systemImage: "lightbulb.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.yellow)
                    Text(lightingNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            // General notes
            if let notes = shot.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes", systemImage: "note.text")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(controlBackgroundColor)
        )
    }
}

struct CameraDetailItem: View {
    let label: String
    let value: String?
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value ?? "—")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(value != nil ? .primary : .tertiary)
            }

            Spacer()
        }
    }
}

#Preview {
    CameraNotesViewer()
}
