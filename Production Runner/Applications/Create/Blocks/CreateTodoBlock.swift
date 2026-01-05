import SwiftUI
import CoreData

// MARK: - Todo Block
struct CreateTodoBlock: View {
    let block: CreateBlockModel
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @State private var newItemText: String = ""
    @State private var editingItemID: UUID?
    @State private var editingText: String = ""
    @FocusState private var isNewItemFocused: Bool

    private var content: TodoContent {
        block.todoContent ?? TodoContent()
    }

    private var syncService: CreateTaskSyncService {
        CreateTaskSyncService.shared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.green)

                Text(content.title)
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Text("\(completedCount)/\(content.items.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))

            Divider()

            // Items list
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(content.items) { item in
                        todoItemRow(item)
                    }

                    // Add new item
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.green.opacity(0.5))
                            .font(.system(size: 14))

                        TextField("Add task...", text: $newItemText)
                            .font(.system(size: 11))
                            .textFieldStyle(.plain)
                            .focused($isNewItemFocused)
                            .onSubmit {
                                addNewItem()
                            }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color.green.opacity(0.03))
    }

    // MARK: - Todo Item Row
    @ViewBuilder
    private func todoItemRow(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
            // Checkbox
            Button {
                toggleItem(item.id)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            // Text
            if editingItemID == item.id {
                TextField("", text: $editingText, onCommit: {
                    finishEditing(item.id)
                })
                .font(.system(size: 11))
                .textFieldStyle(.plain)
            } else {
                Text(item.text)
                    .font(.system(size: 11))
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .onTapGesture(count: 2) {
                        startEditing(item)
                    }
            }

            Spacer()

            // Delete button (on hover)
            Button {
                deleteItem(item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers
    private var completedCount: Int {
        content.items.filter(\.isCompleted).count
    }

    private func toggleItem(_ id: UUID) {
        onContentUpdate { b in
            var c = b.todoContent ?? TodoContent()
            if let index = c.items.firstIndex(where: { $0.id == id }) {
                c.items[index].isCompleted.toggle()

                // Sync completion status to Tasks app
                if let taskID = c.items[index].linkedTaskID {
                    syncService.updateTaskCompletion(
                        taskID: taskID,
                        isCompleted: c.items[index].isCompleted,
                        in: viewContext
                    )
                }
            }
            b.encodeContent(c)
        }
    }

    private func addNewItem() {
        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let itemText = newItemText
        let listTitle = content.title

        onContentUpdate { b in
            var c = b.todoContent ?? TodoContent()

            // Create new item and sync to Tasks app
            var newItem = TodoItem(text: itemText)
            let taskID = syncService.syncTodoItem(newItem, listTitle: listTitle, in: viewContext)
            newItem.linkedTaskID = taskID

            c.items.append(newItem)
            b.encodeContent(c)
        }

        newItemText = ""
        isNewItemFocused = true
    }

    private func deleteItem(_ id: UUID) {
        onContentUpdate { b in
            var c = b.todoContent ?? TodoContent()

            // Delete linked task from Tasks app
            if let item = c.items.first(where: { $0.id == id }),
               let taskID = item.linkedTaskID {
                syncService.deleteTask(taskID: taskID, in: viewContext)
            }

            c.items.removeAll { $0.id == id }
            b.encodeContent(c)
        }
    }

    private func startEditing(_ item: TodoItem) {
        editingItemID = item.id
        editingText = item.text
    }

    private func finishEditing(_ id: UUID) {
        guard !editingText.trimmingCharacters(in: .whitespaces).isEmpty else {
            deleteItem(id)
            editingItemID = nil
            return
        }

        let updatedText = editingText
        let listTitle = content.title

        onContentUpdate { b in
            var c = b.todoContent ?? TodoContent()
            if let index = c.items.firstIndex(where: { $0.id == id }) {
                c.items[index].text = updatedText

                // Sync updated text to Tasks app
                _ = syncService.syncTodoItem(c.items[index], listTitle: listTitle, in: viewContext)
            }
            b.encodeContent(c)
        }

        editingItemID = nil
        editingText = ""
    }
}

// MARK: - Preview
#if DEBUG
struct CreateTodoBlock_Previews: PreviewProvider {
    static var previews: some View {
        CreateTodoBlock(
            block: {
                var block = CreateBlockModel.createTodo(at: .zero)
                let content = TodoContent(title: "Project Tasks", items: [
                    TodoItem(text: "Design mockups", isCompleted: true),
                    TodoItem(text: "Implement UI", isCompleted: false),
                    TodoItem(text: "Write tests", isCompleted: false)
                ])
                block.encodeContent(content)
                return block
            }(),
            onContentUpdate: { _ in }
        )
        .frame(width: 200, height: 180)
        .padding()
    }
}
#endif
