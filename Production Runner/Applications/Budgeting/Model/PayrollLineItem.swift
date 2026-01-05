import Foundation
import SwiftUI

// MARK: - Payroll Line Item

struct PayrollLineItem: Identifiable, Codable, Hashable {
    let id: UUID
    var personName: String
    var contactID: UUID?
    var role: String
    var department: String
    var contactType: ContactType
    var totalBudgetedAmount: Double
    var ratePerPeriod: Double
    var payPeriods: [PayrollPayPeriod]
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        personName: String,
        contactID: UUID? = nil,
        role: String,
        department: String,
        contactType: ContactType,
        totalBudgetedAmount: Double,
        ratePerPeriod: Double = 0,
        payPeriods: [PayrollPayPeriod] = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.personName = personName
        self.contactID = contactID
        self.role = role
        self.department = department
        self.contactType = contactType
        self.totalBudgetedAmount = totalBudgetedAmount
        self.ratePerPeriod = ratePerPeriod
        self.payPeriods = payPeriods
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Contact Type

    enum ContactType: String, Codable, CaseIterable, Identifiable {
        case cast = "Cast"
        case crew = "Crew"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .cast: return "person.2.fill"
            case .crew: return "person.3.fill"
            }
        }

        var color: Color {
            switch self {
            case .cast: return .purple
            case .crew: return .blue
            }
        }
    }

    // MARK: - Computed Properties

    var totalPaid: Double {
        payPeriods
            .filter { $0.status == .paid }
            .reduce(0) { $0 + $1.netAmount }
    }

    var totalPending: Double {
        payPeriods
            .filter { $0.status == .pending }
            .reduce(0) { $0 + $1.netAmount }
    }

    var totalApproved: Double {
        payPeriods
            .filter { $0.status == .approved }
            .reduce(0) { $0 + $1.netAmount }
    }

    var remainingBalance: Double {
        totalBudgetedAmount - totalPaid
    }

    var percentagePaid: Double {
        guard totalBudgetedAmount > 0 else { return 0 }
        return (totalPaid / totalBudgetedAmount) * 100
    }

    var totalGrossAmount: Double {
        payPeriods.reduce(0) { $0 + $1.grossAmount }
    }

    var totalDeductions: Double {
        payPeriods.reduce(0) { $0 + $1.deductions }
    }

    var totalNetAmount: Double {
        payPeriods.reduce(0) { $0 + $1.netAmount }
    }

    var numberOfPayPeriods: Int {
        payPeriods.count
    }

    var nextPaymentDue: PayrollPayPeriod? {
        payPeriods
            .filter { $0.status != .paid }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    var latestPayment: PayrollPayPeriod? {
        payPeriods
            .filter { $0.status == .paid }
            .sorted { ($0.paymentDate ?? Date.distantPast) > ($1.paymentDate ?? Date.distantPast) }
            .first
    }

    // MARK: - Helper Methods

    func payPeriod(withID id: UUID) -> PayrollPayPeriod? {
        payPeriods.first { $0.id == id }
    }

    func payPeriods(withStatus status: PayrollPayPeriod.PaymentStatus) -> [PayrollPayPeriod] {
        payPeriods.filter { $0.status == status }
    }

    func payPeriods(in dateRange: ClosedRange<Date>) -> [PayrollPayPeriod] {
        payPeriods.filter { period in
            dateRange.contains(period.startDate) || dateRange.contains(period.endDate)
        }
    }

    mutating func addPayPeriod(_ period: PayrollPayPeriod) {
        payPeriods.append(period)
        updatedAt = Date()
    }

    mutating func updatePayPeriod(_ period: PayrollPayPeriod) {
        if let index = payPeriods.firstIndex(where: { $0.id == period.id }) {
            payPeriods[index] = period
            updatedAt = Date()
        }
    }

    mutating func removePayPeriod(withID id: UUID) {
        payPeriods.removeAll { $0.id == id }
        updatedAt = Date()
    }

    mutating func updatePaymentStatus(periodID: UUID, status: PayrollPayPeriod.PaymentStatus) {
        if let index = payPeriods.firstIndex(where: { $0.id == periodID }) {
            payPeriods[index].status = status
            if status == .paid && payPeriods[index].paymentDate == nil {
                payPeriods[index].paymentDate = Date()
            }
            updatedAt = Date()
        }
    }

    // MARK: - Search & Filter Helpers

    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        let lowercased = searchText.lowercased()
        return personName.lowercased().contains(lowercased) ||
               role.lowercased().contains(lowercased) ||
               department.lowercased().contains(lowercased) ||
               notes.lowercased().contains(lowercased)
    }
}

// MARK: - Hashable Conformance

extension PayrollLineItem {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PayrollLineItem, rhs: PayrollLineItem) -> Bool {
        lhs.id == rhs.id
    }
}
