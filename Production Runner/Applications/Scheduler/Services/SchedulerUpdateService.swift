//
//  SchedulerUpdateService.swift
//  Production Runner
//
//  Automatically updates scheduler after script re-import
//

import Foundation
import CoreData

public final class SchedulerUpdateService {
    
    /// Update scheduler after applying a diff result
    public static func updateScheduler(
        after diffResult: DiffResult,
        in context: NSManagedObjectContext
    ) throws {
        
        var thrownError: Error?
        
        context.performAndWait {
            // 1. Handle removed scenes
            handleRemovedScenes(diffResult.removed, context: context)
            
            // 2. Handle added scenes
            handleAddedScenes(diffResult.added, context: context)
            
            // 3. Handle modified scenes
            handleModifiedScenes(diffResult.modified, context: context)
            
            // 4. Handle moved scenes
            handleMovedScenes(diffResult.moved, context: context)
            
            // 5. Recalculate day totals
            recalculateDayTotals(in: context)
            
            // 6. Save changes
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    NSLog("Failed to save scheduler updates: \(error)")
                    thrownError = error
                }
            }
        }
        
        if let error = thrownError {
            throw error
        }
    }
    
    // MARK: - Handle Removed Scenes
    
    private static func handleRemovedScenes(_ removed: [SceneEntity], context: NSManagedObjectContext) {
        for scene in removed {
            // Check if scene is scheduled
            if let shootDay = scene.shootDay {
                NSLog("⚠️ Scene \(scene.number ?? "?") removed from script but was scheduled on \(shootDay.displayTitle ?? "unknown day")")
                
                // Option 1: Unschedule the scene (recommended)
                scene.shootDay = nil
                scene.setValue(nil, forKey: "shootDayOrder")
                
                // Option 2: Mark as removed but keep in schedule (alternative)
                // scene.setValue(true, forKey: "isRemovedFromScript")
            }
        }
    }
    
    // MARK: - Handle Added Scenes
    
    private static func handleAddedScenes(_ added: [FDXSceneDraft], context: NSManagedObjectContext) {
        // Added scenes are not scheduled yet
        // They'll appear in the "unscheduled" section
        NSLog("✅ \(added.count) new scenes added to script (unscheduled)")
    }
    
    // MARK: - Handle Modified Scenes
    
    private static func handleModifiedScenes(_ modified: [ModifiedScene], context: NSManagedObjectContext) {
        for modScene in modified {
            let scene = modScene.existing
            let changes = modScene.changes
            
            // If page count changed and scene is scheduled, update day totals
            if changes.pageEighthsChanged {
                NSLog("📄 Scene \(scene.number ?? "?") page count changed")
                
                // The scene's pageEighths will be updated by the import
                // Day totals will be recalculated in recalculateDayTotals()
            }
            
            // If scene number changed and scene is scheduled, log warning
            if changes.numberChanged, scene.shootDay != nil {
                NSLog("⚠️ Scene number changed from \(scene.number ?? "?") to \(modScene.incoming.numberString) while scheduled")
            }
            
            // If heading changed significantly, log for review
            if changes.headingChanged || changes.locationTypeChanged || changes.scriptLocationChanged {
                NSLog("ℹ️ Scene \(scene.number ?? "?") heading changed - may affect scheduling")
            }
        }
    }
    
    // MARK: - Handle Moved Scenes
    
    private static func handleMovedScenes(_ moved: [MovedScene], context: NSManagedObjectContext) {
        for movedScene in moved {
            NSLog("📦 Scene \(movedScene.scene.number ?? "?") moved from position \(movedScene.oldIndex + 1) to \(movedScene.newIndex + 1)")
            
            // Scenes maintain their shoot day assignments even if moved in script order
            // This is intentional - script order ≠ shooting order
        }
    }
    
    // MARK: - Recalculate Day Totals
    
    private static func recalculateDayTotals(in context: NSManagedObjectContext) {
        // Fetch all shoot days
        let fetchRequest: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        guard let shootDays = try? context.fetch(fetchRequest) else {
            NSLog("Failed to fetch shoot days")
            return
        }
        
        for day in shootDays {
            // Calculate total page eighths for this day
            var totalEighths: Int16 = 0
            var sceneCount = 0
            
            if let scenes = day.scenes as? Set<SceneEntity> {
                for scene in scenes {
                    totalEighths += scene.pageEighths
                    sceneCount += 1
                }
            }
            
            // Update day totals
            day.totalPageEighths = totalEighths
            day.sceneCount = Int16(sceneCount)
            
            NSLog("📊 Day \(day.displayTitle ?? "?"): \(sceneCount) scenes, \(formatEighths(totalEighths)) pages")
        }
    }
    
    // MARK: - Helper Functions
    
    private static func formatEighths(_ eighths: Int16) -> String {
        guard eighths > 0 else { return "0" }
        
        let pages = eighths / 8
        let remainder = eighths % 8
        
        if pages > 0 && remainder > 0 {
            return "\(pages) \(remainder)/8"
        } else if pages > 0 {
            return "\(pages)"
        } else {
            return "\(remainder)/8"
        }
    }
    
    /// Get summary of scheduler impacts
    public static func getImpactSummary(for diffResult: DiffResult) -> SchedulerImpact {
        var impact = SchedulerImpact()
        
        // Count scenes that are scheduled
        impact.removedScheduledScenes = diffResult.removed.filter { $0.shootDay != nil }.count
        
        // Calculate page changes for scheduled scenes
        for modScene in diffResult.modified {
            if modScene.existing.shootDay != nil && modScene.changes.pageEighthsChanged {
                impact.daysAffectedByPageChanges += 1
            }
        }
        
        // Count moved scheduled scenes
        impact.movedScheduledScenes = diffResult.moved.filter { $0.scene.shootDay != nil }.count
        
        return impact
    }
    
    public struct SchedulerImpact {
        public var removedScheduledScenes: Int = 0
        public var daysAffectedByPageChanges: Int = 0
        public var movedScheduledScenes: Int = 0
        
        public var hasImpact: Bool {
            removedScheduledScenes > 0 ||
            daysAffectedByPageChanges > 0 ||
            movedScheduledScenes > 0
        }
        
        public var summary: String {
            var parts: [String] = []
            
            if removedScheduledScenes > 0 {
                parts.append("\(removedScheduledScenes) scheduled scene(s) will be unscheduled")
            }
            
            if daysAffectedByPageChanges > 0 {
                parts.append("\(daysAffectedByPageChanges) day(s) will have updated page counts")
            }
            
            if movedScheduledScenes > 0 {
                parts.append("\(movedScheduledScenes) scheduled scene(s) moved in script order")
            }
            
            return parts.isEmpty ? "No scheduler impact" : parts.joined(separator: ", ")
        }
    }
}

// MARK: - ShootDayEntity Extensions

extension ShootDayEntity {
    public var displayTitle: String? {
        if let date = self.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Day - \(formatter.string(from: date))"
        }
        return nil
    }
    
    public var totalPageEighths: Int16 {
        get {
            return self.value(forKey: "totalPageEighths") as? Int16 ?? 0
        }
        set {
            self.setValue(newValue, forKey: "totalPageEighths")
        }
    }
    
    public var sceneCount: Int16 {
        get {
            return self.value(forKey: "sceneCount") as? Int16 ?? 0
        }
        set {
            self.setValue(newValue, forKey: "sceneCount")
        }
    }
}
