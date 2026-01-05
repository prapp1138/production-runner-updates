//
//  BudgetMigrationManager.swift
//  Production Runner
//
//  Created by Claude Code on 2026-01-05.
//  Migration manager for moving budget data from UserDefaults to Core Data
//

import Foundation
import CoreData

final class BudgetMigrationManager {

    /// Check if migration from UserDefaults is needed
    static func needsMigration() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "budgetVersions"),
              let versions = try? JSONDecoder().decode([BudgetVersion].self, from: data) else {
            return false
        }
        return !versions.isEmpty
    }

    /// Migrate budget versions from UserDefaults to Core Data
    /// Returns: (migrated count, skipped count)
    static func migrateFromUserDefaults(context: NSManagedObjectContext) throws -> (Int, Int) {
        let storageKey = "budgetVersions"

        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let versions = try? JSONDecoder().decode([BudgetVersion].self, from: data) else {
            print("[BudgetMigration] No UserDefaults data to migrate")
            return (0, 0)
        }

        var migrated = 0
        var skipped = 0

        print("[BudgetMigration] Starting migration of \(versions.count) budget versions")

        for version in versions {
            // Check if already migrated
            let fetchRequest: NSFetchRequest<BudgetVersionEntity> = BudgetVersionEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", version.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if (try? context.fetch(fetchRequest).first) != nil {
                print("[BudgetMigration] Version '\(version.name)' already exists, skipping")
                skipped += 1
                continue
            }

            // Create new entity
            let entity = BudgetVersionEntity(context: context)
            entity.id = version.id
            entity.name = version.name
            entity.createdDate = version.createdDate
            entity.isLocked = version.isLocked
            entity.lockedAt = version.lockedAt
            entity.lockedBy = version.lockedBy
            entity.currency = version.currency
            entity.notes = version.notes

            // Serialize collections as JSON
            if let lineItemsData = try? JSONEncoder().encode(version.lineItems),
               let lineItemsJSON = String(data: lineItemsData, encoding: .utf8) {
                entity.lineItemsJSON = lineItemsJSON
            }

            if let transactionsData = try? JSONEncoder().encode(version.transactions),
               let transactionsJSON = String(data: transactionsData, encoding: .utf8) {
                entity.transactionsJSON = transactionsJSON
            }

            if let payrollData = try? JSONEncoder().encode(version.payrollItems),
               let payrollJSON = String(data: payrollData, encoding: .utf8) {
                entity.payrollItemsJSON = payrollJSON
            }

            migrated += 1
            print("[BudgetMigration] Migrated version '\(version.name)'")
        }

        try context.save()

        // Create backup of UserDefaults data with timestamp
        let backupKey = "budgetVersions_backup_\(Date().timeIntervalSince1970)"
        UserDefaults.standard.set(data, forKey: backupKey)
        print("[BudgetMigration] ✅ Created backup at key: \(backupKey)")

        print("[BudgetMigration] ✅ Migration complete: \(migrated) migrated, \(skipped) skipped")

        return (migrated, skipped)
    }

    /// Verify migration completed successfully
    static func verifyMigration(context: NSManagedObjectContext) -> Bool {
        // Count UserDefaults versions
        guard let data = UserDefaults.standard.data(forKey: "budgetVersions"),
              let udVersions = try? JSONDecoder().decode([BudgetVersion].self, from: data) else {
            print("[BudgetMigration] No UserDefaults data to verify")
            return true // OK if nothing to migrate
        }

        // Count Core Data versions
        let fetchRequest: NSFetchRequest<BudgetVersionEntity> = BudgetVersionEntity.fetchRequest()
        let cdCount = (try? context.fetch(fetchRequest).count) ?? 0

        print("[BudgetMigration] Verification: UserDefaults: \(udVersions.count), Core Data: \(cdCount)")

        return cdCount >= udVersions.count
    }
}
