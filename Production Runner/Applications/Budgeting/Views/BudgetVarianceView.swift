import SwiftUI

/// Shows budget variance analysis - actual vs budgeted spending
struct BudgetVarianceView: View {
    @ObservedObject var viewModel: BudgetViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    overallSummary
                    categoryBreakdown
                    topVariances
                }
                .padding(20)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Variance Analysis")
                    .font(.system(size: 20, weight: .semibold))
                Text("Budget vs Actual Spending")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            // Export button
            Menu {
                Button("Export to CSV") {
                    // Export variance report
                }
                Button("Export to PDF") {
                    // Export PDF report
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .padding(20)
    }

    // MARK: - Overall Summary

    private var overallSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Overall Budget Status", icon: "chart.pie.fill")

            if let version = viewModel.selectedVersion {
                HStack(spacing: 20) {
                    // Budgeted
                    summaryCard(
                        title: "Budgeted",
                        value: version.totalBudget.asCurrency(),
                        color: .blue
                    )

                    // Spent
                    summaryCard(
                        title: "Spent",
                        value: version.totalSpent.asCurrency(),
                        color: .orange
                    )

                    // Remaining
                    summaryCard(
                        title: "Remaining",
                        value: version.remaining.asCurrency(),
                        color: version.remaining >= 0 ? .green : .red
                    )

                    // Percentage Used
                    progressCard(
                        title: "Used",
                        percentage: version.percentageUsed,
                        status: version.budgetStatus
                    )
                }

                // Status bar
                statusBar(for: version)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressCard(title: String, percentage: Double, status: BudgetVersion.BudgetStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(String(format: "%.1f%%", percentage))
                    .font(.system(size: 18, weight: .semibold))

                Text(status.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(statusColor(for: status).opacity(0.2))
                    )
                    .foregroundStyle(statusColor(for: status))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBar(for version: BudgetVersion) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(statusColor(for: version.budgetStatus))
                    .frame(width: min(geometry.size.width * CGFloat(version.percentageUsed / 100), geometry.size.width))
            }
        }
        .frame(height: 8)
        .padding(.top, 8)
    }

    private func statusColor(for status: BudgetVersion.BudgetStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .overBudget: return .red
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("By Category", icon: "folder.fill")

            let variances = viewModel.getCategoryVariances()

            ForEach(BudgetCategory.allCases) { category in
                if let variance = variances[category] {
                    categoryVarianceRow(category: category, variance: variance)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func categoryVarianceRow(category: BudgetCategory, variance: BudgetVariance) -> some View {
        VStack(spacing: 8) {
            HStack {
                Label(category.rawValue, systemImage: category.icon)
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(variance.formattedVariance)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(variance.isOverBudget ? .red : .green)

                    Text("\(String(format: "%.1f", variance.percentageUsed))% used")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(varianceColor(for: variance.status))
                        .frame(width: min(geometry.size.width * CGFloat(variance.percentageUsed / 100), geometry.size.width))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8)
    }

    private func varianceColor(for status: BudgetVariance.Status) -> Color {
        switch status {
        case .onTrack: return .green
        case .warning: return .yellow
        case .nearLimit: return .orange
        case .overBudget: return .red
        }
    }

    // MARK: - Top Variances

    private var topVariances: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Highest Variances", icon: "exclamationmark.triangle.fill")

            let itemVariances = viewModel.lineItems.map { item in
                (item: item, variance: viewModel.getVariance(for: item))
            }
            .sorted { abs($0.variance.variance) > abs($1.variance.variance) }
            .prefix(10)

            if itemVariances.isEmpty {
                Text("No variances to display. Add transactions to see variance analysis.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(itemVariances), id: \.item.id) { item, variance in
                    itemVarianceRow(item: item, variance: variance)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func itemVarianceRow(item: BudgetLineItem, variance: BudgetVariance) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("Budgeted: \(variance.budgeted.asCurrency())")
                    Text("Actual: \(variance.actual.asCurrency())")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(variance.formattedVariance)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(variance.isOverBudget ? .red : .green)

                Text(variance.status.rawValue)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(varianceColor(for: variance.status).opacity(0.2))
                    )
                    .foregroundStyle(varianceColor(for: variance.status))
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.blue)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            #if os(macOS)
            .fill(Color(nsColor: .controlBackgroundColor))
            #else
            .fill(Color(uiColor: .secondarySystemBackground))
            #endif
    }
}

// MARK: - Compact Variance Indicator

/// Small variance indicator shown in line item rows
struct VarianceIndicator: View {
    let variance: BudgetVariance

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            if variance.actual > 0 {
                Text(String(format: "%.0f%%", variance.percentageUsed))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var indicatorColor: Color {
        switch variance.status {
        case .onTrack: return .green
        case .warning: return .yellow
        case .nearLimit: return .orange
        case .overBudget: return .red
        }
    }
}

// MARK: - Preview

struct BudgetVarianceView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetVarianceView(
            viewModel: BudgetViewModel(context: PersistenceController.preview.container.viewContext)
        )
    }
}
