import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct AddBudgetItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel

    @State private var name: String = ""
    @State private var selectedAccount: BudgetAccount = .none
    @State private var selectedCategoryID: UUID?
    @State private var selectedSubcategory: String = ""
    @State private var section: String = ""
    @State private var quantity: Double = 1.0
    @State private var days: Double = 1.0
    @State private var unitCost: Double = 0.0
    @State private var notes: String = ""
    @State private var isLinkedToRateCard: Bool = false
    @State private var selectedRateCard: RateCardEntity?

    // Computed property for the selected category
    private var selectedCategory: CustomBudgetCategory? {
        viewModel.customCategories.first { $0.id == selectedCategoryID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    basicInfoSection
                    costDetailsSection
                    rateCardSection
                    notesSection
                }
                .padding(24)
            }

            Divider()

            // Footer with buttons
            footer
        }
        .frame(width: 520, height: 680)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .onAppear {
            // Set initial category to first available
            if selectedCategoryID == nil, let firstCategory = viewModel.customCategories.first {
                selectedCategoryID = firstCategory.id
                selectedSubcategory = firstCategory.subcategories.first ?? ""
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Budget Item")
                    .font(.system(size: 18, weight: .semibold))
                Text("Create a new line item for your budget")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(20)
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Basic Information", icon: "doc.text")

            VStack(spacing: 12) {
                // Item Name
                HStack(spacing: 12) {
                    Text("Item Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)

                    TextField("Enter item name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Account
                HStack(spacing: 12) {
                    Text("Account")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)

                    Picker("", selection: $selectedAccount) {
                        ForEach(BudgetAccount.allCases) { account in
                            Text(account.rawValue).tag(account)
                        }
                    }
                    .labelsHidden()
                }

                // Category (from ViewModel's customCategories)
                HStack(spacing: 12) {
                    Text("Category")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)

                    Picker("", selection: $selectedCategoryID) {
                        ForEach(viewModel.customCategories) { category in
                            Label(category.name, systemImage: category.icon)
                                .tag(category.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedCategoryID) { newValue in
                        // Update subcategory when category changes
                        if let categoryID = newValue,
                           let category = viewModel.customCategories.first(where: { $0.id == categoryID }) {
                            selectedSubcategory = category.subcategories.first ?? ""
                        }
                    }
                }

                // Subcategory (from selected category's subcategories)
                if let category = selectedCategory, !category.subcategories.isEmpty {
                    HStack(spacing: 12) {
                        Text("Subcategory")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)

                        Picker("", selection: $selectedSubcategory) {
                            Text("None").tag("")
                            ForEach(category.subcategories, id: \.self) { subcategory in
                                Text(subcategory).tag(subcategory)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Section (for grouping line items)
                HStack(spacing: 12) {
                    Text("Section")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("e.g., Camera Equipment, Crew Salaries", text: $section)
                            .textFieldStyle(.roundedBorder)

                        Text("Optional. Group related items under a section heading.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }

    // MARK: - Cost Details Section

    private var costDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Cost Details", icon: "dollarsign.circle")

            VStack(spacing: 12) {
                // Quantity
                HStack(spacing: 12) {
                    Text("Quantity")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)

                    TextField("1.0", value: $quantity, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                    Spacer()
                }

                // Days
                HStack(spacing: 12) {
                    Text("Days")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)

                    TextField("1.0", value: $days, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                    Spacer()
                }

                // Unit Cost
                HStack(spacing: 12) {
                    Text("Unit Cost")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)

                    TextField("$0.00", value: $unitCost, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)

                    Spacer()
                }

                Divider()
                    .padding(.vertical, 4)

                // Total
                HStack(spacing: 12) {
                    Text("Total")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 100, alignment: .trailing)

                    Text((quantity * days * unitCost).asCurrency())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.blue)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }

    // MARK: - Rate Card Section

    private var rateCardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Rate Card", icon: "creditcard")

            VStack(spacing: 12) {
                Toggle("Link to Rate Card", isOn: $isLinkedToRateCard)
                    .toggleStyle(.switch)

                if isLinkedToRateCard {
                    HStack(spacing: 12) {
                        Text("Rate Card")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)

                        Picker("", selection: $selectedRateCard) {
                            Text("None").tag(nil as RateCardEntity?)
                            ForEach(viewModel.rateCards, id: \.id) { rateCard in
                                Text(rateCard.displayName).tag(rateCard as RateCardEntity?)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedRateCard) { newCard in
                            if let card = newCard {
                                unitCost = card.defaultRate
                            }
                        }
                    }

                    if let card = selectedRateCard {
                        rateCardDetails(card: card)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }

    private func rateCardDetails(card: RateCardEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text("Rate Card Details")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Category:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(card.categoryType)
                    .font(.system(size: 12, weight: .medium))
            }

            HStack {
                Text("Unit:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(card.defaultUnit ?? "N/A")
                    .font(.system(size: 12, weight: .medium))
            }

            HStack {
                Text("Default Rate:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(card.formattedRate)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Notes", icon: "note.text")

            TextEditor(text: $notes)
                .font(.system(size: 13))
                .frame(minHeight: 60)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        #if os(macOS)
                        .fill(Color(nsColor: .textBackgroundColor))
                        #else
                        .fill(Color(uiColor: .systemBackground))
                        #endif
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Add Item") {
                addItem()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty)
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private func addItem() {
        // Get the category name from the selected custom category
        let categoryName = selectedCategory?.name ?? "Other"

        // Use section if provided, otherwise default to subcategory for grouping
        let trimmedSection = section.trimmingCharacters(in: .whitespaces)
        let sectionValue: String?
        if !trimmedSection.isEmpty {
            sectionValue = trimmedSection
        } else if !selectedSubcategory.isEmpty {
            sectionValue = selectedSubcategory
        } else {
            sectionValue = nil
        }

        let item = BudgetLineItem(
            name: name,
            account: selectedAccount.code,
            category: categoryName,
            subcategory: selectedSubcategory,
            section: sectionValue,
            quantity: quantity,
            days: days,
            unitCost: unitCost,
            notes: notes,
            isLinkedToRateCard: isLinkedToRateCard,
            rateCardID: selectedRateCard?.id
        )

        viewModel.addLineItem(item)
        dismiss()
    }
}

// MARK: - Preview
struct AddBudgetItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddBudgetItemView(viewModel: BudgetViewModel(context: PersistenceController.preview.container.viewContext))
    }
}
