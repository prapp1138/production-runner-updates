import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct DayByDayBudgetView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: LiveModeStore

    @State private var showingAddExpense: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var dailyExpenses: [DailyExpense] = []

    // Fetch transactions
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BudgetTransactionEntity.date, ascending: false)],
        animation: .default
    )
    private var allTransactions: FetchedResults<BudgetTransactionEntity>

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Left: Daily summary
            dailySummaryPanel
                .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)

            // Right: Expense list
            expenseListPanel
                .frame(minWidth: 400)
        }
        #else
        NavigationSplitView {
            dailySummaryPanel
        } detail: {
            expenseListPanel
        }
        #endif
    }

    // MARK: - Daily Summary Panel

    @ViewBuilder
    private var dailySummaryPanel: some View {
        VStack(spacing: 0) {
            // Date selector
            VStack(spacing: 12) {
                HStack {
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        if let dayNumber = store.currentShootDay {
                            Text("Day \(dayNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(selectedDate, style: .date)
                            .font(.headline)
                    }

                    Spacer()

                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(Calendar.current.isDateInToday(selectedDate) || selectedDate > Date())
                }
                .padding(.horizontal, 8)

                // Today button
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button("Today") {
                        selectedDate = Date()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(16)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Daily total
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Daily Spend")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(dailyTotal, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(dailyTotal > 0 ? .primary : .secondary)
                }

                // Category breakdown
                if !categoryTotals.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(categoryTotals.sorted { $0.value > $1.value }, id: \.key) { category, amount in
                            HStack {
                                Text(category)
                                    .font(.subheadline)
                                Spacer()
                                Text(amount, format: .currency(code: "USD"))
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)

            Divider()

            // Quick expense categories
            ScrollView {
                VStack(spacing: 12) {
                    Text("Quick Add")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        QuickExpenseButton(category: "Meals", icon: "fork.knife", color: .orange) {
                            addQuickExpense(category: "Meals")
                        }
                        QuickExpenseButton(category: "Transport", icon: "car.fill", color: .blue) {
                            addQuickExpense(category: "Transport")
                        }
                        QuickExpenseButton(category: "Supplies", icon: "shippingbox.fill", color: .green) {
                            addQuickExpense(category: "Supplies")
                        }
                        QuickExpenseButton(category: "Rentals", icon: "video.fill", color: .purple) {
                            addQuickExpense(category: "Rentals")
                        }
                        QuickExpenseButton(category: "Petty Cash", icon: "dollarsign.circle.fill", color: .mint) {
                            addQuickExpense(category: "Petty Cash")
                        }
                        QuickExpenseButton(category: "Other", icon: "ellipsis.circle.fill", color: .gray) {
                            addQuickExpense(category: "Other")
                        }
                    }
                }
                .padding(16)
            }

            Spacer(minLength: 0)

            Divider()

            // Add expense button
            Button {
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(16)
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseSheet(
                isPresented: $showingAddExpense,
                date: selectedDate
            ) { expense in
                saveExpense(expense)
            }
        }
    }

    // MARK: - Expense List Panel

    @ViewBuilder
    private var expenseListPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Expenses")
                    .font(.headline)

                Spacer()

                Text("\(todaysTransactions.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Expense list
            if todaysTransactions.isEmpty {
                EmptyStateView(
                    "No Expenses",
                    systemImage: "dollarsign.circle",
                    description: "Add expenses for today"
                )
            } else {
                List {
                    ForEach(todaysTransactions, id: \.id) { transaction in
                        ExpenseRow(transaction: transaction)
                    }
                    .onDelete(perform: deleteExpenses)
                }
                .listStyle(.plain)
            }

            Divider()

            // Running totals footer
            runningTotalsFooter
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    // MARK: - Running Totals Footer

    @ViewBuilder
    private var runningTotalsFooter: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Week Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(weekTotal, format: .currency(code: "USD"))
                    .font(.system(size: 16, weight: .semibold))
            }

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Production Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(productionTotal, format: .currency(code: "USD"))
                    .font(.system(size: 16, weight: .semibold))
            }

            Spacer()
        }
        .padding(16)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

    // MARK: - Computed Properties

    private var todaysTransactions: [BudgetTransactionEntity] {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        return allTransactions.filter { transaction in
            guard let date = transaction.date else { return false }
            return date >= startOfDay && date < endOfDay
        }
    }

    private var dailyTotal: Double {
        todaysTransactions.reduce(0) { $0 + $1.amount }
    }

    private var categoryTotals: [String: Double] {
        var totals: [String: Double] = [:]
        for transaction in todaysTransactions {
            let category = transaction.category ?? "Other"
            totals[category, default: 0] += transaction.amount
        }
        return totals
    }

    private var weekTotal: Double {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        return allTransactions
            .filter { transaction in
                guard let date = transaction.date else { return false }
                return date >= weekStart && date < weekEnd
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var productionTotal: Double {
        allTransactions.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Actions

    private func addQuickExpense(category: String) {
        showingAddExpense = true
        // Pre-select category in sheet
    }

    private func saveExpense(_ expense: DailyExpense) {
        let entity = BudgetTransactionEntity(context: context)
        entity.id = UUID()
        entity.date = expense.date
        entity.amount = expense.amount
        entity.category = expense.category
        entity.descriptionText = expense.description
        entity.payee = expense.payee
        entity.transactionType = "Expense"
        entity.createdAt = Date()
        entity.updatedAt = Date()

        do {
            try context.save()
        } catch {
            print("Error saving expense: \(error)")
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            let transaction = todaysTransactions[index]
            context.delete(transaction)
        }

        do {
            try context.save()
        } catch {
            print("Error deleting expenses: \(error)")
        }
    }
}

// MARK: - Quick Expense Button

struct QuickExpenseButton: View {
    let category: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Text(category)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let transaction: BudgetTransactionEntity

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: categoryIcon)
                        .foregroundStyle(categoryColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText ?? transaction.category ?? "Expense")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    if let category = transaction.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let payee = transaction.payee, !payee.isEmpty {
                        Text("• \(payee)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(transaction.amount, format: .currency(code: "USD"))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch transaction.category?.lowercased() {
        case "meals": return .orange
        case "transport": return .blue
        case "supplies": return .green
        case "rentals": return .purple
        case "petty cash": return .mint
        default: return .gray
        }
    }

    private var categoryIcon: String {
        switch transaction.category?.lowercased() {
        case "meals": return "fork.knife"
        case "transport": return "car.fill"
        case "supplies": return "shippingbox.fill"
        case "rentals": return "video.fill"
        case "petty cash": return "dollarsign.circle.fill"
        default: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Daily Expense Model

struct DailyExpense: Identifiable {
    let id: UUID = UUID()
    var date: Date
    var amount: Double
    var category: String
    var description: String
    var payee: String?
    var receiptData: Data?
}

// MARK: - Add Expense Sheet

struct AddExpenseSheet: View {
    @Binding var isPresented: Bool
    let date: Date
    let onSave: (DailyExpense) -> Void

    @State private var amount: String = ""
    @State private var category: String = "Other"
    @State private var description: String = ""
    @State private var payee: String = ""

    private let categories = ["Meals", "Transport", "Supplies", "Rentals", "Petty Cash", "Labor", "Equipment", "Location", "Other"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Expense")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                // Amount
                HStack {
                    Text("$")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $amount)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .textFieldStyle(.plain)
                }
                .padding(.vertical, 8)

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }

                TextField("Description", text: $description)

                TextField("Payee/Vendor (optional)", text: $payee)
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: "")) else { return }

                    let expense = DailyExpense(
                        date: date,
                        amount: amountValue,
                        category: category,
                        description: description.isEmpty ? category : description,
                        payee: payee.isEmpty ? nil : payee
                    )
                    onSave(expense)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount.isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 400)
    }
}

#Preview {
    DayByDayBudgetView()
        .environmentObject(LiveModeStore())
}
