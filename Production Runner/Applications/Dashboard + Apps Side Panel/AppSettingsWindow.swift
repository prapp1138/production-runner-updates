// MARK: - Platform Imports
#if os(macOS)
import AppKit
#endif
import SwiftUI
import CoreData

// MARK: - Global Typeface Options (10 macOS style typefaces)
private enum GlobalTypeface: String, CaseIterable, Identifiable {
    case sfPro = "SF Pro"
    case helveticaNeue = "Helvetica Neue"
    case avenir = "Avenir"
    case futura = "Futura"
    case gill = "Gill Sans"
    case palatino = "Palatino"
    case baskerville = "Baskerville"
    case georgia = "Georgia"
    case courier = "Courier"
    case menlo = "Menlo"
    
    var id: String { rawValue }
    
    var systemName: String {
        switch self {
        case .sfPro: return ".AppleSystemUIFont"
        case .helveticaNeue: return "Helvetica Neue"
        case .avenir: return "Avenir Next"
        case .futura: return "Futura"
        case .gill: return "Gill Sans"
        case .palatino: return "Palatino"
        case .baskerville: return "Baskerville"
        case .georgia: return "Georgia"
        case .courier: return "Courier"
        case .menlo: return "Menlo"
        }
    }
    
    var fontDesign: Font.Design {
        switch self {
        case .courier, .menlo:
            return .monospaced
        case .georgia, .baskerville, .palatino:
            return .serif
        default:
            return .default
        }
    }
}

struct AppSettingsWindow: View {
    let project: NSManagedObject
    
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    
    private func hasAttr(_ key: String) -> Bool { project.entity.attributesByName[key] != nil }
    
    @State private var editName: String = ""
    @State private var isEditingName: Bool = false
    @State private var editProductionCompany: String = ""
    @State private var editStatus: ProjectStatus = .development
    
    // Global Typeface Setting
    @AppStorage("global_typeface") private var globalTypeface: String = GlobalTypeface.sfPro.rawValue
    @AppStorage("global_typeface_size") private var globalTypefaceSize: Double = 64

    // Header Color Settings
    @AppStorage("header_preset") private var headerPreset: String = "Aurora"
    @AppStorage("header_hue") private var headerHue: Double = 0.58
    @AppStorage("header_intensity") private var headerIntensity: Double = 0.18

    private var projectIDString: String {
        project.objectID.uriRepresentation().absoluteString
    }
    
    private var selectedTypeface: GlobalTypeface {
        GlobalTypeface(rawValue: globalTypeface) ?? .sfPro
    }
    
    private func loadEdits() {
        editName = hasAttr("name") ? ((project.value(forKey: "name") as? String) ?? "") : ""
        editProductionCompany = hasAttr("productionCompany") ? ((project.value(forKey: "productionCompany") as? String) ?? "") : ""
        if hasAttr("status") {
            let raw = (project.value(forKey: "status") as? String) ?? ProjectStatus.development.rawValue
            editStatus = ProjectStatus(rawValue: raw) ?? .development
        } else {
            editStatus = .development
        }
    }
    
    private func touch(_ object: NSManagedObject) {
        if object.entity.attributesByName["updatedAt"] != nil {
            object.setValue(Date(), forKey: "updatedAt")
        }
    }
    
    private func saveEdits() {
        if hasAttr("name") {
            let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
            project.setValue(trimmed.isEmpty ? "Untitled" : trimmed, forKey: "name")
        }
        if hasAttr("productionCompany") { project.setValue(editProductionCompany.isEmpty ? nil : editProductionCompany, forKey: "productionCompany") }
        if hasAttr("status") { project.setValue(editStatus.rawValue, forKey: "status") }
        
        // Save global typeface to per-project as well for backwards compatibility
        UserDefaults.standard.set(selectedTypeface.systemName, forKey: "pr.font.family.\(projectIDString)")
        UserDefaults.standard.set(globalTypefaceSize, forKey: "pr.font.size.\(projectIDString)")
        
        touch(project)
        try? moc.save()

        // Post notification that fonts changed
        NotificationCenter.default.post(name: Notification.Name("GlobalFontDidChange"), object: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Minimalist Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                    Text("Configure your project")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help(Tooltips.Settings.closeSettings)
            }
            .padding(24)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // Project Title - Simplified inline editing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Project Title")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        HStack(spacing: 12) {
                            if isEditingName {
                                TextField("Project Name", text: $editName)
                                    .font(.system(size: 24, weight: .semibold))
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.accentColor.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor, lineWidth: 2)
                                    )
                                    .onSubmit {
                                        withAnimation {
                                            isEditingName = false
                                        }
                                    }
                                
                                Button {
                                    withAnimation {
                                        isEditingName = false
                                    }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                .help(Tooltips.Settings.confirmProjectName)
                            } else {
                                Text(editName.isEmpty ? "Untitled Project" : editName)
                                    .font(.system(size: 24, weight: .semibold))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.primary.opacity(0.03))
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation {
                                            isEditingName = true
                                        }
                                    }
                                
                                Button {
                                    withAnimation {
                                        isEditingName = true
                                    }
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(Tooltips.Settings.editProjectName)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Basic Settings
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Basic Info")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        VStack(spacing: 16) {
                            MinimalField(label: "Production Company", value: $editProductionCompany)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Project Status")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $editStatus) {
                                    ForEach(ProjectStatus.allCases) { s in
                                        Text(s.rawValue).tag(s)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Global Typeface
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Typography")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        VStack(spacing: 16) {
                            // Typeface Preview
                            Text(editName.isEmpty ? "Project Title" : editName)
                                .font(.system(size: CGFloat(globalTypefaceSize), weight: .semibold, design: selectedTypeface.fontDesign))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.primary.opacity(0.03))
                                )
                            
                            // Typeface Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Font Family")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                
                                Picker("Font Family", selection: $globalTypeface) {
                                    ForEach(GlobalTypeface.allCases) { typeface in
                                        Text(typeface.rawValue)
                                            .font(.system(size: 13, design: typeface.fontDesign))
                                            .tag(typeface.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                                .help(Tooltips.Settings.fontFamily)
                                .onChange(of: globalTypeface) { _ in
                                    // Immediately save and notify on change
                                    UserDefaults.standard.set(selectedTypeface.systemName, forKey: "pr.font.family.\(projectIDString)")
                                    NotificationCenter.default.post(name: Notification.Name("GlobalFontDidChange"), object: nil)
                                }
                            }
                            
                            // Font Size Slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Font Size")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(globalTypefaceSize)) pt")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .monospacedDigit()
                                }
                                
                                Slider(value: $globalTypefaceSize, in: 32...96, step: 2)
                                    .tint(.accentColor)
                                    .help(Tooltips.Settings.fontSize)
                                    .onChange(of: globalTypefaceSize) { _ in
                                        // Immediately save and notify on change
                                        UserDefaults.standard.set(globalTypefaceSize, forKey: "pr.font.size.\(projectIDString)")
                                        NotificationCenter.default.post(name: Notification.Name("GlobalFontDidChange"), object: nil)
                                    }
                            }
                            
                            Text("Note: Font changes apply to dashboard project titles")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }

                    Divider()

                    // Header Color Settings
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Header Colors")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        VStack(spacing: 16) {
                            // Color Preset Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Color Preset")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)

                                Picker("Color Preset", selection: $headerPreset) {
                                    Text("Aurora").tag("Aurora")
                                    Text("Sunset").tag("Sunset")
                                    Text("Ocean").tag("Ocean")
                                    Text("Forest").tag("Forest")
                                    Text("Midnight").tag("Midnight")
                                    Text("Custom").tag("Custom")
                                }
                                .pickerStyle(.segmented)
                                .help(Tooltips.Settings.colorPreset)
                            }

                            // Custom Color Controls (only show when Custom is selected)
                            if headerPreset == "Custom" {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Custom Hue")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(headerHue * 360))°")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .monospacedDigit()
                                    }

                                    Slider(value: $headerHue, in: 0...1)
                                        .tint(.accentColor)
                                        .help(Tooltips.Settings.customHue)
                                }
                            }

                            // Intensity Slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Intensity")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(headerIntensity * 100))%")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .monospacedDigit()
                                }

                                Slider(value: $headerIntensity, in: 0.05...0.4)
                                    .tint(.accentColor)
                                    .help(Tooltips.Settings.colorIntensity)
                            }

                            // Preview
                            PreviewGradient(preset: headerPreset, hue: headerHue, intensity: headerIntensity)

                            Text("Note: Header colors apply to the dashboard background gradient")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }

                    Divider()

                    // Roles Management
                    RolesManagementSection()

                }
                .padding(24)
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .help(Tooltips.Settings.cancelChanges)
                
                Button {
                    saveEdits()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Save Changes")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    #if os(macOS)
                    .foregroundStyle(Color(NSColor.controlTextColor))
                    #else
                    .foregroundStyle(.white)
                    #endif
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .help(Tooltips.Settings.saveChanges)
            }
            .padding(20)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 560, height: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadEdits()
        }
    }
}

// MARK: - Minimal Field Component
private struct MinimalField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("", text: $value)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview Gradient Component
private struct PreviewGradient: View {
    let preset: String
    let hue: Double
    let intensity: Double

    var body: some View {
        let (startColor, endColor) = gradientColors()

        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    startColor,
                    endColor,
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            Text("Preview")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
        )
    }

    private func gradientColors() -> (Color, Color) {
        let presetLower = preset.lowercased()
        switch presetLower {
        case "sunset":
            return (Color(red: 1.0, green: 0.55, blue: 0.35).opacity(max(0.35, intensity * 2.5)),
                    Color(red: 0.90, green: 0.20, blue: 0.50).opacity(0.25))
        case "ocean":
            return (Color(red: 0.10, green: 0.55, blue: 0.95).opacity(max(0.35, intensity * 2.5)),
                    Color(red: 0.05, green: 0.30, blue: 0.60).opacity(0.25))
        case "forest":
            return (Color(red: 0.10, green: 0.65, blue: 0.30).opacity(max(0.35, intensity * 2.5)),
                    Color(red: 0.05, green: 0.35, blue: 0.20).opacity(0.25))
        case "midnight":
            return (Color(white: 0.9).opacity(max(0.35, intensity * 2.5)),
                    Color.white.opacity(0.15))
        case "custom":
            let start = Color(hue: hue, saturation: 0.75, brightness: 0.95).opacity(max(0.35, intensity * 2.5))
            let end = Color(hue: hue, saturation: 0.6, brightness: 0.75).opacity(0.25)
            return (start, end)
        default: // "Aurora"
            return (Color.accentColor.opacity(max(0.35, intensity * 2.5)),
                    Color.accentColor.opacity(0.25))
        }
    }
}

// MARK: - Roles Management Section
private struct RolesManagementSection: View {
    @Environment(\.managedObjectContext) private var moc
    @State private var roles: [NSManagedObject] = []
    @State private var rolesByCategory: [String: [NSManagedObject]] = [:]
    @State private var expandedCategories: Set<String> = []
    @State private var showAddRole = false
    @State private var newRoleName = ""
    @State private var newRoleCategory = "🧰 Miscellaneous"
    @State private var searchText = ""

    var filteredCategories: [String] {
        let categories = rolesByCategory.keys.sorted()
        if searchText.isEmpty {
            return categories
        }
        return categories.filter { category in
            let rolesInCategory = rolesByCategory[category] ?? []
            return category.localizedCaseInsensitiveContains(searchText) ||
                   rolesInCategory.contains { role in
                       (role.value(forKey: "name") as? String ?? "").localizedCaseInsensitiveContains(searchText)
                   }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Crew Roles")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(spacing: 16) {
                // Info Text
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    Text("These roles are available when adding contacts. Default roles are automatically loaded.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search roles...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
                .help(Tooltips.Settings.searchRoles)

                // Add Custom Role Button
                Button {
                    showAddRole = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom Role")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(Tooltips.Settings.addCustomRole)

                // Roles List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredCategories, id: \.self) { category in
                            categorySection(category: category)
                        }
                    }
                }
                .frame(maxHeight: 400)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.02))
                )

                Text("Tip: Click a category name to expand or collapse roles")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .onAppear {
            loadRoles()
        }
        .sheet(isPresented: $showAddRole) {
            addRoleSheet
        }
    }

    private func categorySection(category: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            Button {
                withAnimation {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text(category)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\((rolesByCategory[category] ?? []).count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.1))
                        )
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Roles in category
            if expandedCategories.contains(category) {
                VStack(spacing: 4) {
                    ForEach(filteredRoles(for: category), id: \.objectID) { role in
                        roleRow(role: role)
                    }
                }
                .padding(.leading, 20)
            }
        }
    }

    private func filteredRoles(for category: String) -> [NSManagedObject] {
        let roles = rolesByCategory[category] ?? []
        if searchText.isEmpty {
            return roles
        }
        return roles.filter { role in
            (role.value(forKey: "name") as? String ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private func roleRow(role: NSManagedObject) -> some View {
        HStack {
            Text(role.value(forKey: "name") as? String ?? "")
                .font(.system(size: 12))
            Spacer()
            if role.value(forKey: "isCustom") as? Bool == true {
                Text("Custom")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                Button {
                    deleteRole(role)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(6)
    }

    private var addRoleSheet: some View {
        VStack(spacing: 20) {
            Text("Add Custom Role")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Role Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g., VR Supervisor", text: $newRoleName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Category", selection: $newRoleCategory) {
                    ForEach(Array(rolesByCategory.keys.sorted()), id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Cancel") {
                    showAddRole = false
                    newRoleName = ""
                }
                .keyboardShortcut(.cancelAction)

                Button("Add Role") {
                    addCustomRole()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newRoleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func loadRoles() {
        // Ensure default roles are loaded
        RolesDataManager.loadDefaultRoles(context: moc)

        // Fetch all roles
        roles = RolesDataManager.fetchAllRoles(context: moc)
        rolesByCategory = RolesDataManager.fetchRolesByCategory(context: moc)

        // Expand first category by default
        if let firstCategory = rolesByCategory.keys.sorted().first {
            expandedCategories.insert(firstCategory)
        }
    }

    private func addCustomRole() {
        guard !newRoleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        RolesDataManager.addCustomRole(name: newRoleName, category: newRoleCategory, context: moc)

        showAddRole = false
        newRoleName = ""
        loadRoles()
    }

    private func deleteRole(_ role: NSManagedObject) {
        moc.delete(role)
        try? moc.save()
        loadRoles()
    }
}

// MARK: - Full-Screen Project Settings View (with back navigation)
/// A full-screen wrapper for project settings that replaces the main content area
/// instead of appearing as a sheet. Provides back navigation to return to the dashboard.
struct ProjectSettingsFullView: View {
    let project: NSManagedObject
    let onBack: () -> Void

    @Environment(\.managedObjectContext) private var moc
    @AppStorage("app_theme") private var appTheme: String = "Standard"

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    private func hasAttr(_ key: String) -> Bool {
        project.entity.attributesByName[key] != nil
    }

    private var projectName: String {
        hasAttr("name") ? ((project.value(forKey: "name") as? String) ?? "Project") : "Project"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation header with back button
            HStack(spacing: 8) {
                Button(action: onBack) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(currentTheme.accentColor)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Spacer()

                Text("Project Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Spacer to balance the back button
                Color.clear
                    .frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Embed the existing settings content
            ProjectSettingsContent(project: project)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Project Settings Content (reusable between sheet and full view)
/// The actual settings content, extracted to be reusable
struct ProjectSettingsContent: View {
    let project: NSManagedObject

    @Environment(\.managedObjectContext) private var moc

    private func hasAttr(_ key: String) -> Bool { project.entity.attributesByName[key] != nil }

    @State private var editName: String = ""
    @State private var isEditingName: Bool = false
    @State private var editProductionCompany: String = ""
    @State private var editStatus: ProjectStatus = .development

    // Global Typeface Setting
    @AppStorage("global_typeface") private var globalTypeface: String = "SF Pro"
    @AppStorage("global_typeface_size") private var globalTypefaceSize: Double = 64

    // Header Color Settings
    @AppStorage("header_preset") private var headerPreset: String = "Aurora"
    @AppStorage("header_hue") private var headerHue: Double = 0.58
    @AppStorage("header_intensity") private var headerIntensity: Double = 0.18

    private var projectIDString: String {
        project.objectID.uriRepresentation().absoluteString
    }

    private func loadEdits() {
        editName = hasAttr("name") ? ((project.value(forKey: "name") as? String) ?? "") : ""
        editProductionCompany = hasAttr("productionCompany") ? ((project.value(forKey: "productionCompany") as? String) ?? "") : ""
        if hasAttr("status") {
            let raw = (project.value(forKey: "status") as? String) ?? ProjectStatus.development.rawValue
            editStatus = ProjectStatus(rawValue: raw) ?? .development
        } else {
            editStatus = .development
        }
    }

    private func touch(_ object: NSManagedObject) {
        if object.entity.attributesByName["updatedAt"] != nil {
            object.setValue(Date(), forKey: "updatedAt")
        }
    }

    private func saveEdits() {
        if hasAttr("name") {
            let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
            project.setValue(trimmed.isEmpty ? "Untitled" : trimmed, forKey: "name")
        }
        if hasAttr("productionCompany") { project.setValue(editProductionCompany.isEmpty ? nil : editProductionCompany, forKey: "productionCompany") }
        if hasAttr("status") { project.setValue(editStatus.rawValue, forKey: "status") }

        touch(project)
        try? moc.save()

        NotificationCenter.default.post(name: Notification.Name("GlobalFontDidChange"), object: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Project Title Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Title")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Project Name", text: $editName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .semibold))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .onChange(of: editName) { _ in saveEdits() }
                }

                // Production Company Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Production Company")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Company Name", text: $editProductionCompany)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .onChange(of: editProductionCompany) { _ in saveEdits() }
                }

                // Status Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Status")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("Status", selection: $editStatus) {
                        ForEach(ProjectStatus.allCases) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                    .onChange(of: editStatus) { _ in saveEdits() }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { loadEdits() }
    }
}
