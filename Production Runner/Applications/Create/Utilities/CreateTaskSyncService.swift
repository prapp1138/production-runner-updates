import SwiftUI
import CoreData

// MARK: - Create Task Sync Service
/// Syncs todo items from Create app's TodoBlocks to the Tasks app's TaskEntity

class CreateTaskSyncService {
    static let shared = CreateTaskSyncService()

    private init() {}

    // MARK: - Sync Todo Item to Task

    /// Creates or updates a TaskEntity from a TodoItem
    /// - Parameters:
    ///   - item: The TodoItem to sync
    ///   - listTitle: The title of the todo list (used as note prefix)
    ///   - context: The managed object context
    /// - Returns: The UUID of the linked TaskEntity
    func syncTodoItem(_ item: TodoItem, listTitle: String, in context: NSManagedObjectContext) -> UUID {
        // Check if task already exists
        if let linkedID = item.linkedTaskID,
           let existingTask = fetchTask(id: linkedID, in: context) {
            // Update existing task
            updateTask(existingTask, from: item, listTitle: listTitle)
            saveContext(context)
            return linkedID
        } else {
            // Create new task
            let newTask = createTask(from: item, listTitle: listTitle, in: context)
            saveContext(context)
            return newTask.id ?? UUID()
        }
    }

    /// Syncs all items in a TodoContent to Tasks
    /// - Parameters:
    ///   - content: The TodoContent containing items to sync
    ///   - context: The managed object context
    /// - Returns: Updated TodoContent with linked task IDs
    func syncTodoContent(_ content: TodoContent, in context: NSManagedObjectContext) -> TodoContent {
        var updatedContent = content

        for (index, item) in content.items.enumerated() {
            let taskID = syncTodoItem(item, listTitle: content.title, in: context)
            updatedContent.items[index].linkedTaskID = taskID
        }

        return updatedContent
    }

    /// Updates an existing task's completion status
    func updateTaskCompletion(taskID: UUID, isCompleted: Bool, in context: NSManagedObjectContext) {
        guard let task = fetchTask(id: taskID, in: context) else { return }

        task.isCompleted = isCompleted
        task.completedAt = isCompleted ? Date() : nil

        saveContext(context)
    }

    /// Deletes a task by ID
    func deleteTask(taskID: UUID, in context: NSManagedObjectContext) {
        guard let task = fetchTask(id: taskID, in: context) else { return }

        context.delete(task)
        saveContext(context)
    }

    /// Deletes all tasks linked to items in a TodoContent
    func deleteLinkedTasks(from content: TodoContent, in context: NSManagedObjectContext) {
        for item in content.items {
            if let taskID = item.linkedTaskID {
                deleteTask(taskID: taskID, in: context)
            }
        }
    }

    // MARK: - Private Helpers

    private func fetchTask(id: UUID, in context: NSManagedObjectContext) -> TaskEntity? {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    private func createTask(from item: TodoItem, listTitle: String, in context: NSManagedObjectContext) -> TaskEntity {
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = item.text
        task.notes = "From Create: \(listTitle)"
        task.isCompleted = item.isCompleted
        task.completedAt = item.isCompleted ? Date() : nil
        task.createdAt = Date()

        return task
    }

    private func updateTask(_ task: TaskEntity, from item: TodoItem, listTitle: String) {
        task.title = item.text
        task.notes = "From Create: \(listTitle)"
        task.isCompleted = item.isCompleted
        task.completedAt = item.isCompleted ? Date() : nil
    }

    private func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("CreateTaskSyncService: Error saving context - \(error.localizedDescription)")
        }
    }
}

// MARK: - TodoItem Extension for Sync

extension TodoItem {
    /// Creates a synced TodoItem that will be linked to a TaskEntity
    static func synced(text: String, in context: NSManagedObjectContext, listTitle: String = "Tasks") -> TodoItem {
        var item = TodoItem(text: text)
        let taskID = CreateTaskSyncService.shared.syncTodoItem(item, listTitle: listTitle, in: context)
        item.linkedTaskID = taskID
        return item
    }
}
