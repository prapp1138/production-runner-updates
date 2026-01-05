import SwiftUI
import FirebaseCore
import CoreData
import UniformTypeIdentifiers
import Combine
import Sentry

// MARK: - Sentry Configuration
// Set to true to enable Sentry crash reporting and analytics
private let SENTRY_ENABLED = false
#if os(macOS)
import AppKit
import Sparkle
#else
import UIKit
#endif

// MARK: - Firebase App Delegate
#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    var splashWindowController: SplashWindowController?
    private var splashDismissed = false

    // Sparkle updater controller for automatic updates
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Sentry if enabled
        if SENTRY_ENABLED {
            SentrySDK.start { options in
                options.dsn = "https://a8a3f81c7f35efd2b568926e196f73c8@o4510652841197568.ingest.us.sentry.io/4510652906012672"
                options.debug = false
                options.tracesSampleRate = 1.0
                options.enableCrashHandler = true
                options.enableAutoSessionTracking = true
                options.sessionTrackingIntervalMillis = 30000
                options.enableAutoPerformanceTracing = true
                options.enableUserInteractionTracing = true
                options.enablePreWarmedAppStartTracing = true
                options.attachStacktrace = true

                // Set release version
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
                let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
                options.releaseName = "production-runner@\(version)+\(build)"

                #if DEBUG
                options.environment = "development"
                #else
                options.environment = "production"
                #endif
            }
            print("📊 Sentry configured (macOS)")
        }

        FirebaseApp.configure()
        print("🔥 Firebase configured (macOS)")

        // Initialize LocationDataManager early to ensure it listens for project switch notifications
        LocationDataManager.initialize()

        // Initialize NotificationManager to load persisted notifications and ensure system is ready
        _ = NotificationManager.shared

        // Show splash screen
        splashWindowController = SplashWindowController()
        splashWindowController?.showSplash()

        // Initialize auth service and dismiss splash when done
        Task { @MainActor in
            await AuthService.shared.initializeAuth()
            // Dismiss splash after auth initialization completes
            self.dismissSplash()
        }
    }

    func dismissSplash() {
        guard !splashDismissed else { return }
        splashDismissed = true
        splashWindowController?.dismissSplash()
        splashWindowController = nil
        print("🔥 Splash dismissed")
    }
}
#else
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize Sentry if enabled
        if SENTRY_ENABLED {
            SentrySDK.start { options in
                options.dsn = "https://a8a3f81c7f35efd2b568926e196f73c8@o4510652841197568.ingest.us.sentry.io/4510652906012672"
                options.debug = false
                options.tracesSampleRate = 1.0
                options.enableCrashHandler = true
                options.enableAutoSessionTracking = true
                options.sessionTrackingIntervalMillis = 30000
                options.enableAutoPerformanceTracing = true
                options.enableUserInteractionTracing = true
                options.enablePreWarmedAppStartTracing = true
                options.attachStacktrace = true

                // Set release version
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
                let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
                options.releaseName = "production-runner@\(version)+\(build)"

                #if DEBUG
                options.environment = "development"
                #else
                options.environment = "production"
                #endif
            }
            print("📊 Sentry configured (iOS)")
        }

        FirebaseApp.configure()
        print("🔥 Firebase configured (iOS)")

        // Initialize LocationDataManager early to ensure it listens for project switch notifications
        LocationDataManager.initialize()

        // Initialize NotificationManager to load persisted notifications and ensure system is ready
        _ = NotificationManager.shared

        // Initialize auth service
        Task { @MainActor in
            await AuthService.shared.initializeAuth()
        }

        return true
    }
}
#endif

// Debug tag used by _debugBadge; safe to keep or change
private let __GLOBAL_PATCH_TAG__ = "PR BUILD • v1.0.0 (1) • 2025-01-05"

#if os(macOS)
/// Default window size helper used by .defaultSize
private var defaultWindowSize: CGSize {
    let vf = NSScreen.main?.visibleFrame ?? .zero
    let w = max(1200, vf.width * 0.85)
    let h = max(800,  vf.height * 0.85)
    return .init(width: w, height: h)
}
#endif

// Provide a stable viewContext accessor for PersistenceController
extension PersistenceController {
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
}

// MARK: - Recent projects persistence (security-scoped bookmarks)
final class RecentProjects: ObservableObject {
    struct Item: Identifiable, Codable {
        var id: UUID = UUID()
        var name: String
        var bookmark: Data
        var lastOpened: Date
    }

    @Published private(set) var items: [Item] = [] {
        didSet { persist() }
    }

    private let storageKey = "recentProjects.bookmarks.v1"
    private var deletionObserver: NSObjectProtocol?

    init() {
        load()
        // Listen for project deletion to remove from bookmarks
        deletionObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("prProjectDeleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let url = notification.object as? URL {
                self?.remove(url: url)
            }
        }
    }

    deinit {
        if let observer = deletionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func add(url: URL) {
        #if os(macOS)
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
            // De-dup by path if already exists
            var filtered = items.filter { existing in
                if let resolved = resolve(existing.bookmark), resolved == url { return false }
                return true
            }
            filtered.insert(Item(name: name, bookmark: bookmark, lastOpened: Date()), at: 0)
            items = Array(filtered.prefix(10))
        } catch {
            print("⚠️ Failed to create bookmark for recent project: \(error)")
        }
        #endif
    }

    func resolve(_ bookmark: Data) -> URL? {
        var isStale = false
        do {
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            let url = try URL(resolvingBookmarkData: bookmark, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale)
            return url
        } catch {
            print("⚠️ Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    func remove(url: URL) {
        items = items.filter { item in
            guard let resolved = resolve(item.bookmark) else { return false }
            return resolved.standardizedFileURL != url.standardizedFileURL
        }
    }

    private func persist() {
        do {
            let data = try PropertyListEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("⚠️ Failed to encode recents: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            items = try PropertyListDecoder().decode([Item].self, from: data)
        } catch {
            print("⚠️ Failed to decode recents: \(error)")
        }
    }
}

@main
struct ProductionRunnerApp: App {
    // Register AppDelegate for Firebase setup
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    @State private var storeEpoch = UUID()
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    let persistence = PersistenceController.shared
    @StateObject var projectFileStore = ProjectFileStore()
    @StateObject var recents = RecentProjects()

    // System Appearance Setting
    @AppStorage("app_appearance") private var appAppearance: String = "system"
    @AppStorage("app_theme") private var appTheme: String = "Standard"
    @AppStorage("app_custom_accent_enabled") private var customAccentEnabled: Bool = false
    @AppStorage("app_custom_accent_color") private var customAccentHex: String = ""

    private var colorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var currentThemeAccentColor: Color {
        // If custom accent is enabled and we have a valid hex color, use it
        if customAccentEnabled, !customAccentHex.isEmpty, let customColor = Color(hex: customAccentHex) {
            return customColor
        }
        // Otherwise use the theme's accent color
        return AppAppearance.Theme(rawValue: appTheme)?.accentColor ?? .accentColor
    }

    private func applyAppearance() {
        print("🎨 App launch - applying appearance: \(appAppearance)")
        AppAppearance.apply(appAppearance)
    }

    private func applyTheme() {
        print("🎨 App launch - applying theme: \(appTheme)")
        AppAppearance.applyTheme(appTheme)
    }

    // MARK: - Main Content View with Modifiers
    private var mainContentView: some View {
        contentWithEnvironment
            .onReceive(projectFileStore.$url.compactMap { $0 }, perform: switchProject)
            .onReceive(NotificationCenter.default.publisher(for: .prNewProject)) { _ in newProject() }
            .onReceive(NotificationCenter.default.publisher(for: .prOpenProject)) { _ in openProject() }
            .onReceive(NotificationCenter.default.publisher(for: .prSaveProjectAs)) { _ in saveProjectAs() }
            .onReceive(NotificationCenter.default.publisher(for: .prCloseProject)) { _ in closeProject() }
            .onReceive(NotificationCenter.default.publisher(for: .prSwitchProject)) { _ in openProject() }
            .onReceive(NotificationCenter.default.publisher(for: .prSaveProject)) { _ in saveProject() }
            .onReceive(NotificationCenter.default.publisher(for: .prImport)) { _ in importData() }
            .onReceive(NotificationCenter.default.publisher(for: .prExport)) { _ in exportData() }
            .onReceive(NotificationCenter.default.publisher(for: .prClose)) { _ in closeWindow() }
    }

    private var contentWithEnvironment: some View {
        contentWithWindowHandlers
            .environment(\.managedObjectContext, persistence.viewContext as NSManagedObjectContext)
            .id(ObjectIdentifier(persistence.viewContext))
            .id(storeEpoch)
            .environmentObject(projectFileStore)
            .environmentObject(recents)
            .tint(currentThemeAccentColor)
            .onAppear { autosaveEvery(10, context: persistence.viewContext) }
    }

    private var contentWithWindowHandlers: some View {
        contentWithAppearance
#if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: .prShowHelp)) { _ in openWindow(id: "help") }
            .onReceive(NotificationCenter.default.publisher(for: .prShowKeyboardShortcuts)) { _ in openWindow(id: "shortcuts") }
            .onReceive(NotificationCenter.default.publisher(for: .prShowGetStarted)) { _ in openWindow(id: "getstarted") }
            .onReceive(NotificationCenter.default.publisher(for: .prShowWhatsNew)) { _ in openWindow(id: "whatsnew") }
            .onReceive(NotificationCenter.default.publisher(for: .prProjectSettings)) { _ in openWindow(id: "project-settings") }
            .onReceive(NotificationCenter.default.publisher(for: .prReportIssue)) { _ in
                if let url = URL(string: "https://github.com/anthropics/claude-code/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prSendFeedback)) { _ in
                if let url = URL(string: "mailto:feedback@productionrunner.app?subject=Production%20Runner%20Feedback") {
                    NSWorkspace.shared.open(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prToggleSidebar)) { _ in
                NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .prToggleFullScreen)) { _ in
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .prUndo)) { _ in
                persistence.viewContext.undoManager?.undo()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prRedo)) { _ in
                persistence.viewContext.undoManager?.redo()
            }
#endif
    }

    private var contentWithAppearance: some View {
        AuthRootView()
            .onAppear {
                print("🟢 Launched: \(__GLOBAL_PATCH_TAG__)")
                print("🟢 Bundle: \(Bundle.main.bundleIdentifier ?? "nil")")
                applyAppearance()
                applyTheme()
            }
            .onChange(of: appAppearance) { newValue in
                print("🎨 Appearance changed via AppStorage: \(newValue)")
                AppAppearance.apply(newValue)
            }
            .onChange(of: appTheme) { newValue in
                print("🎨 Theme changed via AppStorage: \(newValue)")
                AppAppearance.applyTheme(newValue)
            }
            .onChange(of: customAccentEnabled) { _ in }
            .onChange(of: customAccentHex) { _ in }
            .preferredColorScheme(colorScheme)
    }

    var body: some Scene {
        WindowGroup("Production Runner") {
            mainContentView
        }
#if os(macOS)
        .defaultSize(width: defaultWindowSize.width, height: defaultWindowSize.height)
        .windowResizability(.contentMinSize)
#endif
        .onChange(of: scenePhase) { phase in
            let ctx = persistence.viewContext
            if phase == .inactive || phase == .background {
                ctx.pr_save()
            }
        }
#if os(macOS)
        .commands {
            GlobalCommands()
            ContactsCommands()
        }
#endif
#if os(macOS)
        // Dedicated Projects window so toolbar/button calls to openWindow(id: "projects") work
        Window("Projects", id: "projects") {
            AuthRootView()
                .onAppear {
                    print("🟢 Projects Window: \(__GLOBAL_PATCH_TAG__)")
                }
                .environment(\.managedObjectContext, persistence.viewContext as NSManagedObjectContext)
                .id(ObjectIdentifier(persistence.viewContext))
                .id(storeEpoch)
                .environmentObject(projectFileStore)
                .environmentObject(recents)
                .tint(currentThemeAccentColor)
                .preferredColorScheme(colorScheme)
        }

        // Help Window
        Window("Production Runner Help", id: "help") {
            HelpView()
                .preferredColorScheme(colorScheme)
        }
        .defaultSize(width: 900, height: 650)

        // Keyboard Shortcuts Window
        Window("Keyboard Shortcuts", id: "shortcuts") {
            KeyboardShortcutsView()
                .preferredColorScheme(colorScheme)
        }
        .defaultSize(width: 500, height: 600)

        // What's New Window
        Window("What's New", id: "whatsnew") {
            WhatsNewView()
                .preferredColorScheme(colorScheme)
        }
        .defaultSize(width: 550, height: 700)

        // Get Started Window
        Window("Get Started", id: "getstarted") {
            GetStartedWindowView()
                .preferredColorScheme(colorScheme)
        }
        .defaultSize(width: 700, height: 600)

        // Project Settings Window
        Window("Project Settings", id: "project-settings") {
            Text("Project Settings")
                .frame(minWidth: 600, minHeight: 400)
                .preferredColorScheme(colorScheme)
        }
        .defaultSize(width: 600, height: 400)
#endif
    }

    // MARK: - Project Management Methods

    private func switchProject(to projectURL: URL?) {
        guard let projectURL else { return }
        #if os(macOS)
        _ = projectURL.startAccessingSecurityScopedResource()
        #endif

        // If a .runner package was selected, open it using the public loader; otherwise fall back to folder mapping
        if projectURL.pathExtension == "runner" {
            do {
                let pkg = try ProjectFileManager.normalizePackageURL(projectURL)
                let storeURL = pkg.appendingPathComponent("Store", isDirectory: true)
                    .appendingPathComponent("ProductionRunner.sqlite")
                try persistence.load(at: storeURL)
                NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
            } catch {
                print("⚠️ Failed to open package: \(error)")
            }
        } else {
            do {
                let storeURL = PersistenceController.storeURL(forProjectFolder: projectURL)
                try persistence.load(at: storeURL)
                NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
            } catch {
                print("⚠️ Failed to load project: \(error)")
            }
        }
    }

    private func restoreLastProjectIfNeeded() {
        // If no project is selected yet, try the most recent bookmark
        if projectFileStore.url == nil, let first = recents.items.first, let url = recents.resolve(first.bookmark) {
            projectFileStore.url = url
        }
    }
    
    private func newProject() {
        #if os(macOS)
        guard let pkgURL = ProjectFilePicker.promptToCreatePackage(defaultName: "Untitled Project.runner") else { return }
         do {
             let name = pkgURL.deletingPathExtension().lastPathComponent
             let parent = pkgURL.deletingLastPathComponent()
             let pkg = try ProjectFileManager.createProject(named: name, in: parent)
             projectFileStore.url = pkg
             recents.add(url: pkg)
             
             // After switching to the new store, create the initial ProjectEntity
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                 let ctx = self.persistence.viewContext
                 let store = ProjectStore(context: ctx)
                 _ = store.create(name: name, user: nil, statusRaw: "development")
                 NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
             }
         } catch {
             print("⚠️ New packaged project failed: \(error)")
         }
        #endif
    }
    
#if os(macOS)
    private func openProject() {
        guard let picked = ProjectFilePicker.promptToOpenPackage() else { return }
         do {
             let pkg = try ProjectFileManager.normalizePackageURL(picked)
             projectFileStore.url = pkg
             recents.add(url: pkg)
             NSApp.activate(ignoringOtherApps: true)
             
             // After switching to the store, check if ProjectEntity exists
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                 let ctx = self.persistence.viewContext
                 if ProjectStore.fetchAll(in: ctx).isEmpty {
                     let name = pkg.deletingPathExtension().lastPathComponent
                     let store = ProjectStore(context: ctx)
                     _ = store.create(name: name, user: nil, statusRaw: "development")
                 }
                 NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
             }
         } catch {
             print("⚠️ Open packaged project failed: \(error)")
         }
    }

    private func saveProjectAs() {
        #if os(macOS)
        guard let pkgURL = ProjectFilePicker.promptToCreatePackage(defaultName: "New Project.runner") else { return }
        do {
            // Inline export: copy live Core Data store into new .runner package, then switch to it
            let coordinator = persistence.container.persistentStoreCoordinator
            guard let liveStore = coordinator.persistentStores.first, let liveURL = liveStore.url else {
                throw NSError(domain: "ProductionRunner", code: 2001, userInfo: [NSLocalizedDescriptionKey: "No active persistent store"])
            }

            // Ensure package structure
            let fm = FileManager.default
            try fm.createDirectory(at: pkgURL, withIntermediateDirectories: true)
            let storeFolder = pkgURL.appendingPathComponent("Store", isDirectory: true)
            try fm.createDirectory(at: storeFolder, withIntermediateDirectories: true)
            let sqliteURL = storeFolder.appendingPathComponent("ProductionRunner.sqlite")

            // Write minimal manifest
            let manifestURL = pkgURL.appendingPathComponent("project.json")
            let manifest: [String: Any] = [
                "name": "Production Runner Project",
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "schema": 1
            ]
            let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
            try manifestData.write(to: manifestURL, options: .atomic)

            // Migrate/copy the live store to destination, then migrate back to keep original URL unchanged
            let options: [AnyHashable: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
            let migrated = try coordinator.migratePersistentStore(liveStore, to: sqliteURL, options: options, withType: NSSQLiteStoreType)
            _ = try coordinator.migratePersistentStore(migrated, to: liveURL, options: options, withType: NSSQLiteStoreType)

            // Now switch UI to the newly exported package
            let pkg = try ProjectFileManager.normalizePackageURL(pkgURL)
            projectFileStore.url = pkg
            recents.add(url: pkg)
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            print("⚠️ Save Project As (package) failed: \(error)")
        }
        #endif
    }

    private func closeProject() {
        projectFileStore.url = nil
        NSApp.activate(ignoringOtherApps: true)
    }

    private func saveProject() {
        // Save the current project by triggering Core Data save
        do {
            try persistence.viewContext.save()
            print("✅ Project saved successfully")
        } catch {
            print("⚠️ Failed to save project: \(error.localizedDescription)")
        }
    }

    private func importData() {
        // Open file picker to import various file types
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf, .plainText, .xml, .json, .commaSeparatedText]
        panel.message = "Select a file to import"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Post notification with the selected URL for specific app handlers
            NotificationCenter.default.post(
                name: .prImportFile,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    private func exportData() {
        // Open save panel to export project data
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Production Runner Export"
        panel.allowedContentTypes = [.pdf, .plainText, .json]
        panel.message = "Export project data"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Post notification with the selected URL for specific app handlers
            NotificationCenter.default.post(
                name: .prExportFile,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    private func closeWindow() {
        // Close the current window
        if let window = NSApp.keyWindow {
            window.performClose(nil)
        }
    }
#endif

}


// MARK: - Auth-Aware Root View

struct AuthRootView: View {
    @ObservedObject var authService = AuthService.shared

    var body: some View {
        Group {
            switch authService.authState {
            case .unknown:
                // Show splash screen content (on iOS; macOS uses separate window)
                #if os(iOS)
                SplashScreenView()
                #else
                // macOS: Show nothing while splash window is visible
                Color.clear
                #endif

            case .unauthenticated:
                // Show login screen
                LoginView()

            case .authenticated:
                // Show main app
                AuthenticatedContentView()
            }
        }
    }
}

// MARK: - Authenticated Content View

struct AuthenticatedContentView: View {
    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject var projectFileStore: ProjectFileStore
    @EnvironmentObject var recents: RecentProjects

    var body: some View {
        CurrentProjectHost()
            .checkNotificationPermission()
    }
}

struct CurrentProjectHost: View {
    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject var projectFileStore: ProjectFileStore
    @EnvironmentObject var recents: RecentProjects
    @State private var selected: NSManagedObject? = nil

    var body: some View {
        NavigationStack {
            Group {
                if let proj = selected {
                    MainDashboardView(project: proj, projectFileURL: projectFileStore.url)
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
                                Button("Switch Project") { selected = nil }
                                    .keyboardShortcut("L", modifiers: [.command, .shift])
                            }
                        }
                } else {
                    #if os(macOS)
                    ProjectsDashboard_Package(
                        onOpen: { url in
                            _ = url.startAccessingSecurityScopedResource()
                            do {
                                let pkg = try ProjectFileManager.normalizePackageURL(url)
                                projectFileStore.url = pkg
                                recents.add(url: pkg)
                                #if os(macOS)
                                NSDocumentController.shared.noteNewRecentDocumentURL(pkg)
                                NSApp.activate(ignoringOtherApps: true)
                                #endif
                                // After the store loads, check if ProjectEntity exists and create if needed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if ProjectStore.fetchAll(in: ctx).isEmpty {
                                        let name = pkg.deletingPathExtension().lastPathComponent
                                        let store = ProjectStore(context: ctx)
                                        _ = store.create(name: name, user: nil, statusRaw: "development")
                                    }
                                    NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                                    if let first = ProjectStore.fetchAll(in: ctx).first { selected = first }
                                }
                            } catch {
                                print("⚠️ Dashboard/Open packaged project failed: \(error)")
                            }
                        },
                        onCreate: { url in
                            do {
                                let name = url.deletingPathExtension().lastPathComponent
                                let parent = url.deletingLastPathComponent()
                                let pkg = try ProjectFileManager.createProject(named: name, in: parent)
                                projectFileStore.url = pkg
                                recents.add(url: pkg)
                                #if os(macOS)
                                NSDocumentController.shared.noteNewRecentDocumentURL(pkg)
                                NSApp.activate(ignoringOtherApps: true)
                                #endif
                                // After switching to the new store, create the initial ProjectEntity
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    let store = ProjectStore(context: ctx)
                                    _ = store.create(name: name, user: nil, statusRaw: "development")
                                    NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                                    if let first = ProjectStore.fetchAll(in: ctx).first { selected = first }
                                }
                            } catch {
                                print("⚠️ Dashboard/New packaged project failed: \(error)")
                            }
                        },
                        extraRecents: recents.items.compactMap { recents.resolve($0.bookmark) }
                    )
                    .padding(0)
                    #else
                    // iOS: Use the same ProjectsDashboard_Package as macOS
                    ProjectsDashboard_Package(
                        onOpen: { url in
                            _ = url.startAccessingSecurityScopedResource()
                            do {
                                let pkg = try ProjectFileManager.normalizePackageURL(url)
                                projectFileStore.url = pkg
                                recents.add(url: pkg)
                                // After the store loads, check if ProjectEntity exists and create if needed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if ProjectStore.fetchAll(in: ctx).isEmpty {
                                        let name = pkg.deletingPathExtension().lastPathComponent
                                        let store = ProjectStore(context: ctx)
                                        _ = store.create(name: name, user: nil, statusRaw: "development")
                                    }
                                    NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                                    if let first = ProjectStore.fetchAll(in: ctx).first { selected = first }
                                }
                            } catch {
                                print("⚠️ Dashboard/Open packaged project failed:", error)
                            }
                        },
                        onCreate: { url in
                            do {
                                let name = url.deletingPathExtension().lastPathComponent
                                let parent = url.deletingLastPathComponent()
                                let pkg = try ProjectFileManager.createProject(named: name, in: parent)
                                projectFileStore.url = pkg
                                recents.add(url: pkg)
                                // After switching to the new store, create the initial ProjectEntity
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    let store = ProjectStore(context: ctx)
                                    _ = store.create(name: name, user: nil, statusRaw: "development")
                                    NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                                    if let first = ProjectStore.fetchAll(in: ctx).first { selected = first }
                                }
                            } catch {
                                print("⚠️ Dashboard/New packaged project failed:", error)
                            }
                        },
                        extraRecents: recents.items.compactMap { recents.resolve($0.bookmark) }
                    )
                    .padding(0)
                    #endif
                }
            }
            .navigationTitle("")
            .onReceive(NotificationCenter.default.publisher(for: .prStoreDidSwitch)) { _ in
                // After switching stores, pick the first project in the new store, if any
                if let first = ProjectStore.fetchAll(in: ctx).first { selected = first } else { selected = nil }
            }
        }
    }
}

extension Notification.Name {
    static let prStoreDidSwitch = Notification.Name("pr.storeDidSwitch")
}


// MARK: - Fallback shims for missing ProjectFileManager APIs
import Foundation

extension ProjectFileManager {
    /// Returns the `.runner` package root even if a child URL was passed (e.g., Store/ProductionRunner.sqlite).
    static func normalizePackageURL(_ url: URL) throws -> URL {
        if url.pathExtension == "runner" { return url }
        var probe = url
        let fm = FileManager.default
        for _ in 0..<8 { // walk up a few levels max
            probe.deleteLastPathComponent()
            if probe.pathExtension == "runner", fm.fileExists(atPath: probe.path) {
                return probe
            }
        }
        throw NSError(domain: "ProductionRunner",
                      code: 9001,
                      userInfo: [NSLocalizedDescriptionKey: "Not a Production Runner package"])
    }

    /// Creates a new `.runner` package at `parent/name.runner` with a minimal Store and manifest.
    @discardableResult
    static func createProject(named raw: String, in parent: URL) throws -> URL {
        let name = sanitizedFilename(from: raw.isEmpty ? "Untitled Project" : raw)
        let pkg = parent.appendingPathComponent("\(name).runner", isDirectory: true)
        let fm = FileManager.default

        try fm.createDirectory(at: pkg, withIntermediateDirectories: true)
        let store = pkg.appendingPathComponent("Store", isDirectory: true)
        try fm.createDirectory(at: store, withIntermediateDirectories: true)

        // Touch sqlite (Core Data will create/replace on first save)
        let sqlite = store.appendingPathComponent("ProductionRunner.sqlite")
        fm.createFile(atPath: sqlite.path, contents: nil)

        // Minimal manifest
        let manifest: [String: Any] = [
            "name": name,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "schema": 1
        ]
        let manifestURL = pkg.appendingPathComponent("project.json")
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: manifestURL, options: .atomic)

        return pkg
    }

    // Local helper to keep filenames clean
    private static func sanitizedFilename(from name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}
