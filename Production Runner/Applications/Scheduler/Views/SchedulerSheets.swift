//
//  SchedulerSheets.swift
//  Production Runner
//
//  Sheet views for the Scheduler module.
//  Extracted from SchedulerView.swift for better organization.
//

import SwiftUI
import CoreData

#if os(macOS)
import AppKit

// MARK: - Strip Color Customizer

struct StripColorCustomizer: View {
    @Binding var colorIntDay: String
    @Binding var colorExtDay: String
    @Binding var colorIntNight: String
    @Binding var colorExtNight: String
    @Binding var colorIntMorning: String
    @Binding var colorExtMorning: String
    @Binding var colorIntDawn: String
    @Binding var colorExtDawn: String
    @Binding var colorIntDusk: String
    @Binding var colorExtDusk: String
    @Binding var colorIntEvening: String
    @Binding var colorExtEvening: String

    @Environment(\.dismiss) private var dismiss

    @State private var tempIntDay: Color = Color(red: 1.0, green: 1.0, blue: 1.0)
    @State private var tempExtDay: Color = Color(red: 1.0, green: 0.92, blue: 0.23)
    @State private var tempIntNight: Color = Color(red: 0.53, green: 0.81, blue: 0.98)
    @State private var tempExtNight: Color = Color(red: 0.60, green: 0.98, blue: 0.60)
    @State private var tempIntMorning: Color = Color(red: 1.0, green: 0.95, blue: 0.80)
    @State private var tempExtMorning: Color = Color(red: 1.0, green: 0.85, blue: 0.50)
    @State private var tempIntDawn: Color = Color(red: 0.95, green: 0.85, blue: 0.95)
    @State private var tempExtDawn: Color = Color(red: 0.98, green: 0.75, blue: 0.85)
    @State private var tempIntDusk: Color = Color(red: 0.85, green: 0.75, blue: 0.95)
    @State private var tempExtDusk: Color = Color(red: 0.95, green: 0.65, blue: 0.75)
    @State private var tempIntEvening: Color = Color(red: 0.75, green: 0.85, blue: 0.95)
    @State private var tempExtEvening: Color = Color(red: 0.65, green: 0.75, blue: 0.95)

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Customize Strip Colors")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            Divider()

            // Color Pickers in ScrollView
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Times
                    Text("Basic Times")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    colorPickerRow(
                        title: "INT. DAY",
                        subtitle: "Interior scenes during daytime",
                        icon: "house.fill",
                        color: $tempIntDay
                    )

                    colorPickerRow(
                        title: "EXT. DAY",
                        subtitle: "Exterior scenes during daytime",
                        icon: "sun.max.fill",
                        color: $tempExtDay
                    )

                    colorPickerRow(
                        title: "INT. NIGHT",
                        subtitle: "Interior scenes during nighttime",
                        icon: "moon.fill",
                        color: $tempIntNight
                    )

                    colorPickerRow(
                        title: "EXT. NIGHT",
                        subtitle: "Exterior scenes during nighttime",
                        icon: "moon.stars.fill",
                        color: $tempExtNight
                    )

                    Divider()
                        .padding(.vertical, 8)

                    // Specific Times
                    Text("Specific Times")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    colorPickerRow(
                        title: "INT. MORNING",
                        subtitle: "Interior scenes in the morning",
                        icon: "sunrise.fill",
                        color: $tempIntMorning
                    )

                    colorPickerRow(
                        title: "EXT. MORNING",
                        subtitle: "Exterior scenes in the morning",
                        icon: "sunrise.fill",
                        color: $tempExtMorning
                    )

                    colorPickerRow(
                        title: "INT. DAWN",
                        subtitle: "Interior scenes at dawn",
                        icon: "sun.horizon.fill",
                        color: $tempIntDawn
                    )

                    colorPickerRow(
                        title: "EXT. DAWN",
                        subtitle: "Exterior scenes at dawn",
                        icon: "sun.horizon.fill",
                        color: $tempExtDawn
                    )

                    colorPickerRow(
                        title: "INT. DUSK",
                        subtitle: "Interior scenes at dusk",
                        icon: "sun.horizon.fill",
                        color: $tempIntDusk
                    )

                    colorPickerRow(
                        title: "EXT. DUSK",
                        subtitle: "Exterior scenes at dusk",
                        icon: "sun.horizon.fill",
                        color: $tempExtDusk
                    )

                    colorPickerRow(
                        title: "INT. EVENING",
                        subtitle: "Interior scenes in the evening",
                        icon: "sunset.fill",
                        color: $tempIntEvening
                    )

                    colorPickerRow(
                        title: "EXT. EVENING",
                        subtitle: "Exterior scenes in the evening",
                        icon: "sunset.fill",
                        color: $tempExtEvening
                    )
                }
                .padding(.horizontal, 24)
            }

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    applyChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 550, height: 680)
        .onAppear {
            loadCurrentColors()
        }
    }

    private func colorPickerRow(title: String, subtitle: String, icon: String, color: Binding<Color>) -> some View {
        HStack(spacing: 16) {
            // Icon and Info
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Color Picker
            ColorPicker("", selection: color)
                .labelsHidden()
                .frame(width: 80)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func loadCurrentColors() {
        tempIntDay = colorFromString(colorIntDay)
        tempExtDay = colorFromString(colorExtDay)
        tempIntNight = colorFromString(colorIntNight)
        tempExtNight = colorFromString(colorExtNight)
        tempIntMorning = colorFromString(colorIntMorning)
        tempExtMorning = colorFromString(colorExtMorning)
        tempIntDawn = colorFromString(colorIntDawn)
        tempExtDawn = colorFromString(colorExtDawn)
        tempIntDusk = colorFromString(colorIntDusk)
        tempExtDusk = colorFromString(colorExtDusk)
        tempIntEvening = colorFromString(colorIntEvening)
        tempExtEvening = colorFromString(colorExtEvening)
    }

    private func applyChanges() {
        colorIntDay = colorToString(tempIntDay)
        colorExtDay = colorToString(tempExtDay)
        colorIntNight = colorToString(tempIntNight)
        colorExtNight = colorToString(tempExtNight)
        colorIntMorning = colorToString(tempIntMorning)
        colorExtMorning = colorToString(tempExtMorning)
        colorIntDawn = colorToString(tempIntDawn)
        colorExtDawn = colorToString(tempExtDawn)
        colorIntDusk = colorToString(tempIntDusk)
        colorExtDusk = colorToString(tempExtDusk)
        colorIntEvening = colorToString(tempIntEvening)
        colorExtEvening = colorToString(tempExtEvening)
    }

    private func resetToDefaults() {
        tempIntDay = Color(red: 1.0, green: 1.0, blue: 1.0)
        tempExtDay = Color(red: 1.0, green: 0.92, blue: 0.23)
        tempIntNight = Color(red: 0.53, green: 0.81, blue: 0.98)
        tempExtNight = Color(red: 0.60, green: 0.98, blue: 0.60)
        tempIntMorning = Color(red: 1.0, green: 0.95, blue: 0.80)
        tempExtMorning = Color(red: 1.0, green: 0.85, blue: 0.50)
        tempIntDawn = Color(red: 0.95, green: 0.85, blue: 0.95)
        tempExtDawn = Color(red: 0.98, green: 0.75, blue: 0.85)
        tempIntDusk = Color(red: 0.85, green: 0.75, blue: 0.95)
        tempExtDusk = Color(red: 0.95, green: 0.65, blue: 0.75)
        tempIntEvening = Color(red: 0.75, green: 0.85, blue: 0.95)
        tempExtEvening = Color(red: 0.65, green: 0.75, blue: 0.95)
    }

    private func colorFromString(_ str: String) -> Color {
        let components = str.split(separator: ",").compactMap { Double($0) }
        guard components.count == 3 else {
            return Color(red: 0.98, green: 0.97, blue: 0.95)
        }
        return Color(red: components[0], green: components[1], blue: components[2])
    }

    private func colorToString(_ color: Color) -> String {
        if let nsColor = NSColor(color).usingColorSpace(.deviceRGB) {
            return "\(nsColor.redComponent),\(nsColor.greenComponent),\(nsColor.blueComponent)"
        }
        return "1.0,1.0,1.0"
    }
}

// MARK: - Set Dates Sheet

struct SetDatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Binding var productionStartDate: Date
    var project: NSManagedObject

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Production Dates")
                        .font(.system(size: 20, weight: .bold))
                    Text("Configure the start date for your production schedule")
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

            Divider()

            // Date Picker
            VStack(alignment: .leading, spacing: 12) {
                Text("PRODUCTION START DATE")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)

                DatePicker(
                    "",
                    selection: $productionStartDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }

            Spacer()

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    project.setValue(productionStartDate, forKey: "startDate")
                    moc.pr_save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400, height: 500)
    }
}

// MARK: - Schedule Version Dialogs

struct NewScheduleVersionDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void
    @State private var versionName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(.green.gradient)

                        Text("Create New Schedule Version")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Enter a name for your new schedule version")
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

                        TextField("e.g., Schedule v2.0", text: $versionName)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal, 40)

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            if !versionName.isEmpty {
                                onCreate(versionName)
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
                                    .fill(versionName.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(Color.green.gradient))
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
                                        .fill(Color(nsColor: .tertiarySystemBackground))
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
            versionName = "Schedule v1.0"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

struct RenameScheduleVersionDialog: View {
    let version: ScheduleVersion
    @Binding var isPresented: Bool
    let onRename: (ScheduleVersion, String) -> Void
    @State private var versionName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Version Name", text: $versionName)
                } header: {
                    Text("Rename Schedule Version")
                } footer: {
                    Text("Enter a new name for this schedule version.")
                }
            }
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !versionName.isEmpty {
                            onRename(version, versionName)
                            isPresented = false
                        }
                    }
                    .disabled(versionName.isEmpty || versionName == version.name)
                }
            }
        }
        .onAppear {
            versionName = version.name
        }
    }
}

// MARK: - Add Cast Sheet

struct SchedulerAddCastSheet: View {
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Cast Member")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            Form {
                Section("Contact Info") {
                    TextField("Name", text: $name)
                    TextField("Role / Character", text: $role)
                    TextField("Phone", text: $phone)
                    TextField("Email", text: $email)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Add Cast") {
                    addCastMember()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(name.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }

    private func addCastMember() {
        let entity = NSEntityDescription.entity(forEntityName: "ContactEntity", in: context)!
        let contact = NSManagedObject(entity: entity, insertInto: context)
        contact.setValue(UUID(), forKey: "id")
        contact.setValue(name, forKey: "name")
        contact.setValue(role, forKey: "role")
        contact.setValue(phone, forKey: "phone")
        contact.setValue(email, forKey: "email")
        contact.setValue("Cast", forKey: "category")
        contact.setValue(Date(), forKey: "createdAt")
        context.pr_save()
    }
}

// MARK: - Add Crew Sheet

struct SchedulerAddCrewSheet: View {
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var department = "Camera"
    @State private var role = ""
    @State private var phone = ""
    @State private var email = ""

    private let departments = [
        "Camera", "Grip", "Electric", "Sound", "Art", "Wardrobe",
        "Makeup", "Hair", "Props", "Set Dec", "Transportation",
        "Catering", "Production", "Post", "VFX", "Other"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Crew Member")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            Form {
                Section("Contact Info") {
                    TextField("Name", text: $name)
                    Picker("Department", selection: $department) {
                        ForEach(departments, id: \.self) { dept in
                            Text(dept).tag(dept)
                        }
                    }
                    TextField("Position / Title", text: $role)
                    TextField("Phone", text: $phone)
                    TextField("Email", text: $email)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Add Crew") {
                    addCrewMember()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(name.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 400)
    }

    private func addCrewMember() {
        let entity = NSEntityDescription.entity(forEntityName: "ContactEntity", in: context)!
        let contact = NSManagedObject(entity: entity, insertInto: context)
        contact.setValue(UUID(), forKey: "id")
        contact.setValue(name, forKey: "name")
        contact.setValue(role, forKey: "role")
        contact.setValue(department, forKey: "department")
        contact.setValue(phone, forKey: "phone")
        contact.setValue(email, forKey: "email")
        contact.setValue("Crew", forKey: "category")
        contact.setValue(Date(), forKey: "createdAt")
        context.pr_save()
    }
}

// MARK: - Location Sync Row

struct LocationSyncRow: View {
    let location: LocationItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                        .frame(width: 40, height: 40)

                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .green : .secondary)
                }

                // Location info
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if !location.address.isEmpty {
                        Text(location.address)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if !location.locationInFilm.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(.system(size: 10))
                            Text(location.locationInFilm)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.green.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.green.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wrapping HStack Layout

struct WrappingHStack: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(in: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(in maxWidth: CGFloat, subviews: Subviews) -> (positions: [CGPoint], width: CGFloat, height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, maxX, y + rowHeight)
    }
}

// MARK: - Add Unit Sheet

struct SchedulerAddUnitSheet: View {
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var unitName = ""
    @State private var unitType = "Main Unit"
    @State private var notes = ""

    private let unitTypes = ["Main Unit", "2nd Unit", "Splinter Unit", "Insert Unit", "B-Camera Unit", "Aerial Unit", "Underwater Unit", "VFX Unit"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Production Unit")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            Form {
                Section("Unit Details") {
                    TextField("Unit Name", text: $unitName)
                    Picker("Unit Type", selection: $unitType) {
                        ForEach(unitTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Add Unit") {
                    addUnit()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(unitName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 320)
        .onAppear {
            if unitName.isEmpty {
                unitName = unitType
            }
        }
    }

    private func addUnit() {
        // Check if UnitEntity exists in the model
        guard let entity = NSEntityDescription.entity(forEntityName: "UnitEntity", in: context) else {
            print("[SchedulerAddUnitSheet] UnitEntity not found in Core Data model")
            return
        }
        let unit = NSManagedObject(entity: entity, insertInto: context)
        unit.setValue(UUID(), forKey: "id")
        unit.setValue(unitName, forKey: "name")
        unit.setValue(unitType, forKey: "type")
        unit.setValue(notes, forKey: "notes")
        unit.setValue(Date(), forKey: "createdAt")
        context.pr_save()
    }
}

#endif
