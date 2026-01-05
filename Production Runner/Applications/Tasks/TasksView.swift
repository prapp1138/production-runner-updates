import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Tasks View
struct TasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)],
        animation: .default)
    private var tasks: FetchedResults<TaskEntity>

    @State private var showingAddTask = false
    @State private var showingEditTask = false
    @State private var editingTask: TaskEntity?
    @State private var searchText = ""
    @State private var filterCompleted = false
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var copiedTasks: [TaskEntity] = []
    @State private var showBottomPane = false
    @State private var showAssignmentPicker = false
    @State private var availableContacts: [TaskContactData] = []

    // Undo/Redo - uses Core Data's built-in undo manager
    @Environment(\.undoManager) private var undoManager

    var unassignedTasks: [TaskEntity] {
        let filtered = tasks.filter { task in
            (task.assignedTo == nil || task.assignedTo?.isEmpty == true) &&
            (!filterCompleted || !task.isCompleted) &&
            (searchText.isEmpty || (task.title ?? "").localizedCaseInsensitiveContains(searchText))
        }
        return Array(filtered)
    }

    var assignedTasks: [TaskEntity] {
        let filtered = tasks.filter { task in
            task.assignedTo != nil && !task.assignedTo!.isEmpty &&
            (!filterCompleted || !task.isCompleted) &&
            (searchText.isEmpty || (task.title ?? "").localizedCaseInsensitiveContains(searchText))
        }
        return Array(filtered)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Toolbar
                toolbar

                Divider()

                // Split view: Tasks | Assigned Tasks
                HStack(spacing: 0) {
                    // Left pane: Unassigned Tasks
                    VStack(spacing: 0) {
                        // Left pane header
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.blue)
                                Text("Tasks")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Spacer()
                            Text("\(unassignedTasks.count)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.03))

                        Divider()

                        // Left pane content
                        ScrollView {
                            VStack(spacing: 8) {
                                if unassignedTasks.isEmpty {
                                    EmptyTasksView(message: "No tasks")
                                } else {
                                    ForEach(unassignedTasks, id: \.id) { task in
                                        TaskRowView(
                                            task: task,
                                            isSelected: selectedTaskIDs.contains(task.id ?? UUID()),
                                            onTap: {
                                                if let id = task.id {
                                                    if selectedTaskIDs.contains(id) {
                                                        selectedTaskIDs.remove(id)
                                                    } else {
                                                        selectedTaskIDs.insert(id)
                                                    }
                                                }
                                            },
                                            onToggle: { toggleTaskCompletion(task) }
                                        )
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                    .frame(width: geometry.size.width / 2)

                    Divider()

                    // Right pane: Assigned Tasks
                    VStack(spacing: 0) {
                        // Right pane header
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill.checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.green)
                                Text("Assigned Tasks")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Spacer()
                            Text("\(assignedTasks.count)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.03))

                        Divider()

                        // Right pane content
                        ScrollView {
                            VStack(spacing: 8) {
                                if assignedTasks.isEmpty {
                                    EmptyTasksView(message: "No assigned tasks")
                                } else {
                                    ForEach(assignedTasks, id: \.id) { task in
                                        TaskRowView(
                                            task: task,
                                            isSelected: selectedTaskIDs.contains(task.id ?? UUID()),
                                            onTap: {
                                                if let id = task.id {
                                                    if selectedTaskIDs.contains(id) {
                                                        selectedTaskIDs.remove(id)
                                                    } else {
                                                        selectedTaskIDs.insert(id)
                                                    }
                                                }
                                            },
                                            onToggle: { toggleTaskCompletion(task) }
                                        )
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                    .frame(width: geometry.size.width / 2)
                }

                // Bottom popup pane
                if showBottomPane {
                    VStack(spacing: 0) {
                        Divider()
                        bottomPane
                    }
                    .frame(height: geometry.size.height * 0.3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
#else
        .background(Color(UIColor.systemBackground))
#endif
        .sheet(isPresented: $showingAddTask) {
            AddEditTaskView(
                existingTask: nil,
                onSave: { title, notes, reminderDate, assignedTo in
                    createTask(title: title, notes: notes, reminderDate: reminderDate, assignedTo: assignedTo)
                }
            )
        }
        .sheet(isPresented: $showingEditTask) {
            if let task = editingTask {
                AddEditTaskView(
                    existingTask: task,
                    onSave: { title, notes, reminderDate, assignedTo in
                        updateTask(task, title: title, notes: notes, reminderDate: reminderDate, assignedTo: assignedTo)
                    }
                )
            }
        }
        .sheet(isPresented: $showAssignmentPicker) {
            TaskAssignmentPickerSheet(
                contacts: availableContacts,
                onSelect: { selectedContact in
                    assignTasksToContact(selectedContact)
                    showAssignmentPicker = false
                },
                onCancel: { showAssignmentPicker = false }
            )
        }
        #if os(macOS)
        .onAppear {
            viewContext.undoManager = undoManager
        }
        .onReceive(NotificationCenter.default.publisher(for: .prUndo)) { _ in
            undoManager?.undo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prRedo)) { _ in
            undoManager?.redo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
            handleCut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
            handleCopy()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
            handlePaste()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
            handleDelete()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
            selectAllTasks()
        }
        #endif
    }

    #if os(macOS)
    private func selectAllTasks() {
        var allIDs: Set<UUID> = []
        for task in tasks {
            if let id = task.id {
                allIDs.insert(id)
            }
        }
        selectedTaskIDs = allIDs
    }
    #endif

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: 12) {
            // Left side: New Task button and search
            HStack(spacing: 12) {
                // New Task button (moved here)
                Button {
                    showingAddTask = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("New Task")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: [.command])

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("Search tasks...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.1))
                )
                .frame(width: 200)
            }

            Spacer()

            // Center: Action buttons
            HStack(spacing: 8) {
                toolbarButton(icon: "scissors", label: "Cut", action: handleCut)
                toolbarButton(icon: "doc.on.doc", label: "Copy", action: handleCopy)
                toolbarButton(icon: "doc.on.clipboard", label: "Paste", action: handlePaste)
                toolbarButton(icon: "trash", label: "Delete", color: .red, action: handleDelete)

                Divider()
                    .frame(height: 20)

                toolbarButton(icon: "person.fill.badge.plus", label: "Assign", color: .green) {
                    loadContactsForAssignment()
                    showAssignmentPicker = true
                }
            }

            Spacer()

            // Right side: Options
            HStack(spacing: 8) {
                Button(action: { showBottomPane.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: showBottomPane ? "info.circle.fill" : "info.circle")
                            .font(.system(size: 11, weight: .medium))
                        Text("Details")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(showBottomPane ? .white : .blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showBottomPane ? Color.blue : Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)

                // Hide Completed button (colored style)
                Button(action: { filterCompleted.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: filterCompleted ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("Hide Completed")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(filterCompleted ? .white : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(filterCompleted ? Color.orange : Color.orange.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
    }

    private func toolbarButton(icon: String, label: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
    }

    // MARK: - Bottom Pane
    private var bottomPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Task Details")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: { showBottomPane = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            ScrollView {
                if selectedTaskIDs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Select a task to view details")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(selectedTasks, id: \.id) { task in
                            TaskDetailView(task: task)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    private var selectedTasks: [TaskEntity] {
        tasks.filter { selectedTaskIDs.contains($0.id ?? UUID()) }
    }

    // MARK: - Actions
    private func handleCut() {
        handleCopy()
        handleDelete()
    }

    private func handleCopy() {
        copiedTasks = selectedTasks
    }

    private func handlePaste() {
        guard !copiedTasks.isEmpty else { return }

        withAnimation {
            for task in copiedTasks {
                let newTask = TaskEntity(context: viewContext)
                newTask.id = UUID()
                newTask.title = task.title
                newTask.notes = task.notes
                newTask.isCompleted = false
                newTask.createdAt = Date()
                newTask.reminderDate = task.reminderDate
                newTask.assignedTo = task.assignedTo
            }

            do {
                try viewContext.save()
            } catch {
                print("Error pasting tasks: \(error)")
            }
        }
    }

    private func handleDelete() {
        guard !selectedTaskIDs.isEmpty else { return }

        withAnimation {
            for task in selectedTasks {
                viewContext.delete(task)
            }

            selectedTaskIDs.removeAll()

            do {
                try viewContext.save()
            } catch {
                print("Error deleting tasks: \(error)")
            }
        }
    }

    private func loadContactsForAssignment() {
        availableContacts = []

        let req = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        if let contacts = try? viewContext.fetch(req) {
            availableContacts = contacts.compactMap { contact -> TaskContactData? in
                let name = (contact.value(forKey: "name") as? String) ?? ""
                guard !name.isEmpty else { return nil }

                return TaskContactData(
                    id: contact.objectID,
                    name: name,
                    role: (contact.value(forKey: "role") as? String) ?? "",
                    phone: (contact.value(forKey: "phone") as? String) ?? "",
                    email: (contact.value(forKey: "email") as? String) ?? "",
                    category: (contact.value(forKey: "category") as? String) ?? ""
                )
            }
        }
    }

    private func assignTasksToContact(_ contact: TaskContactData) {
        guard !selectedTaskIDs.isEmpty else { return }

        withAnimation {
            for task in selectedTasks {
                task.assignedTo = contact.name
            }

            do {
                try viewContext.save()
                // Send notification for each assigned task
                for task in selectedTasks {
                    NotificationManager.shared.notifyTaskAssigned(
                        taskName: task.title ?? "Untitled Task",
                        assignedBy: AuthService.shared.currentUser?.displayName ?? "Someone"
                    )
                }
            } catch {
                print("Error assigning tasks: \(error)")
            }
        }
    }

    // MARK: - Task Operations
    private func createTask(title: String, notes: String?, reminderDate: Date?, assignedTo: String?) {
        withAnimation {
            let newTask = TaskEntity(context: viewContext)
            newTask.id = UUID()
            newTask.title = title
            newTask.notes = notes
            newTask.isCompleted = false
            newTask.createdAt = Date()
            newTask.reminderDate = reminderDate
            newTask.assignedTo = assignedTo

            do {
                try viewContext.save()
                // Send notification if task is assigned to someone
                if let assignee = assignedTo, !assignee.isEmpty {
                    NotificationManager.shared.notifyTaskAssigned(
                        taskName: title,
                        assignedBy: AuthService.shared.currentUser?.displayName ?? "You"
                    )
                }
            } catch {
                print("Error creating task: \(error)")
            }
        }
    }

    private func updateTask(_ task: TaskEntity, title: String, notes: String?, reminderDate: Date?, assignedTo: String?) {
        withAnimation {
            task.title = title
            task.notes = notes
            task.reminderDate = reminderDate
            task.assignedTo = assignedTo

            do {
                try viewContext.save()
            } catch {
                print("Error updating task: \(error)")
            }
        }
        showingEditTask = false
        editingTask = nil
    }

    private func toggleTaskCompletion(_ task: TaskEntity) {
        withAnimation {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil

            do {
                try viewContext.save()
            } catch {
                print("Error toggling task: \(error)")
            }
        }
    }
}

// MARK: - Task Row View
private struct TaskRowView: View {
    @ObservedObject var task: TaskEntity
    let isSelected: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let assignedTo = task.assignedTo, !assignedTo.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text(assignedTo)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.blue)
                }

                if let reminderDate = task.reminderDate {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                        Text(reminderDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(reminderDate < Date() && !task.isCompleted ? .red : .secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.blue.opacity(0.4) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Task Detail View
private struct TaskDetailView: View {
    @ObservedObject var task: TaskEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title ?? "Untitled")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }

            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if let assignedTo = task.assignedTo, !assignedTo.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text("Assigned to: \(assignedTo)")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.blue)
            }

            if let reminderDate = task.reminderDate {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10))
                    Text("Reminder: \(reminderDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                }
                .foregroundStyle(reminderDate < Date() && !task.isCompleted ? .red : .secondary)
            }

            if let completedAt = task.completedAt {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                    Text("Completed: \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Empty State View
private struct EmptyTasksView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add/Edit Task View
private struct AddEditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let existingTask: TaskEntity?
    let onSave: (String, String?, Date?, String?) -> Void

    @State private var title: String
    @State private var notes: String
    @State private var hasReminder: Bool
    @State private var reminderDate: Date
    @State private var assignedTo: String

    init(existingTask: TaskEntity?, onSave: @escaping (String, String?, Date?, String?) -> Void) {
        self.existingTask = existingTask
        self.onSave = onSave

        _title = State(initialValue: existingTask?.title ?? "")
        _notes = State(initialValue: existingTask?.notes ?? "")
        _hasReminder = State(initialValue: existingTask?.reminderDate != nil)
        _reminderDate = State(initialValue: existingTask?.reminderDate ?? Date().addingTimeInterval(3600))
        _assignedTo = State(initialValue: existingTask?.assignedTo ?? "")
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                Spacer()

                Text(existingTask == nil ? "New Task" : "Edit Task")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Button(action: saveTask) {
                    Text("Save")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isValid ? Color.blue : Color.blue.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Task Title Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Task Title", systemImage: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("What needs to be done?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.blue.opacity(title.isEmpty ? 0 : 0.5), lineWidth: 1)
                            )
                    }

                    // Notes Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Add additional details...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                            TextEditor(text: $notes)
                                .font(.system(size: 14))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                        }
                        .frame(height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // Assign To Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Assign To", systemImage: "person")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("Enter person's name", text: $assignedTo)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Reminder Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Reminder", systemImage: "bell")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Toggle("", isOn: $hasReminder)
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }

                        if hasReminder {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)

                                DatePicker(
                                    "",
                                    selection: $reminderDate,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
                .padding(20)
            }
        }
        .frame(width: 450, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        let finalReminderDate = hasReminder ? reminderDate : nil
        let trimmedAssignedTo = assignedTo.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalAssignedTo = trimmedAssignedTo.isEmpty ? nil : trimmedAssignedTo

        onSave(trimmedTitle, finalNotes, finalReminderDate, finalAssignedTo)
        dismiss()
    }
}

// MARK: - Task Contact Data Model
struct TaskContactData: Identifiable {
    let id: NSManagedObjectID
    let name: String
    let role: String
    let phone: String
    let email: String
    let category: String
}

// MARK: - Task Assignment Picker Sheet
struct TaskAssignmentPickerSheet: View {
    let contacts: [TaskContactData]
    let onSelect: (TaskContactData) -> Void
    let onCancel: () -> Void

    @State private var searchText: String = ""

    var filteredContacts: [TaskContactData] {
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Assign Task To")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search contacts...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Contact List
            if contacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No contacts found")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("Add contacts in the Contacts app first.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredContacts) { contact in
                            TaskContactPickerRow(contact: contact) {
                                onSelect(contact)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 400, height: 450)
    }
}

struct TaskContactPickerRow: View {
    let contact: TaskContactData
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(contact.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 13, weight: .semibold))

                if !contact.role.isEmpty {
                    Text(contact.role)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if !contact.category.isEmpty {
                    Text(contact.category.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(contact.category.lowercased() == "cast" ? Color.blue : Color.purple)
                        )
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.green.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovered ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - Preview
#Preview {
    let previewController = PersistenceController(inMemory: true)
    return TasksView()
        .environment(\.managedObjectContext, previewController.container.viewContext)
}
