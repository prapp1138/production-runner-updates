
import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#endif

// MARK: - iOS Breakdowns Design Constants
#if os(iOS)
private enum BreakdownsDesigniOS {
    static let spacing: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let cornerRadius: CGFloat = 14
}

// MARK: - Section Header
private struct SectionHeader: View {
    let title: String
    let icon: String?
    var action: (() -> Void)?

    init(title: String, icon: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if let action {
                Button(action: action) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - iOS Breakdowns with Expandable Scene Strips
/// iOS-specific Breakdowns view matching macOS design.
/// Each scene is a strip that expands to show Scene Info and Production Elements.
struct BreakdownsiOS: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var stripStore: StripStore

    @State private var showFDXImportSheet: Bool = false
    @State private var showFountainImportSheet: Bool = false
    @State private var showFadeInImportSheet: Bool = false
    @State private var expandedScenes: Set<NSManagedObjectID> = []
    @State private var selectedSceneID: NSManagedObjectID?
    @State private var searchText: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var pendingDeleteID: NSManagedObjectID? = nil

    init() {
        let ctx = PersistenceController.shared.container.viewContext

        let project: ProjectEntity = {
            let req = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
            req.fetchLimit = 1
            if let fetched = try? ctx.fetch(req), let existing = fetched.first {
                return existing
            }
            return ProjectEntity(context: ctx)
        }()

        _stripStore = StateObject(wrappedValue: StripStore(context: ctx, project: project))
    }

    private var filteredScenes: [SceneEntity] {
        if searchText.isEmpty {
            return stripStore.scenes
        }
        return stripStore.scenes.filter { scene in
            let numberMatch = (scene.number ?? "").lowercased().contains(searchText.lowercased())
            let slugMatch = (scene.sceneSlug ?? "").lowercased().contains(searchText.lowercased())
            let locationMatch = (scene.scriptLocation ?? "").lowercased().contains(searchText.lowercased())
            let scriptMatch = (scene.scriptText ?? "").lowercased().contains(searchText.lowercased())
            return numberMatch || slugMatch || locationMatch || scriptMatch
        }
    }

    private var selectedScene: SceneEntity? {
        guard let id = selectedSceneID else { return nil }
        return stripStore.scenes.first { $0.objectID == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider()

            if stripStore.scenes.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredScenes, id: \.objectID) { scene in
                            SceneStripiOS(
                                scene: scene,
                                isExpanded: expandedScenes.contains(scene.objectID),
                                isSelected: selectedSceneID == scene.objectID,
                                onToggle: { toggleExpanded(scene.objectID) },
                                onSelect: { selectedSceneID = scene.objectID }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showFDXImportSheet) {
            FDX_Import()
                .environment(\.managedObjectContext, context)
        }
        .sheet(isPresented: $showFadeInImportSheet) {
            FadeIn_Import()
                .environment(\.managedObjectContext, context)
        }
        .alert("Delete Scene", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID {
                    deleteScene(id: id)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteID = nil
            }
        } message: {
            Text("This scene will be deleted.")
        }
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            // Top row with title and main menu
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Breakdowns")
                        .font(.title2.bold())
                    Text("\(filteredScenes.count) scenes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Menu {
                        Button(action: { showFDXImportSheet = true }) {
                            Label("Final Draft", systemImage: "doc.text")
                        }
                        Button(action: { showFadeInImportSheet = true }) {
                            Label("Fade In", systemImage: "doc.text")
                        }
                    } label: {
                        Label("Import Script", systemImage: "square.and.arrow.down")
                    }
                    Button(action: addNewScene) {
                        Label("New Scene", systemImage: "plus")
                    }
                    Button(action: duplicateScene) {
                        Label("Duplicate Scene", systemImage: "doc.on.doc")
                    }
                    .disabled(selectedScene == nil)
                    Button(action: confirmDeleteScene) {
                        Label("Delete Scene", systemImage: "trash")
                    }
                    .disabled(selectedScene == nil)
                    Divider()
                    Menu {
                        Button(action: exportSceneBreakdown) {
                            Label("Scene", systemImage: "doc.text")
                        }
                        .disabled(selectedScene == nil)
                        Button(action: exportScriptBreakdown) {
                            Label("Script", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(action: printSceneBreakdown) {
                            Label("Print", systemImage: "printer")
                        }
                        .disabled(selectedScene == nil)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(action: expandAll) {
                        Label("Expand All", systemImage: "rectangle.expand.vertical")
                    }
                    Button(action: collapseAll) {
                        Label("Collapse All", systemImage: "rectangle.compress.vertical")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No Scenes")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Import a script or add a new scene to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Menu {
                Button(action: { showFDXImportSheet = true }) {
                    Label("Final Draft", systemImage: "doc.text")
                }
                Button(action: { showFadeInImportSheet = true }) {
                    Label("Fade In", systemImage: "doc.text")
                }
            } label: {
                Label("Import Script", systemImage: "square.and.arrow.down")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }

    private func addNewScene() {
        let newScene = SceneEntity(context: context)
        newScene.number = "\(stripStore.scenes.count + 1)"
        newScene.locationType = "INT."
        newScene.timeOfDay = "DAY"
        try? context.save()
    }

    private func toggleExpanded(_ id: NSManagedObjectID) {
        withAnimation(.easeInOut(duration: 0.5)) {
            if expandedScenes.contains(id) {
                expandedScenes.remove(id)
            } else {
                expandedScenes.insert(id)
            }
        }
    }

    private func expandAll() {
        withAnimation(.easeInOut(duration: 0.5)) {
            expandedScenes = Set(stripStore.scenes.map { $0.objectID })
        }
    }

    private func collapseAll() {
        withAnimation(.easeInOut(duration: 0.5)) {
            expandedScenes.removeAll()
        }
    }

    private func duplicateScene() {
        guard let scene = selectedScene else { return }
        let newScene = SceneEntity(context: context)
        newScene.number = scene.number.map { "\(Int($0) ?? 0 + 1)" }
        newScene.locationType = scene.locationType
        newScene.timeOfDay = scene.timeOfDay
        newScene.sceneSlug = scene.sceneSlug
        newScene.scriptLocation = scene.scriptLocation
        newScene.scriptText = scene.scriptText
        newScene.scriptFDX = scene.scriptFDX
        newScene.pageEighths = scene.pageEighths
        newScene.descriptionText = scene.descriptionText
        newScene.castIDs = scene.castIDs
        try? context.save()
    }

    private func confirmDeleteScene() {
        guard let scene = selectedScene else { return }
        pendingDeleteID = scene.objectID
        showDeleteConfirm = true
    }

    private func deleteScene(id: NSManagedObjectID) {
        guard let scene = try? context.existingObject(with: id) as? SceneEntity else { return }
        context.delete(scene)
        try? context.save()
        if selectedSceneID == id {
            selectedSceneID = nil
        }
        pendingDeleteID = nil
    }

    private func exportSceneBreakdown() {
        guard let scene = selectedScene,
              let pdfDocument = BreakdownScenePDF.generatePDF(for: scene, context: context),
              let data = pdfDocument.dataRepresentation() else {
            print("Failed to generate scene breakdown PDF")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func exportScriptBreakdown() {
        let scenes = stripStore.scenes
        guard !scenes.isEmpty,
              let pdfDocument = BreakdownScenePDF.generateMultiScenePDF(for: scenes, context: context),
              let data = pdfDocument.dataRepresentation() else {
            print("Failed to generate script breakdown PDF")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func printSceneBreakdown() {
        guard let scene = selectedScene,
              let pdfDocument = BreakdownScenePDF.generatePDF(for: scene, context: context),
              let data = pdfDocument.dataRepresentation() else {
            print("Failed to generate scene breakdown PDF for printing")
            return
        }

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Scene \(scene.number ?? "Unknown") Breakdown"
        printController.printInfo = printInfo
        printController.printingItem = data

        printController.present(animated: true) { _, completed, error in
            if let error = error {
                print("Print error: \(error.localizedDescription)")
            } else if completed {
                print("Print completed successfully")
            }
        }
    }
}

// MARK: - Scene Strip iOS (Matches macOS modernSceneRow)
private struct SceneStripiOS: View {
    @ObservedObject var scene: SceneEntity
    @Environment(\.colorScheme) private var colorScheme
    let isExpanded: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    private var heading: String {
        let coreHeading: String = {
            if scene.entity.attributesByName.keys.contains("heading"),
               let h = scene.value(forKey: "heading") as? String,
               !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return h.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let loc = scene.scriptLocation?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
                return loc
            }
            return ""
        }()

        let locType = (scene.locationType ?? "").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let tod     = (scene.timeOfDay ?? "").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        // Only add the period if it's not already there
        if !locType.isEmpty {
            parts.append(locType.hasSuffix(".") ? locType : locType + ".")
        }
        if !coreHeading.isEmpty {
            // Remove leading period if present to avoid double periods like "INT. . SCENE"
            var cleanedHeading = coreHeading.uppercased()
            if cleanedHeading.hasPrefix(".") {
                cleanedHeading = String(cleanedHeading.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            parts.append(cleanedHeading)
        }

        let left = parts.isEmpty ? nil : parts.joined(separator: " ")
        if let left, !tod.isEmpty { return left + " — " + tod }
        if let left { return left }

        return coreHeading.isEmpty ? "UNTITLED SCENE" : coreHeading.uppercased()
    }

    private func formatPageLength(_ eighths: Int) -> String {
        if eighths == 0 { return "0" }
        let whole = eighths / 8
        let remainder = eighths % 8
        if whole == 0 { return "\(remainder)/8" }
        else if remainder == 0 { return "\(whole)" }
        else { return "\(whole) \(remainder)/8" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scene Strip Header
            HStack(spacing: 14) {
                // Expand/Collapse Button
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
                .buttonStyle(.plain)

                // Scene Number Badge
                Text(scene.number?.isEmpty == false ? scene.number! : "—")
                    .font(.system(size: 15, weight: .bold))
                    .frame(minWidth: 44)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: BreakdownsDesigniOS.cornerRadius, style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BreakdownsDesigniOS.cornerRadius, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(isSelected ? .white : .primary)

                // Scene Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)

                    HStack(spacing: 12) {
                        if let castIDs = scene.castIDs, !castIDs.isEmpty {
                            Label(castIDs, systemImage: "person.2.fill")
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }

                        Label(formatPageLength(Int(scene.pageEighths)) + " pgs", systemImage: "doc.text.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: BreakdownsDesigniOS.cornerRadius, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color(UIColor.systemGray6).opacity(colorScheme == .dark ? 1.0 : 0.5))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: BreakdownsDesigniOS.cornerRadius, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: BreakdownsDesigniOS.cornerRadius))
            .onTapGesture {
                onSelect()
            }

            // Expanded Content - Breakdown Elements
            if isExpanded {
                SceneBreakdownContent(scene: scene)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .clipped()
        .animation(.easeInOut(duration: 0.5), value: isExpanded)
        .shadow(
            color: Color.black.opacity(isSelected ? 0.15 : 0.05),
            radius: isSelected ? 8 : 4,
            y: isSelected ? 4 : 2
        )
    }
}

// MARK: - Scene Breakdown Content (Matches macOS sceneBreakdownContent)
private struct SceneBreakdownContent: View {
    @ObservedObject var scene: SceneEntity
    @Environment(\.managedObjectContext) private var context

    // Editable state
    @State private var sceneNumber: String = ""
    @State private var slugLine: String = ""
    @State private var descriptionText: String = ""
    @State private var scriptDay: String = ""
    @State private var locationType: String = "INT."
    @State private var timeOfDay: String = "DAY"
    @State private var pageLengthEighths: Int = 0
    @State private var notes: String = ""

    // Cast members
    @State private var castMembers: [BreakdownCastMember] = []
    @State private var newCastID: String = ""
    @State private var newCastName: String = ""

    // Script Preview zoom
    @State private var scriptZoomLevel: CGFloat = 1.0
    private let minScriptZoom: CGFloat = 1.0
    private let maxScriptZoom: CGFloat = 2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scene Information Section
            sceneInfoSection

            Divider()

            // Script Preview Section
            scriptPreviewSection

            Divider()

            // Production Elements Section
            productionElementsSection

            Divider()

            // Notes Section
            notesSection
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
        .onAppear { loadSceneData() }
        .onChange(of: scene.objectID) { _ in loadSceneData() }
    }

    // MARK: - Scene Info Section
    private var sceneInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Scene Information", icon: "info.circle.fill")

            sceneFieldsContent
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var sceneFieldsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sceneFieldsRow
            Divider()
            sceneDescriptionField
        }
    }

    private var sceneFieldsRow: some View {
        HStack(spacing: 8) {
            Group {
                // Scene Number
                TextField("1", text: $sceneNumber)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .onChange(of: sceneNumber) { newValue in
                        print("🟡 [SceneNumberDebug] BreakdownsiOS: User changed scene number from '\(scene.number ?? "(nil)")' to '\(newValue)' for scene id=\(scene.id?.uuidString ?? "nil")")
                        scene.number = newValue
                        saveContext()
                    }

                // INT/EXT Dropdown
                Menu {
                    Button("INT.") { locationType = "INT."; scene.locationType = "INT."; saveContext() }
                    Button("EXT.") { locationType = "EXT."; scene.locationType = "EXT."; saveContext() }
                    Button("INT./EXT.") { locationType = "INT./EXT."; scene.locationType = "INT./EXT."; saveContext() }
                } label: {
                    Text(locationType)
                        .frame(width: 70)
                }
                .buttonStyle(.bordered)

                // Heading TextField
                TextField("KITCHEN", text: $slugLine)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: slugLine) { newValue in
                        let uppercased = newValue.uppercased()
                        scene.sceneSlug = uppercased
                        saveContext()
                        syncLocationToApp(uppercased)
                    }
            }

            Group {
                // Time Dropdown
                Menu {
                    Button("DAY") { timeOfDay = "DAY"; scene.timeOfDay = "DAY"; saveContext() }
                    Button("NIGHT") { timeOfDay = "NIGHT"; scene.timeOfDay = "NIGHT"; saveContext() }
                    Button("DAWN") { timeOfDay = "DAWN"; scene.timeOfDay = "DAWN"; saveContext() }
                    Button("DUSK") { timeOfDay = "DUSK"; scene.timeOfDay = "DUSK"; saveContext() }
                    Button("CONTINUOUS") { timeOfDay = "CONTINUOUS"; scene.timeOfDay = "CONTINUOUS"; saveContext() }
                } label: {
                    Text(timeOfDay)
                        .frame(width: 90)
                }
                .buttonStyle(.bordered)

                // Page Length
                pageLengthControls

                // Script Day Separator
                Text("·")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))

                // Script Day
                TextField("Day 1", text: $scriptDay)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onChange(of: scriptDay) { newValue in
                        scene.scriptDay = newValue
                        saveContext()
                    }
            }
        }
    }

    private var sceneDescriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(minHeight: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )

                TextEditor(text: $descriptionText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 50)
                    .padding(8)
                    .onChange(of: descriptionText) { newValue in
                        scene.descriptionText = newValue
                        saveContext()
                    }
            }
        }
    }

    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $descriptionText)
                .font(.system(size: 12))
                .frame(minHeight: 60, maxHeight: 100)
                .padding(8)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: descriptionText) { newValue in
                    scene.descriptionText = newValue
                    saveContext()
                }
        }
    }

    // MARK: - Page Length Controls
    private var pageLengthControls: some View {
        HStack(spacing: 6) {
            Button(action: {
                if pageLengthEighths > 0 {
                    pageLengthEighths -= 1
                    scene.pageEighths = Int16(pageLengthEighths)
                    saveContext()
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(pageLengthEighths == 0 ? .tertiary : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(pageLengthEighths == 0)

            Text(formatPageLength(pageLengthEighths))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 35, alignment: .center)

            Button(action: {
                pageLengthEighths += 1
                scene.pageEighths = Int16(pageLengthEighths)
                saveContext()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Script Preview Section
    @ViewBuilder
    private var scriptPreviewSection: some View {
        let rawFDX = scene.scriptFDX?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainText = scene.scriptText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sceneIDString = scene.objectID.uriRepresentation().absoluteString

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Script Preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                // Zoom controls
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scriptZoomLevel = max(minScriptZoom, scriptZoomLevel - 0.25)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(scriptZoomLevel > minScriptZoom ? .secondary : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .disabled(scriptZoomLevel <= minScriptZoom)

                    Text("\(Int(scriptZoomLevel * 100))%")
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 40)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scriptZoomLevel = min(maxScriptZoom, scriptZoomLevel + 0.25)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(scriptZoomLevel < maxScriptZoom ? .secondary : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .disabled(scriptZoomLevel >= maxScriptZoom)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }

            // Highlight Toolbar
            HighlightToolbariOS(sceneID: sceneIDString)

            if let fdx = rawFDX, !fdx.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    EnhancedFDXScriptView(
                        fdxXML: fdx,
                        pageEighths: Int(scene.pageEighths),
                        showRevisionMarks: true,
                        showSceneNumbers: false,
                        includeHeader: false,
                        showRawXML: false,
                        startingPageNumber: 1,
                        sceneID: sceneIDString
                    )
                    .drawingGroup()
                    .scaleEffect(scriptZoomLevel, anchor: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(minWidth: 500, minHeight: 200)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let text = plainText, !text.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.custom("Courier", size: 11))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(scriptZoomLevel, anchor: .top)
                }
                .frame(minHeight: 100, maxHeight: 200)
                .background(Color.white)
                .cornerRadius(8)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("No script content")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            }

            // Tagged Elements Summary
            HighlightedElementsSummaryiOS(sceneID: sceneIDString)
        }
    }

    // MARK: - Production Elements Section
    private var productionElementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Production Elements")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            // Cast Section
            VStack(alignment: .leading, spacing: 6) {
                Label("Cast", systemImage: "person.2.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.blue)

                if castMembers.isEmpty {
                    Text("No cast members added")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    FlowLayoutiOS(spacing: 6) {
                        ForEach(castMembers, id: \.id) { member in
                            HStack(spacing: 4) {
                                Text(member.castID)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(3)
                                Text(member.name)
                                    .font(.system(size: 10))
                                Button(action: { removeCastMember(member) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(6)
                        }
                    }
                }

                // Add cast member
                HStack(spacing: 6) {
                    TextField("ID", text: $newCastID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .frame(width: 45)

                    TextField("Name...", text: $newCastName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    Button(action: addCastMember) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(newCastID.isEmpty || newCastName.isEmpty)
                }
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Production Notes", systemImage: "note.text")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .font(.system(size: 11))
                .frame(minHeight: 50, maxHeight: 80)
                .padding(8)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: notes) { newValue in
                    // Save notes to scene entity
                    saveContext()
                }
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Helper Functions
    private func loadSceneData() {
        sceneNumber = scene.number ?? ""
        slugLine = scene.sceneSlug ?? ""
        descriptionText = scene.descriptionText ?? ""
        scriptDay = scene.scriptDay ?? ""
        locationType = scene.locationType ?? "INT."
        timeOfDay = scene.timeOfDay ?? "DAY"
        pageLengthEighths = Int(scene.pageEighths)

        // Load cast members from JSON
        if let json = scene.castMembersJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([BreakdownCastMember].self, from: data) {
            castMembers = decoded
        } else {
            castMembers = []
        }
    }

    private func saveContext() {
        try? context.save()
    }

    private func formatPageLength(_ eighths: Int) -> String {
        if eighths == 0 { return "0" }
        let whole = eighths / 8
        let remainder = eighths % 8
        if whole == 0 { return "\(remainder)/8" }
        else if remainder == 0 { return "\(whole)" }
        else { return "\(whole) \(remainder)/8" }
    }

    private func addCastMember() {
        guard !newCastID.isEmpty, !newCastName.isEmpty else { return }
        let member = BreakdownCastMember(name: newCastName, castID: newCastID)
        castMembers.append(member)
        saveCastMembers()
        newCastID = ""
        newCastName = ""
    }

    private func removeCastMember(_ member: BreakdownCastMember) {
        castMembers.removeAll { $0.id == member.id }
        saveCastMembers()
    }

    private func saveCastMembers() {
        if let data = try? JSONEncoder().encode(castMembers),
           let json = String(data: data, encoding: .utf8) {
            scene.castMembersJSON = json
            // Also update castIDs string
            scene.castIDs = castMembers.map { $0.castID }.joined(separator: ", ")
            saveContext()
        }
    }

    private func syncLocationToApp(_ locationName: String) {
        guard !locationName.isEmpty else { return }

        let locationManager = LocationDataManager.shared

        // Check if location already exists
        if locationManager.getLocation(byName: locationName) == nil {
            // Create new location
            let newLocation = LocationItem(
                name: locationName,
                address: "",
                locationInFilm: locationName,
                permitStatus: "Needs Scout"
            )
            locationManager.addLocation(newLocation)
            print("✅ Added new location to Locations app: \(locationName)")
        }
    }
}

// MARK: - Flow Layout for iOS
private struct FlowLayoutiOS: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(in: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(in maxWidth: CGFloat, subviews: Subviews) -> (positions: [CGPoint], width: CGFloat, height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, maxX, y + rowHeight)
    }
}

// MARK: - iOS Highlight Toolbar
/// iOS version of the highlight toolbar for tagging production elements
private struct HighlightToolbariOS: View {
    @ObservedObject var manager = HighlightManager.shared
    let sceneID: String

    var body: some View {
        HStack(spacing: 10) {
            // Element Type Picker
            Menu {
                ForEach(ProductionElementType.allCases) { type in
                    Button(action: { manager.selectedElementType = type }) {
                        Label(type.rawValue, systemImage: type.icon)
                    }
                }

                if manager.selectedElementType != nil {
                    Divider()
                    Button("Stop Highlighting", role: .destructive) {
                        manager.selectedElementType = nil
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let selected = manager.selectedElementType {
                        Image(systemName: selected.icon)
                            .foregroundColor(selected.color)
                        Text(selected.rawValue)
                            .foregroundColor(selected.color)
                    } else {
                        Image(systemName: "highlighter")
                        Text("Tag Element")
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(manager.selectedElementType != nil
                              ? manager.selectedElementType!.color.opacity(0.15)
                              : Color(UIColor.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(manager.selectedElementType?.color.opacity(0.4) ?? Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Instructions
            if manager.selectedElementType != nil {
                Text("Select text to tag")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            manager.currentSceneID = sceneID
        }
    }
}

// MARK: - iOS Highlighted Elements Summary
/// Shows tagged elements for a scene, grouped by type
private struct HighlightedElementsSummaryiOS: View {
    @ObservedObject var manager = HighlightManager.shared
    let sceneID: String

    private var sceneHighlights: [ScriptHighlight] {
        manager.highlightsForScene(sceneID)
    }

    private var groupedHighlights: [ProductionElementType: [ScriptHighlight]] {
        Dictionary(grouping: sceneHighlights) { $0.elementType }
    }

    var body: some View {
        if !sceneHighlights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tagged Elements")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(ProductionElementType.allCases) { type in
                    if let highlights = groupedHighlights[type], !highlights.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(type.rawValue, systemImage: type.icon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(type.color)

                            FlowLayoutiOS(spacing: 6) {
                                ForEach(highlights) { highlight in
                                    TagBadgeiOS(text: highlight.highlightedText, color: type.color) {
                                        manager.removeHighlight(highlight)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.tertiarySystemBackground)))
        }
    }
}

// MARK: - iOS Tag Badge
/// A removable tag badge for highlighted elements
private struct TagBadgeiOS: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .foregroundColor(color)
    }
}
#endif
