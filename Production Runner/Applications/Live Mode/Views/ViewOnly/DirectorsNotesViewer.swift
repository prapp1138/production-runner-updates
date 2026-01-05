import SwiftUI
import CoreData

// MARK: - Scene Note Model

struct SceneNote: Identifiable, Codable {
    let id: UUID
    var sceneNumber: String
    var category: NoteCategory
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), sceneNumber: String, category: NoteCategory, content: String) {
        self.id = id
        self.sceneNumber = sceneNumber
        self.category = category
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum NoteCategory: String, Codable, CaseIterable, Identifiable {
        case performance = "Performance"
        case blocking = "Blocking"
        case camera = "Camera"
        case lighting = "Lighting"
        case sound = "Sound"
        case props = "Props"
        case general = "General"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .performance: return "person.fill"
            case .blocking: return "arrow.up.and.down.and.arrow.left.and.right"
            case .camera: return "camera.fill"
            case .lighting: return "lightbulb.fill"
            case .sound: return "waveform"
            case .props: return "cube.fill"
            case .general: return "note.text"
            }
        }

        var color: Color {
            switch self {
            case .performance: return .purple
            case .blocking: return .blue
            case .camera: return .red
            case .lighting: return .yellow
            case .sound: return .green
            case .props: return .orange
            case .general: return .gray
            }
        }
    }
}

// MARK: - Director Notes Store

class DirectorNotesStore: ObservableObject {
    static let shared = DirectorNotesStore()

    @Published private var notes: [UUID: [SceneNote]] = [:] // scriptID -> notes

    private init() {}

    func getNotes(for scriptID: UUID, sceneNumber: String) -> [SceneNote] {
        return notes[scriptID]?.filter { $0.sceneNumber == sceneNumber } ?? []
    }

    func noteCount(for scriptID: UUID, sceneNumber: String) -> Int {
        return getNotes(for: scriptID, sceneNumber: sceneNumber).count
    }

    func addNote(_ note: SceneNote, for scriptID: UUID) {
        if notes[scriptID] == nil {
            notes[scriptID] = []
        }
        notes[scriptID]?.append(note)
    }

    func removeNote(_ noteID: UUID, from scriptID: UUID) {
        notes[scriptID]?.removeAll { $0.id == noteID }
    }
}

// MARK: - Directors Notes Viewer

struct DirectorsNotesViewer: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var notesStore = DirectorNotesStore.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SceneEntity.sortIndex, ascending: true)],
        animation: .default
    )
    private var scenes: FetchedResults<SceneEntity>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ScreenplayDraftEntity.updatedAt, ascending: false)],
        predicate: nil,
        animation: .default
    )
    private var drafts: FetchedResults<ScreenplayDraftEntity>

    @State private var selectedSceneNumber: String?
    @State private var searchText: String = ""
    @State private var filterCategory: SceneNote.NoteCategory?

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Left: Scene list with note counts
            sceneListPanel
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)

            // Right: Notes display
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

    // MARK: - Scene List Panel

    @ViewBuilder
    private var sceneListPanel: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 12) {
                HStack {
                    Text("Scenes")
                        .font(.headline)
                    Spacer()
                    Text("\(scenesWithNotes.count) with notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search scenes...", text: $searchText)
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
            if scenes.isEmpty {
                EmptyStateView(
                    "No Scenes",
                    systemImage: "doc.text",
                    description: "Import a screenplay to view director's notes"
                )
            } else {
                List(selection: $selectedSceneNumber) {
                    ForEach(filteredScenes) { scene in
                        SceneNoteListRow(
                            scene: scene,
                            noteCount: noteCount(for: scene),
                            isSelected: selectedSceneNumber == scene.number
                        )
                        .tag(scene.number ?? "")
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(textBackgroundColor)
    }

    // MARK: - Notes Panel

    @ViewBuilder
    private var notesPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let sceneNumber = selectedSceneNumber,
                   let scene = scenes.first(where: { $0.number == sceneNumber }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scene \(sceneNumber)")
                            .font(.headline)
                        if let slug = scene.sceneSlug {
                            Text(slug)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Director's Notes")
                        .font(.headline)
                }

                Spacer()

                // Category filter
                Picker("Filter", selection: $filterCategory) {
                    Text("All Categories").tag(nil as SceneNote.NoteCategory?)
                    Divider()
                    ForEach(SceneNote.NoteCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category as SceneNote.NoteCategory?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
            .padding(16)
            .background(controlBackgroundColor)

            Divider()

            // Notes content
            if let sceneNumber = selectedSceneNumber {
                notesContent(for: sceneNumber)
            } else {
                EmptyStateView(
                    "Select a Scene",
                    systemImage: "hand.tap",
                    description: "Choose a scene to view its director's notes"
                )
            }
        }
        .background(textBackgroundColor)
    }

    @ViewBuilder
    private func notesContent(for sceneNumber: String) -> some View {
        let notes = getNotesForScene(sceneNumber)
        let filteredNotes = filterCategory == nil ? notes : notes.filter { $0.category == filterCategory }

        if filteredNotes.isEmpty {
            EmptyStateView(
                "No Notes",
                systemImage: "note.text",
                description: "No director's notes for this scene"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredNotes) { note in
                        NoteCard(note: note)
                    }
                }
                .padding(16)
            }
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

    private var scenesWithNotes: [SceneEntity] {
        scenes.filter { noteCount(for: $0) > 0 }
    }

    private func noteCount(for scene: SceneEntity) -> Int {
        guard let scriptID = drafts.first?.id,
              let sceneNumber = scene.number else { return 0 }
        return notesStore.noteCount(for: scriptID, sceneNumber: sceneNumber)
    }

    private func getNotesForScene(_ sceneNumber: String) -> [SceneNote] {
        guard let scriptID = drafts.first?.id else { return [] }
        return notesStore.getNotes(for: scriptID, sceneNumber: sceneNumber)
    }
}

// MARK: - Scene Note List Row

struct SceneNoteListRow: View {
    let scene: SceneEntity
    let noteCount: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Scene number
            Text(scene.number ?? "—")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.indigo)
                .frame(width: 40, alignment: .leading)

            // Scene info
            VStack(alignment: .leading, spacing: 2) {
                Text(scene.sceneSlug ?? "Scene")
                    .font(.subheadline)
                    .lineLimit(1)

                if let pageEighths = scene.pageEighthsString {
                    Text(pageEighths)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Note count badge
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.indigo)
                    )
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Note Card

struct NoteCard: View {
    let note: SceneNote

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
                Label(note.category.rawValue, systemImage: note.category.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(note.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(note.category.color.opacity(0.15))
                    )

                Spacer()

                Text(note.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Content
            Text(note.content)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(controlBackgroundColor)
        )
    }
}

#Preview {
    DirectorsNotesViewer()
}
