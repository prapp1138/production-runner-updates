import Foundation
import SwiftUI

// MARK: - Budget Account Codes
enum BudgetAccount: String, CaseIterable, Identifiable {
    case none = "No Account"
    
    // Above the Line (10-00 to 15-00)
    case developmentCosts = "10-00 - Development Costs"
    case storyRights = "11-00 - Story & Rights"
    case producerUnit = "12-00 - Producer Unit"
    case directorStaff = "13-00 - Director & Staff"
    case cast = "14-00 - Cast"
    case travelLiving = "15-00 - Travel & Living"
    
    // Below the Line - Production (20-00 to 39-00)
    case productionStaff = "20-00 - Production Staff"
    case extraTalent = "21-00 - Extra Talent"
    case setDesign = "22-00 - Set Design"
    case setConstruction = "23-00 - Set Construction"
    case setPreRigStrike = "24-00 - Set Pre-rig & Strike"
    case setOperations = "25-00 - Set Operations"
    case setDressing = "26-00 - Set Dressing"
    case property = "27-00 - Property"
    case wardrobe = "28-00 - Wardrobe"
    case electric = "29-00 - Electric"
    case camera = "30-00 - Camera"
    case productionSound = "31-00 - Production Sound"
    case makeupHair = "32-00 - Make-up & Hair"
    case transportation = "33-00 - Transportation"
    case locations = "34-00 - Locations"
    case pictureVehiclesAnimals = "35-00 - Picture Vehicles & Animals"
    case specialEffects = "36-00 - Special Effects"
    case visualEffectsPost = "37-00 - Visual Effects - Post"
    case filmLab = "38-00 - Film & Lab"
    case btlTravel = "39-00 - BTL Travel"
    
    // Post-Production (45-00 to 49-00)
    case filmEditing = "45-00 - Film Editing"
    case music = "46-00 - Music"
    case visualEffects = "47-00 - Visual Effects"
    case postProductionSound = "48-00 - Post Production Sound"
    case postProductionFilmLab = "49-00 - Post Production Film & Lab"
    
    // Other (55-00 to 58-00)
    case publicity = "55-00 - Publicity"
    case legalAccounting = "56-00 - Legal & Accounting"
    case generalExpense = "57-00 - General Expense"
    case insurance = "58-00 - Insurance"
    
    var id: String { rawValue }
    
    var code: String {
        switch self {
        case .none: return ""
        case .developmentCosts: return "10-00"
        case .storyRights: return "11-00"
        case .producerUnit: return "12-00"
        case .directorStaff: return "13-00"
        case .cast: return "14-00"
        case .travelLiving: return "15-00"
        case .productionStaff: return "20-00"
        case .extraTalent: return "21-00"
        case .setDesign: return "22-00"
        case .setConstruction: return "23-00"
        case .setPreRigStrike: return "24-00"
        case .setOperations: return "25-00"
        case .setDressing: return "26-00"
        case .property: return "27-00"
        case .wardrobe: return "28-00"
        case .electric: return "29-00"
        case .camera: return "30-00"
        case .productionSound: return "31-00"
        case .makeupHair: return "32-00"
        case .transportation: return "33-00"
        case .locations: return "34-00"
        case .pictureVehiclesAnimals: return "35-00"
        case .specialEffects: return "36-00"
        case .visualEffectsPost: return "37-00"
        case .filmLab: return "38-00"
        case .btlTravel: return "39-00"
        case .filmEditing: return "45-00"
        case .music: return "46-00"
        case .visualEffects: return "47-00"
        case .postProductionSound: return "48-00"
        case .postProductionFilmLab: return "49-00"
        case .publicity: return "55-00"
        case .legalAccounting: return "56-00"
        case .generalExpense: return "57-00"
        case .insurance: return "58-00"
        }
    }
    
    // Helper to get account from section name
    static func from(sectionName: String) -> BudgetAccount {
        let lowercased = sectionName.lowercased()
        
        // Above the Line
        if lowercased.contains("development") { return .developmentCosts }
        if lowercased.contains("story") && lowercased.contains("rights") { return .storyRights }
        if lowercased.contains("producer") { return .producerUnit }
        if lowercased.contains("director") { return .directorStaff }
        if lowercased.contains("cast") { return .cast }
        if lowercased.contains("travel") && lowercased.contains("living") { return .travelLiving }
        
        // Below the Line - Production
        if lowercased.contains("production staff") { return .productionStaff }
        if lowercased.contains("extra talent") { return .extraTalent }
        if lowercased.contains("set design") { return .setDesign }
        if lowercased.contains("set construction") { return .setConstruction }
        if lowercased.contains("pre-rig") || lowercased.contains("strike") { return .setPreRigStrike }
        if lowercased.contains("set operations") { return .setOperations }
        if lowercased.contains("set dressing") { return .setDressing }
        if lowercased.contains("property") { return .property }
        if lowercased.contains("wardrobe") { return .wardrobe }
        if lowercased.contains("electric") { return .electric }
        if lowercased.contains("camera") { return .camera }
        if lowercased.contains("production sound") { return .productionSound }
        if lowercased.contains("makeup") || lowercased.contains("hair") { return .makeupHair }
        if lowercased.contains("transportation") { return .transportation }
        if lowercased.contains("locations") { return .locations }
        if lowercased.contains("picture vehicles") || lowercased.contains("animals") { return .pictureVehiclesAnimals }
        if lowercased.contains("special effects") { return .specialEffects }
        if lowercased.contains("visual effects") && lowercased.contains("post") { return .visualEffectsPost }
        if lowercased.contains("film") && lowercased.contains("lab") && !lowercased.contains("post") { return .filmLab }
        if lowercased.contains("btl travel") || lowercased.contains("below the line travel") { return .btlTravel }
        
        // Post-Production
        if lowercased.contains("film editing") || lowercased.contains("editing") { return .filmEditing }
        if lowercased.contains("music") { return .music }
        if lowercased.contains("visual effects") && !lowercased.contains("post") { return .visualEffects }
        if lowercased.contains("post production sound") || lowercased.contains("post-production sound") { return .postProductionSound }
        if lowercased.contains("post production film") || lowercased.contains("post-production film") { return .postProductionFilmLab }
        
        // Other
        if lowercased.contains("publicity") { return .publicity }
        if lowercased.contains("legal") || lowercased.contains("accounting") { return .legalAccounting }
        if lowercased.contains("general expense") { return .generalExpense }
        if lowercased.contains("insurance") { return .insurance }
        
        return .none
    }
}

// MARK: - Budget Category Definitions
enum BudgetCategory: String, CaseIterable, Identifiable {
    case aboveTheLine = "Above the Line"
    case belowTheLine = "Below the Line"
    case postProduction = "Post-Production"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .aboveTheLine: return "star.fill"
        case .belowTheLine: return "film.fill"
        case .postProduction: return "waveform"
        case .other: return "folder.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .aboveTheLine: return .purple
        case .belowTheLine: return .blue
        case .postProduction: return .orange
        case .other: return .gray
        }
    }
    
    var subcategories: [String] {
        switch self {
        case .aboveTheLine:
            return ["Writers", "Producers", "Directors", "Cast"]
        case .belowTheLine:
            return ["Production Staff", "Camera", "Lighting", "Sound", "Art Department", "Wardrobe", "Makeup", "Locations", "Transportation", "Equipment"]
        case .postProduction:
            return ["Editing", "Sound Design", "Color Grading", "VFX", "Music"]
        case .other:
            return ["Insurance", "Legal", "Contingency", "Marketing"]
        }
    }

    // Get matching transaction categories for filtering expenses
    func matchingTransactionCategories() -> [String] {
        switch self {
        case .aboveTheLine:
            return [TransactionCategory.development.rawValue, TransactionCategory.aboveTheLine.rawValue]
        case .belowTheLine:
            return [TransactionCategory.production.rawValue, TransactionCategory.artCameraLightingSound.rawValue, TransactionCategory.locationsLogistics.rawValue]
        case .postProduction:
            return [TransactionCategory.postProduction.rawValue]
        case .other:
            return [TransactionCategory.marketingDistribution.rawValue, TransactionCategory.adminOfficeMisc.rawValue]
        }
    }
}

// MARK: - Custom Budget Category (User-defined)
struct CustomBudgetCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int
    var subcategories: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        sortOrder: Int = 0,
        subcategories: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.subcategories = subcategories
        self.createdAt = createdAt
    }

    var color: Color {
        Color.fromHex(colorHex)
    }

    // Default categories for Feature Film template
    static var featureFilmDefaults: [CustomBudgetCategory] {
        [
            CustomBudgetCategory(name: "Above the Line", icon: "star.fill", colorHex: "#AF52DE", sortOrder: 0, subcategories: ["Writers", "Producers", "Directors", "Cast"]),
            CustomBudgetCategory(name: "Below the Line", icon: "film.fill", colorHex: "#007AFF", sortOrder: 1, subcategories: ["Production Staff", "Camera", "Lighting", "Sound", "Art Department", "Wardrobe", "Makeup", "Locations", "Transportation", "Equipment"]),
            CustomBudgetCategory(name: "Post-Production", icon: "waveform", colorHex: "#FF9500", sortOrder: 2, subcategories: ["Editing", "Sound Design", "Color Grading", "VFX", "Music"]),
            CustomBudgetCategory(name: "Other", icon: "folder.fill", colorHex: "#8E8E93", sortOrder: 3, subcategories: ["Insurance", "Legal", "Contingency", "Marketing"])
        ]
    }

    // Default categories for Short Film template
    static var shortFilmDefaults: [CustomBudgetCategory] {
        [
            CustomBudgetCategory(name: "Cast", icon: "person.2.fill", colorHex: "#AF52DE", sortOrder: 0, subcategories: []),
            CustomBudgetCategory(name: "Crew", icon: "person.3.fill", colorHex: "#007AFF", sortOrder: 1, subcategories: []),
            CustomBudgetCategory(name: "Other", icon: "folder.fill", colorHex: "#8E8E93", sortOrder: 2, subcategories: [])
        ]
    }
}

// MARK: - Custom Category Summary
struct CustomCategorySummary {
    var totalBudget: Double = 0
    var categoryTotals: [UUID: Double] = [:] // category ID -> total

    func amount(for categoryID: UUID) -> Double {
        categoryTotals[categoryID] ?? 0
    }

    func percentage(for categoryID: UUID) -> Double {
        guard totalBudget > 0 else { return 0 }
        let amount = categoryTotals[categoryID] ?? 0
        return (amount / totalBudget) * 100
    }
}

// MARK: - Budget Summary Model
struct BudgetSummary {
    var totalBudget: Double = 0
    var aboveTheLineTotal: Double = 0
    var belowTheLineTotal: Double = 0
    var postProductionTotal: Double = 0
    var otherTotal: Double = 0
    
    var categoryBreakdown: [BudgetCategory: Double] {
        [
            .aboveTheLine: aboveTheLineTotal,
            .belowTheLine: belowTheLineTotal,
            .postProduction: postProductionTotal,
            .other: otherTotal
        ]
    }
    
    func percentage(for category: BudgetCategory) -> Double {
        guard totalBudget > 0 else { return 0 }
        let amount = categoryBreakdown[category] ?? 0
        return (amount / totalBudget) * 100
    }
}

// MARK: - Budget Section
struct BudgetSection: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var isExpanded: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        isExpanded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isExpanded = isExpanded
    }
}

// MARK: - Budget Version
struct BudgetVersion: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdDate: Date
    var lineItems: [BudgetLineItem]
    var transactions: [BudgetTransaction]
    var payrollItems: [PayrollLineItem]
    var isLocked: Bool
    var lockedAt: Date?
    var lockedBy: String?
    var currency: String
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        lineItems: [BudgetLineItem] = [],
        transactions: [BudgetTransaction] = [],
        payrollItems: [PayrollLineItem] = [],
        isLocked: Bool = false,
        lockedAt: Date? = nil,
        lockedBy: String? = nil,
        currency: String = "USD",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.lineItems = lineItems
        self.transactions = transactions
        self.payrollItems = payrollItems
        self.isLocked = isLocked
        self.lockedAt = lockedAt
        self.lockedBy = lockedBy
        self.currency = currency
        self.notes = notes
    }

    // Create a copy with a new ID
    func duplicate(newName: String? = nil) -> BudgetVersion {
        return BudgetVersion(
            id: UUID(),
            name: newName ?? "\(self.name) (Copy)",
            createdDate: Date(),
            lineItems: self.lineItems,
            transactions: self.transactions,
            payrollItems: self.payrollItems,
            isLocked: false,
            lockedAt: nil,
            lockedBy: nil,
            currency: self.currency,
            notes: ""
        )
    }

    // MARK: - Computed Properties

    /// Total budget amount
    var totalBudget: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }

    /// Total spent (from transactions)
    var totalSpent: Double {
        transactions
            .filter { $0.transactionType == TransactionType.expense.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    /// Remaining budget
    var remaining: Double {
        totalBudget - totalSpent
    }

    /// Percentage of budget used
    var percentageUsed: Double {
        guard totalBudget > 0 else { return 0 }
        return (totalSpent / totalBudget) * 100
    }

    /// Budget status based on spending
    var budgetStatus: BudgetStatus {
        let pct = percentageUsed
        if pct > 100 { return .overBudget }
        if pct > 90 { return .critical }
        if pct > 75 { return .warning }
        return .healthy
    }

    enum BudgetStatus: String {
        case healthy = "Healthy"
        case warning = "Warning"
        case critical = "Critical"
        case overBudget = "Over Budget"

        var color: String {
            switch self {
            case .healthy: return "green"
            case .warning: return "yellow"
            case .critical: return "orange"
            case .overBudget: return "red"
            }
        }
    }
}

// MARK: - Budget Line Item
struct BudgetLineItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var account: String
    var category: String
    var subcategory: String
    var section: String? // Optional section grouping
    var quantity: Double
    var days: Double
    var unitCost: Double
    var totalBudget: Double // Total budget allocated for this line item
    var notes: String
    var isLinkedToRateCard: Bool
    var rateCardID: UUID?
    var linkedContactID: UUID? // Reference to crew, cast, or vendor
    var linkedContactType: ContactType? // Type of contact linked
    var parentItemID: UUID? // For sub-items (e.g., cast members under Lead Cast)
    var childItemIDs: [UUID]? // For parent items that have sub-items
    var ignoreTotal: Bool = false // If true, exclude this item from budget totals

    var total: Double {
        // Parent items with children should return 0 (children hold the actual costs)
        if let childIDs = childItemIDs, !childIDs.isEmpty {
            return 0
        }
        // Always use calculated cost (totalBudget is for reference only)
        return quantity * days * unitCost
    }
    
    enum ContactType: String, Codable {
        case crew = "Crew"
        case cast = "Cast"
        case vendor = "Vendor"
    }
    
    // Check if this is a cast category that can have sub-items
    var canHaveCastMembers: Bool {
        return name.localizedCaseInsensitiveContains("Lead Cast") ||
               name.localizedCaseInsensitiveContains("Supporting Cast") ||
               name.localizedCaseInsensitiveContains("Day Player")
    }
    
    init(
        id: UUID = UUID(),
        name: String = "",
        account: String = "",
        category: String = BudgetCategory.belowTheLine.rawValue,
        subcategory: String = "",
        section: String? = nil,
        quantity: Double = 0.0,
        days: Double = 0.0,
        unitCost: Double = 0.0,
        totalBudget: Double = 0.0,
        notes: String = "",
        isLinkedToRateCard: Bool = false,
        rateCardID: UUID? = nil,
        linkedContactID: UUID? = nil,
        linkedContactType: ContactType? = nil,
        parentItemID: UUID? = nil,
        childItemIDs: [UUID]? = nil
    ) {
        self.id = id
        self.name = name
        self.account = account
        self.category = category
        self.subcategory = subcategory
        self.section = section
        self.quantity = quantity
        self.days = days
        self.unitCost = unitCost
        self.totalBudget = totalBudget
        self.notes = notes
        self.isLinkedToRateCard = isLinkedToRateCard
        self.rateCardID = rateCardID
        self.linkedContactID = linkedContactID
        self.linkedContactType = linkedContactType
        self.parentItemID = parentItemID
        self.childItemIDs = childItemIDs
    }
}

// MARK: - Budget Transaction
struct BudgetTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var amount: Double
    var category: String
    var department: String
    var transactionType: String
    var descriptionText: String
    var payee: String
    var notes: String
    var lineItemID: UUID?
    var vendorID: UUID?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Double = 0.0,
        category: String = BudgetCategory.other.rawValue,
        department: String = "",
        transactionType: String = "Expense",
        descriptionText: String = "",
        payee: String = "",
        notes: String = "",
        lineItemID: UUID? = nil,
        vendorID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.category = category
        self.department = department
        self.transactionType = transactionType
        self.descriptionText = descriptionText
        self.payee = payee
        self.notes = notes
        self.lineItemID = lineItemID
        self.vendorID = vendorID
    }
}

// MARK: - Transaction Type
enum TransactionType: String, CaseIterable {
    case expense = "Expense"
    case payment = "Payment"
    case refund = "Refund"
    case adjustment = "Adjustment"

    var displayName: String { rawValue }
}

// MARK: - Transaction Category
enum TransactionCategory: String, CaseIterable, Identifiable {
    case development = "Development"
    case aboveTheLine = "Above the Line"
    case production = "Production (Below the Line)"
    case artCameraLightingSound = "Art / Camera / Lighting / Sound"
    case locationsLogistics = "Locations & Logistics"
    case postProduction = "Post-Production"
    case marketingDistribution = "Marketing / Distribution"
    case adminOfficeMisc = "Admin / Office / Misc"

    var id: String { rawValue }
    var displayName: String { rawValue }

    // Map TransactionCategory to BudgetCategory for budget tracking
    func matchesBudgetCategory(_ budgetCategory: BudgetCategory) -> Bool {
        switch self {
        case .development, .aboveTheLine:
            return budgetCategory == .aboveTheLine
        case .production, .artCameraLightingSound, .locationsLogistics:
            return budgetCategory == .belowTheLine
        case .postProduction:
            return budgetCategory == .postProduction
        case .marketingDistribution, .adminOfficeMisc:
            return budgetCategory == .other
        }
    }
}

// MARK: - Rate Unit Types
enum RateUnit: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case flat = "Flat Rate"
    case hourly = "Hourly"
    case perItem = "Per Item"

    var displayName: String { rawValue }
}

// MARK: - Formatting Helpers
extension Double {
    func asCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}

// MARK: - Budget Search & Filter

struct BudgetSearchFilter {
    var searchText: String = ""
    var selectedCategory: BudgetCategory?
    var selectedSection: String?
    var minAmount: Double?
    var maxAmount: Double?
    var dateRange: ClosedRange<Date>?
    var showOnlyLinked: Bool = false
    var sortBy: SortOption = .name
    var sortAscending: Bool = true

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case amount = "Amount"
        case category = "Category"
        case section = "Section"
        case account = "Account"

        var keyPath: PartialKeyPath<BudgetLineItem> {
            switch self {
            case .name: return \BudgetLineItem.name
            case .amount: return \BudgetLineItem.total
            case .category: return \BudgetLineItem.category
            case .section: return \BudgetLineItem.section
            case .account: return \BudgetLineItem.account
            }
        }
    }

    /// Apply filter to line items
    func apply(to items: [BudgetLineItem]) -> [BudgetLineItem] {
        var filtered = items

        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter { item in
                item.name.lowercased().contains(query) ||
                item.subcategory.lowercased().contains(query) ||
                item.account.lowercased().contains(query) ||
                item.notes.lowercased().contains(query) ||
                (item.section?.lowercased().contains(query) ?? false)
            }
        }

        // Category filter
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category.rawValue }
        }

        // Section filter
        if let section = selectedSection {
            filtered = filtered.filter { $0.section == section }
        }

        // Amount range
        if let minAmt = minAmount {
            filtered = filtered.filter { $0.total >= minAmt }
        }
        if let maxAmt = maxAmount {
            filtered = filtered.filter { $0.total <= maxAmt }
        }

        // Linked items only
        if showOnlyLinked {
            filtered = filtered.filter { $0.isLinkedToRateCard || $0.linkedContactID != nil }
        }

        // Sorting
        filtered = sort(filtered)

        return filtered
    }

    private func sort(_ items: [BudgetLineItem]) -> [BudgetLineItem] {
        switch sortBy {
        case .name:
            return items.sorted { sortAscending ? $0.name < $1.name : $0.name > $1.name }
        case .amount:
            return items.sorted { sortAscending ? $0.total < $1.total : $0.total > $1.total }
        case .category:
            return items.sorted { sortAscending ? $0.category < $1.category : $0.category > $1.category }
        case .section:
            return items.sorted {
                let s1 = $0.section ?? ""
                let s2 = $1.section ?? ""
                return sortAscending ? s1 < s2 : s1 > s2
            }
        case .account:
            return items.sorted { sortAscending ? $0.account < $1.account : $0.account > $1.account }
        }
    }

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        selectedCategory != nil ||
        selectedSection != nil ||
        minAmount != nil ||
        maxAmount != nil ||
        showOnlyLinked
    }

    /// Reset all filters
    mutating func reset() {
        searchText = ""
        selectedCategory = nil
        selectedSection = nil
        minAmount = nil
        maxAmount = nil
        dateRange = nil
        showOnlyLinked = false
        sortBy = .name
        sortAscending = true
    }
}

// MARK: - Transaction Search & Filter

struct TransactionSearchFilter {
    var searchText: String = ""
    var transactionType: TransactionType?
    var category: String?
    var dateRange: ClosedRange<Date>?
    var minAmount: Double?
    var maxAmount: Double?
    var sortBy: SortOption = .date
    var sortAscending: Bool = false

    enum SortOption: String, CaseIterable {
        case date = "Date"
        case amount = "Amount"
        case category = "Category"
        case payee = "Payee"
    }

    /// Apply filter to transactions
    func apply(to transactions: [BudgetTransaction]) -> [BudgetTransaction] {
        var filtered = transactions

        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter { t in
                t.descriptionText.lowercased().contains(query) ||
                t.payee.lowercased().contains(query) ||
                t.notes.lowercased().contains(query)
            }
        }

        // Type filter
        if let type = transactionType {
            filtered = filtered.filter { $0.transactionType == type.rawValue }
        }

        // Category filter
        if let cat = category {
            filtered = filtered.filter { $0.category == cat }
        }

        // Date range
        if let range = dateRange {
            filtered = filtered.filter { range.contains($0.date) }
        }

        // Amount range
        if let minAmt = minAmount {
            filtered = filtered.filter { $0.amount >= minAmt }
        }
        if let maxAmt = maxAmount {
            filtered = filtered.filter { $0.amount <= maxAmt }
        }

        // Sorting
        filtered = sort(filtered)

        return filtered
    }

    private func sort(_ transactions: [BudgetTransaction]) -> [BudgetTransaction] {
        switch sortBy {
        case .date:
            return transactions.sorted { sortAscending ? $0.date < $1.date : $0.date > $1.date }
        case .amount:
            return transactions.sorted { sortAscending ? $0.amount < $1.amount : $0.amount > $1.amount }
        case .category:
            return transactions.sorted { sortAscending ? $0.category < $1.category : $0.category > $1.category }
        case .payee:
            return transactions.sorted { sortAscending ? $0.payee < $1.payee : $0.payee > $1.payee }
        }
    }

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        transactionType != nil ||
        category != nil ||
        dateRange != nil ||
        minAmount != nil ||
        maxAmount != nil
    }

    /// Reset all filters
    mutating func reset() {
        searchText = ""
        transactionType = nil
        category = nil
        dateRange = nil
        minAmount = nil
        maxAmount = nil
        sortBy = .date
        sortAscending = false
    }
}

// MARK: - Template Models

struct BudgetTemplate: Codable {
    let version: String
    let name: String
    let sheets: [BudgetSheet]
}

struct BudgetSheet: Codable {
    let id: String
    let name: String
    let rows: [BudgetRow]
}

struct BudgetRow: Codable {
    let id: String
    let description: String
    let amount: Double?
    let unit: String?
    let x: Double?
    let rate: Double?
    let isSection: Bool
    let isSubtotal: Bool
}

// MARK: - Custom Budget Template (User-saved)

struct CustomBudgetTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var createdAt: Date
    var modifiedAt: Date
    var categories: [CustomBudgetCategory]
    var lineItems: [BudgetLineItem]

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        categories: [CustomBudgetCategory] = [],
        lineItems: [BudgetLineItem] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.categories = categories
        self.lineItems = lineItems
    }

    var itemCount: Int {
        lineItems.count
    }

    var categoryCount: Int {
        categories.count
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedAt)
    }
}
