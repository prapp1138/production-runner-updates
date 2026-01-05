import Foundation
import CoreData
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

enum AssetKind: String { case script, document, other }

struct AssetAnalysis { var pages: Int?; var scenes: Int?; var words: Int? }

enum AssetStore {
    /// Adds a file using a previously-created security-scoped bookmark.
    /// Resolves the bookmark to a URL and forwards to the existing importer.
    static func addFile(at originalURL: URL,
                        bookmark: Data,
                        to project: NSManagedObject,
                        projectFileURL: URL?,
                        in context: NSManagedObjectContext) throws
    {
        var isStale = false
        // Resolve the bookmark to a file URL. We do not startAccessing here;
        // the existing addFile(at:to:projectFileURL:in:) handles security scope.
        #if os(macOS)
        let resolveOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let resolveOptions: URL.BookmarkResolutionOptions = []
        #endif
        let resolvedURL = try URL(resolvingBookmarkData: bookmark,
                                  options: resolveOptions,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)
        // Forward to existing logic so all coordination/copying and Core Data writes stay centralized.
        try addFile(at: resolvedURL, to: project, projectFileURL: projectFileURL, in: context)
    }

    static func addFile(at url: URL, to project: NSManagedObject, projectFileURL: URL?, in context: NSManagedObjectContext) throws {
        #if os(macOS)
        let scoped = url.startAccessingSecurityScopedResource()
        var pkgScoped = false
        if let pkg = projectFileURL { pkgScoped = pkg.startAccessingSecurityScopedResource() }

        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
            if pkgScoped, let pkg = projectFileURL { pkg.stopAccessingSecurityScopedResource() }
        }
        #endif

        let pidString: String
        if let u: UUID = (project.value(forKey: "id") as? UUID) { pidString = u.uuidString }
        else if let s = project.value(forKey: "id") as? String { pidString = s }
        else { throw NSError(domain: "AssetStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Project missing id"]) }

        let destURL: URL
        if let packageURL = projectFileURL {
            let assetsDir = packageURL.appendingPathComponent("Project Assets", isDirectory: true)
            // Coordinate writes into the package to satisfy sandbox + document coordination
            #if os(macOS) || os(iOS)
            let coordinator = NSFileCoordinator()

            var mkdirCoordError: NSError?
            var mkdirInnerError: Error?
            coordinator.coordinate(writingItemAt: assetsDir, options: .forMerging, error: &mkdirCoordError) { writeDir in
                do {
                    try FileManager.default.createDirectory(at: writeDir, withIntermediateDirectories: true)
                } catch {
                    mkdirInnerError = error
                }
            }
            if let e = mkdirCoordError { throw e }
            if let e = mkdirInnerError { throw e }

            let candidate = uniqueDestination(for: url.lastPathComponent, in: assetsDir)
            destURL = candidate

            var copyCoordError: NSError?
            var copyInnerError: Error?
            coordinator.coordinate(writingItemAt: destURL, options: .forReplacing, error: &copyCoordError) { writeURL in
                do {
                    _ = try? FileManager.default.removeItem(at: writeURL)
                    try FileManager.default.copyItem(at: url, to: writeURL)
                } catch {
                    copyInnerError = error
                }
            }
            if let e = copyCoordError { throw e }
            if let e = copyInnerError { throw e }
            #else
            try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
            destURL = uniqueDestination(for: url.lastPathComponent, in: assetsDir)
            try FileManager.default.copyItem(at: url, to: destURL)
            #endif
        } else {
            destURL = url
        }

        // Always persist a bookmark to satisfy Core Data "required" constraint,
        // using security scope for external URLs and a plain bookmark for package URLs.
        let bookmarkData: Data = {
            if projectFileURL != nil {
                // Inside the .runner package: no security scope needed, but still store a bookmark.
                return (try? destURL.bookmarkData()) ?? Data()
            } else {
                #if os(macOS)
                return (try? url.bookmarkData(options: [.withSecurityScope],
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil)) ?? ((try? url.bookmarkData()) ?? Data())
                #else
                return (try? url.bookmarkData()) ?? Data()
                #endif
            }
        }()

        let ext = destURL.pathExtension.lowercased()
        let name = destURL.deletingPathExtension().lastPathComponent

        let a = NSEntityDescription.insertNewObject(forEntityName: "AssetEntity", into: context)
        let aAttrs = a.entity.attributesByName

        if aAttrs["id"] != nil { a.setValue(UUID(), forKey: "id") }
        if aAttrs["projectId"] != nil { a.setValue(pidString, forKey: "projectId") }
        if aAttrs["name"] != nil { a.setValue(name, forKey: "name") }
        if aAttrs["fileExt"] != nil { a.setValue(ext, forKey: "fileExt") }
        if aAttrs["createdAt"] != nil { a.setValue(Date(), forKey: "createdAt") }
        if aAttrs["bookmark"] != nil { a.setValue(bookmarkData, forKey: "bookmark") }
        if aAttrs["kind"] != nil { a.setValue(classify(ext: ext).rawValue, forKey: "kind") }
        if projectFileURL != nil, aAttrs["relativePath"] != nil {
            a.setValue("Project Assets/\(destURL.lastPathComponent)", forKey: "relativePath")
        }

        let analysis = analyze(url: destURL, ext: ext)
        if let pages = analysis.pages, aAttrs["pages"] != nil { a.setValue(pages, forKey: "pages") }
        if let scenes = analysis.scenes, aAttrs["scenes"] != nil { a.setValue(scenes, forKey: "scenes") }
        if let words = analysis.words, aAttrs["words"] != nil { a.setValue(words, forKey: "words") }

        let projAttrs = project.entity.attributesByName
        if projAttrs["modifiedAt"] != nil { project.setValue(Date(), forKey: "modifiedAt") }
        try context.save()
    }

    // MARK: - URL resolution helpers for UI/metadata use
    /// Resolves an AssetEntity to a readable URL, preferring relativePath inside the package,
    /// and falling back to the stored bookmark.
    static func resolvedURL(for asset: NSManagedObject, projectFileURL: URL?) -> URL? {
        if let rel = asset.value(forKey: "relativePath") as? String,
           let packageURL = projectFileURL {
            let full = packageURL.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: full.path) {
                return full
            }
        }
        if let data = asset.value(forKey: "bookmark") as? Data {
            var stale = false
            #if os(macOS)
            let opts: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let opts: URL.BookmarkResolutionOptions = []
            #endif
            if let url = try? URL(resolvingBookmarkData: data, options: opts, relativeTo: nil, bookmarkDataIsStale: &stale) {
                return url
            }
        }
        return nil
    }

    /// Returns the file size (in bytes) for a URL if available.
    static func fileSize(at url: URL) -> Int64? {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let n = attrs[.size] as? NSNumber {
            return n.int64Value
        }
        return nil
    }

    /// Returns a displayable content type string using extension/UTType if available.
    static func displayContentType(forExt ext: String) -> String {
        #if canImport(UniformTypeIdentifiers)
        if let type = UTType(filenameExtension: ext) {
            return type.localizedDescription ?? ext.uppercased()
        }
        #endif
        switch ext.lowercased() {
        case "pdf": return "PDF Document"
        case "fdx": return "Final Draft Document"
        case "celtx": return "Celtx Document"
        case "txt": return "Plain Text"
        case "rtf": return "Rich Text"
        case "doc": return "Word Document"
        case "docx": return "Word Document"
        default: return ext.uppercased()
        }
    }

    static func deleteFile(_ asset: NSManagedObject,
                           projectFileURL: URL?,
                           in context: NSManagedObjectContext) throws {
        // Resolve file URL preference: relativePath inside package, else bookmark
        var targetURL: URL? = nil

        if let rel = asset.value(forKey: "relativePath") as? String,
           let packageURL = projectFileURL {
            let full = packageURL.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: full.path) {
                targetURL = full
            }
        }

        if targetURL == nil,
           let data = asset.value(forKey: "bookmark") as? Data {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) {
                targetURL = url
            }
        }

        // Move to Trash (macOS) or remove (iOS)
        if let url = targetURL {
            #if os(macOS)
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            #else
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            #endif
        }

        // Remove Core Data row
        context.delete(asset)
        try context.save()
    }

    static func deleteFiles(_ assets: [NSManagedObject],
                            projectFileURL: URL?,
                            in context: NSManagedObjectContext) throws {
        for a in assets {
            // Delete one-by-one without saving each time to minimize disk I/O
            // but reuse the single delete logic by not saving inside it.
            // We'll inline the logic here to batch the Core Data save.
            var targetURL: URL? = nil
            if let rel = a.value(forKey: "relativePath") as? String,
               let packageURL = projectFileURL {
                let full = packageURL.appendingPathComponent(rel)
                if FileManager.default.fileExists(atPath: full.path) {
                    targetURL = full
                }
            }
            if targetURL == nil,
               let data = a.value(forKey: "bookmark") as? Data {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) {
                    targetURL = url
                }
            }
            if let url = targetURL {
                #if os(macOS)
                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                #else
                if FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
                #endif
            }
            context.delete(a)
        }
        try context.save()
    }

    static func classify(ext: String) -> AssetKind {
        switch ext { case "pdf","fdx","celtx": return .script
        case "txt","rtf","doc","docx": return .document
        default: return .other }
    }

    static func analyze(url: URL, ext: String) -> AssetAnalysis {
        var out = AssetAnalysis(pages: nil, scenes: nil, words: nil)
        if ext == "pdf" {
            #if canImport(PDFKit)
            if let doc = PDFDocument(url: url) {
                out.pages = doc.pageCount
                var words = 0
                for i in 0..<doc.pageCount {
                    if let page = doc.page(at: i), let s = page.string {
                        words += s.split{ !$0.isLetter && !$0.isNumber }.count
                    }
                }
                out.words = words
            }
            #endif
        } else if ext == "fdx" {
            if let data = try? Data(contentsOf: url), let xml = String(data: data, encoding: .utf8) {
                let count = xml.components(separatedBy: "<SceneHeading>").count - 1
                out.scenes = max(count, 0)
                out.words = xml.split{ !$0.isLetter && !$0.isNumber }.count
            }
        }
        return out
    }

    private static func uniqueDestination(for filename: String, in folder: URL) -> URL {
        var candidate = folder.appendingPathComponent(filename)
        let ext = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var i = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let nextName = ext.isEmpty ? "\(stem) \(i)" : "\(stem) \(i).\(ext)"
            candidate = folder.appendingPathComponent(nextName)
            i += 1
        }
        return candidate
    }
}
