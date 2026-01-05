//
//  Celtx_Import.swift
//  Production Runner
//
//  Celtx file importer for screenplay files
//  Celtx files are .celtx (zipped) or .html exports
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct Celtx_Import: View {
    @Environment(\.managedObjectContext) private var moc
    @State private var isImporterPresented = false
    @State private var importLog: [String] = []
    @State private var isBusy = false
    @State private var importedSceneCount = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Celtx Importer")
                .font(.largeTitle).bold()

            Text("Import Celtx screenplay files into Scenes.")
                .font(.subheadline)

            HStack {
                Button(action: { isImporterPresented = true }) {
                    Label("Choose Celtx File", systemImage: "doc.badge.plus")
                }
                .disabled(isBusy)
                if isBusy { ProgressView().padding(.leading, 8) }
                Spacer()
                if importedSceneCount > 0 {
                    Text("\(importedSceneCount) scenes imported")
                        .foregroundStyle(.green)
                }
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(importLog.indices, id: \.self) { i in
                        Text(importLog[i])
                            .font(.caption.monospaced())
                            .foregroundStyle(logColor(for: importLog[i]))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 4)
            }
            .background(Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer(minLength: 0)
        }
        .padding()
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "celtx") ?? .xml,
                .xml,
                .html
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await performImport(url: url) }
            case .failure(let err):
                appendLog("[Error] Importer error: \(err.localizedDescription)")
            }
        }
    }

    private func logColor(for line: String) -> Color {
        if line.contains("[Error]") { return .red }
        if line.contains("[Warning]") { return .orange }
        if line.contains("[Success]") { return .green }
        return .primary
    }

    private func performImport(url: URL) async {
        // Fetch a project from the current context
        let fetch = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        fetch.fetchLimit = 1
        guard let project = try? moc.fetch(fetch).first else {
            appendLog("[Error] No ProjectEntity found. Create a project first.")
            return
        }

        isBusy = true
        defer { Task { @MainActor in isBusy = false } }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        appendLog("[Celtx] Starting import: \(url.lastPathComponent)")

        do {
            let parser = CeltxParser(context: moc, project: project)
            let scenes = try await parser.parse(url: url, logHandler: { message in
                Task { @MainActor in
                    self.appendLog(message)
                }
            })

            await MainActor.run {
                importedSceneCount = scenes.count
                appendLog("[Success] Imported \(scenes.count) scenes")
            }
        } catch {
            appendLog("[Error] Import failed: \(error.localizedDescription)")
        }
    }

    private func appendLog(_ line: String) {
        Task { @MainActor in
            withAnimation { importLog.append(line) }
        }
    }
}

// MARK: - Celtx Parser

class CeltxParser {
    private let context: NSManagedObjectContext
    private let project: ProjectEntity

    init(context: NSManagedObjectContext, project: ProjectEntity) {
        self.context = context
        self.project = project
    }

    func parse(url: URL, logHandler: @escaping (String) -> Void) async throws -> [SceneEntity] {
        // Read file data
        let data = try Data(contentsOf: url)

        // Check if it's a ZIP archive (Celtx files are zipped)
        if data.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]) {
            logHandler("[Celtx] Detected ZIP archive format")
            return try await parseZippedCeltx(data: data, logHandler: logHandler)
        }

        // Try as text content
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw CeltxParseError.invalidEncoding
        }

        if content.contains("<!DOCTYPE html") || content.contains("<html") {
            logHandler("[Celtx] Detected HTML export format")
            return try await parseHTMLContent(content: content, logHandler: logHandler)
        } else if content.contains("<?xml") {
            logHandler("[Celtx] Detected XML format")
            return try await parseXMLContent(content: content, logHandler: logHandler)
        }

        // Fallback to plain text parsing
        logHandler("[Celtx] Attempting plain text parsing")
        return try await parsePlainText(content: content, logHandler: logHandler)
    }

    private func parseZippedCeltx(data: Data, logHandler: @escaping (String) -> Void) async throws -> [SceneEntity] {
        // Create temp file for ZIP extraction
        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        let tempExtractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        defer {
            try? FileManager.default.removeItem(at: tempZipURL)
            try? FileManager.default.removeItem(at: tempExtractDir)
        }

        try data.write(to: tempZipURL)
        try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)

        // Use Process to unzip (macOS only)
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", tempZipURL.path, "-d", tempExtractDir.path]
        process.standardOutput = nil
        process.standardError = nil
        try process.run()
        process.waitUntilExit()

        logHandler("[Celtx] Extracted archive contents")

        // Find screenplay HTML file
        let enumerator = FileManager.default.enumerator(at: tempExtractDir, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            let filename = fileURL.lastPathComponent.lowercased()
            if filename.hasSuffix(".html") || filename.hasSuffix(".htm") {
                if filename.contains("script") || filename.contains("screenplay") || filename == "index.html" {
                    logHandler("[Celtx] Found screenplay: \(fileURL.lastPathComponent)")
                    let htmlData = try Data(contentsOf: fileURL)
                    if let content = String(data: htmlData, encoding: .utf8) {
                        return try await parseHTMLContent(content: content, logHandler: logHandler)
                    }
                }
            }
        }

        // Try any HTML file
        let contents = try FileManager.default.contentsOfDirectory(at: tempExtractDir, includingPropertiesForKeys: nil)
        for file in contents {
            if file.pathExtension.lowercased() == "html" || file.pathExtension.lowercased() == "htm" {
                logHandler("[Celtx] Trying HTML file: \(file.lastPathComponent)")
                let htmlData = try Data(contentsOf: file)
                if let content = String(data: htmlData, encoding: .utf8) {
                    return try await parseHTMLContent(content: content, logHandler: logHandler)
                }
            }
        }
        #endif

        throw CeltxParseError.noScreenplayFound
    }

    private func parseHTMLContent(content: String, logHandler: @escaping (String) -> Void) async throws -> [SceneEntity] {
        var scenes: [SceneEntity] = []
        var currentSceneNumber = 0
        var currentElements: [(type: String, text: String)] = []

        // Celtx HTML uses specific CSS classes for screenplay elements
        let patterns: [(className: String, elementType: String)] = [
            ("sceneheading", "Scene Heading"),
            ("scene-heading", "Scene Heading"),
            ("slugline", "Scene Heading"),
            ("action", "Action"),
            ("character", "Character"),
            ("dialog", "Dialogue"),
            ("dialogue", "Dialogue"),
            ("parenthetical", "Parenthetical"),
            ("transition", "Transition"),
            ("shot", "Shot")
        ]

        // Extract paragraphs with class attributes
        let paragraphPattern = #"<p[^>]*class\s*=\s*[\"']([^\"']*)[\"'][^>]*>(.*?)</p>"#
        let paragraphRegex = try NSRegularExpression(pattern: paragraphPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])

        let range = NSRange(content.startIndex..., in: content)
        let matches = paragraphRegex.matches(in: content, range: range)

        logHandler("[Celtx] Found \(matches.count) styled paragraph elements")

        for match in matches {
            guard let classRange = Range(match.range(at: 1), in: content),
                  let textRange = Range(match.range(at: 2), in: content) else { continue }

            let className = String(content[classRange]).lowercased()
            var text = String(content[textRange])

            // Strip HTML tags from text
            text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text = text.decodingHTMLEntities()

            guard !text.isEmpty else { continue }

            // Determine element type
            var elementType = "Action"
            for pattern in patterns {
                if className.contains(pattern.className) {
                    elementType = pattern.elementType
                    break
                }
            }

            // Check if this is a new scene
            if elementType == "Scene Heading" {
                // Save previous scene if exists
                if !currentElements.isEmpty {
                    let scene = try createSceneEntity(
                        number: currentSceneNumber,
                        elements: currentElements,
                        logHandler: logHandler
                    )
                    scenes.append(scene)
                }

                currentSceneNumber += 1
                currentElements = [(elementType, text)]
                logHandler("[Celtx] Scene \(currentSceneNumber): \(text.prefix(50))...")
            } else {
                currentElements.append((elementType, text))
            }
        }

        // Save last scene
        if !currentElements.isEmpty {
            let scene = try createSceneEntity(
                number: currentSceneNumber,
                elements: currentElements,
                logHandler: logHandler
            )
            scenes.append(scene)
        }

        // If no scenes found with class-based parsing, try fallback
        if scenes.isEmpty {
            logHandler("[Celtx] No class-based elements found, trying pattern matching")
            return try await parsePlainText(content: content, logHandler: logHandler)
        }

        try context.save()
        logHandler("[Celtx] Saved \(scenes.count) scenes to database")

        return scenes
    }

    private func parseXMLContent(content: String, logHandler: @escaping (String) -> Void) async throws -> [SceneEntity] {
        // Celtx XML format uses similar structure
        return try await parseHTMLContent(content: content, logHandler: logHandler)
    }

    private func parsePlainText(content: String, logHandler: @escaping (String) -> Void) async throws -> [SceneEntity] {
        var scenes: [SceneEntity] = []

        // Look for scene heading patterns: INT. / EXT. / INT./EXT.
        let sceneHeadingPattern = #"(?:^|\n)\s*((?:INT\.|EXT\.|INT\./EXT\.|I/E\.)[^\n<]+)"#
        let sceneRegex = try NSRegularExpression(pattern: sceneHeadingPattern, options: [.caseInsensitive])

        let range = NSRange(content.startIndex..., in: content)
        let matches = sceneRegex.matches(in: content, range: range)

        logHandler("[Celtx] Found \(matches.count) scene headings via pattern matching")

        for (index, match) in matches.enumerated() {
            guard let headingRange = Range(match.range(at: 1), in: content) else { continue }
            let heading = String(content[headingRange])
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .decodingHTMLEntities()

            let sceneNumber = index + 1
            logHandler("[Celtx] Scene \(sceneNumber): \(heading.prefix(50))...")

            let scene = SceneEntity(context: context)
            scene.id = UUID()
            scene.number = String(sceneNumber)
            scene.sceneSlug = heading
            scene.displayOrder = Int32(sceneNumber)
            scene.createdAt = Date()
            scene.lastLocalEdit = Date()
            scene.project = project

            // Parse location and time of day
            let parts = heading.components(separatedBy: " - ")
            if parts.count >= 2 {
                var location = parts[0]
                for prefix in ["INT.", "EXT.", "INT./EXT.", "I/E."] {
                    if location.uppercased().hasPrefix(prefix) {
                        location = String(location.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                scene.scriptLocation = location
                scene.timeOfDay = parts.last?.trimmingCharacters(in: .whitespaces)
            }

            scenes.append(scene)
        }

        try context.save()
        return scenes
    }

    private func createSceneEntity(number: Int, elements: [(type: String, text: String)], logHandler: @escaping (String) -> Void) throws -> SceneEntity {
        let scene = SceneEntity(context: context)
        scene.id = UUID()
        scene.number = String(number)
        scene.displayOrder = Int32(number)
        scene.createdAt = Date()
        scene.lastLocalEdit = Date()
        scene.project = project

        // First element should be scene heading
        if let firstElement = elements.first, firstElement.type == "Scene Heading" {
            scene.sceneSlug = firstElement.text

            // Parse location and time
            let parts = firstElement.text.components(separatedBy: " - ")
            if parts.count >= 2 {
                var location = parts[0]
                for prefix in ["INT.", "EXT.", "INT./EXT.", "I/E."] {
                    if location.uppercased().hasPrefix(prefix) {
                        location = String(location.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                scene.scriptLocation = location
                scene.timeOfDay = parts.last?.trimmingCharacters(in: .whitespaces)
            }
        }

        // Compile description from remaining elements
        let bodyElements = elements.dropFirst()
        var bodyText = ""
        for element in bodyElements {
            if !bodyText.isEmpty { bodyText += "\n" }
            bodyText += element.text
        }
        scene.descriptionText = String(bodyText.prefix(500))

        return scene
    }
}

// MARK: - Celtx Parse Errors

enum CeltxParseError: LocalizedError {
    case noScreenplayFound
    case invalidEncoding
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noScreenplayFound:
            return "No screenplay content found in the Celtx file"
        case .invalidEncoding:
            return "Unable to read file encoding"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

// MARK: - String HTML Decoding Extension

extension String {
    func decodingHTMLEntities() -> String {
        var result = self
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&#160;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "...",
            "&rsquo;": "\u{2019}",
            "&lsquo;": "\u{2018}",
            "&rdquo;": "\u{201D}",
            "&ldquo;": "\u{201C}"
        ]
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }
}

#Preview {
    Celtx_Import()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
