// MARK: - Call Sheet Editable Sections
// Production Runner - Call Sheet Module
// Individual section views for editing call sheet content

import SwiftUI
import CoreData

#if os(macOS)

// MARK: - Header Section

struct HeaderSectionView: View {
    @Binding var callSheet: CallSheet
    @Environment(\.managedObjectContext) private var context
    @State private var showImagePicker = false
    @State private var projectCompanyName: String = ""
    @State private var projectName: String = ""

    var body: some View {
        CallSheetSectionCard(
            title: "Header",
            icon: "doc.text",
            headerAction: syncFromProject,
            headerActionIcon: "arrow.triangle.2.circlepath"
        ) {
            VStack(spacing: CallSheetDesign.itemSpacing) {
                // Production Company Logo
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRODUCTION LOGO")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textSecondary)

                        Button(action: { showImagePicker = true }) {
                            if let imageData = callSheet.productionCompanyImageData,
                               let nsImage = NSImage(data: imageData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 120, maxHeight: 60)
                                    .cornerRadius(4)
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 20))
                                    Text("Add Logo")
                                        .font(CallSheetDesign.captionFont)
                                }
                                .foregroundColor(CallSheetDesign.textTertiary)
                                .frame(width: 120, height: 60)
                                .background(CallSheetDesign.sectionHeader)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundColor(CallSheetDesign.border)
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .frame(height: 80)

                    VStack(spacing: CallSheetDesign.itemSpacing) {
                        // Company field with sync indicator
                        HStack(spacing: 4) {
                            InlineEditableField(label: "Company", text: $callSheet.productionCompany, labelWidth: 80)

                            if !projectCompanyName.isEmpty && callSheet.productionCompany != projectCompanyName {
                                Button(action: { callSheet.productionCompany = projectCompanyName }) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(CallSheetDesign.accent)
                                }
                                .buttonStyle(.plain)
                                .help("Use '\(projectCompanyName)' from Project Settings")
                            } else if callSheet.productionCompany == projectCompanyName && !projectCompanyName.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                    .help("Synced with Project Settings")
                            }
                        }

                        // Project field with sync indicator
                        HStack(spacing: 4) {
                            InlineEditableField(label: "Project", text: $callSheet.projectName, labelWidth: 80)

                            if !projectName.isEmpty && callSheet.projectName != projectName {
                                Button(action: { callSheet.projectName = projectName }) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(CallSheetDesign.accent)
                                }
                                .buttonStyle(.plain)
                                .help("Use '\(projectName)' from Project Settings")
                            } else if callSheet.projectName == projectName && !projectName.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                    .help("Synced with Project Settings")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider()
                    .background(CallSheetDesign.divider)

                // All header fields on one line
                HStack(spacing: 12) {
                    // Call Sheet Title (shortened)
                    HStack(spacing: 8) {
                        Text("Call Sheet Title")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textSecondary)
                            .frame(width: 100, alignment: .trailing)

                        TextField("Title", text: $callSheet.title)
                            .textFieldStyle(.plain)
                            .font(CallSheetDesign.bodyFont)
                            .frame(width: 180)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Shoot Date (styled to match UI)
                    HStack(spacing: 8) {
                        Text("Shoot Date")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textSecondary)

                        DatePicker("", selection: $callSheet.shootDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(width: 120)
                    }

                    // Status (dropdown)
                    HStack(spacing: 8) {
                        Text("Status")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textSecondary)

                        Menu {
                            ForEach(CallSheetStatus.allCases) { status in
                                Button(action: { callSheet.status = status }) {
                                    HStack {
                                        Text(status.rawValue)
                                        if callSheet.status == status {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(callSheet.status.rawValue)
                                    .font(CallSheetDesign.bodyFont)
                                    .foregroundColor(CallSheetDesign.textPrimary)

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(CallSheetDesign.textTertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(width: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // Day of
                    HStack(spacing: 8) {
                        Text("DAY")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textSecondary)

                        Stepper(value: $callSheet.dayNumber, in: 1...999) {
                            Text("\(callSheet.dayNumber)")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(CallSheetDesign.accent)
                                .frame(minWidth: 25)
                        }
                        .labelsHidden()

                        Text("OF")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textSecondary)

                        Stepper(value: $callSheet.totalDays, in: 1...999) {
                            Text("\(callSheet.totalDays)")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(CallSheetDesign.textPrimary)
                                .frame(minWidth: 25)
                        }
                        .labelsHidden()
                    }

                    Spacer()

                    // Revision
                    RevisionColorBadge(revision: callSheet.revisionColor)
                }
            }
        }
        .fileImporter(isPresented: $showImagePicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                if let data = try? Data(contentsOf: url) {
                    callSheet.productionCompanyImageData = data
                }
            }
        }
        .onAppear {
            loadProjectSettings()
        }
    }

    private func loadProjectSettings() {
        // Fetch the current project to get company name and project name
        let request = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        guard let projects = try? context.fetch(request), let project = projects.first else { return }

        if let company = project.value(forKey: "productionCompany") as? String {
            projectCompanyName = company
        }
        if let name = project.value(forKey: "name") as? String {
            projectName = name
        }
    }

    private func syncFromProject() {
        loadProjectSettings()

        // Auto-fill empty fields from project settings
        if callSheet.productionCompany.isEmpty && !projectCompanyName.isEmpty {
            callSheet.productionCompany = projectCompanyName
        }
        if callSheet.projectName.isEmpty && !projectName.isEmpty {
            callSheet.projectName = projectName
        }
    }
}

// MARK: - Production Info Section

struct ProductionInfoSectionView: View {
    @Binding var callSheet: CallSheet
    @Environment(\.managedObjectContext) private var context
    @State private var contactsForRoles: [String: [String]] = [:] // role -> list of matching names
    @State private var allContacts: [String] = [] // All contact names for fallback

    // Role mappings: label -> possible role matches in contacts
    private let roleMatches: [(label: String, binding: WritableKeyPath<CallSheet, String>, matches: [String])] = [
        ("Director", \CallSheet.director, ["director", "film director", "tv director"]),
        ("1st AD", \CallSheet.firstAD, ["1st ad", "first ad", "1st assistant director", "first assistant director"]),
        ("2nd AD", \CallSheet.secondAD, ["2nd ad", "second ad", "2nd assistant director", "second assistant director"]),
        ("Producer", \CallSheet.producer, ["producer", "executive producer", "ep"]),
        ("Line Producer", \CallSheet.lineProducer, ["line producer", "lp"]),
        ("UPM", \CallSheet.upm, ["upm", "unit production manager", "production manager"]),
        ("DOP", \CallSheet.dop, ["dop", "dp", "director of photography", "cinematographer"]),
        ("Prod. Manager", \CallSheet.productionManager, ["production manager", "pm"]),
        ("Prod. Coord.", \CallSheet.productionCoordinator, ["production coordinator", "poc", "coordinator"])
    ]

    var body: some View {
        CallSheetSectionCard(
            title: "Key Personnel",
            icon: "person.2",
            headerAction: syncFromContacts,
            headerActionIcon: "arrow.triangle.2.circlepath"
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: CallSheetDesign.itemSpacing) {
                KeyPersonnelField(label: "Director", text: $callSheet.director, matchingContacts: contactsForRoles["Director"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "1st AD", text: $callSheet.firstAD, matchingContacts: contactsForRoles["1st AD"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "2nd AD", text: $callSheet.secondAD, matchingContacts: contactsForRoles["2nd AD"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "Producer", text: $callSheet.producer, matchingContacts: contactsForRoles["Producer"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "Line Producer", text: $callSheet.lineProducer, matchingContacts: contactsForRoles["Line Producer"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "UPM", text: $callSheet.upm, matchingContacts: contactsForRoles["UPM"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "DOP", text: $callSheet.dop, matchingContacts: contactsForRoles["DOP"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "Prod. Manager", text: $callSheet.productionManager, matchingContacts: contactsForRoles["Prod. Manager"] ?? [], allContacts: allContacts)
                KeyPersonnelField(label: "Prod. Coord.", text: $callSheet.productionCoordinator, matchingContacts: contactsForRoles["Prod. Coord."] ?? [], allContacts: allContacts)
            }
        }
        .onAppear {
            loadContactsForRoles()
        }
    }

    private func loadContactsForRoles() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        guard let contacts = try? context.fetch(request) else { return }

        // Build list of all contact names
        allContacts = contacts.compactMap { $0.value(forKey: "name") as? String }
            .filter { !$0.isEmpty }
            .sorted()

        var mapping: [String: [String]] = [:]

        for (label, _, matches) in roleMatches {
            // Find ALL contacts whose role matches one of our expected roles
            let matchingNames = contacts.compactMap { obj -> String? in
                guard let role = obj.value(forKey: "role") as? String else { return nil }
                let lowerRole = role.lowercased().trimmingCharacters(in: .whitespaces)
                let isMatch = matches.contains { lowerRole == $0 || lowerRole.contains($0) }
                if isMatch, let name = obj.value(forKey: "name") as? String, !name.isEmpty {
                    return name
                }
                return nil
            }
            mapping[label] = matchingNames.sorted()
        }

        contactsForRoles = mapping
    }

    private func syncFromContacts() {
        loadContactsForRoles()

        // Auto-fill empty fields with first matching contact
        for (label, keyPath, _) in roleMatches {
            if callSheet[keyPath: keyPath].isEmpty, let firstName = contactsForRoles[label]?.first {
                callSheet[keyPath: keyPath] = firstName
            }
        }
    }
}

// MARK: - Key Personnel Field

private struct KeyPersonnelField: View {
    let label: String
    @Binding var text: String
    let matchingContacts: [String] // Contacts that match this role
    let allContacts: [String] // All contacts for "Other" selection

    @State private var isCustomMode: Bool = false
    @State private var showOtherContacts: Bool = false

    private var displayOptions: [String] {
        var options = matchingContacts
        if !options.contains(text) && !text.isEmpty && text != "Custom" {
            // Current value isn't in the list, add it
            options.insert(text, at: 0)
        }
        return options
    }

    private var otherContacts: [String] {
        // Contacts not in the matching list
        allContacts.filter { !matchingContacts.contains($0) }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(CallSheetDesign.labelFont)
                .foregroundColor(CallSheetDesign.textSecondary)
                .frame(width: 90, alignment: .trailing)

            if isCustomMode {
                // Custom text entry mode
                HStack(spacing: 4) {
                    TextField("Enter name", text: $text)
                        .textFieldStyle(.plain)
                        .font(CallSheetDesign.bodyFont)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(CallSheetDesign.sectionHeader)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CallSheetDesign.accent.opacity(0.5), lineWidth: 1)
                        )

                    Button(action: {
                        isCustomMode = false
                        if text.isEmpty {
                            text = matchingContacts.first ?? ""
                        }
                    }) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(CallSheetDesign.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Switch to dropdown selection")
                }
            } else {
                // Dropdown selection mode
                Menu {
                    // Matching contacts section
                    if !matchingContacts.isEmpty {
                        Section("From Contacts") {
                            ForEach(matchingContacts, id: \.self) { name in
                                Button(action: { text = name }) {
                                    HStack {
                                        Text(name)
                                        if text == name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Other contacts section
                    if !otherContacts.isEmpty {
                        Section("Other Contacts") {
                            ForEach(otherContacts, id: \.self) { name in
                                Button(action: { text = name }) {
                                    HStack {
                                        Text(name)
                                        if text == name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Custom entry option
                    Button(action: {
                        isCustomMode = true
                        if matchingContacts.contains(text) || allContacts.contains(text) {
                            text = "" // Clear if switching to custom from a contact
                        }
                    }) {
                        Label("Custom...", systemImage: "pencil")
                    }

                    // Clear option
                    if !text.isEmpty {
                        Button(role: .destructive, action: { text = "" }) {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    HStack {
                        Text(text.isEmpty ? "Select..." : text)
                            .font(CallSheetDesign.bodyFont)
                            .foregroundColor(text.isEmpty ? CallSheetDesign.textTertiary : CallSheetDesign.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        // Show indicator if from contacts
                        if matchingContacts.contains(text) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 10))
                                .foregroundColor(.green.opacity(0.7))
                        } else if allContacts.contains(text) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.blue.opacity(0.7))
                        }

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(CallSheetDesign.textTertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CallSheetDesign.sectionHeader)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(CallSheetDesign.border, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Call Times Section

struct CallTimesSectionView: View {
    @Binding var callSheet: CallSheet
    @State private var isLunchManuallySet = false

    private let turnaroundOptions = [
        "12 Hour Turnaround",
        "11 Hour Turnaround",
        "10 Hour Turnaround",
        "9 Hour Turnaround",
        "8 Hour Turnaround",
        "Forced Call"
    ]

    var body: some View {
        CallSheetSectionCard(title: "Call Times", icon: "clock") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: CallSheetDesign.itemSpacing) {
                TimePickerField(label: "Crew Call", date: $callSheet.crewCall, labelWidth: 90)
                    .onChange(of: callSheet.crewCall) { newCrewCall in
                        // Auto-adjust lunch time if user hasn't manually set it
                        if !isLunchManuallySet, let crewCall = newCrewCall {
                            callSheet.lunch = Calendar.current.date(byAdding: .hour, value: 6, to: crewCall)
                        }
                    }
                TimePickerField(label: "On Set", date: $callSheet.onSetCall, labelWidth: 90)
                TimePickerField(label: "Shooting Call", date: $callSheet.shootingCall, labelWidth: 90)
                TimePickerField(label: "First Shot", date: $callSheet.firstShotCall, labelWidth: 90)
                TimePickerField(label: "Breakfast", date: $callSheet.breakfast, labelWidth: 90)
                TimePickerField(label: "Lunch", date: Binding(
                    get: { callSheet.lunch },
                    set: { newValue in
                        callSheet.lunch = newValue
                        // Mark as manually set when user changes it
                        isLunchManuallySet = true
                    }
                ), labelWidth: 90)
                TimePickerField(label: "2nd Meal", date: $callSheet.secondMeal, labelWidth: 90)
                TimePickerField(label: "Est. Wrap", date: $callSheet.estimatedWrap, labelWidth: 90)
                TimePickerField(label: "Hard Out", date: $callSheet.hardOut, labelWidth: 90)
            }

            Divider()
                .background(CallSheetDesign.divider)
                .padding(.vertical, 8)

            // Turnaround dropdown
            HStack(spacing: 8) {
                Text("Turnaround")
                    .font(CallSheetDesign.labelFont)
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .frame(width: 90, alignment: .trailing)

                Menu {
                    ForEach(turnaroundOptions, id: \.self) { option in
                        Button(action: { callSheet.gracePeriod = option }) {
                            HStack {
                                Text(option)
                                if callSheet.gracePeriod == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    if !callSheet.gracePeriod.isEmpty {
                        Button(role: .destructive, action: { callSheet.gracePeriod = "" }) {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: turnaroundIcon)
                            .font(.system(size: 11))
                            .foregroundColor(turnaroundColor)

                        Text(callSheet.gracePeriod.isEmpty ? "Select turnaround" : callSheet.gracePeriod)
                            .font(CallSheetDesign.bodyFont)
                            .foregroundColor(callSheet.gracePeriod.isEmpty ? CallSheetDesign.textTertiary : CallSheetDesign.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(CallSheetDesign.textTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(turnaroundBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(turnaroundBorder, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .frame(width: 200)

                Spacer()
            }
        }
    }

    private var turnaroundIcon: String {
        if callSheet.gracePeriod.contains("Forced") {
            return "exclamationmark.triangle.fill"
        }
        return "arrow.triangle.2.circlepath"
    }

    private var turnaroundColor: Color {
        if callSheet.gracePeriod.isEmpty {
            return CallSheetDesign.textTertiary
        } else if callSheet.gracePeriod.contains("Forced") {
            return .red
        } else if callSheet.gracePeriod.contains("8") || callSheet.gracePeriod.contains("9") {
            return .orange
        }
        return CallSheetDesign.accent
    }

    private var turnaroundBackground: Color {
        if callSheet.gracePeriod.contains("Forced") {
            return Color.red.opacity(0.1)
        }
        return CallSheetDesign.sectionHeader
    }

    private var turnaroundBorder: Color {
        if callSheet.gracePeriod.contains("Forced") {
            return Color.red.opacity(0.3)
        }
        return CallSheetDesign.border
    }
}

// MARK: - Weather Section

struct WeatherSectionView: View {
    @Binding var callSheet: CallSheet
    @StateObject private var weatherService = LocationWeatherService.shared

    var body: some View {
        CallSheetSectionCard(
            title: "Weather",
            icon: "cloud.sun",
            headerAction: fetchWeather,
            headerActionIcon: "arrow.clockwise"
        ) {
            VStack(spacing: CallSheetDesign.itemSpacing) {
                // Auto-fetch status
                if weatherService.isLoadingWeather {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Fetching weather data...")
                            .font(.caption)
                            .foregroundColor(CallSheetDesign.textTertiary)
                        Spacer()
                    }
                } else if let error = weatherService.weatherError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()

                        Button("Retry") {
                            fetchWeather()
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(CallSheetDesign.accent)
                    }
                }

                HStack(spacing: 24) {
                    // Temperature
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEMPERATURE")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "thermometer.sun")
                                    .foregroundColor(.orange)
                                TextField("High", text: $callSheet.weatherHigh)
                                    .textFieldStyle(.plain)
                                    .frame(width: 50)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "thermometer.snowflake")
                                    .foregroundColor(.blue)
                                TextField("Low", text: $callSheet.weatherLow)
                                    .textFieldStyle(.plain)
                                    .frame(width: 50)
                            }
                        }
                        .font(CallSheetDesign.bodyFont)
                    }

                    Divider()
                        .frame(height: 50)

                    // Sun Times
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUN")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "sunrise")
                                    .foregroundColor(.orange)
                                TextField("Sunrise", text: $callSheet.sunrise)
                                    .textFieldStyle(.plain)
                                    .frame(width: 70)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "sunset")
                                    .foregroundColor(.orange)
                                TextField("Sunset", text: $callSheet.sunset)
                                    .textFieldStyle(.plain)
                                    .frame(width: 70)
                            }
                        }
                        .font(CallSheetDesign.bodyFont)
                    }

                    Divider()
                        .frame(height: 50)

                    // Conditions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONDITIONS")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        HStack(spacing: 16) {
                            TextField("Conditions", text: $callSheet.weatherConditions)
                                .textFieldStyle(.plain)
                                .frame(minWidth: 100)

                            HStack(spacing: 4) {
                                Image(systemName: "humidity")
                                TextField("%", text: $callSheet.humidity)
                                    .textFieldStyle(.plain)
                                    .frame(width: 40)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "wind")
                                TextField("Wind", text: $callSheet.windSpeed)
                                    .textFieldStyle(.plain)
                                    .frame(width: 60)
                            }
                        }
                        .font(CallSheetDesign.bodyFont)
                        .foregroundColor(CallSheetDesign.textSecondary)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LocationSelectedForCallSheet"))) { notification in
            // Auto-fetch weather when location is selected
            if let userInfo = notification.userInfo {
                if let lat = userInfo["latitude"] as? Double,
                   let lon = userInfo["longitude"] as? Double {
                    weatherService.fetchWeather(latitude: lat, longitude: lon, date: callSheet.shootDate) { result in
                        if let weather = result {
                            applyWeatherResult(weather)
                        }
                    }
                } else if let address = userInfo["address"] as? String, !address.isEmpty {
                    weatherService.fetchWeather(address: address, date: callSheet.shootDate) { result in
                        if let weather = result {
                            applyWeatherResult(weather)
                        }
                    }
                }
            }
        }
    }

    private func fetchWeather() {
        // Try to fetch weather using location address
        guard !callSheet.locationAddress.isEmpty else {
            weatherService.weatherError = "Set a location address first"
            return
        }

        weatherService.fetchWeather(address: callSheet.locationAddress, date: callSheet.shootDate) { result in
            if let weather = result {
                applyWeatherResult(weather)
            }
        }
    }

    private func applyWeatherResult(_ weather: WeatherResult) {
        callSheet.weatherHigh = weather.high
        callSheet.weatherLow = weather.low
        callSheet.weatherConditions = weather.conditions
        callSheet.humidity = weather.humidity
        callSheet.windSpeed = weather.windSpeed
        callSheet.sunrise = weather.sunrise
        callSheet.sunset = weather.sunset
    }
}

// MARK: - Location Section

struct CallSheetLocationSectionView: View {
    @Binding var callSheet: CallSheet
    @StateObject private var locationManager = LocationDataManager.shared
    @StateObject private var locationService = LocationWeatherService.shared
    @State private var selectedLocationID: UUID?
    @State private var isCustomLocation: Bool = false

    var body: some View {
        CallSheetSectionCard(
            title: "Location",
            icon: "mappin.and.ellipse",
            headerAction: findNearestHospital,
            headerActionIcon: "cross.circle"
        ) {
            VStack(spacing: CallSheetDesign.itemSpacing) {
                // Location Selector
                HStack(spacing: 12) {
                    Text("SELECT LOCATION")
                        .font(CallSheetDesign.labelFont)
                        .foregroundColor(CallSheetDesign.textTertiary)

                    Menu {
                        Section("From Locations App") {
                            ForEach(locationManager.locations) { location in
                                Button(action: { selectLocation(location) }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(location.name)
                                            if !location.address.isEmpty {
                                                Text(location.address)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if selectedLocationID == location.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        Button(action: {
                            isCustomLocation = true
                            selectedLocationID = nil
                        }) {
                            Label("Custom Location...", systemImage: "pencil")
                        }

                        if selectedLocationID != nil || !callSheet.shootingLocation.isEmpty {
                            Button(role: .destructive, action: clearLocation) {
                                Label("Clear Location", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(selectedLocationID != nil ? CallSheetDesign.accent : CallSheetDesign.textTertiary)

                            Text(locationDisplayName)
                                .font(CallSheetDesign.bodyFont)
                                .foregroundColor(selectedLocationID != nil || !callSheet.shootingLocation.isEmpty ? CallSheetDesign.textPrimary : CallSheetDesign.textTertiary)
                                .lineLimit(1)

                            Spacer()

                            if selectedLocationID != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green.opacity(0.7))
                            }

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(CallSheetDesign.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(CallSheetDesign.sectionHeader)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(CallSheetDesign.border, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 350)

                    Spacer()
                }

                Divider()
                    .background(CallSheetDesign.divider)

                VStack(alignment: .leading, spacing: 16) {
                    // Shooting Location
                    VStack(alignment: .leading, spacing: CallSheetDesign.itemSpacing) {
                        Text("SHOOTING LOCATION")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        InlineEditableField(label: "Name", text: $callSheet.shootingLocation, labelWidth: 70)
                        InlineEditableField(label: "Address", text: $callSheet.locationAddress, isMultiline: true, labelWidth: 70)
                        InlineEditableField(label: "Contact", text: $callSheet.locationContact, labelWidth: 70)
                        InlineEditableField(label: "Phone", text: $callSheet.locationPhone, labelWidth: 70)
                    }

                    Divider()

                    // Basecamp & Parking
                    VStack(alignment: .leading, spacing: CallSheetDesign.itemSpacing) {
                        Text("BASECAMP & PARKING")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        InlineEditableField(label: "Basecamp", text: $callSheet.basecamp, labelWidth: 70)
                        InlineEditableField(label: "Address", text: $callSheet.basecampAddress, labelWidth: 70)
                        InlineEditableField(label: "Crew Park", text: $callSheet.crewParking, labelWidth: 70)
                        InlineEditableField(label: "Talent Park", text: $callSheet.talentParking, labelWidth: 70)
                        InlineEditableField(label: "Instructions", text: $callSheet.parkingInstructions, isMultiline: true, labelWidth: 70)
                    }

                    Divider()

                    // Hospital
                    VStack(alignment: .leading, spacing: CallSheetDesign.itemSpacing) {
                        HStack {
                            Image(systemName: "cross.circle.fill")
                                .foregroundColor(.red)
                            Text("NEAREST HOSPITAL")
                                .font(CallSheetDesign.labelFont)
                                .foregroundColor(CallSheetDesign.textTertiary)

                            Spacer()

                            if locationService.isLoadingHospital {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Button(action: findNearestHospital) {
                                    Image(systemName: "location.magnifyingglass")
                                        .font(.system(size: 12))
                                        .foregroundColor(CallSheetDesign.accent)
                                }
                                .buttonStyle(.plain)
                                .help("Find nearest hospital")
                            }
                        }

                        if let error = locationService.hospitalError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        InlineEditableField(label: "Name", text: $callSheet.nearestHospital, labelWidth: 60)
                        InlineEditableField(label: "Address", text: $callSheet.hospitalAddress, isMultiline: true, labelWidth: 60)
                        InlineEditableField(label: "Phone", text: $callSheet.hospitalPhone, labelWidth: 60)
                    }
                }
            }
        }
    }

    private var locationDisplayName: String {
        if let id = selectedLocationID,
           let location = locationManager.locations.first(where: { $0.id == id }) {
            return location.name
        } else if !callSheet.shootingLocation.isEmpty {
            return callSheet.shootingLocation
        }
        return "Select a location..."
    }

    private func selectLocation(_ location: LocationItem) {
        selectedLocationID = location.id
        isCustomLocation = false

        // Populate call sheet fields from location
        callSheet.shootingLocation = location.name
        callSheet.locationAddress = location.address
        callSheet.locationContact = location.contact
        callSheet.locationPhone = location.phone

        // Auto-find nearest hospital if location has coordinates
        if let lat = location.latitude, let lon = location.longitude {
            locationService.findNearestHospital(latitude: lat, longitude: lon) { result in
                if let hospital = result {
                    callSheet.nearestHospital = hospital.name
                    callSheet.hospitalAddress = hospital.address
                    callSheet.hospitalPhone = hospital.phone
                }
            }
        } else if !location.address.isEmpty {
            // Geocode from address
            locationService.findNearestHospital(address: location.address) { result in
                if let hospital = result {
                    callSheet.nearestHospital = hospital.name
                    callSheet.hospitalAddress = hospital.address
                    callSheet.hospitalPhone = hospital.phone
                }
            }
        }

        // Post notification for weather update
        NotificationCenter.default.post(
            name: Notification.Name("LocationSelectedForCallSheet"),
            object: nil,
            userInfo: ["address": location.address, "latitude": location.latitude as Any, "longitude": location.longitude as Any]
        )
    }

    private func clearLocation() {
        selectedLocationID = nil
        isCustomLocation = false
        callSheet.shootingLocation = ""
        callSheet.locationAddress = ""
        callSheet.locationContact = ""
        callSheet.locationPhone = ""
    }

    private func findNearestHospital() {
        // Try to find hospital from current location data
        if let id = selectedLocationID,
           let location = locationManager.locations.first(where: { $0.id == id }) {
            if let lat = location.latitude, let lon = location.longitude {
                locationService.findNearestHospital(latitude: lat, longitude: lon) { result in
                    if let hospital = result {
                        callSheet.nearestHospital = hospital.name
                        callSheet.hospitalAddress = hospital.address
                        callSheet.hospitalPhone = hospital.phone
                    }
                }
            } else if !location.address.isEmpty {
                locationService.findNearestHospital(address: location.address) { result in
                    if let hospital = result {
                        callSheet.nearestHospital = hospital.name
                        callSheet.hospitalAddress = hospital.address
                        callSheet.hospitalPhone = hospital.phone
                    }
                }
            }
        } else if !callSheet.locationAddress.isEmpty {
            locationService.findNearestHospital(address: callSheet.locationAddress) { result in
                if let hospital = result {
                    callSheet.nearestHospital = hospital.name
                    callSheet.hospitalAddress = hospital.address
                    callSheet.hospitalPhone = hospital.phone
                }
            }
        }
    }
}

// MARK: - Schedule Section

struct ScheduleSectionView: View {
    @Binding var callSheet: CallSheet
    @State private var selectedItem: ScheduleItem?
    @State private var showAddSheet = false

    var body: some View {
        CallSheetSectionCard(
            title: "Shooting Schedule",
            icon: "list.bullet.rectangle",
            headerAction: { showAddSheet = true },
            headerActionIcon: "plus"
        ) {
            if callSheet.scheduleItems.isEmpty {
                CallSheetEmptyState(
                    icon: "film.stack",
                    title: "No Scenes Added",
                    message: "Add scenes to your shooting schedule or import from the Scheduler.",
                    actionTitle: "Add Scene",
                    action: { showAddSheet = true }
                )
            } else {
                VStack(spacing: 8) {
                    // Scene strips
                    ForEach($callSheet.scheduleItems) { $item in
                        CallSheetScheduleItemRow(item: $item, onDelete: {
                            callSheet.scheduleItems.removeAll { $0.id == item.id }
                        })
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(CallSheetDesign.border.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CallSheetAddScheduleItemSheet(callSheet: $callSheet)
        }
    }
}

// MARK: - Schedule Item Row

struct CallSheetScheduleItemRow: View {
    @Binding var item: ScheduleItem
    let onDelete: () -> Void
    @State private var isExpanded = false

    var stripColor: Color {
        switch (item.intExt, item.dayNight) {
        case (.int, .day), (.int, .morning), (.int, .afternoon):
            return Color.orange.opacity(0.15)
        case (.ext, .day), (.ext, .morning), (.ext, .afternoon):
            return Color.yellow.opacity(0.15)
        case (.int, .night), (.int, .evening):
            return Color.blue.opacity(0.15)
        case (.ext, .night), (.ext, .evening):
            return Color.green.opacity(0.15)
        case (.int, .dawn), (.int, .dusk):
            return Color.pink.opacity(0.15)
        case (.ext, .dawn), (.ext, .dusk):
            return Color.purple.opacity(0.15)
        default:
            return Color.gray.opacity(0.08)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Scene Number Badge
                Text(item.sceneNumber.isEmpty ? "—" : item.sceneNumber)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor)
                    )

                // Scene Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if item.intExt != .int {
                            Text(item.intExt.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.primary.opacity(0.8))
                        }
                        Text(item.setDescription.isEmpty ? "Set Description" : item.setDescription.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(item.setDescription.isEmpty ? 0.4 : 0.8))
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Text(item.dayNight.rawValue.uppercased())
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("\(item.pages == 0 ? "—" : String(format: "%.1f", item.pages)) PGS")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                        if !item.castIds.isEmpty {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text("CAST: \(item.castIds.joined(separator: ","))")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(isExpanded ? CallSheetDesign.accent : CallSheetDesign.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Hide details" : "Show details")

                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Delete scene")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(stripColor)
            .overlay(
                HStack(spacing: 0) {
                    StripColorIndicator(intExt: item.intExt, dayNight: item.dayNight)
                        .frame(height: 40)
                    Spacer()
                }
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TIME OF DAY")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(CallSheetDesign.textTertiary)
                            Text(item.dayNight.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(CallSheetDesign.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("INT/EXT")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(CallSheetDesign.textTertiary)
                            Text(item.intExt.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(CallSheetDesign.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("EST. TIME")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(CallSheetDesign.textTertiary)
                            Text(item.estimatedTime.isEmpty ? "—" : item.estimatedTime)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(item.estimatedTime.isEmpty ? CallSheetDesign.textTertiary : CallSheetDesign.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("LOCATION")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(CallSheetDesign.textTertiary)
                            Text(item.location.isEmpty ? "—" : item.location)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(item.location.isEmpty ? CallSheetDesign.textTertiary : CallSheetDesign.textPrimary)
                                .lineLimit(1)
                        }
                    }

                    if !item.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(CallSheetDesign.textTertiary)
                            Text(item.notes)
                                .font(.system(size: 11))
                                .foregroundColor(CallSheetDesign.textSecondary)
                        }
                    }

                    if !item.specialRequirements.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SPECIAL REQUIREMENTS")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(CallSheetDesign.textTertiary)
                            Text(item.specialRequirements)
                                .font(.system(size: 11))
                                .foregroundColor(CallSheetDesign.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(CallSheetDesign.sectionHeader.opacity(0.3))
            }
        }
    }
}

// MARK: - Add Schedule Item Sheet

struct CallSheetAddScheduleItemSheet: View {
    @Binding var callSheet: CallSheet
    @Environment(\.dismiss) private var dismiss
    @State private var newItem = ScheduleItem.empty()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Scene")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(CallSheetDesign.textSecondary)
            }
            .padding()
            .background(CallSheetDesign.sectionHeader)

            Divider()

            ScrollView {
                VStack(spacing: CallSheetDesign.itemSpacing) {
                    HStack(spacing: 16) {
                        InlineEditableField(label: "Scene #", text: $newItem.sceneNumber, labelWidth: 80)
                        Picker("INT/EXT", selection: $newItem.intExt) {
                            ForEach(ScheduleItem.IntExt.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .frame(width: 100)
                        Picker("D/N", selection: $newItem.dayNight) {
                            ForEach(ScheduleItem.DayNight.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .frame(width: 140)
                    }

                    InlineEditableField(label: "Set Description", text: $newItem.setDescription, labelWidth: 80)
                    InlineEditableField(label: "Location", text: $newItem.location, labelWidth: 80)

                    HStack(spacing: 16) {
                        HStack {
                            Text("Pages")
                                .font(CallSheetDesign.labelFont)
                                .foregroundColor(CallSheetDesign.textSecondary)
                            TextField("0", value: $newItem.pages, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                        InlineEditableField(label: "Est. Time", text: $newItem.estimatedTime, labelWidth: 60)
                    }

                    InlineEditableField(label: "Notes", text: $newItem.notes, isMultiline: true, labelWidth: 80)
                    InlineEditableField(label: "Special Req.", text: $newItem.specialRequirements, isMultiline: true, labelWidth: 80)
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                CallSheetButton(title: "Cancel", style: .secondary) { dismiss() }
                CallSheetButton(title: "Add Scene", icon: "plus", style: .primary) {
                    newItem.sortOrder = callSheet.scheduleItems.count
                    callSheet.scheduleItems.append(newItem)
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Cast Section

struct CastSectionView: View {
    @Binding var callSheet: CallSheet
    @Environment(\.managedObjectContext) private var context
    @State private var contacts: [(name: String, role: String, phone: String, email: String)] = []
    @State private var selectedContactName: String = ""

    var body: some View {
        CallSheetSectionCard(
            title: "Cast",
            icon: "person.2",
            headerAction: nil,
            headerActionIcon: nil
        ) {
            VStack(spacing: 12) {
                // Add cast member dropdown
                HStack(spacing: 12) {
                    Text("ADD CAST")
                        .font(CallSheetDesign.labelFont)
                        .foregroundColor(CallSheetDesign.textTertiary)

                    Menu {
                        Section("From Cast Contacts") {
                            ForEach(contacts, id: \.name) { contact in
                                Button(action: { addCastMember(from: contact) }) {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                        if !contact.role.isEmpty {
                                            Text(contact.role)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 11))
                                .foregroundColor(CallSheetDesign.accent)
                            Text("Select from Contacts")
                                .font(CallSheetDesign.bodyFont)
                                .foregroundColor(CallSheetDesign.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(CallSheetDesign.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(CallSheetDesign.sectionHeader))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(CallSheetDesign.border, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 350)

                    Spacer()
                }

                if !callSheet.castMembers.isEmpty {
                    Divider()

                    // Header
                    HStack(spacing: 0) {
                        Text("#")
                            .frame(width: 30, alignment: .center)
                        Text("CHARACTER")
                            .frame(width: 120, alignment: .leading)
                        Text("ACTOR")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("STATUS")
                            .frame(width: 50, alignment: .center)
                        Text("PICKUP")
                            .frame(width: 70, alignment: .center)
                        Text("MU/HAIR")
                            .frame(width: 70, alignment: .center)
                        Text("ON SET")
                            .frame(width: 70, alignment: .center)
                        Text("")
                            .frame(width: 30)
                    }
                    .font(CallSheetDesign.labelFont)
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CallSheetDesign.sectionHeader)

                    Divider()

                    ForEach($callSheet.castMembers) { $member in
                        CastMemberRow(member: $member, onDelete: {
                            callSheet.castMembers.removeAll { $0.id == member.id }
                        })
                        Divider()
                            .background(CallSheetDesign.divider)
                    }
                }
            }
        }
        .onAppear {
            loadContacts()
        }
    }

    private func addCastMember(from contact: (name: String, role: String, phone: String, email: String)) {
        let newNumber = (callSheet.castMembers.map { $0.castNumber }.max() ?? 0) + 1
        let newMember = CastMember(
            castNumber: newNumber,
            role: contact.role,
            actorName: contact.name,
            status: .work,
            pickupTime: "",
            reportToMakeup: "",
            reportToSet: "",
            remarks: "",
            phone: contact.phone,
            email: contact.email,
            daysWorked: 1,
            isStunt: false,
            isPhotoDouble: false
        )
        callSheet.castMembers.append(newMember)
    }

    private func loadContacts() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        guard let fetchedContacts = try? context.fetch(request) else { return }

        contacts = fetchedContacts.compactMap { obj in
            guard let name = obj.value(forKey: "name") as? String, !name.isEmpty else { return nil }

            let note = obj.value(forKey: "note") as? String ?? ""
            let categoryAttr = obj.value(forKey: "category") as? String ?? ""
            let isCast = note.lowercased().contains("[cast]") || categoryAttr.lowercased() == "cast"

            guard isCast else { return nil }

            let role = obj.value(forKey: "role") as? String ?? ""
            let phone = obj.value(forKey: "phone") as? String ?? ""
            let email = obj.value(forKey: "email") as? String ?? ""
            return (name: name, role: role, phone: phone, email: email)
        }.sorted { $0.name < $1.name }
    }
}

// MARK: - Cast Member Row

struct CastMemberRow: View {
    @Binding var member: CastMember
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("\(member.castNumber)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(CallSheetDesign.accent)
                .frame(width: 30, alignment: .center)

            TextField("Role", text: $member.role)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 120, alignment: .leading)

            TextField("Actor Name", text: $member.actorName)
                .font(CallSheetDesign.bodyFont)
                .frame(maxWidth: .infinity, alignment: .leading)

            CastStatusPicker(status: $member.status)
                .frame(width: 50)

            TextField("--:--", text: $member.pickupTime)
                .font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 70)

            TextField("--:--", text: $member.reportToMakeup)
                .font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 70)

            TextField("--:--", text: $member.reportToSet)
                .font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 70)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .frame(width: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Crew Section

struct CrewSectionView: View {
    @Binding var callSheet: CallSheet
    @Environment(\.managedObjectContext) private var context
    @State private var contacts: [(name: String, phone: String, email: String, role: String)] = []
    @State private var expandedDepartments: Set<CrewDepartment> = Set(CrewDepartment.allCases)
    @State private var selectedDepartment: CrewDepartment = .camera

    private var groupedCrew: [CrewDepartment: [CrewMember]] {
        Dictionary(grouping: callSheet.crewMembers, by: { $0.department })
    }

    // Filter contacts by selected department
    private var filteredContacts: [(name: String, phone: String, email: String, role: String)] {
        let deptKeywords = selectedDepartment.roleKeywords
        return contacts.filter { contact in
            let role = contact.role.lowercased()
            return deptKeywords.isEmpty || deptKeywords.contains { role.contains($0) }
        }
    }

    var body: some View {
        CallSheetSectionCard(
            title: "Crew",
            icon: "person.3",
            headerAction: nil,
            headerActionIcon: nil
        ) {
            VStack(spacing: 12) {
                // Add crew dropdown
                HStack(spacing: 12) {
                    Text("ADD CREW")
                        .font(CallSheetDesign.labelFont)
                        .foregroundColor(CallSheetDesign.textTertiary)

                    // Department selector
                    Picker("", selection: $selectedDepartment) {
                        ForEach(CrewDepartment.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { dept in
                            Label(dept.rawValue, systemImage: dept.icon).tag(dept)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)

                    // Contact dropdown
                    Menu {
                        Section("\(selectedDepartment.rawValue) Contacts") {
                            ForEach(filteredContacts, id: \.name) { contact in
                                Button(action: { addCrewMember(from: contact) }) {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                        if !contact.role.isEmpty {
                                            Text(contact.role)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        if !filteredContacts.isEmpty {
                            Divider()
                        }

                        Section("All Contacts") {
                            ForEach(contacts, id: \.name) { contact in
                                Button(action: { addCrewMember(from: contact) }) {
                                    Text(contact.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 11))
                                .foregroundColor(CallSheetDesign.accent)
                            Text("Select from Contacts")
                                .font(CallSheetDesign.bodyFont)
                                .foregroundColor(CallSheetDesign.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(CallSheetDesign.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(CallSheetDesign.sectionHeader))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(CallSheetDesign.border, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 300)

                    Spacer()
                }

                if !callSheet.crewMembers.isEmpty {
                    Divider()

                    VStack(spacing: 8) {
                        ForEach(CrewDepartment.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { dept in
                            if let members = groupedCrew[dept], !members.isEmpty {
                                CrewDepartmentGroup(
                                    department: dept,
                                    members: Binding(
                                        get: { members },
                                        set: { newMembers in
                                            // Update the members in callSheet
                                            for member in newMembers {
                                                if let index = callSheet.crewMembers.firstIndex(where: { $0.id == member.id }) {
                                                    callSheet.crewMembers[index] = member
                                                }
                                            }
                                        }
                                    ),
                                    isExpanded: expandedDepartments.contains(dept),
                                    onToggle: {
                                        if expandedDepartments.contains(dept) {
                                            expandedDepartments.remove(dept)
                                        } else {
                                            expandedDepartments.insert(dept)
                                        }
                                    },
                                    onDeleteMember: { member in
                                        callSheet.crewMembers.removeAll { $0.id == member.id }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadContacts()
        }
    }

    private func addCrewMember(from contact: (name: String, phone: String, email: String, role: String)) {
        let newMember = CrewMember(
            department: selectedDepartment,
            position: contact.role.isEmpty ? "Crew" : contact.role,
            name: contact.name,
            phone: contact.phone,
            email: contact.email,
            callTime: "",
            notes: ""
        )
        callSheet.crewMembers.append(newMember)
        // Expand the department when adding
        expandedDepartments.insert(selectedDepartment)
    }

    private func loadContacts() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        guard let fetchedContacts = try? context.fetch(request) else { return }

        contacts = fetchedContacts.compactMap { obj in
            guard let name = obj.value(forKey: "name") as? String, !name.isEmpty else { return nil }
            let phone = obj.value(forKey: "phone") as? String ?? ""
            let email = obj.value(forKey: "email") as? String ?? ""
            let role = obj.value(forKey: "role") as? String ?? ""
            return (name: name, phone: phone, email: email, role: role)
        }.sorted { $0.name < $1.name }
    }
}

// MARK: - Crew Department Group

struct CrewDepartmentGroup: View {
    let department: CrewDepartment
    @Binding var members: [CrewMember]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDeleteMember: (CrewMember) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Department Header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: department.icon)
                        .font(.system(size: 12))
                        .foregroundColor(CallSheetDesign.accent)
                        .frame(width: 20)

                    Text(department.rawValue.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(CallSheetDesign.textSecondary)

                    Text("(\(members.count))")
                        .font(.system(size: 10))
                        .foregroundColor(CallSheetDesign.textTertiary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(CallSheetDesign.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CallSheetDesign.sectionHeader)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach($members) { $member in
                        HStack(spacing: 12) {
                            Text(member.position)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(CallSheetDesign.textSecondary)
                                .frame(width: 100, alignment: .trailing)

                            Text(member.name)
                                .font(CallSheetDesign.bodyFont)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(member.phone)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(CallSheetDesign.textSecondary)
                                .frame(width: 110)

                            TextField("--:--", text: $member.callTime)
                                .font(.system(size: 11, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .frame(width: 60)

                            Button(action: { onDeleteMember(member) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundColor(CallSheetDesign.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        Divider()
                            .background(CallSheetDesign.divider)
                    }
                }
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CallSheetDesign.border, lineWidth: 1)
        )
    }
}

// MARK: - Production Notes Section

struct ProductionNotesSectionView: View {
    @Binding var callSheet: CallSheet

    var body: some View {
        CallSheetSectionCard(title: "Production Notes", icon: "note.text") {
            VStack(alignment: .leading, spacing: CallSheetDesign.itemSpacing) {
                Text("GENERAL NOTES")
                    .font(CallSheetDesign.labelFont)
                    .foregroundColor(CallSheetDesign.textTertiary)

                TextEditor(text: $callSheet.productionNotes)
                    .font(CallSheetDesign.bodyFont)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(CallSheetDesign.sectionHeader)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CallSheetDesign.border, lineWidth: 1)
                    )

                Divider()

                Text("SPECIAL EQUIPMENT")
                    .font(CallSheetDesign.labelFont)
                    .foregroundColor(CallSheetDesign.textTertiary)

                TextEditor(text: $callSheet.specialEquipment)
                    .font(CallSheetDesign.bodyFont)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(CallSheetDesign.sectionHeader)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CallSheetDesign.border, lineWidth: 1)
                    )

                Divider()

                InlineEditableField(
                    label: "Walkie Channels",
                    text: $callSheet.walkie,
                    placeholder: "Ch1: Production, Ch2: Camera/Electric...",
                    labelWidth: 100
                )
            }
        }
    }
}

// MARK: - Advance Schedule Section

struct AdvanceScheduleSectionView: View {
    @Binding var callSheet: CallSheet

    var body: some View {
        CallSheetSectionCard(title: "Advance Schedule", icon: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's shooting next...")
                    .font(CallSheetDesign.captionFont)
                    .foregroundColor(CallSheetDesign.textTertiary)

                TextEditor(text: $callSheet.advanceSchedule)
                    .font(CallSheetDesign.bodyFont)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(CallSheetDesign.sectionHeader)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CallSheetDesign.border, lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Safety Info Section

struct SafetyInfoSectionView: View {
    @Binding var callSheet: CallSheet

    var body: some View {
        CallSheetSectionCard(title: "Safety Information", icon: "cross.circle") {
            VStack(alignment: .leading, spacing: CallSheetDesign.itemSpacing) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("SAFETY FIRST")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }

                TextEditor(text: $callSheet.safetyNotes)
                    .font(CallSheetDesign.bodyFont)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )

                // Quick add common safety notes
                HStack(spacing: 8) {
                    ForEach(["No Smoking", "Hard Hats Required", "Closed Set", "No Visitors"], id: \.self) { note in
                        Button(action: {
                            if !callSheet.safetyNotes.contains(note) {
                                callSheet.safetyNotes += (callSheet.safetyNotes.isEmpty ? "" : " | ") + note.uppercased()
                            }
                        }) {
                            Text("+ \(note)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(CallSheetDesign.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(CallSheetDesign.accent.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Background Actors Section

struct BackgroundActorsSectionView: View {
    @Binding var callSheet: CallSheet
    @Environment(\.managedObjectContext) private var context
    @State private var contacts: [(name: String, phone: String, role: String)] = []

    // Filter contacts that might be extras/background coordinators
    private var backgroundContacts: [(name: String, phone: String, role: String)] {
        let keywords = ["extra", "background", "bg", "stand-in", "photo double"]
        return contacts.filter { contact in
            let role = contact.role.lowercased()
            return keywords.contains { role.contains($0) }
        }
    }

    var body: some View {
        CallSheetSectionCard(
            title: "Background / Extras",
            icon: "person.3.sequence",
            headerAction: nil,
            headerActionIcon: nil
        ) {
            VStack(spacing: 12) {
                // Add background dropdown
                HStack(spacing: 12) {
                    Text("ADD BACKGROUND")
                        .font(CallSheetDesign.labelFont)
                        .foregroundColor(CallSheetDesign.textTertiary)

                    Menu {
                        Section("From Contacts") {
                            ForEach(backgroundContacts, id: \.name) { contact in
                                Button(action: { addBackgroundActor(from: contact) }) {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                        if !contact.role.isEmpty {
                                            Text(contact.role)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        Button(action: { addBackgroundActor(from: (name: "", phone: "", role: "")) }) {
                            Label("Add Custom Entry", systemImage: "plus.circle")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 11))
                                .foregroundColor(CallSheetDesign.accent)
                            Text("Select from Contacts")
                                .font(CallSheetDesign.bodyFont)
                                .foregroundColor(CallSheetDesign.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(CallSheetDesign.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(CallSheetDesign.sectionHeader))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(CallSheetDesign.border, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 350)

                    Spacer()
                }

                if !callSheet.backgroundActors.isEmpty {
                    Divider()

                    VStack(spacing: 8) {
                        ForEach($callSheet.backgroundActors) { $bg in
                            HStack(spacing: 12) {
                                Text("\(bg.count)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(CallSheetDesign.accent)
                                    .frame(width: 30)

                                TextField("Description", text: $bg.description)
                                    .font(CallSheetDesign.bodyFont)
                                    .frame(maxWidth: .infinity)

                                TextField("Call", text: $bg.callTime)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 60)

                                TextField("Wrap", text: $bg.wrapTime)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 60)

                                Button(action: {
                                    callSheet.backgroundActors.removeAll { $0.id == bg.id }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(CallSheetDesign.sectionHeader)
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadContacts()
        }
    }

    private func addBackgroundActor(from contact: (name: String, phone: String, role: String)) {
        let newBG = BackgroundActor(
            count: 1,
            description: contact.role.isEmpty ? "Background Actors" : contact.role,
            callTime: "",
            wrapTime: "",
            wardrobeNotes: "",
            reportTo: contact.name,
            scenes: []
        )
        callSheet.backgroundActors.append(newBG)
    }

    private func loadContacts() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        guard let fetchedContacts = try? context.fetch(request) else { return }

        contacts = fetchedContacts.compactMap { obj in
            guard let name = obj.value(forKey: "name") as? String, !name.isEmpty else { return nil }
            let phone = obj.value(forKey: "phone") as? String ?? ""
            let role = obj.value(forKey: "role") as? String ?? ""
            return (name: name, phone: phone, role: role)
        }.sorted { $0.name < $1.name }
    }
}

#endif
