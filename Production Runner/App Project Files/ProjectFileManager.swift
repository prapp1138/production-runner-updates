import SwiftUI
import UniformTypeIdentifiers
import CoreData
#if canImport(AppKit)
import AppKit
#endif

#if !canImport(AppKit)
import UIKit
public typealias NSColor = UIColor
extension NSColor {
    static var windowBackgroundColor: NSColor { .systemBackground }
    static var controlBackgroundColor: NSColor { .secondarySystemBackground }
    static var controlAccentColor: NSColor { .tintColor }
    static var separatorColor: NSColor { .separator }
}
#endif


// Provide PFError for non-macOS platforms
#if !os(macOS)
enum PFError: Error { case userCancelled }
#endif

private extension Notification.Name {
    static let prRecentsDidChange = Notification.Name("prRecentsDidChange")
}

// MARK: - Minimal Project File Ops (macOS)
struct ProjectFileManager {
#if os(macOS)
    enum PFError: Error { case userCancelled }

    /// Create a new `.runner` package and return its URL
    static func newProject() throws -> URL {
        let panel = NSSavePanel()
        panel.title = "Create Production Runner Project"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [UTType(filenameExtension: "runner", conformingTo: .package) ?? .data]
        panel.nameFieldStringValue = "Untitled Project.runner"
        guard panel.runModal() == .OK, let dest = panel.url else { throw PFError.userCancelled }

        let url = dest.pathExtension.lowercased() == "runner" ? dest : dest.appendingPathExtension("runner")
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        // Seed minimal metadata so the package isn't empty
        let metaURL = url.appendingPathComponent("project.json")
        if !FileManager.default.fileExists(atPath: metaURL.path) {
            let payload = Data("{\"created\":\"\(ISO8601DateFormatter().string(from: Date()))\"}".utf8)
            try? payload.write(to: metaURL)
        }
        return url
    }

    /// Choose an existing `.runner` package and return its URL
    static func openProject() throws -> URL {
        let panel = NSOpenPanel()
        panel.title = "Open Production Runner Project"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "runner", conformingTo: .package) ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { throw PFError.userCancelled }
        return url
    }

    /// Placeholder for legacy upgrades; returns the input URL unchanged
    @discardableResult
    static func upgradeLegacyPackageIfNeeded(at url: URL) throws -> URL { url }

    /// Move a project package to the Trash
    static func deleteProject(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
#else
    // iOS implementations using UIDocumentPickerViewController
    @MainActor
    static func newProject() async throws -> URL {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            throw PFError.userCancelled
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let projectName = "Untitled Project.runner"
        let tempURL = tempDir.appendingPathComponent(projectName)
        
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        
        let metaURL = tempURL.appendingPathComponent("project.json")
        let payload = Data("{\"created\":\"\(ISO8601DateFormatter().string(from: Date()))\"}".utf8)
        try? payload.write(to: metaURL)
        
        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: false)
        picker.delegate = IOSDocumentPickerCoordinator.shared
        
        return try await withCheckedThrowingContinuation { continuation in
            IOSDocumentPickerCoordinator.shared.continuation = continuation
            rootVC.present(picker, animated: true)
        }
    }
    
    @MainActor
    static func openProject() async throws -> URL {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            throw PFError.userCancelled
        }
        
        let primaryType = UTType(filenameExtension: "runner", conformingTo: .package) ?? .data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [primaryType])
        picker.delegate = IOSDocumentPickerCoordinator.shared
        picker.allowsMultipleSelection = false
        
        return try await withCheckedThrowingContinuation { continuation in
            IOSDocumentPickerCoordinator.shared.continuation = continuation
            rootVC.present(picker, animated: true)
        }
    }
    
    @discardableResult 
    static func upgradeLegacyPackageIfNeeded(at url: URL) throws -> URL { url }
    
    static func deleteProject(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
#endif
}

#if !os(macOS)
private class IOSDocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    static let shared = IOSDocumentPickerCoordinator()
    var continuation: CheckedContinuation<URL, Error>?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            continuation?.resume(throwing: PFError.userCancelled)
            continuation = nil
            return
        }
        
        _ = url.startAccessingSecurityScopedResource()
        continuation?.resume(returning: url)
        continuation = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(throwing: PFError.userCancelled)
        continuation = nil
    }
}
#endif

// MARK: - Package Picker Helpers (AppKit panels)
public enum ProjectFilePicker {
    #if os(macOS)
    private static var primaryType: UTType {
        UTType(filenameExtension: "runner", conformingTo: .package) ?? .data
    }

    public static func promptToOpenPackage() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Production Runner Project"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [primaryType]
        return panel.runModal() == .OK ? panel.url : nil
    }

    public static func promptToCreatePackage(defaultName: String = "Untitled Project.runner") -> URL? {
        let panel = NSSavePanel()
        panel.title = "Create Production Runner Project"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [primaryType]
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }
    #else
    public static func promptToOpenPackage() -> URL? { nil }
    public static func promptToCreatePackage(defaultName: String = "Untitled Project.runner") -> URL? { nil }
    #endif
}

// MARK: - Recent Projects Dashboard (macOS)
private struct PRHeaderButton: View {
    let title: String
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                Text(title)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08))
                    )
            )
        }
        .buttonStyle(.plain)
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

public struct ProjectsDashboard: View {
    public var onOpen: ((URL) -> Void)?
    public var onCreate: ((URL) -> Void)?
    public var extraRecents: [URL] = []

    @State private var recent: [URL] = []
    @Environment(\.managedObjectContext) private var moc
    @State private var openedProject: NSManagedObject? = nil
    @State private var presentDashboard: Bool = false

    public init(onOpen: ((URL) -> Void)? = nil,
                onCreate: ((URL) -> Void)? = nil,
                extraRecents: [URL] = []) {
        self.onOpen = onOpen
        self.onCreate = onCreate
        self.extraRecents = extraRecents
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(NSColor.windowBackgroundColor))
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
            if let proj = openedProject {
                MainDashboardView(project: proj, projectFileURL: nil as URL?)
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            } else {
                Text("Loading Project…")
                    .padding()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Production Runner")
                .font(.system(size: 28, weight: .bold))
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {
                PRHeaderButton(title: "New Project", systemName: "plus.circle.fill") {
                    #if os(macOS)
                    do {
                        let url = try ProjectFileManager.newProject()
                        NSDocumentController.shared.noteNewRecentDocumentURL(url)
                        NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                        NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                        onCreate?(url)
                    } catch {
                        #if DEBUG
                        print("newProject failed:", error)
                        #endif
                    }
                    #else
                    Task { @MainActor in
                        do {
                            let url = try await ProjectFileManager.newProject()
                            NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                            NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                            onCreate?(url)
                        } catch {
                            #if DEBUG
                            print("newProject failed:", error)
                            #endif
                        }
                    }
                    #endif
                }

                PRHeaderButton(title: "Open Project…", systemName: "folder.fill") {
                    #if os(macOS)
                    do {
                        let url = try ProjectFileManager.openProject()
                        NSDocumentController.shared.noteNewRecentDocumentURL(url)
                        NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                        NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                        onOpen?(url)
                    } catch {
                        #if DEBUG
                        print("openProject failed:", error)
                        #endif
                    }
                    #else
                    Task { @MainActor in
                        do {
                            let url = try await ProjectFileManager.openProject()
                            NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
                            NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
                            onOpen?(url)
                        } catch {
                            #if DEBUG
                            print("openProject failed:", error)
                            #endif
                        }
                    }
                    #endif
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [
                    Color(NSColor.controlAccentColor).opacity(0.18),
                    Color(NSColor.controlAccentColor).opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.black.opacity(0.04))
            )
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Projects")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.horizontal, 24)

            if recent.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recent, id: \.self) { url in
                            RecentRow(url: url) {
                                handleOpen(url)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .imageScale(.large)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text("No recent projects yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Create a new project or open an existing .runner package.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadRecents() {
        #if canImport(AppKit)
        let docURLs = NSDocumentController.shared.recentDocumentURLs
        let pool = docURLs + extraRecents
        let unique = Dictionary(grouping: pool.map { $0.standardizedFileURL }) { $0 }.keys
        let filtered = unique.filter { $0.pathExtension.lowercased() == "runner" }
        let sorted = filtered.sorted { a, b in
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
            _ = try ProjectFileManager.upgradeLegacyPackageIfNeeded(at: url)
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
}

private struct RecentRow: View {
    let url: URL
    var open: () -> Void

    @State private var isHover = false
    @State private var modifiedDate: Date? = nil

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                ZstackIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(url.deletingLastPathComponent().path)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if let d = modifiedDate {
                    Text(Self.dateFormatter.string(from: d))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHover ? Color(NSColor.controlAccentColor).opacity(0.12) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isHover ? Color(NSColor.separatorColor).opacity(0.35) : Color.black.opacity(0.08))
                    )
            )
        }
        .buttonStyle(.plain)
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

    private var ZstackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)
                .frame(width: 36, height: 36)
            Image(systemName: "internaldrive")
                .imageScale(.medium)
                .foregroundStyle(.secondary)
        }
    }

    private func fetchDate() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date {
            modifiedDate = mod
        }
    }

    #if os(macOS)
    private func confirmAndTrash() {
        let alert = NSAlert()
        alert.messageText = "Move to Trash?"
        alert.informativeText = "This will move the project ‘\(url.lastPathComponent)’ to the Trash. You can restore it from the Trash if needed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try ProjectFileManager.deleteProject(at: url)
                NotificationCenter.default.post(name: .prRecentsDidChange, object: nil)
            } catch {
                let fail = NSAlert()
                fail.messageText = "Couldn’t Delete Project"
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
