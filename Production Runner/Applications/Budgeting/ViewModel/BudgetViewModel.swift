import Foundation
import SwiftUI
import CoreData
import Combine

// MARK: - Budget Template Type
enum BudgetTemplateType: String, Codable {
    case standard = "Standard"
    case shortFilm = "Short Film"
    case featureFilm = "Feature Film"
    case tvShow = "TV Show"
}

// MARK: - Short Film Category (for Short Film template)
enum ShortFilmCategory: String, CaseIterable, Identifiable {
    case cast = "Cast"
    case crew = "Crew"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cast: return "person.2.fill"
        case .crew: return "person.3.fill"
        case .other: return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .cast: return .purple
        case .crew: return .blue
        case .other: return .gray
        }
    }
}

// MARK: - Budget ViewModel

/// Main ViewModel for the Budgeting app
/// Coordinates between services and provides a unified interface for views
class BudgetViewModel: ObservableObject {

    // MARK: - Published Properties (UI State)

    @Published var lineItems: [BudgetLineItem] = []
    @Published var transactions: [BudgetTransaction] = []
    @Published var summary: BudgetSummary = BudgetSummary()
    @Published var selectedCategory: BudgetCategory = .aboveTheLine
    @Published var selectedShortFilmCategory: ShortFilmCategory = .cast
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var expandedSections: Set<String> = []
    @Published var currentTemplateType: BudgetTemplateType = .standard
    @Published var shortFilmSummary: ShortFilmBudgetSummary = ShortFilmBudgetSummary()
    @Published var customCategorySummary: CustomCategorySummary = CustomCategorySummary()
    @Published var filter: BudgetSearchFilter = BudgetSearchFilter()

    // Payroll-specific state
    @Published var payrollItems: [PayrollLineItem] = []
    @Published var payrollSummary: PayrollSummary = PayrollSummary()
    @Published var selectedPayrollContactType: PayrollLineItem.ContactType? = nil
    @Published var payrollSearchText: String = ""
    @Published var payrollSortOption: PayrollSortOption = .nameAscending

    // MARK: - Service Layer

    private let versionManager: BudgetVersionManager
    private let templateManager: BudgetTemplateManager
    private let categoryManager: BudgetCategoryManager
    private let transactionManager: BudgetTransactionManager
    private let rateCardManager: BudgetRateCardManager
    private let payrollManager: BudgetPayrollManager
    private let currencyManager: CurrencyManager
    private let auditTrail: BudgetAuditTrail

    // MARK: - Private Properties

    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties (Service Proxies)

    var budgetVersions: [BudgetVersion] {
        versionManager.versions
    }

    var selectedVersion: BudgetVersion? {
        versionManager.selectedVersion
    }

    var customCategories: [CustomBudgetCategory] {
        categoryManager.customCategories
    }

    var selectedCustomCategoryID: UUID? {
        get { categoryManager.selectedCategoryID }
        set { categoryManager.selectedCategoryID = newValue }
    }

    var rateCards: [RateCardEntity] {
        rateCardManager.rateCards
    }

    var customTemplates: [CustomBudgetTemplate] {
        templateManager.customTemplates
    }

    var canUndo: Bool {
        auditTrail.canUndo
    }

    var canRedo: Bool {
        auditTrail.canRedo
    }

    // MARK: - Initialization

    init(context: NSManagedObjectContext) {
        self.context = context

        // Initialize services
        self.auditTrail = BudgetAuditTrail()
        self.versionManager = BudgetVersionManager(context: context, auditTrail: auditTrail)
        self.templateManager = BudgetTemplateManager(auditTrail: auditTrail)
        self.categoryManager = BudgetCategoryManager(auditTrail: auditTrail)
        self.transactionManager = BudgetTransactionManager(context: context, auditTrail: auditTrail)
        self.rateCardManager = BudgetRateCardManager(context: context, auditTrail: auditTrail)
        self.payrollManager = BudgetPayrollManager(context: context, auditTrail: auditTrail)
        self.currencyManager = CurrencyManager()

        // Load initial data
        loadInitialData()
        setupObservers()

        BudgetLogger.info("BudgetViewModel initialized", category: BudgetLogger.general)
    }

    private func loadInitialData() {
        // Load from selected version
        if let version = versionManager.selectedVersion {
            lineItems = version.lineItems
            transactions = version.transactions
            payrollManager.loadFromVersion(version)
            payrollItems = payrollManager.payrollItems
            expandedSections = versionManager.getExpandedSections(for: version.id)
            if expandedSections.isEmpty {
                expandedSections = Set(lineItems.compactMap { $0.section })
            }
        }

        calculateSummary()
        calculatePayrollSummary()
    }

    // MARK: - Version Management

    func loadVersions() {
        versionManager.loadVersions()
        if let version = versionManager.selectedVersion {
            selectVersion(version)
        }
    }

    func selectVersion(_ version: BudgetVersion) {
        versionManager.selectVersion(version)
        lineItems = version.lineItems
        transactions = version.transactions
        transactionManager.setTransactions(version.transactions)
        payrollManager.loadFromVersion(version)
        payrollItems = payrollManager.payrollItems
        expandedSections = versionManager.getExpandedSections(for: version.id)
        if expandedSections.isEmpty {
            expandedSections = Set(lineItems.compactMap { $0.section })
        }
        calculateSummary()
        calculatePayrollSummary()
    }

    func createNewVersion(name: String, copyFromCurrent: Bool = true) {
        let newVersion = versionManager.createVersion(name: name, copyFromCurrent: copyFromCurrent)
        selectVersion(newVersion)
    }

    func renameVersion(_ version: BudgetVersion, to newName: String) {
        versionManager.renameVersion(version, to: newName)
    }

    func deleteVersion(_ version: BudgetVersion) {
        versionManager.deleteVersion(version)
        if let current = versionManager.selectedVersion {
            selectVersion(current)
        }
    }

    func duplicateVersion(_ version: BudgetVersion) {
        let newVersion = versionManager.duplicateVersion(version)
        selectVersion(newVersion)
    }

    func lockVersion(_ version: BudgetVersion) {
        versionManager.lockVersion(version)
    }

    func unlockVersion(_ version: BudgetVersion) {
        versionManager.unlockVersion(version)
    }

    private func updateCurrentVersion() {
        versionManager.updateLineItems(lineItems)
        versionManager.updateTransactions(transactions)
        if var version = versionManager.selectedVersion {
            payrollManager.saveToVersion(&version)
            versionManager.updateVersion(version)
        }
        if let versionID = selectedVersion?.id {
            versionManager.saveExpandedSections(expandedSections, for: versionID)
        }
    }

    // MARK: - Section Management

    func toggleSection(_ sectionName: String) {
        if expandedSections.contains(sectionName) {
            expandedSections.remove(sectionName)
        } else {
            expandedSections.insert(sectionName)
        }
        // Persist section state
        if let versionID = selectedVersion?.id {
            versionManager.saveExpandedSections(expandedSections, for: versionID)
        }
    }

    func isSectionExpanded(_ sectionName: String) -> Bool {
        expandedSections.contains(sectionName)
    }

    var sectionsForCurrentCategory: [String] {
        let items = filteredLineItems
        let sections = Set(items.compactMap { $0.section })
        return Array(sections).sorted()
    }

    func items(forSection section: String) -> [BudgetLineItem] {
        filteredLineItems.filter { $0.section == section && $0.parentItemID == nil }
    }

    var ungroupedItems: [BudgetLineItem] {
        filteredLineItems.filter { $0.section == nil && $0.parentItemID == nil }
    }

    func totalForSection(_ section: String) -> Double {
        // Get parent items for this section
        let parentItems = items(forSection: section)

        // Calculate total including child items
        return parentItems.reduce(0) { total, item in
            // If this item has children, sum the children's totals instead
            if let childIDs = item.childItemIDs, !childIDs.isEmpty {
                let childrenTotal = lineItems
                    .filter { childIDs.contains($0.id) }
                    .reduce(0) { $0 + $1.total }
                return total + childrenTotal
            }
            // Otherwise use the item's own total
            return total + item.total
        }
    }

    // MARK: - Data Loading

    func loadData() {
        isLoading = true
        defer { isLoading = false }

        rateCardManager.loadRateCards()
        calculateSummary()
    }

    func refresh() {
        loadData()
    }

    // MARK: - Template Loading

    func loadStandardTemplate() {
        do {
            let items = try templateManager.loadStandardTemplate()
            lineItems = items
            expandedSections = Set(items.compactMap { $0.section })
            currentTemplateType = .featureFilm
            categoryManager.loadDefaults(for: .featureFilm)
            calculateSummary()
            updateCurrentVersion()
        } catch {
            BudgetLogger.logTemplateError(error, templateName: "Standard")
        }
    }

    func loadStandardTemplateWithResult() throws -> Int {
        let items = try templateManager.loadStandardTemplate()
        lineItems = items
        expandedSections = Set(items.compactMap { $0.section })
        currentTemplateType = .featureFilm
        categoryManager.loadDefaults(for: .featureFilm)
        calculateSummary()
        updateCurrentVersion()
        return items.count
    }

    func loadShortFilmTemplate() throws -> Int {
        let items = try templateManager.loadShortFilmTemplate()
        lineItems = items
        expandedSections = Set(["Cast", "Crew", "Other"])
        currentTemplateType = .shortFilm
        selectedShortFilmCategory = .cast
        categoryManager.loadDefaults(for: .shortFilm)
        calculateSummary()
        calculateShortFilmSummary()
        updateCurrentVersion()
        return items.count
    }

    // MARK: - Custom Template Management

    func loadCustomTemplates() {
        templateManager.loadCustomTemplates()
    }

    func saveAsCustomTemplate(name: String, description: String) -> CustomBudgetTemplate {
        templateManager.saveAsCustomTemplate(
            name: name,
            description: description,
            categories: customCategories,
            lineItems: lineItems
        )
    }

    func updateCustomTemplate(_ template: CustomBudgetTemplate, name: String, description: String) {
        templateManager.updateCustomTemplate(
            template,
            name: name,
            description: description,
            categories: customCategories,
            lineItems: lineItems
        )
    }

    func deleteCustomTemplate(_ template: CustomBudgetTemplate) {
        templateManager.deleteCustomTemplate(template)
    }

    func loadCustomTemplate(_ template: CustomBudgetTemplate) throws -> Int {
        let (items, categories) = try templateManager.loadCustomTemplate(template)
        lineItems = items
        categoryManager.replaceCategories(categories)
        expandedSections = Set(items.compactMap { $0.section })
        currentTemplateType = .standard
        calculateSummary()
        calculateCustomCategorySummary()
        updateCurrentVersion()
        return items.count
    }

    // MARK: - Filtered Line Items

    var filteredLineItems: [BudgetLineItem] {
        let categoryFiltered: [BudgetLineItem]

        if let categoryID = selectedCustomCategoryID,
           let category = customCategories.first(where: { $0.id == categoryID }) {
            categoryFiltered = lineItems.filter { item in
                item.category == category.name
            }
        } else if currentTemplateType == .shortFilm {
            categoryFiltered = lineItems.filter { item in
                let section = item.section ?? item.subcategory
                return section == selectedShortFilmCategory.rawValue
            }
        } else {
            categoryFiltered = lineItems.filter { item in
                item.category == selectedCategory.rawValue
            }
        }

        // Apply additional filters
        var result = categoryFiltered

        if !searchText.isEmpty {
            result = result.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.subcategory.localizedCaseInsensitiveContains(searchText) ||
                item.account.localizedCaseInsensitiveContains(searchText) ||
                item.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply advanced filter if active
        if filter.hasActiveFilters {
            result = filter.apply(to: result)
        }

        return result
    }

    var categoryTotals: [String: Double] {
        var totals: [String: Double] = [:]
        for item in lineItems {
            totals[item.category, default: 0] += item.total
        }
        return totals
    }

    // MARK: - Budget Line Item Operations

    func addLineItem(_ item: BudgetLineItem) {
        // Validate
        let validationResult = BudgetValidation.validate(item, existingItems: lineItems)
        validationResult.logIfFailure()

        lineItems.append(item)
        calculateSummary()
        updateCurrentVersion()
        objectWillChange.send()

        // Save to CoreData
        saveLineItemToCoreData(item)

        auditTrail.recordLineItemChange(action: .created, item: item)
    }

    func updateLineItem(_ item: BudgetLineItem) {
        guard let index = lineItems.firstIndex(where: { $0.id == item.id }) else { return }

        // Validate
        let validationResult = BudgetValidation.validate(item, existingItems: lineItems)
        validationResult.logIfFailure()

        let previousItem = lineItems[index]
        lineItems[index] = item
        calculateSummary()
        updateCurrentVersion()
        objectWillChange.send()

        // Update in CoreData
        updateLineItemInCoreData(item)

        auditTrail.recordLineItemChange(action: .updated, item: item, previousItem: previousItem)
    }

    func deleteLineItem(_ item: BudgetLineItem) {
        lineItems.removeAll { $0.id == item.id }
        calculateSummary()
        updateCurrentVersion()
        objectWillChange.send()

        // Delete from CoreData
        deleteLineItemFromCoreData(item.id)

        auditTrail.recordLineItemChange(action: .deleted, item: item)
    }

    func deleteLineItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredLineItems[$0] }
        for item in itemsToDelete {
            deleteLineItem(item)
        }
    }

    // MARK: - CoreData Operations for Line Items

    private func saveLineItemToCoreData(_ item: BudgetLineItem) {
        let _ = BudgetLineItemEntity.create(
            name: item.name,
            account: item.account,
            category: item.category,
            subcategory: item.subcategory,
            section: item.section,
            quantity: item.quantity,
            days: item.days,
            unitCost: item.unitCost,
            notes: item.notes,
            in: context
        )
        BudgetLogger.logDataOperation(.create, entity: "BudgetLineItem", success: true)
    }

    private func updateLineItemInCoreData(_ item: BudgetLineItem) {
        let request: NSFetchRequest<BudgetLineItemEntity> = BudgetLineItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                entity.update(
                    name: item.name,
                    account: item.account,
                    category: item.category,
                    subcategory: item.subcategory,
                    quantity: item.quantity,
                    days: item.days,
                    unitCost: item.unitCost,
                    notes: item.notes
                )
                BudgetLogger.logDataOperation(.update, entity: "BudgetLineItem", success: true)
            }
        } catch {
            BudgetLogger.error("Failed to update line item in CoreData: \(error.localizedDescription)", category: BudgetLogger.data)
        }
    }

    private func deleteLineItemFromCoreData(_ id: UUID) {
        let request: NSFetchRequest<BudgetLineItemEntity> = BudgetLineItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                entity.delete()
                BudgetLogger.logDataOperation(.delete, entity: "BudgetLineItem", success: true)
            }
        } catch {
            BudgetLogger.error("Failed to delete line item from CoreData: \(error.localizedDescription)", category: BudgetLogger.data)
        }
    }

    // MARK: - Transaction Operations

    func addTransaction(_ transaction: BudgetTransaction) {
        let result = transactionManager.addTransaction(transaction, budgetRemaining: selectedVersion?.remaining)
        if case .success = result {
            transactions = transactionManager.transactions
            updateCurrentVersion()
            objectWillChange.send()
        }
    }

    func updateTransaction(_ transaction: BudgetTransaction) {
        let result = transactionManager.updateTransaction(transaction)
        if case .success = result {
            transactions = transactionManager.transactions
            updateCurrentVersion()
            objectWillChange.send()
        }
    }

    func deleteTransaction(_ transaction: BudgetTransaction) {
        transactionManager.deleteTransaction(transaction)
        transactions = transactionManager.transactions
        updateCurrentVersion()
        objectWillChange.send()
    }

    // MARK: - Summary Calculation

    private func calculateSummary() {
        summary = BudgetCalculationService.calculateSummary(from: lineItems)

        if currentTemplateType == .shortFilm {
            calculateShortFilmSummary()
        }

        calculateCustomCategorySummary()
    }

    func calculateShortFilmSummary() {
        shortFilmSummary = BudgetCalculationService.calculateShortFilmSummary(from: lineItems)
    }

    func calculateCustomCategorySummary() {
        customCategorySummary = BudgetCalculationService.calculateCustomCategorySummary(
            from: lineItems,
            categories: customCategories
        )
    }

    // MARK: - Variance Analysis

    func getVariance(for item: BudgetLineItem) -> BudgetVariance {
        let actual = transactions
            .filter { $0.lineItemID == item.id }
            .reduce(0) { $0 + $1.amount }
        return BudgetCalculationService.calculateVariance(budgeted: item.total, actual: actual)
    }

    func getCategoryVariances() -> [BudgetCategory: BudgetVariance] {
        BudgetCalculationService.calculateCategoryVariances(items: lineItems, transactions: transactions)
    }

    // MARK: - Custom Category Management

    func loadCustomCategories() {
        categoryManager.loadCustomCategories()
    }

    func saveCustomCategories() {
        categoryManager.saveCustomCategories()
    }

    func addCustomCategory(_ category: CustomBudgetCategory) {
        categoryManager.addCategory(category)
        calculateCustomCategorySummary()
    }

    func updateCustomCategory(_ category: CustomBudgetCategory) {
        categoryManager.updateCategory(category)
        calculateCustomCategorySummary()
    }

    func deleteCustomCategory(_ category: CustomBudgetCategory) {
        categoryManager.deleteCategory(category)
        calculateCustomCategorySummary()
    }

    func reorderCustomCategories(from source: IndexSet, to destination: Int) {
        categoryManager.reorderCategories(from: source, to: destination)
    }

    func loadDefaultCategories(for templateType: BudgetTemplateType) {
        categoryManager.loadDefaults(for: templateType)
        calculateCustomCategorySummary()
    }

    func itemCount(for category: CustomBudgetCategory) -> Int {
        categoryManager.itemCount(for: category, in: lineItems)
    }

    var filteredLineItemsByCustomCategory: [BudgetLineItem] {
        categoryManager.filterItems(lineItems, searchText: searchText)
    }

    // MARK: - Rate Card Operations

    func createRateCard(name: String, category: String, unit: String, rate: Double, notes: String = "") {
        rateCardManager.createRateCard(name: name, category: category, unit: unit, rate: rate, notes: notes)
    }

    func deleteRateCard(_ rateCard: RateCardEntity) {
        rateCardManager.deleteRateCard(rateCard)
    }

    func linkItemToRateCard(item: BudgetLineItem, rateCard: RateCardEntity) {
        var updatedItem = item
        rateCardManager.linkItemToRateCard(item: &updatedItem, rateCard: rateCard)
        updateLineItem(updatedItem)
    }

    // MARK: - Contact Linking

    func linkContactToItem(itemID: UUID, contactID: UUID, contactType: BudgetLineItem.ContactType) {
        guard let index = lineItems.firstIndex(where: { $0.id == itemID }) else { return }
        lineItems[index].linkedContactID = contactID
        lineItems[index].linkedContactType = contactType
        calculateSummary()
        updateCurrentVersion()
    }

    func unlinkContactFromItem(itemID: UUID) {
        guard let index = lineItems.firstIndex(where: { $0.id == itemID }) else { return }
        lineItems[index].linkedContactID = nil
        lineItems[index].linkedContactType = nil
        calculateSummary()
        updateCurrentVersion()
    }

    // MARK: - Cast Member Management

    func addCastMemberToItem(parentItemID: UUID, contactID: UUID, contactName: String, dayRate: Double, shootDays: Double) {
        guard let parentIndex = lineItems.firstIndex(where: { $0.id == parentItemID }) else { return }

        let parentItem = lineItems[parentIndex]

        let castMember = BudgetLineItem(
            name: contactName,
            account: parentItem.account,
            category: parentItem.category,
            subcategory: parentItem.subcategory,
            section: parentItem.section,
            quantity: 1,
            days: shootDays,
            unitCost: dayRate,
            notes: "Cast member linked to \(parentItem.name)",
            linkedContactID: contactID,
            linkedContactType: .cast,
            parentItemID: parentItemID
        )

        lineItems.append(castMember)

        var updatedParent = parentItem
        if updatedParent.childItemIDs == nil {
            updatedParent.childItemIDs = []
        }
        updatedParent.childItemIDs?.append(castMember.id)
        lineItems[parentIndex] = updatedParent

        calculateSummary()
        updateCurrentVersion()
        objectWillChange.send()

        auditTrail.recordLineItemChange(action: .created, item: castMember)
    }

    func removeCastMember(_ castMemberID: UUID) {
        guard let castMemberIndex = lineItems.firstIndex(where: { $0.id == castMemberID }),
              let parentID = lineItems[castMemberIndex].parentItemID else { return }

        let castMember = lineItems[castMemberIndex]
        lineItems.remove(at: castMemberIndex)

        if let parentIndex = lineItems.firstIndex(where: { $0.id == parentID }) {
            var updatedParent = lineItems[parentIndex]
            updatedParent.childItemIDs?.removeAll { $0 == castMemberID }
            lineItems[parentIndex] = updatedParent
        }

        calculateSummary()
        updateCurrentVersion()
        objectWillChange.send()

        auditTrail.recordLineItemChange(action: .deleted, item: castMember)
    }

    func childItems(for parentID: UUID) -> [BudgetLineItem] {
        lineItems.filter { $0.parentItemID == parentID }
    }

    // MARK: - Export Operations

    func exportToCSV() -> Data? {
        BudgetExportService.exportToCSV(items: lineItems, summary: summary)
    }

    func exportTransactionsToCSV() -> Data? {
        BudgetExportService.exportTransactionsToCSV(transactions: transactions)
    }

    func exportToJSON() -> Data? {
        guard let version = selectedVersion else { return nil }
        return BudgetExportService.exportToJSON(version: version, summary: summary)
    }

    func exportToPDF() -> Data? {
        guard let version = selectedVersion else { return nil }
        return BudgetExportService.exportToPDF(version: version, summary: summary)
    }

    // MARK: - Currency Operations

    var baseCurrency: String {
        currencyManager.baseCurrency
    }

    func setBaseCurrency(_ code: String) {
        currencyManager.setBaseCurrency(code)
    }

    func formatCurrency(_ amount: Double) -> String {
        currencyManager.format(amount)
    }

    // MARK: - Audit Trail

    func getRecentAuditEntries(limit: Int = 50) -> [AuditEntry] {
        auditTrail.recentEntries(limit: limit)
    }

    func getAuditEntries(for itemID: UUID) -> [AuditEntry] {
        auditTrail.entries(for: itemID)
    }

    // MARK: - Observers

    private func setupObservers() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe version manager changes
        versionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe category manager changes
        categoryManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe payroll manager changes
        payrollManager.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.payrollItems = self.payrollManager.payrollItems
                self.calculatePayrollSummary()
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe payroll search text changes
        $payrollSearchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Payroll Management

    func addPayrollItem(_ item: PayrollLineItem) {
        let validation = payrollManager.validatePayrollItem(item)
        switch validation {
        case .success:
            payrollManager.addPayrollItem(item)
            updateCurrentVersion()
            BudgetLogger.info("Added payroll item: \(item.personName)", category: BudgetLogger.general)
        case .failure(let error):
            BudgetLogger.error("Failed to add payroll item: \(error.localizedDescription)", category: BudgetLogger.general)
        }
    }

    func updatePayrollItem(_ item: PayrollLineItem) {
        let validation = payrollManager.validatePayrollItem(item)
        switch validation {
        case .success:
            payrollManager.updatePayrollItem(item)
            updateCurrentVersion()
            BudgetLogger.info("Updated payroll item: \(item.personName)", category: BudgetLogger.general)
        case .failure(let error):
            BudgetLogger.error("Failed to update payroll item: \(error.localizedDescription)", category: BudgetLogger.general)
        }
    }

    func deletePayrollItem(_ item: PayrollLineItem) {
        payrollManager.deletePayrollItem(item)
        updateCurrentVersion()
        BudgetLogger.info("Deleted payroll item: \(item.personName)", category: BudgetLogger.general)
    }

    func addPayPeriod(to itemID: UUID, period: PayrollPayPeriod) {
        let validation = payrollManager.validatePayPeriod(period)
        switch validation {
        case .success:
            payrollManager.addPayPeriod(to: itemID, period: period)
            updateCurrentVersion()
            BudgetLogger.info("Added pay period: \(period.periodName)", category: BudgetLogger.general)
        case .failure(let error):
            BudgetLogger.error("Failed to add pay period: \(error.localizedDescription)", category: BudgetLogger.general)
        }
    }

    func updatePayPeriod(itemID: UUID, period: PayrollPayPeriod) {
        let validation = payrollManager.validatePayPeriod(period)
        switch validation {
        case .success:
            payrollManager.updatePayPeriod(itemID: itemID, period: period)
            updateCurrentVersion()
            BudgetLogger.info("Updated pay period: \(period.periodName)", category: BudgetLogger.general)
        case .failure(let error):
            BudgetLogger.error("Failed to update pay period: \(error.localizedDescription)", category: BudgetLogger.general)
        }
    }

    func deletePayPeriod(itemID: UUID, periodID: UUID) {
        payrollManager.deletePayPeriod(itemID: itemID, periodID: periodID)
        updateCurrentVersion()
        BudgetLogger.info("Deleted pay period", category: BudgetLogger.general)
    }

    func updatePaymentStatus(itemID: UUID, periodID: UUID, status: PayrollPayPeriod.PaymentStatus) {
        payrollManager.updatePaymentStatus(itemID: itemID, periodID: periodID, status: status)
        updateCurrentVersion()
        BudgetLogger.info("Updated payment status to: \(status.rawValue)", category: BudgetLogger.general)
    }

    func calculatePayrollSummary() {
        payrollSummary = payrollManager.calculateSummary()
    }

    // MARK: - Payroll Filtering & Queries

    var filteredPayrollItems: [PayrollLineItem] {
        var items = payrollItems

        // Filter by contact type
        if let contactType = selectedPayrollContactType {
            items = items.filter { $0.contactType == contactType }
        }

        // Filter by search text
        if !payrollSearchText.isEmpty {
            items = items.filter { $0.matches(searchText: payrollSearchText) }
        }

        // Sort
        return payrollManager.sortedItems(by: payrollSortOption)
            .filter { items.contains($0) }
    }

    func payrollItems(for contactType: PayrollLineItem.ContactType) -> [PayrollLineItem] {
        payrollManager.items(for: contactType)
    }

    func payrollItems(for department: String) -> [PayrollLineItem] {
        payrollManager.items(for: department)
    }

    func upcomingPayments(within days: Int = 7) -> [(item: PayrollLineItem, period: PayrollPayPeriod)] {
        payrollManager.upcomingPayments(within: days)
    }

    func overduePayments() -> [(item: PayrollLineItem, period: PayrollPayPeriod)] {
        payrollManager.overduePayments()
    }
}
