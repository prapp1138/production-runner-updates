import SwiftUI
import CoreData

struct ProjectNotesViewer: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \IdeaSectionEntity.sortOrder, ascending: true)],
        animation: .default
    )
    private var sections: FetchedResults<IdeaSectionEntity>

    @State private var selectedSectionID: UUID?
    @State private var searchText: String = ""

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Left: Section list
            sectionListPanel
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)

            // Right: Notes display
            notesPanel
                .frame(minWidth: 400)
        }
        #else
        NavigationSplitView {
            sectionListPanel
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

    // MARK: - Section List Panel

    @ViewBuilder
    private var sectionListPanel: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Sections")
                        .font(.headline)
                    Spacer()
                    Text("\(totalNoteCount) notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search notes...", text: $searchText)
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

            // Section list
            if sections.isEmpty {
                EmptyStateView(
                    "No Sections",
                    systemImage: "folder",
                    description: "Create note sections in the Ideas app"
                )
            } else {
                List(selection: $selectedSectionID) {
                    ForEach(sections) { section in
                        ProjectSectionRow(
                            section: section,
                            isSelected: selectedSectionID == section.id
                        )
                        .tag(section.id)
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
                Image(systemName: "note.text")
                    .foregroundStyle(.brown)
                Text("Project Notes")
                    .font(.headline)

                Spacer()

                if !searchText.isEmpty {
                    Text("\(filteredNotes.count) results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(controlBackgroundColor)

            Divider()

            // Content
            if !searchText.isEmpty {
                // Show search results
                searchResultsView
            } else if let sectionID = selectedSectionID,
                      let section = sections.first(where: { $0.id == sectionID }) {
                sectionNotesContent(for: section)
            } else {
                EmptyStateView(
                    "Select a Section",
                    systemImage: "folder",
                    description: "Choose a section to view its notes"
                )
            }
        }
        .background(textBackgroundColor)
    }

    @ViewBuilder
    private func sectionNotesContent(for section: IdeaSectionEntity) -> some View {
        let notes = (section.notes as? Set<IdeaNoteEntity>)?.sorted {
            $0.sortOrder < $1.sortOrder
        } ?? []

        if notes.isEmpty {
            EmptyStateView(
                "No Notes",
                systemImage: "note.text",
                description: "This section has no notes"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(notes) { note in
                        ProjectNoteCard(note: note)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        if filteredNotes.isEmpty {
            EmptyStateView(
                "No Results",
                systemImage: "magnifyingglass",
                description: "No notes match your search"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredNotes) { note in
                        ProjectNoteCard(note: note, showSection: true)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Helpers

    private var totalNoteCount: Int {
        sections.reduce(0) { total, section in
            total + ((section.notes as? Set<IdeaNoteEntity>)?.count ?? 0)
        }
    }

    private var allNotes: [IdeaNoteEntity] {
        sections.flatMap { section in
            (section.notes as? Set<IdeaNoteEntity>) ?? []
        }
    }

    private var filteredNotes: [IdeaNoteEntity] {
        guard !searchText.isEmpty else { return [] }
        return allNotes.filter { note in
            (note.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            (note.content ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Project Section Row

struct ProjectSectionRow: View {
    let section: IdeaSectionEntity
    let isSelected: Bool

    private var noteCount: Int {
        (section.notes as? Set<IdeaNoteEntity>)?.count ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.brown)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.name ?? "Untitled Section")
                    .font(.subheadline.weight(.medium))
                Text("\(noteCount) notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.brown)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Note Card

struct ProjectNoteCard: View {
    let note: IdeaNoteEntity
    var showSection: Bool = false

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
                Text(note.title ?? "Untitled")
                    .font(.headline)

                Spacer()

                Text(note.updatedAt ?? Date(), style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Section badge (in search results)
            if showSection, let section = note.section {
                Label(section.name ?? "Section", systemImage: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.brown)
            }

            // Content
            if let content = note.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(10)
            } else {
                Text("No content")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
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
    ProjectNotesViewer()
}
