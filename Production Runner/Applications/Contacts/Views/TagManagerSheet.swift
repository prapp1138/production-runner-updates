//
//  TagManagerSheet.swift
//  Production Runner
//
//  Manages contact tags: create, edit, delete, and color assignment.
//

import SwiftUI
import CoreData

// MARK: - Tag Model
struct ContactTag: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var sortOrder: Int16 = 0
    var createdAt: Date = Date()

    var color: Color {
        Color(hex: colorHex) ?? .purple
    }

    static let defaultColors: [String] = [
        "#FF6B6B", // Red
        "#4ECDC4", // Teal
        "#45B7D1", // Blue
        "#96CEB4", // Green
        "#FFEAA7", // Yellow
        "#DDA0DD", // Plum
        "#98D8C8", // Mint
        "#F7DC6F", // Gold
        "#BB8FCE", // Lavender
        "#85C1E9"  // Sky Blue
    ]
}

// MARK: - Tag Manager Sheet (macOS)
#if os(macOS)
struct TagManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var tags: [ContactTag] = []
    @State private var newTagName: String = ""
    @State private var selectedColor: String = ContactTag.defaultColors[0]
    @State private var editingTag: ContactTag? = nil
    @State private var showingDeleteConfirmation: Bool = false
    @State private var tagToDelete: ContactTag? = nil

    private let entityName = "ContactTagEntity"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Tags")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color.primary.opacity(0.03))

            Divider()

            // Add New Tag Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Create New Tag")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    TextField("Tag name", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)

                    // Color picker
                    HStack(spacing: 4) {
                        ForEach(ContactTag.defaultColors.prefix(5), id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == colorHex ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                }
                        }

                        Menu {
                            ForEach(ContactTag.defaultColors.dropFirst(5), id: \.self) { colorHex in
                                Button(action: { selectedColor = colorHex }) {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: colorHex) ?? .gray)
                                            .frame(width: 12, height: 12)
                                        Text("Color")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 24)
                    }

                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()

            Divider()

            // Existing Tags List
            if tags.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tag")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No tags yet")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("Create tags to organize your contacts")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tags) { tag in
                            tagRow(tag)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 450, height: 400)
        .onAppear { loadTags() }
        .alert("Delete Tag?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    deleteTag(tag)
                }
            }
        } message: {
            Text("This will remove the tag from all contacts. This action cannot be undone.")
        }
    }

    private func tagRow(_ tag: ContactTag) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tag.color)
                .frame(width: 16, height: 16)

            if editingTag?.id == tag.id {
                TextField("Tag name", text: Binding(
                    get: { editingTag?.name ?? "" },
                    set: { editingTag?.name = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 150)
                .onSubmit { saveEditingTag() }

                // Color selection for editing
                HStack(spacing: 4) {
                    ForEach(ContactTag.defaultColors.prefix(5), id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex) ?? .gray)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(editingTag?.colorHex == colorHex ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                editingTag?.colorHex = colorHex
                            }
                    }
                }

                Button("Save") { saveEditingTag() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button("Cancel") { editingTag = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Text(tag.name)
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Button(action: { editingTag = tag }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: {
                    tagToDelete = tag
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Core Data Operations

    private func loadTags() {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try context.fetch(request)
            tags = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }
                let colorHex = (mo.value(forKey: "colorHex") as? String) ?? ContactTag.defaultColors[0]
                let sortOrder = (mo.value(forKey: "sortOrder") as? Int16) ?? 0
                let createdAt = (mo.value(forKey: "createdAt") as? Date) ?? Date()
                return ContactTag(id: id, name: name, colorHex: colorHex, sortOrder: sortOrder, createdAt: createdAt)
            }
        } catch {
            print("Failed to load tags: \(error)")
        }
    }

    private func addTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { return }
        let mo = NSManagedObject(entity: entity, insertInto: context)

        let newTag = ContactTag(
            id: UUID(),
            name: trimmedName,
            colorHex: selectedColor,
            sortOrder: Int16(tags.count),
            createdAt: Date()
        )

        mo.setValue(newTag.id, forKey: "id")
        mo.setValue(newTag.name, forKey: "name")
        mo.setValue(newTag.colorHex, forKey: "colorHex")
        mo.setValue(newTag.sortOrder, forKey: "sortOrder")
        mo.setValue(newTag.createdAt, forKey: "createdAt")

        do {
            try context.save()
            tags.append(newTag)
            newTagName = ""
            selectedColor = ContactTag.defaultColors.randomElement() ?? ContactTag.defaultColors[0]
            NotificationCenter.default.post(name: .tagsDidChange, object: nil)
        } catch {
            print("Failed to save tag: \(error)")
        }
    }

    private func saveEditingTag() {
        guard let tag = editingTag else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                mo.setValue(tag.name, forKey: "name")
                mo.setValue(tag.colorHex, forKey: "colorHex")
                try context.save()

                if let index = tags.firstIndex(where: { $0.id == tag.id }) {
                    tags[index] = tag
                }
                NotificationCenter.default.post(name: .tagsDidChange, object: nil)
            }
        } catch {
            print("Failed to update tag: \(error)")
        }

        editingTag = nil
    }

    private func deleteTag(_ tag: ContactTag) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                context.delete(mo)
                try context.save()
                tags.removeAll { $0.id == tag.id }
                NotificationCenter.default.post(name: .tagsDidChange, object: nil)
            }
        } catch {
            print("Failed to delete tag: \(error)")
        }
    }
}

#elseif os(iOS)
struct TagManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var tags: [ContactTag] = []
    @State private var newTagName: String = ""
    @State private var selectedColor: String = ContactTag.defaultColors[0]
    @State private var editingTag: ContactTag? = nil
    @State private var showingDeleteConfirmation: Bool = false
    @State private var tagToDelete: ContactTag? = nil

    private let entityName = "ContactTagEntity"

    var body: some View {
        NavigationStack {
            List {
                // Create New Tag Section
                Section {
                    HStack(spacing: 12) {
                        TextField("New tag name", text: $newTagName)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(ContactTag.defaultColors, id: \.self) { colorHex in
                                    Circle()
                                        .fill(Color(hex: colorHex) ?? .gray)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == colorHex ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            selectedColor = colorHex
                                        }
                                }
                            }
                        }
                        .frame(width: 120)

                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Create Tag")
                }

                // Existing Tags
                Section {
                    if tags.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text("No tags yet")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(tags) { tag in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 16, height: 16)

                                Text(tag.name)
                                    .font(.system(size: 16))

                                Spacer()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    tagToDelete = tag
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingTag = tag
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                } header: {
                    Text("Your Tags")
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadTags() }
            .alert("Delete Tag?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let tag = tagToDelete {
                        deleteTag(tag)
                    }
                }
            } message: {
                Text("This will remove the tag from all contacts.")
            }
            .sheet(item: $editingTag) { tag in
                editTagSheet(tag)
            }
        }
    }

    private func editTagSheet(_ tag: ContactTag) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: Binding(
                        get: { editingTag?.name ?? tag.name },
                        set: { editingTag?.name = $0 }
                    ))
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(ContactTag.defaultColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(editingTag?.colorHex == colorHex ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    editingTag?.colorHex = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingTag = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEditingTag() }
                }
            }
        }
    }

    // MARK: - Core Data Operations

    private func loadTags() {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try context.fetch(request)
            tags = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }
                let colorHex = (mo.value(forKey: "colorHex") as? String) ?? ContactTag.defaultColors[0]
                let sortOrder = (mo.value(forKey: "sortOrder") as? Int16) ?? 0
                let createdAt = (mo.value(forKey: "createdAt") as? Date) ?? Date()
                return ContactTag(id: id, name: name, colorHex: colorHex, sortOrder: sortOrder, createdAt: createdAt)
            }
        } catch {
            print("Failed to load tags: \(error)")
        }
    }

    private func addTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { return }
        let mo = NSManagedObject(entity: entity, insertInto: context)

        let newTag = ContactTag(
            id: UUID(),
            name: trimmedName,
            colorHex: selectedColor,
            sortOrder: Int16(tags.count),
            createdAt: Date()
        )

        mo.setValue(newTag.id, forKey: "id")
        mo.setValue(newTag.name, forKey: "name")
        mo.setValue(newTag.colorHex, forKey: "colorHex")
        mo.setValue(newTag.sortOrder, forKey: "sortOrder")
        mo.setValue(newTag.createdAt, forKey: "createdAt")

        do {
            try context.save()
            tags.append(newTag)
            newTagName = ""
            selectedColor = ContactTag.defaultColors.randomElement() ?? ContactTag.defaultColors[0]
            NotificationCenter.default.post(name: .tagsDidChange, object: nil)
        } catch {
            print("Failed to save tag: \(error)")
        }
    }

    private func saveEditingTag() {
        guard let tag = editingTag else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                mo.setValue(tag.name, forKey: "name")
                mo.setValue(tag.colorHex, forKey: "colorHex")
                try context.save()

                if let index = tags.firstIndex(where: { $0.id == tag.id }) {
                    tags[index] = tag
                }
                NotificationCenter.default.post(name: .tagsDidChange, object: nil)
            }
        } catch {
            print("Failed to update tag: \(error)")
        }

        editingTag = nil
    }

    private func deleteTag(_ tag: ContactTag) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                context.delete(mo)
                try context.save()
                tags.removeAll { $0.id == tag.id }
                NotificationCenter.default.post(name: .tagsDidChange, object: nil)
            }
        } catch {
            print("Failed to delete tag: \(error)")
        }
    }
}
#endif

// MARK: - Notification for Tag Changes
extension Notification.Name {
    static let tagsDidChange = Notification.Name("tagsDidChange")
}

// MARK: - Tag Pill View
struct TagPillView: View {
    let tagName: String
    let color: Color
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(tagName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .clipShape(Capsule())
    }
}

// MARK: - Tag Assignment Popover (macOS)
#if os(macOS)
struct TagAssignmentView: View {
    @Environment(\.managedObjectContext) private var context
    @Binding var selectedTags: [String]
    @State private var availableTags: [ContactTag] = []
    @State private var showingTagManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showingTagManager = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if availableTags.isEmpty {
                VStack(spacing: 8) {
                    Text("No tags created yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Button("Create Tags") { showingTagManager = true }
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                        .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                // Current tags
                if !selectedTags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(selectedTags, id: \.self) { tagName in
                            if let tag = availableTags.first(where: { $0.name == tagName }) {
                                TagPillView(tagName: tagName, color: tag.color) {
                                    selectedTags.removeAll { $0 == tagName }
                                }
                            }
                        }
                    }
                }

                // Available tags to add
                let unassignedTags = availableTags.filter { !selectedTags.contains($0.name) }
                if !unassignedTags.isEmpty {
                    Divider()
                    Text("Add tag:")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    FlowLayout(spacing: 6) {
                        ForEach(unassignedTags) { tag in
                            Button(action: { selectedTags.append(tag.name) }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 8, height: 8)
                                    Text(tag.name)
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear { loadTags() }
        .onReceive(NotificationCenter.default.publisher(for: .tagsDidChange)) { _ in
            loadTags()
        }
        .sheet(isPresented: $showingTagManager) {
            TagManagerSheet()
        }
    }

    private func loadTags() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactTagEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try context.fetch(request)
            availableTags = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }
                let colorHex = (mo.value(forKey: "colorHex") as? String) ?? ContactTag.defaultColors[0]
                let sortOrder = (mo.value(forKey: "sortOrder") as? Int16) ?? 0
                return ContactTag(id: id, name: name, colorHex: colorHex, sortOrder: sortOrder)
            }
        } catch {
            print("Failed to load tags: \(error)")
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
#endif

// MARK: - Tag Assignment View (iOS)
#if os(iOS)
struct TagAssignmentView: View {
    @Environment(\.managedObjectContext) private var context
    @Binding var selectedTags: [String]
    @State private var availableTags: [ContactTag] = []
    @State private var showingTagManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.purple)
                    .frame(width: 24)

                Text("Tags")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { showingTagManager = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            if availableTags.isEmpty {
                Button("Create tags to organize contacts") {
                    showingTagManager = true
                }
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .padding(.leading, 34)
            } else {
                // Current tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedTags, id: \.self) { tagName in
                            if let tag = availableTags.first(where: { $0.name == tagName }) {
                                TagPillView(tagName: tagName, color: tag.color) {
                                    selectedTags.removeAll { $0 == tagName }
                                }
                            }
                        }

                        // Add tag button
                        Menu {
                            let unassignedTags = availableTags.filter { !selectedTags.contains($0.name) }
                            ForEach(unassignedTags) { tag in
                                Button(action: { selectedTags.append(tag.name) }) {
                                    Label(tag.name, systemImage: "tag")
                                }
                            }
                            Divider()
                            Button(action: { showingTagManager = true }) {
                                Label("Manage Tags", systemImage: "gear")
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.leading, 34)
            }
        }
        .onAppear { loadTags() }
        .onReceive(NotificationCenter.default.publisher(for: .tagsDidChange)) { _ in
            loadTags()
        }
        .sheet(isPresented: $showingTagManager) {
            TagManagerSheet()
        }
    }

    private func loadTags() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactTagEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try context.fetch(request)
            availableTags = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }
                let colorHex = (mo.value(forKey: "colorHex") as? String) ?? ContactTag.defaultColors[0]
                let sortOrder = (mo.value(forKey: "sortOrder") as? Int16) ?? 0
                return ContactTag(id: id, name: name, colorHex: colorHex, sortOrder: sortOrder)
            }
        } catch {
            print("Failed to load tags: \(error)")
        }
    }
}
#endif
