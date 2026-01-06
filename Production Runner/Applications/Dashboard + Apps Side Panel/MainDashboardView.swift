import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Combine
#if os(macOS)
import AppKit
#endif

extension Font {
    /// Build a Font from a family/PostScript name with graceful fallback
    static func pr_build(family: String, size: CGFloat) -> Font {
        #if os(macOS)
        if let ns = NSFont(name: family, size: size) {
            return Font(ns)
        }
        #else
        if let ui = UIFont(name: family, size: size) {
            return Font(ui)
        }
        #endif
        return .system(size: size, weight: .black)
    }
}

struct MainDashboardView: View {
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
    private var startsCompleted: Int { hasAttr("startsCompleted") ? ((project.value(forKey: "startsCompleted") as? Int) ?? 0) : 0 }
    private var startsIncomplete: Int { hasAttr("startsIncomplete") ? ((project.value(forKey: "startsIncomplete") as? Int) ?? 0) : 0 }

    // NEW: Aspect Ratio (safe)
    private var aspectRatioRaw: String {
        if hasAttr("aspectRatio") { return (project.value(forKey: "aspectRatio") as? String) ?? "2.39:1" }
        return "2.39:1"
    }
    private var aspectRatio: String { aspectRatioRaw }

    @AppStorage("account_role") private var accountRole: String = ""
    @AppStorage("account_name") private var accountNameStorage: String = ""
    @AppStorage("account_email") private var accountEmail: String = ""
    @AppStorage("account_phone") private var accountPhone: String = ""
    @AppStorage("account_avatar_color") private var avatarColorHex: String = "#007AFF"
    @AppStorage("account_avatar_image") private var avatarImageData: Data?

    // Header color controls (configured in AppSettingsWindow)
    @AppStorage("header_preset") private var headerPreset: String = "Aurora" // Presets: Aurora, Sunset, Ocean, Forest, Midnight, Custom
    @AppStorage("header_hue") private var headerHue: Double = 0.58            // Used when preset == "Custom" (0.0...1.0)
    @AppStorage("header_intensity") private var headerIntensity: Double = 0.18 // Opacity for start color (0.05...0.4 recommended)

    // System Appearance Setting
    @AppStorage("app_appearance") private var appAppearance: String = "system"
    @AppStorage("app_theme") private var appTheme: String = "Standard"

    private var preferredScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    // Theme-aware sidebar colors
    private var themedSidebarTextColor: Color {
        switch currentTheme {
        case .standard: return .primary
        case .aqua: return Color(red: 0.85, green: 0.88, blue: 0.92)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .cinema: return .white  // Letterboxd uses white text
        }
    }

    private var themedSidebarSecondaryColor: Color {
        switch currentTheme {
        case .standard: return .secondary
        case .aqua: return Color(red: 0.6, green: 0.65, blue: 0.72)
        case .retro: return Color(red: 0.1, green: 0.5, blue: 0.15)
        case .neon: return Color(red: 0.5, green: 0.3, blue: 0.6)
        case .cinema: return Color(red: 0.6, green: 0.6, blue: 0.6)  // Letterboxd gray
        }
    }

    private var themedSidebarSearchBackground: Color {
        switch currentTheme {
        case .standard: return Color.primary.opacity(0.06)
        case .aqua: return Color.white.opacity(0.08)
        case .retro: return Color.green.opacity(0.05)
        case .neon: return Color.white.opacity(0.03)
        case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157).opacity(0.8)  // Letterboxd card bg
        }
    }

    private var themedSidebarSearchBorder: Color {
        switch currentTheme {
        case .standard: return Color.primary.opacity(0.12)
        case .aqua: return Color.white.opacity(0.15)
        case .retro: return Color(red: 0.1, green: 0.5, blue: 0.15).opacity(0.5)
        case .neon: return Color(red: 0.5, green: 0.3, blue: 0.6).opacity(0.4)
        case .cinema: return Color(red: 0.0, green: 0.878, blue: 0.329).opacity(0.3)  // Letterboxd green
        }
    }

    // Theme-aware dashboard content colors
    private var themedDashboardCardBackground: Color {
        switch currentTheme {
        case .standard: return Color.primary.opacity(0.03)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.08)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.06)
        case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157)  // Letterboxd card bg #1c2228
        }
    }

    private var themedDashboardCardBorder: Color {
        switch currentTheme {
        case .standard: return Color.primary.opacity(0.08)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.2)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.25)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.2)
        case .cinema: return Color(red: 0.0, green: 0.878, blue: 0.329).opacity(0.25)  // Letterboxd green
        }
    }

    private var themedDashboardAccent: Color {
        switch currentTheme {
        case .standard: return .accentColor
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .cinema: return Color(red: 0.0, green: 0.878, blue: 0.329)  // Letterboxd green #00e054
        }
    }

    private var themedDashboardSecondaryAccent: Color {
        switch currentTheme {
        case .standard: return .accentColor.opacity(0.7)
        case .aqua: return Color(red: 0.0, green: 0.55, blue: 0.70)
        case .retro: return Color(red: 0.80, green: 0.45, blue: 0.45)
        case .neon: return Color(red: 0.6, green: 0.0, blue: 1.0)
        case .cinema: return Color(red: 1.0, green: 0.502, blue: 0.0)  // Letterboxd orange #ff8000
        }
    }

    private var themedDashboardTextColor: Color {
        switch currentTheme {
        case .standard: return .primary
        case .aqua: return Color(red: 0.85, green: 0.88, blue: 0.92)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .neon: return .white
        case .cinema: return .white  // Letterboxd uses white text
        }
    }

    private var themedDashboardSecondaryTextColor: Color {
        switch currentTheme {
        case .standard: return .secondary
        case .aqua: return Color(red: 0.6, green: 0.65, blue: 0.72)
        case .retro: return Color(red: 0.1, green: 0.5, blue: 0.15)
        case .neon: return Color(red: 0.7, green: 0.7, blue: 0.8)
        case .cinema: return Color(red: 0.6, green: 0.6, blue: 0.6)  // Letterboxd gray
        }
    }

    @Environment(\.managedObjectContext) private var moc
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var projectFileStore = ProjectFileStore()
    @Environment(\.dismiss) private var dismiss
#if os(macOS)
    @Environment(\.openWindow) private var openWindow
#endif
    @State private var showProjectSettings = false
    @State private var showAppSettings = false
    @State private var showAccountManager = false
    @State private var showAddUser = false
    @State private var showImporter = false
    @State private var importError: String?
    @State private var editName: String = ""
    @State private var editUser: String = ""
    @State private var editRole: String = ""
    @State private var editStatus: ProjectStatus = .development
    @State private var editStart: Date = Date()
    @State private var editWrap: Date = Date()
    @State private var editAspectRatio: String = "2.39:1" // NEW
    @State private var newCrewName: String = ""
    @State private var newCastName: String = ""

    @State private var appSelection: AppSection? = .productionRunner
    @State private var searchText: String = ""
    @State private var showWelcomeSheet: Bool = false

    // Dashboard app card reordering - iOS/macOS widget-style
    @StateObject private var orderManager = DashboardOrderManager()
    @State private var draggingSection: AppSection? = nil
    @State private var dropTargetSection: AppSection? = nil

    private var effectiveProjectFileURL: URL? { projectFileURL ?? projectFileStore.url }

    // Project ID for tracking welcome sheet shown state
    private var projectIDString: String {
        if hasAttr("id"), let id = project.value(forKey: "id") as? UUID {
            return id.uuidString
        }
        return name // Fallback to project name
    }

    // Key for tracking if welcome has been shown for this project
    private var welcomeShownKey: String {
        "welcome_shown_\(projectIDString)"
    }

    private var filteredSections: [AppSection] {
        if searchText.isEmpty {
            return AppSection.allCases
        } else {
            return AppSection.allCases.filter { section in
                section.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func touch(_ object: NSManagedObject) {
        if object.entity.attributesByName["updatedAt"] != nil {
            object.setValue(Date(), forKey: "updatedAt")
        }
    }

    private func loadEdits() {
        editName = hasAttr("name") ? ((project.value(forKey: "name") as? String) ?? "") : ""
        editUser = hasAttr("user") ? ((project.value(forKey: "user") as? String) ?? "") : ""
        editRole = accountRole
        editStatus = ProjectStatus(rawValue: statusRaw) ?? .development
        editStart = startDate ?? Date()
        editWrap = wrapDate ?? Date()
        editAspectRatio = aspectRatio // NEW
    }

    private func saveEdits() {
        if hasAttr("name") {
            project.setValue(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : editName, forKey: "name")
        }
        if hasAttr("user") { project.setValue(editUser.isEmpty ? nil : editUser, forKey: "user") }
        if hasAttr("status") { project.setValue(editStatus.rawValue, forKey: "status") }
        if hasAttr("startDate") { if project.entity.attributesByName["startDate"] != nil { project.setValue(editStart, forKey: "startDate") } }
        if hasAttr("wrapDate") { project.setValue(editWrap, forKey: "wrapDate") }
        UserDefaults.standard.set(editRole, forKey: "account_role")
        if hasAttr("aspectRatio") { project.setValue(editAspectRatio, forKey: "aspectRatio") } // NEW
        // Touch for updatedAt locally; then save
        touch(project)
        try? moc.save()
    }

    private func addCrew(_ name: String) {
        guard hasAttr("crewNames"), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var arr = crewNames; arr.append(name)
        project.setValue(arr, forKey: "crewNames"); touch(project); try? moc.save()
    }
    private func addCast(_ name: String) {
        guard hasAttr("castNames"), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var arr = castNames; arr.append(name)
        project.setValue(arr, forKey: "castNames"); touch(project); try? moc.save()
    }
    private func removeCrew(at offsets: IndexSet) {
        guard hasAttr("crewNames") else { return }
        var arr = crewNames; arr.remove(atOffsets: offsets)
        project.setValue(arr, forKey: "crewNames"); touch(project); try? moc.save()
    }
    private func removeCast(at offsets: IndexSet) {
        guard hasAttr("castNames") else { return }
        var arr = castNames; arr.remove(atOffsets: offsets)
        project.setValue(arr, forKey: "castNames"); touch(project); try? moc.save()
    }

    // MARK: - Import handling with security-scoped bookmarks
    private func handleImport(urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ["pdf", "fdx", "celtx"].contains(ext) else {
                importError = "Unsupported file type: .\(ext). Use PDF, FDX, or CELTX."
                continue
            }
            do {
                // Create a security-scoped bookmark for persistent access
                let bookmark: Data
#if os(macOS)
                bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
#else
                bookmark = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
#endif
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

    // MARK: - Dashboard helpers (non-invasive; work even if entities don't exist)
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
        if hasEntity("LocationEntity") {
            toScout = entityCount("LocationEntity", predicate: NSPredicate(format: "scouted == NO"))
            scouted = entityCount("LocationEntity", predicate: NSPredicate(format: "scouted == YES"))
        }
        return (total, toScout, scouted)
    }

    // MARK: - Tasks Breakdown
    private func tasksBreakdown() -> (total: Int, pending: Int, completed: Int) {
        guard hasEntity("TaskEntity") else { return (0, 0, 0) }
        let total = entityCount("TaskEntity")
        let completed = entityCount("TaskEntity", predicate: NSPredicate(format: "isCompleted == YES"))
        let pending = total - completed
        return (total, pending, completed)
    }
    
    // MARK: - Fetch Upcoming Tasks
    private func upcomingTasks() -> [TaskEntity] {
        guard hasEntity("TaskEntity") else { return [] }
        let req = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        req.predicate = NSPredicate(format: "isCompleted == NO AND reminderDate != nil AND reminderDate >= %@", Date() as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "reminderDate", ascending: true)]
        req.fetchLimit = 5
        do {
            return try moc.fetch(req)
        } catch {
            #if DEBUG
            print("Fetch upcoming tasks failed:", error)
            #endif
            return []
        }
    }

    // MARK: - Data Fetching Functions for Dashboard Cards

    // Calendar data - shows upcoming events and date range
    private func calendarData() -> String {
        var lines: [String] = []

        // Show production date range
        if let start = startDate, let wrap = wrapDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            lines.append("\(formatter.string(from: start)) → \(formatter.string(from: wrap))")

            // Calculate days until start or wrap
            let today = Date()
            if today < start {
                let days = Calendar.current.dateComponents([.day], from: today, to: start).day ?? 0
                lines.append("\(days) days to start")
            } else if today <= wrap {
                let days = Calendar.current.dateComponents([.day], from: today, to: wrap).day ?? 0
                lines.append("\(days) days remaining")
            }
        }

        // Count calendar events
        if hasEntity("CalendarEntity") {
            let eventCount = entityCount("CalendarEntity")
            if eventCount > 0 {
                lines.append("\(eventCount) event\(eventCount == 1 ? "" : "s")")
            }
        }

        return lines.isEmpty ? "No dates set" : lines.joined(separator: "\n")
    }

    // Contacts data - shows breakdown by type
    private func contactsData() -> String {
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

    // Breakdowns data - shows scene count and completion
    private func breakdownsData() -> String {
        guard hasEntity("SceneEntity") else { return "Import a script" }
        let sceneCount = entityCount("SceneEntity")

        if sceneCount == 0 {
            return "Import a script"
        }

        // Check how many scenes have breakdowns
        var withBreakdown = 0
        if hasEntity("BreakdownEntity") {
            withBreakdown = entityCount("BreakdownEntity")
        }

        let percentage = sceneCount > 0 ? Int((Double(withBreakdown) / Double(sceneCount)) * 100) : 0

        return "\(sceneCount) scene\(sceneCount == 1 ? "" : "s")\n\(percentage)% broken down"
    }

    // Budget data - shows versions and total budget
    private func budgetData() -> String {
        // Try BudgetEntity first (versions)
        if hasEntity("BudgetEntity") {
            let req = NSFetchRequest<NSManagedObject>(entityName: "BudgetEntity")
            req.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]

            do {
                let budgets = try moc.fetch(req)
                if budgets.count > 0 {
                    var totalBudget: Double = 0

                    // Get line items total
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

        // Fallback to category-based budget
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

    // Shots data - shows count per scene average
    private func shotsData() -> String {
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

    // Locations data - shows scouting progress
    private func locationsData() -> String {
        let loc = locationsBreakdown()

        if loc.total == 0 {
            return "No locations added"
        }

        let scoutedPercent = loc.total > 0 ? Int((Double(loc.scouted) / Double(loc.total)) * 100) : 0

        return "\(loc.total) location\(loc.total == 1 ? "" : "s")\n\(scoutedPercent)% scouted"
    }

    // Scheduler data - shows shoot days and scenes scheduled
    private func schedulerData() -> String {
        let sceneCount = entityCount("SceneEntity")

        // Count shoot days
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

    // Call Sheets data - shows recent and count
    private func callSheetsData() -> String {
        guard hasEntity("CallSheetEntity") else { return "No call sheets" }

        let req = NSFetchRequest<NSManagedObject>(entityName: "CallSheetEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "shootDate", ascending: false)]

        do {
            let sheets = try moc.fetch(req)
            if sheets.isEmpty {
                return "No call sheets"
            }

            let count = sheets.count

            // Get next upcoming call sheet
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

    // Tasks data - shows pending with priority
    private func tasksData() -> String {
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

        // Check for overdue tasks
        if hasEntity("TaskEntity") {
            let req = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
            req.predicate = NSPredicate(format: "isCompleted == NO AND reminderDate < %@", Date() as CVarArg)
            if let overdueCount = try? moc.count(for: req), overdueCount > 0 {
                lines.insert("⚠ \(overdueCount) overdue", at: 0)
            }
        }

        return lines.joined(separator: "\n")
    }

    #if INCLUDE_CHAT
    // Chat data - shows message count and last activity
    private func chatData() -> String {
        guard hasEntity("ChatMessageEntity") else { return "No messages" }

        let req = NSFetchRequest<NSManagedObject>(entityName: "ChatMessageEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let messages = try moc.fetch(req)
            if messages.isEmpty {
                return "No messages"
            }

            let count = messages.count

            // Get time since last message
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
    #endif

    #if INCLUDE_PAPERWORK
    // Paperwork data - shows document types
    private func paperworkData() -> String {
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
    #endif

    #if INCLUDE_SCRIPTY
    // Scripty data - shows script supervisor tools status
    private func scriptyData() -> String {
        return "4 tools available"
    }
    #endif

    // Plan data - shows plan items status
    private func planData() -> String {
        return "Get started"
    }

    // Helper to get data text for any app section (used by drag-and-drop grid)
    private func dataTextFor(_ section: AppSection) -> String {
        switch section {
        #if INCLUDE_CALENDAR
        case .calendar: return calendarData()
        #endif
        case .contacts: return contactsData()
        case .breakdowns: return breakdownsData()
        case .shotLister: return shotsData()
        case .locations: return locationsData()
        case .scheduler: return schedulerData()
        case .callSheets: return callSheetsData()
        case .tasks: return tasksData()
        #if INCLUDE_PLAN
        case .plan: return planData()
        #endif
        #if INCLUDE_BUDGETING
        case .budget: return budgetData()
        #endif
        #if INCLUDE_SCRIPTY
        case .scripty: return scriptyData()
        #endif
        #if INCLUDE_CHAT
        case .chat: return chatData()
        #endif
        #if INCLUDE_PAPERWORK
        case .paperwork: return paperworkData()
        #endif
        default: return ""
        }
    }

    // MARK: - Contacts Totals (Core Data)
    private func contactTotalsCount() -> Int {
        let req = NSFetchRequest<NSFetchRequestResult>(entityName: "ContactEntity")
        req.includesSubentities = false
        do {
            return try moc.count(for: req)
        } catch {
            #if DEBUG
            print("Count ContactEntity failed:", error)
            #endif
            return 0
        }
    }

    // MARK: - Contact Totals (Core Data with graceful fallbacks)
    private func contactCounts() -> (cast: Int, crew: Int, vendor: Int) {
        // Fetch only what we need; we will inspect attributes safely
        let req = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        req.includesPropertyValues = true
        do {
            let rows = try moc.fetch(req)
            // Inspect available attributes on the entity at runtime
            guard let entity = rows.first?.entity ?? NSEntityDescription.entity(forEntityName: "ContactEntity", in: moc) else {
                return (0, 0, 0)
            }
            let attrs = entity.attributesByName
            let hasCategory = attrs["category"] != nil
            let hasNote = attrs["note"] != nil
            var cast = 0, crew = 0, vendor = 0
            for mo in rows {
                if hasCategory {
                    // Accept String or Int-based categories
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
                    // No category or note; count under crew as a safe default
                    crew += 1
                }
            }
            return (cast, crew, vendor)
        } catch {
            #if DEBUG
            print("contactCounts() failed:", error)
            #endif
            return (0, 0, 0)
        }
    }

    // Checklist item bound to actual app data where possible
    private struct TodoItem: Identifiable {
        let id = UUID()
        let title: String
        let done: Bool
    }
    private var checklistItems: [TodoItem] {
        let scenes = entityCount("SceneEntity") // Breakdowns
        let shots = entityCount("ShotEntity")
        let strips = entityCount("StripEntity") // Scheduler
        let callSheets = entityCount("CallSheetEntity")
        let loc = locationsBreakdown().total
        return [
            TodoItem(title: "Add at least 1 Cast member", done: !castNames.isEmpty),
            TodoItem(title: "Add at least 1 Crew member", done: !crewNames.isEmpty),
            TodoItem(title: "Create first Scene in Breakdowns", done: scenes > 0),
            TodoItem(title: "Add shots in Shot Lister", done: shots > 0),
            TodoItem(title: "Add at least 1 Location", done: loc > 0),
            TodoItem(title: "Build a Schedule (strips)", done: strips > 0),
            TodoItem(title: "Create a Call Sheet", done: callSheets > 0)
        ]
    }

    // MARK: - Assigned Tasks (for current user)
    private struct AssignedTaskItem: Identifiable {
        let id: UUID
        let title: String
        let notes: String?
        let dueDate: Date?
        let isOverdue: Bool
    }

    private func fetchAssignedTasks() -> [AssignedTaskItem] {
        guard hasEntity("TaskEntity") else { return [] }

        let currentUserName = accountNameStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentUserName.isEmpty else { return [] }

        let req = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "assignedTo ==[cd] %@", currentUserName),
            NSPredicate(format: "isCompleted == NO")
        ])
        req.sortDescriptors = [NSSortDescriptor(key: "reminderDate", ascending: true)]
        req.fetchLimit = 5

        do {
            let tasks = try moc.fetch(req)
            let today = Calendar.current.startOfDay(for: Date())

            return tasks.compactMap { task in
                guard let id = task.value(forKey: "id") as? UUID,
                      let title = task.value(forKey: "title") as? String else { return nil }

                let notes = task.value(forKey: "notes") as? String
                let dueDate = task.value(forKey: "reminderDate") as? Date
                let isOverdue = dueDate != nil && dueDate! < today

                return AssignedTaskItem(id: id, title: title, notes: notes, dueDate: dueDate, isOverdue: isOverdue)
            }
        } catch {
            #if DEBUG
            print("Fetch assigned tasks error:", error)
            #endif
            return []
        }
    }

    // MARK: - Project Updates
    private struct ProjectUpdate: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let timestamp: Date
        let color: Color
    }

    private func fetchProjectUpdates() -> [ProjectUpdate] {
        var updates: [ProjectUpdate] = []

        // Check for recent script imports (safe attribute check)
        if hasEntity("SceneEntity") {
            if let entity = NSEntityDescription.entity(forEntityName: "SceneEntity", in: moc),
               entity.attributesByName["createdAt"] != nil {
                let req = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
                req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                req.fetchLimit = 1
                if let scenes = try? moc.fetch(req), let lastScene = scenes.first,
                   let createdAt = lastScene.value(forKey: "createdAt") as? Date,
                   Calendar.current.isDateInThisWeek(createdAt) {
                    let sceneCount = entityCount("SceneEntity")
                    updates.append(ProjectUpdate(
                        icon: "doc.text.fill",
                        title: "Script Imported",
                        detail: "\(sceneCount) scenes added",
                        timestamp: createdAt,
                        color: .blue
                    ))
                }
            }
        }

        // Check for recent budget changes (safe attribute check)
        if hasEntity("BudgetEntity") {
            if let entity = NSEntityDescription.entity(forEntityName: "BudgetEntity", in: moc),
               entity.attributesByName["modifiedDate"] != nil {
                let req = NSFetchRequest<NSManagedObject>(entityName: "BudgetEntity")
                req.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
                req.fetchLimit = 1
                if let budgets = try? moc.fetch(req), let lastBudget = budgets.first,
                   let modifiedDate = lastBudget.value(forKey: "modifiedDate") as? Date,
                   Calendar.current.isDateInThisWeek(modifiedDate) {
                    let versionCount = entityCount("BudgetEntity")
                    updates.append(ProjectUpdate(
                        icon: "dollarsign.circle.fill",
                        title: "Budget Updated",
                        detail: "\(versionCount) version\(versionCount == 1 ? "" : "s")",
                        timestamp: modifiedDate,
                        color: .green
                    ))
                }
            }
        }

        // Check for recent call sheets (uses shootDate, not createdAt)
        if hasEntity("CallSheetEntity") {
            let req = NSFetchRequest<NSManagedObject>(entityName: "CallSheetEntity")
            req.sortDescriptors = [NSSortDescriptor(key: "shootDate", ascending: false)]
            req.fetchLimit = 1
            if let sheets = try? moc.fetch(req), let lastSheet = sheets.first,
               let shootDate = lastSheet.value(forKey: "shootDate") as? Date,
               Calendar.current.isDateInThisWeek(shootDate) {
                let sheetCount = entityCount("CallSheetEntity")
                updates.append(ProjectUpdate(
                    icon: "doc.badge.clock.fill",
                    title: "Call Sheet Created",
                    detail: "\(sheetCount) call sheet\(sheetCount == 1 ? "" : "s")",
                    timestamp: shootDate,
                    color: .orange
                ))
            }
        }

        // Check for recent location additions (safe attribute check)
        if hasEntity("LocationEntity") {
            let req = NSFetchRequest<NSManagedObject>(entityName: "LocationEntity")
            if let entity = NSEntityDescription.entity(forEntityName: "LocationEntity", in: moc),
               entity.attributesByName["createdAt"] != nil {
                req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                req.fetchLimit = 1
                if let locations = try? moc.fetch(req), let lastLoc = locations.first,
                   let createdAt = lastLoc.value(forKey: "createdAt") as? Date,
                   Calendar.current.isDateInThisWeek(createdAt) {
                    let locCount = entityCount("LocationEntity")
                    updates.append(ProjectUpdate(
                        icon: "mappin.circle.fill",
                        title: "Location Added",
                        detail: "\(locCount) total location\(locCount == 1 ? "" : "s")",
                        timestamp: createdAt,
                        color: .purple
                    ))
                }
            }
        }

        // Check for recent shot additions (safe attribute check)
        if hasEntity("ShotEntity") {
            let req = NSFetchRequest<NSManagedObject>(entityName: "ShotEntity")
            if let entity = NSEntityDescription.entity(forEntityName: "ShotEntity", in: moc),
               entity.attributesByName["createdAt"] != nil {
                req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                req.fetchLimit = 1
                if let shots = try? moc.fetch(req), let lastShot = shots.first,
                   let createdAt = lastShot.value(forKey: "createdAt") as? Date,
                   Calendar.current.isDateInThisWeek(createdAt) {
                    let shotCount = entityCount("ShotEntity")
                    updates.append(ProjectUpdate(
                        icon: "camera.fill",
                        title: "Shots Updated",
                        detail: "\(shotCount) total shot\(shotCount == 1 ? "" : "s")",
                        timestamp: createdAt,
                        color: .red
                    ))
                }
            }
        }

        // Sort by most recent first
        return updates.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Clean, Minimal Design Components

    // App card for dashboard - colored rectangles matching AppSection colors with data
    private struct AppCard: View {
        let section: AppSection
        let dataText: String
        var theme: AppAppearance.Theme = .standard
        var isDragging: Bool = false
        var isDropTarget: Bool = false
        var action: () -> Void
        @State private var isHovered = false

        // iOS/macOS widget-style drag animation
        private var dragRotation: Double {
            isDragging ? Double.random(in: -2...2) : 0
        }

        var body: some View {
            Group {
                switch theme {
                case .standard:
                    standardCardContent
                case .aqua:
                    aquaCardContent
                case .neon:
                    neonCardContent
                case .retro:
                    retroCardContent
                case .cinema:
                    cinemaCardContent
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .onHover { hovering in
                isHovered = hovering
                #if os(macOS)
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
                #endif
            }
        }

        // MARK: - Standard Theme Card
        private var standardCardContent: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                }

                Text(section.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer()

                Text(dataText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(alignment: .leading)
            .frame(width: 140, height: 140)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [section.accentColor.opacity(0.8), section.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(section.accentColor.opacity(0.4), lineWidth: 1)
            )
            // iOS/macOS widget-style drag effects
            .shadow(color: .black.opacity(isDragging ? 0.3 : 0.1), radius: isDragging ? 20 : 5, y: isDragging ? 15 : 3) // Depth shadow
            .shadow(color: section.accentColor.opacity(isDragging ? 0.4 : (isHovered ? 0.25 : 0.1)), radius: isDragging ? 25 : (isHovered ? 12 : 6)) // Glow
            .scaleEffect(isDragging ? 1.05 : (isDropTarget ? 1.08 : (isHovered ? 1.02 : 1.0)))
            .rotationEffect(.degrees(isDragging ? 2 : 0)) // Subtle tilt like iOS widgets
            .opacity(isDragging ? 0.95 : (isDropTarget ? 0.7 : 1.0))
            .zIndex(isDragging ? 100 : 0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25), value: isDragging)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: isDropTarget)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }

        // MARK: - Aqua Theme Card (Brushed Metal Style)
        private var aquaCardContent: some View {
            let aquaBlue = Color(red: 0.3, green: 0.6, blue: 1.0)

            return VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Gel-style icon container
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.4, green: 0.7, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                Ellipse()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.6), Color.white.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                                    .frame(width: 28, height: 14)
                                    .offset(y: -6)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.4), Color.black.opacity(0.3)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )

                        Image(systemName: section.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 1, y: 1)
                    }
                    Spacer()
                }

                Text(section.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.9, green: 0.92, blue: 0.95))
                    .shadow(color: Color.black.opacity(0.5), radius: 1, y: 1)
                    .lineLimit(1)

                Spacer()

                Text(dataText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.7, green: 0.75, blue: 0.82))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(alignment: .leading)
            .frame(width: 140, height: 140)
            .padding(12)
            .background(
                ZStack {
                    // Brushed metal base
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.32, green: 0.35, blue: 0.40),
                                    Color(red: 0.25, green: 0.28, blue: 0.32),
                                    Color(red: 0.28, green: 0.31, blue: 0.35),
                                    Color(red: 0.22, green: 0.25, blue: 0.28)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Subtle cyan glow at bottom
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, aquaBlue.opacity(isHovered ? 0.2 : 0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.black.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // iOS/macOS widget-style drag effects
            .shadow(color: .black.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 20 : 6, y: isDragging ? 15 : 4)
            .shadow(color: aquaBlue.opacity(isDragging ? 0.5 : (isHovered ? 0.35 : 0.15)), radius: isDragging ? 25 : (isHovered ? 15 : 8))
            .scaleEffect(isDragging ? 1.05 : (isDropTarget ? 1.08 : (isHovered ? 1.02 : 1.0)))
            .rotationEffect(.degrees(isDragging ? 2 : 0))
            .opacity(isDragging ? 0.95 : (isDropTarget ? 0.7 : 1.0))
            .zIndex(isDragging ? 100 : 0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25), value: isDragging)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: isDropTarget)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }

        // MARK: - Neon Theme Card (RGB Glow Style)
        private var neonCardContent: some View {
            let neonPink = Color(red: 1.0, green: 0.2, blue: 0.6)
            let neonCyan = Color(red: 0.0, green: 0.8, blue: 1.0)

            return VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Glowing icon
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [neonPink, neonCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: neonPink.opacity(0.8), radius: isHovered ? 10 : 5)
                        .shadow(color: neonCyan.opacity(0.5), radius: isHovered ? 6 : 3)
                    Spacer()
                }

                Text(section.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: neonPink.opacity(0.5), radius: 4)
                    .lineLimit(1)

                Spacer()

                Text(dataText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.7, green: 0.7, blue: 0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(alignment: .leading)
            .frame(width: 140, height: 140)
            .padding(12)
            .background(
                ZStack {
                    // Pure black base
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.05, green: 0.05, blue: 0.08))

                    // RGB corner glows
                    GeometryReader { geo in
                        ZStack {
                            // Top-left pink glow
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [neonPink.opacity(isHovered ? 0.4 : 0.2), Color.clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: geo.size.width * 0.4
                                    )
                                )
                                .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                                .offset(x: -geo.size.width * 0.15, y: -geo.size.height * 0.1)

                            // Bottom-right cyan glow
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [neonCyan.opacity(isHovered ? 0.3 : 0.15), Color.clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: geo.size.width * 0.4
                                    )
                                )
                                .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                                .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [neonPink.opacity(0.5), neonCyan.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 2 : 1
                    )
            )
            // iOS/macOS widget-style drag effects
            .shadow(color: .black.opacity(isDragging ? 0.4 : 0.2), radius: isDragging ? 20 : 8, y: isDragging ? 15 : 5)
            .shadow(color: neonPink.opacity(isDragging ? 0.6 : (isHovered ? 0.4 : 0.15)), radius: isDragging ? 30 : (isHovered ? 20 : 10))
            .scaleEffect(isDragging ? 1.05 : (isDropTarget ? 1.08 : (isHovered ? 1.02 : 1.0)))
            .rotationEffect(.degrees(isDragging ? 2 : 0))
            .opacity(isDragging ? 0.95 : (isDropTarget ? 0.7 : 1.0))
            .zIndex(isDragging ? 100 : 0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25), value: isDragging)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: isDropTarget)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }

        // MARK: - Retro Theme Card (80s Terminal Style)
        private var retroCardContent: some View {
            let retroGreen = Color(red: 0.2, green: 1.0, blue: 0.3)
            let retroAmber = Color(red: 0.95, green: 0.6, blue: 0.2)

            return VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Terminal-style icon with scanline effect
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black)
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(retroGreen.opacity(0.6), lineWidth: 1)
                            )

                        Image(systemName: section.icon)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(retroGreen)
                            .shadow(color: retroGreen.opacity(0.8), radius: isHovered ? 5 : 2)
                    }
                    Spacer()
                }

                Text("> \(section.rawValue)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(retroGreen)
                    .shadow(color: retroGreen.opacity(0.5), radius: 2)
                    .lineLimit(1)

                Spacer()

                Text(dataText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(retroAmber.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(alignment: .leading)
            .frame(width: 140, height: 140)
            .padding(12)
            .background(
                ZStack {
                    // CRT black
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.02, green: 0.02, blue: 0.02))

                    // Phosphor glow
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [retroGreen.opacity(isHovered ? 0.15 : 0.08), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )

                    // Scanlines
                    GeometryReader { geo in
                        VStack(spacing: 2) {
                            ForEach(0..<Int(geo.size.height / 4), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.black.opacity(0.15))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(retroGreen.opacity(isHovered ? 0.6 : 0.4), lineWidth: 1)
            )
            // iOS/macOS widget-style drag effects
            .shadow(color: .black.opacity(isDragging ? 0.4 : 0.2), radius: isDragging ? 18 : 6, y: isDragging ? 12 : 4)
            .shadow(color: retroGreen.opacity(isDragging ? 0.5 : (isHovered ? 0.35 : 0.15)), radius: isDragging ? 22 : (isHovered ? 15 : 8))
            .scaleEffect(isDragging ? 1.05 : (isDropTarget ? 1.08 : (isHovered ? 1.02 : 1.0)))
            .rotationEffect(.degrees(isDragging ? 1.5 : 0))
            .opacity(isDragging ? 0.95 : (isDropTarget ? 0.7 : 1.0))
            .zIndex(isDragging ? 100 : 0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25), value: isDragging)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: isDropTarget)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }

        // MARK: - Cinema Theme Card (Letterboxd Style)
        private var cinemaCardContent: some View {
            // Letterboxd colors
            let lbGreen = Color(red: 0.0, green: 0.878, blue: 0.329)      // #00e054
            let lbOrange = Color(red: 1.0, green: 0.502, blue: 0.0)       // #ff8000
            let lbCardBg = Color(red: 0.110, green: 0.133, blue: 0.157)   // #1c2228
            let lbLightGray = Color(red: 0.6, green: 0.6, blue: 0.6)

            return VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Clean Letterboxd-style icon container
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(lbGreen.opacity(isHovered ? 0.2 : 0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: section.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(lbGreen)
                    }
                    Spacer()

                    // Orange accent dot (like Letterboxd's activity indicators)
                    Circle()
                        .fill(lbOrange)
                        .frame(width: 6, height: 6)
                }

                Text(section.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(dataText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(lbLightGray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(alignment: .leading)
            .frame(width: 140, height: 140)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(lbCardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(lbGreen.opacity(isDragging ? 0.6 : (isDropTarget ? 0.5 : (isHovered ? 0.4 : 0.2))), lineWidth: isDragging || isDropTarget ? 2 : 1)
            )
            // iOS/macOS widget-style drag effects
            .shadow(color: .black.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 18 : 5, y: isDragging ? 12 : 3)
            .shadow(color: lbGreen.opacity(isDragging ? 0.4 : (isHovered ? 0.2 : 0.1)), radius: isDragging ? 20 : (isHovered ? 10 : 5))
            .scaleEffect(isDragging ? 1.05 : (isDropTarget ? 1.08 : (isHovered ? 1.02 : 1.0)))
            .rotationEffect(.degrees(isDragging ? 1.5 : 0))
            .opacity(isDragging ? 0.95 : (isDropTarget ? 0.7 : 1.0))
            .zIndex(isDragging ? 100 : 0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25), value: isDragging)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: isDropTarget)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }

    // Minimal stat card for black background dashboard
    private struct MinimalStatCard: View {
        let title: String
        let value: String
        var color: Color = .white
        var theme: AppAppearance.Theme = .standard
        @State private var isHovered = false

        private var cardBackground: Color {
            switch theme {
            case .standard: return Color.white.opacity(isHovered ? 0.03 : 0.01)
            case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(isHovered ? 0.08 : 0.04)
            case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(isHovered ? 0.08 : 0.04)
            case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(isHovered ? 0.06 : 0.03)
            case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157).opacity(isHovered ? 1.0 : 0.8)  // Letterboxd card bg
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.0)

                Text(value)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(color.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    // Compact stat card for refined dashboard
    private struct CompactStatCard: View {
        let title: String
        let value: String
        var color: Color = .accentColor
        var subtitle: String? = nil
        var theme: AppAppearance.Theme = .standard
        @State private var isHovered = false

        private var cardBackground: Color {
            switch theme {
            case .standard: return color.opacity(0.08)
            case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.12)
            case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.12)
            case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.10)
            case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157)  // Letterboxd card bg #1c2228
            }
        }

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
                    .fill(cardBackground)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    // Clean stat card with simple indicator dot (NO GLOW)
    private struct StatCard: View {
        let title: String
        let value: String
        var color: Color = .accentColor
        var theme: AppAppearance.Theme = .standard
        @State private var isHovered = false

        private var cardBackground: Color {
            switch theme {
            case .standard: return Color.primary.opacity(0.03)
            case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
            case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.08)
            case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.06)
            case .cinema: return Color(red: 0.7, green: 0.15, blue: 0.2).opacity(0.08)
            }
        }

        private var cardBorder: Color {
            switch theme {
            case .standard: return Color.primary.opacity(0.08)
            case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.2)
            case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.25)
            case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.2)
            case .cinema: return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.25)
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    // Simple solid circle - NO GLOW
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)

                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Text(value)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            .padding(18)
            .frame(minWidth: 160, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    private struct SectionCard<Content: View>: View {
        let title: String
        var icon: String? = nil
        var theme: AppAppearance.Theme = .standard
        @ViewBuilder var content: Content

        private var cardBackground: Color {
            switch theme {
            case .standard: return Color.primary.opacity(0.03)
            case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
            case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.08)
            case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.06)
            case .cinema: return Color(red: 0.7, green: 0.15, blue: 0.2).opacity(0.08)
            }
        }

        private var cardBorder: Color {
            switch theme {
            case .standard: return Color.primary.opacity(0.08)
            case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.2)
            case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.25)
            case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.2)
            case .cinema: return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.25)
            }
        }

        private var iconColor: Color {
            switch theme {
            case .standard: return .secondary
            case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85)
            case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2)
            case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6)
            case .cinema: return Color(red: 0.85, green: 0.65, blue: 0.2)
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                content
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var accountBadge: some View {
        let displayName = accountNameStorage.isEmpty ? "Brandon" : accountNameStorage
        let displayRole = accountRole.isEmpty ? "Filmmaker" : accountRole
        HStack(spacing: 12) {
            // Avatar with photo or initials
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                avatarColor.opacity(0.8),
                                avatarColor.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                if let imageData = avatarImageData,
                   let image = loadAvatarImage(from: imageData) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(avatarInitials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
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

    // Helper computed properties and methods for avatar
    private var avatarColor: Color {
        hexToColor(avatarColorHex)
    }

    private var avatarInitials: String {
        let components = accountNameStorage.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    private func hexToColor(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    #if os(macOS)
    private func loadAvatarImage(from data: Data) -> Image? {
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
    }
    #else
    private func loadAvatarImage(from data: Data) -> Image? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
    #endif


    @ViewBuilder
    private var minimalistAccountBadge: some View {
        let displayName = accountNameStorage.isEmpty ? "Brandon" : accountNameStorage
        let displayRole = accountRole.isEmpty ? "Filmmaker" : accountRole
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.accentColor)
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    // NEW: City label from timezone (used by the live clock)
    private func currentLocationLabel() -> String {
        let tz = TimeZone.current
        let parts = tz.identifier.split(separator: "/").map(String.init)
        if parts.count >= 2 {
            return parts[1].replacingOccurrences(of: "_", with: " ")
        } else {
            return tz.identifier.replacingOccurrences(of: "_", with: " ")
        }
    }

    // Compute header gradient colors from settings (theme-aware)
    private func headerGradientColors() -> (Color, Color) {
        let preset = headerPreset.lowercased()
        switch preset {
        case "sunset":
            return (Color(red: 1.0, green: 0.55, blue: 0.35).opacity(max(0.35, headerIntensity * 2.5)),
                    Color(red: 0.90, green: 0.20, blue: 0.50).opacity(0.25))
        case "ocean":
            return (Color(red: 0.10, green: 0.55, blue: 0.95).opacity(max(0.35, headerIntensity * 2.5)),
                    Color(red: 0.05, green: 0.30, blue: 0.60).opacity(0.25))
        case "forest":
            return (Color(red: 0.10, green: 0.65, blue: 0.30).opacity(max(0.35, headerIntensity * 2.5)),
                    Color(red: 0.05, green: 0.35, blue: 0.20).opacity(0.25))
        case "midnight":
            return (Color(white: 0.9).opacity(max(0.35, headerIntensity * 2.5)),
                    Color.white.opacity(0.15))
        case "custom":
            let start = Color(hue: headerHue, saturation: 0.75, brightness: 0.95).opacity(max(0.35, headerIntensity * 2.5))
            let end = Color(hue: headerHue, saturation: 0.6, brightness: 0.75).opacity(0.25)
            return (start, end)
        default: // "Aurora" - uses theme-aware colors
            let themeAccent = themedDashboardAccent
            let themeSecondary = themedDashboardSecondaryAccent
            return (themeAccent.opacity(max(0.35, headerIntensity * 2.5)),
                    themeSecondary.opacity(0.25))
        }
    }

    // Prebuilt gradient header view to avoid trailing-closure hacks in ViewBuilder
    private var headerView: some View {
        let (startC, endC) = headerGradientColors()
        // Typography (per-project) — read stored font family/size
        let pid = project.objectID.uriRepresentation().absoluteString
        let fam = UserDefaults.standard.string(forKey: "pr.font.family.\(pid)") ?? ".SFNS"
        let sz = UserDefaults.standard.double(forKey: "pr.font.size.\(pid)")
        let pointSize = sz > 0 ? sz : 56
        let titleFont = Font.pr_build(family: fam, size: CGFloat(pointSize))
        let startText = DateFormatter.localizedString(from: startDate ?? Date(), dateStyle: .medium, timeStyle: .none)
        let wrapText  = DateFormatter.localizedString(from: wrapDate  ?? Date(), dateStyle: .medium, timeStyle: .none)
        let prodCompany = (project.value(forKey: "productionCompany") as? String) ?? ""
        return DashboardHeader(
            projectName: name,
            productionCompany: prodCompany,
            locationLabel: currentLocationLabel(),
            startDateText: startText,
            wrapDateText:  wrapText,
            startColor: startC,
            endColor: endC,
            titleFont: titleFont,
            onProjectSettings: { showProjectSettings = true },
            theme: currentTheme
        )
    }

    // MARK: - Apps Sidebar (icons with text below)
    private var appsSidebar: some View {
        ZStack {
            // Background layer
            SidebarBackground()
                .ignoresSafeArea()

            // Content layer
            VStack(spacing: 0) {
                // App list
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(AppSection.allCases) { section in
                            sidebarTile(for: section)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }

                Spacer(minLength: 0)

                // Account button at bottom
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 12)
                    Button {
                        showAccountManager = true
                    } label: {
                        collapsedAccountAvatar
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Sidebar Tile (icon with text below)
    private func sidebarTile(for section: AppSection) -> some View {
        let isActive = appSelection == section
        let sectionColor = section.accentColor

        return Button {
            appSelection = section
        } label: {
            VStack(spacing: 4) {
                // Icon with background
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? sectionColor.opacity(0.15) : Color.clear)
                        .frame(width: 48, height: 48)

                    Image(systemName: section.icon)
                        .font(.system(size: 22, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(isActive ? sectionColor : themedSidebarSecondaryColor)
                }

                // Title below icon
                Text(section.rawValue)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? themedSidebarTextColor : themedSidebarSecondaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 84, height: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper: Extract Initials
    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    // MARK: - Collapsed Account Avatar
    private var collapsedAccountAvatar: some View {
        let displayName = accountNameStorage.isEmpty ? "Brandon" : accountNameStorage

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            avatarColor.opacity(0.8),
                            avatarColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)

            if let imageData = avatarImageData {
                #if os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(initials(from: displayName))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                #else
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(initials(from: displayName))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                #endif
            } else {
                Text(initials(from: displayName))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            // Sidebar - fixed width with icons and text below
            appsSidebar
                .frame(width: 100)

            Divider()

            // Main content area - show settings or app selection
            if showProjectSettings {
                ProjectSettingsFullView(project: project, onBack: { showProjectSettings = false })
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                selectionView()
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                    .focusedValue(\.activeAppSection, appSelection)
            }
        }
        .frame(minWidth: 1400, minHeight: 600)
        .sheet(isPresented: $showAppSettings) {
            AppSettingsView()
                .preferredColorScheme(preferredScheme)
        }
        .sheet(isPresented: $showAccountManager) {
            AccountSheet()
                .preferredColorScheme(preferredScheme)
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
        .sheet(isPresented: $showWelcomeSheet) {
            WelcomeSheet(projectID: projectIDString)
                .preferredColorScheme(preferredScheme)
        }
        .onAppear {
            seedAccountDefaultsIfNeeded()
            // Default landing section when opening a project
            appSelection = .productionRunner

            // Show welcome sheet if not previously shown for this project
            if !UserDefaults.standard.bool(forKey: welcomeShownKey) {
                // Small delay to let the view settle before showing the sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showWelcomeSheet = true
                }
            }
        }
        .onChange(of: appAppearance) { newValue in
            print("🎨 MainDashboardView: Appearance changed to \(newValue)")
            AppAppearance.apply(newValue)
        }
        .preferredColorScheme(preferredScheme)
        .enableTooltips()
        #else
        // Use dedicated iOS view for iPhone and iPad
        MainDashboardViewiOS(project: project, projectFileURL: projectFileURL)
        #endif
    }

    // MARK: - LEGACY iOS CODE (now handled by MainDashboardViewiOS)
    #if false
    private var legacyiOSCode: some View {
        if hSize == .compact {
            // iPhone / compact: stacked dashboard with account badge footer
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Gradient header with project info
                        headerView

                        // Team Overview section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.3")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(themedDashboardAccent)
                                Text("Team Overview")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }

                            VStack(spacing: 10) {
                                StatTile(title: "Cast", count: contactCounts().cast, color: .red, theme: currentTheme)
                                StatTile(title: "Crew", count: contactCounts().crew, color: .blue, theme: currentTheme)
                                StatTile(title: "Vendors", count: contactCounts().vendor, color: .green, theme: currentTheme)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themedDashboardCardBackground)
                        )

                        // Locations & Tasks section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                StatTile(title: "Locations", count: locationsBreakdown().total, color: .purple, theme: currentTheme)
                                StatTile(title: "Tasks", count: tasksBreakdown().pending, color: .orange, theme: currentTheme)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themedDashboardCardBackground)
                        )

                        // Production Schedule section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(themedDashboardAccent)
                                Text("Production Schedule")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Scheduled Days")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text("\(productionScheduleInfo().scheduledDays)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.green)
                                        .monospacedDigit()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.08))
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Total Scenes")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text("\(productionScheduleInfo().totalScenes)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.blue)
                                        .monospacedDigit()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.08))
                                )
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themedDashboardCardBackground)
                        )
                        
                        // Team section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.2")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.purple)
                                Text("Team")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Users")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("\(teamUsersCount())")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.purple)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple.opacity(0.08))
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.04))
                        )

                    }
                    .padding()
                }
                Divider().padding(.horizontal, 12)
                Button { showAccountManager = true } label: { accountBadge }
                    .buttonStyle(.plain)
                    .padding(12)
            }
            .sheet(isPresented: $showProjectSettings) {
                AppSettingsWindow(project: project)
                    .preferredColorScheme(preferredScheme)
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
                // Default landing section when opening a project
                appSelection = .productionRunner
            }
            .onChange(of: appAppearance) { newValue in
                AppAppearance.apply(newValue)
            }
            .preferredColorScheme(preferredScheme)
        } else {
            // iPad / regular: show bottom dock with dashboard detail (macOS dock style)
            VStack(spacing: 0) {
                iOSDetailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                // Bottom dock
                iOSBottomDock
            }
            .edgesIgnoringSafeArea(.bottom)
            .sheet(isPresented: $showProjectSettings) {
                AppSettingsWindow(project: project)
                    .preferredColorScheme(preferredScheme)
            }
            .sheet(isPresented: $showAccountManager) {
                AccountSheet()
                    .preferredColorScheme(preferredScheme)
            }
            .sheet(isPresented: $showAddUser) {
                TeamManagementSheet()
                    .environment(\.managedObjectContext, moc)
                    .preferredColorScheme(preferredScheme)
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
            .onChange(of: appAppearance) { newValue in
                AppAppearance.apply(newValue)
            }
            .preferredColorScheme(preferredScheme)
        }
    }
    #endif
    // END LEGACY iOS CODE

    private func pageWrapper<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
    }

    // MARK: - Toolbar Helper
    #if os(macOS)
    private func applyStandardToolbar<V: View>(to view: V, title: String, icon: String) -> some View {
        view.toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                }
            }

            ToolbarItem(placement: .principal) {
                // Project name
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            ToolbarItemGroup(placement: .automatic) {
                // Add User button (only show on Dashboard)
                if title == "Dashboard" {
                    Button {
                        showAddUser = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                    }
                    .customTooltip("Add User")
                }

                Button {
                    showAppSettings = true
                } label: {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 16))
                }
                .customTooltip("App Settings")

                Button {
                    projectFileStore.url = nil
                    openWindow(id: "projects")
                } label: {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 16))
                }
                .customTooltip("Projects")
            }
        }
    }

    @ToolbarContentBuilder
    private func standardToolbar(title: String, icon: String) -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.title2.weight(.semibold))
            }
        }
        ToolbarItem(placement: .principal) {
            Text(name)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        ToolbarItemGroup(placement: .automatic) {
            // Add User button (only show on Dashboard)
            if title == "Dashboard" {
                Button {
                    showAddUser = true
                } label: {
                    Label("Add User", systemImage: "person.badge.plus")
                }
            }

            Button {
                showAppSettings = true
            } label: {
                Label("App Settings", systemImage: "wrench.and.screwdriver")
            }
            Button {
                projectFileStore.url = nil
                openWindow(id: "projects")
            } label: {
                Label("Projects", systemImage: "rectangle.grid.2x2")
            }
        }
    }
    #else
    // iOS version - simpler toolbar to avoid ambiguity
    private func applyIOSToolbar<V: View>(to view: V, title: String, icon: String) -> some View {
        view
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if title == "Dashboard" {
                            Button {
                                showAddUser = true
                            } label: {
                                Label("Add User", systemImage: "person.badge.plus")
                            }
                        }
                        Button {
                            showAppSettings = true
                        } label: {
                            Label("App Settings", systemImage: "wrench.and.screwdriver")
                        }
                        Button {
                            projectFileStore.url = nil
                        } label: {
                            Label("Projects", systemImage: "rectangle.grid.2x2")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
    }
    #endif

    #if os(macOS)
    @ViewBuilder
    private func selectionView() -> some View {
        switch appSelection {
        case .none:
            applyStandardToolbar(to: pageWrapper { ContactsView() }.navigationTitle(""), title: "Contacts", icon: "person.2")
        case .productionRunner:
            applyStandardToolbar(to: macOSDashboardDetail.navigationTitle(""), title: "Dashboard", icon: "chart.bar.doc.horizontal")
        #if INCLUDE_CALENDAR
        case .calendar:
            applyStandardToolbar(to: CalendarView(project: project).navigationTitle(""), title: "Calendar", icon: "calendar")
        #endif
        case .screenplay:
            applyStandardToolbar(to: ScreenplayEditorView().navigationTitle(""), title: "Screenplay", icon: "text.page.fill")
        case .contacts:
            applyStandardToolbar(to: pageWrapper { ContactsView() }.navigationTitle(""), title: "Contacts", icon: "person.2")
        case .breakdowns:
            applyStandardToolbar(to: Breakdowns().navigationTitle(""), title: "Breakdowns", icon: "rectangle.3.group")
        #if INCLUDE_SCRIPTY
        case .scripty:
            applyStandardToolbar(to: pageWrapper { Scripty(project: project) }.navigationTitle(""), title: "Scripty", icon: "pencil.and.list.clipboard")
        #endif
        #if INCLUDE_BUDGETING
        case .budget:
            applyStandardToolbar(to: pageWrapper { BudgetView() }.navigationTitle(""), title: "Budgeting", icon: "dollarsign.circle")
        #endif
        case .shotLister:
            applyStandardToolbar(to: pageWrapper { ShotListerView(projectID: project.objectID) }.navigationTitle(""), title: "Shots", icon: "video")
        case .locations:
            applyStandardToolbar(to: pageWrapper { LocationsView() }.navigationTitle(""), title: "Locations", icon: "mappin.circle")
        case .scheduler:
            applyStandardToolbar(to: pageWrapper { SchedulerView(projectID: project.objectID) }.navigationTitle(""), title: "Scheduler", icon: "calendar")
        case .callSheets:
            applyStandardToolbar(to: pageWrapper { CallSheetsView(projectID: project.objectID) }.navigationTitle(""), title: "Call Sheets", icon: "doc.text")
        case .tasks:
            applyStandardToolbar(to: pageWrapper { TasksView() }.navigationTitle(""), title: "Tasks", icon: "checklist")
        #if INCLUDE_CHAT
        case .chat:
            applyStandardToolbar(to: pageWrapper { ChatView() }.navigationTitle(""), title: "Chat", icon: "bubble.left.and.bubble.right")
        #endif
        #if INCLUDE_PAPERWORK
        case .paperwork:
            applyStandardToolbar(to: pageWrapper { PaperworkView() }.navigationTitle(""), title: "Paperwork", icon: "doc.badge.ellipsis")
        #endif
        #if INCLUDE_LIVE_MODE
        case .liveMode:
            applyStandardToolbar(to: LiveMode().navigationTitle(""), title: "Live Mode", icon: "record.circle")
        #endif
        #if INCLUDE_PLAN
        case .plan:
            applyStandardToolbar(to: pageWrapper { PlanView() }.navigationTitle(""), title: "Plan", icon: "list.bullet.clipboard")
        #endif
        @unknown default:
            applyStandardToolbar(to: pageWrapper { ContactsView() }.navigationTitle(""), title: "Contacts", icon: "person.2")
        }
    }
    #endif

    // Clean checklist with minimal design
    private struct ChecklistItemRow: View {
        let item: TodoItem
        let index: Int
        @State private var appeared = false
        
        var body: some View {
            HStack(spacing: 12) {
                // Simple checkbox - no glow
                ZStack {
                    Circle()
                        .strokeBorder(item.done ? Color.green : Color.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(item.done ? Color.green.opacity(0.1) : Color.clear)
                        )
                    
                    if item.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.green)
                    }
                }
                
                Text(item.title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .strikethrough(item.done, color: .secondary)
                
                Spacer()
                
                if !item.done {
                    Text("Pending")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.done ? Color.green.opacity(0.04) : Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        item.done ? Color.green.opacity(0.2) : Color.primary.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .scaleEffect(appeared ? 1.0 : 0.98)
            .opacity(appeared ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.04)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - iOS iPad Sidebar (Icon Only)
    #if os(iOS)
    @ViewBuilder
    private var iOSIconSidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(AppSection.allCases) { section in
                        AppSectionTileiOS(section: section, isSelected: appSelection == section) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                appSelection = section
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)

            Divider().padding(.horizontal, 4)

            Button { showAccountManager = true } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
        .frame(width: 52)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - iOS Bottom Dock (macOS-style, scrollable)
    @ViewBuilder
    private var iOSBottomDock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Home/Dashboard button
                DockIconiPad(
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
                ForEach(AppSection.allCases.filter { $0 != .productionRunner }) { section in
                    DockIconiPad(
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
                DockIconiPad(
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - iOS iPad Detail View
    @ViewBuilder
    private var iOSDetailView: some View {
        switch appSelection {
        case .none, .productionRunner:
            iOSDashboardContent
        #if INCLUDE_CALENDAR
        case .calendar:
            iOSDisabledPlaceholder(title: "Calendar", icon: "calendar")
        #endif
        case .screenplay:
            iOSDisabledPlaceholder(title: "Screenplay", icon: "text.page.fill")
        case .contacts:
            pageWrapper { ContactsViewiOS() }
        case .breakdowns:
            BreakdownsiOS()
        #if INCLUDE_SCRIPTY
        case .scripty:
            iOSDisabledPlaceholder(title: "Scripty", icon: "pencil.and.list.clipboard")
        #endif
        #if INCLUDE_BUDGETING
        case .budget:
            iOSDisabledPlaceholder(title: "Budget", icon: "dollarsign.circle")
        #endif
        case .shotLister:
            pageWrapper { ShotsView(projectID: project.objectID) }
        case .locations:
            iOSDisabledPlaceholder(title: "Locations", icon: "mappin.and.ellipse")
        case .scheduler:
            iOSDisabledPlaceholder(title: "Scheduler", icon: "calendar.badge.clock")
        case .callSheets:
            iOSDisabledPlaceholder(title: "Call Sheets", icon: "doc.text.fill")
        case .tasks:
            iOSDisabledPlaceholder(title: "Tasks", icon: "checklist")
        #if INCLUDE_CHAT
        case .chat:
            iOSDisabledPlaceholder(title: "Chat", icon: "bubble.left.and.bubble.right")
        #endif
        #if INCLUDE_PAPERWORK
        case .paperwork:
            iOSDisabledPlaceholder(title: "Paperwork", icon: "doc.text.fill")
        #endif
        #if INCLUDE_LIVE_MODE
        case .liveMode:
            iOSDisabledPlaceholder(title: "Live Mode", icon: "record.circle")
        #endif
        #if INCLUDE_PLAN
        case .plan:
            iOSDisabledPlaceholder(title: "Plan", icon: "list.bullet.clipboard")
        #endif
        }
    }

    @ViewBuilder
    private func iOSDisabledPlaceholder(title: String, icon: String) -> some View {
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

    @ViewBuilder
    private var iOSDashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                    .padding(.bottom, 8)

                // Team Overview
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text("Team Overview")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    HStack(spacing: 12) {
                        CompactStatCardiOS(title: "Cast", value: "\(contactCounts().cast)", color: .red)
                        CompactStatCardiOS(title: "Crew", value: "\(contactCounts().crew)", color: .blue)
                        CompactStatCardiOS(title: "Vendors", value: "\(contactCounts().vendor)", color: .green)
                    }

                    HStack(spacing: 12) {
                        CompactStatCardiOS(title: "Locations", value: "\(locationsBreakdown().total)", color: .purple)
                        CompactStatCardiOS(title: "Tasks", value: "\(tasksBreakdown().pending)", color: .orange)
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

                // Production Schedule
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.green)
                        Text("Production Schedule")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    HStack(spacing: 12) {
                        CompactStatCardiOS(title: "Scheduled Days", value: "\(productionScheduleInfo().scheduledDays)", color: .green)
                        CompactStatCardiOS(title: "Total Scenes", value: "\(productionScheduleInfo().totalScenes)", color: .indigo)
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

                Spacer(minLength: 20)
            }
            .padding(20)
        }
    }
    #endif

    @ViewBuilder
    private var macOSDashboardDetail: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Gradient header with Aura effect
                    headerView

                    // App Grid - Responsive columns based on available width, with iOS/macOS widget-style drag-to-reorder
                    LazyVGrid(columns: adaptiveColumns(for: geometry.size.width), spacing: 12) {
                        ForEach(orderManager.orderedSections, id: \.self) { section in
                            AppCard(
                                section: section,
                                dataText: dataTextFor(section),
                                theme: currentTheme,
                                isDragging: draggingSection == section,
                                isDropTarget: dropTargetSection == section,
                                action: { appSelection = section }
                            )
                            .draggable(AppCardDragItem(section: section)) {
                                // Drag preview - lifted card appearance
                                AppCard(
                                    section: section,
                                    dataText: dataTextFor(section),
                                    theme: currentTheme,
                                    isDragging: true,
                                    isDropTarget: false,
                                    action: {}
                                )
                                .frame(width: 140, height: 140)
                            }
                            .dropDestination(for: AppCardDragItem.self) { items, _ in
                                dropTargetSection = nil
                                guard let draggedItem = items.first,
                                      let draggedSection = draggedItem.section,
                                      draggedSection != section else {
                                    return false
                                }
                                // iOS widget-style smooth reorder animation
                                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
                                    orderManager.move(from: draggedSection, to: section)
                                }
                                return true
                            } isTargeted: { isTargeted in
                                // Visual feedback when hovering over a drop target
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.15)) {
                                    dropTargetSection = isTargeted ? section : nil
                                }
                            }
                            .onDrag {
                                draggingSection = section
                                return NSItemProvider(object: section.rawValue as NSString)
                            }
                            .onChange(of: draggingSection) { newValue in
                                if newValue == nil {
                                    // Drag ended - clear drop target
                                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                        dropTargetSection = nil
                                    }
                                }
                            }
                        }
                    }
                    // iOS/macOS widget-style smooth grid reordering animation
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3), value: orderManager.orderedSections)

                    // Assigned to Me & Project Updates - Side by side
                    HStack(alignment: .top, spacing: 20) {
                        assignedToMeSection
                        projectUpdatesSection
                    }

                    // Active Users Section
                    activeUsersSection

                    Spacer(minLength: 40)
                }
                .padding(32)
            }
            .background(ThemedDashboardBackground(theme: currentTheme))
        }
        .clipped()
    }

    // MARK: - Assigned to Me Section
    @ViewBuilder
    private var assignedToMeSection: some View {
        let tasks = fetchAssignedTasks()

        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themedDashboardAccent)
                Text("Assigned to Me")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themedDashboardTextColor)

                Spacer()

                if !tasks.isEmpty {
                    Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(themedDashboardAccent.opacity(0.15))
                        )
                }

                Button {
                    appSelection = .tasks
                } label: {
                    Text("View All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(themedDashboardAccent)
                }
                .buttonStyle(.plain)
            }

            // Task list
            if tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                    Text("No tasks assigned")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                    Text("Tasks assigned to you will appear here")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(themedDashboardSecondaryTextColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themedDashboardCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(themedDashboardCardBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(task.isOverdue ? Color.red : themedDashboardAccent)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(themedDashboardTextColor)
                                    .lineLimit(1)

                                if let dueDate = task.dueDate {
                                    let formatter = DateFormatter()
                                    let _ = formatter.dateFormat = "MMM d"
                                    Text(task.isOverdue ? "Overdue: \(formatter.string(from: dueDate))" : "Due: \(formatter.string(from: dueDate))")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(task.isOverdue ? Color.red : themedDashboardSecondaryTextColor)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(themedDashboardCardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(task.isOverdue ? Color.red.opacity(0.3) : themedDashboardCardBorder, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Project Updates Section
    @ViewBuilder
    private var projectUpdatesSection: some View {
        let updates = fetchProjectUpdates()

        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themedDashboardAccent)
                Text("Project Updates")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themedDashboardTextColor)

                Spacer()

                if !updates.isEmpty {
                    Text("This week")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(themedDashboardAccent.opacity(0.15))
                        )
                }
            }

            // Updates list
            if updates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                    Text("All caught up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                    Text("Recent project changes will appear here")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(themedDashboardSecondaryTextColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themedDashboardCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(themedDashboardCardBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(updates) { update in
                        HStack(spacing: 12) {
                            Image(systemName: update.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(update.color)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(update.color.opacity(0.15))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(update.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(themedDashboardTextColor)

                                Text(update.detail)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(themedDashboardSecondaryTextColor)
                            }

                            Spacer()

                            let formatter = RelativeDateTimeFormatter()
                            let _ = formatter.unitsStyle = .abbreviated
                            Text(formatter.localizedString(for: update.timestamp, relativeTo: Date()))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(themedDashboardSecondaryTextColor.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(themedDashboardCardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(themedDashboardCardBorder, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Active Users Section
    @ViewBuilder
    private var activeUsersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themedDashboardAccent)
                Text("Active Users")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themedDashboardTextColor)

                Spacer()

                Text("\(activeUsers().count) online")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themedDashboardSecondaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    )
            }

            // Users grid
            if activeUsers().isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                    Text("No active users")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedDashboardSecondaryTextColor)
                    Text("Users will appear here when they're online")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(themedDashboardSecondaryTextColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themedDashboardCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(themedDashboardCardBorder, lineWidth: 1)
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeUsers(), id: \.id) { user in
                            ActiveUserCard(user: user, theme: currentTheme)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 0)
    }

    // Fetch active users from contacts
    private func activeUsers() -> [ActiveUser] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        req.includesPropertyValues = true
        req.fetchLimit = 10 // Show max 10 active users
        req.fetchBatchSize = 10
        req.returnsObjectsAsFaults = true

        do {
            let contacts = try moc.fetch(req)
            guard let entity = contacts.first?.entity ?? NSEntityDescription.entity(forEntityName: "ContactEntity", in: moc) else {
                return []
            }

            let attrs = entity.attributesByName
            let hasName = attrs["name"] != nil
            let hasRole = attrs["role"] != nil
            let hasCategory = attrs["category"] != nil

            return contacts.compactMap { contact in
                guard hasName else { return nil }
                let name = (contact.value(forKey: "name") as? String) ?? "Unknown"
                let role = hasRole ? ((contact.value(forKey: "role") as? String) ?? "Team Member") : "Team Member"
                let category = hasCategory ? ((contact.value(forKey: "category") as? String) ?? "Crew") : "Crew"

                return ActiveUser(
                    id: UUID(),
                    name: name,
                    role: role,
                    category: category,
                    isOnline: Bool.random() // Simulate online status - can be enhanced later
                )
            }
        } catch {
            #if DEBUG
            print("Failed to fetch active users:", error)
            #endif
            return []
        }
    }

    // Helper function to calculate adaptive columns based on available width
    private func adaptiveColumns(for width: CGFloat) -> [GridItem] {
        let minCardWidth: CGFloat = 100  // Minimum width for each card (smaller icons allow tighter packing)
        let spacing: CGFloat = 10
        let padding: CGFloat = 48  // Total horizontal padding (24 on each side)
        let availableWidth = width - padding

        // Calculate how many columns can fit
        var columnCount = Int(availableWidth / (minCardWidth + spacing))
        columnCount = max(1, min(columnCount, 8))  // Between 1 and 8 columns

        return Array(repeating: GridItem(.flexible(minimum: minCardWidth), spacing: spacing), count: columnCount)
    }

    // MARK: - Opera-Style Gradient Background
    private struct LiveEarthAtNightBackground: View {
        @Environment(\.colorScheme) private var colorScheme

        // Gradient colors - warm orange to cool blue (adapts to color scheme)
        private var gradientColors: [Color] {
            if colorScheme == .dark {
                // Dark mode - deeper, more saturated colors
                return [
                    Color(red: 0.85, green: 0.35, blue: 0.1),    // Deep orange
                    Color(red: 0.75, green: 0.2, blue: 0.35),    // Deep coral
                    Color(red: 0.45, green: 0.15, blue: 0.55),   // Deep purple
                    Color(red: 0.15, green: 0.2, blue: 0.6),     // Deep blue
                    Color(red: 0.08, green: 0.25, blue: 0.7)     // Bright blue
                ]
            } else {
                // Light mode - softer, more vibrant colors
                return [
                    Color(red: 1.0, green: 0.55, blue: 0.3),     // Warm orange
                    Color(red: 0.98, green: 0.45, blue: 0.55),   // Coral/salmon
                    Color(red: 0.75, green: 0.4, blue: 0.75),    // Purple transition
                    Color(red: 0.4, green: 0.5, blue: 0.92),     // Blue
                    Color(red: 0.3, green: 0.6, blue: 0.98)      // Bright blue
                ]
            }
        }

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Overlay glow effects for depth
                    ZStack {
                        // Top-left orange glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [gradientColors[0].opacity(0.6), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geometry.size.width * 0.5
                                )
                            )
                            .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                            .offset(x: -geometry.size.width * 0.25, y: -geometry.size.height * 0.2)

                        // Bottom-right blue glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [gradientColors[4].opacity(0.5), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geometry.size.width * 0.6
                                )
                            )
                            .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                            .offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.3)

                        // Center purple accent
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [gradientColors[2].opacity(0.35), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geometry.size.width * 0.4
                                )
                            )
                            .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.5)
                            .offset(x: geometry.size.width * 0.1, y: geometry.size.height * 0.1)

                        // Additional accent for visual interest
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [gradientColors[1].opacity(0.3), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geometry.size.width * 0.3
                                )
                            )
                            .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                            .offset(x: -geometry.size.width * 0.1, y: geometry.size.height * 0.25)
                    }

                    // Subtle noise/texture overlay for depth
                    Rectangle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.03))
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Theme-Aware Dashboard Background
    private struct ThemedDashboardBackground: View {
        let theme: AppAppearance.Theme
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            GeometryReader { geometry in
                switch theme {
                case .standard:
                    // Standard uses the Opera-style gradient (LiveEarthAtNightBackground style)
                    standardBackground(geometry: geometry)
                case .aqua:
                    aquaBackground(geometry: geometry)
                case .neon:
                    neonBackground(geometry: geometry)
                case .retro:
                    retroBackground(geometry: geometry)
                case .cinema:
                    cinemaBackground(geometry: geometry)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }

        // Standard - Black, blue, and orange gradient background
        @ViewBuilder
        private func standardBackground(geometry: GeometryProxy) -> some View {
            // Orange colors
            let lightOrange = Color(red: 1.0, green: 0.5, blue: 0.0)    // Vivid orange
            let darkOrange = Color(red: 0.8, green: 0.4, blue: 0.0)     // Rich orange

            // Blue colors
            let lightBlue = Color(red: 0.0, green: 0.5, blue: 1.0)      // Bright blue
            let darkBlue = Color(red: 0.0, green: 0.3, blue: 0.8)       // Deep blue

            // Black base for both modes
            let baseColor = Color.black
            let spotOrange = colorScheme == .dark ? darkOrange : lightOrange
            let spotBlue = colorScheme == .dark ? darkBlue : lightBlue

            // Adjust opacity based on color scheme
            let primaryOpacity = colorScheme == .dark ? 0.8 : 0.7
            let secondaryOpacity = colorScheme == .dark ? 0.4 : 0.3

            ZStack {
                // Black base
                baseColor

                // Orange spot - top left
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [spotOrange.opacity(primaryOpacity), spotOrange.opacity(secondaryOpacity), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width * 0.5
                        )
                    )
                    .frame(width: geometry.size.width * 0.85, height: geometry.size.width * 0.85)
                    .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.25)

                // Blue spot - top right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [spotBlue.opacity(primaryOpacity), spotBlue.opacity(secondaryOpacity), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width * 0.5
                        )
                    )
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                    .offset(x: geometry.size.width * 0.35, y: -geometry.size.height * 0.15)

                // Blue spot - bottom center (creates depth with the black)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [spotBlue.opacity(primaryOpacity * 0.6), spotBlue.opacity(secondaryOpacity * 0.5), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width * 0.5
                        )
                    )
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                    .offset(x: geometry.size.width * 0.05, y: geometry.size.height * 0.4)

                // Orange accent - bottom right for balance
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [spotOrange.opacity(primaryOpacity * 0.5), spotOrange.opacity(secondaryOpacity * 0.4), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width * 0.4
                        )
                    )
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                    .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.35)
            }
        }

        // Aqua - Dark brushed metal with cyan accents
        @ViewBuilder
        private func aquaBackground(geometry: GeometryProxy) -> some View {
            let aquaBlue = Color(red: 0.0, green: 0.75, blue: 0.85)

            ZStack {
                // Base dark brushed metal gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.16, blue: 0.18),
                        Color(red: 0.10, green: 0.12, blue: 0.14),
                        Color(red: 0.08, green: 0.10, blue: 0.12),
                        Color(red: 0.06, green: 0.08, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Subtle brushed metal texture lines
                VStack(spacing: 2) {
                    ForEach(0..<150, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(Double.random(in: 0.01...0.03)))
                            .frame(height: 1)
                    }
                }
                .opacity(0.5)

                // Aqua glow accents
                Circle()
                    .fill(RadialGradient(colors: [aquaBlue.opacity(0.15), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.4))
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.1)

                Circle()
                    .fill(RadialGradient(colors: [aquaBlue.opacity(0.1), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.5))
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                    .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.4)
            }
        }

        // Neon - Dark with RGB glow effects
        @ViewBuilder
        private func neonBackground(geometry: GeometryProxy) -> some View {
            let neonPink = Color(red: 1.0, green: 0.2, blue: 0.6)
            let neonPurple = Color(red: 0.6, green: 0.0, blue: 1.0)
            let neonCyan = Color(red: 0.0, green: 1.0, blue: 0.9)

            ZStack {
                // Deep black base
                Color.black

                // RGB glow effects
                Circle()
                    .fill(RadialGradient(colors: [neonPink.opacity(0.25), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.5))
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                    .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.15)

                Circle()
                    .fill(RadialGradient(colors: [neonPurple.opacity(0.2), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.6))
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                    .offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.3)

                Circle()
                    .fill(RadialGradient(colors: [neonCyan.opacity(0.12), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.35))
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                    .offset(x: geometry.size.width * 0.1, y: geometry.size.height * 0.5)

                // Scanline effect
                VStack(spacing: 4) {
                    ForEach(0..<100, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.02))
                            .frame(height: 1)
                    }
                }
            }
        }

        // Retro - Pure black with green terminal glow
        @ViewBuilder
        private func retroBackground(geometry: GeometryProxy) -> some View {
            let retroGreen = Color(red: 0.2, green: 1.0, blue: 0.3)

            ZStack {
                // Pure black base (CRT black)
                Color.black

                // Green terminal glow from corners
                Circle()
                    .fill(RadialGradient(colors: [retroGreen.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.5))
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                    .offset(x: -geometry.size.width * 0.25, y: -geometry.size.height * 0.2)

                Circle()
                    .fill(RadialGradient(colors: [retroGreen.opacity(0.05), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.4))
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                    .offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.35)

                // CRT scanline effect
                VStack(spacing: 2) {
                    ForEach(0..<200, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 1)
                    }
                }
                .opacity(0.4)

                // Subtle vignette
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.4)],
                    center: .center,
                    startRadius: geometry.size.width * 0.3,
                    endRadius: geometry.size.width * 0.8
                )
            }
        }

        // Cinema - Letterboxd Style (dark with green/orange accents)
        @ViewBuilder
        private func cinemaBackground(geometry: GeometryProxy) -> some View {
            // Letterboxd colors
            let lbGreen = Color(red: 0.0, green: 0.878, blue: 0.329)      // #00e054
            let lbOrange = Color(red: 1.0, green: 0.502, blue: 0.0)       // #ff8000
            let lbDarkBg = Color(red: 0.078, green: 0.094, blue: 0.110)   // #14181c

            ZStack {
                // Solid dark background like Letterboxd
                lbDarkBg

                // Subtle green glow accent (very subtle, Letterboxd is mostly flat)
                Circle()
                    .fill(RadialGradient(colors: [lbGreen.opacity(0.06), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.5))
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                    .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.2)

                // Subtle orange glow accent
                Circle()
                    .fill(RadialGradient(colors: [lbOrange.opacity(0.04), Color.clear], center: .center, startRadius: 0, endRadius: geometry.size.width * 0.4))
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                    .offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.4)
            }
        }
    }

    // MARK: - Minimalist Header
    private var minimalistHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Project name
            Text(name.isEmpty ? "Untitled Project" : name)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.black)

            // Dates row
            HStack(spacing: 24) {
                if let start = startDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.black.opacity(0.5))
                        Text(DateFormatter.localizedString(from: start, dateStyle: .medium, timeStyle: .none))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }

                if let wrap = wrapDate {
                    HStack(spacing: 6) {
                        Image(systemName: "flag")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.black.opacity(0.5))
                        Text(DateFormatter.localizedString(from: wrap, dateStyle: .medium, timeStyle: .none))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Production Schedule Info
    private func productionScheduleInfo() -> (scheduledDays: Int, totalScenes: Int) {
        guard hasEntity("SceneEntity") else { return (0, 0) }
        
        let req = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
        do {
            let scenes = try moc.fetch(req)
            let totalScenes = scenes.count
            
            // Check if scheduledDate attribute exists before trying to access it
            guard let entity = scenes.first?.entity ?? NSEntityDescription.entity(forEntityName: "SceneEntity", in: moc),
                  entity.attributesByName["scheduledDate"] != nil else {
                // If scheduledDate doesn't exist, return 0 scheduled days
                return (0, totalScenes)
            }
            
            // Get unique scheduled dates from scenes
            var scheduledDates = Set<Date>()
            for scene in scenes {
                if let scheduledDate = scene.value(forKey: "scheduledDate") as? Date {
                    // Normalize to start of day
                    let calendar = Calendar.current
                    if let dayStart = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: scheduledDate)) {
                        scheduledDates.insert(dayStart)
                    }
                }
            }
            
            return (scheduledDates.count, totalScenes)
        } catch {
            #if DEBUG
            print("Failed to fetch production schedule info:", error)
            #endif
            return (0, 0)
        }
    }
    
    // MARK: - Team Users Count
    private func teamUsersCount() -> Int {
        // Count unique users from the team
        // This combines Cast + Crew + Vendor names
        let allNames = Set(castNames + crewNames + vendorNames)
        return allNames.count
    }

    private func formatted(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}

// Local small tile used on the overview page (scoped to this file)
private struct AppSectionTileSmall: View {
    var section: AppSection
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .renderingMode(.template)
                    .imageScale(.medium)
                    .font(.system(size: 16))
                    .frame(width: 22, height: 18)
                Text(section.rawValue)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clean Minimalist Header Design

private struct ClockView: View {
    @State private var now: Date = Date()
    var timeZone: TimeZone = .current
    var locationLabel: String
    var theme: AppAppearance.Theme = .standard

    // Theme-aware text colors
    private var primaryTextColor: Color {
        switch theme {
        case .standard:
            return .white
        case .aqua:
            return Color(red: 0.9, green: 0.92, blue: 0.95)
        case .neon:
            return .white
        case .retro:
            return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .cinema:
            return Color(red: 0.95, green: 0.9, blue: 0.85)
        }
    }

    private var secondaryTextColor: Color {
        switch theme {
        case .standard:
            return .white.opacity(0.7)
        case .aqua:
            return Color(red: 0.7, green: 0.75, blue: 0.82)
        case .neon:
            return Color(red: 0.8, green: 0.8, blue: 0.9)
        case .retro:
            return Color(red: 0.1, green: 0.6, blue: 0.2)
        case .cinema:
            return Color(red: 0.85, green: 0.65, blue: 0.2)
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                Text(locationLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .fixedSize()

            Text(timeString(now))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primaryTextColor)
                .fixedSize()

            Text(dateString(now))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
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
    let productionCompany: String
    let locationLabel: String
    let startDateText: String
    let wrapDateText: String
    let startColor: Color
    let endColor: Color
    let titleFont: Font
    let onProjectSettings: () -> Void
    var theme: AppAppearance.Theme = .standard

    @Environment(\.colorScheme) private var colorScheme

    // Theme-aware gradient colors for header background
    private var gradientColors: [Color] {
        switch theme {
        case .standard:
            // Original opera-style gradient (warm orange to cool blue)
            if colorScheme == .dark {
                return [
                    Color(red: 0.95, green: 0.4, blue: 0.15),
                    Color(red: 0.85, green: 0.25, blue: 0.4),
                    Color(red: 0.55, green: 0.2, blue: 0.6),
                    Color(red: 0.2, green: 0.3, blue: 0.75),
                    Color(red: 0.15, green: 0.4, blue: 0.85)
                ]
            } else {
                return [
                    Color(red: 1.0, green: 0.5, blue: 0.25),
                    Color(red: 0.95, green: 0.4, blue: 0.5),
                    Color(red: 0.7, green: 0.35, blue: 0.7),
                    Color(red: 0.35, green: 0.45, blue: 0.9),
                    Color(red: 0.25, green: 0.55, blue: 0.95)
                ]
            }
        case .aqua:
            // Brushed metal with cyan/teal accents
            return [
                Color(red: 0.35, green: 0.40, blue: 0.45),
                Color(red: 0.28, green: 0.32, blue: 0.38),
                Color(red: 0.0, green: 0.55, blue: 0.70),
                Color(red: 0.0, green: 0.65, blue: 0.80),
                Color(red: 0.22, green: 0.26, blue: 0.30)
            ]
        case .neon:
            // Dark with RGB neon accents
            return [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.6, green: 0.0, blue: 0.8),
                Color(red: 1.0, green: 0.2, blue: 0.6),
                Color(red: 0.0, green: 0.8, blue: 1.0),
                Color(red: 0.1, green: 0.1, blue: 0.15)
            ]
        case .retro:
            // 80s terminal green/amber
            return [
                Color(red: 0.02, green: 0.02, blue: 0.02),
                Color(red: 0.05, green: 0.15, blue: 0.05),
                Color(red: 0.1, green: 0.4, blue: 0.15),
                Color(red: 0.6, green: 0.35, blue: 0.1),
                Color(red: 0.03, green: 0.03, blue: 0.03)
            ]
        case .cinema:
            // Letterboxd style - dark base with green/orange accents
            return [
                Color(red: 0.078, green: 0.094, blue: 0.110),  // #14181c dark bg
                Color(red: 0.110, green: 0.133, blue: 0.157),  // #1c2228 card bg
                Color(red: 0.0, green: 0.878, blue: 0.329),    // #00e054 green
                Color(red: 1.0, green: 0.502, blue: 0.0),      // #ff8000 orange
                Color(red: 0.078, green: 0.094, blue: 0.110)   // #14181c dark bg
            ]
        }
    }

    // Theme-aware text colors
    private var textColor: Color {
        switch theme {
        case .standard:
            return .white
        case .aqua:
            return Color(red: 0.9, green: 0.92, blue: 0.95)
        case .neon:
            return .white
        case .retro:
            return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .cinema:
            return .white  // Letterboxd uses white text
        }
    }

    private var secondaryTextColor: Color {
        switch theme {
        case .standard:
            return .white.opacity(0.8)
        case .aqua:
            return Color(red: 0.7, green: 0.75, blue: 0.82)
        case .neon:
            return Color(red: 0.8, green: 0.8, blue: 0.9)
        case .retro:
            return Color(red: 0.1, green: 0.6, blue: 0.2)
        case .cinema:
            return Color(red: 0.6, green: 0.6, blue: 0.6)  // Letterboxd gray
        }
    }

    // Theme-aware border colors
    private var borderColors: (Color, Color) {
        switch theme {
        case .standard:
            return (Color.white.opacity(0.4), Color.white.opacity(0.1))
        case .aqua:
            return (Color(red: 0.5, green: 0.55, blue: 0.6).opacity(0.6), Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.3))
        case .neon:
            return (Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.5), Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3))
        case .retro:
            return (Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.4), Color(red: 0.2, green: 0.5, blue: 0.2).opacity(0.2))
        case .cinema:
            return (Color(red: 0.0, green: 0.878, blue: 0.329).opacity(0.5), Color(red: 1.0, green: 0.502, blue: 0.0).opacity(0.3))  // Letterboxd green/orange
        }
    }

    // Theme-aware badge background
    private var badgeBackground: Color {
        switch theme {
        case .standard:
            return Color.white.opacity(0.12)
        case .aqua:
            return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.15)
        case .neon:
            return Color.white.opacity(0.08)
        case .retro:
            return Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.08)
        case .cinema:
            return Color(red: 0.0, green: 0.878, blue: 0.329).opacity(0.15)  // Letterboxd green
        }
    }

    var body: some View {
        let (borderStart, borderEnd) = borderColors
        return ZStack {
            // Theme-aware gradient background
            gradientBackground
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [borderStart, borderEnd]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: gradientColors[2].opacity(0.4), radius: 30, x: 0, y: 12)

            HStack(spacing: 20) {
                // Left: Project info
                VStack(alignment: .leading, spacing: 10) {
                    Text(greetingMessage())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                        .fixedSize()

                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(projectName.isEmpty ? "Untitled Project" : projectName)
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)

                        if !productionCompany.isEmpty {
                            Text(productionCompany)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(1)
                        }

                        // Project Settings Button
                        Button(action: onProjectSettings) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(badgeBackground)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(borderStart.opacity(0.6), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Project Settings")
                    }

                    HStack(spacing: 12) {
                        ThemedDateBadge(icon: "calendar", label: "Start", date: startDateText, theme: theme)
                        ThemedDateBadge(icon: "flag", label: "Wrap", date: wrapDateText, theme: theme)
                    }
                    .fixedSize()
                }

                Spacer(minLength: 20)

                // Right: Clock
                ClockView(locationLabel: locationLabel, theme: theme)
                    .fixedSize()
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(badgeBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(borderStart.opacity(0.6), lineWidth: 1)
                    )
            }
            .padding(24)
        }
        .frame(minHeight: 140)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Gradient Background

    private var gradientBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Overlay glow effects for depth
            GeometryReader { geometry in
                ZStack {
                    // Top-left orange glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [gradientColors[0].opacity(0.5), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.4
                            )
                        )
                        .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                        .offset(x: -geometry.size.width * 0.15, y: -geometry.size.height * 0.3)

                    // Bottom-right blue glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [gradientColors[4].opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.2)

                    // Center purple accent
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [gradientColors[2].opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.3
                            )
                        )
                        .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.6)
                        .offset(x: geometry.size.width * 0.1, y: 0)
                }
            }

            // Subtle noise/texture overlay
            Rectangle()
                .fill(Color.white.opacity(0.02))
        }
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

// MARK: - Gradient Date Badge (for use in gradient header)

private struct GradientDateBadge: View {
    let icon: String
    let label: String
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundStyle(.white.opacity(0.7))

            Text(date)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Themed Date Badge (theme-aware version)

private struct ThemedDateBadge: View {
    let icon: String
    let label: String
    let date: String
    var theme: AppAppearance.Theme = .standard

    // Theme-aware text colors
    private var primaryTextColor: Color {
        switch theme {
        case .standard:
            return .white
        case .aqua:
            return Color(red: 0.9, green: 0.92, blue: 0.95)
        case .neon:
            return .white
        case .retro:
            return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .cinema:
            return Color(red: 0.95, green: 0.9, blue: 0.85)
        }
    }

    private var secondaryTextColor: Color {
        switch theme {
        case .standard:
            return .white.opacity(0.7)
        case .aqua:
            return Color(red: 0.7, green: 0.75, blue: 0.82)
        case .neon:
            return Color(red: 0.8, green: 0.8, blue: 0.9)
        case .retro:
            return Color(red: 0.1, green: 0.6, blue: 0.2)
        case .cinema:
            return Color(red: 0.85, green: 0.65, blue: 0.2)
        }
    }

    private var badgeBackground: Color {
        switch theme {
        case .standard:
            return Color.white.opacity(0.12)
        case .aqua:
            return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.15)
        case .neon:
            return Color.white.opacity(0.08)
        case .retro:
            return Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.08)
        case .cinema:
            return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch theme {
        case .standard:
            return Color.white.opacity(0.2)
        case .aqua:
            return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.3)
        case .neon:
            return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.3)
        case .retro:
            return Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.25)
        case .cinema:
            return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundStyle(secondaryTextColor)

            Text(date)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(primaryTextColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(badgeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
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
                    .foregroundStyle(.black.opacity(0.6))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.black.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            .fixedSize()
            Text(date)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
        )
        .fixedSize()
    }
}

// Simple stat tile for mobile - clean design
private struct StatTile: View {
    let title: String
    let count: Int
    var color: Color = .accentColor
    var theme: AppAppearance.Theme = .standard
    @State private var appeared = false

    private var cardBackground: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.03)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.08)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.06)
        case .cinema: return Color(red: 0.7, green: 0.15, blue: 0.2).opacity(0.08)
        }
    }

    private var cardBorder: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.08)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.2)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.25)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.2)
        case .cinema: return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.25)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                // Simple dot - NO GLOW
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
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
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
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

// MARK: - Tasks Dashboard Section
private struct TasksDashboardSection: View {
    @Environment(\.managedObjectContext) private var moc
    var theme: AppAppearance.Theme = .standard
    @State private var taskStats: (total: Int, pending: Int, completed: Int) = (0, 0, 0)
    @State private var upcoming: [TaskEntity] = []

    private var cardBackground: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.03)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.08)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.06)
        case .cinema: return Color(red: 0.7, green: 0.15, blue: 0.2).opacity(0.08)
        }
    }

    private var cardBorder: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.08)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.2)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.25)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.2)
        case .cinema: return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.25)
        }
    }

    private var iconColor: Color {
        switch theme {
        case .standard: return .secondary
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .cinema: return Color(red: 0.85, green: 0.65, blue: 0.2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
                Text("Tasks")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            // Task stats
            HStack(spacing: 16) {
                TaskStatCard(title: "Total", value: "\(taskStats.total)", color: .blue, theme: theme)
                TaskStatCard(title: "Pending", value: "\(taskStats.pending)", color: .orange, theme: theme)
                TaskStatCard(title: "Completed", value: "\(taskStats.completed)", color: .green, theme: theme)
                Spacer()
            }

            // Upcoming tasks with reminders
            if !upcoming.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming Reminders")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    ForEach(upcoming, id: \.self) { task in
                        UpcomingTaskRow(task: task)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .onAppear {
            refreshData()
        }
        .onChange(of: moc.hasChanges) { _ in
            refreshData()
        }
    }
    
    private func refreshData() {
        taskStats = fetchTasksBreakdown()
        upcoming = fetchUpcomingTasks()
    }
    
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
    
    private func fetchTasksBreakdown() -> (total: Int, pending: Int, completed: Int) {
        guard hasEntity("TaskEntity") else { return (0, 0, 0) }
        let total = entityCount("TaskEntity")
        let completed = entityCount("TaskEntity", predicate: NSPredicate(format: "isCompleted == YES"))
        let pending = total - completed
        return (total, pending, completed)
    }
    
    private func fetchUpcomingTasks() -> [TaskEntity] {
        guard hasEntity("TaskEntity") else { return [] }
        let req = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        req.predicate = NSPredicate(format: "isCompleted == NO AND reminderDate != nil AND reminderDate >= %@", Date() as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "reminderDate", ascending: true)]
        req.fetchLimit = 5
        do {
            return try moc.fetch(req)
        } catch {
            return []
        }
    }
}

// Task stat card (smaller version for tasks section)
private struct TaskStatCard: View {
    let title: String
    let value: String
    var color: Color = .accentColor
    var theme: AppAppearance.Theme = .standard
    @State private var isHovered = false

    private var cardBackground: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.02)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.06)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.06)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.04)
        case .cinema: return Color(red: 0.7, green: 0.15, blue: 0.2).opacity(0.06)
        }
    }

    private var cardBorder: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.06)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.15)
        case .retro: return Color(red: 0.95, green: 0.6, blue: 0.2).opacity(0.18)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.15)
        case .cinema: return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.18)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(14)
        .frame(minWidth: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Upcoming task row for dashboard
private struct UpcomingTaskRow: View {
    @ObservedObject var task: TaskEntity
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(reminderColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let reminderDate = task.reminderDate {
                    Text(formatDate(reminderDate))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "bell.fill")
                .font(.system(size: 11))
                .foregroundStyle(reminderColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(reminderColor.opacity(0.08))
        )
    }
    
    private var reminderColor: Color {
        guard let reminderDate = task.reminderDate else { return .gray }
        let now = Date()
        let timeInterval = reminderDate.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return .red // Overdue
        } else if timeInterval < 3600 { // Less than 1 hour
            return .orange
        } else if timeInterval < 86400 { // Less than 24 hours
            return .yellow
        } else {
            return .blue
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at " + formatter.string(from: date)
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Tomorrow at " + formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// Temporary placeholder used when ShotListerView isn't available in this target
private struct ShotListerPlaceholder: View {
    let projectID: NSManagedObjectID
    var body: some View {
        VStack(spacing: 12) {
            Text("Shot Lister")
                .font(.title2).bold()
            Text("This build doesn't include the Shot Lister UI in scope.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @escaping () -> Content) { self.build = build }
    var body: some View { build() }
}

// MARK: - Active User Model
struct ActiveUser: Identifiable {
    let id: UUID
    let name: String
    let role: String
    let category: String
    let isOnline: Bool

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    var categoryColor: Color {
        switch category.lowercased() {
        case let c where c.contains("cast"): return .red
        case let c where c.contains("vendor"): return .green
        default: return .blue
        }
    }
}

// MARK: - Active User Card
struct ActiveUserCard: View {
    let user: ActiveUser
    var theme: AppAppearance.Theme = .standard
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var textColor: Color {
        switch theme {
        case .standard: return .primary
        case .aqua: return Color(red: 0.85, green: 0.88, blue: 0.92)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .neon: return .white
        case .cinema: return Color(red: 0.95, green: 0.9, blue: 0.85)
        }
    }

    private var secondaryTextColor: Color {
        switch theme {
        case .standard: return .secondary
        case .aqua: return Color(red: 0.6, green: 0.65, blue: 0.72)
        case .retro: return Color(red: 0.1, green: 0.5, blue: 0.15)
        case .neon: return Color(red: 0.7, green: 0.7, blue: 0.8)
        case .cinema: return Color(red: 0.65, green: 0.55, blue: 0.55)
        }
    }

    private var cardBackground: Color {
        switch theme {
        case .standard:
            return isHovered
                ? Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                : Color.primary.opacity(colorScheme == .dark ? 0.02 : 0.04)
        case .aqua:
            return isHovered
                ? Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.12)
                : Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.06)
        case .retro:
            return isHovered
                ? Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.08)
                : Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.04)
        case .neon:
            return isHovered
                ? Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.1)
                : Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.05)
        case .cinema:
            return isHovered
                ? Color(red: 0.7, green: 0.15, blue: 0.2).opacity(0.12)
                : Color(red: 0.7, green: 0.15, blue: 0.2).opacity(0.06)
        }
    }

    private var cardBorder: Color {
        switch theme {
        case .standard:
            return isHovered
                ? user.categoryColor.opacity(0.3)
                : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15)
        case .aqua:
            return isHovered
                ? Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.4)
                : Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.2)
        case .retro:
            return isHovered
                ? Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.5)
                : Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.2)
        case .neon:
            return isHovered
                ? Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.4)
                : Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.2)
        case .cinema:
            return isHovered
                ? Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.4)
                : Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.2)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    user.categoryColor.opacity(0.3),
                                    user.categoryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Text(user.initials.uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(user.categoryColor)
                }

                // Online status indicator
                if user.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(theme == .standard ? Color(colorScheme == .dark ? .black : .white) : Color.black, lineWidth: 2)
                        )
                        .offset(x: -2, y: -2)
                }
            }

            // User info
            VStack(spacing: 4) {
                Text(user.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Text(user.role)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                // Category badge
                Text(user.category.capitalized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(user.categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(user.categoryColor.opacity(0.15))
                    )
            }
        }
        .frame(width: 120)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }
}

// MARK: - Sidebar Background (matches NavigationSplitView sidebar)
#if os(macOS)
struct SidebarBackground: View {
    @AppStorage("app_theme") private var appTheme: String = "Standard"

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    var body: some View {
        switch currentTheme {
        case .standard:
            // Use system sidebar material for standard theme
            SidebarVisualEffectBackground()
        case .aqua:
            // Dark brushed metal - simple gradient without fixed-height texture
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.26),
                    Color(red: 0.18, green: 0.20, blue: 0.22),
                    Color(red: 0.15, green: 0.17, blue: 0.19),
                    Color(red: 0.12, green: 0.14, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .retro:
            // Pure terminal black
            Color.black
        case .neon:
            // Black with subtle RGB hints
            ZStack {
                Color.black
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.black,
                        Color.red.opacity(0.06),
                        Color.black,
                        Color.green.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.blue.opacity(0.04),
                        Color.clear,
                        Color.red.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        case .cinema:
            // Deep burgundy/velvet theater curtain gradient
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.04, blue: 0.06),
                    Color(red: 0.18, green: 0.06, blue: 0.08),
                    Color(red: 0.14, green: 0.04, blue: 0.06),
                    Color(red: 0.10, green: 0.03, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Original NSVisualEffectView wrapper for standard theme
struct SidebarVisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#else
// iOS Implementation
import UIKit

/// iOS version of SidebarBackground with theme support
struct SidebarBackground: View {
    @AppStorage("app_theme") private var appTheme: String = "Standard"

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    var body: some View {
        switch currentTheme {
        case .standard:
            // Use system sidebar blur for standard theme
            SidebarVisualEffectBackground()
        case .aqua:
            // Dark brushed metal gradient
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.26),
                    Color(red: 0.18, green: 0.20, blue: 0.22),
                    Color(red: 0.15, green: 0.17, blue: 0.19),
                    Color(red: 0.12, green: 0.14, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .retro:
            // Pure terminal black
            Color.black
        case .neon:
            // Black with subtle RGB hints
            ZStack {
                Color.black
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.black,
                        Color.red.opacity(0.06),
                        Color.black,
                        Color.green.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .cinema:
            // Deep burgundy/velvet theater curtain gradient
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.04, blue: 0.06),
                    Color(red: 0.18, green: 0.06, blue: 0.08),
                    Color(red: 0.14, green: 0.04, blue: 0.06),
                    Color(red: 0.10, green: 0.03, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// iOS UIVisualEffectView wrapper for blur effects
struct SidebarVisualEffectBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let view = UIVisualEffectView(effect: blurEffect)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
#endif

// MARK: - Compact Stat Card for iOS
private struct CompactStatCardiOS: View {
    let title: String
    let value: String
    var color: Color = .accentColor

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Dock Icon for iPad (Bottom Dock)
#if os(iOS)
private struct DockIconiPad: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isSelected
                                ? color.opacity(0.2)
                                : Color.primary.opacity(0.05)
                        )
                        .frame(width: 52, height: 52)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? color : .secondary)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)

                // Label
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? color : .secondary)
                    .lineLimit(1)

                // Selection indicator
                Circle()
                    .fill(isSelected ? color : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
#endif

// MARK: - Calendar Extension for Week Check
extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        let now = Date()
        guard let weekStart = self.date(from: self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = self.date(byAdding: .day, value: 7, to: weekStart) else {
            return false
        }
        return date >= weekStart && date < weekEnd
    }
}
