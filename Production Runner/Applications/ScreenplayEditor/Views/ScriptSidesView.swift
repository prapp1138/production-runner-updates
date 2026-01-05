//
//  ScriptSidesView.swift
//  Production Runner
//
//  UI for generating script sides with filtering options.
//

import SwiftUI
import PDFKit
import CoreData

#if os(macOS)

struct ScriptSidesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc

    let document: ScreenplayDocument

    // MARK: - State

    @State private var filterType: ScriptSidesFilterType = .scenes
    @State private var selectedSceneNumbers: Set<String> = []
    @State private var selectedCharacter: String?
    @State private var selectedShootDayID: UUID?
    @State private var headerText: String = ""
    @State private var includeSceneNumbers: Bool = true
    @State private var includePageNumbers: Bool = true
    @State private var showRevisionMarks: Bool = true

    @State private var previewPDF: PDFDocument?
    @State private var isGenerating: Bool = false
    @State private var sceneSearchText: String = ""

    // MARK: - Computed

    private var scenes: [(number: String, heading: String)] {
        ScriptSidesGenerator.scenes(from: document)
    }

    private var characters: [String] {
        ScriptSidesGenerator.characters(from: document)
    }

    private var filteredScenes: [(number: String, heading: String)] {
        if sceneSearchText.isEmpty {
            return scenes
        }
        let search = sceneSearchText.lowercased()
        return scenes.filter {
            $0.number.lowercased().contains(search) ||
            $0.heading.lowercased().contains(search)
        }
    }

    private var canGenerate: Bool {
        switch filterType {
        case .scenes:
            return !selectedSceneNumbers.isEmpty
        case .character:
            return selectedCharacter != nil
        case .shootDay:
            return selectedShootDayID != nil
        }
    }

    // MARK: - Body

    var body: some View {
        HSplitView {
            // Left: Options
            optionsPanel
                .frame(minWidth: 320, maxWidth: 400)

            // Right: Preview
            previewPanel
                .frame(minWidth: 400)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            updatePreview()
        }
    }

    // MARK: - Options Panel

    private var optionsPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Generate Sides")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Filter Type Picker
                    filterTypePicker

                    Divider()

                    // Filter-specific options
                    switch filterType {
                    case .scenes:
                        sceneSelector
                    case .character:
                        characterSelector
                    case .shootDay:
                        shootDaySelector
                    }

                    Divider()

                    // Additional options
                    additionalOptions
                }
                .padding()
            }

            Divider()

            // Footer with Export button
            HStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Export PDF") {
                    exportSides()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canGenerate)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private var statusText: String {
        switch filterType {
        case .scenes:
            return "\(selectedSceneNumbers.count) scene(s) selected"
        case .character:
            if let char = selectedCharacter {
                return "Scenes with \(char)"
            }
            return "No character selected"
        case .shootDay:
            if selectedShootDayID != nil {
                return "Shoot day selected"
            }
            return "No shoot day selected"
        }
    }

    // MARK: - Filter Type Picker

    private var filterTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter By")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("", selection: $filterType) {
                ForEach(ScriptSidesFilterType.allCases) { type in
                    HStack {
                        Image(systemName: type.icon)
                        Text(type.rawValue)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: filterType) { _ in
                updatePreview()
            }

            Text(filterType.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Scene Selector

    private var sceneSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Scenes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Select All") {
                    selectedSceneNumbers = Set(scenes.map { $0.number })
                    updatePreview()
                }
                .buttonStyle(.link)

                Button("Clear") {
                    selectedSceneNumbers.removeAll()
                    updatePreview()
                }
                .buttonStyle(.link)
            }

            // Search field
            TextField("Search scenes...", text: $sceneSearchText)
                .textFieldStyle(.roundedBorder)

            // Scene list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredScenes, id: \.number) { scene in
                        sceneRow(scene)
                    }
                }
            }
            .frame(maxHeight: 250)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
        }
    }

    private func sceneRow(_ scene: (number: String, heading: String)) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { selectedSceneNumbers.contains(scene.number) },
                set: { isSelected in
                    if isSelected {
                        selectedSceneNumbers.insert(scene.number)
                    } else {
                        selectedSceneNumbers.remove(scene.number)
                    }
                    updatePreview()
                }
            ))
            .toggleStyle(.checkbox)

            Text(scene.number)
                .font(.system(.body, design: .monospaced))
                .frame(width: 40, alignment: .leading)

            Text(scene.heading)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedSceneNumbers.contains(scene.number) {
                selectedSceneNumbers.remove(scene.number)
            } else {
                selectedSceneNumbers.insert(scene.number)
            }
            updatePreview()
        }
    }

    // MARK: - Character Selector

    private var characterSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Character")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if characters.isEmpty {
                Text("No characters found in screenplay")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Picker("", selection: $selectedCharacter) {
                    Text("Select a character...").tag(nil as String?)
                    ForEach(characters, id: \.self) { character in
                        Text(character).tag(character as String?)
                    }
                }
                .onChange(of: selectedCharacter) { _ in
                    updatePreview()
                }
            }

            if let character = selectedCharacter {
                let sceneCount = countScenesWithCharacter(character)
                Text("\(sceneCount) scene(s) contain \(character)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func countScenesWithCharacter(_ character: String) -> Int {
        var sceneSet = Set<String>()
        var currentSceneNumber: String?

        for element in document.elements {
            if element.type == .sceneHeading {
                currentSceneNumber = element.sceneNumber
            } else if element.type == .character {
                let charName = element.text.uppercased()
                    .replacingOccurrences(of: "(V.O.)", with: "")
                    .replacingOccurrences(of: "(O.S.)", with: "")
                    .replacingOccurrences(of: "(CONT'D)", with: "")
                    .trimmingCharacters(in: .whitespaces)

                if charName == character, let num = currentSceneNumber {
                    sceneSet.insert(num)
                }
            }
        }

        return sceneSet.count
    }

    // MARK: - Shoot Day Selector

    private var shootDaySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Shoot Day")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Fetch shoot days
            let shootDays = fetchShootDays()

            if shootDays.isEmpty {
                Text("No shoot days found. Schedule scenes in the Scheduler to use this filter.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Picker("", selection: $selectedShootDayID) {
                    Text("Select a shoot day...").tag(nil as UUID?)
                    ForEach(shootDays, id: \.id) { day in
                        Text("Day \(day.dayNumber) - \(formatDate(day.date))")
                            .tag(day.id as UUID?)
                    }
                }
                .onChange(of: selectedShootDayID) { _ in
                    updatePreview()
                }
            }

            if let dayID = selectedShootDayID {
                let sceneNumbers = ScriptSidesGenerator.scenesForShootDay(shootDayID: dayID, context: moc)
                Text("\(sceneNumbers.count) scene(s) scheduled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private struct ShootDayInfo: Identifiable {
        let id: UUID
        let dayNumber: Int
        let date: Date
    }

    private func fetchShootDays() -> [ShootDayInfo] {
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ShootDayEntity")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            let results = try moc.fetch(fetchRequest)
            return results.compactMap { day -> ShootDayInfo? in
                guard let id = day.value(forKey: "id") as? UUID,
                      let date = day.value(forKey: "date") as? Date,
                      let dayNumber = day.value(forKey: "dayNumber") as? Int32 else {
                    return nil
                }
                return ShootDayInfo(id: id, dayNumber: Int(dayNumber), date: date)
            }
        } catch {
            return []
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Additional Options

    private var additionalOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle("Include scene numbers in margins", isOn: $includeSceneNumbers)
                .onChange(of: includeSceneNumbers) { _ in updatePreview() }

            Toggle("Include page numbers", isOn: $includePageNumbers)
                .onChange(of: includePageNumbers) { _ in updatePreview() }

            Toggle("Show revision marks", isOn: $showRevisionMarks)
                .onChange(of: showRevisionMarks) { _ in updatePreview() }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Header Text (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g., DAY 3 SIDES", text: $headerText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: headerText) { _ in updatePreview() }
            }
        }
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // PDF Preview
            if let pdf = previewPDF {
                PDFKitView(document: pdf)
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select scenes to preview")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
    }

    // MARK: - Actions

    private func updatePreview() {
        guard canGenerate else {
            previewPDF = nil
            return
        }

        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            let options = buildOptions()
            if let data = ScriptSidesGenerator.generateSides(
                document: document,
                options: options,
                context: moc
            ) {
                let pdf = PDFDocument(data: data)
                DispatchQueue.main.async {
                    self.previewPDF = pdf
                    self.isGenerating = false
                }
            } else {
                DispatchQueue.main.async {
                    self.previewPDF = nil
                    self.isGenerating = false
                }
            }
        }
    }

    private func buildOptions() -> ScriptSidesOptions {
        var options = ScriptSidesOptions()
        options.filterType = filterType
        options.sceneNumbers = Array(selectedSceneNumbers)
        options.characterName = selectedCharacter
        options.shootDayID = selectedShootDayID
        options.includeSceneNumbers = includeSceneNumbers
        options.includePageNumbers = includePageNumbers
        options.headerText = headerText
        options.showRevisionMarks = showRevisionMarks
        return options
    }

    private func exportSides() {
        let options = buildOptions()
        ScriptSidesGenerator.exportWithPanel(
            document: document,
            options: options,
            context: moc
        )
    }
}

// MARK: - PDF Kit View

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
    }
}

#endif
