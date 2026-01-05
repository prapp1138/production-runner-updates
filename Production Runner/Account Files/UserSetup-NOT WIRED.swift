//
//  UserSetupWizard.swift
//  Production Runner
//
//  First-run setup wizard for new users
//

import SwiftUI
import CoreData

// MARK: - User Setup Wizard

struct UserSetupWizard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    // App Storage for persisting user preferences
    @AppStorage("account_name") private var accountName: String = ""
    @AppStorage("account_email") private var accountEmail: String = ""
    @AppStorage("account_role") private var accountRole: String = ""
    @AppStorage("account_avatar_color") private var avatarColorHex: String = "#007AFF"
    @AppStorage("user_setup_completed") private var setupCompleted: Bool = false
    @AppStorage("preferred_modules") private var preferredModulesData: Data = Data()

    // Wizard state
    @State private var currentStep: SetupStep = .welcome
    @State private var selectedRole: ProductionRole = .producer
    @State private var selectedProjectType: ProjectType = .feature
    @State private var selectedModules: Set<AppModule> = Set(AppModule.allCases)
    @State private var userName: String = ""
    @State private var userEmail: String = ""
    @State private var selectedColor: Color = .blue

    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case role = 1
        case projectType = 2
        case modules = 3
        case profile = 4
        case complete = 5

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .role: return "Your Role"
            case .projectType: return "Project Type"
            case .modules: return "Modules"
            case .profile: return "Profile"
            case .complete: return "Ready!"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(SetupStep.welcome)
                roleStep.tag(SetupStep.role)
                projectTypeStep.tag(SetupStep.projectType)
                modulesStep.tag(SetupStep.modules)
                profileStep.tag(SetupStep.profile)
                completeStep.tag(SetupStep.complete)
            }
            #if os(macOS)
            .tabViewStyle(.automatic)
            #endif

            // Navigation buttons
            navigationButtons
        }
        .frame(width: 600, height: 500)
        .background(backgroundGradient)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(SetupStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "film.stack")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Welcome to Production Runner")
                .font(.largeTitle.bold())

            Text("Let's set up your workspace in just a few steps.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Role Step

    private var roleStep: some View {
        VStack(spacing: 24) {
            Text("What's your primary role?")
                .font(.title.bold())
                .padding(.top, 40)

            Text("We'll customize your experience based on your role.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(ProductionRole.allCases, id: \.self) { role in
                    RoleCard(
                        role: role,
                        isSelected: selectedRole == role
                    ) {
                        selectedRole = role
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Project Type Step

    private var projectTypeStep: some View {
        VStack(spacing: 24) {
            Text("What type of project?")
                .font(.title.bold())
                .padding(.top, 40)

            Text("Select the type of production you're working on.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(ProjectType.allCases, id: \.self) { type in
                    ProjectTypeCard(
                        type: type,
                        isSelected: selectedProjectType == type
                    ) {
                        selectedProjectType = type
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Modules Step

    private var modulesStep: some View {
        VStack(spacing: 24) {
            Text("Which modules do you need?")
                .font(.title.bold())
                .padding(.top, 40)

            Text("Select the tools you'll use most. You can always change this later.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(AppModule.allCases, id: \.self) { module in
                        ModuleCard(
                            module: module,
                            isSelected: selectedModules.contains(module)
                        ) {
                            if selectedModules.contains(module) {
                                selectedModules.remove(module)
                            } else {
                                selectedModules.insert(module)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxHeight: 280)

            HStack(spacing: 16) {
                Button("Select All") {
                    selectedModules = Set(AppModule.allCases)
                }
                .buttonStyle(.bordered)

                Button("Clear All") {
                    selectedModules.removeAll()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }

    // MARK: - Profile Step

    private var profileStep: some View {
        VStack(spacing: 24) {
            Text("Set up your profile")
                .font(.title.bold())
                .padding(.top, 40)

            // Avatar preview
            ZStack {
                Circle()
                    .fill(selectedColor.gradient)
                    .frame(width: 100, height: 100)

                Text(initials)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Your name", text: $userName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("your@email.com", text: $userEmail)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Avatar Color")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            selectedColor == color ? Color.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 80)

            Spacer()
        }
    }

    // MARK: - Complete Step

    private var completeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're all set!")
                .font(.largeTitle.bold())

            Text("Your workspace is ready. Let's start creating!")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(label: "Role", value: selectedRole.name)
                SummaryRow(label: "Project Type", value: selectedProjectType.name)
                SummaryRow(label: "Active Modules", value: "\(selectedModules.count) selected")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.horizontal, 80)

            Spacer()
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        if let previous = SetupStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = previous
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep == .complete {
                Button("Get Started") {
                    completeSetup()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Next") {
                    withAnimation {
                        if let next = SetupStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = next
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == .profile && userName.isEmpty)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }

    // MARK: - Helpers

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.05),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var initials: String {
        let components = userName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    private var presetColors: [Color] {
        [.blue, .purple, .pink, .red, .orange, .green, .teal, .indigo]
    }

    private func completeSetup() {
        // Save user preferences
        accountName = userName
        accountEmail = userEmail
        accountRole = selectedRole.name
        avatarColorHex = colorToHex(selectedColor)

        // Save preferred modules
        if let data = try? JSONEncoder().encode(Array(selectedModules.map { $0.rawValue })) {
            preferredModulesData = data
        }

        // Mark setup as completed
        setupCompleted = true

        dismiss()
    }

    private func colorToHex(_ color: Color) -> String {
        #if os(macOS)
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return "#007AFF" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #endif
    }
}

// MARK: - Production Role

enum ProductionRole: String, CaseIterable {
    case producer
    case director
    case assistantDirector
    case cinematographer
    case productionManager
    case editor
    case scriptSupervisor
    case other

    var name: String {
        switch self {
        case .producer: return "Producer"
        case .director: return "Director"
        case .assistantDirector: return "Assistant Director"
        case .cinematographer: return "Cinematographer"
        case .productionManager: return "Production Manager"
        case .editor: return "Editor"
        case .scriptSupervisor: return "Script Supervisor"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .producer: return "person.crop.rectangle.stack"
        case .director: return "megaphone"
        case .assistantDirector: return "clock.badge.checkmark"
        case .cinematographer: return "camera"
        case .productionManager: return "folder.badge.gearshape"
        case .editor: return "scissors"
        case .scriptSupervisor: return "doc.text.magnifyingglass"
        case .other: return "person.crop.circle"
        }
    }
}

// MARK: - Project Type

enum ProjectType: String, CaseIterable {
    case feature
    case tv
    case commercial
    case musicVideo
    case documentary
    case shortFilm

    var name: String {
        switch self {
        case .feature: return "Feature Film"
        case .tv: return "TV Series"
        case .commercial: return "Commercial"
        case .musicVideo: return "Music Video"
        case .documentary: return "Documentary"
        case .shortFilm: return "Short Film"
        }
    }

    var icon: String {
        switch self {
        case .feature: return "film"
        case .tv: return "tv"
        case .commercial: return "megaphone"
        case .musicVideo: return "music.note.tv"
        case .documentary: return "video"
        case .shortFilm: return "film.stack"
        }
    }
}

// MARK: - App Module

enum AppModule: String, CaseIterable, Codable {
    case screenplay
    case breakdowns
    case scheduler
    case shotList
    case budget
    case callSheets
    case contacts
    case calendar
    case locations
    case liveMode
    case create
    case scripty
    case tasks

    var name: String {
        switch self {
        case .screenplay: return "Screenplay"
        case .breakdowns: return "Breakdowns"
        case .scheduler: return "Scheduler"
        case .shotList: return "Shot List"
        case .budget: return "Budget"
        case .callSheets: return "Call Sheets"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .locations: return "Locations"
        case .liveMode: return "Live Mode"
        case .create: return "Create"
        case .scripty: return "Scripty"
        case .tasks: return "Tasks"
        }
    }

    var icon: String {
        switch self {
        case .screenplay: return "doc.text"
        case .breakdowns: return "list.bullet.clipboard"
        case .scheduler: return "calendar.day.timeline.left"
        case .shotList: return "camera.viewfinder"
        case .budget: return "dollarsign.circle"
        case .callSheets: return "doc.badge.clock"
        case .contacts: return "person.crop.circle"
        case .calendar: return "calendar"
        case .locations: return "mappin.circle"
        case .liveMode: return "play.circle"
        case .create: return "square.grid.2x2"
        case .scripty: return "pencil.and.scribble"
        case .tasks: return "checkmark.circle"
        }
    }
}

// MARK: - Supporting Views

private struct RoleCard: View {
    let role: ProductionRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: role.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(role.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectTypeCard: View {
    let type: ProjectType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : .accentColor)
                    .frame(width: 40)

                Text(type.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ModuleCard: View {
    let module: AppModule
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: module.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? .white : .primary)
                }

                Text(module.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    UserSetupWizard()
}
