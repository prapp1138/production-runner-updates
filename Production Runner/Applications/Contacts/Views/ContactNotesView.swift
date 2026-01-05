//
//  ContactNotesView.swift
//  Production Runner
//
//  Manages timestamped notes/comments for contacts.
//

import SwiftUI
import CoreData

// MARK: - Note Model
struct ContactNote: Identifiable, Equatable {
    let id: UUID
    let contactID: UUID
    var content: String
    var noteType: NoteType
    var authorName: String?
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    enum NoteType: String, CaseIterable {
        case general = "General"
        case callLog = "Call Log"
        case meeting = "Meeting"
        case reminder = "Reminder"

        var icon: String {
            switch self {
            case .general: return "note.text"
            case .callLog: return "phone.arrow.up.right"
            case .meeting: return "person.2"
            case .reminder: return "bell"
            }
        }

        var color: Color {
            switch self {
            case .general: return .blue
            case .callLog: return .green
            case .meeting: return .purple
            case .reminder: return .orange
            }
        }
    }
}

// MARK: - Notes Service
class ContactNotesService {
    static let shared = ContactNotesService()
    private let entityName = "ContactNoteEntity"

    private init() {}

    func fetchNotes(for contactID: UUID, context: NSManagedObjectContext) -> [ContactNote] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "contactID == %@", contactID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            let results = try context.fetch(request)
            return results.compactMap { mo -> ContactNote? in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let cID = mo.value(forKey: "contactID") as? UUID,
                      let content = mo.value(forKey: "content") as? String,
                      let createdAt = mo.value(forKey: "createdAt") as? Date,
                      let updatedAt = mo.value(forKey: "updatedAt") as? Date else {
                    return nil
                }

                let typeRaw = (mo.value(forKey: "noteType") as? String) ?? "General"
                let noteType = ContactNote.NoteType(rawValue: typeRaw) ?? .general

                return ContactNote(
                    id: id,
                    contactID: cID,
                    content: content,
                    noteType: noteType,
                    authorName: mo.value(forKey: "authorName") as? String,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    isPinned: (mo.value(forKey: "isPinned") as? Bool) ?? false
                )
            }
        } catch {
            print("Failed to fetch notes: \(error)")
            return []
        }
    }

    func addNote(
        contactID: UUID,
        content: String,
        noteType: ContactNote.NoteType = .general,
        context: NSManagedObjectContext
    ) -> ContactNote? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            return nil
        }

        let now = Date()
        let id = UUID()
        let mo = NSManagedObject(entity: entity, insertInto: context)

        mo.setValue(id, forKey: "id")
        mo.setValue(contactID, forKey: "contactID")
        mo.setValue(content, forKey: "content")
        mo.setValue(noteType.rawValue, forKey: "noteType")
        mo.setValue(getCurrentUser(), forKey: "authorName")
        mo.setValue(now, forKey: "createdAt")
        mo.setValue(now, forKey: "updatedAt")
        mo.setValue(false, forKey: "isPinned")

        do {
            try context.save()
            return ContactNote(
                id: id,
                contactID: contactID,
                content: content,
                noteType: noteType,
                authorName: getCurrentUser(),
                createdAt: now,
                updatedAt: now,
                isPinned: false
            )
        } catch {
            print("Failed to save note: \(error)")
            return nil
        }
    }

    func updateNote(_ note: ContactNote, context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                mo.setValue(note.content, forKey: "content")
                mo.setValue(note.noteType.rawValue, forKey: "noteType")
                mo.setValue(note.isPinned, forKey: "isPinned")
                mo.setValue(Date(), forKey: "updatedAt")
                try context.save()
            }
        } catch {
            print("Failed to update note: \(error)")
        }
    }

    func deleteNote(_ note: ContactNote, context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                context.delete(mo)
                try context.save()
            }
        } catch {
            print("Failed to delete note: \(error)")
        }
    }

    func togglePin(_ note: ContactNote, context: NSManagedObjectContext) {
        var updated = note
        updated.isPinned.toggle()
        updateNote(updated, context: context)
    }

    private func getCurrentUser() -> String {
        #if os(macOS)
        return NSFullUserName()
        #else
        return UIDevice.current.name
        #endif
    }
}

// MARK: - Notes View (macOS)
#if os(macOS)
struct ContactNotesView: View {
    let contactID: UUID
    @Environment(\.managedObjectContext) private var context
    @State private var notes: [ContactNote] = []
    @State private var isExpanded = true
    @State private var newNoteContent = ""
    @State private var newNoteType: ContactNote.NoteType = .general
    @State private var editingNote: ContactNote? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("Notes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if !notes.isEmpty {
                    Text("\(notes.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue))
                }

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                // Add note input
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(ContactNote.NoteType.allCases, id: \.self) { type in
                                Button(action: { newNoteType = type }) {
                                    Label(type.rawValue, systemImage: type.icon)
                                }
                            }
                        } label: {
                            Image(systemName: newNoteType.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(newNoteType.color)
                                .frame(width: 24, height: 24)
                                .background(newNoteType.color.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        TextField("Add a note...", text: $newNoteContent)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        Button(action: addNote) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(newNoteContent.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Notes list
                if notes.isEmpty {
                    Text("No notes yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(notes) { note in
                                noteRow(note)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .onAppear { loadNotes() }
    }

    private func noteRow(_ note: ContactNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: note.noteType.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(note.noteType.color)

                Text(note.noteType.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(note.noteType.color)

                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text(note.createdAt, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Menu {
                    Button(action: { togglePin(note) }) {
                        Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                    }
                    Button(action: { editingNote = note }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive, action: { deleteNote(note) }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(note.content)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(3)

            if let author = note.authorName, !author.isEmpty {
                Text("— \(author)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(note.isPinned ? Color.orange.opacity(0.05) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(note.isPinned ? Color.orange.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    private func loadNotes() {
        notes = ContactNotesService.shared.fetchNotes(for: contactID, context: context)
    }

    private func addNote() {
        let content = newNoteContent.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        if let note = ContactNotesService.shared.addNote(
            contactID: contactID,
            content: content,
            noteType: newNoteType,
            context: context
        ) {
            notes.insert(note, at: 0)
            newNoteContent = ""
        }
    }

    private func togglePin(_ note: ContactNote) {
        ContactNotesService.shared.togglePin(note, context: context)
        loadNotes()
    }

    private func deleteNote(_ note: ContactNote) {
        ContactNotesService.shared.deleteNote(note, context: context)
        notes.removeAll { $0.id == note.id }
    }
}

#elseif os(iOS)
struct ContactNotesView: View {
    let contactID: UUID
    @Environment(\.managedObjectContext) private var context
    @State private var notes: [ContactNote] = []
    @State private var isExpanded = false
    @State private var showingAddNote = false
    @State private var newNoteContent = ""
    @State private var newNoteType: ContactNote.NoteType = .general

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)
                        .frame(width: 24)

                    Text("Notes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !notes.isEmpty {
                        Text("\(notes.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Add note button
                Button(action: { showingAddNote = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Add Note")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.leading, 34)

                // Notes list
                if notes.isEmpty {
                    Text("No notes yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 34)
                } else {
                    VStack(spacing: 6) {
                        ForEach(notes.prefix(5)) { note in
                            noteRow(note)
                        }

                        if notes.count > 5 {
                            Text("+ \(notes.count - 5) more notes")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 34)
                        }
                    }
                }
            }
        }
        .onAppear { loadNotes() }
        .sheet(isPresented: $showingAddNote) {
            addNoteSheet
        }
    }

    private func noteRow(_ note: ContactNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: note.noteType.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(note.noteType.color)

                Text(note.noteType.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(note.noteType.color)

                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text(note.createdAt, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Text(note.content)
                .font(.system(size: 12))
                .lineLimit(2)
        }
        .padding(8)
        .background(note.isPinned ? Color.orange.opacity(0.05) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 34)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteNote(note)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                togglePin(note)
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
    }

    private var addNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Note Type") {
                    Picker("Type", selection: $newNoteType) {
                        ForEach(ContactNote.NoteType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Content") {
                    TextEditor(text: $newNoteContent)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddNote = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addNote()
                        showingAddNote = false
                    }
                    .disabled(newNoteContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func loadNotes() {
        notes = ContactNotesService.shared.fetchNotes(for: contactID, context: context)
    }

    private func addNote() {
        let content = newNoteContent.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        if let note = ContactNotesService.shared.addNote(
            contactID: contactID,
            content: content,
            noteType: newNoteType,
            context: context
        ) {
            notes.insert(note, at: 0)
            newNoteContent = ""
        }
    }

    private func togglePin(_ note: ContactNote) {
        ContactNotesService.shared.togglePin(note, context: context)
        loadNotes()
    }

    private func deleteNote(_ note: ContactNote) {
        ContactNotesService.shared.deleteNote(note, context: context)
        notes.removeAll { $0.id == note.id }
    }
}
#endif
