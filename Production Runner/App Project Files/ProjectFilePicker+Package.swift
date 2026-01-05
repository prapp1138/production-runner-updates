import SwiftUI
import UniformTypeIdentifiers
import CoreData
#if canImport(AppKit)
import AppKit
#endif
#if !canImport(AppKit)
import UIKit
#endif

extension Color {
    static var prWindowBackground: Color {
        #if canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    static var prControlAccent: Color {
        #if canImport(AppKit)
        return Color(NSColor.controlAccentColor)
        #else
        return Color.accentColor
        #endif
    }
    static var prSeparator: Color {
        #if canImport(AppKit)
        return Color(NSColor.separatorColor)
        #else
        return Color(UIColor.separator)
        #endif
    }
    static var prControlBackground: Color {
        #if canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

private extension Notification.Name {
    static let prRecentsDidChange = Notification.Name("prRecentsDidChange")
    static let prProjectDeleted = Notification.Name("prProjectDeleted")
}

// MARK: - Package Picker Helpers (AppKit panels)
private enum PRPicker {
#if os(macOS)
    private static var primaryType: UTType {
        UTType(filenameExtension: "runner", conformingTo: .package) ?? .data
    }

    @MainActor
    static func promptToOpenPackage() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Production Runner Project"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [primaryType]
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func promptToCreatePackage(defaultName: String = "Untitled Project.runner") -> URL? {
        let panel = NSSavePanel()
        panel.title = "Create Production Runner Project"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [primaryType]
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }
#else
    static func promptToOpenPackage() -> URL? { nil }
    static func promptToCreatePackage(defaultName: String = "Untitled Project.runner") -> URL? { nil }
#endif
}

// MARK: - Recent Projects Dashboard (macOS)
// MARK: - PRFileOps for macOS (replaces ProjectFileManager)
#if os(macOS)
private struct PRFileOps {
    enum PROpsError: Error { case userCancelled, invalidURL }

    /// Create a new `.runner` package and return its URL
    @MainActor
    static func newProject() throws -> URL {
        // Ask for destination
        guard let dest = PRPicker.promptToCreatePackage() else { throw PROpsError.userCancelled }
        // Ensure extension
        let url = dest.pathExtension.lowercased() == "runner" ? dest : dest.appendingPathExtension("runner")
        // Create the package folder if needed
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        // Drop a tiny metadata file so the package isn't empty
        let metaURL = url.appendingPathComponent("project.json")
        if !FileManager.default.fileExists(atPath: metaURL.path) {
            let payload = Data("{\"created\":\"\(ISO8601DateFormatter().string(from: Date()))\"}".utf8)
            try? payload.write(to: metaURL)
        }
        return url
    }

    /// Choose an existing `.runner` package and return its URL
    @MainActor
    static func openProject() throws -> URL {
        guard let url = PRPicker.promptToOpenPackage() else { throw PROpsError.userCancelled }
        return url
    }

    /// No-op upgrade hook for legacy packages; returns input URL
    @discardableResult
    static func upgradeLegacyPackageIfNeeded(at url: URL) throws -> URL { url }

    /// Move a project package to the Trash
    static func deleteProject(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
#endif

private struct PRHeaderButton: View {
    let title: String
    let systemName: String
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.35),
                                    Color(red: 0.95, green: 0.35, blue: 0.50)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .foregroundStyle(.white)
            .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .keyboardShortcut(keyEquivalent(for: title), modifiers: .command)
        .help(title)
    }

    private func keyEquivalent(for title: String) -> KeyEquivalent {
        switch title {
        case _ where title.hasPrefix("New"): return "n"
        case _ where title.hasPrefix("Open"): return "o"
        default: return " "
        }
    }
}

public struct ProjectsDashboard_Package: View {
    public var onOpen: ((URL) -> Void)?
    public var onCreate: ((URL) -> Void)?
    public var extraRecents: [URL] = []

    @State private var recent: [URL] = []
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSize
    @AppStorage("app_appearance") private var appAppearance: String = "system"
    @State private var openedProject: NSManagedObject? = nil
    @State private var presentDashboard: Bool = false
    @State private var showAccountSheet: Bool = false
    @State private var showAppSettings: Bool = false

    private var backgroundColor: Color {
        #if os(macOS)
        colorScheme == .dark ? Color.black : Color(NSColor.windowBackgroundColor)
        #else
        colorScheme == .dark ? Color.black : Color(UIColor.systemBackground)
        #endif
    }

    private var preferredScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    public init(onOpen: ((URL) -> Void)? = nil,
                onCreate: ((URL) -> Void)? = nil,
                extraRecents: [URL] = []) {
        self.onOpen = onOpen
        self.onCreate = onCreate
        self.extraRecents = extraRecents
    }

    public var body: some View {
        Group {
            #if os(iOS)
            if hSize == .compact {
                compactBody
            } else {
                regularBody
            }
            #else
            regularBody
            #endif
        }
        .background(backgroundColor)
        .onAppear(perform: loadRecents)
        .onReceive(NotificationCenter.default.publisher(for: .prStoreDidSwitch)) { _ in
            if let proj = fetchPrimaryProject() {
                self.openedProject = proj
                self.presentDashboard = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if let proj2 = fetchPrimaryProject() {
                        self.openedProject = proj2
                        self.presentDashboard = true
                    } else {
                        self.presentDashboard = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prRecentsDidChange)) { _ in
            loadRecents()
        }
        .sheet(isPresented: $presentDashboard) {
            let ctx = PersistenceController.shared.container.viewContext
            if let proj = openedProject {
                MainDashboardView(project: proj, projectFileURL: nil)
                    .environment(\.managedObjectContext, ctx)
                    .preferredColorScheme(preferredScheme)
            } else {
                Text("Loading Project…").padding()
                    .environment(\.managedObjectContext, ctx)
                    .preferredColorScheme(preferredScheme)
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet()
                .preferredColorScheme(preferredScheme)
        }
        .sheet(isPresented: $showAppSettings) {
            LaunchSettingsSheet()
                .preferredColorScheme(preferredScheme)
        }
    }

    // MARK: - Regular Layout (iPad/Mac)
    private var regularBody: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            accountFooter
        }
    }

    // MARK: - Compact Layout (iPhone)
    #if os(iOS)
    private var compactBody: some View {
        VStack(spacing: 0) {
            compactHeader
            compactContent
            Spacer(minLength: 0)
            compactFooter
        }
        .edgesIgnoringSafeArea(.top)
    }

    private var compactHeader: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 50) // Safe area padding

            // App icon (smaller for iPhone)
            ZStack {
                // Rainbow aura (smaller)
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.red, Color.orange, Color.yellow,
                                Color.green, Color.cyan, Color.blue,
                                Color.purple, Color.pink, Color.red
                            ]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .blur(radius: 15)
                    .opacity(0.5)
                    .frame(width: 80, height: 80)

                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.35, blue: 0.50),
                                Color(red: 1.0, green: 0.55, blue: 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "film.stack")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("Production Runner")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(0.3)

                Text("Film Production Management")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Stacked buttons for iPhone
            VStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            let url = try await PRFileOpsShim.newProject()
                            NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                            NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                            onCreate?(url)
                        } catch {
                            #if DEBUG
                            print("newProject failed:", error)
                            #endif
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("New Project")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.55, blue: 0.35),
                                        Color(red: 0.95, green: 0.35, blue: 0.50)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        do {
                            let url = try await PRFileOpsShim.openProject()
                            NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                            NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                            onOpen?(url)
                        } catch {
                            #if DEBUG
                            print("openProject failed:", error)
                            #endif
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Open Project")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.35),
                    Color.accentColor.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var compactContent: some View {
        VStack(alignment: .center, spacing: 0) {
            // Centered section header
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.35))
                Text("Recent Projects")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                if !recent.isEmpty {
                    Text("\(recent.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.2))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if recent.isEmpty {
                compactEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recent, id: \.self) { url in
                            CompactRecentRow(url: url) {
                                handleOpen(url)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.10),
                    Color.accentColor.opacity(0.05),
                    backgroundColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var compactEmptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
            }

            VStack(spacing: 4) {
                Text("No Recent Projects")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Create or open a project to get started")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 50)
    }

    private var compactFooter: some View {
        HStack(spacing: 10) {
            // Smaller Account button
            Button(action: { showAccountSheet = true }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(accountName.isEmpty ? "Account" : accountName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(accountRole.isEmpty ? "Tap to set up" : accountRole)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.35))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Smaller Settings button
            Button(action: { showAppSettings = true }) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.02))
    }
    #endif

    private var header: some View {
        VStack(spacing: 20) {
            // App icon and title
            VStack(spacing: 12) {
                // App icon circle with rainbow aura
                ZStack {
                    // Outer rainbow aura (larger, softer glow)
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.red,
                                    Color.orange,
                                    Color.yellow,
                                    Color.green,
                                    Color.cyan,
                                    Color.blue,
                                    Color.purple,
                                    Color.pink,
                                    Color.red
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            )
                        )
                        .blur(radius: 20)
                        .opacity(0.6)
                        .frame(width: 120, height: 120)

                    // Mid-layer aura
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.red,
                                    Color.orange,
                                    Color.yellow,
                                    Color.green,
                                    Color.cyan,
                                    Color.blue,
                                    Color.purple,
                                    Color.pink,
                                    Color.red
                                ]),
                                center: .center,
                                startAngle: .degrees(45),
                                endAngle: .degrees(405)
                            )
                        )
                        .blur(radius: 12)
                        .opacity(0.5)
                        .frame(width: 100, height: 100)

                    // Inner solid circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.35, blue: 0.50),
                                    Color(red: 1.0, green: 0.55, blue: 0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "film.stack")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text("Production Runner")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(0.3)

                    Text("Film Production Management")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                PRHeaderButton(title: "New Project", systemName: "plus.circle.fill") {
                    Task {
                        do {
                            let url = try await PRFileOpsShim.newProject()
                            #if canImport(AppKit)
                            NSDocumentController.shared.noteNewRecentDocumentURL(url)
                            #endif
                            NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                            NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                            onCreate?(url)
                        } catch {
                            #if DEBUG
                            print("newProject failed:", error)
                            #endif
                        }
                    }
                }

                PRHeaderButton(title: "Open Project…", systemName: "folder.fill") {
                    Task {
                        do {
                            let url = try await PRFileOpsShim.openProject()
                            #if canImport(AppKit)
                            NSDocumentController.shared.noteNewRecentDocumentURL(url)
                            #endif
                            NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                            NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                            onOpen?(url)
                        } catch {
                            #if DEBUG
                            print("openProject failed:", error)
                            #endif
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Blue gradient background matching dashboard
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.35),
                        Color.accentColor.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle border
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                }
            }
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.35))
                Text("Recent Projects")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                if !recent.isEmpty {
                    Text("\(recent.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.2))
                        )
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            if recent.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recent, id: \.self) { url in
                            RecentRow(url: url) {
                                handleOpen(url)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.15),
                    Color.accentColor.opacity(0.08),
                    backgroundColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
            }

            VStack(spacing: 6) {
                Text("No Recent Projects")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Create a new project or open an existing one to get started")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }

    private func loadRecents() {
        #if canImport(AppKit)
        let docURLs = NSDocumentController.shared.recentDocumentURLs
        let pool = docURLs + extraRecents
        let unique = Dictionary(grouping: pool.map { $0.standardizedFileURL }) { $0 }.keys
        let filtered = unique.filter { url in
            // Check for .runner extension (case-insensitive)
            guard url.pathExtension.lowercased() == "runner" else { return false }
            // Start security-scoped access to check if file exists
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted { url.stopAccessingSecurityScopedResource() }
            }
            // Verify the file actually exists on disk
            return FileManager.default.fileExists(atPath: url.path)
        }
        let sorted = filtered.sorted { a, b in
            // Start security-scoped access for each URL before reading attributes
            let aAccess = a.startAccessingSecurityScopedResource()
            let bAccess = b.startAccessingSecurityScopedResource()
            defer {
                if aAccess { a.stopAccessingSecurityScopedResource() }
                if bAccess { b.stopAccessingSecurityScopedResource() }
            }
            let aDate = (try? FileManager.default.attributesOfItem(atPath: a.path)[.modificationDate] as? Date) ?? .distantPast
            let bDate = (try? FileManager.default.attributesOfItem(atPath: b.path)[.modificationDate] as? Date) ?? .distantPast
            return aDate > bDate
        }
        recent = Array(sorted)
        #endif
    }

    private func handleOpen(_ url: URL) {
        if let onOpen { onOpen(url); return }
        do {
            _ = try PRFileOpsShim.upgradeLegacyPackageIfNeeded(at: url)
            #if canImport(AppKit)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            #endif
            NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
            NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
        } catch {
            #if DEBUG
            print("openProject failed:", error)
            #endif
        }
    }

    private func fetchPrimaryProject() -> NSManagedObject? {
        let ctx = PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        let sort = NSSortDescriptor(key: "updatedAt", ascending: false)
        let sort2 = NSSortDescriptor(key: "createdAt", ascending: false)
        req.sortDescriptors = [sort, sort2]
        req.fetchLimit = 1
        return try? ctx.fetch(req).first
    }

    @AppStorage("account_name") private var accountName: String = ""
    @AppStorage("account_role") private var accountRole: String = ""

    private var accountFooter: some View {
        VStack(spacing: 12) {
            // User Account and Settings Buttons
            HStack(spacing: 12) {
                // User Account Button
                Button(action: { showAccountSheet = true }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(accountName.isEmpty ? "User Account" : accountName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Text(accountRole.isEmpty ? "Tap to set up your account" : accountRole)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.35))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: 420)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.3),
                                        Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.2)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Settings Button
                Button(action: { showAppSettings = true }) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.3),
                                            Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .help("App Settings")
            }

        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    backgroundColor,
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct RecentRow: View {
    let url: URL
    var open: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHover = false
    @State private var modifiedDate: Date? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Combined project card with attached trash button
            HStack(spacing: 0) {
                // Open button (main area) - Compact width with glow
                Button(action: open) {
                    HStack(spacing: 12) {
                        // Project icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.3),
                                            Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)

                            Image(systemName: "film.stack")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                        }

                        // Project name only
                        Text(url.deletingPathExtension().lastPathComponent)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        // Date
                        if let d = modifiedDate {
                            Text(relativeDate(d))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.35))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                #if os(macOS)
                // Delete button attached to the right edge
                Button(action: {
                    confirmAndTrash()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                        .frame(width: 40, height: 44)
                }
                .buttonStyle(.plain)
                .help("Move to Trash")
                #endif
            }
            .frame(width: 520)
            .background(
                ZStack {
                    // Glowing gradient background with complementary colors
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.35).opacity(isHover ? 0.22 : 0.15),
                                    Color(red: 0.95, green: 0.35, blue: 0.50).opacity(isHover ? 0.18 : 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border glow
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.35).opacity(isHover ? 0.6 : 0.4),
                                    Color(red: 0.95, green: 0.35, blue: 0.50).opacity(isHover ? 0.5 : 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHover ? 2 : 1.5
                        )
                }
            )
            .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.50).opacity(isHover ? 0.4 : 0.2), radius: isHover ? 12 : 8, x: 0, y: isHover ? 6 : 4)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isHover ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHover)
        .onHover { isHover = $0 }
        .onAppear(perform: fetchDate)
        .contextMenu {
            #if canImport(AppKit)
            Button("Open") { open() }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Divider()
            Button(role: .destructive, action: {
                confirmAndTrash()
            }) {
                Text("Move to Trash…")
            }
            #endif
        }
    }
    
    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return "\(days) days ago"
        } else {
            return Self.dateFormatter.string(from: date)
        }
    }

    private func fetchDate() {
        // Start security-scoped access for bookmark-resolved URLs
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date {
            modifiedDate = mod
        }
    }

    #if os(macOS)
    private func confirmAndTrash() {
        let alert = NSAlert()
        alert.messageText = "Move to Trash?"
        alert.informativeText = "This will move the project '\(url.lastPathComponent)' to the Trash. You can restore it from the Trash if needed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                // Remove from NSDocumentController's recent documents list before deleting
                NSDocumentController.shared.clearRecentDocuments(nil)
                let currentRecents = NSDocumentController.shared.recentDocumentURLs.filter { $0.standardizedFileURL != url.standardizedFileURL }
                currentRecents.forEach { NSDocumentController.shared.noteNewRecentDocumentURL($0) }

                try PRFileOps.deleteProject(at: url)
                NotificationCenter.default.post(name: .prProjectDeleted, object: url)
                NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
            } catch {
                let fail = NSAlert()
                fail.messageText = "Couldn't Delete Project"
                fail.informativeText = error.localizedDescription
                fail.alertStyle = .critical
                fail.addButton(withTitle: "OK")
                fail.runModal()
            }
        }
    }
    #endif

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()
}

// MARK: - Compact Recent Row (iPhone)
#if os(iOS)
private struct CompactRecentRow: View {
    let url: URL
    var open: () -> Void

    @State private var modifiedDate: Date? = nil

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                // Smaller project icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.25),
                                    Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "film.stack")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.50))
                }

                // Project name
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Date
                if let d = modifiedDate {
                    Text(relativeDate(d))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.35))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.12),
                                Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.3),
                                Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear(perform: fetchDate)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return "\(days)d ago"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            return df.string(from: date)
        }
    }

    private func fetchDate() {
        // Start security-scoped access for bookmark-resolved URLs
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date {
            modifiedDate = mod
        }
    }
}
#endif

// MARK: - iOS File Operations
#if !os(macOS)
@MainActor
private class PRFileOpsIOS {
    enum PROpsError: Error { 
        case userCancelled
        case invalidURL
        case noViewController
    }
    
    static func newProject() async throws -> URL {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            throw PROpsError.noViewController
        }
        
        // Create a temporary .runner package
        let tempDir = FileManager.default.temporaryDirectory
        let projectName = "Untitled Project.runner"
        let tempURL = tempDir.appendingPathComponent(projectName)
        
        // Create the package folder
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        
        // Drop a metadata file
        let metaURL = tempURL.appendingPathComponent("project.json")
        let payload = Data("{\"created\":\"\(ISO8601DateFormatter().string(from: Date()))\"}".utf8)
        try? payload.write(to: metaURL)
        
        // Present document picker to move/export the project
        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: false)
        picker.delegate = DocumentPickerCoordinator.shared
        
        return try await withCheckedThrowingContinuation { continuation in
            DocumentPickerCoordinator.shared.continuation = continuation
            rootVC.present(picker, animated: true)
        }
    }
    
    static func openProject() async throws -> URL {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            throw PROpsError.noViewController
        }
        
        let primaryType = UTType(filenameExtension: "runner", conformingTo: .package) ?? .data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [primaryType])
        picker.delegate = DocumentPickerCoordinator.shared
        picker.allowsMultipleSelection = false
        
        return try await withCheckedThrowingContinuation { continuation in
            DocumentPickerCoordinator.shared.continuation = continuation
            rootVC.present(picker, animated: true)
        }
    }
    
    @discardableResult
    static func upgradeLegacyPackageIfNeeded(at url: URL) throws -> URL { url }
    
    static func deleteProject(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

private class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    static let shared = DocumentPickerCoordinator()
    var continuation: CheckedContinuation<URL, Error>?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            continuation?.resume(throwing: PRFileOpsIOS.PROpsError.invalidURL)
            continuation = nil
            return
        }
        
        // Start accessing security-scoped resource
        _ = url.startAccessingSecurityScopedResource()
        
        continuation?.resume(returning: url)
        continuation = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(throwing: PRFileOpsIOS.PROpsError.userCancelled)
        continuation = nil
    }
}
#endif

private enum PRFileOpsShim {
#if os(macOS)
    @MainActor
    static func newProject() async throws -> URL { try PRFileOps.newProject() }
    @MainActor
    static func openProject() async throws -> URL { try PRFileOps.openProject() }
    @discardableResult
    static func upgradeLegacyPackageIfNeeded(at url: URL) throws -> URL { try PRFileOps.upgradeLegacyPackageIfNeeded(at: url) }
    static func deleteProject(at url: URL) throws { try PRFileOps.deleteProject(at: url) }
#else
    @MainActor
    static func newProject() async throws -> URL {
        try await PRFileOpsIOS.newProject()
    }
    
    @MainActor
    static func openProject() async throws -> URL {
        try await PRFileOpsIOS.openProject()
    }
    
    @MainActor @discardableResult
    static func upgradeLegacyPackageIfNeeded(at url: URL) throws -> URL { try PRFileOpsIOS.upgradeLegacyPackageIfNeeded(at: url) }
    @MainActor static func deleteProject(at url: URL) throws { try PRFileOpsIOS.deleteProject(at: url) }
#endif
}

// MARK: - Launch Settings Sheet (Appearance only, no project required)
private struct LaunchSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_appearance") private var appAppearance: String = "system"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                    Text("App preferences")
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
            }
            .padding(24)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 20) {
                Text("Appearance")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        Picker("Appearance", selection: $appAppearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appAppearance) { newValue in
                            applyAppearance(newValue)
                        }
                    }

                    Text("Choose how Production Runner appears. System follows your Mac's appearance setting.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(24)

            Spacer()

            Divider()

            // Done button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 400, height: 320)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #endif
        .onAppear {
            // Apply current appearance when sheet opens
            applyAppearance(appAppearance)
        }
    }

    private func applyAppearance(_ appearance: String) {
        AppAppearance.apply(appearance)
    }
}
