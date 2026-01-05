import SwiftUI

struct EditBudgetItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel
    
    let item: BudgetLineItem
    
    @State private var name: String
    @State private var account: String
    @State private var selectedCategory: BudgetCategory
    @State private var selectedSubcategory: String
    @State private var quantity: Double
    @State private var days: Double
    @State private var unitCost: Double
    @State private var notes: String
    @State private var isLinkedToRateCard: Bool
    @State private var selectedRateCard: RateCardEntity?
    
    init(item: BudgetLineItem, viewModel: BudgetViewModel) {
        self.item = item
        self.viewModel = viewModel
        
        // Initialize state from item
        _name = State(initialValue: item.name)
        _account = State(initialValue: item.account)
        _selectedCategory = State(initialValue: BudgetCategory.allCases.first(where: { $0.rawValue == item.category }) ?? .belowTheLine)
        _selectedSubcategory = State(initialValue: item.subcategory)
        _quantity = State(initialValue: item.quantity)
        _days = State(initialValue: item.days)
        _unitCost = State(initialValue: item.unitCost)
        _notes = State(initialValue: item.notes)
        _isLinkedToRateCard = State(initialValue: item.isLinkedToRateCard)
        
        // Find the rate card if linked
        if let rateCardID = item.rateCardID {
            _selectedRateCard = State(initialValue: viewModel.rateCards.first(where: { $0.id == rateCardID }))
        } else {
            _selectedRateCard = State(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                costDetailsSection
                rateCardSection
                notesSection
                deleteSection
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Budget Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 650)
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        Section("Basic Information") {
            HStack {
                Text("Item Name")
                    .frame(width: 100, alignment: .trailing)
                TextField("Item Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("Account")
                    .frame(width: 100, alignment: .trailing)
                TextField("Account", text: $account)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("Category")
                    .frame(width: 100, alignment: .trailing)
                Picker("Category", selection: $selectedCategory) {
                    ForEach(BudgetCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            }
            .onChange(of: selectedCategory) { newValue in
                if !newValue.subcategories.contains(selectedSubcategory) {
                    selectedSubcategory = newValue.subcategories.first ?? ""
                }
            }
            
            HStack {
                Text("Subcategory")
                    .frame(width: 100, alignment: .trailing)
                Picker("Subcategory", selection: $selectedSubcategory) {
                    ForEach(selectedCategory.subcategories, id: \.self) { subcategory in
                        Text(subcategory).tag(subcategory)
                    }
                }
            }
        }
    }
    
    private var costDetailsSection: some View {
        Section("Cost Details") {
            HStack {
                Text("Quantity")
                    .frame(width: 100, alignment: .trailing)
                TextField("1.0", value: $quantity, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Spacer()
            }
            
            HStack {
                Text("Days")
                    .frame(width: 100, alignment: .trailing)
                TextField("1.0", value: $days, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Spacer()
            }
            
            HStack {
                Text("Unit Cost")
                    .frame(width: 100, alignment: .trailing)
                TextField("$0.00", value: $unitCost, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Spacer()
            }
            
            HStack {
                Text("Total")
                    .frame(width: 100, alignment: .trailing)
                    .fontWeight(.semibold)
                Text((quantity * days * unitCost).asCurrency())
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
            }
        }
    }
    
    private var rateCardSection: some View {
        Section("Rate Card") {
            Toggle("Link to Rate Card", isOn: $isLinkedToRateCard)
            
            if isLinkedToRateCard {
                rateCardPicker
                
                if let card = selectedRateCard {
                    rateCardDetails(card: card)
                }
            }
        }
    }
    
    private var rateCardPicker: some View {
        HStack {
            Text("Select Rate Card")
                .frame(width: 120, alignment: .trailing)
            Picker("Select Rate Card", selection: $selectedRateCard) {
                Text("None").tag(nil as RateCardEntity?)
                ForEach(viewModel.rateCards, id: \.id) { rateCard in
                    Text(rateCard.displayName).tag(rateCard as RateCardEntity?)
                }
            }
            Spacer()
        }
        .onChange(of: selectedRateCard) { newCard in
            if let card = newCard {
                unitCost = card.defaultRate
            }
        }
    }
    
    private func rateCardDetails(card: RateCardEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rate Card Details")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("Category:")
                Spacer()
                Text(card.categoryType)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Unit:")
                Spacer()
                Text(card.defaultUnit ?? "N/A")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Default Rate:")
                Spacer()
                Text(card.formattedRate)
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive, action: {
                viewModel.deleteLineItem(item)
                dismiss()
            }) {
                Label("Delete Item", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        var updatedItem = item
        updatedItem.name = name
        updatedItem.account = account
        updatedItem.category = selectedCategory.rawValue
        updatedItem.subcategory = selectedSubcategory
        updatedItem.quantity = quantity
        updatedItem.days = days
        updatedItem.unitCost = unitCost
        updatedItem.notes = notes
        updatedItem.isLinkedToRateCard = isLinkedToRateCard
        updatedItem.rateCardID = selectedRateCard?.id
        
        viewModel.updateLineItem(updatedItem)
        dismiss()
    }
}

// MARK: - Preview
struct EditBudgetItemView_Previews: PreviewProvider {
    static var previews: some View {
        let item = BudgetLineItem(
            name: "Test Item",
            category: "Above the Line",
            subcategory: "Cast",
            quantity: 5,
            days: 10,
            unitCost: 1000,
            notes: "Test notes"
        )
        EditBudgetItemView(
            item: item,
            viewModel: BudgetViewModel(context: PersistenceController.preview.container.viewContext)
        )
    }
}
