import SwiftUI

// MARK: - Payroll Full View

struct PayrollFullView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingAddPayrollItem = false
    @State private var showingEditPayrollItem = false
    @State private var showingAddPayPeriod = false
    @State private var showingEditPayPeriod = false
    @State private var selectedPayrollItem: PayrollLineItem?
    @State private var selectedPayPeriod: PayrollPayPeriod?
    @State private var expandedItemIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            payrollHeader

            Divider()

            // Split view: Summary (30%) and List (70%)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left: Payroll Summary
                    PayrollSummaryPane(
                        viewModel: viewModel,
                        selectedContactType: $viewModel.selectedPayrollContactType
                    )
                    .frame(width: geometry.size.width * 0.3)

                    Divider()

                    // Right: Payroll Details List
                    PayrollListPane(
                        viewModel: viewModel,
                        expandedItemIDs: $expandedItemIDs,
                        onAddPayPeriod: { item in
                            selectedPayrollItem = item
                            showingAddPayPeriod = true
                        },
                        onEditPayrollItem: { item in
                            selectedPayrollItem = item
                            showingEditPayrollItem = true
                        },
                        onEditPayPeriod: { item, period in
                            selectedPayrollItem = item
                            selectedPayPeriod = period
                            showingEditPayPeriod = true
                        },
                        onDeletePayrollItem: { item in
                            viewModel.deletePayrollItem(item)
                        },
                        onDeletePayPeriod: { itemID, periodID in
                            viewModel.deletePayPeriod(itemID: itemID, periodID: periodID)
                        },
                        onUpdatePaymentStatus: { itemID, periodID, status in
                            viewModel.updatePaymentStatus(itemID: itemID, periodID: periodID, status: status)
                        }
                    )
                    .frame(width: geometry.size.width * 0.7)
                }
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingAddPayrollItem) {
            AddPayrollItemSheet(viewModel: viewModel, isPresented: $showingAddPayrollItem)
        }
        .sheet(isPresented: $showingEditPayrollItem) {
            if let item = selectedPayrollItem {
                EditPayrollItemSheet(viewModel: viewModel, item: item, isPresented: $showingEditPayrollItem)
            }
        }
        .sheet(isPresented: $showingAddPayPeriod) {
            if let item = selectedPayrollItem {
                AddPayPeriodSheet(
                    viewModel: viewModel,
                    payrollItem: item,
                    isPresented: $showingAddPayPeriod
                )
            }
        }
        .sheet(isPresented: $showingEditPayPeriod) {
            if let item = selectedPayrollItem, let period = selectedPayPeriod {
                EditPayPeriodSheet(
                    viewModel: viewModel,
                    payrollItem: item,
                    period: period,
                    isPresented: $showingEditPayPeriod
                )
            }
        }
    }

    private var payrollHeader: some View {
        HStack {
            Text("Payroll")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                showingAddPayrollItem = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Cast/Crew")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.blue.gradient)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 60)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Payroll Summary Pane

struct PayrollSummaryPane: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var selectedContactType: PayrollLineItem.ContactType?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Payroll Summary")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Summary Cards
                VStack(spacing: 12) {
                    SummaryCard(
                        title: "Total Budgeted",
                        amount: viewModel.payrollSummary.totalBudgeted,
                        icon: "dollarsign.circle.fill",
                        color: .blue
                    )

                    SummaryCard(
                        title: "Total Paid",
                        amount: viewModel.payrollSummary.totalPaid,
                        icon: "checkmark.circle.fill",
                        color: .green,
                        subtitle: "\(Int(viewModel.payrollSummary.percentagePaid))% of budget"
                    )

                    SummaryCard(
                        title: "Remaining",
                        amount: viewModel.payrollSummary.remainingBalance,
                        icon: "clock.circle.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal, 16)

                Divider()
                    .padding(.vertical, 8)

                // Category Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("By Category")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    CategoryRow(
                        title: "Cast Payroll",
                        amount: viewModel.payrollSummary.castTotal,
                        itemCount: viewModel.payrollItems(for: .cast).count,
                        icon: "person.2.fill",
                        color: .purple,
                        isSelected: selectedContactType == .cast
                    ) {
                        selectedContactType = selectedContactType == .cast ? nil : .cast
                    }

                    CategoryRow(
                        title: "Crew Payroll",
                        amount: viewModel.payrollSummary.crewTotal,
                        itemCount: viewModel.payrollItems(for: .crew).count,
                        icon: "person.3.fill",
                        color: .blue,
                        isSelected: selectedContactType == .crew
                    ) {
                        selectedContactType = selectedContactType == .crew ? nil : .crew
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                // Status Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Payment Status")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    StatusCard(
                        title: "Pending",
                        amount: viewModel.payrollSummary.totalPending,
                        color: .orange,
                        icon: "clock"
                    )

                    StatusCard(
                        title: "Approved",
                        amount: viewModel.payrollSummary.totalApproved,
                        color: .blue,
                        icon: "checkmark.circle"
                    )

                    StatusCard(
                        title: "Paid",
                        amount: viewModel.payrollSummary.totalPaid,
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(amount.asCurrency())
                .font(.title3)
                .fontWeight(.bold)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let title: String
    let amount: Double
    let itemCount: Int
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(itemCount) \(itemCount == 1 ? "person" : "people")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(amount.asCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? color.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Card

private struct StatusCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(amount.asCurrency())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Payroll List Pane

struct PayrollListPane: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var expandedItemIDs: Set<UUID>
    let onAddPayPeriod: (PayrollLineItem) -> Void
    let onEditPayrollItem: (PayrollLineItem) -> Void
    let onEditPayPeriod: (PayrollLineItem, PayrollPayPeriod) -> Void
    let onDeletePayrollItem: (PayrollLineItem) -> Void
    let onDeletePayPeriod: (UUID, UUID) -> Void
    let onUpdatePaymentStatus: (UUID, UUID, PayrollPayPeriod.PaymentStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Filter/sort controls
            controlsBar

            Divider()

            // Payroll items list
            if viewModel.filteredPayrollItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredPayrollItems) { item in
                            PayrollPersonRow(
                                item: item,
                                isExpanded: expandedItemIDs.contains(item.id),
                                onToggleExpand: {
                                    if expandedItemIDs.contains(item.id) {
                                        expandedItemIDs.remove(item.id)
                                    } else {
                                        expandedItemIDs.insert(item.id)
                                    }
                                },
                                onAddPayPeriod: { onAddPayPeriod(item) },
                                onEdit: { onEditPayrollItem(item) },
                                onDelete: { onDeletePayrollItem(item) },
                                onEditPayPeriod: { period in
                                    onEditPayPeriod(item, period)
                                },
                                onDeletePayPeriod: { periodID in
                                    onDeletePayPeriod(item.id, periodID)
                                },
                                onUpdatePaymentStatus: { periodID, status in
                                    onUpdatePaymentStatus(item.id, periodID, status)
                                }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search payroll...", text: $viewModel.payrollSearchText)
                    .textFieldStyle(.plain)
                if !viewModel.payrollSearchText.isEmpty {
                    Button {
                        viewModel.payrollSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.tertiarySystemBackground))
            )

            // Sort
            Menu {
                ForEach(PayrollSortOption.allCases) { option in
                    Button {
                        viewModel.payrollSortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if viewModel.payrollSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
            .menuStyle(.borderlessButton)

            Spacer()

            Text("\(viewModel.filteredPayrollItems.count) \(viewModel.filteredPayrollItems.count == 1 ? "person" : "people")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Payroll Entries")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Add cast and crew members to track their compensation and payment schedules")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Payroll Person Row

private struct PayrollPersonRow: View {
    let item: PayrollLineItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onAddPayPeriod: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onEditPayPeriod: (PayrollPayPeriod) -> Void
    let onDeletePayPeriod: (UUID) -> Void
    let onUpdatePaymentStatus: (UUID, PayrollPayPeriod.PaymentStatus) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    // Expand chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    // Contact type icon
                    Image(systemName: item.contactType.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(item.contactType.color)
                        .frame(width: 28)

                    // Person info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.personName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 6) {
                            Text(item.role)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !item.department.isEmpty {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.department)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Payment progress
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(item.totalBudgetedAmount.asCurrency())
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack(spacing: 4) {
                            Text("Paid:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(item.totalPaid.asCurrency())
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }

                    // Progress bar
                    VStack(spacing: 4) {
                        Text("\(Int(item.percentagePaid))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.green)
                                    .frame(width: 60 * (item.percentagePaid / 100), height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                    .frame(width: 60)

                    // Actions menu
                    Menu {
                        Button {
                            onAddPayPeriod()
                        } label: {
                            Label("Add Pay Period", systemImage: "plus.circle")
                        }

                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content - Pay periods
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()

                    if item.payPeriods.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text("No pay periods")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Add Pay Period") {
                                    onAddPayPeriod()
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                        .background(Color(.secondarySystemBackground))
                    } else {
                        ForEach(item.payPeriods) { period in
                            PayPeriodRow(
                                period: period,
                                onEdit: { onEditPayPeriod(period) },
                                onDelete: { onDeletePayPeriod(period.id) },
                                onUpdateStatus: { status in
                                    onUpdatePaymentStatus(period.id, status)
                                }
                            )
                            if period.id != item.payPeriods.last?.id {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pay Period Row

private struct PayPeriodRow: View {
    let period: PayrollPayPeriod
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onUpdateStatus: (PayrollPayPeriod.PaymentStatus) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Indent
            Spacer()
                .frame(width: 48)

            // Status indicator
            Image(systemName: period.status.icon)
                .font(.system(size: 14))
                .foregroundStyle(period.status.color)
                .frame(width: 24)

            // Period info
            VStack(alignment: .leading, spacing: 4) {
                Text(period.periodName)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(period.formattedPeriod)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amounts
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Gross:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(period.grossAmount.asCurrency())
                        .font(.caption)
                }

                if period.deductions > 0 {
                    HStack(spacing: 4) {
                        Text("Deductions:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("-\(period.deductions.asCurrency())")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 4) {
                    Text("Net:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(period.netAmount.asCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(period.status.color)
                }
            }

            // Status menu
            Menu {
                ForEach(PayrollPayPeriod.PaymentStatus.allCases) { status in
                    Button {
                        onUpdateStatus(status)
                    } label: {
                        HStack {
                            Label(status.rawValue, systemImage: status.icon)
                            if period.status == status {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Add Payroll Item Sheet

struct AddPayrollItemSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool

    @State private var personName: String = ""
    @State private var role: String = ""
    @State private var department: String = ""
    @State private var contactType: PayrollLineItem.ContactType = .cast
    @State private var totalBudgetedAmount: String = ""
    @State private var ratePerPeriod: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Person Information") {
                    TextField("Name", text: $personName)
                    TextField("Role", text: $role)
                    TextField("Department", text: $department)

                    Picker("Type", selection: $contactType) {
                        ForEach(PayrollLineItem.ContactType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                }

                Section("Compensation") {
                    TextField("Total Budgeted Amount", text: $totalBudgetedAmount)
                    TextField("Rate Per Period (optional)", text: $ratePerPeriod)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Cast/Crew")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        savePayrollItem()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(totalBudgetedAmount) != nil
    }

    private func savePayrollItem() {
        guard let budgetedAmount = Double(totalBudgetedAmount) else { return }
        let rate = Double(ratePerPeriod) ?? 0

        let item = PayrollLineItem(
            personName: personName,
            role: role,
            department: department,
            contactType: contactType,
            totalBudgetedAmount: budgetedAmount,
            ratePerPeriod: rate,
            notes: notes
        )

        viewModel.addPayrollItem(item)
        isPresented = false
    }
}

// MARK: - Edit Payroll Item Sheet

struct EditPayrollItemSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let item: PayrollLineItem
    @Binding var isPresented: Bool

    @State private var personName: String
    @State private var role: String
    @State private var department: String
    @State private var contactType: PayrollLineItem.ContactType
    @State private var totalBudgetedAmount: String
    @State private var ratePerPeriod: String
    @State private var notes: String

    init(viewModel: BudgetViewModel, item: PayrollLineItem, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self.item = item
        self._isPresented = isPresented

        _personName = State(initialValue: item.personName)
        _role = State(initialValue: item.role)
        _department = State(initialValue: item.department)
        _contactType = State(initialValue: item.contactType)
        _totalBudgetedAmount = State(initialValue: String(item.totalBudgetedAmount))
        _ratePerPeriod = State(initialValue: String(item.ratePerPeriod))
        _notes = State(initialValue: item.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Person Information") {
                    TextField("Name", text: $personName)
                    TextField("Role", text: $role)
                    TextField("Department", text: $department)

                    Picker("Type", selection: $contactType) {
                        ForEach(PayrollLineItem.ContactType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                }

                Section("Compensation") {
                    TextField("Total Budgeted Amount", text: $totalBudgetedAmount)
                    TextField("Rate Per Period (optional)", text: $ratePerPeriod)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Edit \(item.personName)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(totalBudgetedAmount) != nil
    }

    private func saveChanges() {
        guard let budgetedAmount = Double(totalBudgetedAmount) else { return }
        let rate = Double(ratePerPeriod) ?? 0

        var updatedItem = item
        updatedItem.personName = personName
        updatedItem.role = role
        updatedItem.department = department
        updatedItem.contactType = contactType
        updatedItem.totalBudgetedAmount = budgetedAmount
        updatedItem.ratePerPeriod = rate
        updatedItem.notes = notes

        viewModel.updatePayrollItem(updatedItem)
        isPresented = false
    }
}

// MARK: - Add Pay Period Sheet

struct AddPayPeriodSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let payrollItem: PayrollLineItem
    @Binding var isPresented: Bool

    @State private var periodName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var grossAmount: String = ""
    @State private var deductions: String = "0"
    @State private var status: PayrollPayPeriod.PaymentStatus = .pending
    @State private var paymentDate: Date = Date()
    @State private var hasPaymentDate: Bool = false
    @State private var paymentMethod: PayrollPayPeriod.PaymentMethod = .directDeposit
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Period Information") {
                    TextField("Period Name (e.g., Week 1)", text: $periodName)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                Section("Payment Details") {
                    TextField("Gross Amount", text: $grossAmount)
                    TextField("Deductions", text: $deductions)

                    HStack {
                        Text("Net Amount")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(netAmount.asCurrency())
                            .fontWeight(.semibold)
                    }
                }

                Section("Payment Status") {
                    Picker("Status", selection: $status) {
                        ForEach(PayrollPayPeriod.PaymentStatus.allCases) { s in
                            HStack {
                                Image(systemName: s.icon)
                                Text(s.rawValue)
                            }
                            .tag(s)
                        }
                    }

                    Toggle("Set Payment Date", isOn: $hasPaymentDate)
                    if hasPaymentDate {
                        DatePicker("Payment Date", selection: $paymentDate, displayedComponents: .date)
                    }

                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(PayrollPayPeriod.PaymentMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Pay Period")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        savePeriod()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !periodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(grossAmount) != nil &&
        Double(deductions) != nil &&
        startDate <= endDate
    }

    private var netAmount: Double {
        let gross = Double(grossAmount) ?? 0
        let deduct = Double(deductions) ?? 0
        return max(0, gross - deduct)
    }

    private func savePeriod() {
        guard let gross = Double(grossAmount),
              let deduct = Double(deductions) else { return }

        let period = PayrollPayPeriod(
            periodName: periodName,
            startDate: startDate,
            endDate: endDate,
            grossAmount: gross,
            deductions: deduct,
            status: status,
            paymentDate: hasPaymentDate ? paymentDate : nil,
            paymentMethod: paymentMethod,
            notes: notes
        )

        viewModel.addPayPeriod(to: payrollItem.id, period: period)
        isPresented = false
    }
}

// MARK: - Edit Pay Period Sheet

struct EditPayPeriodSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let payrollItem: PayrollLineItem
    let period: PayrollPayPeriod
    @Binding var isPresented: Bool

    @State private var periodName: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var grossAmount: String
    @State private var deductions: String
    @State private var status: PayrollPayPeriod.PaymentStatus
    @State private var paymentDate: Date
    @State private var hasPaymentDate: Bool
    @State private var paymentMethod: PayrollPayPeriod.PaymentMethod
    @State private var notes: String

    init(viewModel: BudgetViewModel, payrollItem: PayrollLineItem, period: PayrollPayPeriod, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self.payrollItem = payrollItem
        self.period = period
        self._isPresented = isPresented

        _periodName = State(initialValue: period.periodName)
        _startDate = State(initialValue: period.startDate)
        _endDate = State(initialValue: period.endDate)
        _grossAmount = State(initialValue: String(period.grossAmount))
        _deductions = State(initialValue: String(period.deductions))
        _status = State(initialValue: period.status)
        _paymentDate = State(initialValue: period.paymentDate ?? Date())
        _hasPaymentDate = State(initialValue: period.paymentDate != nil)
        _paymentMethod = State(initialValue: period.paymentMethod ?? .directDeposit)
        _notes = State(initialValue: period.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Period Information") {
                    TextField("Period Name", text: $periodName)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                Section("Payment Details") {
                    TextField("Gross Amount", text: $grossAmount)
                    TextField("Deductions", text: $deductions)

                    HStack {
                        Text("Net Amount")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(netAmount.asCurrency())
                            .fontWeight(.semibold)
                    }
                }

                Section("Payment Status") {
                    Picker("Status", selection: $status) {
                        ForEach(PayrollPayPeriod.PaymentStatus.allCases) { s in
                            HStack {
                                Image(systemName: s.icon)
                                Text(s.rawValue)
                            }
                            .tag(s)
                        }
                    }

                    Toggle("Set Payment Date", isOn: $hasPaymentDate)
                    if hasPaymentDate {
                        DatePicker("Payment Date", selection: $paymentDate, displayedComponents: .date)
                    }

                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(PayrollPayPeriod.PaymentMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Edit Pay Period")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !periodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(grossAmount) != nil &&
        Double(deductions) != nil &&
        startDate <= endDate
    }

    private var netAmount: Double {
        let gross = Double(grossAmount) ?? 0
        let deduct = Double(deductions) ?? 0
        return max(0, gross - deduct)
    }

    private func saveChanges() {
        guard let gross = Double(grossAmount),
              let deduct = Double(deductions) else { return }

        var updatedPeriod = period
        updatedPeriod.periodName = periodName
        updatedPeriod.startDate = startDate
        updatedPeriod.endDate = endDate
        updatedPeriod.grossAmount = gross
        updatedPeriod.deductions = deduct
        updatedPeriod.netAmount = gross - deduct
        updatedPeriod.status = status
        updatedPeriod.paymentDate = hasPaymentDate ? paymentDate : nil
        updatedPeriod.paymentMethod = paymentMethod
        updatedPeriod.notes = notes

        viewModel.updatePayPeriod(itemID: payrollItem.id, period: updatedPeriod)
        isPresented = false
    }
}
