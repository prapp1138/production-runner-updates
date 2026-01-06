import SwiftUI
import CoreData
import UniformTypeIdentifiers

#if os(iOS)
struct MainDashboardViewiOS: View {
    let project: NSManagedObject
    let projectFileURL: URL?

    // Safe Core Data attribute checking
    private func hasAttr(_ key: String) -> Bool { project.entity.attributesByName[key] != nil }

    private var name: String {
        if hasAttr("name") { return (project.value(forKey: "name") as? String) ?? "Untitled" }
        return "Untitled"
    }
    private var statusRaw: String {
        if hasAttr("status") { return (project.value(forKey: "status") as? String) ?? ProjectStatus.development.rawValue }
        return ProjectStatus.development.rawValue
    }
    private var status: ProjectStatus { ProjectStatus(rawValue: statusRaw) ?? .development }
    private var user: String {
        if hasAttr("user") { return (project.value(forKey: "user") as? String) ?? "—" }
        return "—"
    }
    private var created: Date? { hasAttr("createdAt") ? project.value(forKey: "createdAt") as? Date : nil }
    private var updated: Date? { hasAttr("updatedAt") ? project.value(forKey: "updatedAt") as? Date : nil }
    private var startDate: Date? { hasAttr("startDate") ? project.value(forKey: "startDate") as? Date : nil }
    private var wrapDate: Date? { hasAttr("wrapDate") ? project.value(forKey: "wrapDate") as? Date : nil }
    private var crewNames: [String] { hasAttr("crewNames") ? ((project.value(forKey: "crewNames") as? [String]) ?? []) : [] }
    private var castNames: [String] { hasAttr("castNames") ? ((project.value(forKey: "castNames") as? [String]) ?? []) : [] }
    private var vendorNames: [String] { hasAttr("vendorNames") ? ((project.value(forKey: "vendorNames") as? [String]) ?? []) : [] }

    private var aspectRatioRaw: String {
        if hasAttr("aspectRatio") { return (project.value(forKey: "aspectRatio") as? String) ?? "2.39:1" }
        return "2.39:1"
    }
    private var aspectRatio: String { aspectRatioRaw }

    private var productionCompany: String {
        if hasAttr("productionCompany") { return (project.value(forKey: "productionCompany") as? String) ?? "" }
        return ""
    }

    @AppStorage("account_role") private var accountRole: String = ""
    @AppStorage("account_name") private var accountNameStorage: String = ""
    @AppStorage("account_email") private var accountEmail: String = ""
    @AppStorage("account_phone") private var accountPhone: String = ""

    @AppStorage("header_preset") private var headerPreset: String = "Aurora"
    @AppStorage("header_hue") private var headerHue: Double = 0.58
    @AppStorage("header_intensity") private var headerIntensity: Double = 0.18

    @Environment(\.managedObjectContext) private var moc
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var projectFileStore = ProjectFileStore()

    @State private var showSettings = false
    @State private var showAccountManager = false
    @State private var showImporter = false
    @State private var showAppsDrawer = false
    @State private var importError: String?
    @State private var appSelection: AppSection? = .productionRunner

    // Dashboard app card reordering (iOS) - iOS/macOS widget-style
    @StateObject private var orderManageriOS = DashboardOrderManager()
    @State private var draggingSectioniOS: AppSection? = nil
    @State private var dropTargetSectioniOS: AppSection? = nil

    private var effectiveProjectFileURL: URL? { projectFileURL ?? projectFileStore.url }

    // MARK: - Dashboard helpers
    private func hasEntity(_ name: String) -> Bool {
        moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName[name] != nil
    }
    
    private func entityCount(_ name: String, predicate: NSPredicate? = nil) -> Int {
        guard hasEntity(name) else { return 0 }
        let req = NSFetchRequest<NSManagedObject>(entityName: name)
        req.includesSubentities = true
        req.includesPropertyValues = false
        req.predicate = predicate
        do { return try moc.count(for: req) } catch { return 0 }
    }
    
    private func locationsBreakdown() -> (total: Int, toScout: Int, scouted: Int) {
        guard hasEntity("LocationEntity") else { return (0, 0, 0) }
        let total = entityCount("LocationEntity")
        var toScout = 0
        var scouted = 0

        // Use Bool 'scouted' field from Core Data model
        toScout = entityCount("LocationEntity", predicate: NSPredicate(format: "scouted == NO"))
        scouted = entityCount("LocationEntity", predicate: NSPredicate(format: "scouted == YES"))

        return (total, toScout, scouted)
    }

    private func tasksBreakdown() -> (total: Int, pending: Int, completed: Int) {
        guard hasEntity("TaskEntity") else { return (0, 0, 0) }
        let total = entityCount("TaskEntity")
        let completed = entityCount("TaskEntity", predicate: NSPredicate(format: "isCompleted == YES"))
        let pending = total - completed
        return (total, pending, completed)
    }

    private func contactCounts() -> (cast: Int, crew: Int, vendor: Int) {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        req.includesPropertyValues = true
        do {
            let rows = try moc.fetch(req)
            guard let entity = rows.first?.entity ?? NSEntityDescription.entity(forEntityName: "ContactEntity", in: moc) else {
                return (0, 0, 0)
            }
            let attrs = entity.attributesByName
            let hasCategory = attrs["category"] != nil
            let hasNote = attrs["note"] != nil
            var cast = 0, crew = 0, vendor = 0
            for mo in rows {
                if hasCategory {
                    if let s = mo.value(forKey: "category") as? String {
                        let v = s.lowercased()
                        if v.contains("cast") { cast += 1 }
                        else if v.contains("vendor") { vendor += 1 }
                        else { crew += 1 }
                    } else if let n = mo.value(forKey: "category") as? NSNumber {
                        switch n.intValue {
                        case 0: cast += 1
                        case 1: crew += 1
                        case 2: vendor += 1
                        default: crew += 1
                        }
                    } else {
                        crew += 1
                    }
                } else if hasNote, let note = mo.value(forKey: "note") as? String {
                    let v = note.lowercased()
                    if v.contains("[cast]") || v.contains("cast:") || v.contains(" cast ") { cast += 1 }
                    else if v.contains("[crew]") || v.contains("crew:") || v.contains(" crew ") { crew += 1 }
                    else if v.contains("[vendor]") || v.contains("vendor:") || v.contains(" vendor ") { vendor += 1 }
                    else { crew += 1 }
                } else {
                    crew += 1
                }
            }
            return (cast, crew, vendor)
        } catch {
            return (0, 0, 0)
        }
    }

    private func productionScheduleInfo() -> (scheduledDays: Int, totalScenes: Int) {
        guard hasEntity("SceneEntity") else { return (0, 0) }
        
        let req = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
        do {
            let scenes = try moc.fetch(req)
            let totalScenes = scenes.count
            
            guard let entity = scenes.first?.entity ?? NSEntityDescription.entity(forEntityName: "SceneEntity", in: moc),
                  entity.attributesByName["scheduledDate"] != nil else {
                return (0, totalScenes)
            }
            
            var scheduledDates = Set<Date>()
            for scene in scenes {
                if let scheduledDate = scene.value(forKey: "scheduledDate") as? Date {
                    let calendar = Calendar.current
                    if let dayStart = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: scheduledDate)) {
                        scheduledDates.insert(dayStart)
                    }
                }
            }
            
            return (scheduledDates.count, totalScenes)
        } catch {
            return (0, 0)
        }
    }
    
    private func teamUsersCount() -> Int {
        let allNames = Set(castNames + crewNames + vendorNames)
        return allNames.count
    }

    private func currentLocationLabel() -> String {
        let tz = TimeZone.current
        let parts = tz.identifier.split(separator: "/").map(String.init)
        if parts.count >= 2 {
            return parts[1].replacingOccurrences(of: "_", with: " ")
        } else {
            return tz.identifier.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func headerGradientColors() -> (Color, Color) {
        let preset = headerPreset.lowercased()
        switch preset {
        case "sunset":
            return (Color(red: 1.0, green: 0.55, blue: 0.35).opacity(max(0.05, headerIntensity)),
                    Color(red: 0.90, green: 0.20, blue: 0.50).opacity(0.08))
        case "ocean":
            return (Color(red: 0.10, green: 0.55, blue: 0.95).opacity(max(0.05, headerIntensity)),
                    Color(red: 0.05, green: 0.30, blue: 0.60).opacity(0.08))
        case "forest":
            return (Color(red: 0.10, green: 0.65, blue: 0.30).opacity(max(0.05, headerIntensity)),
                    Color(red: 0.05, green: 0.35, blue: 0.20).opacity(0.08))
        case "midnight":
            return (Color(white: 1.0).opacity(max(0.05, headerIntensity) * 0.25),
                    Color.primary.opacity(0.06))
        case "custom":
            let start = Color(hue: headerHue, saturation: 0.65, brightness: 0.95).opacity(max(0.05, headerIntensity))
            let end = Color.primary.opacity(0.05)
            return (start, end)
        default:
            return (Color.accentColor.opacity(max(0.05, headerIntensity)),
                    Color.primary.opacity(0.05))
        }
    }

    private var headerView: some View {
        let (startC, endC) = headerGradientColors()
        let pid = project.objectID.uriRepresentation().absoluteString
        let fam = UserDefaults.standard.string(forKey: "pr.font.family.\(pid)") ?? ".SFNS"
        let sz = UserDefaults.standard.double(forKey: "pr.font.size.\(pid)")
        let pointSize = sz > 0 ? sz : 56
        let titleFont = Font.pr_build(family: fam, size: CGFloat(pointSize))
        let startText = DateFormatter.localizedString(from: startDate ?? Date(), dateStyle: .medium, timeStyle: .none)
        let wrapText  = DateFormatter.localizedString(from: wrapDate  ?? Date(), dateStyle: .medium, timeStyle: .none)
        return HStack(alignment: .top) {
            DashboardHeader(
                projectName: name,
                locationLabel: currentLocationLabel(),
                startDateText: startText,
                wrapDateText:  wrapText,
                startColor: startC,
                endColor: endC,
                titleFont: titleFont
            )

            Spacer()

            // Switch Project Button (iPad)
            Button {
                projectFileStore.url = nil
            } label: {
                Image(systemName: "rectangle.grid.2x2")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Compact Header (iPhone)
    private var compactHeaderView: some View {
        let (startC, endC) = headerGradientColors()
        let startText = DateFormatter.localizedString(from: startDate ?? Date(), dateStyle: .medium, timeStyle: .none)
        let wrapText  = DateFormatter.localizedString(from: wrapDate  ?? Date(), dateStyle: .medium, timeStyle: .none)

        return VStack(alignment: .leading, spacing: 8) {
            // Project Title Row with Switch Project button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? "Untitled Project" : name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    // Production Company (if set)
                    if !productionCompany.isEmpty {
                        Text(productionCompany)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Switch Project Button
                Button {
                    projectFileStore.url = nil
                } label: {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(.plain)
            }

            // Start and Wrap dates
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.35))
                    Text("Start:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(startText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                    Text("Wrap:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(wrapText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [startC, endC]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var accountBadge: some View {
        let displayName = accountNameStorage.isEmpty ? "Brandon" : accountNameStorage
        let displayRole = accountRole.isEmpty ? "Filmmaker" : accountRole
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text(displayRole)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private func seedAccountDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        if (defaults.string(forKey: "account_name") ?? "").isEmpty {
            let fallbackName = "Brandon Brefka"
            let userName: String
            if hasAttr("user") {
                userName = (project.value(forKey: "user") as? String) ?? fallbackName
            } else {
                userName = fallbackName
            }
            defaults.set(userName, forKey: "account_name")
        }
        if (defaults.string(forKey: "account_role") ?? "").isEmpty {
            defaults.set(accountRole.isEmpty ? "Filmmaker" : accountRole, forKey: "account_role")
        }
    }

    private func handleImport(urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ["pdf", "fdx", "celtx"].contains(ext) else {
                importError = "Unsupported file type: .\(ext). Use PDF, FDX, or CELTX."
                continue
            }
            do {
                let bookmark = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try AssetStore.addFile(
                    at: url,
                    bookmark: bookmark,
                    to: project,
                    projectFileURL: effectiveProjectFileURL,
                    in: moc
                )
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    var body: some View {
        if hSize == .compact {
            // iPhone / compact: stacked dashboard with account badge footer
            compactLayout
        } else {
            // iPad / regular: show Apps sidebar with dashboard detail
            regularLayout
        }
    }

    // MARK: - Compact Layout (iPhone)
    @ViewBuilder
    private var compactLayout: some View {
        VStack(spacing: 0) {
            // Main content area
            if appSelection == .productionRunner {
                // Dashboard view
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        compactHeaderView

                        // Quick stats summary
                        compactDashboardStats
                            .padding(.horizontal, 16)
                    }
                }
            } else {
                // Selected app content
                compactDetailView
            }

            // Bottom navigation bar
            compactBottomBar
        }
        .sheet(isPresented: $showSettings) {
            AppSettingsWindow(project: project)
        }
        .sheet(isPresented: $showAccountManager) {
            accountManagerSheet
        }
        .sheet(isPresented: $showAppsDrawer) {
            appsDrawerSheet
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType.pdf, UTType.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                handleImport(urls: urls)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "Unknown error") }
        .onAppear {
            seedAccountDefaultsIfNeeded()
            appSelection = .productionRunner
        }
    }

    // MARK: - Compact Bottom Bar (3 buttons: Home, Apps, Account)
    private var compactBottomBar: some View {
        HStack(spacing: 0) {
            // Home
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    appSelection = .productionRunner
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: appSelection == .productionRunner ? "house.fill" : "house")
                        .font(.system(size: 22, weight: .medium))
                    Text("Home")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(appSelection == .productionRunner ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Apps
            Button {
                showAppsDrawer = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: appSelection != .productionRunner ? "square.grid.2x2.fill" : "square.grid.2x2")
                        .font(.system(size: 22, weight: .medium))
                    Text("Apps")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(appSelection != .productionRunner ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Account
            Button {
                showAccountManager = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 22, weight: .medium))
                    Text("Account")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 34) // Account for home indicator
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }

    // MARK: - Apps Drawer Sheet
    private var appsDrawerSheet: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 20) {
                    ForEach(AppSection.iOSAvailableCases, id: \.self) { section in
                        Button {
                            showAppsDrawer = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    appSelection = section
                                }
                            }
                        } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    section.accentColor.opacity(0.8),
                                                    section.accentColor.opacity(0.6)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .shadow(color: section.accentColor.opacity(0.3), radius: 8, y: 4)

                                    Image(systemName: section.icon)
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                                Text(section.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAppsDrawer = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - App Dock (macOS-style bottom dock)
    private var appDock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Home/Dashboard button
                DockIcon(
                    icon: "house.fill",
                    label: "Home",
                    color: .accentColor,
                    isSelected: appSelection == .productionRunner
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        appSelection = .productionRunner
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 40)

                // App icons
                ForEach(AppSection.iOSAvailableCases, id: \.self) { section in
                    DockIcon(
                        icon: section.icon,
                        label: section.rawValue,
                        color: section.accentColor,
                        isSelected: appSelection == section
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appSelection = section
                        }
                    }
                }

                // Divider before account
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 40)

                // Account button
                DockIcon(
                    icon: "person.crop.circle.fill",
                    label: "Account",
                    color: .secondary,
                    isSelected: false
                ) {
                    showAccountManager = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Compact Dashboard Stats
    private var compactDashboardStats: some View {
        VStack(spacing: 12) {
            // Quick overview cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                CompactQuickStat(title: "Contacts", value: "\(contactCounts().cast + contactCounts().crew + contactCounts().vendor)", color: AppSection.contacts.accentColor)
                CompactQuickStat(title: "Scenes", value: "\(entityCount("SceneEntity"))", color: AppSection.breakdowns.accentColor)
                CompactQuickStat(title: "Shots", value: "\(entityCount("ShotEntity"))", color: AppSection.shotLister.accentColor)
                CompactQuickStat(title: "Locations", value: "\(locationsBreakdown().total)", color: AppSection.locations.accentColor)
            }

            // Tasks summary
            let tasks = tasksBreakdown()
            if tasks.total > 0 {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(AppSection.tasks.accentColor)
                    Text("\(tasks.pending) pending tasks")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("\(tasks.completed) done")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
    }

    // MARK: - Compact Detail View
    @ViewBuilder
    private var compactDetailView: some View {
        Group {
            switch appSelection {
            case .screenplay:
                NavigationView {
                    ScreenplayEditorView()
                        .navigationTitle("Screenplay")
                        .navigationBarTitleDisplayMode(.inline)
                }
            case .contacts:
                NavigationView {
                    ContactsViewiOS()
                        .navigationTitle("Contacts")
                        .navigationBarTitleDisplayMode(.inline)
                }
            default:
                disabledViewPlaceholder(title: appSelection?.rawValue ?? "App", icon: appSelection?.icon ?? "app")
            }
        }
    }

    // MARK: - Regular Layout (iPad)
    @ViewBuilder
    private var regularLayout: some View {
        VStack(spacing: 0) {
            // Main content area
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // Bottom dock
            iPadAppDock
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showSettings) {
            AppSettingsWindow(project: project)
        }
        .sheet(isPresented: $showAccountManager) {
            accountManagerSheet
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                handleImport(urls: urls)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "Unknown error") }
        .onAppear { seedAccountDefaultsIfNeeded() }
    }

    // MARK: - iPad App Dock (scrollable, smaller icons)
    private var iPadAppDock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Home/Dashboard button
                DockIconLarge(
                    icon: "house.fill",
                    label: "Home",
                    color: .accentColor,
                    isSelected: appSelection == .productionRunner
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        appSelection = .productionRunner
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 40)

                // App icons
                ForEach(AppSection.iOSAvailableCases, id: \.self) { section in
                    DockIconLarge(
                        icon: section.icon,
                        label: section.rawValue,
                        color: section.accentColor,
                        isSelected: appSelection == section
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appSelection = section
                        }
                    }
                }

                // Divider before account
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 40)

                // Account button
                DockIconLarge(
                    icon: "person.crop.circle.fill",
                    label: "Account",
                    color: .secondary,
                    isSelected: false
                ) {
                    showAccountManager = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        )
        .padding(.bottom, 34) // Account for home indicator
    }

    // MARK: - Account Manager Sheet
    @ViewBuilder
    private var accountManagerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account").font(.title2).bold()
            VStack(alignment: .leading, spacing: 10) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Name", text: $accountNameStorage)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Email").font(.caption).foregroundStyle(.secondary)
                TextField("Email", text: $accountEmail)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Phone").font(.caption).foregroundStyle(.secondary)
                TextField("Phone", text: $accountPhone)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Role").font(.caption).foregroundStyle(.secondary)
                TextField("Role", text: $accountRole)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button { showAccountManager = false } label: {
                    Text("Close").bold()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Detail View for iPad
    @ViewBuilder
    private var detailView: some View {
        Group {
            switch appSelection {
            case .productionRunner:
                dashboardContent
            case .screenplay:
                pageWrapper { ScreenplayEditorView() }
                    .navigationTitle("Screenplay")
            case .contacts:
                pageWrapper { ContactsViewiOS() }
                    .navigationTitle("Contacts")
            default:
                // Fallback for any other app selection
                pageWrapper { ContactsViewiOS() }
                    .navigationTitle("Contacts")
            }
        }
        .id(appSelection)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appSelection)
    }

    // MARK: - Disabled View Placeholder
    @ViewBuilder
    private func disabledViewPlaceholder(title: String, icon: String) -> some View {
        pageWrapper {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Coming Soon on iOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("This feature is available on Mac")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(title)
    }

    @ViewBuilder
    private var dashboardContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerView
                        .padding(.bottom, 8)

                    // App Grid - only showing iOS-available apps, with iOS widget-style drag-to-reorder
                    LazyVGrid(columns: adaptiveColumnsiOS(for: geometry.size.width), spacing: 16) {
                        ForEach(orderManageriOS.orderedSections.filter { AppSection.iOSAvailableCases.contains($0) }, id: \.self) { section in
                            AppCardiOS(
                                section: section,
                                dataText: dataTextForiOS(section),
                                isDragging: draggingSectioniOS == section,
                                isDropTarget: dropTargetSectioniOS == section,
                                action: { appSelection = section }
                            )
                            .draggable(AppCardDragItem(section: section)) {
                                // Drag preview - lifted card appearance
                                AppCardiOS(
                                    section: section,
                                    dataText: dataTextForiOS(section),
                                    isDragging: true,
                                    isDropTarget: false,
                                    action: {}
                                )
                                .frame(width: 160, height: 120)
                            }
                            .dropDestination(for: AppCardDragItem.self) { items, _ in
                                dropTargetSectioniOS = nil
                                guard let draggedItem = items.first,
                                      let draggedSection = draggedItem.section,
                                      draggedSection != section else {
                                    return false
                                }
                                // iOS widget-style smooth reorder animation
                                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
                                    orderManageriOS.move(from: draggedSection, to: section)
                                }
                                return true
                            } isTargeted: { isTargeted in
                                // Visual feedback when hovering over a drop target
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.15)) {
                                    dropTargetSectioniOS = isTargeted ? section : nil
                                }
                            }
                            .onDrag {
                                draggingSectioniOS = section
                                return NSItemProvider(object: section.rawValue as NSString)
                            }
                            .onChange(of: draggingSectioniOS) { newValue in
                                if newValue == nil {
                                    // Drag ended - clear drop target
                                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                        dropTargetSectioniOS = nil
                                    }
                                }
                            }
                        }
                    }
                    // iOS widget-style smooth grid reordering animation
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3), value: orderManageriOS.orderedSections)

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
        }
    }

    // MARK: - Adaptive Columns for iOS
    private func adaptiveColumnsiOS(for width: CGFloat) -> [GridItem] {
        let minCardWidth: CGFloat = 160
        let spacing: CGFloat = 16
        let padding: CGFloat = 48
        let availableWidth = width - padding

        var columnCount = Int(availableWidth / (minCardWidth + spacing))
        columnCount = max(2, min(columnCount, 4))

        return Array(repeating: GridItem(.flexible(minimum: minCardWidth), spacing: spacing), count: columnCount)
    }

    // MARK: - Data Functions for iOS Dashboard Cards
    private func screenplayDataiOS() -> String {
        guard hasEntity("SceneEntity") else { return "Import a script" }
        let sceneCount = entityCount("SceneEntity")

        if sceneCount == 0 {
            return "Import a script"
        }

        // Try to get page count estimate (approximately 1 page per scene on average)
        return "\(sceneCount) scene\(sceneCount == 1 ? "" : "s")"
    }

    private func calendarDataiOS() -> String {
        var lines: [String] = []

        if let start = startDate, let wrap = wrapDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            lines.append("\(formatter.string(from: start)) → \(formatter.string(from: wrap))")

            let today = Date()
            if today < start {
                let days = Calendar.current.dateComponents([.day], from: today, to: start).day ?? 0
                lines.append("\(days) days to start")
            } else if today <= wrap {
                let days = Calendar.current.dateComponents([.day], from: today, to: wrap).day ?? 0
                lines.append("\(days) days remaining")
            }
        }

        if hasEntity("CalendarEntity") {
            let eventCount = entityCount("CalendarEntity")
            if eventCount > 0 {
                lines.append("\(eventCount) event\(eventCount == 1 ? "" : "s")")
            }
        }

        return lines.isEmpty ? "No dates set" : lines.joined(separator: "\n")
    }

    private func contactsDataiOS() -> String {
        let counts = contactCounts()
        let total = counts.cast + counts.crew + counts.vendor

        if total == 0 {
            return "No contacts added"
        }

        var lines: [String] = []
        if counts.cast > 0 { lines.append("Cast: \(counts.cast)") }
        if counts.crew > 0 { lines.append("Crew: \(counts.crew)") }
        if counts.vendor > 0 { lines.append("Vendors: \(counts.vendor)") }

        return lines.joined(separator: "\n")
    }

    // Helper to get data text for any app section (used by drag-and-drop grid on iOS)
    private func dataTextForiOS(_ section: AppSection) -> String {
        switch section {
        case .screenplay: return screenplayDataiOS()
        case .contacts: return contactsDataiOS()
        #if INCLUDE_CALENDAR
        case .calendar: return calendarDataiOS()
        #endif
        case .breakdowns: return breakdownsDataiOS()
        default: return ""
        }
    }

    private func breakdownsDataiOS() -> String {
        guard hasEntity("SceneEntity") else { return "Import a script" }
        let sceneCount = entityCount("SceneEntity")

        if sceneCount == 0 {
            return "Import a script"
        }

        var withBreakdown = 0
        if hasEntity("BreakdownEntity") {
            withBreakdown = entityCount("BreakdownEntity")
        }

        let percentage = sceneCount > 0 ? Int((Double(withBreakdown) / Double(sceneCount)) * 100) : 0

        return "\(sceneCount) scene\(sceneCount == 1 ? "" : "s")\n\(percentage)% broken down"
    }

    private func budgetDataiOS() -> String {
        if hasEntity("BudgetEntity") {
            let req = NSFetchRequest<NSManagedObject>(entityName: "BudgetEntity")
            req.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]

            do {
                let budgets = try moc.fetch(req)
                if budgets.count > 0 {
                    var totalBudget: Double = 0

                    if hasEntity("BudgetLineItemEntity") {
                        let lineReq = NSFetchRequest<NSManagedObject>(entityName: "BudgetLineItemEntity")
                        let items = try moc.fetch(lineReq)
                        for item in items {
                            let qty = item.value(forKey: "quantity") as? Double ?? 1
                            let unitCost = item.value(forKey: "unitCost") as? Double ?? 0
                            totalBudget += qty * unitCost
                        }
                    }

                    let formatter = NumberFormatter()
                    formatter.numberStyle = .currency
                    formatter.maximumFractionDigits = 0

                    let versionText = budgets.count == 1 ? "1 version" : "\(budgets.count) versions"
                    if totalBudget > 0, let formatted = formatter.string(from: NSNumber(value: totalBudget)) {
                        return "\(formatted)\n\(versionText)"
                    }
                    return "\(versionText) created"
                }
            } catch {
                #if DEBUG
                print("Budget fetch error:", error)
                #endif
            }
        }

        guard hasEntity("BudgetCategoryEntity") else { return "No budget created" }

        let req = NSFetchRequest<NSManagedObject>(entityName: "BudgetCategoryEntity")
        do {
            let categories = try moc.fetch(req)
            if categories.isEmpty { return "No budget created" }

            var total: Double = 0
            for category in categories {
                if let amount = category.value(forKey: "totalAmount") as? Double {
                    total += amount
                }
            }

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.maximumFractionDigits = 0

            if let formattedTotal = formatter.string(from: NSNumber(value: total)) {
                return "\(formattedTotal)\n\(categories.count) categories"
            }
            return "\(categories.count) categories"
        } catch {
            return "No budget created"
        }
    }

    private func shotsDataiOS() -> String {
        let shotCount = entityCount("ShotEntity")
        let sceneCount = entityCount("SceneEntity")

        if shotCount == 0 {
            return "No shots added"
        }

        var lines = ["\(shotCount) shot\(shotCount == 1 ? "" : "s")"]

        if sceneCount > 0 {
            let avg = Double(shotCount) / Double(sceneCount)
            lines.append(String(format: "%.1f per scene", avg))
        }

        return lines.joined(separator: "\n")
    }

    private func locationsDataiOS() -> String {
        let loc = locationsBreakdown()

        if loc.total == 0 {
            return "No locations added"
        }

        let scoutedPercent = loc.total > 0 ? Int((Double(loc.scouted) / Double(loc.total)) * 100) : 0

        return "\(loc.total) location\(loc.total == 1 ? "" : "s")\n\(scoutedPercent)% scouted"
    }

    private func schedulerDataiOS() -> String {
        let sceneCount = entityCount("SceneEntity")

        var shootDays = 0
        if hasEntity("ShootDayEntity") {
            shootDays = entityCount("ShootDayEntity")
        }

        if sceneCount == 0 && shootDays == 0 {
            return "Import scenes first"
        }

        var lines: [String] = []

        if shootDays > 0 {
            lines.append("\(shootDays) shoot day\(shootDays == 1 ? "" : "s")")
        }

        if sceneCount > 0 {
            lines.append("\(sceneCount) scene\(sceneCount == 1 ? "" : "s")")
        }

        return lines.isEmpty ? "Not scheduled" : lines.joined(separator: "\n")
    }

    private func callSheetsDataiOS() -> String {
        guard hasEntity("CallSheetEntity") else { return "No call sheets" }

        let req = NSFetchRequest<NSManagedObject>(entityName: "CallSheetEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "shootDate", ascending: false)]

        do {
            let sheets = try moc.fetch(req)
            if sheets.isEmpty {
                return "No call sheets"
            }

            let count = sheets.count

            let today = Calendar.current.startOfDay(for: Date())
            if let nextSheet = sheets.first(where: { sheet in
                if let date = sheet.value(forKey: "shootDate") as? Date {
                    return date >= today
                }
                return false
            }), let shootDate = nextSheet.value(forKey: "shootDate") as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return "\(count) sheet\(count == 1 ? "" : "s")\nNext: \(formatter.string(from: shootDate))"
            }

            return "\(count) call sheet\(count == 1 ? "" : "s")"
        } catch {
            return "No call sheets"
        }
    }

    private func tasksDataiOS() -> String {
        let tasks = tasksBreakdown()

        if tasks.total == 0 {
            return "No tasks"
        }

        var lines: [String] = []

        if tasks.pending > 0 {
            lines.append("\(tasks.pending) pending")
        }
        if tasks.completed > 0 {
            lines.append("\(tasks.completed) done")
        }

        if hasEntity("TaskEntity") {
            let req = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
            req.predicate = NSPredicate(format: "isCompleted == NO AND reminderDate < %@", Date() as CVarArg)
            if let overdueCount = try? moc.count(for: req), overdueCount > 0 {
                lines.insert("⚠ \(overdueCount) overdue", at: 0)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func chatDataiOS() -> String {
        guard hasEntity("ChatMessageEntity") else { return "No messages" }

        let req = NSFetchRequest<NSManagedObject>(entityName: "ChatMessageEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let messages = try moc.fetch(req)
            if messages.isEmpty {
                return "No messages"
            }

            let count = messages.count

            if let lastMessage = messages.first,
               let timestamp = lastMessage.value(forKey: "timestamp") as? Date {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                let relativeTime = formatter.localizedString(for: timestamp, relativeTo: Date())
                return "\(count) message\(count == 1 ? "" : "s")\nLast: \(relativeTime)"
            }

            return "\(count) message\(count == 1 ? "" : "s")"
        } catch {
            return "No messages"
        }
    }

    private func paperworkDataiOS() -> String {
        guard hasEntity("PaperworkEntity") else { return "No documents" }

        let req = NSFetchRequest<NSManagedObject>(entityName: "PaperworkEntity")

        do {
            let docs = try moc.fetch(req)
            if docs.isEmpty {
                return "No documents"
            }

            let count = docs.count
            return "\(count) document\(count == 1 ? "" : "s")"
        } catch {
            return "No documents"
        }
    }

    // Scripty data - shows script supervisor tools status
    private func scriptyDataiOS() -> String {
        return "4 tools available"
    }

    private func pageWrapper<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding()
    }
}

// MARK: - Supporting Components

// App Card for iOS Dashboard - colored squares matching macOS style with iOS widget-style animations
private struct AppCardiOS: View {
    let section: AppSection
    let dataText: String
    var isDragging: Bool = false
    var isDropTarget: Bool = false
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: section.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            Text(section.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text(dataText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [section.accentColor.opacity(0.9), section.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(isDragging ? 0.6 : (isDropTarget ? 0.5 : 0.2)), lineWidth: isDragging || isDropTarget ? 2 : 1)
        )
        // iOS widget-style drag effects
        .shadow(color: .black.opacity(isDragging ? 0.3 : 0.1), radius: isDragging ? 20 : 5, y: isDragging ? 15 : 3) // Depth shadow
        .shadow(color: section.accentColor.opacity(isDragging ? 0.4 : 0.2), radius: isDragging ? 20 : 8) // Glow
        .scaleEffect(isDragging ? 1.05 : (isDropTarget ? 1.08 : 1.0))
        .rotationEffect(.degrees(isDragging ? 2 : 0)) // Subtle tilt like iOS widgets
        .opacity(isDragging ? 0.95 : (isDropTarget ? 0.7 : 1.0))
        .zIndex(isDragging ? 100 : 0)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25), value: isDragging)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: isDropTarget)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

private struct CompactStatCard: View {
    let title: String
    let value: String
    var color: Color = .accentColor
    var subtitle: String? = nil
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}

private struct StatTile: View {
    let title: String
    let count: Int
    var color: Color = .accentColor
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            Text("\(count)")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1.0 : 0.95)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

private struct ClockView: View {
    @State private var now: Date = Date()
    var timeZone: TimeZone = .current
    var locationLabel: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(locationLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            Text(timeString(now))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            
            Text(dateString(now))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }
    
    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = .current
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: d)
    }
    
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = .current
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: d)
    }
}

private struct DashboardHeader: View {
    let projectName: String
    let locationLabel: String
    let startDateText: String
    let wrapDateText: String
    let startColor: Color
    let endColor: Color
    let titleFont: Font
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [startColor, endColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(greetingMessage())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text(projectName.isEmpty ? "Untitled Project" : projectName)
                        .font(.system(size: 42, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        DateBadge(icon: "calendar", label: "Start", date: startDateText)
                        DateBadge(icon: "flag", label: "Wrap", date: wrapDateText)
                    }
                }
                
                Spacer()
                
                ClockView(locationLabel: locationLabel)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.08))
                    )
            }
            .padding(20)
        }
        .frame(minHeight: 130)
    }
    
    private func greetingMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return "Working Late"
        case 6..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Working Late"
        }
    }
}

private struct DateBadge: View {
    let icon: String
    let label: String
    let date: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            Text(date)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - Dock Icon Component (iPhone)
private struct DockIcon: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isSelected
                                ? color.opacity(0.2)
                                : Color.primary.opacity(0.06)
                        )
                        .frame(width: 56, height: 56)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? color : .secondary)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)

                // Label
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? color : .secondary)
                    .lineLimit(1)

                // Selection indicator
                Circle()
                    .fill(isSelected ? color : .clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Dock Icon Large Component (iPad)
private struct DockIconLarge: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isSelected
                                ? color.opacity(0.25)
                                : Color.primary.opacity(isHovered ? 0.1 : 0.06)
                        )
                        .frame(width: 68, height: 68)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? color : .secondary)
                }
                .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.05 : 1.0))
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)

                // Label
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? color : .secondary)
                    .lineLimit(1)

                // Selection indicator
                Circle()
                    .fill(isSelected ? color : .clear)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Compact Quick Stat Card
private struct CompactQuickStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }
}
#endif // os(iOS)
