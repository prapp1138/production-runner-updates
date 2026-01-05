import Foundation
import CoreData
import Combine

// MARK: - Budget Payroll Manager

final class BudgetPayrollManager: ObservableObject {
    @Published private(set) var payrollItems: [PayrollLineItem] = []

    private let context: NSManagedObjectContext
    private let auditTrail: BudgetAuditTrail

    init(context: NSManagedObjectContext, auditTrail: BudgetAuditTrail) {
        self.context = context
        self.auditTrail = auditTrail
    }

    // MARK: - CRUD Operations

    func addPayrollItem(_ item: PayrollLineItem) {
        payrollItems.append(item)
        auditTrail.recordChange(
            action: .created,
            entityType: "PayrollLineItem",
            entityID: item.id,
            details: "Added \(item.personName) (\(item.role))"
        )
        objectWillChange.send()
    }

    func updatePayrollItem(_ item: PayrollLineItem) {
        if let index = payrollItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.updatedAt = Date()
            payrollItems[index] = updatedItem
            auditTrail.recordChange(
                action: .updated,
                entityType: "PayrollLineItem",
                entityID: item.id,
                details: "Updated \(item.personName)"
            )
            objectWillChange.send()
        }
    }

    func deletePayrollItem(_ item: PayrollLineItem) {
        payrollItems.removeAll { $0.id == item.id }
        auditTrail.recordChange(
            action: .deleted,
            entityType: "PayrollLineItem",
            entityID: item.id,
            details: "Deleted \(item.personName) (\(item.role))"
        )
        objectWillChange.send()
    }

    func deletePayrollItem(withID id: UUID) {
        if let item = payrollItems.first(where: { $0.id == id }) {
            deletePayrollItem(item)
        }
    }

    // MARK: - Pay Period Management

    func addPayPeriod(to itemID: UUID, period: PayrollPayPeriod) {
        if let index = payrollItems.firstIndex(where: { $0.id == itemID }) {
            var item = payrollItems[index]
            item.addPayPeriod(period)
            payrollItems[index] = item
            auditTrail.recordChange(
                action: .created,
                entityType: "PayrollPayPeriod",
                entityID: period.id,
                details: "Added \(period.periodName) for \(item.personName)"
            )
            objectWillChange.send()
        }
    }

    func updatePayPeriod(itemID: UUID, period: PayrollPayPeriod) {
        if let index = payrollItems.firstIndex(where: { $0.id == itemID }) {
            var item = payrollItems[index]
            item.updatePayPeriod(period)
            payrollItems[index] = item
            auditTrail.recordChange(
                action: .updated,
                entityType: "PayrollPayPeriod",
                entityID: period.id,
                details: "Updated \(period.periodName) for \(item.personName)"
            )
            objectWillChange.send()
        }
    }

    func deletePayPeriod(itemID: UUID, periodID: UUID) {
        if let itemIndex = payrollItems.firstIndex(where: { $0.id == itemID }) {
            var item = payrollItems[itemIndex]
            if let period = item.payPeriod(withID: periodID) {
                item.removePayPeriod(withID: periodID)
                payrollItems[itemIndex] = item
                auditTrail.recordChange(
                    action: .deleted,
                    entityType: "PayrollPayPeriod",
                    entityID: periodID,
                    details: "Deleted \(period.periodName) for \(item.personName)"
                )
                objectWillChange.send()
            }
        }
    }

    func updatePaymentStatus(itemID: UUID, periodID: UUID, status: PayrollPayPeriod.PaymentStatus) {
        if let itemIndex = payrollItems.firstIndex(where: { $0.id == itemID }) {
            var item = payrollItems[itemIndex]
            if let period = item.payPeriod(withID: periodID) {
                item.updatePaymentStatus(periodID: periodID, status: status)
                payrollItems[itemIndex] = item

                let statusDescription = status == .paid ? "marked as paid" : "updated status to \(status.rawValue)"
                auditTrail.recordChange(
                    action: .updated,
                    entityType: "PayrollPayPeriod",
                    entityID: periodID,
                    details: "\(period.periodName) for \(item.personName) \(statusDescription)"
                )
                objectWillChange.send()
            }
        }
    }

    // MARK: - Batch Operations

    func addPayPeriodToMultipleItems(itemIDs: [UUID], period: PayrollPayPeriod) {
        for itemID in itemIDs {
            addPayPeriod(to: itemID, period: period)
        }
    }

    func updatePaymentStatusForMultiplePeriods(updates: [(itemID: UUID, periodID: UUID, status: PayrollPayPeriod.PaymentStatus)]) {
        for update in updates {
            updatePaymentStatus(itemID: update.itemID, periodID: update.periodID, status: update.status)
        }
    }

    // MARK: - Query Methods

    func items(for contactType: PayrollLineItem.ContactType) -> [PayrollLineItem] {
        payrollItems.filter { $0.contactType == contactType }
    }

    func items(for department: String) -> [PayrollLineItem] {
        payrollItems.filter { $0.department == department }
    }

    func item(withID id: UUID) -> PayrollLineItem? {
        payrollItems.first { $0.id == id }
    }

    func items(matching searchText: String) -> [PayrollLineItem] {
        guard !searchText.isEmpty else { return payrollItems }
        return payrollItems.filter { $0.matches(searchText: searchText) }
    }

    func items(withContactID contactID: UUID) -> [PayrollLineItem] {
        payrollItems.filter { $0.contactID == contactID }
    }

    func allDepartments() -> [String] {
        Array(Set(payrollItems.map { $0.department })).sorted()
    }

    // MARK: - Summary Calculations

    func calculateSummary() -> PayrollSummary {
        PayrollSummary.calculate(from: payrollItems)
    }

    func calculateSummary(for contactType: PayrollLineItem.ContactType) -> PayrollSummary {
        let filteredItems = items(for: contactType)
        return PayrollSummary.calculate(from: filteredItems)
    }

    func calculateSummary(for department: String) -> PayrollSummary {
        let filteredItems = items(for: department)
        return PayrollSummary.calculate(from: filteredItems)
    }

    // MARK: - Pay Period Queries

    func allPayPeriods() -> [PayrollPayPeriod] {
        payrollItems.flatMap { $0.payPeriods }
    }

    func payPeriods(withStatus status: PayrollPayPeriod.PaymentStatus) -> [PayrollPayPeriod] {
        payrollItems.flatMap { $0.payPeriods(withStatus: status) }
    }

    func payPeriods(in dateRange: ClosedRange<Date>) -> [PayrollPayPeriod] {
        payrollItems.flatMap { $0.payPeriods(in: dateRange) }
    }

    func upcomingPayments(within days: Int = 7) -> [(item: PayrollLineItem, period: PayrollPayPeriod)] {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        var upcoming: [(PayrollLineItem, PayrollPayPeriod)] = []

        for item in payrollItems {
            for period in item.payPeriods where period.status != .paid {
                if let paymentDate = period.paymentDate, paymentDate <= futureDate {
                    upcoming.append((item, period))
                }
            }
        }

        return upcoming.sorted { (a: (item: PayrollLineItem, period: PayrollPayPeriod), b: (item: PayrollLineItem, period: PayrollPayPeriod)) in
            (a.1.paymentDate ?? Date.distantFuture) < (b.1.paymentDate ?? Date.distantFuture)
        }
    }

    func overduePayments() -> [(item: PayrollLineItem, period: PayrollPayPeriod)] {
        var overdue: [(PayrollLineItem, PayrollPayPeriod)] = []

        for item in payrollItems {
            for period in item.payPeriods where period.isPastDue() {
                overdue.append((item, period))
            }
        }

        return overdue.sorted { (a: (item: PayrollLineItem, period: PayrollPayPeriod), b: (item: PayrollLineItem, period: PayrollPayPeriod)) in
            (a.1.paymentDate ?? Date.distantPast) < (b.1.paymentDate ?? Date.distantPast)
        }
    }

    // MARK: - Persistence

    func loadFromVersion(_ version: BudgetVersion) {
        payrollItems = version.payrollItems
        objectWillChange.send()
    }

    func saveToVersion(_ version: inout BudgetVersion) {
        version.payrollItems = payrollItems
    }

    func clearAll() {
        payrollItems.removeAll()
        auditTrail.recordChange(
            action: .deleted,
            entityType: "PayrollLineItem",
            entityID: UUID(),
            details: "Cleared all payroll items"
        )
        objectWillChange.send()
    }

    // MARK: - Validation

    func validatePayrollItem(_ item: PayrollLineItem) -> Result<Void, PayrollValidationError> {
        // Check for empty name
        guard !item.personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyPersonName)
        }

        // Check for empty role
        guard !item.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyRole)
        }

        // Check for valid budgeted amount
        guard item.totalBudgetedAmount >= 0 else {
            return .failure(.negativeBudgetedAmount)
        }

        // Check for duplicate names (optional - you may want to allow duplicates)
        let duplicateExists = payrollItems.contains { existing in
            existing.id != item.id &&
            existing.personName.lowercased() == item.personName.lowercased() &&
            existing.role.lowercased() == item.role.lowercased()
        }

        if duplicateExists {
            return .failure(.duplicateEntry)
        }

        return .success(())
    }

    func validatePayPeriod(_ period: PayrollPayPeriod) -> Result<Void, PayrollValidationError> {
        // Check for empty period name
        guard !period.periodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyPeriodName)
        }

        // Check date range validity
        guard period.startDate <= period.endDate else {
            return .failure(.invalidDateRange)
        }

        // Check for negative amounts
        guard period.grossAmount >= 0 else {
            return .failure(.negativeGrossAmount)
        }

        guard period.deductions >= 0 else {
            return .failure(.negativeDeductions)
        }

        guard period.netAmount >= 0 else {
            return .failure(.negativeNetAmount)
        }

        return .success(())
    }

    // MARK: - Sorting

    func sortedItems(by sortOption: PayrollSortOption) -> [PayrollLineItem] {
        switch sortOption {
        case .nameAscending:
            return payrollItems.sorted { $0.personName < $1.personName }
        case .nameDescending:
            return payrollItems.sorted { $0.personName > $1.personName }
        case .totalBudgetedAscending:
            return payrollItems.sorted { $0.totalBudgetedAmount < $1.totalBudgetedAmount }
        case .totalBudgetedDescending:
            return payrollItems.sorted { $0.totalBudgetedAmount > $1.totalBudgetedAmount }
        case .totalPaidAscending:
            return payrollItems.sorted { $0.totalPaid < $1.totalPaid }
        case .totalPaidDescending:
            return payrollItems.sorted { $0.totalPaid > $1.totalPaid }
        case .remainingBalanceAscending:
            return payrollItems.sorted { $0.remainingBalance < $1.remainingBalance }
        case .remainingBalanceDescending:
            return payrollItems.sorted { $0.remainingBalance > $1.remainingBalance }
        case .departmentAscending:
            return payrollItems.sorted { $0.department < $1.department }
        case .roleAscending:
            return payrollItems.sorted { $0.role < $1.role }
        }
    }
}

// MARK: - Payroll Sort Option

enum PayrollSortOption: String, CaseIterable, Identifiable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case totalBudgetedAscending = "Budget (Low to High)"
    case totalBudgetedDescending = "Budget (High to Low)"
    case totalPaidAscending = "Paid (Low to High)"
    case totalPaidDescending = "Paid (High to Low)"
    case remainingBalanceAscending = "Remaining (Low to High)"
    case remainingBalanceDescending = "Remaining (High to Low)"
    case departmentAscending = "Department"
    case roleAscending = "Role"

    var id: String { rawValue }
}

// MARK: - Payroll Validation Error

enum PayrollValidationError: LocalizedError {
    case emptyPersonName
    case emptyRole
    case emptyPeriodName
    case negativeBudgetedAmount
    case negativeGrossAmount
    case negativeDeductions
    case negativeNetAmount
    case invalidDateRange
    case duplicateEntry

    var errorDescription: String? {
        switch self {
        case .emptyPersonName:
            return "Person name cannot be empty"
        case .emptyRole:
            return "Role cannot be empty"
        case .emptyPeriodName:
            return "Pay period name cannot be empty"
        case .negativeBudgetedAmount:
            return "Budgeted amount cannot be negative"
        case .negativeGrossAmount:
            return "Gross amount cannot be negative"
        case .negativeDeductions:
            return "Deductions cannot be negative"
        case .negativeNetAmount:
            return "Net amount cannot be negative"
        case .invalidDateRange:
            return "Start date must be before or equal to end date"
        case .duplicateEntry:
            return "A payroll entry with this name and role already exists"
        }
    }
}
