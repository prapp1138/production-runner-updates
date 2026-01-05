//
//  FadeIn_Import.swift
//  Production Runner
//
//  Fade-In file importer for screenplay files
//  .fadein files are XML-based screenplay documents
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct FadeIn_Import: View {
    @Environment(\.managedObjectContext) private var moc
    @State private var isImporterPresented = false
    @State private var importLog: [String] = []
    @State private var isBusy = false
    @State private var importedSceneCount = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fade-In Importer")
                .font(.largeTitle).bold()

            Text("Import Fade-In screenplay files (.fadein) into Scenes.")
                .font(.subheadline)

            HStack {
                Button(action: { isImporterPresented = true }) {
                    Label("Choose Fade-In File", systemImage: "doc.badge.plus")
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
                UTType(filenameExtension: "fadein") ?? .xml,
                .xml
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

        appendLog("[Fade-In] Starting import: \(url.lastPathComponent)")

        do {
            let parser = FadeInParser(context: moc, project: project)
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

// MARK: - Fade-In Parser

class FadeInParser: NSObject, XMLParserDelegate {
    private let context: NSManagedObjectContext
    private let project: ProjectEntity
    private var logHandler: ((String) -> Void)?

    // Parsing state
    private var scenes: [SceneEntity] = []
    private var currentElement: String = ""
    private var currentText: String = ""
    private var currentSceneNumber = 0
    private var currentElementType: String = ""
    private var currentSceneElements: [(type: String, text: String)] = []
    private var insideParagraph = false
    private var paragraphStyle: String = ""

    init(context: NSManagedObjectContext, project: ProjectEntity) {
        self.context = context
        self.project = project
        super.init()
    }

    func parse(url: URL, logHandler: @escaping (String) -> Void) async throws -> [SceneEntity] {
        self.logHandler = logHandler

        let data = try Data(contentsOf: url)

        // Check if it's a ZIP archive (some .fadein files are compressed)
        if data.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]) {
            logHandler("[Fade-In] Detected compressed format")
            return try await parseCompressedFadeIn(data: data, logHandler: logHandler)
        }

        // Try to parse as XML directly
        guard let xmlContent = String(data: data, encoding: .utf8) else {
            throw FadeInParseError.invalidEncoding
        }

        logHandler("[Fade-In] Parsing XML content (\(data.count) bytes)")

        // Check for Fade-In document structure
        if xmlContent.contains("<document") || xmlContent.contains("<FadeIn") || xmlContent.contains("<screenplay") {
            return try parseXMLContent(data: data, logHandler: logHandler)
        }

        // Fallback to text-based parsing
        logHandler("[Fade-In] Using pattern-based fallback parsing")
        return try parsePlainTextContent(content: xmlContent, logHandler: logHandler)
    }

    private func parseCompressedFadeIn(data: Data, logHandler: @escaping (String) -> Void) async throws -> [SceneEntity] {
        #if os(macOS)
        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        let tempExtractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        defer {
            try? FileManager.default.removeItem(at: tempZipURL)
            try? FileManager.default.removeItem(at: tempExtractDir)
        }

        try data.write(to: tempZipURL)
        try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", tempZipURL.path, "-d", tempExtractDir.path]
        process.standardOutput = nil
        process.standardError = nil
        try process.run()
        process.waitUntilExit()

        logHandler("[Fade-In] Extracted archive contents")

        // Look for the document XML file
        let enumerator = FileManager.default.enumerator(at: tempExtractDir, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            let filename = fileURL.lastPathComponent.lowercased()
            if filename.hasSuffix(".xml") || filename == "document.xml" || filename == "screenplay.xml" {
                logHandler("[Fade-In] Found document: \(fileURL.lastPathComponent)")
                let xmlData = try Data(contentsOf: fileURL)
                return try parseXMLContent(data: xmlData, logHandler: logHandler)
            }
        }

        // Try first file that might be XML
        let contents = try FileManager.default.contentsOfDirectory(at: tempExtractDir, includingPropertiesForKeys: nil)
        for file in contents {
            let fileData = try Data(contentsOf: file)
            if let content = String(data: fileData, encoding: .utf8),
               content.contains("<?xml") || content.contains("<document") {
                logHandler("[Fade-In] Trying file: \(file.lastPathComponent)")
                return try parseXMLContent(data: fileData, logHandler: logHandler)
            }
        }
        #endif

        throw FadeInParseError.noDocumentFound
    }

    private func parseXMLContent(data: Data, logHandler: @escaping (String) -> Void) throws -> [SceneEntity] {
        // Reset state
        scenes = []
        currentSceneNumber = 0
        currentSceneElements = []

        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            // Save final scene if any elements
            if !currentSceneElements.isEmpty {
                try saveCurrentScene()
            }

            try context.save()
            logHandler("[Fade-In] Saved \(scenes.count) scenes to database")
            return scenes
        } else if let error = parser.parserError {
            throw FadeInParseError.xmlError(error.localizedDescription)
        }

        throw FadeInParseError.parseError("Unknown XML parsing error")
    }

    private func parsePlainTextContent(content: String, logHandler: @escaping (String) -> Void) throws -> [SceneEntity] {
        var parsedScenes: [SceneEntity] = []

        // Look for scene heading patterns
        let sceneHeadingPattern = #"(?:^|\n)\s*((?:INT\.|EXT\.|INT\./EXT\.|I/E\.)[^\n]+)"#
        let sceneRegex = try NSRegularExpression(pattern: sceneHeadingPattern, options: [.caseInsensitive])

        let range = NSRange(content.startIndex..., in: content)
        let matches = sceneRegex.matches(in: content, range: range)

        logHandler("[Fade-In] Found \(matches.count) scene headings via pattern matching")

        for (index, match) in matches.enumerated() {
            guard let headingRange = Range(match.range(at: 1), in: content) else { continue }
            let heading = String(content[headingRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let sceneNumber = index + 1
            logHandler("[Fade-In] Scene \(sceneNumber): \(heading.prefix(50))...")

            let scene = SceneEntity(context: context)
            scene.id = UUID()
            scene.number = String(sceneNumber)
            scene.sceneSlug = heading
            scene.displayOrder = Int32(sceneNumber)
            scene.createdAt = Date()
            scene.lastLocalEdit = Date()
            scene.project = project

            // Parse location and time
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

            parsedScenes.append(scene)
        }

        try context.save()
        return parsedScenes
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""

        // Fade-In uses <para> or <p> elements with style attributes
        if currentElement == "para" || currentElement == "p" || currentElement == "paragraph" {
            insideParagraph = true
            // Get style attribute - Fade-In uses different attribute names
            paragraphStyle = attributeDict["style"]?.lowercased() ??
                            attributeDict["type"]?.lowercased() ??
                            attributeDict["class"]?.lowercased() ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideParagraph {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = elementName.lowercased()

        if element == "para" || element == "p" || element == "paragraph" {
            insideParagraph = false

            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            // Determine element type from style
            let elementType = mapStyleToElementType(paragraphStyle, text: text)

            if elementType == "Scene Heading" {
                // Save previous scene
                if !currentSceneElements.isEmpty {
                    try? saveCurrentScene()
                }
                currentSceneNumber += 1
                currentSceneElements = [(elementType, text)]
                logHandler?("[Fade-In] Scene \(currentSceneNumber): \(text.prefix(50))...")
            } else {
                currentSceneElements.append((elementType, text))
            }

            currentText = ""
            paragraphStyle = ""
        }
    }

    private func mapStyleToElementType(_ style: String, text: String) -> String {
        // Common Fade-In style names
        let styleMapping: [String: String] = [
            "scene heading": "Scene Heading",
            "sceneheading": "Scene Heading",
            "slug": "Scene Heading",
            "slugline": "Scene Heading",
            "action": "Action",
            "description": "Action",
            "character": "Character",
            "dialogue": "Dialogue",
            "dialog": "Dialogue",
            "parenthetical": "Parenthetical",
            "transition": "Transition",
            "shot": "Shot",
            "general": "Action"
        ]

        if let mapped = styleMapping[style] {
            return mapped
        }

        // Check text pattern for scene heading
        let upperText = text.uppercased()
        if upperText.hasPrefix("INT.") || upperText.hasPrefix("EXT.") ||
           upperText.hasPrefix("INT./EXT.") || upperText.hasPrefix("I/E.") {
            return "Scene Heading"
        }

        // Check for transitions
        if upperText.hasSuffix("TO:") || upperText == "FADE IN:" || upperText == "FADE OUT." {
            return "Transition"
        }

        // Check for all caps (likely character name)
        if text == text.uppercased() && text.count < 40 && !text.contains(".") {
            return "Character"
        }

        return "Action"
    }

    private func saveCurrentScene() throws {
        guard !currentSceneElements.isEmpty else { return }

        let scene = SceneEntity(context: context)
        scene.id = UUID()
        scene.number = String(currentSceneNumber)
        scene.displayOrder = Int32(currentSceneNumber)
        scene.createdAt = Date()
        scene.lastLocalEdit = Date()
        scene.project = project

        // First element should be scene heading
        if let firstElement = currentSceneElements.first, firstElement.type == "Scene Heading" {
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

        // Compile description
        let bodyElements = currentSceneElements.dropFirst()
        var bodyText = ""
        for element in bodyElements {
            if !bodyText.isEmpty { bodyText += "\n" }
            bodyText += element.text
        }
        scene.descriptionText = String(bodyText.prefix(500))

        scenes.append(scene)
        currentSceneElements = []
    }
}

// MARK: - Fade-In Parse Errors

enum FadeInParseError: LocalizedError {
    case noDocumentFound
    case invalidEncoding
    case xmlError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noDocumentFound:
            return "No screenplay document found in the Fade-In file"
        case .invalidEncoding:
            return "Unable to read file encoding"
        case .xmlError(let message):
            return "XML parsing error: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

#Preview {
    FadeIn_Import()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
