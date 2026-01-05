//
//  DepartmentManager.swift
//  Production Runner
//
//  Created by Brandon on 11/23/25.
//

import SwiftUI

// MARK: - Production Unit Model
struct ProductionUnit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var memberIDs: [UUID]
    var color: Color
    var createdAt: Date

    init(id: UUID = UUID(), name: String, description: String = "", memberIDs: [UUID] = [], color: Color = .orange, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.memberIDs = memberIDs
        self.color = color
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, memberIDs, colorHex, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        memberIDs = try container.decodeIfPresent([UUID].self, forKey: .memberIDs) ?? []
        let colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#FF9500"
        color = Color.fromHex(colorHex)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(memberIDs, forKey: .memberIDs)
        try container.encode(color.toHex(), forKey: .colorHex)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Models
struct ProductionDepartment: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: Color
    var icon: String

    init(id: UUID = UUID(), name: String, color: Color = .blue, icon: String = "briefcase.fill") {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        color = Color.fromHex(colorHex)
        icon = try container.decode(String.self, forKey: .icon)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color.toHex(), forKey: .colorHex)
        try container.encode(icon, forKey: .icon)
    }

    // Default departments
    static var defaults: [ProductionDepartment] {
        [
            ProductionDepartment(name: "Production", color: .blue, icon: "film.fill"),
            ProductionDepartment(name: "Art", color: .purple, icon: "paintbrush.fill"),
            ProductionDepartment(name: "Grip and Electric", color: .orange, icon: "bolt.fill"),
            ProductionDepartment(name: "Wardrobe", color: .pink, icon: "tshirt.fill"),
            ProductionDepartment(name: "Camera", color: .green, icon: "camera.fill"),
            ProductionDepartment(name: "Sound", color: .cyan, icon: "waveform")
        ]
    }
}

struct DepartmentManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("production_departments") private var departmentsData: Data = Data()
    @State private var departments: [ProductionDepartment] = []

    @State private var newDepartmentName = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String = "briefcase.fill"
    @State private var showingIconPicker = false

    private let availableIcons = [
        "film.fill", "camera.fill", "video.fill", "music.note",
        "paintbrush.fill", "photo.fill", "waveform", "mic.fill",
        "tshirt.fill", "bolt.fill", "lightbulb.fill", "wrench.fill",
        "hammer.fill", "scissors", "briefcase.fill", "folder.fill",
        "star.fill", "heart.fill", "flag.fill", "tag.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    createDepartmentCard
                    existingDepartmentsSection
                }
                .padding(24)
            }

            Divider()
            footerSection
        }
        .frame(width: 580, height: 660)
        .onAppear {
            loadDepartments()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Department Management")
                    .font(.system(size: 22, weight: .bold))
                Text("Create and manage production departments")
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

    private var createDepartmentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Department")
                .font(.system(size: 17, weight: .semibold))

            VStack(spacing: 14) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Department Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("e.g., Production, Camera, Sound", text: $newDepartmentName)
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

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
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

                createButton
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

    private var createButton: some View {
        Button(action: createDepartment) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                Text("Create Department")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(newDepartmentName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
            )
            .foregroundStyle(newDepartmentName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color.white)
        }
        .buttonStyle(.plain)
        .disabled(newDepartmentName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private var existingDepartmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Existing Departments")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(departments.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if departments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No departments created yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Load Defaults") {
                        loadDefaults()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(departments) { dept in
                        departmentRow(dept)
                    }
                }
            }
        }
    }

    private func departmentRow(_ dept: ProductionDepartment) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(dept.color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: dept.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(dept.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(dept.name)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 4) {
                    Circle()
                        .fill(dept.color)
                        .frame(width: 6, height: 6)
                    Text(dept.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: {
                deleteDepartment(dept)
            }) {
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
            .help("Delete department")
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
            Button("Load Defaults") {
                loadDefaults()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.accentColor)

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

    private func createDepartment() {
        let name = newDepartmentName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let dept = ProductionDepartment(name: name, color: selectedColor, icon: selectedIcon)
        departments.append(dept)
        saveDepartments()

        newDepartmentName = ""
        selectedColor = .blue
        selectedIcon = "briefcase.fill"
        showingIconPicker = false
    }

    private func deleteDepartment(_ dept: ProductionDepartment) {
        departments.removeAll { $0.id == dept.id }
        saveDepartments()
    }

    private func loadDefaults() {
        departments = ProductionDepartment.defaults
        saveDepartments()
    }

    private func loadDepartments() {
        guard !departmentsData.isEmpty else {
            // Load defaults on first run
            departments = ProductionDepartment.defaults
            saveDepartments()
            return
        }
        if let decoded = try? JSONDecoder().decode([ProductionDepartment].self, from: departmentsData) {
            departments = decoded
        }
    }

    private func saveDepartments() {
        if let encoded = try? JSONEncoder().encode(departments) {
            departmentsData = encoded
        }
    }
}

// MARK: - Unit Manager Sheet
struct UnitManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("production_units") private var unitsData: Data = Data()
    @State private var units: [ProductionUnit] = []

    let contacts: [Contact]

    @State private var newUnitName = ""
    @State private var newUnitDescription = ""
    @State private var selectedColor: Color = .orange
    @State private var selectedMemberIDs: Set<UUID> = []
    @State private var showingMemberPicker = false
    @State private var editingUnit: ProductionUnit? = nil
    @State private var searchText = ""

    private var crewContacts: [Contact] {
        contacts.filter { $0.category == .crew }
    }

    private var filteredCrewContacts: [Contact] {
        if searchText.isEmpty {
            return crewContacts
        }
        return crewContacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    createUnitCard
                    existingUnitsSection
                }
                .padding(24)
            }

            Divider()
            footerSection
        }
        .frame(width: 620, height: 700)
        .onAppear {
            loadUnits()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Unit Management")
                    .font(.system(size: 22, weight: .bold))
                Text("Create and manage production units (groups of crew)")
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

    private var createUnitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingUnit == nil ? "Create Unit" : "Edit Unit")
                .font(.system(size: 17, weight: .semibold))

            VStack(spacing: 14) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unit Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("e.g., Main Unit, Second Unit, Splinter Unit", text: $newUnitName)
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

                // Description field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Optional description", text: $newUnitDescription)
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

                    // Member count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Members")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Button(action: { showingMemberPicker.toggle() }) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(selectedColor)
                                Text("\(selectedMemberIDs.count) selected")
                                    .font(.system(size: 13))
                                Spacer()
                                Image(systemName: showingMemberPicker ? "chevron.up" : "chevron.down")
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

                // Member picker
                if showingMemberPicker {
                    memberPickerSection
                }

                // Selected members preview
                if !selectedMemberIDs.isEmpty {
                    selectedMembersPreview
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

    private var memberPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Select Crew Members")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !selectedMemberIDs.isEmpty {
                    Button("Clear All") {
                        selectedMemberIDs.removeAll()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
            }

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("Search crew...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )

            if crewContacts.isEmpty {
                Text("No crew contacts available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredCrewContacts, id: \.id) { contact in
                            memberSelectionRow(contact)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
    }

    private func memberSelectionRow(_ contact: Contact) -> some View {
        let isSelected = selectedMemberIDs.contains(contact.id)
        return Button(action: {
            if isSelected {
                selectedMemberIDs.remove(contact.id)
            } else {
                selectedMemberIDs.insert(contact.id)
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? selectedColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(contact.role)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? selectedColor.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedMembersPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Members")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(selectedMemberIDs), id: \.self) { memberID in
                        if let contact = crewContacts.first(where: { $0.id == memberID }) {
                            HStack(spacing: 4) {
                                Text(contact.name)
                                    .font(.system(size: 11, weight: .medium))
                                Button(action: {
                                    selectedMemberIDs.remove(memberID)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selectedColor.opacity(0.12))
                            )
                            .foregroundStyle(selectedColor)
                        }
                    }
                }
            }
        }
    }

    private var createOrUpdateButton: some View {
        HStack(spacing: 12) {
            if editingUnit != nil {
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

            Button(action: editingUnit == nil ? createUnit : updateUnit) {
                HStack(spacing: 8) {
                    Image(systemName: editingUnit == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text(editingUnit == nil ? "Create Unit" : "Update Unit")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(newUnitName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.2) : selectedColor)
                )
                .foregroundStyle(newUnitName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color.white)
            }
            .buttonStyle(.plain)
            .disabled(newUnitName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var existingUnitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Existing Units")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(units.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if units.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No units created yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Units help you organize crew members into groups")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(units) { unit in
                        unitRow(unit)
                    }
                }
            }
        }
    }

    private func unitRow(_ unit: ProductionUnit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(unit.color.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(unit.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(unit.name)
                        .font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text("\(unit.memberIDs.count) members")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)

                        if !unit.description.isEmpty {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(unit.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { startEditing(unit) }) {
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
                    .help("Edit unit")

                    Button(action: { deleteUnit(unit) }) {
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
                    .help("Delete unit")
                }
            }

            // Show member names if any
            if !unit.memberIDs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(unit.memberIDs, id: \.self) { memberID in
                            if let contact = crewContacts.first(where: { $0.id == memberID }) {
                                Text(contact.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(unit.color.opacity(0.1))
                                    )
                                    .foregroundStyle(unit.color)
                            }
                        }
                    }
                }
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

    private func createUnit() {
        let name = newUnitName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let unit = ProductionUnit(
            name: name,
            description: newUnitDescription.trimmingCharacters(in: .whitespaces),
            memberIDs: Array(selectedMemberIDs),
            color: selectedColor
        )
        units.append(unit)
        saveUnits()
        resetForm()
    }

    private func updateUnit() {
        guard let editing = editingUnit else { return }
        let name = newUnitName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        if let index = units.firstIndex(where: { $0.id == editing.id }) {
            units[index].name = name
            units[index].description = newUnitDescription.trimmingCharacters(in: .whitespaces)
            units[index].memberIDs = Array(selectedMemberIDs)
            units[index].color = selectedColor
            saveUnits()
        }
        resetForm()
    }

    private func startEditing(_ unit: ProductionUnit) {
        editingUnit = unit
        newUnitName = unit.name
        newUnitDescription = unit.description
        selectedColor = unit.color
        selectedMemberIDs = Set(unit.memberIDs)
        showingMemberPicker = false
    }

    private func cancelEdit() {
        resetForm()
    }

    private func resetForm() {
        editingUnit = nil
        newUnitName = ""
        newUnitDescription = ""
        selectedColor = .orange
        selectedMemberIDs = []
        showingMemberPicker = false
        searchText = ""
    }

    private func deleteUnit(_ unit: ProductionUnit) {
        units.removeAll { $0.id == unit.id }
        saveUnits()
    }

    private func loadUnits() {
        guard !unitsData.isEmpty else { return }
        if let decoded = try? JSONDecoder().decode([ProductionUnit].self, from: unitsData) {
            units = decoded
        }
    }

    private func saveUnits() {
        if let encoded = try? JSONEncoder().encode(units) {
            unitsData = encoded
        }
    }
}
