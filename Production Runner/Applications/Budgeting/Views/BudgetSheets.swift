//
//  BudgetSheets.swift
//  Production Runner
//
//  Sheet views for the Budget module.
//  Extracted from BudgetView.swift for better organization.
//

import SwiftUI
import CoreData

// MARK: - New Version Dialog

struct NewVersionDialog: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel
    @State private var versionName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)

                        Text("Create New Budget Version")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Enter a name for your new budget version")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    // Version Name Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VERSION NAME")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)

                        TextField("e.g., Budget v2.0", text: $versionName)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .focused($isTextFieldFocused)
                            #if os(iOS)
                            .textInputAutocapitalization(.words)
                            #endif
                    }
                    .padding(.horizontal, 40)

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            if !versionName.isEmpty {
                                viewModel.createNewVersion(name: versionName)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Version")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(versionName.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(Color.blue.gradient))
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(versionName.isEmpty)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("New Version")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Auto-generate a name
            let count = viewModel.budgetVersions.count + 1
            versionName = "Budget v\(count).0"

            // Focus the text field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Rename Version Dialog

struct RenameVersionDialog: View {
    @ObservedObject var viewModel: BudgetViewModel
    let version: BudgetVersion
    @Binding var isPresented: Bool
    @State private var versionName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    private var canSave: Bool {
        !versionName.isEmpty && versionName != version.name
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange.gradient)

                Text("Rename Version")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter a new name for \"\(version.name)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.bottom, 24)

            // Text Field
            VStack(alignment: .leading, spacing: 8) {
                Text("VERSION NAME")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)

                TextField("Enter version name", text: $versionName)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            #if os(macOS)
                            .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                            #else
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                            #endif
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isTextFieldFocused ? Color.orange.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            }
            .padding(.horizontal, 24)

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    if canSave {
                        viewModel.renameVersion(version, to: versionName)
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(canSave ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 340, height: 300)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            versionName = version.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Contact Picker View

struct ContactPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    let item: BudgetLineItem
    @ObservedObject var viewModel: BudgetViewModel
    
    @State private var selectedType: BudgetLineItem.ContactType
    @State private var searchText = ""
    
    // Fetch contacts from ContactEntity and convert to Contact structs
    @State private var allContacts: [ContactInfo] = []
    
    // Simple struct to hold contact info we need
    struct ContactInfo: Identifiable {
        let id: UUID
        let name: String
        let role: String?
        let category: String
    }
    
    init(item: BudgetLineItem, viewModel: BudgetViewModel) {
        self.item = item
        self.viewModel = viewModel
        // Initialize with the item's existing contact type, or default to crew
        _selectedType = State(initialValue: item.linkedContactType ?? .crew)
    }
    
    var filteredContacts: [ContactInfo] {
        var result: [ContactInfo] = []
        
        for contact in allContacts {
            let matchesType: Bool
            switch selectedType {
            case .crew:
                matchesType = contact.category.lowercased().contains("crew")
            case .cast:
                matchesType = contact.category.lowercased().contains("cast")
            case .vendor:
                matchesType = contact.category.lowercased().contains("vendor")
            }
            
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = contact.name.localizedCaseInsensitiveContains(searchText) ||
                               (contact.role?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            
            if matchesType && matchesSearch {
                result.append(contact)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Contact Type Picker
                Picker("Contact Type", selection: $selectedType) {
                    Text("Crew").tag(BudgetLineItem.ContactType.crew)
                    Text("Cast").tag(BudgetLineItem.ContactType.cast)
                    Text("Vendor").tag(BudgetLineItem.ContactType.vendor)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search contacts...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Contact List
                List {
                    if filteredContacts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No Contacts")
                                .font(.headline)
                            
                            Text("No \(selectedType.rawValue.lowercased()) contacts found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredContacts) { contact in
                            Button(action: {
                                attachContact(contact)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(contact.name)
                                            .font(.headline)
                                        
                                        if let role = contact.role, !role.isEmpty {
                                            Text(role)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if let linkedID = item.linkedContactID,
                                       linkedID == contact.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Remove Contact Option
                    if item.linkedContactID != nil {
                        Section {
                            Button(role: .destructive, action: {
                                removeContact()
                            }) {
                                Label("Remove Attached Contact", systemImage: "person.badge.minus")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach Contact")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadContacts()
            }
        }
    }
    
    private func loadContacts() {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let results = try context.fetch(req)
            allContacts = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else {
                    return nil
                }
                
                let role = mo.value(forKey: "role") as? String
                
                // Try to read category from various possible fields
                var category = "crew" // default
                if let categoryString = mo.value(forKey: "category") as? String {
                    category = categoryString
                } else if let categoryInt = mo.value(forKey: "category") as? Int {
                    switch categoryInt {
                    case 0: category = "cast"
                    case 1: category = "crew"
                    case 2: category = "vendor"
                    default: category = "crew"
                    }
                } else if let note = mo.value(forKey: "note") as? String {
                    // Fall back to reading from note tag
                    if note.lowercased().contains("[cast]") {
                        category = "cast"
                    } else if note.lowercased().contains("[vendor]") {
                        category = "vendor"
                    }
                }
                
                return ContactInfo(id: id, name: name, role: role, category: category)
            }
        } catch {
            print("Error fetching contacts: \(error)")
        }
    }
    
    private func attachContact(_ contact: ContactInfo) {
        viewModel.linkContactToItem(itemID: item.id, contactID: contact.id, contactType: selectedType)
        dismiss()
    }
    
    private func removeContact() {
        viewModel.unlinkContactFromItem(itemID: item.id)
        dismiss()
    }
}

// MARK: - Add Cast Member View

struct AddCastMemberView: View {
    @Environment(\.managedObjectContext) private var context
    let parentItem: BudgetLineItem
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var selectedContact: ContactInfo?
    @State private var dayRate: Double = 0.0
    @State private var shootDays: Double = 1.0
    @State private var allContacts: [ContactInfo] = []
    
    struct ContactInfo: Identifiable {
        let id: UUID
        let name: String
        let role: String?
    }
    
    var filteredContacts: [ContactInfo] {
        if searchText.isEmpty {
            return allContacts
        }
        return allContacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText) ||
            (contact.role?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Cast Member Selection
                Section("Select Cast Member") {
                    if let selected = selectedContact {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selected.name)
                                    .font(.headline)
                                if let role = selected.role, !role.isEmpty {
                                    Text(role)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                selectedContact = nil
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        // Search and select
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search cast members...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        
                        ForEach(filteredContacts.prefix(10)) { contact in
                            Button(action: {
                                selectedContact = contact
                                searchText = ""
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.name)
                                            .font(.subheadline)
                                        if let role = contact.role, !role.isEmpty {
                                            Text(role)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Rate Information
                if selectedContact != nil {
                    Section("Rate Details") {
                        HStack {
                            Text("Day Rate")
                            Spacer()
                            TextField("$0.00", value: $dayRate, format: .currency(code: "USD"))
                                .frame(width: 120)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        
                        HStack {
                            Text("Shoot Days")
                            Spacer()
                            TextField("1", value: $shootDays, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        
                        HStack {
                            Text("Total")
                            Spacer()
                            Text((dayRate * shootDays).asCurrency())
                                .font(.headline)
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Add Cast Member")
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
                        if let contact = selectedContact {
                            viewModel.addCastMemberToItem(
                                parentItemID: parentItem.id,
                                contactID: contact.id,
                                contactName: contact.name,
                                dayRate: dayRate,
                                shootDays: shootDays
                            )
                            isPresented = false
                        }
                    }
                    .disabled(selectedContact == nil || dayRate <= 0)
                }
            }
            .onAppear {
                loadCastContacts()
            }
        }
    }
    
    private func loadCastContacts() {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let results = try context.fetch(req)
            allContacts = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else {
                    return nil
                }
                
                // Check if this is a cast contact
                var isCast = false
                if let categoryString = mo.value(forKey: "category") as? String {
                    isCast = categoryString.lowercased().contains("cast")
                } else if let categoryInt = mo.value(forKey: "category") as? Int {
                    isCast = (categoryInt == 0) // Assuming 0 is cast
                } else if let note = mo.value(forKey: "note") as? String {
                    isCast = note.lowercased().contains("[cast]")
                }
                
                guard isCast else { return nil }
                
                let role = mo.value(forKey: "role") as? String
                return ContactInfo(id: id, name: name, role: role)
            }
        } catch {
            print("Error fetching cast contacts: \(error)")
        }
    }
}

// MARK: - Inline Add Transaction Form

struct InlineAddTransactionForm: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isShowing: Bool

    @State private var date = Date()
    @State private var amount: Double = 0
    @State private var selectedCategory: TransactionCategory = .adminOfficeMisc
    @State private var department = ""
    @State private var selectedTransactionType: TransactionType = .expense
    @State private var descriptionText = ""
    @State private var payee = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("New Transaction")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Add") {
                    let transaction = BudgetTransaction(
                        date: date,
                        amount: amount,
                        category: selectedCategory.rawValue,
                        department: department,
                        transactionType: selectedTransactionType.rawValue,
                        descriptionText: descriptionText,
                        payee: payee,
                        notes: notes
                    )
                    viewModel.addTransaction(transaction)

                    // Reset form
                    descriptionText = ""
                    amount = 0
                    department = ""
                    payee = ""
                    notes = ""
                    date = Date()

                    // Close form
                    withAnimation {
                        isShowing = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .disabled(descriptionText.isEmpty || amount == 0)
            }

            Divider()

            // Form Fields (Two Column Layout)
            HStack(alignment: .top, spacing: 16) {
                // Left Column
                VStack(alignment: .leading, spacing: 12) {
                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }

                    // Type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        Picker("", selection: $selectedTransactionType) {
                            ForEach(TransactionType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("What is this for?", text: $descriptionText)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("$0.00", value: $amount, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity)

                // Right Column
                VStack(alignment: .leading, spacing: 12) {
                    // Category
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        Picker("", selection: $selectedCategory) {
                            ForEach(TransactionCategory.allCases) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .labelsHidden()
                    }

                    // Department
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Department")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("Which department?", text: $department)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Payee
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payee")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("Who is this paid to?", text: $payee)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("Additional details", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Inline Edit Transaction Form

struct InlineEditTransactionForm: View {
    let transaction: BudgetTransaction
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isShowing: Bool

    @State private var date: Date
    @State private var amount: Double
    @State private var selectedCategory: TransactionCategory
    @State private var department: String
    @State private var selectedTransactionType: TransactionType
    @State private var descriptionText: String
    @State private var payee: String
    @State private var notes: String

    init(transaction: BudgetTransaction, viewModel: BudgetViewModel, isShowing: Binding<Bool>) {
        self.transaction = transaction
        self.viewModel = viewModel
        self._isShowing = isShowing

        // Initialize state from transaction
        _date = State(initialValue: transaction.date)
        _amount = State(initialValue: transaction.amount)
        _selectedCategory = State(initialValue: TransactionCategory.allCases.first(where: { $0.rawValue == transaction.category }) ?? .adminOfficeMisc)
        _department = State(initialValue: transaction.department)
        _selectedTransactionType = State(initialValue: TransactionType.allCases.first(where: { $0.rawValue == transaction.transactionType }) ?? .expense)
        _descriptionText = State(initialValue: transaction.descriptionText)
        _payee = State(initialValue: transaction.payee)
        _notes = State(initialValue: transaction.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Edit Transaction")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Save") {
                    var updatedTransaction = transaction
                    updatedTransaction.date = date
                    updatedTransaction.amount = amount
                    updatedTransaction.category = selectedCategory.rawValue
                    updatedTransaction.department = department
                    updatedTransaction.transactionType = selectedTransactionType.rawValue
                    updatedTransaction.descriptionText = descriptionText
                    updatedTransaction.payee = payee
                    updatedTransaction.notes = notes

                    viewModel.updateTransaction(updatedTransaction)

                    // Close form
                    withAnimation {
                        isShowing = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .disabled(descriptionText.isEmpty || amount == 0)
            }

            Divider()

            // Form Fields (Two Column Layout)
            HStack(alignment: .top, spacing: 16) {
                // Left Column
                VStack(alignment: .leading, spacing: 12) {
                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }

                    // Type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        Picker("", selection: $selectedTransactionType) {
                            ForEach(TransactionType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("What is this for?", text: $descriptionText)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("$0.00", value: $amount, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity)

                // Right Column
                VStack(alignment: .leading, spacing: 12) {
                    // Category
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        Picker("", selection: $selectedCategory) {
                            ForEach(TransactionCategory.allCases) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .labelsHidden()
                    }

                    // Department
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Department")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("Which department?", text: $department)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Payee
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payee")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("Who is this paid to?", text: $payee)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        TextField("Additional details", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: BudgetTransaction
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Transaction Icon
                Image(systemName: iconForType(transaction.transactionType))
                    .font(.title3)
                    .foregroundStyle(colorForType(transaction.transactionType))
                    .frame(width: 32, height: 32)
                    .background(colorForType(transaction.transactionType).opacity(0.1))
                    .clipShape(Circle())

                // Transaction Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.descriptionText)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(transaction.amount.asCurrency())
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(colorForType(transaction.transactionType))
                    }

                    HStack(spacing: 8) {
                        Text(transaction.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(transaction.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !transaction.department.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text(transaction.department)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !transaction.payee.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text(transaction.payee)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Expand/Collapse Chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "Expense": return "arrow.down.circle.fill"
        case "Payment": return "creditcard.fill"
        case "Refund": return "arrow.up.circle.fill"
        case "Adjustment": return "pencil.circle.fill"
        default: return "dollarsign.circle.fill"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "Expense": return .red
        case "Payment": return .orange
        case "Refund": return .green
        case "Adjustment": return .blue
        default: return .gray
        }
    }
}

// MARK: - Category Total Row
struct CategoryTotalRow: View {
    let category: BudgetCategory
    let total: Double
    let percentage: Double
    @EnvironmentObject var viewModel: BudgetViewModel
    @State private var isExpanded: Bool = false

    // Get all section names from line items that belong to this category
    private var sectionsForCategory: [String] {
        let sections = viewModel.lineItems
            .filter { $0.category == category.rawValue }
            .compactMap { $0.section }
        return Array(Set(sections)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main category row - Modern minimalist design
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        // Category Icon with modern background
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: category.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(category.color)
                        }

                        // Category Details
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(category.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(total.asCurrency())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            // Sleek progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(category.color.gradient)
                                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("\(percentage, specifier: "%.1f")%")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                // Chevron indicator
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Department sections - Modern card style
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sectionsForCategory, id: \.self) { sectionName in
                        DepartmentRow(
                            sectionName: sectionName,
                            category: category,
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }
}

// MARK: - Department Row
struct DepartmentRow: View {
    let sectionName: String
    let category: BudgetCategory
    let viewModel: BudgetViewModel

    private var sectionTotal: Double {
        // Calculate total from line items in this section
        viewModel.lineItems
            .filter { $0.category == category.rawValue && $0.section == sectionName }
            .reduce(0) { $0 + ($1.unitCost * $1.quantity * $1.days) }
    }

    private var actualSpent: Double {
        // Calculate actual expenses from transactions matching this section
        viewModel.transactions
            .filter { $0.category == sectionName && $0.transactionType == "Expense" }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        let remaining = sectionTotal - actualSpent

        HStack(spacing: 12) {
            // Modern accent line
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(category.color.opacity(0.4))
                .frame(width: 3, height: 40)

            VStack(alignment: .leading, spacing: 8) {
                Text(sectionName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    // Budgeted amount
                    HStack(spacing: 4) {
                        Text("Budget:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(sectionTotal.asCurrency())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    // Spent amount
                    HStack(spacing: 4) {
                        Text("Spent:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(actualSpent.asCurrency())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(actualSpent > sectionTotal ? .red : .green)
                    }

                    Spacer()

                    // Remaining
                    HStack(spacing: 4) {
                        Text("Left:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(remaining.asCurrency())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(remaining >= 0 ? .secondary : .red)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .padding(.leading, 44)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Cost Summary Card
struct CostSummaryCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .fontWeight(.semibold)

            Text(amount.asCurrency())
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Category Comparison Bar
struct CategoryComparisonBar: View {
    let category: BudgetCategory
    let budgeted: Double
    let actual: Double

    private var remaining: Double {
        budgeted - actual
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)

                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Budget:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(budgeted.asCurrency())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text("Spent:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(actual.asCurrency())
                            .font(.caption)
                            .foregroundStyle(actual > budgeted ? .red : .primary)
                    }

                    HStack(spacing: 8) {
                        Text("Remaining:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(remaining.asCurrency())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(remaining >= 0 ? .green : .red)
                    }
                }
            }

            // Comparison Bars
            GeometryReader { geometry in
                VStack(spacing: 4) {
                    // Budgeted Bar
                    HStack(spacing: 4) {
                        Text("Budget")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 18)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.gradient)
                                .frame(width: budgeted > 0 ? geometry.size.width - 64 : 0, height: 18)
                        }
                    }

                    // Spent Bar
                    HStack(spacing: 4) {
                        Text("Spent")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 18)

                            RoundedRectangle(cornerRadius: 4)
                                .fill((actual > budgeted ? Color.red : Color.orange).gradient)
                                .frame(width: budgeted > 0 ? max(0, min((geometry.size.width - 64) * (actual / budgeted), geometry.size.width - 64)) : 0, height: 18)
                        }
                    }

                    // Remaining Bar
                    HStack(spacing: 4) {
                        Text("Remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 18)

                            RoundedRectangle(cornerRadius: 4)
                                .fill((remaining >= 0 ? Color.green : Color.clear).gradient)
                                .frame(width: budgeted > 0 && remaining >= 0 ? max(0, (geometry.size.width - 64) * (remaining / budgeted)) : 0, height: 18)
                        }
                    }
                }
            }
            .frame(height: 62)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Cost of Scene Row

struct CostOfSceneRow: View {
    let scene: SceneEntity
    let isSelected: Bool
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpand: () -> Void

    private var sceneHeading: String {
        let locType = (scene.locationType ?? "INT.").trimmingCharacters(in: .whitespacesAndNewlines)
        let tod = (scene.timeOfDay ?? "DAY").trimmingCharacters(in: .whitespacesAndNewlines)
        var location = ""
        if scene.entity.attributesByName.keys.contains("heading"),
           let h = scene.value(forKey: "heading") as? String,
           !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            location = h.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let loc = scene.scriptLocation?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
            location = loc
        } else {
            location = "Untitled Scene"
        }
        return "\(locType) \(location) - \(tod)"
    }

    private var itemCount: Int {
        guard let breakdown = scene.breakdown else { return 0 }
        return breakdown.getCastIDs().count +
               breakdown.getProps().count +
               breakdown.getArt().count +
               breakdown.getWardrobe().count +
               breakdown.getMakeup().count +
               breakdown.getVehicles().count +
               breakdown.getSPFX().count +
               breakdown.getSoundFX().count +
               breakdown.getVisualEffects().count +
               breakdown.getExtras().count +
               breakdown.getCustomCategories().flatMap { $0.items }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Expand/collapse chevron
                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                // Scene number badge
                Text(scene.number ?? "?")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 32)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue))

                // Scene heading
                VStack(alignment: .leading, spacing: 2) {
                    Text(sceneHeading)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(itemCount) breakdown items")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Page count if available
                if let pageEighths = scene.pageEighthsString, !pageEighths.isEmpty {
                    Text(pageEighths)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }

            // Expanded content - show category summary
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let breakdown = scene.breakdown {
                        let castCount = breakdown.getCastIDs().count
                        let propsCount = breakdown.getProps().count
                        let artCount = breakdown.getArt().count
                        let wardrobeCount = breakdown.getWardrobe().count
                        let makeupCount = breakdown.getMakeup().count
                        let vehiclesCount = breakdown.getVehicles().count
                        let spfxCount = breakdown.getSPFX().count
                        let soundCount = breakdown.getSoundFX().count
                        let vfxCount = breakdown.getVisualEffects().count
                        let extrasCount = breakdown.getExtras().count

                        if castCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "person.2.fill", color: .blue, title: "Cast", count: castCount)
                        }
                        if propsCount + artCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "paintbrush.fill", color: .orange, title: "Art", count: propsCount + artCount)
                        }
                        if wardrobeCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "tshirt.fill", color: .purple, title: "Wardrobe", count: wardrobeCount)
                        }
                        if makeupCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "face.smiling", color: .pink, title: "Makeup", count: makeupCount)
                        }
                        if vehiclesCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "car.fill", color: .gray, title: "Vehicles", count: vehiclesCount)
                        }
                        if spfxCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "flame.fill", color: .red, title: "SFX", count: spfxCount)
                        }
                        if soundCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "waveform", color: .green, title: "Sound", count: soundCount)
                        }
                        if vfxCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "sparkles", color: .cyan, title: "VFX", count: vfxCount)
                        }
                        if extrasCount > 0 {
                            CostOfSceneCategorySummaryRow(icon: "person.3.fill", color: .indigo, title: "Extras", count: extrasCount)
                        }
                    }
                }
                .padding(.leading, 56)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Cost of Scene Category Summary Row

struct CostOfSceneCategorySummaryRow: View {
    let icon: String
    let color: Color
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Cost of Scene Category Section

struct CostOfSceneCategorySection: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    let context: NSManagedObjectContext

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                        .frame(width: 24)

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("(\(items.count))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            // Items list
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color.opacity(0.5))
                                .frame(width: 6, height: 6)

                            // For cast items, try to look up the contact name
                            if title == "Cast", let uuid = UUID(uuidString: item) {
                                CostOfSceneCastItemView(castID: uuid, context: context)
                            } else {
                                Text(item)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 38)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                )
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Cost of Scene Cast Item View

struct CostOfSceneCastItemView: View {
    let castID: UUID
    let context: NSManagedObjectContext

    @State private var contactName: String = ""
    @State private var characterName: String = ""

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(contactName.isEmpty ? "Unknown Cast Member" : contactName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if !characterName.isEmpty {
                    Text("as \(characterName)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            loadContactInfo()
        }
    }

    private func loadContactInfo() {
        // Try to fetch contact from Core Data
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        request.predicate = NSPredicate(format: "id == %@", castID as CVarArg)
        request.fetchLimit = 1

        do {
            if let contact = try context.fetch(request).first {
                contactName = contact.value(forKey: "name") as? String ?? ""
                // Check if there's a character/role field
                if contact.entity.attributesByName.keys.contains("role") {
                    characterName = contact.value(forKey: "role") as? String ?? ""
                }
            }
        } catch {
            print("Failed to fetch contact: \(error)")
        }
    }
}

// MARK: - Budget Category Manager Sheet

struct BudgetCategoryManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel

    @State private var newCategoryName = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String = "folder.fill"
    @State private var showingIconPicker = false
    @State private var editingCategory: CustomBudgetCategory? = nil

    private let availableIcons = [
        "star.fill", "film.fill", "video.fill", "camera.fill",
        "waveform", "music.note", "mic.fill", "person.fill",
        "person.2.fill", "person.3.fill", "briefcase.fill", "folder.fill",
        "doc.fill", "tray.fill", "cart.fill", "dollarsign.circle.fill",
        "creditcard.fill", "building.2.fill", "hammer.fill", "wrench.fill",
        "paintbrush.fill", "scissors", "lightbulb.fill", "bolt.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    createCategoryCard
                    existingCategoriesSection
                }
                .padding(24)
            }

            Divider()
            footerSection
        }
        .frame(width: 580, height: 660)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Category Management")
                    .font(.system(size: 22, weight: .bold))
                Text("Create and manage budget categories")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var createCategoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingCategory == nil ? "Create Category" : "Edit Category")
                .font(.system(size: 17, weight: .semibold))

            VStack(spacing: 14) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("e.g., Above the Line, Production, Post", text: $newCategoryName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }

                HStack(spacing: 14) {
                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 24, height: 24)
                            ColorPicker("", selection: $selectedColor)
                                .labelsHidden()
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }

                    // Icon picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Button(action: { showingIconPicker.toggle() }) {
                            HStack {
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(selectedColor)
                                    .frame(width: 24)
                                Text("Choose Icon")
                                    .font(.system(size: 13))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Icon picker grid
                if showingIconPicker {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                            ForEach(availableIcons, id: \.self) { icon in
                                iconButton(icon: icon)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.02))
                    )
                }

                createOrUpdateButton
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func iconButton(icon: String) -> some View {
        let isSelected = selectedIcon == icon
        return Button(action: {
            selectedIcon = icon
            showingIconPicker = false
        }) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? selectedColor : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? selectedColor.opacity(0.12) : Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? selectedColor.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private var createOrUpdateButton: some View {
        HStack(spacing: 12) {
            if editingCategory != nil {
                Button(action: cancelEdit) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            Button(action: editingCategory == nil ? createCategory : updateCategory) {
                HStack(spacing: 8) {
                    Image(systemName: editingCategory == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text(editingCategory == nil ? "Create Category" : "Update Category")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
                )
                .foregroundStyle(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color.white)
            }
            .buttonStyle(.plain)
            .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var existingCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Existing Categories")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(viewModel.customCategories.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if viewModel.customCategories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No categories created yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Load Feature Film Defaults") {
                        viewModel.loadDefaultCategories(for: .featureFilm)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.customCategories) { category in
                        categoryRow(category)
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: CustomBudgetCategory) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(category.color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 4) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 6, height: 6)
                    Text(category.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text("\(viewModel.itemCount(for: category)) items")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { startEditing(category) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Edit category")

                Button(action: { deleteCategory(category) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .help("Delete category")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var footerSection: some View {
        HStack {
            Menu {
                Button("Feature Film Defaults") {
                    viewModel.loadDefaultCategories(for: .featureFilm)
                }
                Button("Short Film Defaults") {
                    viewModel.loadDefaultCategories(for: .shortFilm)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                    Text("Load Defaults")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Helper Functions

    private func createCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let hexColor: String = selectedColor.toHex() ?? "#007AFF"
        let category = CustomBudgetCategory(
            name: name,
            icon: selectedIcon,
            colorHex: hexColor
        )
        viewModel.addCustomCategory(category)
        resetForm()
    }

    private func updateCategory() {
        guard let editing = editingCategory else { return }
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let hexColor: String = selectedColor.toHex() ?? "#007AFF"
        var updated = editing
        updated.name = name
        updated.icon = selectedIcon
        updated.colorHex = hexColor
        viewModel.updateCustomCategory(updated)
        resetForm()
    }

    private func startEditing(_ category: CustomBudgetCategory) {
        editingCategory = category
        newCategoryName = category.name
        selectedColor = category.color
        selectedIcon = category.icon
        showingIconPicker = false
    }

    private func cancelEdit() {
        resetForm()
    }

    private func resetForm() {
        editingCategory = nil
        newCategoryName = ""
        selectedColor = .blue
        selectedIcon = "folder.fill"
        showingIconPicker = false
    }

    private func deleteCategory(_ category: CustomBudgetCategory) {
        viewModel.deleteCustomCategory(category)
    }
}
