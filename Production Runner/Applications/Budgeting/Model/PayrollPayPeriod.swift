import Foundation
import SwiftUI

// MARK: - Payroll Pay Period

struct PayrollPayPeriod: Identifiable, Codable, Hashable {
    let id: UUID
    var periodName: String
    var startDate: Date
    var endDate: Date
    var grossAmount: Double
    var deductions: Double
    var netAmount: Double
    var status: PaymentStatus
    var paymentDate: Date?
    var paymentMethod: PaymentMethod?
    var notes: String

    init(
        id: UUID = UUID(),
        periodName: String,
        startDate: Date,
        endDate: Date,
        grossAmount: Double,
        deductions: Double = 0,
        netAmount: Double? = nil,
        status: PaymentStatus = .pending,
        paymentDate: Date? = nil,
        paymentMethod: PaymentMethod? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.periodName = periodName
        self.startDate = startDate
        self.endDate = endDate
        self.grossAmount = grossAmount
        self.deductions = deductions
        self.netAmount = netAmount ?? (grossAmount - deductions)
        self.status = status
        self.paymentDate = paymentDate
        self.paymentMethod = paymentMethod
        self.notes = notes
    }

    // MARK: - Payment Status

    enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
        case pending = "Pending"
        case approved = "Approved"
        case paid = "Paid"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .pending: return .orange
            case .approved: return .blue
            case .paid: return .green
            }
        }

        var icon: String {
            switch self {
            case .pending: return "clock"
            case .approved: return "checkmark.circle"
            case .paid: return "checkmark.circle.fill"
            }
        }
    }

    // MARK: - Payment Method

    enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
        case check = "Check"
        case directDeposit = "Direct Deposit"
        case cash = "Cash"
        case other = "Other"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .check: return "doc.text"
            case .directDeposit: return "building.columns"
            case .cash: return "dollarsign"
            case .other: return "ellipsis.circle"
            }
        }
    }

    // MARK: - Computed Properties

    var formattedPeriod: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var daysInPeriod: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    // MARK: - Helper Methods

    mutating func updateNetAmount() {
        netAmount = grossAmount - deductions
    }

    func isPastDue() -> Bool {
        guard let payDate = paymentDate else { return false }
        return payDate < Date() && status != .paid
    }
}
