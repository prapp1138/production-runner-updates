import Foundation

// MARK: - Payroll Summary

struct PayrollSummary: Codable, Hashable {
    var totalBudgeted: Double = 0
    var totalPaid: Double = 0
    var totalPending: Double = 0
    var totalApproved: Double = 0
    var castTotal: Double = 0
    var crewTotal: Double = 0

    init(
        totalBudgeted: Double = 0,
        totalPaid: Double = 0,
        totalPending: Double = 0,
        totalApproved: Double = 0,
        castTotal: Double = 0,
        crewTotal: Double = 0
    ) {
        self.totalBudgeted = totalBudgeted
        self.totalPaid = totalPaid
        self.totalPending = totalPending
        self.totalApproved = totalApproved
        self.castTotal = castTotal
        self.crewTotal = crewTotal
    }

    // MARK: - Computed Properties

    var remainingBalance: Double {
        totalBudgeted - totalPaid
    }

    var percentagePaid: Double {
        guard totalBudgeted > 0 else { return 0 }
        return (totalPaid / totalBudgeted) * 100
    }

    var percentagePending: Double {
        guard totalBudgeted > 0 else { return 0 }
        return (totalPending / totalBudgeted) * 100
    }

    var percentageApproved: Double {
        guard totalBudgeted > 0 else { return 0 }
        return (totalApproved / totalBudgeted) * 100
    }

    var percentageCast: Double {
        guard totalBudgeted > 0 else { return 0 }
        return (castTotal / totalBudgeted) * 100
    }

    var percentageCrew: Double {
        guard totalBudgeted > 0 else { return 0 }
        return (crewTotal / totalBudgeted) * 100
    }

    var totalGross: Double {
        totalPaid + totalPending + totalApproved
    }

    // MARK: - Helper Methods

    static func calculate(from items: [PayrollLineItem]) -> PayrollSummary {
        var summary = PayrollSummary()

        for item in items {
            summary.totalBudgeted += item.totalBudgetedAmount
            summary.totalPaid += item.totalPaid
            summary.totalPending += item.totalPending
            summary.totalApproved += item.totalApproved

            switch item.contactType {
            case .cast:
                summary.castTotal += item.totalBudgetedAmount
            case .crew:
                summary.crewTotal += item.totalBudgetedAmount
            }
        }

        return summary
    }

    func breakdown(by contactType: PayrollLineItem.ContactType) -> Double {
        switch contactType {
        case .cast: return castTotal
        case .crew: return crewTotal
        }
    }

    func breakdownPercentage(by contactType: PayrollLineItem.ContactType) -> Double {
        switch contactType {
        case .cast: return percentageCast
        case .crew: return percentageCrew
        }
    }

    // MARK: - Status Breakdown

    struct StatusBreakdown {
        let pending: Double
        let approved: Double
        let paid: Double
        let pendingCount: Int
        let approvedCount: Int
        let paidCount: Int
    }

    func statusBreakdown(from items: [PayrollLineItem]) -> StatusBreakdown {
        var pendingAmount = 0.0
        var approvedAmount = 0.0
        var paidAmount = 0.0
        var pendingCount = 0
        var approvedCount = 0
        var paidCount = 0

        for item in items {
            for period in item.payPeriods {
                switch period.status {
                case .pending:
                    pendingAmount += period.netAmount
                    pendingCount += 1
                case .approved:
                    approvedAmount += period.netAmount
                    approvedCount += 1
                case .paid:
                    paidAmount += period.netAmount
                    paidCount += 1
                }
            }
        }

        return StatusBreakdown(
            pending: pendingAmount,
            approved: approvedAmount,
            paid: paidAmount,
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            paidCount: paidCount
        )
    }

    // MARK: - Department Breakdown

    func departmentBreakdown(from items: [PayrollLineItem]) -> [String: Double] {
        var breakdown: [String: Double] = [:]

        for item in items {
            let currentAmount = breakdown[item.department] ?? 0
            breakdown[item.department] = currentAmount + item.totalBudgetedAmount
        }

        return breakdown
    }
}
