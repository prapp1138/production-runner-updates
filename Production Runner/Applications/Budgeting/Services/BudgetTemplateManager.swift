import Foundation

/// Manages budget template loading, saving, and custom template operations
/// Extracted from BudgetViewModel for single responsibility
final class BudgetTemplateManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var customTemplates: [CustomBudgetTemplate] = []
    @Published private(set) var currentTemplateType: BudgetTemplateType = .standard
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private Properties

    private let customTemplatesKey = "budget_custom_templates"
    private let auditTrail: BudgetAuditTrail

    // MARK: - Template Errors

    enum TemplateError: LocalizedError {
        case fileNotFound
        case invalidFormat
        case noItemsLoaded
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Template file not found. Please ensure StandardBudgetTemplate.json is added to the Xcode project with target membership checked."
            case .invalidFormat:
                return "Template file format is invalid or corrupted."
            case .noItemsLoaded:
                return "No valid budget items found in template. The template may be empty or incorrectly formatted."
            case .decodingFailed(let detail):
                return "Failed to decode template: \(detail)"
            }
        }
    }

    // MARK: - Initialization

    init(auditTrail: BudgetAuditTrail = BudgetAuditTrail()) {
        self.auditTrail = auditTrail
        loadCustomTemplates()
    }

    // MARK: - Standard Template Loading

    /// Load the standard feature film template
    func loadStandardTemplate() throws -> [BudgetLineItem] {
        BudgetLogger.info("Loading standard template...", category: BudgetLogger.template)

        guard let bundlePath = Bundle.main.path(forResource: "StandardBudgetTemplate", ofType: "json") else {
            BudgetLogger.error("StandardBudgetTemplate.json not found in bundle", category: BudgetLogger.template)
            throw TemplateError.fileNotFound
        }

        let url = URL(fileURLWithPath: bundlePath)

        let data: Data
        do {
            data = try Data(contentsOf: url)
            BudgetLogger.debug("Read \(data.count) bytes from template file", category: BudgetLogger.template)
        } catch {
            BudgetLogger.error("Failed to read template file: \(error.localizedDescription)", category: BudgetLogger.template)
            throw TemplateError.invalidFormat
        }

        let template: BudgetTemplate
        do {
            template = try JSONDecoder().decode(BudgetTemplate.self, from: data)
            BudgetLogger.debug("Decoded template with \(template.sheets.count) sheets", category: BudgetLogger.template)
        } catch let decodingError as DecodingError {
            let detail = formatDecodingError(decodingError)
            BudgetLogger.error("Decoding error: \(detail)", category: BudgetLogger.template)
            throw TemplateError.decodingFailed(detail)
        } catch {
            BudgetLogger.error("Unknown decoding error: \(error)", category: BudgetLogger.template)
            throw TemplateError.invalidFormat
        }

        let items = convertTemplateToLineItems(template)

        guard !items.isEmpty else {
            BudgetLogger.error("No items loaded from template", category: BudgetLogger.template)
            throw TemplateError.noItemsLoaded
        }

        currentTemplateType = .featureFilm
        BudgetLogger.logTemplateLoad(name: "Standard Feature Film", itemCount: items.count)

        return items
    }

    /// Load the short film template
    func loadShortFilmTemplate() throws -> [BudgetLineItem] {
        BudgetLogger.info("Loading short film template...", category: BudgetLogger.template)

        var items: [BudgetLineItem] = []

        // Cast items
        let castItems: [(name: String, account: String)] = [
            ("Lead Cast", "10-01"),
            ("Supporting Cast", "10-02"),
            ("Day Players", "10-03"),
            ("Extras", "10-04")
        ]

        for castItem in castItems {
            let item = BudgetLineItem(
                name: castItem.name,
                account: castItem.account,
                category: BudgetCategory.aboveTheLine.rawValue,
                subcategory: "Cast",
                section: "Cast",
                quantity: 1.0,
                days: 1.0,
                unitCost: 0.0,
                notes: "Add cast members to this category"
            )
            items.append(item)
        }

        // Crew items
        let crewRoles: [(name: String, account: String)] = [
            ("Director", "20-01"),
            ("Writer", "20-02"),
            ("Producer", "20-03"),
            ("Cinematographer", "20-04"),
            ("Sound", "20-05"),
            ("Editor", "20-06"),
            ("Lighting", "20-07"),
            ("Makeup", "20-08"),
            ("Wardrobe", "20-09")
        ]

        for role in crewRoles {
            let item = BudgetLineItem(
                name: role.name,
                account: role.account,
                category: BudgetCategory.belowTheLine.rawValue,
                subcategory: "Crew",
                section: "Crew",
                quantity: 1.0,
                days: 1.0,
                unitCost: 0.0,
                notes: ""
            )
            items.append(item)
        }

        // Other expenses
        let otherExpenses: [(name: String, account: String)] = [
            ("Food", "30-01"),
            ("Hard Drives", "30-02")
        ]

        for expense in otherExpenses {
            let item = BudgetLineItem(
                name: expense.name,
                account: expense.account,
                category: BudgetCategory.other.rawValue,
                subcategory: "Other",
                section: "Other",
                quantity: 1.0,
                days: 1.0,
                unitCost: 0.0,
                notes: ""
            )
            items.append(item)
        }

        guard !items.isEmpty else {
            throw TemplateError.noItemsLoaded
        }

        currentTemplateType = .shortFilm
        BudgetLogger.logTemplateLoad(name: "Short Film", itemCount: items.count)

        return items
    }

    // MARK: - Custom Template Operations

    func loadCustomTemplates() {
        if let data = UserDefaults.standard.data(forKey: customTemplatesKey),
           let decoded = try? JSONDecoder().decode([CustomBudgetTemplate].self, from: data) {
            customTemplates = decoded.sorted { $0.modifiedAt > $1.modifiedAt }
            BudgetLogger.info("Loaded \(customTemplates.count) custom templates", category: BudgetLogger.template)
        } else {
            customTemplates = []
        }
    }

    private func saveCustomTemplates() {
        if let encoded = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(encoded, forKey: customTemplatesKey)
        }
    }

    /// Save current budget as a custom template
    @discardableResult
    func saveAsCustomTemplate(
        name: String,
        description: String,
        categories: [CustomBudgetCategory],
        lineItems: [BudgetLineItem]
    ) -> CustomBudgetTemplate {
        let template = CustomBudgetTemplate(
            name: name,
            description: description,
            createdAt: Date(),
            modifiedAt: Date(),
            categories: categories,
            lineItems: lineItems
        )

        customTemplates.insert(template, at: 0)
        saveCustomTemplates()

        auditTrail.recordChange(
            action: .created,
            entityType: "CustomTemplate",
            entityID: template.id,
            details: "Created template '\(name)'"
        )

        BudgetLogger.logDataOperation(.create, entity: "CustomTemplate", success: true)
        return template
    }

    /// Update an existing custom template
    func updateCustomTemplate(
        _ template: CustomBudgetTemplate,
        name: String,
        description: String,
        categories: [CustomBudgetCategory],
        lineItems: [BudgetLineItem]
    ) {
        guard let index = customTemplates.firstIndex(where: { $0.id == template.id }) else { return }

        var updatedTemplate = template
        updatedTemplate.name = name
        updatedTemplate.description = description
        updatedTemplate.modifiedAt = Date()
        updatedTemplate.categories = categories
        updatedTemplate.lineItems = lineItems

        customTemplates[index] = updatedTemplate
        saveCustomTemplates()

        auditTrail.recordChange(
            action: .updated,
            entityType: "CustomTemplate",
            entityID: template.id,
            details: "Updated template '\(name)'"
        )

        BudgetLogger.logDataOperation(.update, entity: "CustomTemplate", success: true)
    }

    /// Delete a custom template
    func deleteCustomTemplate(_ template: CustomBudgetTemplate) {
        let templateName = template.name
        customTemplates.removeAll { $0.id == template.id }
        saveCustomTemplates()

        auditTrail.recordChange(
            action: .deleted,
            entityType: "CustomTemplate",
            entityID: template.id,
            details: "Deleted template '\(templateName)'"
        )

        BudgetLogger.logDataOperation(.delete, entity: "CustomTemplate", success: true)
    }

    /// Load a custom template
    func loadCustomTemplate(_ template: CustomBudgetTemplate) throws -> (items: [BudgetLineItem], categories: [CustomBudgetCategory]) {
        // Create new line items with fresh IDs
        let newLineItems = template.lineItems.map { item -> BudgetLineItem in
            BudgetLineItem(
                id: UUID(),
                name: item.name,
                account: item.account,
                category: item.category,
                subcategory: item.subcategory,
                section: item.section,
                quantity: item.quantity,
                days: item.days,
                unitCost: item.unitCost,
                totalBudget: item.totalBudget,
                notes: item.notes,
                isLinkedToRateCard: item.isLinkedToRateCard,
                rateCardID: item.rateCardID,
                linkedContactID: nil,
                linkedContactType: item.linkedContactType,
                parentItemID: nil,
                childItemIDs: nil
            )
        }

        // Create categories with fresh IDs
        let newCategories = template.categories.map { category in
            CustomBudgetCategory(
                id: UUID(),
                name: category.name,
                icon: category.icon,
                colorHex: category.colorHex,
                sortOrder: category.sortOrder,
                subcategories: category.subcategories,
                createdAt: Date()
            )
        }

        currentTemplateType = .standard
        BudgetLogger.logTemplateLoad(name: template.name, itemCount: newLineItems.count)

        return (newLineItems, newCategories)
    }

    // MARK: - Helper Methods

    private func convertTemplateToLineItems(_ template: BudgetTemplate) -> [BudgetLineItem] {
        var items: [BudgetLineItem] = []

        for sheet in template.sheets {
            let category = mapSheetToCategory(sheet.name)
            var currentSectionName: String? = nil

            for row in sheet.rows {
                // Track section headers
                if row.isSection {
                    currentSectionName = row.description
                    continue
                }

                // Skip subtotals
                guard !row.isSubtotal else { continue }

                let accountCode: String
                if let sectionName = currentSectionName {
                    accountCode = BudgetAccount.from(sectionName: sectionName).code
                } else {
                    accountCode = ""
                }

                let item = BudgetLineItem(
                    name: row.description,
                    account: accountCode,
                    category: category,
                    subcategory: extractSubcategory(from: row.id),
                    section: currentSectionName,
                    quantity: 0.0,
                    days: 0.0,
                    unitCost: 0.0,
                    totalBudget: 0.0,
                    notes: ""
                )

                items.append(item)
            }
        }

        return items
    }

    private func mapSheetToCategory(_ sheetName: String) -> String {
        switch sheetName {
        case "Above the Line":
            return BudgetCategory.aboveTheLine.rawValue
        case "Production Expenses":
            return BudgetCategory.belowTheLine.rawValue
        case "Post-Production Expenses", "Post-Production":
            return BudgetCategory.postProduction.rawValue
        case "Other Expenses":
            return BudgetCategory.other.rawValue
        default:
            return BudgetCategory.other.rawValue
        }
    }

    private func extractSubcategory(from accountId: String) -> String {
        let components = accountId.split(separator: "-")
        if let first = components.first {
            return "Dept \(first)"
        }
        return "General"
    }

    private func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context):
            return "Data corrupted at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .keyNotFound(let key, let context):
            return "Key '\(key.stringValue)' not found at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Value of type \(type) not found at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}
