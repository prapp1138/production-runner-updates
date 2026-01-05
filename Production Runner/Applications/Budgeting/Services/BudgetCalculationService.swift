import Foundation

/// Handles all budget calculations including summaries, variance analysis, and projections
/// Extracted from BudgetViewModel for single responsibility
struct BudgetCalculationService {

    // MARK: - Standard Summary Calculation

    /// Calculate budget summary from line items
    static func calculateSummary(from items: [BudgetLineItem]) -> BudgetSummary {
        var summary = BudgetSummary()

        for item in items {
            // Use item.total which automatically handles parent items (returns 0 for parents with children)
            let calculatedCost = item.total
            summary.totalBudget += calculatedCost

            switch item.category {
            case BudgetCategory.aboveTheLine.rawValue:
                summary.aboveTheLineTotal += calculatedCost
            case BudgetCategory.belowTheLine.rawValue:
                summary.belowTheLineTotal += calculatedCost
            case BudgetCategory.postProduction.rawValue:
                summary.postProductionTotal += calculatedCost
            case BudgetCategory.other.rawValue:
                summary.otherTotal += calculatedCost
            default:
                summary.otherTotal += calculatedCost
            }
        }

        BudgetLogger.logCalculation(type: "BudgetSummary", result: summary.totalBudget)
        return summary
    }

    // MARK: - Short Film Summary

    /// Calculate short film specific summary
    static func calculateShortFilmSummary(from items: [BudgetLineItem]) -> ShortFilmBudgetSummary {
        var castTotal: Double = 0
        var crewTotal: Double = 0
        var otherTotal: Double = 0

        for item in items {
            // Use item.total which automatically handles parent items (returns 0 for parents with children)
            let calculatedCost = item.total
            let section = item.section ?? item.subcategory
            switch section {
            case "Cast":
                castTotal += calculatedCost
            case "Crew":
                crewTotal += calculatedCost
            default:
                otherTotal += calculatedCost
            }
        }

        return ShortFilmBudgetSummary(
            totalBudget: castTotal + crewTotal + otherTotal,
            castTotal: castTotal,
            crewTotal: crewTotal,
            otherTotal: otherTotal
        )
    }

    // MARK: - Custom Category Summary

    /// Calculate summary for custom categories
    static func calculateCustomCategorySummary(
        from items: [BudgetLineItem],
        categories: [CustomBudgetCategory]
    ) -> CustomCategorySummary {
        var summary = CustomCategorySummary()

        // Create a lookup dictionary for quick parent access
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for item in items {
            // Use item.total which automatically handles parent items (returns 0 for parents with children)
            let calculatedCost = item.total
            summary.totalBudget += calculatedCost

            // For child items, use the parent's category for proper attribution
            let categorySourceItem: BudgetLineItem
            if let parentID = item.parentItemID, let parentItem = itemsByID[parentID] {
                categorySourceItem = parentItem
            } else {
                categorySourceItem = item
            }

            // Match item to custom category by name - only use item.category, not section
            if let category = categories.first(where: { $0.name == categorySourceItem.category }) {
                summary.categoryTotals[category.id, default: 0] += calculatedCost
            } else if let lastCategory = categories.last {
                // Fallback to "Other" or last category if no match
                summary.categoryTotals[lastCategory.id, default: 0] += calculatedCost
            }
        }

        return summary
    }

    // MARK: - Variance Analysis

    /// Calculate variance between budget and actual spending
    static func calculateVariance(
        budgeted: Double,
        actual: Double
    ) -> BudgetVariance {
        let variance = budgeted - actual
        let percentageUsed = budgeted > 0 ? (actual / budgeted) * 100 : 0
        let percentageRemaining = 100 - percentageUsed

        let status: BudgetVariance.Status
        if percentageUsed > 100 {
            status = .overBudget
        } else if percentageUsed > 90 {
            status = .nearLimit
        } else if percentageUsed > 75 {
            status = .warning
        } else {
            status = .onTrack
        }

        return BudgetVariance(
            budgeted: budgeted,
            actual: actual,
            variance: variance,
            percentageUsed: percentageUsed,
            percentageRemaining: percentageRemaining,
            status: status
        )
    }

    /// Calculate variance for each line item
    static func calculateItemVariances(
        items: [BudgetLineItem],
        transactions: [BudgetTransaction]
    ) -> [UUID: BudgetVariance] {
        var variances: [UUID: BudgetVariance] = [:]

        for item in items {
            let actual = transactions
                .filter { $0.lineItemID == item.id }
                .reduce(0) { $0 + $1.amount }

            variances[item.id] = calculateVariance(budgeted: item.total, actual: actual)
        }

        return variances
    }

    /// Calculate variance by category
    static func calculateCategoryVariances(
        items: [BudgetLineItem],
        transactions: [BudgetTransaction]
    ) -> [BudgetCategory: BudgetVariance] {
        var variances: [BudgetCategory: BudgetVariance] = [:]

        for category in BudgetCategory.allCases {
            let budgeted = items
                .filter { $0.category == category.rawValue }
                .reduce(0) { $0 + $1.total }

            let matchingCategories = category.matchingTransactionCategories()
            let actual = transactions
                .filter { matchingCategories.contains($0.category) }
                .reduce(0) { $0 + $1.amount }

            variances[category] = calculateVariance(budgeted: budgeted, actual: actual)
        }

        return variances
    }

    // MARK: - Section Calculations

    /// Calculate total for a section
    static func totalForSection(_ section: String, in items: [BudgetLineItem]) -> Double {
        items
            .filter { $0.section == section }
            .reduce(0) { $0 + $1.total }
    }

    /// Calculate totals by section
    static func totalsBySection(in items: [BudgetLineItem]) -> [String: Double] {
        var totals: [String: Double] = [:]

        for item in items {
            if let section = item.section {
                totals[section, default: 0] += item.total
            }
        }

        return totals
    }

    // MARK: - Projections

    /// Project remaining budget based on current spending rate
    static func projectRemaining(
        totalBudget: Double,
        spent: Double,
        daysElapsed: Int,
        totalDays: Int
    ) -> BudgetProjection {
        guard daysElapsed > 0, totalDays > 0 else {
            return BudgetProjection(
                dailyRate: 0,
                projectedTotal: spent,
                projectedRemaining: totalBudget - spent,
                daysRemaining: totalDays,
                onTrack: true
            )
        }

        let dailyRate = spent / Double(daysElapsed)
        let daysRemaining = totalDays - daysElapsed
        let projectedTotal = spent + (dailyRate * Double(daysRemaining))
        let projectedRemaining = totalBudget - projectedTotal
        let onTrack = projectedTotal <= totalBudget

        return BudgetProjection(
            dailyRate: dailyRate,
            projectedTotal: projectedTotal,
            projectedRemaining: projectedRemaining,
            daysRemaining: daysRemaining,
            onTrack: onTrack
        )
    }

    // MARK: - Currency Conversion

    /// Convert amount between currencies
    static func convert(
        amount: Double,
        from sourceCurrency: String,
        to targetCurrency: String,
        using rates: [String: Double]
    ) -> Double {
        guard let sourceRate = rates[sourceCurrency],
              let targetRate = rates[targetCurrency],
              sourceRate > 0 else {
            return amount
        }

        // Convert to base currency (USD) then to target
        let baseAmount = amount / sourceRate
        return baseAmount * targetRate
    }
}

// MARK: - Supporting Types

struct BudgetVariance {
    let budgeted: Double
    let actual: Double
    let variance: Double
    let percentageUsed: Double
    let percentageRemaining: Double
    let status: Status

    enum Status: String {
        case onTrack = "On Track"
        case warning = "Warning"
        case nearLimit = "Near Limit"
        case overBudget = "Over Budget"

        var color: String {
            switch self {
            case .onTrack: return "green"
            case .warning: return "yellow"
            case .nearLimit: return "orange"
            case .overBudget: return "red"
            }
        }
    }

    var isOverBudget: Bool {
        variance < 0
    }

    var formattedVariance: String {
        let prefix = variance >= 0 ? "+" : ""
        return prefix + variance.asCurrency()
    }
}

struct BudgetProjection {
    let dailyRate: Double
    let projectedTotal: Double
    let projectedRemaining: Double
    let daysRemaining: Int
    let onTrack: Bool

    var formattedDailyRate: String {
        dailyRate.asCurrency() + "/day"
    }

    var statusMessage: String {
        if onTrack {
            return "On track to finish under budget"
        } else {
            let overage = projectedTotal - projectedRemaining
            return "Projected to exceed budget by \(overage.asCurrency())"
        }
    }
}

// MARK: - Short Film Summary (moved from ViewModel)

struct ShortFilmBudgetSummary {
    var totalBudget: Double = 0
    var castTotal: Double = 0
    var crewTotal: Double = 0
    var otherTotal: Double = 0

    var categoryBreakdown: [ShortFilmCategory: Double] {
        [
            .cast: castTotal,
            .crew: crewTotal,
            .other: otherTotal
        ]
    }

    func percentage(for category: ShortFilmCategory) -> Double {
        guard totalBudget > 0 else { return 0 }
        let amount = categoryBreakdown[category] ?? 0
        return (amount / totalBudget) * 100
    }
}
