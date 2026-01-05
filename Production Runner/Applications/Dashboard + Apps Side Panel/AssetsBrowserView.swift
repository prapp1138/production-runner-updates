import SwiftUI
import CoreData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum AssetsViewMode: String, CaseIterable { case list = "List", icons = "Icons" }

struct AssetsBrowserView: View {
    let project: NSManagedObject
    let projectFileURL: URL?
    var onBack: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var moc
    @State private var viewMode: AssetsViewMode = .list
    @State private var showingImporter = false
    @State private var selection = Set<NSManagedObjectID>()
    @State private var errorMessage: String?

    // MARK: - Allowed import types (polish)
    private var allowedTypes: [UTType] {
        var types: [UTType] = [.pdf]
        if let fdx = UTType(filenameExtension: "fdx") { types.append(fdx) }
        if let celtx = UTType(filenameExtension: "celtx") { types.append(celtx) }
        // Fallback: .data ensures we can still import when custom UTTypes aren't registered
        types.append(.data)
        return types
    }

    var fetchRequest: FetchRequest<NSManagedObject>
    init(project: NSManagedObject, onBack: (() -> Void)? = nil, projectFileURL: URL? = nil) {
        self.project = project
        self.onBack = onBack
        self.projectFileURL = projectFileURL
        let req: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "AssetEntity")
        req.predicate = NSPredicate(format: "projectId == %@", (project.value(forKey: "id") as? UUID)?.uuidString ?? (project.value(forKey: "id") as? String) ?? "")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        self.fetchRequest = FetchRequest(fetchRequest: req, animation: .default)
    }
    var assets: FetchedResults<NSManagedObject> { fetchRequest.wrappedValue }

    #if os(macOS)
    private func confirmMoveToTrash(message: String = "Move to Trash?",
                                    info: String = "Do you want to move the selected file(s) to the Trash and remove them from the project?",
                                    confirm: String = "Move to Trash",
                                    cancel: String = "Cancel") -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }
    #else
    private func confirmMoveToTrash(message: String = "", info: String = "", confirm: String = "", cancel: String = "") -> Bool { true }
    #endif

    private func resolvedURL(for a: NSManagedObject) -> URL? {
        if let rel = a.value(forKey: "relativePath") as? String,
           let pkg = projectFileURL {
            let u = pkg.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        if let data = a.value(forKey: "bookmark") as? Data {
            var stale = false
            #if os(macOS)
            let opts: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let opts: URL.BookmarkResolutionOptions = []
            #endif
            if let u = try? URL(resolvingBookmarkData: data,
                                options: opts,
                                relativeTo: nil,
                                bookmarkDataIsStale: &stale) {
                return u
            }
        }
        return nil
    }
#if os(macOS)
    private func revealInFinder(_ a: NSManagedObject) {
        guard let url = resolvedURL(for: a) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
#endif
    private func openFile(_ a: NSManagedObject) {
        guard let url = resolvedURL(for: a) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    // MARK: - Import handling with security-scoped bookmarks
    private func handleImport(urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ["pdf", "fdx", "celtx"].contains(ext) else {
                errorMessage = "Unsupported file type: .\(ext). Use PDF, FDX, or CELTX."
                continue
            }
            do {
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
                    projectFileURL: projectFileURL,
                    in: moc
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Project header consistent across app pages

            Text("Assets").font(.title2).bold()

            HStack {
                if let onBack = onBack {
                    Button(action: onBack) { Label("Back", systemImage: "chevron.left") }
                }
                Picker("", selection: $viewMode) {
                    ForEach(AssetsViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 250)

                Spacer()

                // Centered Add/Delete actions
                HStack(spacing: 12) {
                    Button { showingImporter = true } label: { Label("Add Files", systemImage: "plus") }
                    Button(role: .destructive) { deleteSelection() } label: { Label("Delete Files", systemImage: "trash") }
                        .disabled(selection.isEmpty)
                }
            }
            .padding(.horizontal)

            Divider()

            Group {
                if viewMode == .list { listView } else { iconsView }
            }
            .padding(.horizontal)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                handleImport(urls: urls)
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private var listView: some View {
        List(selection: $selection) {
            ForEach(assets, id: \.objectID) { a in
                HStack {
                    let ext = (a.value(forKey: "fileExt") as? String)?.lowercased() ?? ""
                    let name = (a.value(forKey: "name") as? String) ?? "Untitled"
                    Image(systemName: icon(for: ext))
                    Text(name + "." + ext)
                    Spacer()
                    if let pages = a.value(forKey: "pages") as? Int, pages > 0 { Text("\(pages)p").foregroundColor(.secondary) }
                    if let scenes = a.value(forKey: "scenes") as? Int, scenes > 0 { Text("\(scenes) scenes").foregroundColor(.secondary) }
                }
                .tag(a.objectID)
                #if os(macOS)
                .onTapGesture(count: 2) { openFile(a) }
                #endif
                .contextMenu {
                    Button { openFile(a) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                    #if os(macOS)
                    Button { revealInFinder(a) } label: { Label("Reveal in Finder", systemImage: "folder") }
                    Divider()
                    #endif
                    Button(role: .destructive) { deleteOne(a) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    private var iconsView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                ForEach(assets, id: \.objectID) { a in
                    let ext = (a.value(forKey: "fileExt") as? String)?.lowercased() ?? ""
                    let name = (a.value(forKey: "name") as? String) ?? "Untitled"
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.15)).frame(width: 120, height: 120)
                            Image(systemName: icon(for: ext)).font(.system(size: 40))
                        }
                        Text(name + "." + ext).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selection.contains(a.objectID) ? Color.accentColor : Color.clear, lineWidth: 2))
                    .onTapGesture {
                        if selection.contains(a.objectID) { selection.remove(a.objectID) } else { selection.insert(a.objectID) }
                    }
                    #if os(macOS)
                    .onTapGesture(count: 2) { openFile(a) }
                    #endif
                    .contextMenu {
                        Button { openFile(a) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                        #if os(macOS)
                        Button { revealInFinder(a) } label: { Label("Reveal in Finder", systemImage: "folder") }
                        Divider()
                        #endif
                        Button(role: .destructive) { deleteOne(a) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }.padding(12)
        }
    }

    private func deleteSelection() {
        #if os(macOS)
        guard confirmMoveToTrash() else { return }
        #endif
        let objects: [NSManagedObject] = selection.compactMap { try? moc.existingObject(with: $0) }
        do {
            try AssetStore.deleteFiles(objects, projectFileURL: projectFileURL, in: moc)
            selection.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    private func deleteOne(_ a: NSManagedObject) {
        #if os(macOS)
        guard confirmMoveToTrash() else { return }
        #endif
        do {
            try AssetStore.deleteFile(a, projectFileURL: projectFileURL, in: moc)
            selection.remove(a.objectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func icon(for ext: String) -> String {
        switch ext {
        case "pdf": return "doc.richtext"
        case "fdx": return "doc.text"
        default: return "doc"
        }
    }
}
