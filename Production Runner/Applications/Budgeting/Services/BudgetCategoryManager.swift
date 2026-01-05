import Foundation
import SwiftUI

/// Manages custom budget categories and their operations
/// Extracted from BudgetViewModel for single responsibility
final class BudgetCategoryManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var customCategories: [CustomBudgetCategory] = []
    @Published var selectedCategoryID: UUID?

    // MARK: - Private Properties

    private let storageKey = "budgetCustomCategories"
    private let auditTrail: BudgetAuditTrail

    // MARK: - Initialization

    init(auditTrail: BudgetAuditTrail = BudgetAuditTrail()) {
        self.auditTrail = auditTrail
        loadCustomCategories()
    }

    // MARK: - Category Loading

    func loadCustomCategories() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CustomBudgetCategory].self, from: data) {
            customCategories = decoded.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            customCategories = CustomBudgetCategory.featureFilmDefaults
            saveCustomCategories()
        }

        if selectedCategoryID == nil, let first = customCategories.first {
            selectedCategoryID = first.id
        }

        BudgetLogger.info("Loaded \(customCategories.count) custom categories", category: BudgetLogger.data)
    }

    // MARK: - Category Persistence

    func saveCustomCategories() {
        if let encoded = try? JSONEncoder().encode(customCategories) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            BudgetLogger.logDataOperation(.save, entity: "CustomCategories", success: true)
        }
    }

    // MARK: - Category CRUD

    /// Add a new custom category
    func addCategory(_ category: CustomBudgetCategory) {
        var newCategory = category
        newCategory.sortOrder = customCategories.count
        customCategories.append(newCategory)
        saveCustomCategories()

        auditTrail.recordChange(
            action: .created,
            entityType: "CustomCategory",
            entityID: category.id,
            details: "Created category '\(category.name)'"
        )

        BudgetLogger.logDataOperation(.create, entity: "CustomCategory", success: true)
    }

    /// Update an existing category
    func updateCategory(_ category: CustomBudgetCategory) {
        if let index = customCategories.firstIndex(where: { $0.id == category.id }) {
            customCategories[index] = category
            saveCustomCategories()

            auditTrail.recordChange(
                action: .updated,
                entityType: "CustomCategory",
                entityID: category.id,
                details: "Updated category '\(category.name)'"
            )

            BudgetLogger.logDataOperation(.update, entity: "CustomCategory", success: true)
        }
    }

    /// Delete a category
    func deleteCategory(_ category: CustomBudgetCategory) {
        let categoryName = category.name
        customCategories.removeAll { $0.id == category.id }

        // Reorder remaining categories
        for i in 0..<customCategories.count {
            customCategories[i].sortOrder = i
        }
        saveCustomCategories()

        // Select another category if needed
        if selectedCategoryID == category.id {
            selectedCategoryID = customCategories.first?.id
        }

        auditTrail.recordChange(
            action: .deleted,
            entityType: "CustomCategory",
            entityID: category.id,
            details: "Deleted category '\(categoryName)'"
        )

        BudgetLogger.logDataOperation(.delete, entity: "CustomCategory", success: true)
    }

    /// Reorder categories
    func reorderCategories(from source: IndexSet, to destination: Int) {
        customCategories.move(fromOffsets: source, toOffset: destination)
        for i in 0..<customCategories.count {
            customCategories[i].sortOrder = i
        }
        saveCustomCategories()
        BudgetLogger.debug("Reordered categories", category: BudgetLogger.data)
    }

    // MARK: - Template Defaults

    /// Load default categories for a template type
    func loadDefaults(for templateType: BudgetTemplateType) {
        switch templateType {
        case .shortFilm:
            customCategories = CustomBudgetCategory.shortFilmDefaults
        default:
            customCategories = CustomBudgetCategory.featureFilmDefaults
        }
        saveCustomCategories()
        selectedCategoryID = customCategories.first?.id

        BudgetLogger.info("Loaded default categories for \(templateType.rawValue)", category: BudgetLogger.data)
    }

    /// Replace all categories (used when loading templates)
    func replaceCategories(_ categories: [CustomBudgetCategory]) {
        customCategories = categories
        saveCustomCategories()
        selectedCategoryID = customCategories.first?.id
    }

    // MARK: - Category Helpers

    /// Get the currently selected category
    var selectedCategory: CustomBudgetCategory? {
        guard let id = selectedCategoryID else { return nil }
        return customCategories.first { $0.id == id }
    }

    /// Find category by name
    func category(named name: String) -> CustomBudgetCategory? {
        customCategories.first { $0.name == name }
    }

    /// Get category color by ID
    func color(for categoryID: UUID) -> Color {
        guard let category = customCategories.first(where: { $0.id == categoryID }) else {
            return .gray
        }
        return category.color
    }

    /// Get category icon by ID
    func icon(for categoryID: UUID) -> String {
        guard let category = customCategories.first(where: { $0.id == categoryID }) else {
            return "folder.fill"
        }
        return category.icon
    }

    /// Count items in a category
    func itemCount(for category: CustomBudgetCategory, in items: [BudgetLineItem]) -> Int {
        items.filter { item in
            item.category == category.name
        }.count
    }

    /// Filter items by selected category
    func filterItems(_ items: [BudgetLineItem], searchText: String = "") -> [BudgetLineItem] {
        guard let category = selectedCategory else { return items }

        let categoryFiltered = items.filter { item in
            item.category == category.name
        }

        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.subcategory.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}
