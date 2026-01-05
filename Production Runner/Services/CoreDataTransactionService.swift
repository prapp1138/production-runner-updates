//
//  CoreDataTransactionService.swift
//  Production Runner
//
//  Created by Claude Code
//  Purpose: Provides atomic transaction wrappers for multi-entity Core Data operations
//

import Foundation
import CoreData

/// Service providing atomic transaction support for Core Data operations
class CoreDataTransactionService {

    /// Execute a block of code within a Core Data transaction context
    /// - Parameters:
    ///   - context: The managed object context to perform the transaction in
    ///   - block: The block of code to execute atomically
    /// - Throws: Any error that occurs during the transaction
    static func performAtomicTransaction(
        in context: NSManagedObjectContext,
        block: @escaping (NSManagedObjectContext) throws -> Void
    ) throws {
        var thrownError: Error?

        context.performAndWait {
            do {
                try block(context)

                // Only save if there are changes
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                thrownError = error
                context.rollback()
            }
        }

        if let error = thrownError {
            throw error
        }
    }

    /// Execute a block of code within an async Core Data transaction context
    /// - Parameters:
    ///   - context: The managed object context to perform the transaction in
    ///   - block: The block of code to execute atomically
    /// - Throws: Any error that occurs during the transaction
    @available(iOS 15.0, macOS 12.0, *)
    static func performAtomicTransactionAsync(
        in context: NSManagedObjectContext,
        block: @escaping (NSManagedObjectContext) async throws -> Void
    ) async throws {
        var thrownError: Error?

        await context.perform {
            _ = Task {
                do {
                    try await block(context)

                    // Only save if there are changes
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    thrownError = error
                    context.rollback()
                }
            }
        }

        if let error = thrownError {
            throw error
        }
    }

    /// Create a scene with related breakdown and shots atomically
    /// - Parameters:
    ///   - context: The managed object context
    ///   - project: The project entity
    ///   - sceneData: Dictionary containing scene properties
    ///   - breakdownData: Optional dictionary containing breakdown properties
    ///   - shotsData: Optional array of dictionaries containing shot properties
    /// - Returns: The created scene entity
    /// - Throws: Any error that occurs during creation
    static func createSceneWithBreakdownAndShots(
        in context: NSManagedObjectContext,
        project: ProjectEntity,
        sceneData: [String: Any],
        breakdownData: [String: Any]? = nil,
        shotsData: [[String: Any]]? = nil
    ) throws -> SceneEntity {
        var createdScene: SceneEntity?

        try performAtomicTransaction(in: context) { ctx in
            // Create scene
            let scene = SceneEntity(context: ctx)
            scene.id = UUID()
            scene.project = project

            // Apply scene data
            if let number = sceneData["number"] as? String { scene.number = number }
            if let description = sceneData["description"] as? String { scene.descriptionText = description }
            if let location = sceneData["location"] as? String { scene.scriptLocation = location }
            if let timeOfDay = sceneData["timeOfDay"] as? String { scene.timeOfDay = timeOfDay }
            if let pageNumber = sceneData["pageNumber"] as? String { scene.pageNumber = pageNumber }
            if let pageEighths = sceneData["pageEighths"] as? Int16 { scene.pageEighths = pageEighths }

            // Create breakdown if data provided
            if let bData = breakdownData {
                let breakdown = BreakdownEntity(context: ctx)
                breakdown.id = UUID()
                breakdown.scene = scene

                if let castIDs = bData["castIDs"] as? String { breakdown.castIDs = castIDs }
                if let props = bData["props"] as? String { breakdown.props = props }
                if let wardrobe = bData["wardrobe"] as? String { breakdown.wardrobe = wardrobe }
                if let vehicles = bData["vehicles"] as? String { breakdown.vehicles = vehicles }
            }

            // Create shots if data provided
            if let shotsList = shotsData {
                for (index, shotData) in shotsList.enumerated() {
                    let shot = ShotEntity(context: ctx)
                    shot.id = UUID()
                    shot.scene = scene
                    shot.index = Int16(index)

                    if let code = shotData["code"] as? String { shot.code = code }
                    if let description = shotData["description"] as? String { shot.descriptionText = description }
                    if let type = shotData["type"] as? String { shot.type = type }
                    if let cam = shotData["cam"] as? String { shot.cam = cam }
                }
            }

            createdScene = scene
        }

        guard let scene = createdScene else {
            throw NSError(domain: "CoreDataTransactionService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create scene"
            ])
        }

        return scene
    }

    /// Delete a scene and all related entities atomically
    /// - Parameters:
    ///   - scene: The scene to delete
    ///   - context: The managed object context
    /// - Throws: Any error that occurs during deletion
    static func deleteSceneAndRelatedEntities(
        _ scene: SceneEntity,
        in context: NSManagedObjectContext
    ) throws {
        try performAtomicTransaction(in: context) { ctx in
            // Core Data cascade delete rules will handle breakdown and shots
            // But we explicitly clear relationships for clarity
            if let breakdown = scene.breakdown {
                ctx.delete(breakdown)
            }

            if let shots = scene.shots?.allObjects as? [ShotEntity] {
                shots.forEach { ctx.delete($0) }
            }

            ctx.delete(scene)
        }
    }

    /// Import multiple scenes from a screenplay atomically
    /// - Parameters:
    ///   - scenes: Array of scene data dictionaries
    ///   - project: The project entity
    ///   - context: The managed object context
    /// - Returns: Array of created scene entities
    /// - Throws: Any error that occurs during import
    static func importMultipleScenes(
        _ scenes: [[String: Any]],
        into project: ProjectEntity,
        in context: NSManagedObjectContext
    ) throws -> [SceneEntity] {
        var createdScenes: [SceneEntity] = []

        try performAtomicTransaction(in: context) { ctx in
            for sceneData in scenes {
                let scene = SceneEntity(context: ctx)
                scene.id = UUID()
                scene.project = project
                scene.createdAt = Date()

                if let number = sceneData["number"] as? String { scene.number = number }
                if let description = sceneData["description"] as? String { scene.descriptionText = description }
                if let location = sceneData["location"] as? String { scene.scriptLocation = location }
                if let timeOfDay = sceneData["timeOfDay"] as? String { scene.timeOfDay = timeOfDay }

                createdScenes.append(scene)
            }
        }

        return createdScenes
    }
}
