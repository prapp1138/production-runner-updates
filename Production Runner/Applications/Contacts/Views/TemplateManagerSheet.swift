//
//  TemplateManagerSheet.swift
//  Production Runner
//
//  Manages contact templates for quick creation of new contacts with pre-filled fields.
//

import SwiftUI
import CoreData

// MARK: - Template Model
struct ContactTemplate: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: Contact.Category?
    var department: Contact.Department?
    var role: String?
    var ratePerDay: Double?
    var rateUnit: String?
    var sortOrder: Int16 = 0
    var createdAt: Date = Date()
}

// MARK: - Template Manager Sheet (macOS)
#if os(macOS)
struct TemplateManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var templates: [ContactTemplate] = []
    @State private var showingAddTemplate = false
    @State private var editingTemplate: ContactTemplate? = nil
    @State private var showingDeleteConfirmation = false
    @State private var templateToDelete: ContactTemplate? = nil

    private let entityName = "ContactTemplateEntity"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Contact Templates")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: { showingAddTemplate = true }) {
                    Label("New Template", systemImage: "plus")
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color.primary.opacity(0.03))

            Divider()

            if templates.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No templates yet")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("Templates let you quickly create contacts with pre-filled fields")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                    Button("Create Template") { showingAddTemplate = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(templates) { template in
                            templateRow(template)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 400)
        .onAppear { loadTemplates() }
        .sheet(isPresented: $showingAddTemplate) {
            TemplateEditorSheet(template: nil, onSave: { newTemplate in
                saveTemplate(newTemplate)
            })
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorSheet(template: template, onSave: { updatedTemplate in
                updateTemplate(updatedTemplate)
            })
        }
        .alert("Delete Template?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    deleteTemplate(template)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func templateRow(_ template: ContactTemplate) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 8) {
                    if let category = template.category {
                        Text(category.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let dept = template.department {
                        Text(dept.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    if let role = template.role, !role.isEmpty {
                        Text(role)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Button(action: { editingTemplate = template }) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: {
                templateToDelete = template
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Core Data

    private func loadTemplates() {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try context.fetch(request)
            templates = results.compactMap { mo -> ContactTemplate? in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }

                let categoryRaw = mo.value(forKey: "category") as? String
                let category = categoryRaw.flatMap { Contact.Category(rawValue: $0) }

                let deptRaw = mo.value(forKey: "department") as? String
                let department = deptRaw.flatMap { Contact.Department(rawValue: $0) }

                return ContactTemplate(
                    id: id,
                    name: name,
                    category: category,
                    department: department,
                    role: mo.value(forKey: "role") as? String,
                    ratePerDay: mo.value(forKey: "ratePerDay") as? Double,
                    rateUnit: mo.value(forKey: "rateUnit") as? String,
                    sortOrder: (mo.value(forKey: "sortOrder") as? Int16) ?? 0,
                    createdAt: (mo.value(forKey: "createdAt") as? Date) ?? Date()
                )
            }
        } catch {
            print("Failed to load templates: \(error)")
        }
    }

    private func saveTemplate(_ template: ContactTemplate) {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { return }
        let mo = NSManagedObject(entity: entity, insertInto: context)

        mo.setValue(template.id, forKey: "id")
        mo.setValue(template.name, forKey: "name")
        mo.setValue(template.category?.rawValue, forKey: "category")
        mo.setValue(template.department?.rawValue, forKey: "department")
        mo.setValue(template.role, forKey: "role")
        mo.setValue(template.ratePerDay, forKey: "ratePerDay")
        mo.setValue(template.rateUnit, forKey: "rateUnit")
        mo.setValue(Int16(templates.count), forKey: "sortOrder")
        mo.setValue(Date(), forKey: "createdAt")

        do {
            try context.save()
            templates.append(template)
        } catch {
            print("Failed to save template: \(error)")
        }
    }

    private func updateTemplate(_ template: ContactTemplate) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                mo.setValue(template.name, forKey: "name")
                mo.setValue(template.category?.rawValue, forKey: "category")
                mo.setValue(template.department?.rawValue, forKey: "department")
                mo.setValue(template.role, forKey: "role")
                mo.setValue(template.ratePerDay, forKey: "ratePerDay")
                mo.setValue(template.rateUnit, forKey: "rateUnit")
                try context.save()

                if let index = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[index] = template
                }
            }
        } catch {
            print("Failed to update template: \(error)")
        }
    }

    private func deleteTemplate(_ template: ContactTemplate) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                context.delete(mo)
                try context.save()
                templates.removeAll { $0.id == template.id }
            }
        } catch {
            print("Failed to delete template: \(error)")
        }
    }
}

// MARK: - Template Editor Sheet
struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: ContactTemplate?
    let onSave: (ContactTemplate) -> Void

    @State private var name: String = ""
    @State private var category: Contact.Category = .crew
    @State private var hasCategory: Bool = false
    @State private var department: Contact.Department = .production
    @State private var hasDepartment: Bool = false
    @State private var role: String = ""
    @State private var ratePerDay: String = ""
    @State private var rateUnit: String = "Day"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(template == nil ? "New Template" : "Edit Template")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color.primary.opacity(0.03))

            Divider()

            Form {
                TextField("Template Name", text: $name)

                Section("Pre-fill Settings") {
                    Toggle("Set Category", isOn: $hasCategory)
                    if hasCategory {
                        Picker("Category", selection: $category) {
                            ForEach(Contact.Category.allCases, id: \.self) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                    }

                    Toggle("Set Department", isOn: $hasDepartment)
                    if hasDepartment {
                        Picker("Department", selection: $department) {
                            ForEach(Contact.Department.allCases, id: \.self) { dept in
                                Text(dept.displayName).tag(dept)
                            }
                        }
                    }

                    TextField("Role", text: $role)

                    HStack {
                        TextField("Rate", text: $ratePerDay)
                            .frame(width: 100)
                        Picker("Per", selection: $rateUnit) {
                            Text("Day").tag("Day")
                            Text("Week").tag("Week")
                            Text("Hour").tag("Hour")
                            Text("Flat").tag("Flat")
                        }
                        .frame(width: 100)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 400)
        .onAppear {
            if let t = template {
                name = t.name
                if let cat = t.category {
                    hasCategory = true
                    category = cat
                }
                if let dept = t.department {
                    hasDepartment = true
                    department = dept
                }
                role = t.role ?? ""
                if let rate = t.ratePerDay {
                    ratePerDay = String(format: "%.2f", rate)
                }
                rateUnit = t.rateUnit ?? "Day"
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newTemplate = ContactTemplate(
            id: template?.id ?? UUID(),
            name: trimmedName,
            category: hasCategory ? category : nil,
            department: hasDepartment ? department : nil,
            role: role.isEmpty ? nil : role,
            ratePerDay: Double(ratePerDay),
            rateUnit: rateUnit,
            sortOrder: template?.sortOrder ?? 0,
            createdAt: template?.createdAt ?? Date()
        )

        onSave(newTemplate)
        dismiss()
    }
}

#elseif os(iOS)
struct TemplateManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var templates: [ContactTemplate] = []
    @State private var showingAddTemplate = false
    @State private var editingTemplate: ContactTemplate? = nil

    private let entityName = "ContactTemplateEntity"

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("No templates yet")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(templates) { template in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.system(size: 14, weight: .semibold))

                                HStack(spacing: 8) {
                                    if let category = template.category {
                                        Text(category.displayName)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    if let dept = template.department {
                                        Text(dept.displayName)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingTemplate = template
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTemplate = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadTemplates() }
            .sheet(isPresented: $showingAddTemplate) {
                TemplateEditorSheet(template: nil, onSave: { newTemplate in
                    saveTemplate(newTemplate)
                })
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorSheet(template: template, onSave: { updatedTemplate in
                    updateTemplate(updatedTemplate)
                })
            }
        }
    }

    // Same Core Data methods as macOS...
    private func loadTemplates() {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try context.fetch(request)
            templates = results.compactMap { mo -> ContactTemplate? in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }

                let categoryRaw = mo.value(forKey: "category") as? String
                let category = categoryRaw.flatMap { Contact.Category(rawValue: $0) }

                let deptRaw = mo.value(forKey: "department") as? String
                let department = deptRaw.flatMap { Contact.Department(rawValue: $0) }

                return ContactTemplate(
                    id: id,
                    name: name,
                    category: category,
                    department: department,
                    role: mo.value(forKey: "role") as? String,
                    ratePerDay: mo.value(forKey: "ratePerDay") as? Double,
                    rateUnit: mo.value(forKey: "rateUnit") as? String,
                    sortOrder: (mo.value(forKey: "sortOrder") as? Int16) ?? 0,
                    createdAt: (mo.value(forKey: "createdAt") as? Date) ?? Date()
                )
            }
        } catch {
            print("Failed to load templates: \(error)")
        }
    }

    private func saveTemplate(_ template: ContactTemplate) {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { return }
        let mo = NSManagedObject(entity: entity, insertInto: context)

        mo.setValue(template.id, forKey: "id")
        mo.setValue(template.name, forKey: "name")
        mo.setValue(template.category?.rawValue, forKey: "category")
        mo.setValue(template.department?.rawValue, forKey: "department")
        mo.setValue(template.role, forKey: "role")
        mo.setValue(template.ratePerDay, forKey: "ratePerDay")
        mo.setValue(template.rateUnit, forKey: "rateUnit")
        mo.setValue(Int16(templates.count), forKey: "sortOrder")
        mo.setValue(Date(), forKey: "createdAt")

        do {
            try context.save()
            templates.append(template)
        } catch {
            print("Failed to save template: \(error)")
        }
    }

    private func updateTemplate(_ template: ContactTemplate) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                mo.setValue(template.name, forKey: "name")
                mo.setValue(template.category?.rawValue, forKey: "category")
                mo.setValue(template.department?.rawValue, forKey: "department")
                mo.setValue(template.role, forKey: "role")
                mo.setValue(template.ratePerDay, forKey: "ratePerDay")
                mo.setValue(template.rateUnit, forKey: "rateUnit")
                try context.save()

                if let index = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[index] = template
                }
            }
        } catch {
            print("Failed to update template: \(error)")
        }
    }

    private func deleteTemplate(_ template: ContactTemplate) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let mo = try context.fetch(request).first {
                context.delete(mo)
                try context.save()
                templates.removeAll { $0.id == template.id }
            }
        } catch {
            print("Failed to delete template: \(error)")
        }
    }
}

// MARK: - Template Editor Sheet (iOS)
struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: ContactTemplate?
    let onSave: (ContactTemplate) -> Void

    @State private var name: String = ""
    @State private var category: Contact.Category = .crew
    @State private var hasCategory: Bool = false
    @State private var department: Contact.Department = .production
    @State private var hasDepartment: Bool = false
    @State private var role: String = ""
    @State private var ratePerDay: String = ""
    @State private var rateUnit: String = "Day"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template Name", text: $name)
                }

                Section("Pre-fill Settings") {
                    Toggle("Set Category", isOn: $hasCategory)
                    if hasCategory {
                        Picker("Category", selection: $category) {
                            ForEach(Contact.Category.allCases, id: \.self) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                    }

                    Toggle("Set Department", isOn: $hasDepartment)
                    if hasDepartment {
                        Picker("Department", selection: $department) {
                            ForEach(Contact.Department.allCases, id: \.self) { dept in
                                Text(dept.displayName).tag(dept)
                            }
                        }
                    }

                    TextField("Role", text: $role)
                }

                Section("Rate") {
                    TextField("Rate Amount", text: $ratePerDay)
                        .keyboardType(.decimalPad)

                    Picker("Per", selection: $rateUnit) {
                        Text("Day").tag("Day")
                        Text("Week").tag("Week")
                        Text("Hour").tag("Hour")
                        Text("Flat").tag("Flat")
                    }
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let t = template {
                    name = t.name
                    if let cat = t.category {
                        hasCategory = true
                        category = cat
                    }
                    if let dept = t.department {
                        hasDepartment = true
                        department = dept
                    }
                    role = t.role ?? ""
                    if let rate = t.ratePerDay {
                        ratePerDay = String(format: "%.2f", rate)
                    }
                    rateUnit = t.rateUnit ?? "Day"
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newTemplate = ContactTemplate(
            id: template?.id ?? UUID(),
            name: trimmedName,
            category: hasCategory ? category : nil,
            department: hasDepartment ? department : nil,
            role: role.isEmpty ? nil : role,
            ratePerDay: Double(ratePerDay),
            rateUnit: rateUnit,
            sortOrder: template?.sortOrder ?? 0,
            createdAt: template?.createdAt ?? Date()
        )

        onSave(newTemplate)
        dismiss()
    }
}
#endif

// MARK: - Template Picker (for use when adding new contact)
struct TemplatePickerMenu: View {
    @Environment(\.managedObjectContext) private var context
    @State private var templates: [ContactTemplate] = []
    let onSelect: (ContactTemplate) -> Void

    var body: some View {
        Menu {
            if templates.isEmpty {
                Text("No templates available")
            } else {
                ForEach(templates) { template in
                    Button(action: { onSelect(template) }) {
                        VStack(alignment: .leading) {
                            Text(template.name)
                            if let cat = template.category {
                                Text(cat.displayName)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        } label: {
            Label("From Template", systemImage: "doc.on.doc")
        }
        .onAppear { loadTemplates() }
    }

    private func loadTemplates() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactTemplateEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try context.fetch(request)
            templates = results.compactMap { mo -> ContactTemplate? in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }

                let categoryRaw = mo.value(forKey: "category") as? String
                let category = categoryRaw.flatMap { Contact.Category(rawValue: $0) }

                let deptRaw = mo.value(forKey: "department") as? String
                let department = deptRaw.flatMap { Contact.Department(rawValue: $0) }

                return ContactTemplate(
                    id: id,
                    name: name,
                    category: category,
                    department: department,
                    role: mo.value(forKey: "role") as? String,
                    ratePerDay: mo.value(forKey: "ratePerDay") as? Double,
                    rateUnit: mo.value(forKey: "rateUnit") as? String,
                    sortOrder: (mo.value(forKey: "sortOrder") as? Int16) ?? 0
                )
            }
        } catch {
            print("Failed to load templates: \(error)")
        }
    }
}
