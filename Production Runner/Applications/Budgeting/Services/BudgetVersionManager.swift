import Foundation
import CoreData
import Combine

/// Manages budget version CRUD operations, persistence, and state
/// Extracted from BudgetViewModel for single responsibility
/// Updated to use Core Data instead of UserDefaults for unlimited storage
final class BudgetVersionManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var versions: [BudgetVersion] = []
    @Published private(set) var selectedVersion: BudgetVersion?
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private Properties

    private let context: NSManagedObjectContext
    private let projectID: UUID?
    private let expandedSectionsKey = "budgetExpandedSections"
    private let auditTrail: BudgetAuditTrail
    private var migrationCompleted: Bool = false

    // MARK: - Initialization

    init(context: NSManagedObjectContext, projectID: UUID? = nil, auditTrail: BudgetAuditTrail = BudgetAuditTrail()) {
        self.context = context
        self.projectID = projectID
        self.auditTrail = auditTrail

        // Perform migration on initialization if needed
        Task { @MainActor in
            await performMigrationIfNeeded()
            loadVersions()
        }
    }

    // MARK: - Migration

    private func performMigrationIfNeeded() async {
        guard !migrationCompleted, BudgetMigrationManager.needsMigration() else {
            migrationCompleted = true
            return
        }

        BudgetLogger.info("Starting budget migration from UserDefaults to Core Data", category: BudgetLogger.data)

        do {
            let (migrated, skipped) = try BudgetMigrationManager.migrateFromUserDefaults(context: context)
            BudgetLogger.info("✅ Migration complete: \(migrated) migrated, \(skipped) skipped", category: BudgetLogger.data)
            migrationCompleted = true
        } catch {
            BudgetLogger.error("❌ Migration failed: \(error.localizedDescription)", category: BudgetLogger.data)
        }
    }

    // MARK: - Version Loading

    func loadVersions() {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchRequest: NSFetchRequest<BudgetVersionEntity> = BudgetVersionEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]

            // Filter by project if specified
            if let projectID = projectID {
                fetchRequest.predicate = NSPredicate(format: "project.id == %@", projectID as CVarArg)
            }

            let entities = try context.fetch(fetchRequest)
            versions = entities.map { $0.toModel() }

            if let first = versions.first {
                selectVersion(first)
            } else {
                // Create default version
                let defaultVersion = BudgetVersion(name: "Budget v1.0")
                versions = [defaultVersion]
                selectVersion(defaultVersion)
                saveVersions()
            }

            BudgetLogger.info("Loaded \(versions.count) budget versions from Core Data", category: BudgetLogger.data)
        } catch {
            BudgetLogger.error("Failed to load versions: \(error.localizedDescription)", category: BudgetLogger.data)
            // Fallback to empty state
            versions = []
        }
    }

    // MARK: - Version Persistence

    func saveVersions() {
        do {
            // Update or create entities for each version
            for version in versions {
                let fetchRequest: NSFetchRequest<BudgetVersionEntity> = BudgetVersionEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", version.id as CVarArg)
                fetchRequest.fetchLimit = 1

                if let existing = try context.fetch(fetchRequest).first {
                    try existing.update(from: version)
                } else {
                    let newEntity = try BudgetVersionEntity.create(from: version, in: context)
                    // Link to project if projectID is set
                    if let projectID = projectID {
                        let projectFetch: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                        projectFetch.predicate = NSPredicate(format: "id == %@", projectID as CVarArg)
                        projectFetch.fetchLimit = 1
                        if let project = try context.fetch(projectFetch).first {
                            newEntity.project = project
                        }
                    }
                }
            }

            try context.save()
            BudgetLogger.logDataOperation(.save, entity: "BudgetVersions", success: true)
        } catch {
            BudgetLogger.error("Failed to save versions: \(error.localizedDescription)", category: BudgetLogger.data)
        }
    }

    // MARK: - Version Selection

    func selectVersion(_ version: BudgetVersion) {
        selectedVersion = version
        loadExpandedSections(for: version.id)
        BudgetLogger.debug("Selected version: \(version.name)", category: BudgetLogger.data)
    }

    // MARK: - Version CRUD

    /// Create a new budget version
    @discardableResult
    func createVersion(name: String, copyFromCurrent: Bool = true) -> BudgetVersion {
        _ = BudgetValidation.canModify(selectedVersion ?? BudgetVersion(name: ""))

        let newVersion: BudgetVersion

        if copyFromCurrent, let currentVersion = selectedVersion {
            // Copy structure but reset values to 0
            let copiedLineItems = currentVersion.lineItems.map { item in
                BudgetLineItem(
                    id: UUID(),
                    name: item.name,
                    account: item.account,
                    category: item.category,
                    subcategory: item.subcategory,
                    section: item.section,
                    quantity: 0,
                    days: 0,
                    unitCost: 0,
                    notes: "",
                    isLinkedToRateCard: false,
                    rateCardID: nil,
                    linkedContactID: nil,
                    linkedContactType: nil,
                    parentItemID: nil,
                    childItemIDs: nil
                )
            }
            newVersion = BudgetVersion(name: name, lineItems: copiedLineItems)
        } else {
            newVersion = BudgetVersion(name: name)
        }

        versions.append(newVersion)
        selectVersion(newVersion)
        saveVersions()

        auditTrail.recordChange(
            action: .created,
            entityType: "BudgetVersion",
            entityID: newVersion.id,
            details: "Created version '\(name)'"
        )

        BudgetLogger.logDataOperation(.create, entity: "BudgetVersion", success: true)
        return newVersion
    }

    /// Rename a budget version
    func renameVersion(_ version: BudgetVersion, to newName: String) {
        guard case .success = BudgetValidation.canModify(version) else {
            BudgetLogger.warning("Cannot rename locked version", category: BudgetLogger.data)
            return
        }

        if let index = versions.firstIndex(where: { $0.id == version.id }) {
            let oldName = versions[index].name
            versions[index].name = newName
            if selectedVersion?.id == version.id {
                selectedVersion?.name = newName
            }
            saveVersions()

            auditTrail.recordChange(
                action: .updated,
                entityType: "BudgetVersion",
                entityID: version.id,
                details: "Renamed from '\(oldName)' to '\(newName)'"
            )

            BudgetLogger.logDataOperation(.update, entity: "BudgetVersion", success: true)
        }
    }

    /// Delete a budget version
    func deleteVersion(_ version: BudgetVersion) {
        let versionName = version.name
        let versionID = version.id

        versions.removeAll { $0.id == version.id }

        // Select another version if needed
        if selectedVersion?.id == version.id {
            if let first = versions.first {
                selectVersion(first)
            } else {
                // Create new default version if all were deleted
                let defaultVersion = BudgetVersion(name: "Budget v1.0")
                versions = [defaultVersion]
                selectVersion(defaultVersion)
            }
        }

        saveVersions()
        clearExpandedSections(for: versionID)

        auditTrail.recordChange(
            action: .deleted,
            entityType: "BudgetVersion",
            entityID: versionID,
            details: "Deleted version '\(versionName)'"
        )

        BudgetLogger.logDataOperation(.delete, entity: "BudgetVersion", success: true)
    }

    /// Duplicate a budget version
    @discardableResult
    func duplicateVersion(_ version: BudgetVersion) -> BudgetVersion {
        let newVersion = version.duplicate()
        versions.append(newVersion)
        selectVersion(newVersion)
        saveVersions()

        auditTrail.recordChange(
            action: .created,
            entityType: "BudgetVersion",
            entityID: newVersion.id,
            details: "Duplicated from '\(version.name)'"
        )

        BudgetLogger.logDataOperation(.create, entity: "BudgetVersion (duplicate)", success: true)
        return newVersion
    }

    /// Lock a budget version to prevent modifications
    func lockVersion(_ version: BudgetVersion) {
        if let index = versions.firstIndex(where: { $0.id == version.id }) {
            versions[index].isLocked = true
            if selectedVersion?.id == version.id {
                selectedVersion?.isLocked = true
            }
            saveVersions()

            auditTrail.recordChange(
                action: .locked,
                entityType: "BudgetVersion",
                entityID: version.id,
                details: "Version locked"
            )

            BudgetLogger.logAuditEntry(action: .locked, entityType: "BudgetVersion", entityID: version.id)
        }
    }

    /// Unlock a budget version to allow modifications
    func unlockVersion(_ version: BudgetVersion) {
        if let index = versions.firstIndex(where: { $0.id == version.id }) {
            versions[index].isLocked = false
            if selectedVersion?.id == version.id {
                selectedVersion?.isLocked = false
            }
            saveVersions()

            auditTrail.recordChange(
                action: .unlocked,
                entityType: "BudgetVersion",
                entityID: version.id,
                details: "Version unlocked"
            )

            BudgetLogger.logAuditEntry(action: .unlocked, entityType: "BudgetVersion", entityID: version.id)
        }
    }

    // MARK: - Line Item Operations

    /// Update line items for the current version
    func updateLineItems(_ items: [BudgetLineItem]) {
        guard var version = selectedVersion else { return }
        guard case .success = BudgetValidation.canModify(version) else {
            BudgetLogger.warning("Cannot modify locked version", category: BudgetLogger.data)
            return
        }

        version.lineItems = items
        if let index = versions.firstIndex(where: { $0.id == version.id }) {
            versions[index] = version
            selectedVersion = version
        }
        saveVersions()
    }

    /// Update transactions for the current version
    func updateTransactions(_ transactions: [BudgetTransaction]) {
        guard var version = selectedVersion else { return }
        guard case .success = BudgetValidation.canModify(version) else {
            BudgetLogger.warning("Cannot modify locked version", category: BudgetLogger.data)
            return
        }

        version.transactions = transactions
        if let index = versions.firstIndex(where: { $0.id == version.id }) {
            versions[index] = version
            selectedVersion = version
        }
        saveVersions()
    }

    /// Update an existing version
    func updateVersion(_ version: BudgetVersion) {
        if let index = versions.firstIndex(where: { $0.id == version.id }) {
            versions[index] = version
            if selectedVersion?.id == version.id {
                selectedVersion = version
            }
            saveVersions()
        }
    }

    // MARK: - Section State Persistence

    private func loadExpandedSections(for versionID: UUID) {
        // Section state is now persisted per-version
        let key = "\(expandedSectionsKey)_\(versionID.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let sections = try? JSONDecoder().decode(Set<String>.self, from: data) {
            // Sections are loaded and can be accessed via getExpandedSections
            BudgetLogger.debug("Loaded \(sections.count) expanded sections for version", category: BudgetLogger.data)
        }
    }

    func saveExpandedSections(_ sections: Set<String>, for versionID: UUID) {
        let key = "\(expandedSectionsKey)_\(versionID.uuidString)"
        if let data = try? JSONEncoder().encode(sections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func getExpandedSections(for versionID: UUID) -> Set<String> {
        let key = "\(expandedSectionsKey)_\(versionID.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let sections = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return sections
        }
        return []
    }

    private func clearExpandedSections(for versionID: UUID) {
        let key = "\(expandedSectionsKey)_\(versionID.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
    }
}
