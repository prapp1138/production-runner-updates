import SwiftUI

/// Advanced search and filter panel for budget line items
struct BudgetSearchFilterView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var filter: BudgetSearchFilter
    @Binding var isPresented: Bool

    @State private var minAmountText: String = ""
    @State private var maxAmountText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Filter options
            ScrollView {
                VStack(spacing: 20) {
                    searchSection
                    categorySection
                    amountSection
                    sortSection
                    optionsSection
                }
                .padding(20)
            }

            Divider()

            // Footer with actions
            footer
        }
        .frame(width: 400, height: 520)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .onAppear {
            if let min = filter.minAmount {
                minAmountText = String(format: "%.2f", min)
            }
            if let max = filter.maxAmount {
                maxAmountText = String(format: "%.2f", max)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search & Filter")
                    .font(.system(size: 18, weight: .semibold))
                Text("Refine your budget view")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if filter.hasActiveFilters {
                Button(action: resetFilters) {
                    Text("Reset All")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Search Section

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Search", icon: "magnifyingglass")

            TextField("Search by name, account, notes...", text: $filter.searchText)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Category", icon: "folder")

            Picker("Category", selection: $filter.selectedCategory) {
                Text("All Categories").tag(nil as BudgetCategory?)
                ForEach(BudgetCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category as BudgetCategory?)
                }
            }
            .labelsHidden()

            if !viewModel.sectionsForCurrentCategory.isEmpty {
                Picker("Section", selection: $filter.selectedSection) {
                    Text("All Sections").tag(nil as String?)
                    ForEach(viewModel.sectionsForCurrentCategory, id: \.self) { section in
                        Text(section).tag(section as String?)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Amount Range", icon: "dollarsign.circle")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("$0.00", text: $minAmountText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: minAmountText) { newValue in
                            filter.minAmount = Double(newValue)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("No limit", text: $maxAmountText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: maxAmountText) { newValue in
                            filter.maxAmount = Double(newValue)
                        }
                }
            }
        }
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Sort By", icon: "arrow.up.arrow.down")

            HStack(spacing: 12) {
                Picker("Sort", selection: $filter.sortBy) {
                    ForEach(BudgetSearchFilter.SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .labelsHidden()

                Picker("Order", selection: $filter.sortAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Options", icon: "slider.horizontal.3")

            Toggle("Show only linked items", isOn: $filter.showOnlyLinked)
                .toggleStyle(.switch)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            // Filter summary
            if filter.hasActiveFilters {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(.blue)
                    Text("\(activeFilterCount) active")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Apply") {
                applyFilters()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.blue)
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if !filter.searchText.isEmpty { count += 1 }
        if filter.selectedCategory != nil { count += 1 }
        if filter.selectedSection != nil { count += 1 }
        if filter.minAmount != nil { count += 1 }
        if filter.maxAmount != nil { count += 1 }
        if filter.showOnlyLinked { count += 1 }
        return count
    }

    private func resetFilters() {
        filter.reset()
        minAmountText = ""
        maxAmountText = ""
    }

    private func applyFilters() {
        // Filters are already bound, just close
        isPresented = false
    }
}

// MARK: - Quick Filter Bar

/// Compact filter bar shown above the budget list
struct BudgetQuickFilterBar: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var showAdvancedFilter: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search items...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    #if os(macOS)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    #else
                    .fill(Color(uiColor: .secondarySystemBackground))
                    #endif
            )

            // Advanced filter button
            Button(action: { showAdvancedFilter = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.bordered)

            // Active filter indicator
            if viewModel.filter.hasActiveFilters {
                Button(action: { viewModel.filter.reset() }) {
                    HStack(spacing: 4) {
                        Text("Clear")
                            .font(.system(size: 12))
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Chips

/// Shows active filters as removable chips
struct BudgetFilterChips: View {
    @Binding var filter: BudgetSearchFilter

    var body: some View {
        if filter.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !filter.searchText.isEmpty {
                        filterChip(
                            label: "Search: \(filter.searchText)",
                            onRemove: { filter.searchText = "" }
                        )
                    }

                    if let category = filter.selectedCategory {
                        filterChip(
                            label: category.rawValue,
                            onRemove: { filter.selectedCategory = nil }
                        )
                    }

                    if let section = filter.selectedSection {
                        filterChip(
                            label: "Section: \(section)",
                            onRemove: { filter.selectedSection = nil }
                        )
                    }

                    if let min = filter.minAmount {
                        filterChip(
                            label: "Min: \(min.asCurrency())",
                            onRemove: { filter.minAmount = nil }
                        )
                    }

                    if let max = filter.maxAmount {
                        filterChip(
                            label: "Max: \(max.asCurrency())",
                            onRemove: { filter.maxAmount = nil }
                        )
                    }

                    if filter.showOnlyLinked {
                        filterChip(
                            label: "Linked Only",
                            onRemove: { filter.showOnlyLinked = false }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    private func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.15))
        )
        .foregroundStyle(.blue)
    }
}

// MARK: - Preview

struct BudgetSearchFilterView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetSearchFilterView(
            viewModel: BudgetViewModel(context: PersistenceController.preview.container.viewContext),
            filter: .constant(BudgetSearchFilter()),
            isPresented: .constant(true)
        )
    }
}
