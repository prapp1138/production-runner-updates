import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#endif

#if os(macOS)
// MARK: - Plan Tab
enum PlanTab: String, CaseIterable {
    case checklist = "Checklist"
    case characters = "Characters"
    case casting = "Casting"
    case crew = "Crew"
    case locations = "Locations"
    case schedule = "Schedule"
    case create = "Create"

    var icon: String {
        switch self {
        case .checklist: return "checklist"
        case .characters: return "theatermasks.fill"
        case .casting: return "person.2.fill"
        case .crew: return "person.3.fill"
        case .locations: return "mappin.and.ellipse"
        case .schedule: return "calendar"
        case .create: return "rectangle.on.rectangle.angled"
        }
    }

    var color: Color {
        switch self {
        case .checklist: return .yellow
        case .characters: return .purple
        case .casting: return .blue
        case .crew: return .green
        case .locations: return .orange
        case .schedule: return .cyan
        case .create: return .teal
        }
    }
}

// MARK: - Plan View (macOS)
struct PlanView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: PlanTab = .checklist
    @State private var planItems: [PlanItem] = []
    @State private var newItemTitle: String = ""
    @State private var showingAddSheet: Bool = false
    @State private var selectedItem: PlanItem?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            planToolbar

            Divider()

            // Content based on selected tab
            selectedTabContent
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPlanItemSheet(isPresented: $showingAddSheet) { title, description, dueDate, priority in
                addItem(title: title, description: description, dueDate: dueDate, priority: priority)
            }
        }
        #if os(macOS)
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
        #endif
    }

    // MARK: - Global Keyboard Shortcut Handlers
    #if os(macOS)
    private func performDeleteCommand() {
        // Check if text field has focus - let system handle delete
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text delete
            }
        }
        // Delete selected item
        guard let item = selectedItem else { return }
        planItems.removeAll { $0.id == item.id }
        selectedItem = nil
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
        // No clipboard support for plan items yet
    }

    private func performCopyCommand() {
        // Check if text field has focus - let system handle copy
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text copy
            }
        }
        // No clipboard support for plan items yet
    }

    private func performPasteCommand() {
        // Check if text field has focus - let system handle paste
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text paste
            }
        }
        // No clipboard support for plan items yet
    }
    #endif

    // MARK: - Toolbar
    private var planToolbar: some View {
        HStack(spacing: 16) {
            // Tab selector
            HStack(spacing: 4) {
                ForEach(PlanTab.allCases, id: \.self) { tab in
                    planTabButton(tab)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.02))
    }

    private func planTabButton(_ tab: PlanTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tab.color)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .checklist:
            ChecklistTabView()
        case .characters:
            CharactersTabView()
        case .casting:
            CastingTabView()
        case .crew:
            CrewTabView()
        case .locations:
            LocationsTabView()
        case .schedule:
            ScheduleTabView()
        case .create:
            CreateTabView()
        }
    }

    private func addItem(title: String, description: String, dueDate: Date?, priority: PlanItem.Priority) {
        let item = PlanItem(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority
        )
        planItems.append(item)
    }

    private func toggleItem(_ item: PlanItem) {
        if let index = planItems.firstIndex(where: { $0.id == item.id }) {
            planItems[index].isCompleted.toggle()
        }
    }

    private func deleteItem(_ item: PlanItem) {
        planItems.removeAll { $0.id == item.id }
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
    }
}

// MARK: - Checklist Tab View
struct ChecklistTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \IdeaSectionEntity.sortOrder, ascending: true)],
        animation: .default
    )
    private var sectionEntities: FetchedResults<IdeaSectionEntity>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \IdeaNoteEntity.sortOrder, ascending: true)],
        animation: .default
    )
    private var noteEntities: FetchedResults<IdeaNoteEntity>

    @State private var selectedNoteID: UUID?
    @State private var showingAddSection = false
    @State private var newSectionName = ""

    var body: some View {
        HSplitView {
            // Sidebar with sections and notes
            sidebarView
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            // Note editor
            noteEditorView
                .frame(minWidth: 300)
        }
        .onAppear {
            createDefaultSectionIfNeeded()
        }
    }

    private func createDefaultSectionIfNeeded() {
        if sectionEntities.isEmpty {
            // Create Pre-Production section with checklist items
            let preProduction = IdeaSectionEntity(context: viewContext)
            preProduction.id = UUID()
            preProduction.name = "Pre-Production"
            preProduction.isExpanded = true
            preProduction.sortOrder = 0
            preProduction.createdAt = Date()

            let preProductionItems = [
                ("Finalize Script", "Lock the shooting script and distribute to all departments"),
                ("Budget Breakdown", "Create detailed budget with line items for all departments"),
                ("Hire Key Crew", "Director, DP, Production Designer, 1st AD, Line Producer"),
                ("Location Scouting", "Scout and secure all filming locations with permits"),
                ("Casting", "Complete auditions and finalize cast contracts"),
                ("Create Shot List", "Work with director and DP on shot list and storyboards"),
                ("Schedule Creation", "Build shooting schedule with 1st AD"),
                ("Equipment Rental", "Book cameras, lighting, grip, and sound equipment"),
                ("Insurance & Legal", "Production insurance, contracts, releases, and permits"),
                ("Catering & Craft Services", "Arrange meals and craft services for all shoot days")
            ]

            for (index, item) in preProductionItems.enumerated() {
                let note = IdeaNoteEntity(context: viewContext)
                note.id = UUID()
                note.title = item.0
                note.content = item.1
                note.sortOrder = Int32(index)
                note.createdAt = Date()
                note.updatedAt = Date()
                note.section = preProduction
            }

            // Create Production section
            let production = IdeaSectionEntity(context: viewContext)
            production.id = UUID()
            production.name = "Production"
            production.isExpanded = true
            production.sortOrder = 1
            production.createdAt = Date()

            let productionItems = [
                ("Daily Call Sheets", "Distribute call sheets to cast and crew"),
                ("Daily Production Reports", "Complete and file production reports"),
                ("Dailies Review", "Review footage daily with director and editor"),
                ("Continuity Tracking", "Maintain script supervision and continuity notes"),
                ("Media Management", "Backup and organize all footage daily")
            ]

            for (index, item) in productionItems.enumerated() {
                let note = IdeaNoteEntity(context: viewContext)
                note.id = UUID()
                note.title = item.0
                note.content = item.1
                note.sortOrder = Int32(index)
                note.createdAt = Date()
                note.updatedAt = Date()
                note.section = production
            }

            // Create Post-Production section
            let postProduction = IdeaSectionEntity(context: viewContext)
            postProduction.id = UUID()
            postProduction.name = "Post-Production"
            postProduction.isExpanded = true
            postProduction.sortOrder = 2
            postProduction.createdAt = Date()

            let postProductionItems = [
                ("Picture Edit", "Complete rough cut, fine cut, and picture lock"),
                ("Sound Design", "Sound effects, Foley, and ambient audio"),
                ("Music & Score", "Original score composition and licensed music"),
                ("Color Grading", "Color correction and final grade"),
                ("VFX & Graphics", "Visual effects and title graphics"),
                ("Final Mix", "Audio mixing and mastering"),
                ("Deliverables", "Create all required delivery formats")
            ]

            for (index, item) in postProductionItems.enumerated() {
                let note = IdeaNoteEntity(context: viewContext)
                note.id = UUID()
                note.title = item.0
                note.content = item.1
                note.sortOrder = Int32(index)
                note.createdAt = Date()
                note.updatedAt = Date()
                note.section = postProduction
            }

            try? viewContext.save()
        }
    }

    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddSection = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .customTooltip("Add Section")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Sections list
            ScrollView {
                LazyVStack(spacing: 2, pinnedViews: []) {
                    ForEach(sectionEntities) { section in
                        ChecklistSectionRowCD(
                            section: section,
                            notes: noteEntities.filter { $0.section == section },
                            selectedNoteID: $selectedNoteID,
                            onToggleExpand: { toggleSectionExpanded(section) },
                            onAddNote: { addNote(to: section) },
                            onDeleteNote: { deleteNote($0) },
                            onDeleteSection: { deleteSection(section) }
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            // Add section popover
            if showingAddSection {
                VStack(spacing: 12) {
                    Divider()
                    HStack(spacing: 8) {
                        TextField("Section name...", text: $newSectionName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .onSubmit {
                                addSection()
                            }

                        Button(action: addSection) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(newSectionName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color.yellow)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(newSectionName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .customTooltip("Add Section")
                        .allowsHitTesting(!newSectionName.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button {
                            showingAddSection = false
                            newSectionName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Note Editor
    private var noteEditorView: some View {
        VStack(spacing: 0) {
            if let noteID = selectedNoteID,
               let note = noteEntities.first(where: { $0.id == noteID }) {
                // Title field
                TextField("Title", text: Binding(
                    get: { note.title ?? "" },
                    set: { newValue in
                        note.title = newValue
                        note.updatedAt = Date()
                        try? viewContext.save()
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Date
                Text(note.updatedAt ?? Date(), style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

                // Content editor
                TextEditor(text: Binding(
                    get: { note.content ?? "" },
                    set: { newValue in
                        note.content = newValue
                        note.updatedAt = Date()
                        try? viewContext.save()
                    }
                ))
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("Select a note")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)

                    if sectionEntities.isEmpty {
                        Text("Create a section to get started")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Data Management
    private func addSection() {
        let name = newSectionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let section = IdeaSectionEntity(context: viewContext)
        section.id = UUID()
        section.name = name
        section.isExpanded = true
        section.sortOrder = Int32(sectionEntities.count)
        section.createdAt = Date()

        do {
            try viewContext.save()
            newSectionName = ""
            showingAddSection = false
        } catch {
            print("Error saving new section: \(error)")
            // Still reset the form even if save fails
            newSectionName = ""
            showingAddSection = false
        }
    }

    private func deleteSection(_ section: IdeaSectionEntity) {
        // Clear selection if needed
        if let selectedID = selectedNoteID,
           noteEntities.first(where: { $0.id == selectedID })?.section == section {
            selectedNoteID = nil
        }

        viewContext.delete(section)
        try? viewContext.save()
    }

    private func toggleSectionExpanded(_ section: IdeaSectionEntity) {
        section.isExpanded.toggle()
        try? viewContext.save()
    }

    private func addNote(to section: IdeaSectionEntity) {
        let note = IdeaNoteEntity(context: viewContext)
        note.id = UUID()
        note.title = ""
        note.content = ""
        note.sortOrder = Int32(noteEntities.filter { $0.section == section }.count)
        note.createdAt = Date()
        note.updatedAt = Date()
        note.section = section
        try? viewContext.save()
        selectedNoteID = note.id

        // Ensure section is expanded
        if !section.isExpanded {
            section.isExpanded = true
            try? viewContext.save()
        }
    }

    private func deleteNote(_ note: IdeaNoteEntity) {
        if selectedNoteID == note.id {
            selectedNoteID = nil
        }
        viewContext.delete(note)
        try? viewContext.save()
    }
}

// MARK: - Checklist Note Model
struct IdeaNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var sectionID: UUID
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), title: String = "", content: String = "", sectionID: UUID, createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.sectionID = sectionID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Checklist Section Model
struct IdeaSection: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isExpanded: Bool

    init(id: UUID = UUID(), name: String, isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.isExpanded = isExpanded
    }
}

// MARK: - Checklist Section Row
struct ChecklistSectionRow: View {
    let section: IdeaSection
    let notes: [IdeaNote]
    @Binding var selectedNote: IdeaNote?
    let onToggleExpand: () -> Void
    let onAddNote: () -> Void
    let onDeleteNote: (IdeaNote) -> Void
    let onDeleteSection: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Button(action: onToggleExpand) {
                    Image(systemName: section.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)

                Text(section.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text("\(notes.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                if isHovered {
                    Button(action: onAddNote) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Add Note")

                    if notes.isEmpty {
                        Button(action: onDeleteSection) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Delete Section")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }

            // Notes list
            if section.isExpanded {
                ForEach(notes.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { note in
                    ChecklistNoteRow(
                        note: note,
                        isSelected: selectedNote?.id == note.id,
                        onSelect: { selectedNote = note },
                        onDelete: { onDeleteNote(note) }
                    )
                }
            }
        }
    }
}

// MARK: - Checklist Note Row
struct ChecklistNoteRow: View {
    let note: IdeaNote
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Text(note.content.isEmpty ? "No content" : note.content)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.leading, 24)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.yellow.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Checklist Section Row (Core Data)
struct ChecklistSectionRowCD: View {
    @ObservedObject var section: IdeaSectionEntity
    let notes: [IdeaNoteEntity]
    @Binding var selectedNoteID: UUID?
    let onToggleExpand: () -> Void
    let onAddNote: () -> Void
    let onDeleteNote: (IdeaNoteEntity) -> Void
    let onDeleteSection: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Button(action: onToggleExpand) {
                    Image(systemName: section.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)

                Text(section.name ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text("\(notes.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                if isHovered {
                    Button(action: onAddNote) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Add Note")

                    if notes.isEmpty {
                        Button(action: onDeleteSection) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Delete Section")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }

            // Notes list
            if section.isExpanded {
                ForEach(notes.sorted(by: { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) })) { note in
                    ChecklistNoteRowCD(
                        note: note,
                        isSelected: selectedNoteID == note.id,
                        onSelect: { selectedNoteID = note.id },
                        onDelete: { onDeleteNote(note) }
                    )
                }
            }
        }
    }
}

// MARK: - Checklist Note Row (Core Data)
struct ChecklistNoteRowCD: View {
    @ObservedObject var note: IdeaNoteEntity
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text((note.title ?? "").isEmpty ? "Untitled" : (note.title ?? ""))
                    .font(.system(size: 13))
                    .lineLimit(1)

                Text((note.content ?? "").isEmpty ? "No content" : (note.content ?? ""))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.leading, 24)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.yellow.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Casting Actor Model
// Section types for cast/crew organization
enum CastCrewSection: String, CaseIterable {
    case topPicks = "Top Picks"
    case cantGet = "Can't Get"
    case confirmed = "Confirmed"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .topPicks: return "star.fill"
        case .cantGet: return "xmark.circle.fill"
        case .confirmed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .topPicks: return .yellow
        case .cantGet: return .red
        case .confirmed: return .green
        }
    }
}

// MARK: - Drag & Drop Transfer Types
// Note: ActorDragItem, CrewDragItem, and UTType extensions are defined in Utilities/PlanDragDropTypes.swift

struct CastingActor: Identifiable, Equatable {
    let id: UUID
    var name: String
    var role: String
    var websiteURL: String
    var imdbID: String?  // IMDB person ID (e.g., "nm0000138")
    var headshotData: Data?
    var headshotURL: String?  // URL to IMDB photo
    var createdAt: Date
    var rankNumber: Int16
    var section: CastCrewSection
    var notes: String
    var tags: String
    var phone: String
    var email: String
    var agentName: String
    var agentPhone: String
    var agentEmail: String
    var availabilityStart: Date?
    var availabilityEnd: Date?
    var characterID: UUID?

    init(id: UUID = UUID(), name: String, role: String, websiteURL: String, imdbID: String? = nil, headshotData: Data? = nil, headshotURL: String? = nil, createdAt: Date = Date(), rankNumber: Int16 = 0, section: CastCrewSection = .topPicks, notes: String = "", tags: String = "", phone: String = "", email: String = "", agentName: String = "", agentPhone: String = "", agentEmail: String = "", availabilityStart: Date? = nil, availabilityEnd: Date? = nil, characterID: UUID? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.websiteURL = websiteURL
        self.imdbID = imdbID
        self.headshotData = headshotData
        self.headshotURL = headshotURL
        self.createdAt = createdAt
        self.rankNumber = rankNumber
        self.section = section
        self.notes = notes
        self.tags = tags
        self.phone = phone
        self.email = email
        self.agentName = agentName
        self.agentPhone = agentPhone
        self.agentEmail = agentEmail
        self.availabilityStart = availabilityStart
        self.availabilityEnd = availabilityEnd
        self.characterID = characterID
    }
}

// MARK: - IMDB Search Result
struct IMDBSearchResult: Identifiable {
    let id: String  // IMDB ID like "nm0000138"
    let name: String
    let imageURL: String?
    let knownFor: String?
}

// MARK: - IMDB Photo for selection
struct IMDBPhoto: Identifiable {
    let id = UUID()
    let url: String
    var image: NSImage?
}

// MARK: - Casting Tab View
struct CastingTabView: View {
    @Environment(\.managedObjectContext) private var moc
    @FetchRequest(
        entity: CastingActorEntity.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CastingActorEntity.section, ascending: true),
            NSSortDescriptor(keyPath: \CastingActorEntity.rankNumber, ascending: true),
            NSSortDescriptor(keyPath: \CastingActorEntity.createdAt, ascending: false)
        ]
    ) private var actorEntities: FetchedResults<CastingActorEntity>

    @State private var showingAddSheet = false
    @State private var editingActor: CastingActor?
    @State private var expandedSections: Set<CastCrewSection> = Set(CastCrewSection.allCases)

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]

    // Convert Core Data entities to CastingActor models
    private var actors: [CastingActor] {
        actorEntities.map { entity in
            let sectionValue = entity.section ?? "Top Picks"
            let section = CastCrewSection(rawValue: sectionValue) ?? .topPicks
            return CastingActor(
                id: entity.id ?? UUID(),
                name: entity.name ?? "",
                role: entity.role ?? "",
                websiteURL: entity.websiteURL ?? "",
                imdbID: entity.imdbID,
                headshotData: entity.headshotData,
                headshotURL: entity.headshotURL,
                createdAt: entity.createdAt ?? Date(),
                rankNumber: entity.rankNumber,
                section: section,
                notes: entity.notes ?? "",
                tags: entity.tags ?? "",
                phone: entity.phone ?? "",
                email: entity.email ?? "",
                agentName: entity.agentName ?? "",
                agentPhone: entity.agentPhone ?? "",
                agentEmail: entity.agentEmail ?? "",
                availabilityStart: entity.availabilityStart,
                availabilityEnd: entity.availabilityEnd,
                characterID: entity.characterID
            )
        }
    }

    // Group actors by section
    private func actorsInSection(_ section: CastCrewSection) -> [CastingActor] {
        actors.filter { $0.section == section }
            .sorted { $0.rankNumber < $1.rankNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Casting")
                        .font(.system(size: 24, weight: .bold))
                    Text("Manage actors and casting decisions")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Actor", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            if actors.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.opacity(0.4))

                    Text("No Actors Added")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Add actors with their headshots, roles, and contact information.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add First Actor", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Actor grid organized by sections
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(CastCrewSection.allCases, id: \.self) { section in
                            let sectionActors = actorsInSection(section)
                            if !sectionActors.isEmpty || expandedSections.contains(section) {
                                castingSectionView(section: section, actors: sectionActors)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddCastingActorSheet(isPresented: $showingAddSheet) { actor in
                saveActor(actor)
            }
        }
        .sheet(item: $editingActor) { actor in
            EditCastingActorSheet(
                actor: actor,
                isPresented: Binding(
                    get: { editingActor != nil },
                    set: { if !$0 { editingActor = nil } }
                )
            ) { updatedActor in
                updateActor(updatedActor)
            }
        }
    }

    @State private var dragOverSection: CastCrewSection?

    @ViewBuilder
    private func castingSectionView(section: CastCrewSection, actors: [CastingActor]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(section.color)

                    Text(section.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(actors.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Section content
            if expandedSections.contains(section) {
                if actors.isEmpty {
                    // Empty drop zone
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 24))
                                .foregroundStyle(dragOverSection == section ? section.color : .secondary.opacity(0.5))
                            Text("Drop actors here")
                                .font(.system(size: 13))
                                .foregroundStyle(dragOverSection == section ? section.color : .secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                    .background(dragOverSection == section ? section.color.opacity(0.15) : Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(dragOverSection == section ? section.color : Color.clear, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(actors) { actor in
                            CastingActorCard(
                                actor: actor,
                                onDelete: { deleteActor(actor) },
                                onEdit: { editingActor = actor },
                                onSectionChange: { newSection in
                                    updateActorSection(actor, to: newSection)
                                },
                                onRankChange: { newRank in
                                    updateActorRank(actor, to: newRank)
                                }
                            )
                            .draggable(ActorDragItem(id: actor.id))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(dragOverSection == section ? section.color.opacity(0.08) : Color.secondary.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(dragOverSection == section ? section.color : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: ActorDragItem.self) { items, _ in
            for item in items {
                if let actor = actors.first(where: { $0.id == item.id }) ?? self.actors.first(where: { $0.id == item.id }) {
                    updateActorSection(actor, to: section)
                }
            }
            return true
        } isTargeted: { isTargeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                dragOverSection = isTargeted ? section : nil
            }
        }
    }

    private func saveActor(_ actor: CastingActor) {
        let entity = CastingActorEntity(context: moc)
        entity.id = actor.id
        entity.name = actor.name
        entity.role = actor.role
        entity.websiteURL = actor.websiteURL
        entity.imdbID = actor.imdbID
        entity.headshotData = actor.headshotData
        entity.headshotURL = actor.headshotURL
        entity.createdAt = actor.createdAt
        entity.rankNumber = actor.rankNumber
        entity.section = actor.section.rawValue

        do {
            try moc.save()
        } catch {
            print("Error saving actor: \(error)")
        }
    }

    private func updateActor(_ actor: CastingActor) {
        // Find the entity with matching ID
        if let entity = actorEntities.first(where: { $0.id == actor.id }) {
            entity.name = actor.name
            entity.role = actor.role
            entity.websiteURL = actor.websiteURL
            entity.imdbID = actor.imdbID
            entity.headshotData = actor.headshotData
            entity.headshotURL = actor.headshotURL
            entity.rankNumber = actor.rankNumber
            entity.section = actor.section.rawValue

            do {
                try moc.save()
            } catch {
                print("Error updating actor: \(error)")
            }
        }
    }

    private func deleteActor(_ actor: CastingActor) {
        if let entity = actorEntities.first(where: { $0.id == actor.id }) {
            moc.delete(entity)

            do {
                try moc.save()
            } catch {
                print("Error deleting actor: \(error)")
            }
        }
    }

    private func updateActorSection(_ actor: CastingActor, to newSection: CastCrewSection) {
        if let entity = actorEntities.first(where: { $0.id == actor.id }) {
            entity.section = newSection.rawValue
            do {
                try moc.save()

                // When moved to Confirmed, auto-add to Contacts
                if newSection == .confirmed {
                    ContactsService.shared.addContact(
                        name: actor.name,
                        category: .cast,
                        department: .castLead,
                        context: moc
                    )
                }
            } catch {
                print("Error updating actor section: \(error)")
            }
        }
    }

    private func updateActorRank(_ actor: CastingActor, to newRank: Int16) {
        if let entity = actorEntities.first(where: { $0.id == actor.id }) {
            entity.rankNumber = newRank
            do {
                try moc.save()
            } catch {
                print("Error updating actor rank: \(error)")
            }
        }
    }
}

// MARK: - Casting Actor Card
struct CastingActorCard: View {
    let actor: CastingActor
    let onDelete: () -> Void
    let onEdit: () -> Void
    var onSectionChange: ((CastCrewSection) -> Void)? = nil
    var onRankChange: ((Int16) -> Void)? = nil

    @State private var isHovered = false
    @State private var loadedImage: NSImage?
    @State private var showingRankPopover = false
    @State private var rankInput: String = ""

    private let cardWidth: CGFloat = 200
    private let imageHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            // Headshot area - fixed size container
            ZStack {
                // Background gradient (like the sample image)
                LinearGradient(
                    colors: [Color.cyan.opacity(0.6), Color.teal.opacity(0.4)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                // Show image from data, URL, or placeholder
                if let imageData = actor.headshotData,
                   let nsImage = NSImage(data: imageData) {
                    GeometryReader { geo in
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else if let loadedImage = loadedImage {
                    GeometryReader { geo in
                        Image(nsImage: loadedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    // Placeholder
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Rank number badge (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        // Delete button on hover (moves to left of rank)
                        if isHovered {
                            Button(action: onDelete) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        // Rank number badge
                        Button {
                            rankInput = actor.rankNumber > 0 ? "\(actor.rankNumber)" : ""
                            showingRankPopover = true
                        } label: {
                            Text(actor.rankNumber > 0 ? "#\(actor.rankNumber)" : "#")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(actor.rankNumber > 0 ? Color.blue : Color.gray.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingRankPopover) {
                            VStack(spacing: 12) {
                                Text("Set Rank Number")
                                    .font(.system(size: 13, weight: .semibold))
                                TextField("Rank #", text: $rankInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                HStack(spacing: 8) {
                                    Button("Clear") {
                                        onRankChange?(0)
                                        showingRankPopover = false
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                    Button("Set") {
                                        if let rank = Int16(rankInput) {
                                            onRankChange?(rank)
                                        }
                                        showingRankPopover = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(16)
                        }
                    }
                    .padding(8)
                    Spacer()
                }

                // IMDB badge if linked (bottom-left)
                if actor.imdbID != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Text("IMDb")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(8)
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: cardWidth, height: imageHeight)
            .clipped()

            // Info area
            VStack(spacing: 6) {
                Text(actor.name.isEmpty ? "Add a Title" : actor.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !actor.role.isEmpty {
                    Text(actor.role)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                if !actor.websiteURL.isEmpty || actor.imdbID != nil {
                    Link(destination: URL(string: actor.imdbID.map { "https://www.imdb.com/name/\($0)/" } ?? actor.websiteURL) ?? URL(string: "https://imdb.com")!) {
                        HStack(spacing: 4) {
                            Image(systemName: actor.imdbID != nil ? "film" : "link")
                                .font(.system(size: 10))
                            Text(actor.imdbID != nil ? "View on IMDB" : "Website / IMDB")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(width: cardWidth)
            .background(Color(red: 0.35, green: 0.30, blue: 0.55)) // Purple similar to sample
        }
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .contextMenu {
            // Section menu
            Menu("Move to Section") {
                ForEach(CastCrewSection.allCases, id: \.self) { section in
                    Button {
                        onSectionChange?(section)
                    } label: {
                        HStack {
                            Image(systemName: section.icon)
                            Text(section.displayName)
                            if actor.section == section {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadImageFromURL()
        }
    }

    private func loadImageFromURL() {
        guard let urlString = actor.headshotURL,
              let url = URL(string: urlString),
              actor.headshotData == nil else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.loadedImage = image
                }
            }
        }.resume()
    }
}

// MARK: - Add Casting Actor Sheet
struct AddCastingActorSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (CastingActor) -> Void

    @State private var name: String = ""
    @State private var role: String = ""
    @State private var websiteURL: String = ""
    @State private var headshotData: Data?
    @State private var headshotURL: String?
    @State private var imdbID: String?
    @State private var showingImagePicker = false

    // IMDB Search
    @State private var searchQuery: String = ""
    @State private var searchResults: [IMDBSearchResult] = []
    @State private var isSearching = false
    @State private var selectedResult: IMDBSearchResult?
    @State private var showSearchSection = false
    @State private var previewImage: NSImage?
    @State private var previewImageData: Data?  // Store the actual image data for saving
    @State private var fetchedImageURL: String?  // Store the actual fetched image URL
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Actor")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // IMDB Search Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Search IMDB")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedResult != nil {
                                Button("Clear") {
                                    clearIMDBSelection()
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .buttonStyle(.plain)
                            }
                        }

                        // Search field with dropdown
                        ZStack(alignment: .top) {
                            VStack(spacing: 0) {
                                // Search input
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.secondary)
                                    TextField("Search for actor...", text: $searchQuery)
                                        .textFieldStyle(.plain)
                                        .onChange(of: searchQuery) { newValue in
                                            // Auto-search after typing
                                            if newValue.count >= 2 {
                                                debounceSearch()
                                            } else {
                                                searchResults = []
                                            }
                                        }
                                        .onSubmit {
                                            searchIMDB()
                                        }

                                    if isSearching {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 20, height: 20)
                                    } else if !searchQuery.isEmpty {
                                        Button {
                                            searchQuery = ""
                                            searchResults = []
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))
                                )

                                // Dropdown results
                                if !searchResults.isEmpty && selectedResult == nil {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults) { result in
                                            IMDBSearchResultRow(
                                                result: result,
                                                isSelected: false
                                            ) {
                                                selectIMDBResult(result)
                                            }

                                            if result.id != searchResults.last?.id {
                                                Divider()
                                                    .padding(.horizontal, 8)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // Selected IMDB result preview
                        if let selected = selectedResult {
                            HStack(spacing: 12) {
                                // Photo preview
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))

                                    if let image = previewImage {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("IMDb")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.yellow)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                        Text("Linked")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.green)
                                    }
                                    Text(selected.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    if let knownFor = selected.knownFor {
                                        Text(knownFor)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Manual headshot picker (if no IMDB selected)
                    if selectedResult == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Or Choose Headshot Manually")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 16) {
                                // Preview
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))

                                    if let data = headshotData,
                                       let nsImage = NSImage(data: data) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(systemName: "person.crop.rectangle")
                                            .font(.system(size: 30))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 80, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 8) {
                                    Button("Choose Image...") {
                                        chooseImage()
                                    }
                                    .buttonStyle(.bordered)

                                    if headshotData != nil {
                                        Button("Remove") {
                                            headshotData = nil
                                        }
                                        .foregroundStyle(.red)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Role (always show)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Role / Character")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Enter role...", text: $role)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }

                    // Name (if no IMDB selected)
                    if selectedResult == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Actor Name")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("Enter name...", text: $name)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))
                                )
                        }

                        // Website URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Website Link (optional)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("https://...", text: $websiteURL)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))
                                )
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Actor") {
                    let actor = CastingActor(
                        name: selectedResult?.name ?? name,
                        role: role,
                        websiteURL: websiteURL,
                        imdbID: selectedResult?.id,
                        headshotData: previewImageData ?? headshotData,  // Use fetched IMDB image data if available
                        headshotURL: fetchedImageURL ?? selectedResult?.imageURL
                    )
                    onAdd(actor)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(actorName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 620)
    }

    private var actorName: String {
        selectedResult?.name ?? name
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select a headshot image"

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                headshotData = data
            }
        }
    }

    private func debounceSearch() {
        // Cancel any existing search task
        searchTask?.cancel()

        // Create a new debounced search task
        searchTask = Task {
            // Wait 500ms before searching
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Perform search on main thread
            await MainActor.run {
                searchIMDB()
            }
        }
    }

    private func searchIMDB() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        searchResults = []

        // Use IMDB's suggestion API directly - more reliable than scraping
        let query = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = "https://v3.sg.media-imdb.com/suggestion/x/\(query).json"

        guard let url = URL(string: searchURL) else {
            isSearching = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.imdb.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isSearching = false

                guard let data = data else { return }

                // Parse IMDB suggestion JSON response
                let results = self.parseIMDBSuggestionResults(from: data)
                self.searchResults = results
            }
        }.resume()
    }

    private func parseIMDBSuggestionResults(from data: Data) -> [IMDBSearchResult] {
        var results: [IMDBSearchResult] = []

        // Parse JSON response from IMDB suggestion API
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let suggestions = json["d"] as? [[String: Any]] else {
            return results
        }

        for suggestion in suggestions.prefix(5) {
            // Only include people (names start with "nm")
            guard let imdbID = suggestion["id"] as? String,
                  imdbID.hasPrefix("nm"),
                  let name = suggestion["l"] as? String else { continue }

            // Get image URL if available
            let imageURL = (suggestion["i"] as? [String: Any])?["imageUrl"] as? String

            // Get known for info
            let knownFor = suggestion["s"] as? String

            results.append(IMDBSearchResult(
                id: imdbID,
                name: name,
                imageURL: imageURL,
                knownFor: knownFor
            ))
        }

        return results
    }

    private func selectIMDBResult(_ result: IMDBSearchResult) {
        selectedResult = result
        name = result.name
        searchResults = []
        searchQuery = ""

        // Load preview image directly from the API-provided URL
        if let urlString = result.imageURL {
            // Get higher resolution by modifying the URL
            var highResURL = urlString.replacingOccurrences(
                of: #"\._V1_[^.]+\.(jpg|png)"#,
                with: "._V1_UX400.$1",
                options: .regularExpression
            )
            // If no match, just use original
            if highResURL == urlString {
                highResURL = urlString
            }

            fetchedImageURL = highResURL

            if let url = URL(string: highResURL) {
                loadImageDirectly(from: url)
            }
        }
    }

    private func loadImageDirectly(from url: URL) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("https://www.imdb.com/", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { imageData, _, _ in
            if let imageData = imageData,
               let image = NSImage(data: imageData) {
                DispatchQueue.main.async {
                    self.previewImage = image
                    self.previewImageData = imageData
                }
            }
        }.resume()
    }

    private func clearIMDBSelection() {
        selectedResult = nil
        previewImage = nil
        previewImageData = nil
        fetchedImageURL = nil
        headshotURL = nil
        imdbID = nil
    }
}

// MARK: - Edit Casting Actor Sheet
struct EditCastingActorSheet: View {
    let actor: CastingActor
    @Binding var isPresented: Bool
    let onSave: (CastingActor) -> Void

    @State private var name: String = ""
    @State private var role: String = ""
    @State private var websiteURL: String = ""
    @State private var headshotData: Data?
    @State private var headshotURL: String?
    @State private var imdbID: String?
    @State private var previewImage: NSImage?

    // IMDB photo gallery
    @State private var imdbPhotos: [IMDBPhoto] = []
    @State private var isLoadingPhotos = false
    @State private var selectedPhotoIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Actor")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current photo preview
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.05))

                            if let image = previewImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let data = headshotData, let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 12) {
                            if actor.imdbID != nil {
                                HStack(spacing: 6) {
                                    Text("IMDb")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    Text("Linked")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                            }

                            Button {
                                chooseImage()
                            } label: {
                                Label("Choose Image", systemImage: "photo")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)

                            if actor.imdbID != nil && !isLoadingPhotos && imdbPhotos.isEmpty {
                                Button {
                                    loadIMDBPhotos()
                                } label: {
                                    Label("Load IMDB Photos", systemImage: "arrow.down.circle")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    // IMDB Photo Gallery
                    if !imdbPhotos.isEmpty || isLoadingPhotos {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("IMDB Photos")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if isLoadingPhotos {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading photos...")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(imdbPhotos.enumerated()), id: \.element.id) { index, photo in
                                            IMDBPhotoThumbnail(
                                                photo: photo,
                                                isSelected: selectedPhotoIndex == index
                                            ) {
                                                selectPhoto(at: index)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Actor name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Role field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Role")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Character name or role", text: $role)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Website field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Website URL")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("https://...", text: $websiteURL)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save Changes") {
                    let updatedActor = CastingActor(
                        id: actor.id,
                        name: name,
                        role: role,
                        websiteURL: websiteURL,
                        imdbID: imdbID,
                        headshotData: headshotData,
                        headshotURL: headshotURL,
                        createdAt: actor.createdAt
                    )
                    onSave(updatedActor)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 620)
        .onAppear {
            // Initialize with actor data
            name = actor.name
            role = actor.role
            websiteURL = actor.websiteURL
            headshotData = actor.headshotData
            headshotURL = actor.headshotURL
            imdbID = actor.imdbID

            // Load current image
            if let data = actor.headshotData, let image = NSImage(data: data) {
                previewImage = image
            } else if let urlString = actor.headshotURL, let url = URL(string: urlString) {
                loadImage(from: url)
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select a headshot image"

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                headshotData = data
                previewImage = image
                selectedPhotoIndex = nil
            }
        }
    }

    private func loadImage(from url: URL) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.previewImage = image
                }
            }
        }.resume()
    }

    private func loadIMDBPhotos() {
        guard let imdbID = actor.imdbID else { return }

        isLoadingPhotos = true

        // Fetch the media index page for this person
        let mediaURL = URL(string: "https://www.imdb.com/name/\(imdbID)/mediaindex")!

        var request = URLRequest(url: mediaURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.isLoadingPhotos = false }
                return
            }

            // Extract image URLs from the page
            let pattern = #"https://m\.media-amazon\.com/images/M/[^"'\s]+\.jpg"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                DispatchQueue.main.async { self.isLoadingPhotos = false }
                return
            }

            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            var urls = Set<String>()
            for match in matches {
                if let matchRange = Range(match.range, in: html) {
                    var urlString = String(html[matchRange])
                    // Get medium resolution
                    urlString = urlString.replacingOccurrences(
                        of: #"\._V1_[^.]+\.jpg"#,
                        with: "._V1_UX300.jpg",
                        options: .regularExpression
                    )
                    urls.insert(urlString)
                }
            }

            let photoURLs = Array(urls.prefix(12))

            DispatchQueue.main.async {
                self.imdbPhotos = photoURLs.map { IMDBPhoto(url: $0, image: nil) }
                self.isLoadingPhotos = false

                // Load thumbnails
                for (index, photo) in self.imdbPhotos.enumerated() {
                    self.loadThumbnail(for: index, url: photo.url)
                }
            }
        }.resume()
    }

    private func loadThumbnail(for index: Int, url: String) {
        guard let photoURL = URL(string: url) else { return }

        var request = URLRequest(url: photoURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    if index < self.imdbPhotos.count {
                        self.imdbPhotos[index].image = image
                    }
                }
            }
        }.resume()
    }

    private func selectPhoto(at index: Int) {
        selectedPhotoIndex = index
        let photo = imdbPhotos[index]

        // Get higher resolution version
        let highResURL = photo.url.replacingOccurrences(
            of: #"\._V1_[^.]+\.jpg"#,
            with: "._V1_UX400.jpg",
            options: .regularExpression
        )

        headshotURL = highResURL

        if let image = photo.image {
            previewImage = image
        }

        // Load the image data
        if let url = URL(string: highResURL) {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data, let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self.headshotData = data
                        self.previewImage = image
                    }
                }
            }.resume()
        }
    }
}

// MARK: - IMDB Photo Thumbnail
struct IMDBPhotoThumbnail: View {
    let photo: IMDBPhoto
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))

            if let image = photo.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .frame(width: 70, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - IMDB Search Result Row
struct IMDBSearchResultRow: View {
    let result: IMDBSearchResult
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.05))

                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 36, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text("IMDB: \(result.id)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let urlString = result.imageURL,
              let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            }
        }.resume()
    }
}

// MARK: - Plan Crew Member Model (for cards like CastingActor)
struct PlanCrewMember: Identifiable, Equatable {
    let id: UUID
    var name: String
    var role: String  // Job title/position
    var websiteURL: String
    var imdbID: String?
    var headshotData: Data?
    var headshotURL: String?
    var createdAt: Date
    var rankNumber: Int16
    var section: CastCrewSection
    var notes: String
    var tags: String
    var phone: String
    var email: String
    var agentName: String
    var agentPhone: String
    var agentEmail: String
    var availabilityStart: Date?
    var availabilityEnd: Date?

    init(id: UUID = UUID(), name: String, role: String, websiteURL: String, imdbID: String? = nil, headshotData: Data? = nil, headshotURL: String? = nil, createdAt: Date = Date(), rankNumber: Int16 = 0, section: CastCrewSection = .topPicks, notes: String = "", tags: String = "", phone: String = "", email: String = "", agentName: String = "", agentPhone: String = "", agentEmail: String = "", availabilityStart: Date? = nil, availabilityEnd: Date? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.websiteURL = websiteURL
        self.imdbID = imdbID
        self.headshotData = headshotData
        self.headshotURL = headshotURL
        self.createdAt = createdAt
        self.rankNumber = rankNumber
        self.section = section
        self.notes = notes
        self.tags = tags
        self.phone = phone
        self.email = email
        self.agentName = agentName
        self.agentPhone = agentPhone
        self.agentEmail = agentEmail
        self.availabilityStart = availabilityStart
        self.availabilityEnd = availabilityEnd
    }
}

// Legacy crew member option model (kept for backwards compatibility)
struct CrewMemberOption: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var departmentID: UUID

    init(id: UUID = UUID(), name: String, departmentID: UUID) {
        self.id = id
        self.name = name
        self.departmentID = departmentID
    }
}

// MARK: - Crew Tab View
struct CrewTabView: View {
    @Environment(\.managedObjectContext) private var moc
    @FetchRequest(
        entity: PlanCrewMemberEntity.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \PlanCrewMemberEntity.section, ascending: true),
            NSSortDescriptor(keyPath: \PlanCrewMemberEntity.rankNumber, ascending: true),
            NSSortDescriptor(keyPath: \PlanCrewMemberEntity.createdAt, ascending: false)
        ]
    ) private var crewEntities: FetchedResults<PlanCrewMemberEntity>

    @State private var showingAddSheet = false
    @State private var editingCrewMember: PlanCrewMember?
    @State private var expandedSections: Set<CastCrewSection> = Set(CastCrewSection.allCases)

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]

    // Convert Core Data entities to PlanCrewMember models
    private var crewMembers: [PlanCrewMember] {
        crewEntities.map { entity in
            let sectionValue = entity.section ?? "Top Picks"
            let section = CastCrewSection(rawValue: sectionValue) ?? .topPicks
            return PlanCrewMember(
                id: entity.id ?? UUID(),
                name: entity.name ?? "",
                role: entity.role ?? "",
                websiteURL: entity.websiteURL ?? "",
                imdbID: entity.imdbID,
                headshotData: entity.headshotData,
                headshotURL: entity.headshotURL,
                createdAt: entity.createdAt ?? Date(),
                rankNumber: entity.rankNumber,
                section: section,
                notes: entity.notes ?? "",
                tags: entity.tags ?? "",
                phone: entity.phone ?? "",
                email: entity.email ?? "",
                agentName: entity.agentName ?? "",
                agentPhone: entity.agentPhone ?? "",
                agentEmail: entity.agentEmail ?? "",
                availabilityStart: entity.availabilityStart,
                availabilityEnd: entity.availabilityEnd
            )
        }
    }

    // Group crew members by section
    private func crewInSection(_ section: CastCrewSection) -> [PlanCrewMember] {
        crewMembers.filter { $0.section == section }
            .sorted { $0.rankNumber < $1.rankNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crew")
                        .font(.system(size: 24, weight: .bold))
                    Text("Manage crew members and contacts")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Crew Member", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            if crewMembers.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green.opacity(0.4))

                    Text("No Crew Members Added")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Add crew members with their headshots, roles, and contact information.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add First Crew Member", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Crew member grid organized by sections
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(CastCrewSection.allCases, id: \.self) { section in
                            let sectionMembers = crewInSection(section)
                            if !sectionMembers.isEmpty || expandedSections.contains(section) {
                                crewSectionView(section: section, members: sectionMembers)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPlanCrewMemberSheet(isPresented: $showingAddSheet) { member in
                saveCrewMember(member)
            }
        }
        .sheet(item: $editingCrewMember) { member in
            EditPlanCrewMemberSheet(
                crewMember: member,
                isPresented: Binding(
                    get: { editingCrewMember != nil },
                    set: { if !$0 { editingCrewMember = nil } }
                )
            ) { updatedMember in
                updateCrewMember(updatedMember)
            }
        }
    }

    @State private var dragOverSection: CastCrewSection?

    @ViewBuilder
    private func crewSectionView(section: CastCrewSection, members: [PlanCrewMember]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(section.color)

                    Text(section.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(members.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Section content
            if expandedSections.contains(section) {
                if members.isEmpty {
                    // Empty drop zone
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 24))
                                .foregroundStyle(dragOverSection == section ? section.color : .secondary.opacity(0.5))
                            Text("Drop crew members here")
                                .font(.system(size: 13))
                                .foregroundStyle(dragOverSection == section ? section.color : .secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                    .background(dragOverSection == section ? section.color.opacity(0.15) : Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(dragOverSection == section ? section.color : Color.clear, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(members) { member in
                            PlanCrewMemberCard(
                                crewMember: member,
                                onDelete: { deleteCrewMember(member) },
                                onEdit: { editingCrewMember = member },
                                onSectionChange: { newSection in
                                    updateCrewSection(member, to: newSection)
                                },
                                onRankChange: { newRank in
                                    updateCrewRank(member, to: newRank)
                                }
                            )
                            .draggable(CrewDragItem(id: member.id))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(dragOverSection == section ? section.color.opacity(0.08) : Color.secondary.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(dragOverSection == section ? section.color : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: CrewDragItem.self) { items, _ in
            for item in items {
                if let member = members.first(where: { $0.id == item.id }) ?? self.crewMembers.first(where: { $0.id == item.id }) {
                    updateCrewSection(member, to: section)
                }
            }
            return true
        } isTargeted: { isTargeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                dragOverSection = isTargeted ? section : nil
            }
        }
    }

    private func saveCrewMember(_ member: PlanCrewMember) {
        let entity = PlanCrewMemberEntity(context: moc)
        entity.id = member.id
        entity.name = member.name
        entity.role = member.role
        entity.websiteURL = member.websiteURL
        entity.imdbID = member.imdbID
        entity.headshotData = member.headshotData
        entity.headshotURL = member.headshotURL
        entity.createdAt = member.createdAt
        entity.rankNumber = member.rankNumber
        entity.section = member.section.rawValue

        do {
            try moc.save()
        } catch {
            print("Error saving crew member: \(error)")
        }
    }

    private func updateCrewMember(_ member: PlanCrewMember) {
        if let entity = crewEntities.first(where: { $0.id == member.id }) {
            entity.name = member.name
            entity.role = member.role
            entity.websiteURL = member.websiteURL
            entity.imdbID = member.imdbID
            entity.headshotData = member.headshotData
            entity.headshotURL = member.headshotURL
            entity.rankNumber = member.rankNumber
            entity.section = member.section.rawValue

            do {
                try moc.save()
            } catch {
                print("Error updating crew member: \(error)")
            }
        }
    }

    private func deleteCrewMember(_ member: PlanCrewMember) {
        if let entity = crewEntities.first(where: { $0.id == member.id }) {
            moc.delete(entity)

            do {
                try moc.save()
            } catch {
                print("Error deleting crew member: \(error)")
            }
        }
    }

    private func updateCrewSection(_ member: PlanCrewMember, to newSection: CastCrewSection) {
        if let entity = crewEntities.first(where: { $0.id == member.id }) {
            entity.section = newSection.rawValue
            do {
                try moc.save()

                // When moved to Confirmed, auto-add to Contacts
                if newSection == .confirmed {
                    ContactsService.shared.addContact(
                        name: member.name,
                        category: .crew,
                        department: .production,
                        context: moc
                    )
                }
            } catch {
                print("Error updating crew member section: \(error)")
            }
        }
    }

    private func updateCrewRank(_ member: PlanCrewMember, to newRank: Int16) {
        if let entity = crewEntities.first(where: { $0.id == member.id }) {
            entity.rankNumber = newRank
            do {
                try moc.save()
            } catch {
                print("Error updating crew member rank: \(error)")
            }
        }
    }
}

// MARK: - Plan Crew Member Card
struct PlanCrewMemberCard: View {
    let crewMember: PlanCrewMember
    let onDelete: () -> Void
    let onEdit: () -> Void
    var onSectionChange: ((CastCrewSection) -> Void)? = nil
    var onRankChange: ((Int16) -> Void)? = nil

    @State private var isHovered = false
    @State private var loadedImage: NSImage?
    @State private var showingRankPopover = false
    @State private var rankInput: String = ""

    private let cardWidth: CGFloat = 200
    private let imageHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            // Headshot area - fixed size container
            ZStack {
                // Background gradient (green theme for crew)
                LinearGradient(
                    colors: [Color.green.opacity(0.6), Color.teal.opacity(0.4)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                // Show image from data, URL, or placeholder
                if let imageData = crewMember.headshotData,
                   let nsImage = NSImage(data: imageData) {
                    GeometryReader { geo in
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else if let loadedImage = loadedImage {
                    GeometryReader { geo in
                        Image(nsImage: loadedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    // Placeholder
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Rank number badge (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        // Delete button on hover (moves to left of rank)
                        if isHovered {
                            Button(action: onDelete) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        // Rank number badge
                        Button {
                            rankInput = crewMember.rankNumber > 0 ? "\(crewMember.rankNumber)" : ""
                            showingRankPopover = true
                        } label: {
                            Text(crewMember.rankNumber > 0 ? "#\(crewMember.rankNumber)" : "#")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(crewMember.rankNumber > 0 ? Color.green : Color.gray.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingRankPopover) {
                            VStack(spacing: 12) {
                                Text("Set Rank Number")
                                    .font(.system(size: 13, weight: .semibold))
                                TextField("Rank #", text: $rankInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                HStack(spacing: 8) {
                                    Button("Clear") {
                                        onRankChange?(0)
                                        showingRankPopover = false
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                    Button("Set") {
                                        if let rank = Int16(rankInput) {
                                            onRankChange?(rank)
                                        }
                                        showingRankPopover = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(16)
                        }
                    }
                    .padding(8)
                    Spacer()
                }

                // IMDB badge if linked (bottom-left)
                if crewMember.imdbID != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Text("IMDb")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(8)
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: cardWidth, height: imageHeight)
            .clipped()

            // Info area (green theme)
            VStack(spacing: 6) {
                Text(crewMember.name.isEmpty ? "Add a Title" : crewMember.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !crewMember.role.isEmpty {
                    Text(crewMember.role)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                if !crewMember.websiteURL.isEmpty || crewMember.imdbID != nil {
                    Link(destination: URL(string: crewMember.imdbID.map { "https://www.imdb.com/name/\($0)/" } ?? crewMember.websiteURL) ?? URL(string: "https://imdb.com")!) {
                        HStack(spacing: 4) {
                            Image(systemName: crewMember.imdbID != nil ? "film" : "link")
                                .font(.system(size: 10))
                            Text(crewMember.imdbID != nil ? "View on IMDB" : "Website / IMDB")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(width: cardWidth)
            .background(Color(red: 0.20, green: 0.45, blue: 0.35)) // Green similar to crew theme
        }
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .contextMenu {
            // Section menu
            Menu("Move to Section") {
                ForEach(CastCrewSection.allCases, id: \.self) { section in
                    Button {
                        onSectionChange?(section)
                    } label: {
                        HStack {
                            Image(systemName: section.icon)
                            Text(section.displayName)
                            if crewMember.section == section {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadImageFromURL()
        }
    }

    private func loadImageFromURL() {
        guard let urlString = crewMember.headshotURL,
              let url = URL(string: urlString),
              crewMember.headshotData == nil else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.loadedImage = image
                }
            }
        }.resume()
    }
}

// MARK: - Add Plan Crew Member Sheet
struct AddPlanCrewMemberSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (PlanCrewMember) -> Void

    @State private var name: String = ""
    @State private var role: String = ""
    @State private var websiteURL: String = ""
    @State private var headshotData: Data?
    @State private var headshotURL: String?
    @State private var imdbID: String?
    @State private var showingImagePicker = false

    // IMDB Search
    @State private var searchQuery: String = ""
    @State private var searchResults: [IMDBSearchResult] = []
    @State private var isSearching = false
    @State private var selectedResult: IMDBSearchResult?
    @State private var showSearchSection = false
    @State private var previewImage: NSImage?
    @State private var previewImageData: Data?
    @State private var fetchedImageURL: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Crew Member")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // IMDB Search Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Search IMDB")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedResult != nil {
                                Button("Clear") {
                                    clearIMDBSelection()
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .buttonStyle(.plain)
                            }
                        }

                        // Search field with dropdown
                        ZStack(alignment: .top) {
                            VStack(spacing: 0) {
                                // Search input
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.secondary)
                                    TextField("Search for crew member...", text: $searchQuery)
                                        .textFieldStyle(.plain)
                                        .onChange(of: searchQuery) { newValue in
                                            if newValue.count >= 2 {
                                                debounceSearch()
                                            } else {
                                                searchResults = []
                                            }
                                        }
                                        .onSubmit {
                                            searchIMDB()
                                        }

                                    if isSearching {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 20, height: 20)
                                    } else if !searchQuery.isEmpty {
                                        Button {
                                            searchQuery = ""
                                            searchResults = []
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))
                                )

                                // Dropdown results
                                if !searchResults.isEmpty && selectedResult == nil {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults) { result in
                                            IMDBSearchResultRow(
                                                result: result,
                                                isSelected: false
                                            ) {
                                                selectIMDBResult(result)
                                            }

                                            if result.id != searchResults.last?.id {
                                                Divider()
                                                    .padding(.horizontal, 8)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // Selected IMDB result preview
                        if let selected = selectedResult {
                            HStack(spacing: 12) {
                                // Photo preview
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))

                                    if let image = previewImage {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("IMDb")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.yellow)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                        Text("Linked")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.green)
                                    }
                                    Text(selected.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    if let knownFor = selected.knownFor {
                                        Text(knownFor)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Manual headshot picker (if no IMDB selected)
                    if selectedResult == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Or Choose Headshot Manually")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 16) {
                                // Preview
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))

                                    if let data = headshotData,
                                       let nsImage = NSImage(data: data) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(systemName: "person.crop.rectangle")
                                            .font(.system(size: 30))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 80, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 8) {
                                    Button("Choose Image...") {
                                        chooseImage()
                                    }
                                    .buttonStyle(.bordered)

                                    if headshotData != nil {
                                        Button("Remove") {
                                            headshotData = nil
                                        }
                                        .foregroundStyle(.red)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Role/Position (always show)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Role / Position")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Enter role (e.g., Director of Photography)...", text: $role)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }

                    // Name (if no IMDB selected)
                    if selectedResult == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Crew Member Name")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("Enter name...", text: $name)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))
                                )
                        }

                        // Website URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Website Link (optional)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("https://...", text: $websiteURL)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.05))
                                )
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Crew Member") {
                    let member = PlanCrewMember(
                        name: selectedResult?.name ?? name,
                        role: role,
                        websiteURL: websiteURL,
                        imdbID: selectedResult?.id,
                        headshotData: previewImageData ?? headshotData,
                        headshotURL: fetchedImageURL ?? selectedResult?.imageURL
                    )
                    onAdd(member)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(memberName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 620)
    }

    private var memberName: String {
        selectedResult?.name ?? name
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select a headshot image"

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                headshotData = data
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchIMDB()
            }
        }
    }

    private func searchIMDB() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        searchResults = []

        let query = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = "https://v3.sg.media-imdb.com/suggestion/x/\(query).json"

        guard let url = URL(string: searchURL) else {
            isSearching = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.imdb.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isSearching = false
                guard let data = data else { return }
                let results = self.parseIMDBSuggestionResults(from: data)
                self.searchResults = results
            }
        }.resume()
    }

    private func parseIMDBSuggestionResults(from data: Data) -> [IMDBSearchResult] {
        var results: [IMDBSearchResult] = []

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let suggestions = json["d"] as? [[String: Any]] else {
            return results
        }

        for suggestion in suggestions.prefix(5) {
            guard let imdbID = suggestion["id"] as? String,
                  imdbID.hasPrefix("nm"),
                  let name = suggestion["l"] as? String else { continue }

            let imageURL = (suggestion["i"] as? [String: Any])?["imageUrl"] as? String
            let knownFor = suggestion["s"] as? String

            results.append(IMDBSearchResult(
                id: imdbID,
                name: name,
                imageURL: imageURL,
                knownFor: knownFor
            ))
        }

        return results
    }

    private func selectIMDBResult(_ result: IMDBSearchResult) {
        selectedResult = result
        name = result.name
        searchResults = []
        searchQuery = ""

        if let urlString = result.imageURL {
            var highResURL = urlString.replacingOccurrences(
                of: #"\._V1_[^.]+\.(jpg|png)"#,
                with: "._V1_UX400.$1",
                options: .regularExpression
            )
            if highResURL == urlString {
                highResURL = urlString
            }

            fetchedImageURL = highResURL

            if let url = URL(string: highResURL) {
                loadImageDirectly(from: url)
            }
        }
    }

    private func loadImageDirectly(from url: URL) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("https://www.imdb.com/", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { imageData, _, _ in
            if let imageData = imageData,
               let image = NSImage(data: imageData) {
                DispatchQueue.main.async {
                    self.previewImage = image
                    self.previewImageData = imageData
                }
            }
        }.resume()
    }

    private func clearIMDBSelection() {
        selectedResult = nil
        previewImage = nil
        previewImageData = nil
        fetchedImageURL = nil
        headshotURL = nil
        imdbID = nil
    }
}

// MARK: - Edit Plan Crew Member Sheet
struct EditPlanCrewMemberSheet: View {
    let crewMember: PlanCrewMember
    @Binding var isPresented: Bool
    let onSave: (PlanCrewMember) -> Void

    @State private var name: String = ""
    @State private var role: String = ""
    @State private var websiteURL: String = ""
    @State private var headshotData: Data?
    @State private var headshotURL: String?
    @State private var imdbID: String?
    @State private var previewImage: NSImage?

    // IMDB photo gallery
    @State private var imdbPhotos: [IMDBPhoto] = []
    @State private var isLoadingPhotos = false
    @State private var selectedPhotoIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Crew Member")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current photo preview
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.05))

                            if let image = previewImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let data = headshotData, let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 12) {
                            if crewMember.imdbID != nil {
                                HStack(spacing: 6) {
                                    Text("IMDb")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    Text("Linked")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                            }

                            Button {
                                chooseImage()
                            } label: {
                                Label("Choose Image", systemImage: "photo")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)

                            if crewMember.imdbID != nil && !isLoadingPhotos && imdbPhotos.isEmpty {
                                Button {
                                    loadIMDBPhotos()
                                } label: {
                                    Label("Load IMDB Photos", systemImage: "arrow.down.circle")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    // IMDB Photo Gallery
                    if !imdbPhotos.isEmpty || isLoadingPhotos {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("IMDB Photos")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if isLoadingPhotos {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading photos...")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(imdbPhotos.enumerated()), id: \.element.id) { index, photo in
                                            IMDBPhotoThumbnail(
                                                photo: photo,
                                                isSelected: selectedPhotoIndex == index
                                            ) {
                                                selectPhoto(at: index)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Crew member name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Role field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Role / Position")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Job title or position", text: $role)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Website field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Website URL")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("https://...", text: $websiteURL)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save Changes") {
                    let updatedMember = PlanCrewMember(
                        id: crewMember.id,
                        name: name,
                        role: role,
                        websiteURL: websiteURL,
                        imdbID: imdbID,
                        headshotData: headshotData,
                        headshotURL: headshotURL,
                        createdAt: crewMember.createdAt
                    )
                    onSave(updatedMember)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 620)
        .onAppear {
            // Initialize with crew member data
            name = crewMember.name
            role = crewMember.role
            websiteURL = crewMember.websiteURL
            headshotData = crewMember.headshotData
            headshotURL = crewMember.headshotURL
            imdbID = crewMember.imdbID

            // Load current image
            if let data = crewMember.headshotData, let image = NSImage(data: data) {
                previewImage = image
            } else if let urlString = crewMember.headshotURL, let url = URL(string: urlString) {
                loadImage(from: url)
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select a headshot image"

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                headshotData = data
                previewImage = image
                selectedPhotoIndex = nil
            }
        }
    }

    private func loadImage(from url: URL) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.previewImage = image
                }
            }
        }.resume()
    }

    private func loadIMDBPhotos() {
        guard let imdbID = crewMember.imdbID else { return }

        isLoadingPhotos = true

        let mediaURL = URL(string: "https://www.imdb.com/name/\(imdbID)/mediaindex")!

        var request = URLRequest(url: mediaURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.isLoadingPhotos = false }
                return
            }

            let pattern = #"https://m\.media-amazon\.com/images/M/[^"'\s]+\.jpg"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                DispatchQueue.main.async { self.isLoadingPhotos = false }
                return
            }

            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            var urls = Set<String>()
            for match in matches {
                if let matchRange = Range(match.range, in: html) {
                    var urlString = String(html[matchRange])
                    urlString = urlString.replacingOccurrences(
                        of: #"\._V1_[^.]+\.jpg"#,
                        with: "._V1_UX300.jpg",
                        options: .regularExpression
                    )
                    urls.insert(urlString)
                }
            }

            let photoURLs = Array(urls.prefix(12))

            DispatchQueue.main.async {
                self.imdbPhotos = photoURLs.map { IMDBPhoto(url: $0, image: nil) }
                self.isLoadingPhotos = false

                for (index, photo) in self.imdbPhotos.enumerated() {
                    self.loadThumbnail(for: index, url: photo.url)
                }
            }
        }.resume()
    }

    private func loadThumbnail(for index: Int, url: String) {
        guard let photoURL = URL(string: url) else { return }

        var request = URLRequest(url: photoURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    if index < self.imdbPhotos.count {
                        self.imdbPhotos[index].image = image
                    }
                }
            }
        }.resume()
    }

    private func selectPhoto(at index: Int) {
        selectedPhotoIndex = index
        let photo = imdbPhotos[index]

        let highResURL = photo.url.replacingOccurrences(
            of: #"\._V1_[^.]+\.jpg"#,
            with: "._V1_UX400.jpg",
            options: .regularExpression
        )

        headshotURL = highResURL

        if let image = photo.image {
            previewImage = image
        }

        if let url = URL(string: highResURL) {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data, let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self.headshotData = data
                        self.previewImage = image
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Crew Department Section (Legacy)
struct CrewDepartmentSection: View {
    let department: ProductionDepartment
    let crewMembers: [CrewMemberOption]
    @Binding var newMemberText: String
    let onAddMember: (String) -> Void
    let onDeleteMember: (CrewMemberOption) -> Void

    @State private var isExpanded = true
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Department header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(department.color.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: department.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(department.color)
                    }

                    // Department name
                    Text(department.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    // Count badge
                    if !crewMembers.isEmpty {
                        Text("\(crewMembers.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(department.color)
                            )
                    }

                    Spacer()

                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Crew members list
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Existing crew members
                    ForEach(crewMembers) { member in
                        CrewMemberRow(
                            member: member,
                            departmentColor: department.color,
                            onDelete: { onDeleteMember(member) }
                        )
                    }

                    // Add new member text field
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        TextField("Add crew member name...", text: $newMemberText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                if !newMemberText.trimmingCharacters(in: .whitespaces).isEmpty {
                                    onAddMember(newMemberText)
                                }
                            }

                        if !newMemberText.isEmpty {
                            Button {
                                onAddMember(newMemberText)
                            } label: {
                                Image(systemName: "return")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(
                                        Circle()
                                            .fill(department.color)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isTextFieldFocused ? department.color.opacity(0.5) : Color.primary.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Crew Member Row
struct CrewMemberRow: View {
    let member: CrewMemberOption
    let departmentColor: Color
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Bullet/indicator
            Circle()
                .fill(departmentColor.opacity(0.6))
                .frame(width: 6, height: 6)

            // Name
            Text(member.name)
                .font(.system(size: 14))
                .foregroundStyle(.primary)

            Spacer()

            // Delete button on hover
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Plan Item Model
struct PlanItem: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var dueDate: Date?
    var priority: Priority
    var isCompleted: Bool = false
    var createdAt: Date = Date()

    enum Priority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }

        var icon: String {
            switch self {
            case .low: return "arrow.down.circle"
            case .medium: return "minus.circle"
            case .high: return "arrow.up.circle"
            }
        }
    }
}

// MARK: - Plan Item Row
struct PlanItemRow: View {
    let item: PlanItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Completion toggle
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .medium))
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)

                    // Priority badge
                    HStack(spacing: 4) {
                        Image(systemName: item.priority.icon)
                            .font(.system(size: 10))
                        Text(item.priority.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(item.priority.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(item.priority.color.opacity(0.15))
                    )
                }

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let dueDate = item.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(dueDate, style: .date)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(dueDateColor(dueDate))
                }
            }

            Spacer()

            // Delete button (shown on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.purple.opacity(0.1) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.purple.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
    }

    private func dueDateColor(_ date: Date) -> Color {
        let now = Date()
        if item.isCompleted {
            return .secondary
        }
        if date < now {
            return .red
        }
        if date < now.addingTimeInterval(86400 * 3) { // Within 3 days
            return .orange
        }
        return .secondary
    }
}

// MARK: - Add Plan Item Sheet
struct AddPlanItemSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (String, String, Date?, PlanItem.Priority) -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: PlanItem.Priority = .medium

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Plan Item")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Enter title...", text: $title)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $description)
                            .font(.system(size: 14))
                            .frame(height: 80)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Priority", selection: $priority) {
                            ForEach(PlanItem.Priority.allCases, id: \.self) { p in
                                Label(p.rawValue, systemImage: p.icon)
                                    .tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Due Date
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Has Due Date", isOn: $hasDueDate)
                            .font(.system(size: 13, weight: .medium))

                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Item") {
                    onAdd(title, description, hasDueDate ? dueDate : nil, priority)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 450, height: 550)
    }
}

// MARK: - Location Section Enum
enum LocationSection: String, CaseIterable {
    case scouting = "Scouting"
    case approved = "Approved"
    case booked = "Booked"

    var icon: String {
        switch self {
        case .scouting: return "magnifyingglass"
        case .approved: return "checkmark.circle"
        case .booked: return "calendar.badge.checkmark"
        }
    }

    var color: Color {
        switch self {
        case .scouting: return .orange
        case .approved: return .blue
        case .booked: return .green
        }
    }
}

// MARK: - Characters Tab View
struct CharactersTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PlanCharacterEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PlanCharacterEntity.sortOrder, ascending: true)]
    ) private var characterEntities: FetchedResults<PlanCharacterEntity>

    @State private var showingAddSheet = false
    @State private var editingCharacter: PlanCharacterEntity?
    @State private var searchText = ""
    @State private var showingSyncConfirmation = false
    @State private var syncResult: (added: Int, updated: Int) = (0, 0)
    @State private var showingSyncResult = false

    private var filteredCharacters: [PlanCharacterEntity] {
        if searchText.isEmpty {
            return Array(characterEntities)
        }
        return characterEntities.filter { character in
            (character.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            (character.descriptionText ?? "").localizedCaseInsensitiveContains(searchText) ||
            (character.castID ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Characters")
                        .font(.system(size: 24, weight: .bold))
                    Text("Define characters and link them to casting choices")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search characters...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                .frame(width: 200)

                Button {
                    showingSyncConfirmation = true
                } label: {
                    Label("Sync from Breakdowns", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .customTooltip("Import cast members from Breakdowns")

                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Character", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding()

            Divider()

            if filteredCharacters.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "theatermasks")
                        .font(.system(size: 64))
                        .foregroundStyle(.purple.opacity(0.3))
                    Text("No Characters Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Add characters from your screenplay to track casting choices")
                        .foregroundStyle(.secondary)
                    Button("Add Character") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCharacters) { character in
                            CharacterRow(character: character, onEdit: {
                                editingCharacter = character
                            }, onDelete: {
                                deleteCharacter(character)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddCharacterSheet(isPresented: $showingAddSheet)
        }
        .sheet(item: $editingCharacter) { character in
            EditCharacterSheet(character: character, isPresented: Binding(
                get: { editingCharacter != nil },
                set: { if !$0 { editingCharacter = nil } }
            ))
        }
        .alert("Sync from Breakdowns", isPresented: $showingSyncConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sync") {
                syncResult = syncCastFromBreakdowns()
                showingSyncResult = true
            }
        } message: {
            Text("This will import cast members from Breakdowns. Existing characters with matching names will have their Cast ID updated.")
        }
        .alert("Sync Complete", isPresented: $showingSyncResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(syncResult.added) characters added, \(syncResult.updated) characters updated.")
        }
    }

    private func deleteCharacter(_ character: PlanCharacterEntity) {
        viewContext.delete(character)
        try? viewContext.save()
    }

    // MARK: - Sync from Breakdowns
    private func syncCastFromBreakdowns() -> (added: Int, updated: Int) {
        var addedCount = 0
        var updatedCount = 0

        // Fetch all scenes that have cast members
        let sceneRequest = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
        guard let scenes = try? viewContext.fetch(sceneRequest) else {
            return (0, 0)
        }

        // Collect unique cast members from all scenes
        var allCastMembers: [String: String] = [:] // name -> castID

        for scene in scenes {
            // Try to parse castMembersJSON first (new format)
            if let castJSON = scene.value(forKey: "castMembersJSON") as? String,
               let data = castJSON.data(using: .utf8) {
                // Parse the JSON array of cast members
                if let castArray = try? JSONDecoder().decode([BreakdownCastMemberSync].self, from: data) {
                    for member in castArray {
                        // Only update if we don't have this name yet, or if this has a better castID
                        if allCastMembers[member.name] == nil {
                            allCastMembers[member.name] = member.castID
                        }
                    }
                }
            }
        }

        // Now sync to PlanCharacterEntity
        for (name, castID) in allCastMembers {
            // Check if character already exists
            let existingCharacter = characterEntities.first { ($0.name ?? "").lowercased() == name.lowercased() }

            if let character = existingCharacter {
                // Update existing character's castID if different
                if character.castID != castID {
                    character.castID = castID
                    character.updatedAt = Date()
                    updatedCount += 1
                }
            } else {
                // Create new character
                let newCharacter = PlanCharacterEntity(context: viewContext)
                newCharacter.id = UUID()
                newCharacter.name = name
                newCharacter.castID = castID
                newCharacter.sortOrder = Int32(characterEntities.count + addedCount)
                newCharacter.createdAt = Date()
                newCharacter.updatedAt = Date()
                addedCount += 1
            }
        }

        try? viewContext.save()
        return (addedCount, updatedCount)
    }
}

// Helper struct for decoding cast members from Breakdowns JSON
private struct BreakdownCastMemberSync: Codable {
    var id: UUID?
    var name: String
    var castID: String
}

// MARK: - Character Row
struct CharacterRow: View {
    let character: PlanCharacterEntity
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Cast ID badge (if available)
            if let castID = character.castID, !castID.isEmpty {
                Text(castID)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple)
                    )
            } else {
                // Character icon (fallback when no castID)
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(String((character.name ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.purple)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(character.name ?? "Unnamed Character")
                        .font(.system(size: 16, weight: .semibold))

                    if let castID = character.castID, !castID.isEmpty {
                        Text("Cast #\(castID)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.purple.opacity(0.1))
                            )
                    }
                }

                if let description = character.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let age = character.age, !age.isEmpty {
                        Label(age, systemImage: "person")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let gender = character.gender, !gender.isEmpty {
                        Text(gender)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let scenes = character.sceneNumbers, !scenes.isEmpty {
                        Label("Scenes: \(scenes)", systemImage: "film")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Add Character Sheet
struct AddCharacterSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var castID = ""
    @State private var descriptionText = ""
    @State private var age = ""
    @State private var gender = ""
    @State private var traits = ""
    @State private var notes = ""
    @State private var sceneNumbers = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Character")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        FormField(label: "Name", text: $name, placeholder: "Character name")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cast ID")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("e.g., 1, 2A", text: $castID)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                                .frame(width: 80)
                        }
                    }
                    FormField(label: "Description", text: $descriptionText, placeholder: "Brief description")

                    HStack(spacing: 16) {
                        FormField(label: "Age/Age Range", text: $age, placeholder: "e.g., 30s")
                        FormField(label: "Gender", text: $gender, placeholder: "e.g., Female")
                    }

                    FormField(label: "Traits", text: $traits, placeholder: "Key personality traits")
                    FormField(label: "Scene Numbers", text: $sceneNumbers, placeholder: "e.g., 1, 3, 7, 12")
                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Character") {
                    saveCharacter()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
    }

    private func saveCharacter() {
        let character = PlanCharacterEntity(context: viewContext)
        character.id = UUID()
        character.name = name
        character.castID = castID.isEmpty ? nil : castID
        character.descriptionText = descriptionText
        character.age = age
        character.gender = gender
        character.traits = traits
        character.notes = notes
        character.sceneNumbers = sceneNumbers
        character.createdAt = Date()
        character.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Edit Character Sheet
struct EditCharacterSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    let character: PlanCharacterEntity
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var castID = ""
    @State private var descriptionText = ""
    @State private var age = ""
    @State private var gender = ""
    @State private var traits = ""
    @State private var notes = ""
    @State private var sceneNumbers = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Character")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        FormField(label: "Name", text: $name, placeholder: "Character name")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cast ID")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("e.g., 1, 2A", text: $castID)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                                .frame(width: 80)
                        }
                    }
                    FormField(label: "Description", text: $descriptionText, placeholder: "Brief description")

                    HStack(spacing: 16) {
                        FormField(label: "Age/Age Range", text: $age, placeholder: "e.g., 30s")
                        FormField(label: "Gender", text: $gender, placeholder: "e.g., Female")
                    }

                    FormField(label: "Traits", text: $traits, placeholder: "Key personality traits")
                    FormField(label: "Scene Numbers", text: $sceneNumbers, placeholder: "e.g., 1, 3, 7, 12")
                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Changes") {
                    updateCharacter()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .onAppear {
            name = character.name ?? ""
            castID = character.castID ?? ""
            descriptionText = character.descriptionText ?? ""
            age = character.age ?? ""
            gender = character.gender ?? ""
            traits = character.traits ?? ""
            notes = character.notes ?? ""
            sceneNumbers = character.sceneNumbers ?? ""
        }
    }

    private func updateCharacter() {
        character.name = name
        character.castID = castID.isEmpty ? nil : castID
        character.descriptionText = descriptionText
        character.age = age
        character.gender = gender
        character.traits = traits
        character.notes = notes
        character.sceneNumbers = sceneNumbers
        character.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Locations Tab View
struct LocationsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PlanLocationEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PlanLocationEntity.sortOrder, ascending: true)]
    ) private var locationEntities: FetchedResults<PlanLocationEntity>

    @State private var showingAddSheet = false
    @State private var editingLocation: PlanLocationEntity?
    @State private var searchText = ""
    @State private var expandedSections: Set<LocationSection> = Set(LocationSection.allCases)
    @State private var syncStatus: String?
    @State private var isSyncing = false

    private func locationsInSection(_ section: LocationSection) -> [PlanLocationEntity] {
        locationEntities.filter { ($0.section ?? "Scouting") == section.rawValue }
    }

    private var filteredLocations: [PlanLocationEntity] {
        if searchText.isEmpty {
            return Array(locationEntities)
        }
        return locationEntities.filter { location in
            (location.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            (location.address ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Locations")
                        .font(.system(size: 24, weight: .bold))
                    Text("Scout and manage filming locations")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search locations...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                .frame(width: 200)

                Button {
                    syncToLocationsApp()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Label("Sync to Locations", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isSyncing || locationEntities.isEmpty)
                .help("Sync these locations to the Locations app")

                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Location", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()

            // Sync status banner
            if let status = syncStatus {
                HStack {
                    Image(systemName: status.contains("Error") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(status.contains("Error") ? .red : .green)
                    Text(status)
                        .font(.system(size: 12))
                    Spacer()
                    Button {
                        syncStatus = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(status.contains("Error") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
            }

            Divider()

            if locationEntities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange.opacity(0.3))
                    Text("No Locations Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Add locations you're scouting for your production")
                        .foregroundStyle(.secondary)
                    Button("Add Location") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(LocationSection.allCases, id: \.self) { section in
                            LocationSectionView(
                                section: section,
                                locations: locationsInSection(section),
                                isExpanded: expandedSections.contains(section),
                                onToggle: {
                                    if expandedSections.contains(section) {
                                        expandedSections.remove(section)
                                    } else {
                                        expandedSections.insert(section)
                                    }
                                },
                                onEdit: { location in
                                    editingLocation = location
                                },
                                onDelete: { location in
                                    deleteLocation(location)
                                },
                                onUpdateSection: { location, newSection in
                                    updateLocationSection(location, to: newSection)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddLocationSheet(isPresented: $showingAddSheet)
        }
        .sheet(item: $editingLocation) { location in
            EditLocationSheet(location: location, isPresented: Binding(
                get: { editingLocation != nil },
                set: { if !$0 { editingLocation = nil } }
            ))
        }
    }

    private func deleteLocation(_ location: PlanLocationEntity) {
        viewContext.delete(location)
        try? viewContext.save()
    }

    private func updateLocationSection(_ location: PlanLocationEntity, to section: LocationSection) {
        location.section = section.rawValue
        try? viewContext.save()
    }

    // MARK: - Sync to Locations App
    private func syncToLocationsApp() {
        isSyncing = true
        syncStatus = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var addedCount = 0
            var updatedCount = 0
            let locationManager = LocationDataManager.shared

            for planLocation in locationEntities {
                let name = planLocation.name ?? ""
                let address = planLocation.address ?? ""

                // Check if location already exists in Locations app (by name and address)
                if let existingLocation = locationManager.locations.first(where: {
                    $0.name.lowercased() == name.lowercased() &&
                    $0.address.lowercased() == address.lowercased()
                }) {
                    // Update existing location
                    var updated = existingLocation
                    updated = LocationItem(
                        id: existingLocation.id,
                        name: name,
                        address: address,
                        locationInFilm: existingLocation.locationInFilm,
                        contact: planLocation.contactName ?? existingLocation.contact,
                        phone: planLocation.contactPhone ?? existingLocation.phone,
                        email: planLocation.contactEmail ?? existingLocation.email,
                        permitStatus: existingLocation.permitStatus,
                        notes: planLocation.notes ?? existingLocation.notes,
                        dateToScout: existingLocation.dateToScout,
                        scouted: existingLocation.scouted,
                        latitude: planLocation.latitude != 0 ? planLocation.latitude : existingLocation.latitude,
                        longitude: planLocation.longitude != 0 ? planLocation.longitude : existingLocation.longitude,
                        imageDatas: planLocation.imageData != nil ? [planLocation.imageData!] : existingLocation.imageDatas,
                        parkingMapImageData: existingLocation.parkingMapImageData,
                        parkingMapAnnotations: existingLocation.parkingMapAnnotations,
                        folderID: existingLocation.folderID,
                        isFavorite: existingLocation.isFavorite,
                        priority: existingLocation.priority,
                        photos: existingLocation.photos,
                        tagIDs: existingLocation.tagIDs,
                        availabilityWindows: existingLocation.availabilityWindows,
                        scoutWeather: existingLocation.scoutWeather,
                        createdAt: existingLocation.createdAt,
                        updatedAt: Date(),
                        createdBy: existingLocation.createdBy,
                        lastModifiedBy: "Plan App Sync"
                    )
                    locationManager.updateLocation(updated)
                    updatedCount += 1
                } else {
                    // Create new location
                    let newLocation = LocationItem(
                        name: name,
                        address: address,
                        contact: planLocation.contactName ?? "",
                        phone: planLocation.contactPhone ?? "",
                        email: planLocation.contactEmail ?? "",
                        permitStatus: "Pending",
                        notes: planLocation.notes ?? "",
                        latitude: planLocation.latitude != 0 ? planLocation.latitude : nil,
                        longitude: planLocation.longitude != 0 ? planLocation.longitude : nil,
                        imageDatas: planLocation.imageData != nil ? [planLocation.imageData!] : []
                    )
                    locationManager.addLocation(newLocation)
                    addedCount += 1
                }
            }

            isSyncing = false

            if addedCount > 0 || updatedCount > 0 {
                var message = "Synced to Locations app: "
                if addedCount > 0 {
                    message += "\(addedCount) added"
                }
                if updatedCount > 0 {
                    if addedCount > 0 { message += ", " }
                    message += "\(updatedCount) updated"
                }
                syncStatus = message
            } else {
                syncStatus = "No changes to sync"
            }

            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if syncStatus?.contains("Synced") == true || syncStatus == "No changes to sync" {
                    syncStatus = nil
                }
            }
        }
    }
}

// MARK: - Location Section View
struct LocationSectionView: View {
    let section: LocationSection
    let locations: [PlanLocationEntity]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEdit: (PlanLocationEntity) -> Void
    let onDelete: (PlanLocationEntity) -> Void
    let onUpdateSection: (PlanLocationEntity, LocationSection) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: section.icon)
                        .foregroundStyle(section.color)
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                    Text("(\(locations.count))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(section.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if isExpanded && !locations.isEmpty {
                VStack(spacing: 8) {
                    ForEach(locations) { location in
                        LocationRow(
                            location: location,
                            onEdit: { onEdit(location) },
                            onDelete: { onDelete(location) },
                            onUpdateSection: { newSection in onUpdateSection(location, newSection) }
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Location Row
struct LocationRow: View {
    let location: PlanLocationEntity
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onUpdateSection: (LocationSection) -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Location image or placeholder
            if let imageData = location.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 60)
                    .overlay(
                        Image(systemName: "mappin")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange.opacity(0.5))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name ?? "Unnamed Location")
                    .font(.system(size: 15, weight: .semibold))

                if let address = location.address, !address.isEmpty {
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    if location.dailyRate > 0 {
                        Label("$\(Int(location.dailyRate))/day", systemImage: "dollarsign.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let contact = location.contactName, !contact.isEmpty {
                        Label(contact, systemImage: "person")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(LocationSection.allCases, id: \.self) { section in
                            Button(section.rawValue) {
                                onUpdateSection(section)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 30)

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Add Location Sheet
struct AddLocationSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var address = ""
    @State private var descriptionText = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var contactEmail = ""
    @State private var dailyRate = ""
    @State private var notes = ""
    @State private var section: LocationSection = .scouting

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Location")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Location Name", text: $name, placeholder: "e.g., Downtown Warehouse")
                    FormField(label: "Address", text: $address, placeholder: "Full address")
                    FormField(label: "Description", text: $descriptionText, placeholder: "Describe the location")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Status", selection: $section) {
                            ForEach(LocationSection.allCases, id: \.self) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    FormField(label: "Daily Rate", text: $dailyRate, placeholder: "e.g., 500")

                    Text("Contact Information")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.top, 8)

                    FormField(label: "Contact Name", text: $contactName, placeholder: "Location manager")

                    HStack(spacing: 16) {
                        FormField(label: "Phone", text: $contactPhone, placeholder: "(555) 123-4567")
                        FormField(label: "Email", text: $contactEmail, placeholder: "email@example.com")
                    }

                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Location") {
                    saveLocation()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 550, height: 650)
    }

    private func saveLocation() {
        let location = PlanLocationEntity(context: viewContext)
        location.id = UUID()
        location.name = name
        location.address = address
        location.descriptionText = descriptionText
        location.contactName = contactName
        location.contactPhone = contactPhone
        location.contactEmail = contactEmail
        location.dailyRate = Double(dailyRate) ?? 0
        location.notes = notes
        location.section = section.rawValue
        location.createdAt = Date()
        location.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Edit Location Sheet
struct EditLocationSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    let location: PlanLocationEntity
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var address = ""
    @State private var descriptionText = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var contactEmail = ""
    @State private var dailyRate = ""
    @State private var notes = ""
    @State private var section: LocationSection = .scouting

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Location")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Location Name", text: $name, placeholder: "e.g., Downtown Warehouse")
                    FormField(label: "Address", text: $address, placeholder: "Full address")
                    FormField(label: "Description", text: $descriptionText, placeholder: "Describe the location")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Status", selection: $section) {
                            ForEach(LocationSection.allCases, id: \.self) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    FormField(label: "Daily Rate", text: $dailyRate, placeholder: "e.g., 500")

                    Text("Contact Information")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.top, 8)

                    FormField(label: "Contact Name", text: $contactName, placeholder: "Location manager")

                    HStack(spacing: 16) {
                        FormField(label: "Phone", text: $contactPhone, placeholder: "(555) 123-4567")
                        FormField(label: "Email", text: $contactEmail, placeholder: "email@example.com")
                    }

                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Changes") {
                    updateLocation()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 550, height: 650)
        .onAppear {
            name = location.name ?? ""
            address = location.address ?? ""
            descriptionText = location.descriptionText ?? ""
            contactName = location.contactName ?? ""
            contactPhone = location.contactPhone ?? ""
            contactEmail = location.contactEmail ?? ""
            dailyRate = location.dailyRate > 0 ? String(Int(location.dailyRate)) : ""
            notes = location.notes ?? ""
            section = LocationSection(rawValue: location.section ?? "Scouting") ?? .scouting
        }
    }

    private func updateLocation() {
        location.name = name
        location.address = address
        location.descriptionText = descriptionText
        location.contactName = contactName
        location.contactPhone = contactPhone
        location.contactEmail = contactEmail
        location.dailyRate = Double(dailyRate) ?? 0
        location.notes = notes
        location.section = section.rawValue
        location.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Schedule Tab View
struct ScheduleTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PlanScheduleItemEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PlanScheduleItemEntity.startDate, ascending: true)]
    ) private var scheduleItems: FetchedResults<PlanScheduleItemEntity>

    @State private var showingAddSheet = false
    @State private var editingItem: PlanScheduleItemEntity?
    @State private var selectedDate = Date()
    @State private var viewMode: ScheduleViewMode = .list

    enum ScheduleViewMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.system(size: 24, weight: .bold))
                    Text("Plan your production timeline")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("View", selection: $viewMode) {
                    ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Event", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding()

            Divider()

            if scheduleItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 64))
                        .foregroundStyle(.cyan.opacity(0.3))
                    Text("No Events Scheduled")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Add auditions, shoot days, and other important dates")
                        .foregroundStyle(.secondary)
                    Button("Add Event") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewMode {
                case .list:
                    ScheduleListView(
                        items: Array(scheduleItems),
                        onEdit: { editingItem = $0 },
                        onDelete: { deleteItem($0) }
                    )
                case .calendar:
                    ScheduleCalendarView(
                        items: Array(scheduleItems),
                        selectedDate: $selectedDate,
                        onEdit: { editingItem = $0 },
                        onDelete: { deleteItem($0) }
                    )
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddScheduleItemSheet(isPresented: $showingAddSheet)
        }
        .sheet(item: $editingItem) { item in
            EditScheduleItemSheet(item: item, isPresented: Binding(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            ))
        }
    }

    private func deleteItem(_ item: PlanScheduleItemEntity) {
        viewContext.delete(item)
        try? viewContext.save()
    }
}

// MARK: - Schedule List View
struct ScheduleListView: View {
    let items: [PlanScheduleItemEntity]
    let onEdit: (PlanScheduleItemEntity) -> Void
    let onDelete: (PlanScheduleItemEntity) -> Void

    private var groupedItems: [(Date, [PlanScheduleItemEntity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item -> Date in
            calendar.startOfDay(for: item.startDate ?? Date())
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedItems, id: \.0) { date, dayItems in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(date, style: .date)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(dayItems) { item in
                            ScheduleItemRow(item: item, onEdit: { onEdit(item) }, onDelete: { onDelete(item) })
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Schedule Item Row
struct ScheduleItemRow: View {
    let item: PlanScheduleItemEntity
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    private var itemColor: Color {
        if let hex = item.colorHex {
            return Color(hex: hex) ?? .cyan
        }
        return .cyan
    }

    var body: some View {
        HStack(spacing: 16) {
            // Time indicator
            VStack {
                if item.isAllDay {
                    Text("All Day")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if let start = item.startDate {
                    Text(start, style: .time)
                        .font(.system(size: 13, weight: .medium))
                    if let end = item.endDate {
                        Text(end, style: .time)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 70)

            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(itemColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "Untitled Event")
                    .font(.system(size: 15, weight: .semibold))

                if let category = item.category, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(itemColor.opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Schedule Calendar View
struct ScheduleCalendarView: View {
    let items: [PlanScheduleItemEntity]
    @Binding var selectedDate: Date
    let onEdit: (PlanScheduleItemEntity) -> Void
    let onDelete: (PlanScheduleItemEntity) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Calendar picker
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .frame(width: 280)
                .padding()

            Divider()

            // Events for selected date
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedDate, style: .date)
                    .font(.system(size: 18, weight: .semibold))

                let dayItems = items.filter { item in
                    guard let startDate = item.startDate else { return false }
                    return Calendar.current.isDate(startDate, inSameDayAs: selectedDate)
                }

                if dayItems.isEmpty {
                    VStack {
                        Spacer()
                        Text("No events on this day")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(dayItems) { item in
                                ScheduleItemRow(item: item, onEdit: { onEdit(item) }, onDelete: { onDelete(item) })
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Add Schedule Item Sheet
struct AddScheduleItemSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isAllDay = false
    @State private var category = ""
    @State private var notes = ""
    @State private var colorHex = "#00BCD4"

    let categories = ["Audition", "Callback", "Rehearsal", "Shoot Day", "Prep Day", "Wrap", "Meeting", "Tech Scout", "Other"]
    let colors = ["#00BCD4", "#4CAF50", "#FF9800", "#F44336", "#9C27B0", "#2196F3", "#FFEB3B"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Event")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Title", text: $title, placeholder: "Event title")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        Text(cat)
                                            .font(.system(size: 12))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(category == cat ? Color.cyan : Color.primary.opacity(0.05))
                                            .foregroundStyle(category == cat ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Toggle("All Day", isOn: $isAllDay)

                    DatePicker("Start", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])

                    if !isAllDay {
                        DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .cyan)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(colorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Event") {
                    saveItem()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func saveItem() {
        let item = PlanScheduleItemEntity(context: viewContext)
        item.id = UUID()
        item.title = title
        item.descriptionText = descriptionText
        item.startDate = startDate
        item.endDate = isAllDay ? nil : endDate
        item.isAllDay = isAllDay
        item.category = category
        item.colorHex = colorHex
        item.notes = notes
        item.createdAt = Date()
        item.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Edit Schedule Item Sheet
struct EditScheduleItemSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    let item: PlanScheduleItemEntity
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isAllDay = false
    @State private var category = ""
    @State private var notes = ""
    @State private var colorHex = "#00BCD4"

    let categories = ["Audition", "Callback", "Rehearsal", "Shoot Day", "Prep Day", "Wrap", "Meeting", "Tech Scout", "Other"]
    let colors = ["#00BCD4", "#4CAF50", "#FF9800", "#F44336", "#9C27B0", "#2196F3", "#FFEB3B"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Event")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Title", text: $title, placeholder: "Event title")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        Text(cat)
                                            .font(.system(size: 12))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(category == cat ? Color.cyan : Color.primary.opacity(0.05))
                                            .foregroundStyle(category == cat ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Toggle("All Day", isOn: $isAllDay)

                    DatePicker("Start", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])

                    if !isAllDay {
                        DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .cyan)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(colorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Changes") {
                    updateItem()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            title = item.title ?? ""
            descriptionText = item.descriptionText ?? ""
            startDate = item.startDate ?? Date()
            endDate = item.endDate ?? Date()
            isAllDay = item.isAllDay
            category = item.category ?? ""
            colorHex = item.colorHex ?? "#00BCD4"
            notes = item.notes ?? ""
        }
    }

    private func updateItem() {
        item.title = title
        item.descriptionText = descriptionText
        item.startDate = startDate
        item.endDate = isAllDay ? nil : endDate
        item.isAllDay = isAllDay
        item.category = category
        item.colorHex = colorHex
        item.notes = notes
        item.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Budget Tab View
struct BudgetTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PlanBudgetItemEntity.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \PlanBudgetItemEntity.category, ascending: true),
            NSSortDescriptor(keyPath: \PlanBudgetItemEntity.sortOrder, ascending: true)
        ]
    ) private var budgetItems: FetchedResults<PlanBudgetItemEntity>

    @State private var showingAddSheet = false
    @State private var editingItem: PlanBudgetItemEntity?
    @State private var searchText = ""

    let budgetCategories = ["Above the Line", "Production", "Post-Production", "Equipment", "Locations", "Talent", "Crew", "Catering", "Transportation", "Insurance", "Contingency", "Other"]

    private var totalEstimated: Double {
        budgetItems.reduce(0) { $0 + $1.estimatedAmount }
    }

    private var totalActual: Double {
        budgetItems.reduce(0) { $0 + $1.actualAmount }
    }

    private var groupedItems: [(String, [PlanBudgetItemEntity])] {
        let grouped = Dictionary(grouping: budgetItems) { $0.category ?? "Other" }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget")
                        .font(.system(size: 24, weight: .bold))
                    Text("Track your production expenses")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Budget summary
                HStack(spacing: 24) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Estimated")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("$\(Int(totalEstimated))")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Actual")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("$\(Int(totalActual))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(totalActual > totalEstimated ? .red : .green)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Variance")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        let variance = totalEstimated - totalActual
                        Text("\(variance >= 0 ? "+" : "")$\(Int(variance))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(variance >= 0 ? .green : .red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))

                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
            }
            .padding()

            Divider()

            if budgetItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 64))
                        .foregroundStyle(.mint.opacity(0.3))
                    Text("No Budget Items")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Add budget line items to track your production costs")
                        .foregroundStyle(.secondary)
                    Button("Add Budget Item") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(groupedItems, id: \.0) { category, items in
                            BudgetCategorySection(
                                category: category,
                                items: items,
                                onEdit: { editingItem = $0 },
                                onDelete: { deleteItem($0) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddBudgetItemSheet(isPresented: $showingAddSheet, categories: budgetCategories)
        }
        .sheet(item: $editingItem) { item in
            EditBudgetItemSheet(item: item, categories: budgetCategories, isPresented: Binding(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            ))
        }
    }

    private func deleteItem(_ item: PlanBudgetItemEntity) {
        viewContext.delete(item)
        try? viewContext.save()
    }
}

// MARK: - Budget Category Section
struct BudgetCategorySection: View {
    let category: String
    let items: [PlanBudgetItemEntity]
    let onEdit: (PlanBudgetItemEntity) -> Void
    let onDelete: (PlanBudgetItemEntity) -> Void

    @State private var isExpanded = true

    private var categoryTotal: Double {
        items.reduce(0) { $0 + $1.estimatedAmount }
    }

    private var categoryActual: Double {
        items.reduce(0) { $0 + $1.actualAmount }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(category)
                        .font(.system(size: 14, weight: .semibold))

                    Text("(\(items.count))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("$\(Int(categoryTotal))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.mint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        BudgetItemRow(item: item, onEdit: { onEdit(item) }, onDelete: { onDelete(item) })
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Budget Item Row
struct BudgetItemRow: View {
    let item: PlanBudgetItemEntity
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Paid indicator
            Circle()
                .fill(item.isPaid ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Untitled Item")
                    .font(.system(size: 14, weight: .medium))

                HStack(spacing: 12) {
                    if let vendor = item.vendorName, !vendor.isEmpty {
                        Label(vendor, systemImage: "building.2")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let dueDate = item.dueDate {
                        Text(dueDate, style: .date)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(Int(item.estimatedAmount))")
                    .font(.system(size: 14, weight: .medium))
                if item.actualAmount > 0 {
                    Text("Actual: $\(Int(item.actualAmount))")
                        .font(.system(size: 11))
                        .foregroundStyle(item.actualAmount > item.estimatedAmount ? .red : .green)
                }
            }

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Add Budget Item Sheet
struct AddBudgetItemSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    let categories: [String]

    @State private var name = ""
    @State private var category = "Production"
    @State private var subcategory = ""
    @State private var estimatedAmount = ""
    @State private var actualAmount = ""
    @State private var vendorName = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isPaid = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Budget Item")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Item Name", text: $name, placeholder: "e.g., Camera Rental")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                    }

                    FormField(label: "Subcategory", text: $subcategory, placeholder: "Optional subcategory")

                    HStack(spacing: 16) {
                        FormField(label: "Estimated ($)", text: $estimatedAmount, placeholder: "0")
                        FormField(label: "Actual ($)", text: $actualAmount, placeholder: "0")
                    }

                    FormField(label: "Vendor", text: $vendorName, placeholder: "Vendor name")

                    Toggle("Has Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }

                    Toggle("Paid", isOn: $isPaid)

                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Item") {
                    saveItem()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func saveItem() {
        let item = PlanBudgetItemEntity(context: viewContext)
        item.id = UUID()
        item.name = name
        item.category = category
        item.subcategory = subcategory
        item.estimatedAmount = Double(estimatedAmount) ?? 0
        item.actualAmount = Double(actualAmount) ?? 0
        item.vendorName = vendorName
        item.notes = notes
        item.dueDate = hasDueDate ? dueDate : nil
        item.isPaid = isPaid
        item.createdAt = Date()
        item.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Edit Budget Item Sheet
struct EditBudgetItemSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    let item: PlanBudgetItemEntity
    let categories: [String]
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var category = "Production"
    @State private var subcategory = ""
    @State private var estimatedAmount = ""
    @State private var actualAmount = ""
    @State private var vendorName = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isPaid = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Budget Item")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Item Name", text: $name, placeholder: "e.g., Camera Rental")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                    }

                    FormField(label: "Subcategory", text: $subcategory, placeholder: "Optional subcategory")

                    HStack(spacing: 16) {
                        FormField(label: "Estimated ($)", text: $estimatedAmount, placeholder: "0")
                        FormField(label: "Actual ($)", text: $actualAmount, placeholder: "0")
                    }

                    FormField(label: "Vendor", text: $vendorName, placeholder: "Vendor name")

                    Toggle("Has Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }

                    Toggle("Paid", isOn: $isPaid)

                    FormField(label: "Notes", text: $notes, placeholder: "Additional notes", isMultiline: true)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Changes") {
                    updateItem()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            name = item.name ?? ""
            category = item.category ?? "Production"
            subcategory = item.subcategory ?? ""
            estimatedAmount = item.estimatedAmount > 0 ? String(Int(item.estimatedAmount)) : ""
            actualAmount = item.actualAmount > 0 ? String(Int(item.actualAmount)) : ""
            vendorName = item.vendorName ?? ""
            notes = item.notes ?? ""
            hasDueDate = item.dueDate != nil
            dueDate = item.dueDate ?? Date()
            isPaid = item.isPaid
        }
    }

    private func updateItem() {
        item.name = name
        item.category = category
        item.subcategory = subcategory
        item.estimatedAmount = Double(estimatedAmount) ?? 0
        item.actualAmount = Double(actualAmount) ?? 0
        item.vendorName = vendorName
        item.notes = notes
        item.dueDate = hasDueDate ? dueDate : nil
        item.isPaid = isPaid
        item.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Create Tab View
struct CreateTabView: View {
    @Environment(\.managedObjectContext) private var moc

    @StateObject private var canvasViewModel = CreateCanvasViewModel()
    @StateObject private var boardViewModel = CreateBoardViewModel()

    @State private var showBoardBrowser: Bool = true
    @State private var showInspector: Bool = true
    @State private var showNewBoardSheet: Bool = false
    @State private var newBoardName: String = ""

    var body: some View {
        HSplitView {
            // Left: Board Browser Sidebar
            if showBoardBrowser {
                CreateBoardBrowser(
                    boardViewModel: boardViewModel,
                    onSelectBoard: { id in
                        canvasViewModel.loadBoard(id)
                    }
                )
                .frame(minWidth: 200, maxWidth: 280)
            }

            // Center: Canvas Area
            VStack(spacing: 0) {
                CreateToolbar(
                    canvasViewModel: canvasViewModel,
                    showBoardBrowser: $showBoardBrowser,
                    showInspector: $showInspector
                )

                Divider()

                ZStack {
                    CreateCanvasView(viewModel: canvasViewModel)

                    // Minimap overlay (bottom-right)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            CreateMinimap(viewModel: canvasViewModel)
                                .frame(width: 150, height: 100)
                                .padding()
                        }
                    }
                }
            }
            .frame(minWidth: 500)

            // Right: Inspector
            if showInspector {
                CreateInspector(viewModel: canvasViewModel)
                    .frame(minWidth: 280, maxWidth: 350)
            }
        }
        .onAppear {
            canvasViewModel.configure(with: moc)
            boardViewModel.configure(with: moc)
            boardViewModel.ensureDefaultBoard()

            if let firstBoard = boardViewModel.rootBoards.first {
                canvasViewModel.loadBoard(firstBoard.id)
            }
        }
        .undoRedoSupport(
            canUndo: canvasViewModel.undoRedoManager.canUndo,
            canRedo: canvasViewModel.undoRedoManager.canRedo,
            onUndo: canvasViewModel.performUndo,
            onRedo: canvasViewModel.performRedo
        )
        .sheet(isPresented: $showNewBoardSheet) {
            VStack(spacing: 20) {
                Text("New Board")
                    .font(.headline)

                TextField("Board Name", text: $newBoardName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                HStack(spacing: 16) {
                    Button("Cancel") {
                        newBoardName = ""
                        showNewBoardSheet = false
                    }

                    Button("Create") {
                        let id = boardViewModel.createBoard(name: newBoardName.isEmpty ? "Untitled Board" : newBoardName)
                        canvasViewModel.loadBoard(id)
                        newBoardName = ""
                        showNewBoardSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(30)
            .frame(width: 320)
        }
    }
}

// MARK: - Form Field Helper
struct FormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var isMultiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            if isMultiline {
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
        }
    }
}

#Preview {
    PlanView()
}

#else
// MARK: - iOS Placeholder
struct PlanView: View {
    var body: some View {
        Text("Plan view is only available on macOS")
            .foregroundStyle(.secondary)
    }
}
#endif
