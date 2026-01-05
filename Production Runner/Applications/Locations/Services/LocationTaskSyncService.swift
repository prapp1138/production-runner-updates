import SwiftUI
import CoreData

// MARK: - Location Task Sync Service
/// Syncs location assignments from Locations app to the Tasks app's TaskEntity

class LocationTaskSyncService {
    static let shared = LocationTaskSyncService()

    private init() {}

    // MARK: - Sync Assignment to Task

    /// Creates or updates a TaskEntity from a LocationAssignment
    /// - Parameters:
    ///   - assignment: The LocationAssignment to sync
    ///   - locationName: The name of the location (used in task notes)
    ///   - context: The managed object context
    /// - Returns: The UUID of the linked TaskEntity
    func syncAssignment(_ assignment: LocationAssignment, locationName: String, in context: NSManagedObjectContext) -> UUID {
        // Check if task already exists
        if let linkedID = assignment.linkedTaskID,
           let existingTask = fetchTask(id: linkedID, in: context) {
            // Update existing task
            updateTask(existingTask, from: assignment, locationName: locationName)
            saveContext(context)
            return linkedID
        } else {
            // Create new task
            let newTask = createTask(from: assignment, locationName: locationName, in: context)
            saveContext(context)
            return newTask.id ?? UUID()
        }
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

    /// Deletes all tasks linked to assignments for a location
    func deleteLinkedTasks(assignments: [LocationAssignment], in context: NSManagedObjectContext) {
        for assignment in assignments {
            if let taskID = assignment.linkedTaskID {
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

    private func createTask(from assignment: LocationAssignment, locationName: String, in context: NSManagedObjectContext) -> TaskEntity {
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = assignment.taskDescription.isEmpty ? "\(assignment.role.rawValue) - \(locationName)" : assignment.taskDescription
        task.notes = buildTaskNotes(from: assignment, locationName: locationName)
        task.isCompleted = assignment.isCompleted
        task.completedAt = assignment.completedAt
        task.reminderDate = assignment.dueDate
        task.assignedTo = assignment.assigneeName
        task.createdAt = assignment.createdAt

        return task
    }

    private func updateTask(_ task: TaskEntity, from assignment: LocationAssignment, locationName: String) {
        task.title = assignment.taskDescription.isEmpty ? "\(assignment.role.rawValue) - \(locationName)" : assignment.taskDescription
        task.notes = buildTaskNotes(from: assignment, locationName: locationName)
        task.isCompleted = assignment.isCompleted
        task.completedAt = assignment.completedAt
        task.reminderDate = assignment.dueDate
        task.assignedTo = assignment.assigneeName
    }

    private func buildTaskNotes(from assignment: LocationAssignment, locationName: String) -> String {
        var notes = "From Locations: \(locationName)\nRole: \(assignment.role.rawValue)"

        if !assignment.notes.isEmpty {
            notes += "\n\(assignment.notes)"
        }

        if !assignment.assigneeEmail.isEmpty {
            notes += "\nEmail: \(assignment.assigneeEmail)"
        }

        if !assignment.assigneePhone.isEmpty {
            notes += "\nPhone: \(assignment.assigneePhone)"
        }

        return notes
    }

    private func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("LocationTaskSyncService: Error saving context - \(error.localizedDescription)")
        }
    }
}
