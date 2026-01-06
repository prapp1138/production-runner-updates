import SwiftUI
import CoreData
import UniformTypeIdentifiers
import MapKit
import FirebaseFirestore
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

// Note: Models, components, and sheets are now in separate files:
// - BreakdownModels.swift (BreakdownCastMember, enums, constants, AppleAutocomplete)
// - BreakdownComponents.swift (CleanCard, SimpleListItem, SectionHeader, PremiumButton, etc.)
// - BreakdownSheets.swift (AddCustomCategorySheet, LocationPickerSheet, CastManagementPopup, etc.)
// - BreakdownFDXParser.swift (FDXScene, FDXImporter)

// MARK: - Legacy aliases for backward compatibility
private typealias SectionHeader = BreakdownSectionHeader


// MARK: - Main View
@MainActor
struct Breakdowns: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var stripStore: StripStore
    @FetchRequest private var locationsFetch: FetchedResults<NSManagedObject>
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    @State private var sceneNumber: String = ""
    @State private var scriptDay: String = ""
    @State private var linkedLocationID: String = ""
    @State private var slugLine: String = ""
    @State private var locationType: LocationType = .int
    @State private var timeOfDay: TimeOfDay = .day
    @State private var locationName: String = ""
    @State private var pageLengthEighths: Int = 0
    
    // Elements
    @State private var cast: String = ""
    @State private var castMembers: [BreakdownCastMember] = []
    @State private var extras: String = ""
    @State private var stunts: String = ""
    @State private var props: String = ""
    @State private var wardrobe: String = ""
    @State private var vehicles: String = ""
    @State private var makeup: String = ""
    @State private var spfx: String = ""
    @State private var art: String = ""
    @State private var soundfx: String = ""
    @State private var hairMakeupFX: String = ""
    @State private var setDressing: String = ""
    @State private var animals: String = ""
    @State private var sfx: String = ""
    @State private var vfx: String = ""
    @State private var specialEquipment: String = ""
    @State private var notes: String = ""
    @State private var descriptionText: String = ""
    @State private var customCategories: [(name: String, items: [String])] = []
    @State private var customCategoryInputs: [String: String] = [:]
    @State private var newCastToken: String = ""
    @State private var newCastID: String = ""
    @State private var showingCastIDEditor: Bool = false
    @State private var showCastManagementPopup: Bool = false
    @State private var editingBreakdownCastMember: BreakdownCastMember? = nil
    @State private var newExtrasToken: String = ""
    @State private var newStuntsToken: String = ""
    @State private var newPropsToken: String = ""
    @State private var newWardrobeToken: String = ""
    @State private var newVehiclesToken: String = ""
    @State private var newMakeupToken: String = ""
    @State private var newSPFXToken: String = ""
    @State private var newArtToken: String = ""
    @State private var newSoundFXToken: String = ""
    @State private var newHairMakeupFXToken: String = ""
    @State private var newSetDressingToken: String = ""
    @State private var newAnimalsToken: String = ""
    @State private var newSFXToken: String = ""
    @State private var newVFXToken: String = ""
    @State private var newSpecialEquipmentToken: String = ""

    // Focus tracking
    enum FocusField: Hashable {
        case sceneDescription
        case notes
        case slugLine
        case locationName
        case searchField
        case none
    }
    @FocusState private var focusedField: FocusField?

    // UI State
    @State private var showFDXImportSheet: Bool = false
    @State private var showFountainImportSheet: Bool = false
    @State private var showFadeInImportSheet: Bool = false
    @State private var showPDFImportSheet: Bool = false
    @State private var showAddCustomCategorySheet: Bool = false
    @State private var showScreenplayDraftPicker: Bool = false
    @State private var isLoadingFromScreenplay: Bool = false
    @State private var newCustomCategoryName: String = ""
    @State private var currentTab: BreakdownTab = .elements
    @State private var showInspector: Bool = false
    @State private var showOverviewPopup: Bool = false
    @State private var didSetDefaultLayout: Bool = false
    @State private var sidebarWidth: CGFloat = 420
    @State private var showRawXML: Bool = false
    @State private var isDraggingSidebar: Bool = false
    @State private var showExportScenePDF: Bool = false
    @State private var showExportScriptPDF: Bool = false
    private let minSidebarWidth: CGFloat = 500
    private let maxSidebarWidth: CGFloat = 720

    // Breakdown Versions
    @State private var breakdownVersions: [BreakdownVersion] = []
    @State private var selectedVersion: BreakdownVersion? = nil
    @State private var showingNewVersionDialog: Bool = false
    @State private var showingRenameVersionDialog: Bool = false
    @State private var showingDeleteVersionAlert: Bool = false
    @State private var newVersionName: String = ""
    @State private var renameVersionName: String = ""
    @State private var versionToRename: BreakdownVersion? = nil
    @State private var versionToDelete: BreakdownVersion? = nil

    // Script Revision Sync
    @ObservedObject private var scriptSyncService = ScriptRevisionSyncService.shared
    @State private var showMergeResultAlert = false
    @State private var lastMergeResult: MergeResult? = nil

    // iPad Sync
    @State private var syncingToiPad = false
    @State private var lastSyncDate: Date?
    @State private var showSyncAlert = false
    @State private var syncAlertMessage = ""
    @State private var isLoadingScriptRevision = false

    // Highlight System (uses singleton)
    @ObservedObject private var highlightManager = HighlightManager.shared
    
    // Selection
    @State private var selectedScene: SceneEntity? = nil
    @State private var selectedSceneID: NSManagedObjectID? = nil
    @State private var selectedSceneIDs: Set<NSManagedObjectID> = []
    @State private var expandedSceneIDs: Set<NSManagedObjectID> = []
    @State private var selectionAnchorID: NSManagedObjectID? = nil

    // Clipboard for copy/paste operations
    @State private var sceneClipboard: [NSManagedObjectID] = []

    // Delete confirmation
    @State private var pendingDeleteIDs: [NSManagedObjectID] = []
    @State private var showDeleteConfirm: Bool = false
    
    // Undo/Redo
    @Environment(\.undoManager) private var undoManager
    @State private var sidebarRefreshID = UUID()
    @State private var sceneHeadingCache: [NSManagedObjectID: String] = [:]
    @State private var isReordering: Bool = false
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif

    // Light mode background color for better readability
    private var sceneCardBackground: Color {
        colorScheme == .light ? Color.white : Color(BreakdownsPlatformColor.secondarySystemBackground)
    }

    private var sceneCardSecondaryBackground: Color {
        colorScheme == .light ? Color.white : Color(BreakdownsPlatformColor.tertiarySystemBackground)
    }
    #if os(macOS)
    @State private var keyMonitor: Any? = nil
    #endif
    
    // Location search
    @State private var isSearchingLocation: Bool = false
    @State private var locationSearchProvider: LocationSearchProvider = .apple
    @State private var locationSearchText: String = ""
    @StateObject private var appleAutocomplete = AppleAutocomplete()
    
    // Search
    @State private var searchText: String = ""
    @State private var scriptSearchText: String = ""

    // Script Preview zoom
    @State private var scriptZoomLevel: CGFloat = 1.2
    private let minScriptZoom: CGFloat = 1.0
    private let maxScriptZoom: CGFloat = 2.0

    // Screenplay data manager for script preview
    @ObservedObject private var screenplayDataManager = ScreenplayDataManager.shared

    // Department navigation
    @State private var selectedDepartment: BreakdownDepartment = .script
    @State private var departmentSelectedSceneID: NSManagedObjectID? = nil
    
    init() {
        let ctx = PersistenceController.shared.container.viewContext

        let project: ProjectEntity = {
            let req = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
            req.fetchLimit = 1
            if let fetched = try? ctx.fetch(req), let existing = fetched.first {
                print("🔷 [Breakdowns] Found existing project: \(existing.objectID)")
                print("🔷 [Breakdowns] Project UUID: \(existing.id?.uuidString ?? "nil")")
                return existing
            }
            // Create and SAVE a new project so sync can find it
            let newProject = ProjectEntity(context: ctx)
            newProject.id = UUID()
            newProject.name = "Default Project"
            newProject.createdAt = Date()
            do {
                try ctx.save()
                print("🔷 [Breakdowns] Created and saved new project: \(newProject.objectID)")
                print("🔷 [Breakdowns] New project UUID: \(newProject.id?.uuidString ?? "nil")")
            } catch {
                print("🔷 [Breakdowns] ERROR saving new project: \(error)")
            }
            return newProject
        }()

        print("🔷 [Breakdowns] Initializing StripStore with project: \(project.objectID)")
        print("🔷 [Breakdowns] StripStore project UUID: \(project.id?.uuidString ?? "nil")")
        _stripStore = StateObject(wrappedValue: StripStore(context: ctx, project: project))

        // Note: locationsFetch is kept for potential future use but set to fetch nothing
        // to avoid performance issues. Locations are fetched on-demand via getLinkedLocation().
        if let entity = NSEntityDescription.entity(forEntityName: "LocationEntity", in: ctx) {
            let locationsRequest = NSFetchRequest<NSManagedObject>()
            locationsRequest.entity = entity
            locationsRequest.sortDescriptors = []
            locationsRequest.predicate = NSPredicate(value: false) // Don't fetch - unused
            _locationsFetch = FetchRequest(fetchRequest: locationsRequest, animation: nil)
        } else if let fallback = NSEntityDescription.entity(forEntityName: "SceneEntity", in: ctx) {
            _locationsFetch = FetchRequest(
                entity: fallback,
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
        } else {
            let emptyRequest = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
            emptyRequest.predicate = NSPredicate(value: false)
            _locationsFetch = FetchRequest(fetchRequest: emptyRequest, animation: nil)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Department Toolbar (Top Tab Bar)
            departmentToolbar

            Divider()

            // Content based on selected department
            switch selectedDepartment {
            case .script:
                scriptBreakdownContent
            case .art:
                ArtBreakdownView(scenes: stripStore.scenes, selectedSceneID: $departmentSelectedSceneID)
            case .camera:
                CameraBreakdownView(scenes: stripStore.scenes, selectedSceneID: $departmentSelectedSceneID)
            case .sound:
                SoundBreakdownView(scenes: stripStore.scenes, selectedSceneID: $departmentSelectedSceneID)
            case .lighting:
                LightingBreakdownView(scenes: stripStore.scenes, selectedSceneID: $departmentSelectedSceneID)
            }
        }
        .sheet(isPresented: $showFDXImportSheet) {
            FDX_Import(
                breakdownVersionId: nil,  // Will generate a new version ID
                onImportComplete: { versionId, sceneCount in
                    // Create a new breakdown version for this import
                    let versionName = "FDX Import \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
                    let newVersion = BreakdownVersion(
                        id: versionId,
                        name: versionName,
                        sceneCount: sceneCount
                    )
                    breakdownVersions.append(newVersion)
                    selectBreakdownVersion(newVersion)
                }
            )
            .environment(\.managedObjectContext, context)
        }
        .sheet(isPresented: $showFadeInImportSheet) {
            FadeIn_Import()
                .environment(\.managedObjectContext, context)
        }
        .sheet(isPresented: $showPDFImportSheet) {
            PDF_Import()
                .environment(\.managedObjectContext, context)
        }
        .sheet(isPresented: $showAddCustomCategorySheet) {
            AddCustomCategorySheet(
                categoryName: $newCustomCategoryName,
                onAdd: {
                    addCustomCategory(name: newCustomCategoryName)
                    showAddCustomCategorySheet = false
                    newCustomCategoryName = ""
                },
                onCancel: {
                    showAddCustomCategorySheet = false
                    newCustomCategoryName = ""
                }
            )
        }
        .sheet(isPresented: $showCastManagementPopup) {
            CastManagementPopup(
                castMembers: $castMembers,
                onSave: {
                    saveBreakdownCastMembers()
                    showCastManagementPopup = false
                },
                onCancel: {
                    loadBreakdownCastMembers() // Reload to discard changes
                    showCastManagementPopup = false
                }
            )
        }
        .sheet(isPresented: $showScreenplayDraftPicker) {
            ScreenplayDraftPickerSheet(
                isLoading: isLoadingFromScreenplay,
                onSelect: { draft in
                    loadScreenplayDraft(draft)
                },
                onCancel: {
                    showScreenplayDraftPicker = false
                }
            )
        }
        .sheet(isPresented: $isSearchingLocation) {
            LocationPickerSheet(
                locations: LocationDataManager.shared.locations,
                onSelect: { location in
                    linkLocation(location)
                    isSearchingLocation = false
                },
                onCancel: {
                    isSearchingLocation = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
            #if os(macOS)
            // Check if any text-based view has focus (TextField, TextEditor, NSTextView)
            // If so, let the system handle CMD+A for text selection
            if let firstResponder = NSApp.keyWindow?.firstResponder {
                // NSTextView handles script content, TextEditor fields, etc.
                if firstResponder is NSTextView {
                    return // Let system handle text selection
                }
                // NSTextField handles search bar, slug line, etc.
                if firstResponder is NSTextField {
                    return // Let system handle text selection
                }
            }
            // Also check SwiftUI focus state for tracked fields
            if focusedField != nil {
                return // Let system handle text selection
            }
            // No text input focused - select all scenes
            selectAllScenes()
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
            performDeleteCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
            performCutCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
            performCopyCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
            performPasteCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prUndo)) { _ in
            undoManager?.undo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prRedo)) { _ in
            undoManager?.redo()
        }
        .onAppear {
            context.undoManager = undoManager
            if !didSetDefaultLayout {
                showInspector = false
                didSetDefaultLayout = true
            }

            // Configure ScreenplayDataManager so Script Preview can load screenplay content
            ScreenplayDataManager.shared.configure(with: context)

            // Load breakdown versions
            loadBreakdownVersions()

            // Set up highlight callback to add elements to Core Data
            HighlightManager.shared.onElementHighlighted = { [self] elementType, text, sceneID in
                addHighlightedElementToBreakdown(elementType: elementType, text: text)
            }

            // Only reindex scenes after explicit import completion, not on every scene change
            NotificationCenter.default.addObserver(
                forName: .breakdownsImportCompleted,
                object: nil,
                queue: .main
            ) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    reindexAllScenes()
                }
            }

            // Listen for screenplay sync completion to reload scenes
            NotificationCenter.default.addObserver(
                forName: .screenplayBreakdownSyncCompleted,
                object: nil,
                queue: .main
            ) { _ in
                print("📋 [Breakdowns] Received screenplayBreakdownSyncCompleted - reloading StripStore")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    stripStore.reload()
                }
            }
        }
        .onChange(of: selectedSceneID) { newID in
            guard let id = newID else {
                selectedScene = nil
                return
            }
            if let s = stripStore.scenes.first(where: { $0.objectID == id }) {
                selectedScene = s
                if selectedSceneIDs.isEmpty {
                    selectedSceneIDs = [s.objectID]
                    selectionAnchorID = s.objectID
                }
                loadSceneData(s)
            }
        }
        .alert("Are you sure?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                performDelete(ids: pendingDeleteIDs)
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteIDs.removeAll()
            }
        } message: {
            Text(pendingDeleteIDs.count <= 1 ? "This scene will be deleted." : "These \(pendingDeleteIDs.count) scenes will be deleted.")
        }
        // New Version Dialog
        .alert("New Breakdown Version", isPresented: $showingNewVersionDialog) {
            TextField("Version name", text: $newVersionName)
            Button("Create") {
                if !newVersionName.isEmpty {
                    createNewBreakdownVersion(name: newVersionName)
                    newVersionName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newVersionName = ""
            }
        } message: {
            Text("Enter a name for the new breakdown version.")
        }
        // Rename Version Dialog
        .alert("Rename Version", isPresented: $showingRenameVersionDialog) {
            TextField("Version name", text: $renameVersionName)
            Button("Rename") {
                if let version = versionToRename, !renameVersionName.isEmpty {
                    renameBreakdownVersion(version, to: renameVersionName)
                    renameVersionName = ""
                    versionToRename = nil
                }
            }
            Button("Cancel", role: .cancel) {
                renameVersionName = ""
                versionToRename = nil
            }
        } message: {
            Text("Enter a new name for this breakdown version.")
        }
        // Delete Version Confirmation
        .alert("Delete Version?", isPresented: $showingDeleteVersionAlert) {
            Button("Delete", role: .destructive) {
                if let version = versionToDelete {
                    deleteBreakdownVersion(version)
                    versionToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                versionToDelete = nil
            }
        } message: {
            Text("This will delete the breakdown version \"\(versionToDelete?.name ?? "")\". This action cannot be undone.")
        }
        // Script Revision Merge Result Alert
        .alert("Script Revision Loaded", isPresented: $showMergeResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = lastMergeResult {
                Text(result.summary)
            } else {
                Text("Script revision loaded successfully.")
            }
        }
        // iPad Sync Alert
        .alert("iPad Sync", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncAlertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .scriptRevisionSent)) { _ in
            // Refresh to show new revision available indicator
            // The @ObservedObject scriptSyncService will update automatically
        }
        .onReceive(NotificationCenter.default.publisher(for: .breakdownsSceneSynced)) { notification in
            // Reload scene data if Art breakdown or other department modified the current scene
            if let changedID = notification.object as? NSManagedObjectID,
               let current = selectedScene,
               current.objectID == changedID {
                loadSceneData(current)
            }
        }
    }

    // MARK: - Breakdown Version Dropdown
    private var breakdownVersionDropdown: some View {
        Menu {
            // Script Revision Section
            Section("Script Revision") {
                // Current loaded script
                if let scriptName = selectedVersion?.scriptDisplayName {
                    HStack {
                        Circle()
                            .fill(scriptRevisionColor(for: selectedVersion?.scriptColorName))
                            .frame(width: 8, height: 8)
                        Text(scriptName)
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("No script loaded")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Available revisions to load
                if scriptSyncService.sentRevisions.isEmpty {
                    Text("No revisions available")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(scriptSyncService.sentRevisions) { revision in
                        Button(action: {
                            loadScriptRevision(revision)
                        }) {
                            HStack {
                                Circle()
                                    .fill(revision.color)
                                    .frame(width: 8, height: 8)
                                Text(revision.displayName)
                                Spacer()
                                if !revision.loadedInBreakdowns {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            // Breakdown Versions Section
            Section("Breakdown Versions") {
                ForEach(breakdownVersions) { version in
                    Button(action: {
                        selectBreakdownVersion(version)
                    }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.caption)
                            Text(version.name)
                            Spacer()
                            if version.id == selectedVersion?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            Divider()

            // Actions Section
            Section {
                Button(action: {
                    showingNewVersionDialog = true
                }) {
                    Label("New Breakdown Version", systemImage: "plus.circle")
                }

                Button(action: {
                    loadScriptFromScreenplay()
                }) {
                    Label("Load from Screenplay", systemImage: "doc.text.fill")
                }

                if let selectedVersion = selectedVersion {
                    Button(action: {
                        duplicateBreakdownVersion(selectedVersion)
                    }) {
                        Label("Duplicate Current", systemImage: "doc.on.doc")
                    }

                    Button(action: {
                        versionToRename = selectedVersion
                        renameVersionName = selectedVersion.name
                        showingRenameVersionDialog = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }

                    if breakdownVersions.count > 1 {
                        Divider()

                        Button(role: .destructive, action: {
                            versionToDelete = selectedVersion
                            showingDeleteVersionAlert = true
                        }) {
                            Label("Delete Version", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                // Version icon with background
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Breakdown")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if scriptSyncService.hasUpdatesAvailable(for: .breakdowns) {
                            Circle()
                                .fill(.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(selectedVersion?.name ?? "No Version")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(BreakdownsPlatformColor.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .frame(maxWidth: 220)
        .menuStyle(.borderlessButton)
    }

    /// Get color for script revision color name
    private func scriptRevisionColor(for colorName: String?) -> Color {
        guard let name = colorName?.lowercased() else { return .gray }
        switch name {
        case "white": return Color(red: 1.0, green: 1.0, blue: 1.0)
        case "blue": return Color(red: 0.68, green: 0.85, blue: 0.90)
        case "pink": return Color(red: 1.0, green: 0.75, blue: 0.80)
        case "yellow": return Color(red: 1.0, green: 1.0, blue: 0.60)
        case "green": return Color(red: 0.60, green: 0.98, blue: 0.60)
        case "goldenrod": return Color(red: 0.93, green: 0.79, blue: 0.45)
        case "buff": return Color(red: 0.94, green: 0.86, blue: 0.70)
        case "salmon": return Color(red: 1.0, green: 0.63, blue: 0.48)
        case "cherry": return Color(red: 0.87, green: 0.44, blue: 0.63)
        case "tan": return Color(red: 0.82, green: 0.71, blue: 0.55)
        case "gray", "grey": return Color(red: 0.83, green: 0.83, blue: 0.83)
        default: return .gray
        }
    }

    /// Load a script revision into breakdowns
    private func loadScriptRevision(_ revision: SentRevision) {
        guard !isLoadingScriptRevision else { return }
        isLoadingScriptRevision = true

        Task {
            do {
                let result = try await scriptSyncService.loadRevision(
                    revision,
                    into: .breakdowns,
                    context: context
                )

                // Update the selected version with script reference
                if var version = selectedVersion,
                   let index = breakdownVersions.firstIndex(where: { $0.id == version.id }) {
                    version.scriptRevisionId = revision.revisionId
                    version.scriptColorName = revision.colorName
                    version.scriptLoadedDate = Date()
                    breakdownVersions[index] = version
                    selectedVersion = version
                    saveBreakdownVersions()
                }

                lastMergeResult = result
                showMergeResultAlert = true
            } catch {
                print("[Breakdowns] Failed to load script revision: \(error)")
            }

            isLoadingScriptRevision = false
        }
    }

    // MARK: - Toolbar Header
    private var toolbarHeader: some View {
        HStack(spacing: 0) {
            // MARK: Left Section - Version & Scenes
            HStack(spacing: 12) {
                // Version dropdown
                breakdownVersionDropdown

                Divider()
                    .frame(height: 28)

                // Title and count
                Text("Scenes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(filteredScenes.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(4)

                Spacer()

                // Scene action buttons
                HStack(spacing: 6) {
                    // Import Dropdown
                    Menu {
                        Button {
                            showFDXImportSheet = true
                        } label: {
                            Label("Final Draft (.fdx)", systemImage: "doc.text")
                        }

                        Button {
                            showFadeInImportSheet = true
                        } label: {
                            Label("Fade In", systemImage: "doc.text")
                        }

                        Divider()

                        Button {
                            showPDFImportSheet = true
                        } label: {
                            Label("PDF Script", systemImage: "doc.richtext")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                            Text("Import")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .customTooltip("Import Script")

                    // Load from Screenplay Dropdown
                    Menu {
                        Button {
                            loadScriptFromScreenplay()
                        } label: {
                            Label("Load Script", systemImage: "doc.text.fill")
                        }

                        Button {
                            loadRevisionsFromScreenplay()
                        } label: {
                            Label("Load Revisions", systemImage: "arrow.triangle.2.circlepath.doc.on.clipboard")
                        }

                        Divider()

                        Button {
                            recalculateAllPageLengths()
                        } label: {
                            Label("Recalculate Page Lengths", systemImage: "doc.badge.clock")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .font(.system(size: 14, weight: .medium))
                            Text("Load")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .customTooltip("Load from Screenplay App")

                    // Export Dropdown
                    Menu {
                        Button {
                            exportSceneBreakdown()
                        } label: {
                            Label("Scene", systemImage: "doc.text")
                        }
                        .disabled(selectedScene == nil)

                        Button {
                            exportScriptBreakdown()
                        } label: {
                            Label("Script", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button {
                            printSceneBreakdown()
                        } label: {
                            Label("Print", systemImage: "printer")
                        }
                        .disabled(selectedScene == nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                            Text("Export")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .customTooltip("Export Breakdowns")

                    PremiumButton(icon: "plus", style: .green) {
                        performNewScene()
                    }
                    .fixedSize()
                    .customTooltip("New Scene")

                    PremiumButton(icon: "doc.on.doc", style: .blue) {
                        performDuplicate()
                    }
                    .fixedSize()
                    .disabled(selectedScene == nil)
                    .customTooltip("Duplicate Scene")

                    PremiumButton(icon: "trash", style: .destructive) {
                        #if os(macOS)
                        let targets = !selectedSceneIDs.isEmpty ? Array(selectedSceneIDs) : (selectedSceneID.map { [$0] } ?? [])
                        if !targets.isEmpty { confirmDelete(ids: targets) }
                        #else
                        if let target = selectedScene {
                            confirmDelete(ids: [target.objectID])
                        }
                        #endif
                    }
                    .fixedSize()
                    .disabled(selectedScene == nil)
                    .customTooltip("Delete Scene")
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)

            // Section Divider
            Divider()
                .frame(height: 28)

            // MARK: Right Section - Script Preview
            HStack(spacing: 12) {
                // Title
                Text("Script Preview")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                // Highlight Element Button (only when scene selected)
                if let scene = selectedScene {
                    HighlightToolbar(sceneID: scene.objectID.uriRepresentation().absoluteString)
                }

                Spacer()

                // iPad Sync Button
                Button {
                    syncBreakdownsToiPad()
                } label: {
                    Image(systemName: syncingToiPad ? "arrow.triangle.2.circlepath" : "ipad.and.arrow.forward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .fixedSize()
                .customTooltip("Sync script to iPad")
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
    }

    private func toolbarButton(icon: String, title: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(disabled ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.12))
            )
            .foregroundStyle(disabled ? Color.secondary : Color.accentColor)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }

    // MARK: - Sidebar View (Modern Design)
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Scene Actions Toolbar
            HStack(spacing: 8) {
                Text("Scenes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(filteredScenes.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(4)

                Spacer()

                // Action buttons
                HStack(spacing: 4) {
                    Button {
                        performNewScene()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.green.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Add Scene")

                    Button {
                        performDuplicate()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedScene == nil ? Color.secondary.opacity(0.5) : Color.blue)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(selectedScene == nil ? Color.secondary.opacity(0.05) : Color.blue.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedScene == nil)
                    .customTooltip("Copy Scene")

                    Button {
                        #if os(macOS)
                        let targets = !selectedSceneIDs.isEmpty ? Array(selectedSceneIDs) : (selectedSceneID.map { [$0] } ?? [])
                        if !targets.isEmpty { confirmDelete(ids: targets) }
                        #else
                        if let target = selectedScene {
                            confirmDelete(ids: [target.objectID])
                        }
                        #endif
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedScene == nil ? Color.secondary.opacity(0.5) : Color.red)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(selectedScene == nil ? Color.secondary.opacity(0.05) : Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedScene == nil)
                    .customTooltip("Delete Scene")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.primary.opacity(0.015))

            Divider()

            // Selection count indicator (shown when multiple selected)
            #if os(macOS)
            if selectedSceneIDs.count > 1 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                    Text("\(selectedSceneIDs.count) scenes selected")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Deselect All") {
                        selectedSceneIDs.removeAll()
                        if let first = filteredScenes.first {
                            selectedSceneID = first.objectID
                            selectedScene = first
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            #endif

            // Scenes List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredScenes, id: \.objectID) { scene in
                        modernSceneRow(scene)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            #if os(macOS)
            .onAppear {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
                    // If any text field is focused, don't intercept
                    if focusedField != nil {
                        return e
                    }
                    // CMD+A to select all scenes
                    if e.modifierFlags.contains(.command),
                       (e.charactersIgnoringModifiers?.lowercased() == "a") {
                        let all = filteredScenes.map { $0.objectID }
                        selectedSceneIDs = Set(all)
                        if let first = filteredScenes.first {
                            selectionAnchorID = first.objectID
                            selectedSceneID = first.objectID
                            selectedScene = first
                        }
                        return nil // swallow the event
                    }
                    return e
                }
            }
            .onDisappear {
                if let m = keyMonitor {
                    NSEvent.removeMonitor(m)
                    keyMonitor = nil
                }
            }
            #endif
        }
    }
    
    // MARK: - Modern Scene Row
    @ViewBuilder
    private func modernSceneRow(_ s: SceneEntity) -> some View {
        let isSelected = selectedSceneIDs.contains(s.objectID) || (selectedSceneIDs.isEmpty && selectedSceneID == s.objectID)
        let number = s.number ?? ""
        let heading = getHeading(s)
        // Use stored pageEighths, or calculate from FDX content if not set
        let eighths: Int = {
            let stored = Int(s.pageEighths)
            if stored > 0 { return stored }
            // Try to calculate from FDX content
            let fdxAttributeNames = ["scriptFDX", "fdxRaw", "fdxXML", "sourceFDX", "sceneXML", "fdxContent"]
            for key in fdxAttributeNames where s.entity.attributesByName.keys.contains(key) {
                if let value = s.value(forKey: key) as? String,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return calculatePageEighths(from: value)
                }
            }
            return 1 // Default minimum
        }()
        
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                // Multi-selection indicator (checkmark)
                #if os(macOS)
                if selectedSceneIDs.count > 1 {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .animation(.spring(response: 0.3), value: isSelected)
                } else {
                    // Expand/Collapse Button
                    Button(action: { toggleExpanded(s.objectID) }) {
                        Image(systemName: isExpanded(s.objectID) ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isSelected ? Color.white : Color.secondary)
                            .animation(.spring(response: 0.3), value: isExpanded(s.objectID))
                    }
                    .buttonStyle(.plain)
                }
                #else
                // Expand/Collapse Button
                Button(action: { toggleExpanded(s.objectID) }) {
                    Image(systemName: isExpanded(s.objectID) ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .animation(.spring(response: 0.3), value: isExpanded(s.objectID))
                }
                .buttonStyle(.plain)
                #endif
                
                // Scene Number Badge
                Text(number.isEmpty ? "—" : number)
                    .font(.system(size: 15, weight: .bold))
                    .frame(minWidth: 44)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: BreakdownsDesign.cornerRadius, style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BreakdownsDesign.cornerRadius, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                
                // Scene Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    
                    HStack(spacing: 12) {
                        if let castIDs = s.castIDs, !castIDs.isEmpty {
                            Label(castIDs, systemImage: "person.2.fill")
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        
                        Label(formatPageLength(eighths) + " pgs", systemImage: "doc.text.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                }
                
                Spacer(minLength: 0)

                // Location Badge (from Locations app sync)
                if let locationName = getSceneLocationName(s), !locationName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .imageScale(.small)
                        Text(locationName)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.15) : Color.blue.opacity(0.15))
                    )
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: BreakdownsDesign.cornerRadius, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(
                            (colorScheme == .dark
                             ? Color(BreakdownsPlatformColor.systemGray6)
                             : Color(BreakdownsPlatformColor.systemGray6).opacity(0.5))
                          )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: BreakdownsDesign.cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isSelected ? 0.15 : 0.05),
                radius: isSelected ? 8 : 4,
                y: isSelected ? 4 : 2
            )
            .contentShape(RoundedRectangle(cornerRadius: BreakdownsDesign.cornerRadius))
            .onTapGesture {
                handleSceneTap(s)
            }
            .contextMenu {
                Button(role: .destructive) {
                    confirmDelete(ids: [s.objectID])
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            // Expanded Content - Breakdown Elements
                        if isExpanded(s.objectID) {
                            sceneBreakdownContent(for: s)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                                .compositingGroup()
                                .transition(.opacity)
                        }
        }
        .clipped()
        .animation(.easeInOut(duration: 0.5), value: isExpanded(s.objectID))
    }

    // MARK: - Scene Breakdown Content (for expanded scene strips)
    @ViewBuilder
    private func sceneBreakdownContent(for scene: SceneEntity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Scene Information
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Scene Information", icon: "info.circle.fill")

                VStack(alignment: .leading, spacing: 16) {
                    // Row 1: Scene #, INT/EXT, Heading, Time, and Length (all on one line)
                    HStack(spacing: 8) {
                        // Scene Number
                        TextField("1", text: $sceneNumber)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .onChange(of: sceneNumber) { newValue in
                                guard let s = selectedScene else { return }
                                s.number = newValue
                                saveContext()
                                syncSceneToShotLister(s)
                                syncSceneToScheduler(s)
                                sidebarRefreshID = UUID()
                            }

                        // INT/EXT Dropdown
                        Picker("", selection: $locationType) {
                            ForEach(LocationType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 70)
                        .onChange(of: locationType) { newValue in
                            guard let s = selectedScene else { return }
                            s.locationType = newValue.id
                            saveContext()
                            syncSceneToShotLister(s)
                            syncSceneToScheduler(s)
                            sidebarRefreshID = UUID()
                        }

                        // Heading TextField
                        TextField("KITCHEN", text: $slugLine)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .slugLine)
                            .textCase(.uppercase)
                            .onChange(of: slugLine) { newValue in
                                guard let s = selectedScene else { return }
                                let uppercased = newValue.uppercased()
                                setHeading(s, value: uppercased)
                                saveContext()
                                slugLine = uppercased
                                syncSceneToShotLister(s)
                                syncSceneToScheduler(s)
                                sidebarRefreshID = UUID()
                            }

                        // Time Dropdown
                        Picker("", selection: $timeOfDay) {
                            ForEach(TimeOfDay.allCases) { time in
                                Text(time.rawValue).tag(time)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)
                        .onChange(of: timeOfDay) { newValue in
                            guard let s = selectedScene else { return }
                            s.timeOfDay = newValue.id
                            saveContext()
                            syncSceneToShotLister(s)
                            syncSceneToScheduler(s)
                            sidebarRefreshID = UUID()
                        }

                        // Page Length
                        HStack(spacing: 6) {
                            Button(action: {
                                if pageLengthEighths > 0 {
                                    pageLengthEighths -= 1
                                    guard let s = selectedScene else { return }
                                    s.pageEighths = Int16(pageLengthEighths)
                                    saveContext()
                                    syncSceneToShotLister(s)
                                    syncSceneToScheduler(s)
                                    sidebarRefreshID = UUID()
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(pageLengthEighths == 0 ? Color.secondary.opacity(0.5) : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(pageLengthEighths == 0)

                            Text(formatPageLength(pageLengthEighths))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 35, alignment: .center)

                            Button(action: {
                                pageLengthEighths += 1
                                guard let s = selectedScene else { return }
                                s.pageEighths = Int16(pageLengthEighths)
                                saveContext()
                                syncSceneToShotLister(s)
                                syncSceneToScheduler(s)
                                sidebarRefreshID = UUID()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        // Script Day Separator
                        Text("·")
                            .foregroundStyle(.secondary.opacity(0.7))
                            .font(.system(size: 13))

                        // Script Day
                        TextField("Day 1", text: $scriptDay)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: scriptDay) { newValue in
                                guard let s = selectedScene else { return }
                                s.scriptDay = newValue
                                saveContext()
                                syncSceneToShotLister(s)
                                syncSceneToScheduler(s)
                                sidebarRefreshID = UUID()
                            }
                    }

                    Divider()

                    // Row 2: Scene Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(BreakdownsPlatformColor.tertiarySystemBackground))
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
                                .focused($focusedField, equals: .sceneDescription)
                                .onChange(of: descriptionText) { newValue in
                                    guard let s = selectedScene else { return }
                                    setDescription(for: s, value: newValue)
                                    saveContext()
                                    syncSceneToShotLister(s)
                                    syncSceneToScheduler(s)
                                }
                        }
                    }
                }
            }
            .cleanCard()
            .padding(.horizontal, 12)


            // Production Elements
            Text("Production Elements")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            // Cast Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Cast", systemImage: "person.2.fill")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    if !castMembers.isEmpty {
                        Button(action: { showCastManagementPopup = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Manage Cast IDs")
                    }
                }

                if castMembers.isEmpty {
                    Text("No cast members added")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.vertical, 2)
                } else {
                    VStack(spacing: 3) {
                        ForEach(castMembers) { member in
                            HStack(spacing: 6) {
                                Text(member.castID)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(3)
                                Text(member.name)
                                    .font(.system(size: 10))
                                Spacer()
                                Button(action: { removeBreakdownCastMember(member) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(sceneCardSecondaryBackground)
                            .cornerRadius(4)
                        }
                    }
                }

                HStack(spacing: 4) {
                    TextField("ID", text: $newCastID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10))
                        .frame(width: 40)
                        .onSubmit { addBreakdownCastMember() }

                    TextField("Name...", text: $newCastToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10))
                        .onSubmit { addBreakdownCastMember() }

                    Button(action: { addBreakdownCastMember() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(newCastToken.isEmpty || newCastID.isEmpty)
                }
            }
            .padding(8)
            .background(sceneCardBackground)
            .cornerRadius(6)

            // Other Elements (compact) - Two column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], alignment: .leading, spacing: 8) {
                compactElementRow(title: "Stunts", icon: "figure.run", state: $stunts, newToken: $newStuntsToken, color: .orange, attributeKeys: ["stunts"])
                compactElementRow(title: "Props", icon: "cube.fill", state: $props, newToken: $newPropsToken, color: .purple, attributeKeys: ["props"])
                compactElementRow(title: "Wardrobe", icon: "tshirt.fill", state: $wardrobe, newToken: $newWardrobeToken, color: .pink, attributeKeys: ["wardrobe"])
                compactElementRow(title: "Makeup/Hair", icon: "sparkles", state: $hairMakeupFX, newToken: $newHairMakeupFXToken, color: .green, attributeKeys: ["hairMakeupFX", "makeup"])
                compactElementRow(title: "Set Dressing", icon: "sofa.fill", state: $setDressing, newToken: $newSetDressingToken, color: .brown, attributeKeys: ["setDressing"])
                compactElementRow(title: "Special Effects", icon: "flame.fill", state: $sfx, newToken: $newSFXToken, color: .red, attributeKeys: ["sfx", "spfx"])
                compactElementRow(title: "Visual Effects", icon: "wand.and.stars", state: $vfx, newToken: $newVFXToken, color: .blue, attributeKeys: ["vfx"])
                compactElementRow(title: "Animals", icon: "pawprint.fill", state: $animals, newToken: $newAnimalsToken, color: .yellow, attributeKeys: ["animals"])
                compactElementRow(title: "Vehicles", icon: "car.fill", state: $vehicles, newToken: $newVehiclesToken, color: .cyan, attributeKeys: ["vehicles"])
                compactElementRow(title: "Special Equipment", icon: "case.fill", state: $specialEquipment, newToken: $newSpecialEquipmentToken, color: .teal, attributeKeys: ["specialEquipment"])
                compactElementRow(title: "Sound", icon: "waveform", state: $soundfx, newToken: $newSoundFXToken, color: .indigo, attributeKeys: ["soundfx", "sound"])
            }

            // Custom Categories
            if !customCategories.isEmpty {
                ForEach(customCategories.indices, id: \.self) { index in
                    let category = customCategories[index]
                    compactCustomCategoryRow(category: category, index: index)
                }
            }

            // Add Custom Category Button
            Button(action: { showAddCustomCategorySheet = true }) {
                Label("Add Custom Category", systemImage: "plus.circle.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderedProminent)

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Label("Production Notes", systemImage: "note.text")
                    .font(.system(size: 11, weight: .medium))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(sceneCardSecondaryBackground)
                        .frame(minHeight: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )

                    TextEditor(text: $notes)
                        .font(.system(size: 10))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 60)
                        .padding(6)
                        .focused($focusedField, equals: .notes)
                        .onChange(of: notes) { newValue in
                            guard let s = selectedScene else { return }
                            persistElementCSV(to: s, keys: ["notes", "sceneNotes", "notesText"], value: newValue)
                            saveContext()
                            syncSceneToShotLister(s)
                            syncSceneToScheduler(s)
                        }
                }
            }
            .padding(8)
            .background(sceneCardBackground)
            .cornerRadius(6)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
    }

    // MARK: - Left Sidebar with Breakdown Dropdown
    private var leftSidebarWithBreakdown: some View {
        sidebarView
    }

    // MARK: - Right FDX Preview Pane
    private var rightFDXPreviewPane: some View {
        VStack(spacing: 0) {
            // Script Preview Toolbar (Highlight Element + Sync to iPad)
            HStack(spacing: 12) {
                // Highlight Element Button (only when scene selected)
                if let scene = selectedScene {
                    HighlightToolbar(sceneID: scene.objectID.uriRepresentation().absoluteString)
                } else {
                    Text("Select a scene to highlight elements")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // iPad Sync Button
                Button {
                    syncBreakdownsToiPad()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: syncingToiPad ? "arrow.triangle.2.circlepath" : "ipad.and.arrow.forward")
                            .font(.system(size: 12, weight: .medium))
                        Text(syncingToiPad ? "Syncing..." : "Sync to iPad")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.blue.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .customTooltip("Sync script to iPad")
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.primary.opacity(0.015))

            Divider()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .center, spacing: BreakdownsDesign.spacing) {

                        if selectedScene == nil {
                        // Empty state
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No scene selected")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            Text("Select a scene to view its script")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // Scene script content
                        VStack(alignment: .center, spacing: 16) {
                        // Try to find FDX content
                        let fdxAttributeNames = ["scriptFDX", "fdxRaw", "fdxXML", "sourceFDX", "sceneXML", "fdxContent"]
                        let rawFDX: String? = { () -> String? in
                            guard let scene = selectedScene else { return nil }
                            print("🔍 [ScriptPreview] Looking for FDX content in scene '\(scene.number ?? "?")'")
                            print("   Available attributes: \(scene.entity.attributesByName.keys.sorted().joined(separator: ", "))")
                            for key in fdxAttributeNames where scene.entity.attributesByName.keys.contains(key) {
                                let value = scene.value(forKey: key) as? String
                                if let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    print("✅ Found FDX content in attribute '\(key)' (length: \(value.count))")
                                    print("📄 First 200 chars: \(String(value.prefix(200)))")
                                    return value
                                } else {
                                    print("⚠️ Attribute '\(key)' exists but is empty or nil")
                                }
                            }
                            print("❌ No FDX content found - Script Preview will show placeholder")
                            return nil
                        }()

                        // Try to find plain text
                        let textAttributeNames = ["scriptText", "sceneText", "bodyText", "content", "plainText"]
                        let plain: String? = {
                            guard let scene = selectedScene else { return nil }
                            for key in textAttributeNames where scene.entity.attributesByName.keys.contains(key) {
                                if let value = scene.value(forKey: key) as? String,
                                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    return value
                                }
                            }
                            return nil
                        }()

                        // If no scriptFDX, try to generate from screenplay document
                        let generatedFDX: String? = {
                            if rawFDX != nil { return nil } // Use real content if available
                            guard let scene = selectedScene else { return nil }

                            // Try to get document - first from currentDocument, then load from drafts
                            // Use the observed screenplayDataManager to trigger re-render when drafts load
                            var document: ScreenplayDocument? = screenplayDataManager.currentDocument

                            // If no current document loaded, try to load the most recent draft
                            if document == nil && !screenplayDataManager.drafts.isEmpty {
                                if let firstDraft = screenplayDataManager.drafts.first {
                                    document = screenplayDataManager.loadDocument(id: firstDraft.id)
                                    print("[Breakdowns] Loaded screenplay document '\(document?.title ?? "unknown")' with \(document?.elements.count ?? 0) elements")
                                }
                            } else if document == nil && screenplayDataManager.isLoading {
                                print("[Breakdowns] Screenplay drafts still loading...")
                            }

                            if let doc = document {
                                let sceneNum = scene.number ?? "1"
                                print("[Breakdowns] Looking for scene \(sceneNum) in document with \(doc.scenes.count) scenes")
                                // Find matching scene in document by number
                                if let docScene = doc.scenes.first(where: { $0.number == sceneNum }) {
                                    print("[Breakdowns] Found matching scene at index \(docScene.index)")
                                    return generateFDXFromScreenplayScene(document: doc, sceneIndex: docScene.index, sceneNumber: sceneNum)
                                } else {
                                    print("[Breakdowns] No matching scene found. Available: \(doc.scenes.map { $0.number })")
                                }
                            } else if screenplayDataManager.drafts.isEmpty && !screenplayDataManager.isLoading {
                                print("[Breakdowns] No screenplay document available (no drafts)")
                            }

                            // Fallback: Try to use scriptText if available
                            if let scriptText = scene.value(forKey: "scriptText") as? String,
                               !scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let sceneNum = scene.number ?? "1"
                                let slug = (scene.value(forKey: "sceneSlug") as? String) ?? "INT. LOCATION - DAY"
                                print("[Breakdowns] Using scriptText fallback for scene \(sceneNum)")
                                return generateFDXFromPlainText(text: scriptText, heading: slug, sceneNumber: sceneNum)
                            }

                            return nil
                        }()

                        let effectiveFDX = rawFDX ?? generatedFDX

                        if let fdx = effectiveFDX, !fdx.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(spacing: 0) {
                                // Center the script page horizontally
                                scriptFDXPagesView(
                                    injectSceneNumber(into: fdx, scene: selectedScene),
                                    pageEighths: Int(selectedScene?.pageEighths ?? 0),
                                    startingPageNumber: getPageNumber(selectedScene)
                                )
                                .scaleEffect(scriptZoomLevel, anchor: .top)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 16)

                                // Highlighted Elements Summary
                                if let scene = selectedScene {
                                    HighlightedElementsSummary(sceneID: scene.objectID.uriRepresentation().absoluteString)
                                        .padding(.horizontal, BreakdownsDesign.spacing)
                                        .padding(.top, 16)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else if let script = plain, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(spacing: 0) {
                                // Center the script page horizontally
                                scriptPageView(script)
                                    .scaleEffect(scriptZoomLevel, anchor: .top)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 16)

                                // Highlighted Elements Summary
                                if let scene = selectedScene {
                                    HighlightedElementsSummary(sceneID: scene.objectID.uriRepresentation().absoluteString)
                                        .padding(.horizontal, BreakdownsDesign.spacing)
                                        .padding(.top, 16)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else if screenplayDataManager.isLoading {
                            // Loading screenplay data
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading screenplay...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                        } else {
                            // No script content available
                            VStack(alignment: .leading, spacing: 16) {
                                // Header
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.blue.opacity(0.7))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Script Preview Unavailable")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Re-import your screenplay to enable script preview")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }

                                Divider()

                                // Scene info fallback
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        Text(sceneNumber)
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.blue)
                                            .frame(width: 36, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 4) {
                                            if !slugLine.isEmpty {
                                                Text(slugLine.uppercased())
                                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            }

                                            if !descriptionText.isEmpty {
                                                Text(descriptionText)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(4)
                                            }
                                        }
                                    }
                                }

                                // Tip section
                                HStack(spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.system(size: 12))
                                    Text("Tip: Import your FDX or PDF screenplay file to see formatted script pages here")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .background(Color.yellow.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                            .padding(.horizontal, BreakdownsDesign.spacing)
                        }
                        } // Close VStack(spacing: 16)
                    } // Close else
                    } // Close VStack(spacing: BreakdownsDesign.spacing)
                    .frame(width: geometry.size.width)
                    .padding(.bottom, BreakdownsDesign.spacing)
                } // Close ScrollView
            } // Close GeometryReader
        } // Close VStack (toolbar + content)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Script Breakdown Content (Original Breakdowns view content)
    private var scriptBreakdownContent: some View {
        VStack(spacing: 0) {
            // Main Content - Using HStack with flexible frames for better performance
            HStack(spacing: 0) {
                // Left Sidebar with Scenes and Breakdown Dropdown
                leftSidebarWithBreakdown
                    .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
                    .background(Color(BreakdownsPlatformColor.systemBackground))

                Divider()

                // Right - FDX Preview
                rightFDXPreviewPane
                    .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
                    .background(Color(BreakdownsPlatformColor.systemBackground))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom Toolbar
            bottomToolbar
        }
    }

    // MARK: - Unified Toolbar (Combined Department Tabs + Scene Actions)
    private var unifiedToolbar: some View {
        HStack(spacing: 0) {
            // Left: Department Tabs
            HStack(spacing: 2) {
                ForEach(BreakdownDepartment.allCases) { department in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDepartment = department
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: department.icon)
                                .font(.system(size: 14, weight: selectedDepartment == department ? .semibold : .regular))
                            Text(department.rawValue)
                                .font(.system(size: 12, weight: selectedDepartment == department ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(
                            selectedDepartment == department
                                ? department.color
                                : (colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedDepartment == department ? department.color.opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(selectedDepartment == department ? department.color.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .customTooltip(department.description)
                }
            }
            .padding(.leading, 12)

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 12)

            // Center: Version dropdown (only for Script department)
            if selectedDepartment == .script {
                breakdownVersionDropdown
            }

            Spacer()

            // Right: Action Buttons (available for all departments)
            HStack(spacing: 6) {
                // Import Dropdown
                Menu {
                    Button {
                        showFDXImportSheet = true
                    } label: {
                        Label("Final Draft (.fdx)", systemImage: "doc.text")
                    }

                    Button {
                        showFadeInImportSheet = true
                    } label: {
                        Label("Fade In", systemImage: "doc.text")
                    }

                    Divider()

                    Button {
                        showPDFImportSheet = true
                    } label: {
                        Label("PDF Script", systemImage: "doc.richtext")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .medium))
                        Text("Import")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .customTooltip("Import Script")

                // Load from Screenplay
                Menu {
                    Button {
                        loadScriptFromScreenplay()
                    } label: {
                        Label("Load Script", systemImage: "doc.text.fill")
                    }

                    Button {
                        loadRevisionsFromScreenplay()
                    } label: {
                        Label("Load Revisions", systemImage: "arrow.triangle.2.circlepath.doc.on.clipboard")
                    }

                    Divider()

                    Button {
                        recalculateAllPageLengths()
                    } label: {
                        Label("Recalculate Page Lengths", systemImage: "doc.badge.clock")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 13, weight: .medium))
                        Text("Load")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .customTooltip("Load from Screenplay App")

                // Export Dropdown
                Menu {
                    Button {
                        exportSceneBreakdown()
                    } label: {
                        Label("Scene", systemImage: "doc.text")
                    }
                    .disabled(selectedScene == nil)

                    Button {
                        exportScriptBreakdown()
                    } label: {
                        Label("Script", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        printSceneBreakdown()
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .disabled(selectedScene == nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                        Text("Export")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.purple.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .customTooltip("Export Breakdowns")
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
        .frame(height: 48)
        .background(
            colorScheme == .dark
                ? Color(white: 0.08)
                : Color(white: 0.96)
        )
    }

    // MARK: - Legacy Department Toolbar (kept for reference)
    private var departmentToolbar: some View {
        unifiedToolbar
    }

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            // MARK: Left Section - Search Bar (for scene strip)
            HStack(spacing: 12) {
                // Search bar - searches scenes and script content
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 140)
                        .focused($focusedField, equals: .searchField)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Section Divider
            Divider()
                .frame(height: 28)

            // MARK: Right Section - Script Preview Zoom
            HStack(spacing: 12) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Center Editor
    @ViewBuilder
    private var centerEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BreakdownsDesign.sectionSpacing) {
                // Tab Selector (compact, top-aligned)
                HStack {
                    Spacer()
                    Picker("", selection: $currentTab) {
                        ForEach(BreakdownTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.horizontal, BreakdownsDesign.spacing)
                .padding(.top, 12)

                if selectedScene == nil {
                    emptyStateView
                } else {
                    if currentTab == .elements {
                        elementsTabContent
                    } else {
                        reportsTabContent
                    }
                }
            }
            .padding(.bottom, BreakdownsDesign.spacing)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Center Script Pane
    private var centerScriptPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BreakdownsDesign.spacing) {
                if selectedScene == nil {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No scene selected")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 60)
                } else {
                    // Scene Header Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scene \(sceneNumber)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)

                        HStack {
                            Text(slugLine.isEmpty ? "No slug line" : slugLine)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, BreakdownsDesign.spacing)
                    .padding(.top, BreakdownsDesign.spacing)

                    Divider()

                    // Scene Description/Script
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, BreakdownsDesign.spacing)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(BreakdownsPlatformColor.tertiarySystemBackground))
                                .frame(minHeight: 300)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )

                            TextEditor(text: $descriptionText)
                                .font(.system(size: 14))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 300)
                                .padding(8)
                                .focused($focusedField, equals: .sceneDescription)
                                .onChange(of: descriptionText) { newValue in
                                    guard let s = selectedScene else { return }
                                    setDescription(for: s, value: newValue)
                                    saveContext()
                                    syncSceneToShotLister(s)
                                    syncSceneToScheduler(s)
                                }
                        }
                        .padding(.horizontal, BreakdownsDesign.spacing)
                    }
                }
            }
            .padding(.bottom, BreakdownsDesign.spacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Right Breakdown Pane (Dropdown Style)
    private var rightBreakdownPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BreakdownsDesign.spacing) {
                // Header
                HStack {
                    Text("Breakdown Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, BreakdownsDesign.spacing)
                .padding(.top, BreakdownsDesign.spacing)

                if selectedScene == nil {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No scene selected")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: BreakdownsDesign.compactSpacing) {
                        // Scene Info Summary
                        overviewCard(
                            title: "Scene Info",
                            icon: "info.circle.fill",
                            items: [
                                ("Number", sceneNumber.isEmpty ? "—" : sceneNumber),
                                ("Location", locationName.isEmpty ? "—" : locationName),
                                ("Type", "\(locationType.rawValue) \(timeOfDay.rawValue)")
                            ]
                        )

                        // Cast
                        if !castMembers.isEmpty {
                            let castItems = castMembers.map { ($0.name, "") }
                            overviewCard(
                                title: "Cast",
                                icon: "person.2.fill",
                                items: castItems
                            )
                        }

                        // Stunts
                        let stuntsItems = splitTokens(stunts)
                        if !stuntsItems.isEmpty {
                            overviewCard(
                                title: "Stunts",
                                icon: "figure.run",
                                items: stuntsItems.map { ($0, "") }
                            )
                        }

                        // Extras
                        let extrasItems = splitTokens(extras)
                        if !extrasItems.isEmpty {
                            overviewCard(
                                title: "Extras",
                                icon: "person.3.fill",
                                items: extrasItems.map { ($0, "") }
                            )
                        }

                        // Props
                        let propsItems = splitTokens(props)
                        if !propsItems.isEmpty {
                            overviewCard(
                                title: "Props",
                                icon: "wrench.and.screwdriver.fill",
                                items: propsItems.map { ($0, "") }
                            )
                        }

                        // Wardrobe
                        let wardrobeItems = splitTokens(wardrobe)
                        if !wardrobeItems.isEmpty {
                            overviewCard(
                                title: "Wardrobe",
                                icon: "tshirt.fill",
                                items: wardrobeItems.map { ($0, "") }
                            )
                        }

                        // Vehicles
                        let vehiclesItems = splitTokens(vehicles)
                        if !vehiclesItems.isEmpty {
                            overviewCard(
                                title: "Vehicles",
                                icon: "car.fill",
                                items: vehiclesItems.map { ($0, "") }
                            )
                        }

                        // Makeup/Hair
                        let makeupItems = splitTokens(hairMakeupFX)
                        if !makeupItems.isEmpty {
                            overviewCard(
                                title: "Makeup/Hair",
                                icon: "sparkles",
                                items: makeupItems.map { ($0, "") }
                            )
                        }

                        // Set Dressing
                        let setDressingItems = splitTokens(setDressing)
                        if !setDressingItems.isEmpty {
                            overviewCard(
                                title: "Set Dressing",
                                icon: "sofa.fill",
                                items: setDressingItems.map { ($0, "") }
                            )
                        }

                        // Special Effects
                        let sfxItems = splitTokens(sfx)
                        if !sfxItems.isEmpty {
                            overviewCard(
                                title: "Special Effects",
                                icon: "flame.fill",
                                items: sfxItems.map { ($0, "") }
                            )
                        }

                        // Visual Effects
                        let vfxItems = splitTokens(vfx)
                        if !vfxItems.isEmpty {
                            overviewCard(
                                title: "Visual Effects",
                                icon: "wand.and.stars",
                                items: vfxItems.map { ($0, "") }
                            )
                        }

                        // Animals
                        let animalsItems = splitTokens(animals)
                        if !animalsItems.isEmpty {
                            overviewCard(
                                title: "Animals",
                                icon: "pawprint.fill",
                                items: animalsItems.map { ($0, "") }
                            )
                        }

                        // Special Equipment
                        let specialEquipmentItems = splitTokens(specialEquipment)
                        if !specialEquipmentItems.isEmpty {
                            overviewCard(
                                title: "Special Equipment",
                                icon: "case.fill",
                                items: specialEquipmentItems.map { ($0, "") }
                            )
                        }

                        // Custom Categories
                        ForEach(customCategories.indices, id: \.self) { index in
                            let category = customCategories[index]
                            if !category.items.isEmpty {
                                overviewCard(
                                    title: category.name,
                                    icon: "folder.fill",
                                    items: category.items.map { ($0, "") }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, BreakdownsDesign.compactSpacing)
                }
            }
            .padding(.bottom, BreakdownsDesign.spacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Script Elements Overview
    private var scriptElementsOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BreakdownsDesign.spacing) {
                // Header
                Text("Overview")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, BreakdownsDesign.spacing)
                    .padding(.top, BreakdownsDesign.spacing)

                if selectedScene == nil {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No scene selected")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: BreakdownsDesign.compactSpacing) {
                        // Scene Info Summary (always shown)
                        overviewCard(
                            title: "Scene Info",
                            icon: "info.circle.fill",
                            items: [
                                ("Number", sceneNumber.isEmpty ? "—" : sceneNumber),
                                ("Location", locationName.isEmpty ? "—" : locationName),
                                ("Type", "\(locationType.rawValue) \(timeOfDay.rawValue)")
                            ]
                        )

                        // 1. Cast (only show if has content)
                        if !castMembers.isEmpty {
                            let castItems = castMembers.map { ($0.name, "") }
                            overviewCard(
                                title: "Cast",
                                icon: "person.2.fill",
                                items: castItems
                            )
                        }

                        // 2. Stunts (only show if has content)
                        let stuntsItems = splitTokens(stunts)
                        if !stuntsItems.isEmpty {
                            overviewCard(
                                title: "Stunts",
                                icon: "figure.run",
                                items: stuntsItems.map { ($0, "") }
                            )
                        }

                        // 3. Extras (only show if has content)
                        let extrasItems = splitTokens(extras)
                        if !extrasItems.isEmpty {
                            overviewCard(
                                title: "Extras",
                                icon: "person.3.fill",
                                items: extrasItems.map { ($0, "") }
                            )
                        }

                        // 4. Props (only show if has content)
                        let propsItems = splitTokens(props)
                        if !propsItems.isEmpty {
                            overviewCard(
                                title: "Props",
                                icon: "cube.fill",
                                items: propsItems.map { ($0, "") }
                            )
                        }

                        // 5. Wardrobe (only show if has content)
                        let wardrobeItems = splitTokens(wardrobe)
                        if !wardrobeItems.isEmpty {
                            overviewCard(
                                title: "Wardrobe",
                                icon: "tshirt.fill",
                                items: wardrobeItems.map { ($0, "") }
                            )
                        }

                        // 6. Makeup/Hair (only show if has content)
                        let makeupItems = splitTokens(hairMakeupFX)
                        if !makeupItems.isEmpty {
                            overviewCard(
                                title: "Makeup/Hair",
                                icon: "sparkles",
                                items: makeupItems.map { ($0, "") }
                            )
                        }

                        // 7. Set Dressing (only show if has content)
                        let setDressingItems = splitTokens(setDressing)
                        if !setDressingItems.isEmpty {
                            overviewCard(
                                title: "Set Dressing",
                                icon: "sofa.fill",
                                items: setDressingItems.map { ($0, "") }
                            )
                        }

                        // 8. Special Effects (only show if has content)
                        let sfxItems = splitTokens(sfx)
                        if !sfxItems.isEmpty {
                            overviewCard(
                                title: "Special Effects",
                                icon: "flame.fill",
                                items: sfxItems.map { ($0, "") }
                            )
                        }

                        // 9. Visual Effects (only show if has content)
                        let vfxItems = splitTokens(vfx)
                        if !vfxItems.isEmpty {
                            overviewCard(
                                title: "Visual Effects",
                                icon: "wand.and.stars",
                                items: vfxItems.map { ($0, "") }
                            )
                        }

                        // 10. Animals (only show if has content)
                        let animalsItems = splitTokens(animals)
                        if !animalsItems.isEmpty {
                            overviewCard(
                                title: "Animals",
                                icon: "pawprint.fill",
                                items: animalsItems.map { ($0, "") }
                            )
                        }

                        // 11. Vehicles (only show if has content)
                        let vehiclesItems = splitTokens(vehicles)
                        if !vehiclesItems.isEmpty {
                            overviewCard(
                                title: "Vehicles",
                                icon: "car.fill",
                                items: vehiclesItems.map { ($0, "") }
                            )
                        }

                        // 12. Special Equipment (only show if has content)
                        let equipmentItems = splitTokens(specialEquipment)
                        if !equipmentItems.isEmpty {
                            overviewCard(
                                title: "Special Equipment",
                                icon: "wrench.and.screwdriver.fill",
                                items: equipmentItems.map { ($0, "") }
                            )
                        }

                        // 13. Sound (only show if has content)
                        let soundItems = splitTokens(soundfx)
                        if !soundItems.isEmpty {
                            overviewCard(
                                title: "Sound",
                                icon: "speaker.wave.3.fill",
                                items: soundItems.map { ($0, "") }
                            )
                        }
                    }
                    .padding(.horizontal, BreakdownsDesign.spacing)
                }
            }
            .padding(.bottom, BreakdownsDesign.spacing)
        }
    }

    private func overviewCard(title: String, icon: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    HStack(spacing: 4) {
                        if !item.1.isEmpty {
                            Text(item.0)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.7))
                            Text(item.1)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(item.0)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(BreakdownsPlatformColor.tertiarySystemBackground))
        )
    }

    private func splitTokens(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Overview Popup Pane
    private var overviewPopupPane: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Overview")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: { showOverviewPopup = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(BreakdownsPlatformColor.secondarySystemBackground))

            Divider()

            // Content
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 16) {
                    if selectedScene == nil {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("No scene selected")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Scene Info Summary
                        overviewCard(
                            title: "Scene Info",
                            icon: "info.circle.fill",
                            items: [
                                ("Number", sceneNumber.isEmpty ? "—" : sceneNumber),
                                ("Location", locationName.isEmpty ? "—" : locationName),
                                ("Type", "\(locationType.rawValue) \(timeOfDay.rawValue)")
                            ]
                        )
                        .frame(width: 200)

                        // Cast
                        if !castMembers.isEmpty {
                            let castItems = castMembers.map { ($0.name, "") }
                            overviewCard(
                                title: "Cast",
                                icon: "person.2.fill",
                                items: castItems
                            )
                            .frame(width: 200)
                        }

                        // Stunts
                        let stuntsItems = splitTokens(stunts)
                        if !stuntsItems.isEmpty {
                            overviewCard(
                                title: "Stunts",
                                icon: "figure.run",
                                items: stuntsItems.map { ($0, "") }
                            )
                            .frame(width: 200)
                        }

                        // Props
                        let propsItems = splitTokens(props)
                        if !propsItems.isEmpty {
                            overviewCard(
                                title: "Props",
                                icon: "wrench.and.screwdriver.fill",
                                items: propsItems.map { ($0, "") }
                            )
                            .frame(width: 200)
                        }

                        // Wardrobe
                        let wardrobeItems = splitTokens(wardrobe)
                        if !wardrobeItems.isEmpty {
                            overviewCard(
                                title: "Wardrobe",
                                icon: "tshirt.fill",
                                items: wardrobeItems.map { ($0, "") }
                            )
                            .frame(width: 200)
                        }

                        // Vehicles
                        let vehiclesItems = splitTokens(vehicles)
                        if !vehiclesItems.isEmpty {
                            overviewCard(
                                title: "Vehicles",
                                icon: "car.fill",
                                items: vehiclesItems.map { ($0, "") }
                            )
                            .frame(width: 200)
                        }

                        // Special Equipment
                        let equipmentItems = splitTokens(specialEquipment)
                        if !equipmentItems.isEmpty {
                            overviewCard(
                                title: "Special Equipment",
                                icon: "hammer.fill",
                                items: equipmentItems.map { ($0, "") }
                            )
                            .frame(width: 200)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: 250)
        }
        .background(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -8)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            
            Text("Select a scene to begin")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Choose a scene from the sidebar or create a new one")
                .font(.system(size: 14))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
    }
    
    // MARK: - Elements Tab Content
    private var elementsTabContent: some View {
        VStack(spacing: BreakdownsDesign.spacing) {
            sceneInfoCard
            productionElementsCard
            customCategoriesCard
            notesAndSyncCard
        }
    }

    // MARK: - Scene Info Card
    private var sceneInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Scene Information", icon: "info.circle.fill")

            VStack(alignment: .leading, spacing: 16) {
                sceneInfoRow1
                Divider()
                sceneDescriptionRow
            }
        }
        .cleanCard()
        .padding(.horizontal, BreakdownsDesign.spacing)
    }

    private var sceneInfoRow1: some View {
        HStack(spacing: 8) {
            // Scene Number Dropdown
            TextField("1", text: $sceneNumber)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .onChange(of: sceneNumber) { newValue in
                    guard let s = selectedScene else { return }
                    s.number = newValue
                    saveContext()
                    syncSceneToShotLister(s)
                    syncSceneToScheduler(s)
                    sidebarRefreshID = UUID()
                }

            // INT/EXT Dropdown
            Picker("", selection: $locationType) {
                ForEach(LocationType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
            .onChange(of: locationType) { newValue in
                guard let s = selectedScene else { return }
                s.locationType = newValue.id
                saveContext()
                syncSceneToShotLister(s)
                syncSceneToScheduler(s)
                sidebarRefreshID = UUID()
            }

            // Heading TextField
            TextField("KITCHEN", text: $slugLine)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .slugLine)
                .textCase(.uppercase)
                .onChange(of: slugLine) { newValue in
                    guard let s = selectedScene else { return }
                    let uppercased = newValue.uppercased()
                    setHeading(s, value: uppercased)
                    saveContext()
                    slugLine = uppercased
                    syncSceneToShotLister(s)
                    syncSceneToScheduler(s)
                    sidebarRefreshID = UUID()
                }

            // Time Dropdown
            Picker("", selection: $timeOfDay) {
                ForEach(TimeOfDay.allCases) { time in
                    Text(time.rawValue).tag(time)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 90)
            .onChange(of: timeOfDay) { newValue in
                guard let s = selectedScene else { return }
                s.timeOfDay = newValue.id
                saveContext()
                syncSceneToShotLister(s)
                syncSceneToScheduler(s)
                sidebarRefreshID = UUID()
            }

            pageLengthControls

            // Script Day
            Text("·")
                .foregroundStyle(.secondary.opacity(0.7))
                .font(.system(size: 13))

            TextField("Day 1", text: $scriptDay)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .foregroundStyle(.black)
                .onChange(of: scriptDay) { newValue in
                    guard let s = selectedScene else { return }
                    s.scriptDay = newValue
                    saveContext()
                    syncSceneToShotLister(s)
                    syncSceneToScheduler(s)
                    sidebarRefreshID = UUID()
                }
        }
    }

    private var pageLengthControls: some View {
        HStack(spacing: 6) {
            Button(action: {
                if pageLengthEighths > 0 {
                    pageLengthEighths -= 1
                    guard let s = selectedScene else { return }
                    s.pageEighths = Int16(pageLengthEighths)
                    saveContext()
                    syncSceneToShotLister(s)
                    syncSceneToScheduler(s)
                    sidebarRefreshID = UUID()
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(pageLengthEighths == 0 ? Color.secondary.opacity(0.5) : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(pageLengthEighths == 0)

            Text(formatPageLength(pageLengthEighths))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 35, alignment: .center)

            Button(action: {
                pageLengthEighths += 1
                guard let s = selectedScene else { return }
                s.pageEighths = Int16(pageLengthEighths)
                saveContext()
                syncSceneToShotLister(s)
                syncSceneToScheduler(s)
                sidebarRefreshID = UUID()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var sceneDescriptionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(BreakdownsPlatformColor.tertiarySystemBackground))
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
                    .focused($focusedField, equals: .sceneDescription)
                    .onChange(of: descriptionText) { newValue in
                        guard let s = selectedScene else { return }
                        setDescription(for: s, value: newValue)
                        saveContext()
                        syncSceneToShotLister(s)
                        syncSceneToScheduler(s)
                    }
            }
        }
    }

    // MARK: - Production Elements Card
    private var productionElementsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Production Elements", icon: "shippingbox.fill")

            // Cast Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Cast")
                    .font(.system(size: 15, weight: .semibold))

                if castMembers.isEmpty {
                    Text("No cast members added")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(castMembers) { member in
                            BreakdownCastMemberRow(
                                member: member,
                                onEdit: { editingBreakdownCastMember = member; showingCastIDEditor = true },
                                onRemove: { removeBreakdownCastMember(member) }
                            )
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Cast ID (e.g., 1, 2A)", text: $newCastID)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onSubmit { addBreakdownCastMember() }

                    TextField("Cast member name...", text: $newCastToken)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addBreakdownCastMember() }

                    Button("Add") { addBreakdownCastMember() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newCastToken.isEmpty || newCastID.isEmpty)
                }
            }
            .padding(BreakdownsDesign.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(BreakdownsPlatformColor.secondarySystemBackground))
            .cornerRadius(BreakdownsDesign.cornerRadius)

            Divider()

            // Elements Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                modernElementSection(title: "Stunts", state: $stunts, newToken: $newStuntsToken, color: .orange, attributeKeys: ["stunts"])
                modernElementSection(title: "Extras", state: $extras, newToken: $newExtrasToken, color: .mint, attributeKeys: ["extras"])
                modernElementSection(title: "Props", state: $props, newToken: $newPropsToken, color: .purple, attributeKeys: ["props"])
                modernElementSection(title: "Wardrobe", state: $wardrobe, newToken: $newWardrobeToken, color: .pink, attributeKeys: ["wardrobe"])
                modernElementSection(title: "Makeup/Hair", state: $hairMakeupFX, newToken: $newHairMakeupFXToken, color: .green, attributeKeys: ["hairMakeupFX", "makeup"])
                modernElementSection(title: "Set Dressing", state: $setDressing, newToken: $newSetDressingToken, color: .brown, attributeKeys: ["setDressing", "art"])
                modernElementSection(title: "Special Effects", state: $sfx, newToken: $newSFXToken, color: .red, attributeKeys: ["sfx", "spfx"])
                modernElementSection(title: "Visual Effects", state: $vfx, newToken: $newVFXToken, color: .blue, attributeKeys: ["vfx"])
                modernElementSection(title: "Animals", state: $animals, newToken: $newAnimalsToken, color: .yellow, attributeKeys: ["animals"])
                modernElementSection(title: "Vehicles", state: $vehicles, newToken: $newVehiclesToken, color: .cyan, attributeKeys: ["vehicles"])
                modernElementSection(title: "Special Equipment", state: $specialEquipment, newToken: $newSpecialEquipmentToken, color: .teal, attributeKeys: ["specialEquipment"])
                modernElementSection(title: "Sound", state: $soundfx, newToken: $newSoundFXToken, color: .indigo, attributeKeys: ["soundfx", "sound"])
            }
        }
        .cleanCard()
        .padding(.horizontal, BreakdownsDesign.spacing)
        .sheet(isPresented: $showingCastIDEditor) {
            if let member = editingBreakdownCastMember {
                CastIDEditorSheet(
                    member: member,
                    onSave: { updated in
                        updateBreakdownCastMember(updated)
                        showingCastIDEditor = false
                        editingBreakdownCastMember = nil
                    },
                    onCancel: {
                        showingCastIDEditor = false
                        editingBreakdownCastMember = nil
                    }
                )
            }
        }
    }

    // MARK: - Custom Categories Card
    @ViewBuilder
    private var customCategoriesCard: some View {
        if !customCategories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Custom Categories", icon: "folder.fill")
                    Spacer()
                    Button(action: { showAddCustomCategorySheet = true }) {
                        Label("Add Category", systemImage: "plus.circle.fill")
                            .font(.system(size: 11))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderedProminent)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(customCategories, id: \.name) { category in
                        customCategorySection(category: category)
                    }
                }
            }
            .cleanCard()
            .padding(.horizontal, BreakdownsDesign.spacing)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Custom Categories", icon: "folder.fill")

                Button(action: { showAddCustomCategorySheet = true }) {
                    Label("Add Custom Category", systemImage: "plus.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .cleanCard()
            .padding(.horizontal, BreakdownsDesign.spacing)
        }
    }

    // MARK: - Notes and Sync Card
    private var notesAndSyncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Production Notes", icon: "note.text")
            notesEditorSection
            Divider()
            locationSyncSection
            Divider()
            scheduleSyncSection
            Divider()
            budgetSyncSection
        }
        .cleanCard()
        .padding(.horizontal, BreakdownsDesign.spacing)
    }

    private var notesEditorSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(BreakdownsPlatformColor.tertiarySystemBackground))
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )

            TextEditor(text: $notes)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 120)
                .padding(8)
                .focused($focusedField, equals: .notes)
                .onChange(of: notes) { newValue in
                    guard let s = selectedScene else { return }
                    persistElementCSV(to: s, keys: ["notes", "sceneNotes", "notesText"], value: newValue)
                    saveContext()
                    syncSceneToShotLister(s)
                    syncSceneToScheduler(s)
                }
        }
    }

    @ViewBuilder
    private var locationSyncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location Sync")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            if !linkedLocationID.isEmpty, let linkedLocation = getLinkedLocation() {
                linkedLocationRow(linkedLocation)
            } else {
                linkLocationButton
            }
        }
    }

    @ViewBuilder
    private func linkedLocationRow(_ linkedLocation: NSManagedObject) -> some View {
        // Guard against deleted or invalid Core Data objects to prevent EXC_BAD_ACCESS
        if linkedLocation.isDeleted || linkedLocation.managedObjectContext == nil {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(linkedLocation.value(forKey: "name") as? String ?? "Unknown Location")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let address = linkedLocation.value(forKey: "address") as? String, !address.isEmpty {
                        Text(address)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: { unlinkLocation() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1.5)
            )
        }
    }

    private var linkLocationButton: some View {
        Button(action: { showLocationPicker() }) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 14))

                Text("Link Location from Locations App")
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var scheduleSyncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schedule Sync")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            if let scene = selectedScene {
                if let scheduleDate = getSceneScheduleDate(scene) {
                    scheduledDateRow(scene: scene, date: scheduleDate)
                } else {
                    notScheduledRow(scene: scene)
                }
            }
        }
    }

    private func scheduledDateRow(scene: SceneEntity, date: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Scheduled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { syncSceneToScheduler(scene) }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .customTooltip("Sync to Scheduler")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.green.opacity(0.4), lineWidth: 1.5)
        )
    }

    private func notScheduledRow(scene: SceneEntity) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Not yet scheduled")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: { syncSceneToScheduler(scene) }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                    Text("Sync")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color(BreakdownsPlatformColor.tertiarySystemBackground))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var budgetSyncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Budget Sync")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            if let scene = selectedScene {
                let estimatedCost = getSceneBudgetEstimate(scene)
                if estimatedCost > 0 {
                    budgetEstimateRow(scene: scene, cost: estimatedCost)
                } else {
                    noBudgetEstimateRow(scene: scene)
                }
            }
        }
    }

    private func budgetEstimateRow(scene: SceneEntity, cost: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Cost")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(cost, format: .currency(code: "USD"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { syncSceneToBudget(scene) }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .customTooltip("Sync to Budget")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
        )
    }

    private func noBudgetEstimateRow(scene: SceneEntity) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("No budget estimate")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: { syncSceneToBudget(scene) }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                    Text("Sync")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color(BreakdownsPlatformColor.tertiarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Clean Element Section Helper
    @ViewBuilder
    private func modernElementSection(title: String,
                                      state: Binding<String>,
                                      newToken: Binding<String>,
                                      color: Color,
                                      attributeKeys: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title with color accent
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            let tokens = tokensFromCSV(state.wrappedValue)

            if tokens.isEmpty {
                Text("No \(title.lowercased()) added")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(tokens, id: \.self) { item in
                        HStack(spacing: 6) {
                            Text(item)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button(action: {
                                removeElementToken(item, from: state, keys: attributeKeys)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(color.opacity(0.15))
                        .cornerRadius(6)
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("Add...", text: newToken)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(BreakdownsPlatformColor.tertiarySystemBackground))
                    .cornerRadius(6)
                    .onSubmit {
                        addElementToken(newToken.wrappedValue, to: state, keys: attributeKeys)
                        newToken.wrappedValue = ""
                    }

                Button(action: {
                    addElementToken(newToken.wrappedValue, to: state, keys: attributeKeys)
                    newToken.wrappedValue = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                .disabled(newToken.wrappedValue.isEmpty)
            }
        }
        .padding(12)
        .background(Color(BreakdownsPlatformColor.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Clean Custom Category Section Helper
    @ViewBuilder
    private func customCategorySection(category: (name: String, items: [String])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: {
                    removeCustomCategory(name: category.name)
                }) {
                    Image(systemName: "trash.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            if category.items.isEmpty {
                Text("No items added")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(category.items, id: \.self) { item in
                        SimpleListItem(text: item, onRemove: {
                            removeCustomCategoryItem(categoryName: category.name, item: item)
                        })
                    }
                }
            }

            HStack {
                TextField("Add item...", text: Binding(
                    get: { customCategoryInputs[category.name] ?? "" },
                    set: { customCategoryInputs[category.name] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onSubmit {
                    addCustomCategoryItem(categoryName: category.name, item: customCategoryInputs[category.name] ?? "")
                    customCategoryInputs[category.name] = ""
                }

                Button(action: {
                    addCustomCategoryItem(categoryName: category.name, item: customCategoryInputs[category.name] ?? "")
                    customCategoryInputs[category.name] = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(BreakdownsPlatformColor.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Compact Element Row (for dropdown)
    @ViewBuilder
    private func compactElementRow(title: String,
                                   icon: String,
                                   state: Binding<String>,
                                   newToken: Binding<String>,
                                   color: Color,
                                   attributeKeys: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
            }

            let tokens = tokensFromCSV(state.wrappedValue)

            if tokens.isEmpty {
                Text("No \(title.lowercased()) added")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.vertical, 2)
            } else {
                VStack(spacing: 3) {
                    ForEach(tokens, id: \.self) { item in
                        HStack(spacing: 6) {
                            Text(item)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            Button(action: {
                                removeElementToken(item, from: state, keys: attributeKeys)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }

            HStack(spacing: 4) {
                TextField("Add...", text: newToken)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onSubmit {
                        addElementToken(newToken.wrappedValue, to: state, keys: attributeKeys)
                        newToken.wrappedValue = ""
                    }

                Button(action: {
                    addElementToken(newToken.wrappedValue, to: state, keys: attributeKeys)
                    newToken.wrappedValue = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                .disabled(newToken.wrappedValue.isEmpty)
            }
        }
        .padding(10)
        .background(sceneCardBackground)
        .cornerRadius(8)
    }

    // MARK: - Compact Custom Category Row (for dropdown)
    @ViewBuilder
    private func compactCustomCategoryRow(category: (name: String, items: [String]), index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(category.name, systemImage: "folder.fill")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button(action: {
                    removeCustomCategory(name: category.name)
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            if category.items.isEmpty {
                Text("No items added")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.vertical, 2)
            } else {
                VStack(spacing: 3) {
                    ForEach(category.items, id: \.self) { item in
                        HStack(spacing: 6) {
                            Text(item)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            Button(action: {
                                removeCustomCategoryItem(categoryName: category.name, item: item)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(sceneCardSecondaryBackground)
                        .cornerRadius(4)
                    }
                }
            }

            HStack(spacing: 4) {
                TextField("Add item...", text: Binding(
                    get: { customCategoryInputs[category.name] ?? "" },
                    set: { customCategoryInputs[category.name] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .onSubmit {
                    addCustomCategoryItem(categoryName: category.name, item: customCategoryInputs[category.name] ?? "")
                    customCategoryInputs[category.name] = ""
                }

                Button(action: {
                    addCustomCategoryItem(categoryName: category.name, item: customCategoryInputs[category.name] ?? "")
                    customCategoryInputs[category.name] = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(sceneCardBackground)
        .cornerRadius(8)
    }

    // MARK: - Reports Tab
    private var reportsTabContent: some View {
        VStack(alignment: .leading, spacing: BreakdownsDesign.spacing) {
            Text("Reports")
                .font(.system(size: 20, weight: .bold))
            
            Text("Report generation features coming soon...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Inspector
    private var inspectorPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BreakdownsDesign.spacing) {
                Text("Inspector")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, BreakdownsDesign.spacing)
                    .padding(.top, BreakdownsDesign.spacing)
                
                if let scene = selectedScene {
                    VStack(alignment: .leading, spacing: 12) {
                        // Scene Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scene \(scene.number ?? "—")")
                                .font(.system(size: 15, weight: .semibold))
                            Text(getHeading(scene))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cleanCard()
                        
                        // Quick Stats
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Statistics", icon: "chart.bar.fill")
                            
                            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                                GridRow {
                                    Label("Length", systemImage: "doc.text")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatPageLength(Int(scene.pageEighths)) + " pages")
                                        .font(.system(size: 14, design: .monospaced))
                                }
                                
                                GridRow {
                                    Label("Cast", systemImage: "person.2")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(castMembers.count) members")
                                }
                            }
                        }
                        .cleanCard()
                        
                        // Quick Actions
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Actions", icon: "bolt.fill")
                            
                            VStack(spacing: 8) {
                                Button(action: generateDescription) {
                                    Label("Generate Description", systemImage: "wand.and.stars")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(role: .destructive, action: performDeleteCommand) {
                                    Label("Delete Scene", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .cleanCard()
                    }
                    .padding(.horizontal, BreakdownsDesign.spacing)
                } else {
                    Text("No scene selected")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var resizableSidebarDivider: some View {
        #if os(macOS)
        let handleWidth: CGFloat = 8
        Rectangle()
            .fill(isDraggingSidebar ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
            .frame(width: handleWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingSidebar = true
                        let newWidth = sidebarWidth + value.translation.width
                        let clamped = min(max(minSidebarWidth, newWidth), maxSidebarWidth)
                        if clamped != sidebarWidth { sidebarWidth = clamped }
                    }
                    .onEnded { _ in
                        isDraggingSidebar = false
                    }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
            }
        #else
        Divider()
        #endif
    }
    
    // MARK: - Helper Functions
    private var filteredScenes: [SceneEntity] {
        // First, filter by selected breakdown version
        let versionFilteredScenes: [SceneEntity]
        if let selectedVersionId = selectedVersion?.id {
            versionFilteredScenes = stripStore.scenes.filter { scene in
                // Use KVC to access the breakdownVersionId attribute
                if let versionId = scene.value(forKey: "breakdownVersionId") as? UUID {
                    return versionId == selectedVersionId
                }
                // Include scenes without a version ID (unversioned/imported scenes)
                // These should be visible in all versions
                return true
            }
        } else {
            // No version selected - show all scenes (legacy behavior)
            versionFilteredScenes = stripStore.scenes
        }

        // Then apply search filter
        if searchText.isEmpty {
            return versionFilteredScenes
        }
        let search = searchText.lowercased()
        return versionFilteredScenes.filter { scene in
            // Search scene heading and number
            let heading = getHeading(scene).lowercased()
            let number = (scene.number ?? "").lowercased()
            if heading.contains(search) || number.contains(search) {
                return true
            }
            // Search script content (plain text and FDX)
            if let scriptText = scene.scriptText?.lowercased(), scriptText.contains(search) {
                return true
            }
            if let scriptFDX = scene.scriptFDX?.lowercased(), scriptFDX.contains(search) {
                return true
            }
            // Search location/slug
            if let slug = scene.sceneSlug?.lowercased(), slug.contains(search) {
                return true
            }
            // Search location
            if let location = scene.scriptLocation?.lowercased(), location.contains(search) {
                return true
            }
            return false
        }
    }

    // MARK: - PDF Export Functions

    private func exportSceneBreakdown() {
        guard let scene = selectedScene else { return }

        guard let pdfDocument = BreakdownScenePDF.generatePDF(for: scene, context: context),
              let data = pdfDocument.dataRepresentation() else {
            print("Failed to generate scene breakdown PDF")
            return
        }

        savePDF(data: data, filename: "Scene_\(scene.number ?? "Unknown")_Breakdown.pdf")
    }

    private func exportScriptBreakdown() {
        let scenes = stripStore.scenes
        guard !scenes.isEmpty else {
            print("No scenes to export")
            return
        }

        guard let pdfDocument = BreakdownScenePDF.generateMultiScenePDF(for: scenes, context: context),
              let data = pdfDocument.dataRepresentation() else {
            print("Failed to generate script breakdown PDF")
            return
        }

        savePDF(data: data, filename: "Script_Breakdown.pdf")
    }

    private func savePDF(data: Data, filename: String) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Breakdown PDF"
        savePanel.message = "Choose a location to save the breakdown PDF"
        savePanel.nameFieldStringValue = filename

        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    print("PDF saved successfully to \(url.path)")
                } catch {
                    print("Error saving PDF: \(error)")
                }
            }
        }
        #else
        // iOS - use share sheet
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }

    private func printSceneBreakdown() {
        #if os(macOS)
        guard let scene = selectedScene else { return }

        guard let pdfDocument = BreakdownScenePDF.generatePDF(for: scene, context: context) else {
            print("Failed to generate scene breakdown PDF for printing")
            return
        }

        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let printOperation = pdfDocument.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true)
        printOperation?.runModal(for: NSApp.mainWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
        #endif
    }

    private func normalizedHeading(_ text: String?) -> String {
        let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Untitled Scene" : t
    }
    
    private func heading(for scene: SceneEntity) -> String {
        if let cached = sceneHeadingCache[scene.objectID] { return cached }
        let normalized = normalizedHeading(getHeading(scene))
        sceneHeadingCache[scene.objectID] = normalized
        return normalized
    }
    
    private func setHeading(_ text: String, for scene: SceneEntity) {
        setHeading(scene, value: text)
        sceneHeadingCache[scene.objectID] = text
    }
    
    private func getHeading(_ scene: SceneEntity) -> String {
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
    
    private func setHeading(_ scene: SceneEntity, value: String) {
        let original = value
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        sceneHeadingCache[scene.objectID] = trimmed

        if scene.entity.attributesByName.keys.contains("heading") {
            let core = extractCoreHeading(from: trimmed)
            scene.setValue(core, forKey: "heading")
            return
        }

        let normalized = trimmed
            .replacingOccurrences(of: " – ", with: " — ")
            .replacingOccurrences(of: " - ", with: " — ")
            .replacingOccurrences(of: "\u{2013}", with: "—")
            .replacingOccurrences(of: "\u{2014}", with: "—")

        let parts = normalized.split(separator: "—", maxSplits: 1, omittingEmptySubsequences: true)
        let leftPart = parts.first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let rightPart = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

        let upperRight = rightPart.uppercased()
        let knownTimes = ["DAY", "NIGHT", "DAWN", "DUSK"]
        let parsedTime: String? = knownTimes.first { upperRight.contains($0) }

        var parsedLocType: String? = nil
        var parsedLocationName: String = leftPart

        let upperLeft = leftPart.uppercased()
        if upperLeft.hasPrefix("INT./EXT.") {
            parsedLocType = "INT./EXT."
            parsedLocationName = String(leftPart.dropFirst("INT./EXT.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if upperLeft.hasPrefix("INT.") || upperLeft.hasPrefix("INT ") || upperLeft.hasPrefix("INT") {
            parsedLocType = "INT."
            var dropLen = 3
            if upperLeft.hasPrefix("INT.") { dropLen = 4 }
            parsedLocationName = String(leftPart.dropFirst(dropLen)).trimmingCharacters(in: .whitespacesAndNewlines)
            if parsedLocationName.hasPrefix(".") { parsedLocationName = String(parsedLocationName.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
        } else if upperLeft.hasPrefix("EXT.") || upperLeft.hasPrefix("EXT ") || upperLeft.hasPrefix("EXT") {
            parsedLocType = "EXT."
            var dropLen = 3
            if upperLeft.hasPrefix("EXT.") { dropLen = 4 }
            parsedLocationName = String(leftPart.dropFirst(dropLen)).trimmingCharacters(in: .whitespacesAndNewlines)
            if parsedLocationName.hasPrefix(".") { parsedLocationName = String(parsedLocationName.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if let parsedLocType { scene.setValue(parsedLocType, forKey: "locationType") }
        if !parsedLocationName.isEmpty { scene.setValue(parsedLocationName.uppercased(), forKey: "scriptLocation") }
        if let parsedTime { scene.setValue(parsedTime, forKey: "timeOfDay") }
    }
    
    private func extractCoreHeading(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let normalized = trimmed
            .replacingOccurrences(of: " – ", with: " — ")
            .replacingOccurrences(of: " - ", with: " — ")
            .replacingOccurrences(of: "\u{2013}", with: "—")
            .replacingOccurrences(of: "\u{2014}", with: "—")

        let parts = normalized.split(separator: "—", maxSplits: 1, omittingEmptySubsequences: true)
        let leftPart = parts.first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? normalized

        let upperLeft = leftPart.uppercased()
        var core = leftPart
        if upperLeft.hasPrefix("INT./EXT.") {
            core = String(leftPart.dropFirst("INT./EXT.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if upperLeft.hasPrefix("INT.") || upperLeft.hasPrefix("INT ") || upperLeft.hasPrefix("INT") {
            var dropLen = 3
            if upperLeft.hasPrefix("INT.") { dropLen = 4 }
            core = String(leftPart.dropFirst(dropLen)).trimmingCharacters(in: .whitespacesAndNewlines)
            if core.hasPrefix(".") { core = String(core.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
        } else if upperLeft.hasPrefix("EXT.") || upperLeft.hasPrefix("EXT ") || upperLeft.hasPrefix("EXT") {
            var dropLen = 3
            if upperLeft.hasPrefix("EXT.") { dropLen = 4 }
            core = String(leftPart.dropFirst(dropLen)).trimmingCharacters(in: .whitespacesAndNewlines)
            if core.hasPrefix(".") { core = String(core.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return core.uppercased()
    }
    
    private func formatPageLength(_ totalEighths: Int) -> String {
        let pages = totalEighths / 8
        let eighths = totalEighths % 8

        // Film breakdown standard: display as n/8 format (e.g., 4/8 instead of 1/2)
        switch (pages, eighths) {
        case (0, 0): return "0"
        case (0, _): return "\(eighths)/8"
        case (_, 0): return "\(pages)"
        default:     return "\(pages) \(eighths)/8"
        }
    }

    /// Calculate page eighths from FDX content (55 lines = 1 page = 8 eighths)
    private func calculatePageEighths(from fdxContent: String?) -> Int {
        guard let fdx = fdxContent, !fdx.isEmpty else { return 1 }

        // Parse FDX and count lines
        let paragraphs = parseFDXParagraphs(fdx)
        let charsPerLine = 60
        let linesPerPage = 55

        var totalLines = 0
        for para in paragraphs {
            let text = para.text
            let textLines = max(1, (text.count / charsPerLine) + 1)

            // Add spacing based on element type
            let spacing: Int
            switch para.type.lowercased() {
            case "scene heading", "sceneheading", "slug":
                spacing = 2
            case "character":
                spacing = 1
            case "dialogue", "parenthetical":
                spacing = 0
            default:
                spacing = 1
            }
            totalLines += textLines + spacing
        }

        // Convert lines to eighths (55 lines = 8 eighths)
        let eighths = max(1, Int(round(Double(totalLines) * 8.0 / Double(linesPerPage))))
        return eighths
    }

    /// Recalculate page lengths for all scenes from their FDX content
    private func recalculateAllPageLengths() {
        var updatedCount = 0

        for scene in stripStore.scenes {
            // Get FDX content
            let fdxAttributeNames = ["scriptFDX", "fdxRaw", "fdxXML", "sourceFDX", "sceneXML", "fdxContent"]
            var fdxContent: String? = nil

            for key in fdxAttributeNames where scene.entity.attributesByName.keys.contains(key) {
                if let value = scene.value(forKey: key) as? String,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fdxContent = value
                    break
                }
            }

            if let fdx = fdxContent {
                let calculatedEighths = calculatePageEighths(from: fdx)
                if scene.pageEighths != Int16(calculatedEighths) {
                    scene.pageEighths = Int16(calculatedEighths)
                    updatedCount += 1
                }
            }
        }

        if updatedCount > 0 {
            saveContext()
            sidebarRefreshID = UUID()
            print("[Breakdowns] Recalculated page lengths for \(updatedCount) scenes")
        }
    }
    
    private func handleSceneTap(_ s: SceneEntity) {
        #if os(macOS)
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        if flags.contains(.command) {
            if selectedSceneIDs.contains(s.objectID) {
                selectedSceneIDs.remove(s.objectID)
            } else {
                selectedSceneIDs.insert(s.objectID)
                selectionAnchorID = s.objectID
            }
            selectedSceneID = s.objectID
        } else if flags.contains(.shift), let anchor = selectionAnchorID,
                  let a = stripStore.scenes.firstIndex(where: { $0.objectID == anchor }),
                  let b = stripStore.scenes.firstIndex(where: { $0.objectID == s.objectID }) {
            let lo = min(a, b), hi = max(a, b)
            let ids = stripStore.scenes[lo...hi].map { $0.objectID }
            selectedSceneIDs.formUnion(ids)
            selectedSceneID = s.objectID
        } else {
            selectedSceneIDs = [s.objectID]
            selectionAnchorID = s.objectID
            selectedSceneID = s.objectID
        }
        #else
        selectedSceneID = s.objectID
        #endif
    }

    private func selectAllScenes() {
        #if os(macOS)
        let allIDs = stripStore.scenes.map { $0.objectID }
        selectedSceneIDs = Set(allIDs)
        if let first = stripStore.scenes.first {
            selectionAnchorID = first.objectID
            // Keep the current selected scene if one is already selected
            if selectedScene == nil {
                selectedSceneID = first.objectID
            }
        }
        #endif
    }

    private func loadSceneData(_ scene: SceneEntity) {
        // Load basic metadata
        sceneNumber = scene.number ?? ""
        scriptDay = scene.scriptDay ?? ""
        locationName = scene.scriptLocation ?? ""
        pageLengthEighths = Int(scene.pageEighths)

        // Load location type
        if let locType = scene.locationType {
            locationType = LocationType(rawValue: locType) ?? .int
        } else {
            locationType = .int
        }

        // Load time of day
        if let tod = scene.timeOfDay {
            timeOfDay = TimeOfDay(rawValue: tod) ?? .day
        } else {
            timeOfDay = .day
        }
        
        // Load heading
        let coreHeadingForEditor: String = {
            if scene.entity.attributesByName.keys.contains("heading"),
               let h = scene.value(forKey: "heading") as? String,
               !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return h
            }
            return extractCoreHeading(from: getHeading(scene))
        }()
        slugLine = coreHeadingForEditor
        sceneHeadingCache[scene.objectID] = coreHeadingForEditor
        
        // Load cast
        cast = scene.castIDs ?? ""
        loadBreakdownCastMembers()

        // Load description (only if not currently editing it)
        if focusedField != .sceneDescription {
            descriptionText = getDescription(from: scene)
        }

        // Load breakdown data from BreakdownEntity if available
        if let breakdown = scene.breakdown {
            extras = breakdown.extras ?? ""
            props = breakdown.props ?? ""
            wardrobe = breakdown.wardrobe ?? ""
            vehicles = breakdown.vehicles ?? ""
            makeup = breakdown.makeup ?? ""
            spfx = breakdown.spfx ?? ""
            art = breakdown.art ?? ""
            soundfx = breakdown.soundfx ?? ""
            vfx = breakdown.visualEffects ?? ""
            animals = breakdown.animals ?? ""
            stunts = breakdown.stunts ?? ""
            specialEquipment = breakdown.specialEquipment ?? ""

            // Load custom categories
            customCategories = breakdown.getCustomCategories()
        } else {
            // Fallback to old storage if breakdown entity doesn't exist
            func readCSV(_ keys: [String]) -> String {
                for k in keys where scene.entity.attributesByName.keys.contains(k) {
                    if let v = scene.value(forKey: k) as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return v
                    }
                }
                return ""
            }

            extras = readCSV(["extras"])
            props = readCSV(["props"])
            wardrobe = readCSV(["wardrobe"])
            vehicles = readCSV(["vehicles"])
            makeup = readCSV(["makeup"])
            spfx = readCSV(["spfx"])
            art = readCSV(["art"])
            soundfx = readCSV(["soundfx"])
            customCategories = []
        }

        // Legacy elements (keep these for backwards compatibility)
        func readCSV(_ keys: [String]) -> String {
            for k in keys where scene.entity.attributesByName.keys.contains(k) {
                if let v = scene.value(forKey: k) as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return v
                }
            }
            return ""
        }

        stunts = readCSV(["stunts"])
        hairMakeupFX = readCSV(["hairMakeupFX", "hairMakeup", "makeupFX"])
        setDressing = readCSV(["setDressing"])
        animals = readCSV(["animals"])
        sfx = readCSV(["sfx", "practicalEffects"])
        vfx = readCSV(["vfx"])
        specialEquipment = readCSV(["specialEquipment"])
        notes = readCSV(["notes", "sceneNotes", "notesText"])
        
        // Load linked location ID if available
        let locationIDKeys = ["locationID", "locationRef", "locationGUID", "locationEntityID", "linkedLocationID", "locationsAppID"]
        for key in locationIDKeys {
            if scene.entity.attributesByName.keys.contains(key),
               let id = scene.value(forKey: key) as? String,
               !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                linkedLocationID = id
                break
            }
        }
    }
    
    private func isExpanded(_ id: NSManagedObjectID) -> Bool {
        expandedSceneIDs.contains(id)
    }
    
    private func toggleExpanded(_ id: NSManagedObjectID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedSceneIDs.contains(id) {
                expandedSceneIDs.remove(id)
            } else {
                expandedSceneIDs.insert(id)
            }
        }
    }
    
    // MARK: - Cast Management
    private func loadBreakdownCastMembers() {
        guard let s = selectedScene else {
            castMembers = []
            return
        }

        // Try to load from JSON format first
        if let castData = s.value(forKey: "castMembersJSON") as? String,
           let data = castData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([BreakdownCastMember].self, from: data) {
            castMembers = decoded
            return
        }

        // Fall back to legacy CSV format and migrate
        if let castIDs = s.value(forKey: "castIDs") as? String, !castIDs.isEmpty {
            let legacy = castIDs.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { BreakdownCastMember(name: $0.element, castID: "\($0.offset + 1)") }
            castMembers = legacy
            saveBreakdownCastMembers() // Migrate to new format
        } else {
            castMembers = []
        }
    }

    private func saveBreakdownCastMembers() {
        guard let s = selectedScene else { return }

        // Save as JSON
        if let encoded = try? JSONEncoder().encode(castMembers),
           let jsonString = String(data: encoded, encoding: .utf8) {
            s.setValue(jsonString, forKey: "castMembersJSON")
        }

        // Also save to castIDs for backward compatibility with Scheduler
        let castIDsString = castMembers.map { "\($0.castID): \($0.name)" }.joined(separator: ", ")
        s.setValue(castIDsString, forKey: "castIDs")

        saveContext()
        syncSceneToShotLister(s)
        syncSceneToScheduler(s)
    }

    private func addBreakdownCastMember() {
        let trimmedName = newCastToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = newCastID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty && !trimmedID.isEmpty else { return }

        let newMember = BreakdownCastMember(name: trimmedName, castID: trimmedID)
        castMembers.append(newMember)
        saveBreakdownCastMembers()

        newCastToken = ""
        newCastID = ""
    }

    private func removeBreakdownCastMember(_ member: BreakdownCastMember) {
        castMembers.removeAll { $0.id == member.id }
        saveBreakdownCastMembers()
    }

    private func updateBreakdownCastMember(_ updated: BreakdownCastMember) {
        if let index = castMembers.firstIndex(where: { $0.id == updated.id }) {
            castMembers[index] = updated
            saveBreakdownCastMembers()
        }
    }
    
    // MARK: - Generic Element Token Management
    private func tokensFromCSV(_ text: String) -> [String] {
        let seps = CharacterSet(charactersIn: ",\n\r\t;")
        return text
            .components(separatedBy: seps)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func normalizedCSV(from raw: String) -> String {
        let tokens = tokensFromCSV(raw)
        var seen = Set<String>()
        var ordered: [String] = []
        for t in tokens {
            let key = t.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                ordered.append(t)
            }
        }
        return ordered.joined(separator: ", ")
    }
    
    private func addElementToken(_ token: String, to state: Binding<String>, keys: [String]) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var tokens = tokensFromCSV(state.wrappedValue)
        tokens.append(trimmed)
        let csv = normalizedCSV(from: tokens.joined(separator: ", "))
        state.wrappedValue = csv
        if let s = selectedScene {
            persistElementCSV(to: s, keys: keys, value: csv)
            saveContext()
            syncSceneToShotLister(s)
            syncSceneToScheduler(s)
        }
    }
    
    private func removeElementToken(_ token: String, from state: Binding<String>, keys: [String]) {
        var tokens = tokensFromCSV(state.wrappedValue)
        tokens.removeAll { $0.caseInsensitiveCompare(token) == .orderedSame }
        let csv = normalizedCSV(from: tokens.joined(separator: ", "))
        state.wrappedValue = csv
        if let s = selectedScene {
            persistElementCSV(to: s, keys: keys, value: csv)
            saveContext()
            syncSceneToShotLister(s)
            syncSceneToScheduler(s)
        }
    }
    
    private func persistElementCSV(to scene: SceneEntity, keys: [String], value: String) {
        // Get or create breakdown entity
        let breakdown = BreakdownEntity.getOrCreate(for: scene, in: context)

        // Save to BreakdownEntity based on the key
        if keys.contains("extras") {
            breakdown.extras = value
        } else if keys.contains("props") {
            breakdown.props = value
        } else if keys.contains("wardrobe") {
            breakdown.wardrobe = value
        } else if keys.contains("vehicles") {
            breakdown.vehicles = value
        } else if keys.contains("makeup") || keys.contains("hairMakeupFX") {
            breakdown.makeup = value
        } else if keys.contains("spfx") || keys.contains("sfx") {
            breakdown.spfx = value
        } else if keys.contains("art") || keys.contains("setDressing") {
            breakdown.art = value
        } else if keys.contains("soundfx") {
            breakdown.soundfx = value
        } else if keys.contains("vfx") {
            breakdown.visualEffects = value
        } else if keys.contains("animals") {
            breakdown.animals = value
        } else if keys.contains("stunts") {
            breakdown.stunts = value
        } else if keys.contains("specialEquipment") {
            breakdown.specialEquipment = value
        } else {
            // Fallback to old storage for legacy elements
            for k in keys where scene.entity.attributesByName.keys.contains(k) {
                scene.setValue(value, forKey: k)
                return
            }
        }

        breakdown.touch()
    }

    // MARK: - Highlight Element Integration

    /// Adds a highlighted element from the script to the Production Elements breakdown
    private func addHighlightedElementToBreakdown(elementType: ProductionElementType, text: String) {
        guard selectedScene != nil else {
            print("⚠️ No scene selected for highlight")
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        print("✨ Adding highlighted element: '\(trimmed)' as \(elementType.rawValue)")

        // Map element type to the appropriate state binding and attribute keys
        switch elementType {
        case .cast:
            // Cast is handled differently with BreakdownCastMember
            let newMember = BreakdownCastMember(name: trimmed, castID: "\(castMembers.count + 1)")
            castMembers.append(newMember)
            saveBreakdownCastMembers()

        case .extras:
            addElementToken(trimmed, to: $extras, keys: ["extras"])

        case .stunts:
            addElementToken(trimmed, to: $stunts, keys: ["stunts"])

        case .props:
            addElementToken(trimmed, to: $props, keys: ["props"])

        case .wardrobe:
            addElementToken(trimmed, to: $wardrobe, keys: ["wardrobe"])

        case .makeupHair:
            addElementToken(trimmed, to: $hairMakeupFX, keys: ["hairMakeupFX", "makeup"])

        case .setDressing:
            addElementToken(trimmed, to: $setDressing, keys: ["setDressing"])

        case .specialEffects:
            addElementToken(trimmed, to: $sfx, keys: ["sfx", "spfx"])

        case .visualEffects:
            addElementToken(trimmed, to: $vfx, keys: ["vfx"])

        case .animals:
            addElementToken(trimmed, to: $animals, keys: ["animals"])

        case .vehicles:
            addElementToken(trimmed, to: $vehicles, keys: ["vehicles"])

        case .specialEquipment:
            addElementToken(trimmed, to: $specialEquipment, keys: ["specialEquipment"])

        case .sound:
            addElementToken(trimmed, to: $soundfx, keys: ["soundfx", "sound"])
        }
    }
    
    private func persistLinkedLocationID() {
        guard let s = selectedScene else { return }
        let candidateKeys = ["locationID", "locationRef", "locationGUID", "locationEntityID", "linkedLocationID", "locationsAppID"]
        let trimmed = linkedLocationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let available = Set(s.entity.attributesByName.keys)
        if let key = candidateKeys.first(where: { available.contains($0) }) {
            s.setValue(trimmed, forKey: key)
            saveContext()
        }
    }

    // MARK: - Location Sync Management

    private func getLinkedLocation() -> NSManagedObject? {
        guard !linkedLocationID.isEmpty else { return nil }

        // Fetch from Locations app
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "LocationEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", linkedLocationID)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            // Validate the fetched object is not deleted and has valid context
            if let location = results.first,
               !location.isDeleted,
               location.managedObjectContext != nil {
                return location
            }
            return nil
        } catch {
            print("Error fetching linked location: \(error)")
            return nil
        }
    }

    private func getSceneLocationName(_ scene: SceneEntity) -> String? {
        // Try to get linked location ID from scene
        let candidateKeys = ["locationID", "locationRef", "locationGUID", "locationEntityID", "linkedLocationID", "locationsAppID"]
        let available = Set(scene.entity.attributesByName.keys)

        var locationID: String?
        for key in candidateKeys where available.contains(key) {
            if let id = scene.value(forKey: key) as? String, !id.isEmpty {
                locationID = id
                break
            }
        }

        guard let locID = locationID, !locID.isEmpty else { return nil }

        // Fetch location from Locations app
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "LocationEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", locID)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            if let location = results.first {
                return location.value(forKey: "name") as? String
            }
        } catch {
            print("Error fetching location for scene: \(error)")
        }

        return nil
    }

    private func unlinkLocation() {
        linkedLocationID = ""
        guard let s = selectedScene else { return }

        let candidateKeys = ["locationID", "locationRef", "locationGUID", "locationEntityID", "linkedLocationID", "locationsAppID"]
        let available = Set(s.entity.attributesByName.keys)

        for key in candidateKeys where available.contains(key) {
            s.setValue(nil, forKey: key)
        }

        saveContext()
        syncSceneToShotLister(s)
        syncSceneToScheduler(s)
    }

    private func showLocationPicker() {
        // This will trigger the location picker sheet
        // You can implement a custom sheet or use the existing location search
        isSearchingLocation = true
    }

    private func linkLocation(_ location: LocationItem) {
        guard let s = selectedScene else { return }

        // Store the location ID
        linkedLocationID = location.id.uuidString

        // Persist to scene entity
        let candidateKeys = ["locationID", "locationRef", "locationGUID", "locationEntityID", "linkedLocationID", "locationsAppID"]
        let available = Set(s.entity.attributesByName.keys)

        if let key = candidateKeys.first(where: { available.contains($0) }) {
            s.setValue(location.id.uuidString, forKey: key)
        }

        // Also update the script location name if it's empty or matches pattern
        if locationName.isEmpty {
            locationName = location.name
            persistElementCSV(to: s, keys: ["scriptLocation", "locationName", "shootingLocation"], value: location.name)
        }

        saveContext()
        syncSceneToShotLister(s)
        syncSceneToScheduler(s)

        // Post notification for other apps to sync
        NotificationCenter.default.post(name: .breakdownsSceneSynced, object: s.objectID)
    }

    // MARK: - Custom Category Management

    private func addCustomCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !customCategories.contains(where: { $0.name == trimmed }) else { return }

        customCategories.append((name: trimmed, items: []))

        if let scene = selectedScene {
            let breakdown = BreakdownEntity.getOrCreate(for: scene, in: context)
            breakdown.addCustomCategory(name: trimmed)
            saveContext()
            syncSceneToShotLister(scene)
            syncSceneToScheduler(scene)
        }
    }

    private func removeCustomCategory(name: String) {
        customCategories.removeAll { $0.name == name }
        customCategoryInputs.removeValue(forKey: name)

        if let scene = selectedScene {
            let breakdown = BreakdownEntity.getOrCreate(for: scene, in: context)
            breakdown.removeCustomCategory(name: name)
            saveContext()
            syncSceneToShotLister(scene)
            syncSceneToScheduler(scene)
        }
    }

    private func addCustomCategoryItem(categoryName: String, item: String) {
        let trimmed = item.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let index = customCategories.firstIndex(where: { $0.name == categoryName }) {
            var category = customCategories[index]
            guard !category.items.contains(trimmed) else { return }
            category.items.append(trimmed)
            customCategories[index] = category

            if let scene = selectedScene {
                let breakdown = BreakdownEntity.getOrCreate(for: scene, in: context)
                breakdown.updateCustomCategory(name: categoryName, items: category.items)
                saveContext()
                syncSceneToShotLister(scene)
                syncSceneToScheduler(scene)
            }
        }
    }

    private func removeCustomCategoryItem(categoryName: String, item: String) {
        if let index = customCategories.firstIndex(where: { $0.name == categoryName }) {
            var category = customCategories[index]
            category.items.removeAll { $0 == item }
            customCategories[index] = category

            if let scene = selectedScene {
                let breakdown = BreakdownEntity.getOrCreate(for: scene, in: context)
                breakdown.updateCustomCategory(name: categoryName, items: category.items)
                saveContext()
                syncSceneToShotLister(scene)
                syncSceneToScheduler(scene)
            }
        }
    }

    private func generateDescription() {
        let intExt = locationType.id
        let tod    = timeOfDay.id
        let heading = slugLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let loc     = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !intExt.isEmpty { parts.append(intExt.uppercased()) }
        if !heading.isEmpty { parts.append(heading.uppercased()) }
        if !tod.isEmpty { parts.append("— \(tod.uppercased())") }

        var sentence = parts.joined(separator: ". ")
        if !loc.isEmpty { sentence += (sentence.isEmpty ? "" : ". ") + "Location: \(loc)" }

        descriptionText = sentence

        if let s = selectedScene {
            setDescription(for: s, value: sentence)
            saveContext()
        }
    }
    
    private func setDescription(for scene: SceneEntity, value: String) {
        let descriptionAttributeCandidates = ["descriptionText", "sceneDescription", "description", "synopsis", "summary"]
        for key in descriptionAttributeCandidates {
            if scene.entity.attributesByName.keys.contains(key) {
                scene.setValue(value, forKey: key)
                return
            }
        }
    }
    
    // MARK: - Screenplay Integration

    /// Load a script from Screenplay app's Core Data storage
    private func loadScriptFromScreenplay() {
        // Refresh the drafts list from Screenplay
        ScreenplayDataManager.shared.loadDrafts()
        showScreenplayDraftPicker = true
    }

    /// Load a specific draft from Screenplay into Breakdowns
    private func loadScreenplayDraft(_ draft: ScreenplayDraftInfo) {
        isLoadingFromScreenplay = true

        // Create the version ID first so we can tag scenes with it
        let newVersionId = UUID()

        Task {
            do {
                let count = try await ScreenplayBreakdownSync.shared.loadDraftToBreakdowns(
                    draftId: draft.id,
                    context: context,
                    breakdownVersionId: newVersionId  // Pass version ID to tag scenes
                )

                await MainActor.run {
                    isLoadingFromScreenplay = false
                    showScreenplayDraftPicker = false

                    // Create a new breakdown version linked to this screenplay draft
                    let versionName = draft.title.isEmpty ? "Breakdown v\(breakdownVersions.count + 1).0" : "\(draft.title) Breakdown"
                    let newVersion = BreakdownVersion(
                        id: newVersionId,  // Use the same ID we passed to the sync
                        name: versionName,
                        scriptDraftId: draft.id,
                        scriptTitle: draft.title,
                        sceneCount: count
                    )
                    breakdownVersions.append(newVersion)
                    selectBreakdownVersion(newVersion)

                    // Refresh the scenes list
                    NotificationCenter.default.post(
                        name: Notification.Name("breakdownsImportCompleted"),
                        object: nil
                    )

                    print("[Breakdowns] Loaded \(count) scenes from Screenplay draft: \(draft.title)")
                }
            } catch {
                await MainActor.run {
                    isLoadingFromScreenplay = false
                    print("[Breakdowns] Failed to load Screenplay draft: \(error)")
                }
            }
        }
    }

    /// Load revisions from Screenplay app's revision tracking
    private func loadRevisionsFromScreenplay() {
        // Fetch current project
        let projectRequest = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        projectRequest.fetchLimit = 1

        guard let projectEntity = try? context.fetch(projectRequest).first else {
            print("[Breakdowns] No project selected")
            return
        }

        // Fetch all script revisions for this project
        let fetchRequest: NSFetchRequest<ScriptRevisionEntity> = ScriptRevisionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "project == %@", projectEntity)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ScriptRevisionEntity.importedAt, ascending: true)]

        do {
            let revisions = try context.fetch(fetchRequest)

            guard !revisions.isEmpty else {
                print("[Breakdowns] No script revisions found for project")
                return
            }

            // Build revision color map
            var revisionColors: [UUID: (name: String, color: Color)] = [:]
            for revision in revisions {
                let colorName = revision.colorName ?? "white"
                let color = revisionColor(for: colorName)
                revisionColors[revision.id!] = (name: colorName, color: color)
            }

            // Count scenes linked to revisions
            var linkedCount = 0
            for scene in stripStore.scenes {
                if let revisionId = scene.importedFromRevision?.id,
                   let revisionInfo = revisionColors[revisionId] {
                    linkedCount += 1
                    print("[Breakdowns] Scene \(scene.number ?? "?") linked to \(revisionInfo.name) revision (color available via relationship)")
                }
            }

            if linkedCount > 0 {
                print("[Breakdowns] Found \(linkedCount) scenes linked to revisions")
            }

        } catch {
            print("[Breakdowns] Error loading revisions: \(error)")
        }
    }

    /// Get SwiftUI Color for a revision color name
    private func revisionColor(for colorName: String) -> Color {
        switch colorName.lowercased() {
        case "white": return Color(red: 1.0, green: 1.0, blue: 1.0)
        case "blue": return Color(red: 0.68, green: 0.85, blue: 0.90)
        case "pink": return Color(red: 1.0, green: 0.75, blue: 0.80)
        case "yellow": return Color(red: 1.0, green: 1.0, blue: 0.60)
        case "green": return Color(red: 0.60, green: 0.98, blue: 0.60)
        case "goldenrod": return Color(red: 0.93, green: 0.79, blue: 0.45)
        case "buff": return Color(red: 0.94, green: 0.86, blue: 0.70)
        case "salmon": return Color(red: 1.0, green: 0.63, blue: 0.48)
        case "cherry": return Color(red: 0.87, green: 0.44, blue: 0.63)
        case "tan": return Color(red: 0.82, green: 0.71, blue: 0.55)
        case "gray", "grey": return Color(red: 0.83, green: 0.83, blue: 0.83)
        default: return Color(red: 1.0, green: 1.0, blue: 1.0)
        }
    }

    // MARK: - iPad Sync

    /// Sync breakdowns to iPad via Firestore
    private func syncBreakdownsToiPad() {
        // Fetch current project
        let projectRequest = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        projectRequest.fetchLimit = 1

        guard let projectEntity = try? context.fetch(projectRequest).first else {
            syncAlertMessage = "No project selected"
            showSyncAlert = true
            return
        }

        guard let projectId = projectEntity.id?.uuidString else {
            syncAlertMessage = "Invalid project ID"
            showSyncAlert = true
            return
        }

        syncingToiPad = true

        Task {
            do {
                // Get Firestore reference
                let db = Firestore.firestore()
                let breakdownsRef = db.collection("projects").document(projectId).collection("breakdowns")

                // Batch write all scenes
                var batch = db.batch()
                var batchCount = 0
                let maxBatchSize = 500 // Firestore batch limit

                for scene in stripStore.scenes {
                    // Get revision color from linked revision entity
                    let revisionColor = scene.importedFromRevision?.colorName ?? "white"

                    let sceneData: [String: Any] = [
                        "id": scene.id?.uuidString ?? UUID().uuidString,
                        "number": scene.number ?? "",
                        "description": scene.descriptionText ?? "",
                        "location": scene.scriptLocation ?? "",
                        "timeOfDay": scene.timeOfDay ?? "",
                        "pageEighths": scene.pageEighths,
                        "castIDs": scene.castIDs ?? "",
                        "revisionColor": revisionColor,
                        "updatedAt": Date().timeIntervalSince1970
                    ]

                    let docRef = breakdownsRef.document(scene.id?.uuidString ?? UUID().uuidString)
                    batch.setData(sceneData, forDocument: docRef, merge: true)

                    batchCount += 1

                    // Commit batch if we hit the limit
                    if batchCount >= maxBatchSize {
                        try await batch.commit()
                        batch = db.batch()
                        batchCount = 0
                    }
                }

                // Commit remaining batch
                if batchCount > 0 {
                    try await batch.commit()
                }

                // Update sync metadata
                let metadataRef = db.collection("projects").document(projectId)
                try await metadataRef.setData([
                    "lastBreakdownSync": Date().timeIntervalSince1970,
                    "breakdownCount": stripStore.scenes.count
                ], merge: true)

                await MainActor.run {
                    lastSyncDate = Date()
                    syncingToiPad = false
                    syncAlertMessage = "Successfully synced \(stripStore.scenes.count) scenes to iPad"
                    showSyncAlert = true
                    print("[Breakdowns] Synced \(stripStore.scenes.count) scenes to Firestore")
                }

            } catch {
                await MainActor.run {
                    syncingToiPad = false
                    syncAlertMessage = "Sync failed: \(error.localizedDescription)"
                    showSyncAlert = true
                    print("[Breakdowns] Sync error: \(error)")
                }
            }
        }
    }

    // MARK: - Commands
    private func performNewScene() {
        let castCSV = normalizedCSV(from: cast)
        let trimmedNumber = sceneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextNumber: String = ensureUniqueSceneNumber(trimmedNumber)
        
        let new = stripStore.addScene(
            number: nextNumber,
            locationType: locationType.id,
            timeOfDay: timeOfDay.id,
            scriptLocation: locationName,
            castIDsCSV: castCSV,
            pageEighths: Int16(pageLengthEighths)
        )
        if let newScene = new {
            let hasSortIndexAttr = newScene.entity.attributesByName.keys.contains("sortIndex")
            let hasDisplayOrderAttr = newScene.entity.attributesByName.keys.contains("displayOrder")
            if hasSortIndexAttr || hasDisplayOrderAttr {
                let nextOrder = currentMaxDisplayOrder() + 1
                if hasSortIndexAttr { newScene.setValue(nextOrder, forKey: "sortIndex") }
                if hasDisplayOrderAttr { newScene.setValue(nextOrder, forKey: "displayOrder") }
            }
            // Tag scene with current breakdown version ID
            if let versionId = selectedVersion?.id {
                newScene.setValue(versionId, forKey: "breakdownVersionId")
            }
            selectedScene = newScene
            selectedSceneID = newScene.objectID
            if trimmedNumber.isEmpty { sceneNumber = nextNumber }
            setHeading(newScene, value: slugLine)
            sceneHeadingCache[newScene.objectID] = slugLine
            saveContext()
            updateVersionSceneCount()
            NotificationCenter.default.post(name: .breakdownsSceneOrderChanged, object: nil)
            syncSceneToShotLister(newScene)
            syncSceneToScheduler(newScene)
        }
    }
    
    private func performDuplicate() {
        guard let src = selectedScene else { return }
        let copy = SceneEntity(context: context)
        copy.id = UUID()
        copy.number = src.number
        copy.locationType = src.locationType
        copy.timeOfDay = src.timeOfDay
        copy.scriptLocation = src.scriptLocation
        copy.castIDs = src.castIDs
        copy.pageEighths = src.pageEighths
        copy.project = src.project
        setHeading(copy, value: getHeading(src))
        sceneHeadingCache[copy.objectID] = getHeading(src)
        let hasSortIndexAttr = copy.entity.attributesByName.keys.contains("sortIndex")
        let hasDisplayOrderAttr = copy.entity.attributesByName.keys.contains("displayOrder")
        if hasSortIndexAttr || hasDisplayOrderAttr {
            let nextOrder = currentMaxDisplayOrder() + 1
            if hasSortIndexAttr { copy.setValue(nextOrder, forKey: "sortIndex") }
            if hasDisplayOrderAttr { copy.setValue(nextOrder, forKey: "displayOrder") }
        }
        // Tag duplicated scene with current breakdown version ID
        if let versionId = selectedVersion?.id {
            copy.setValue(versionId, forKey: "breakdownVersionId")
        }
        saveContext()
        updateVersionSceneCount()
        NotificationCenter.default.post(name: .breakdownsSceneOrderChanged, object: nil)
        syncSceneToShotLister(copy)
        syncSceneToScheduler(copy)
        selectedScene = copy
        selectedSceneID = copy.objectID
    }
    
    private func performDeleteCommand() {
        #if os(macOS)
        let targets = !selectedSceneIDs.isEmpty ? Array(selectedSceneIDs) : (selectedSceneID.map { [$0] } ?? [])
        if !targets.isEmpty { confirmDelete(ids: targets) }
        #else
        if let target = selectedScene {
            removeFromShotLister(target)
            removeFromScheduler(target)
            context.delete(target)
            saveContext()
            NotificationCenter.default.post(name: .breakdownsSceneOrderChanged, object: nil)
            selectedScene = nil
            selectedSceneID = nil
        }
        #endif
    }
    
    private func confirmDelete(ids: [NSManagedObjectID]) {
        pendingDeleteIDs = ids
        showDeleteConfirm = true
    }
    
    private func performDelete(ids: [NSManagedObjectID]) {
        guard !ids.isEmpty else { return }
        context.undoManager?.beginUndoGrouping()
        for id in ids {
            if let s = stripStore.scenes.first(where: { $0.objectID == id }) {
                removeFromShotLister(s)
                removeFromScheduler(s)
                context.delete(s)
            }
        }
        saveContext()
        context.undoManager?.endUndoGrouping()
        selectedSceneIDs.subtract(ids)
        if let cur = selectedSceneID, ids.contains(cur) {
            selectedSceneID = nil
            selectedScene = nil
        }
        NotificationCenter.default.post(name: .breakdownsSceneOrderChanged, object: nil)
        sidebarRefreshID = UUID()
    }

    // MARK: - Clipboard Operations (Cut, Copy, Paste)

    private func performCutCommand() {
        #if os(macOS)
        // Check if text field has focus - let system handle cut
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text cut
            }
        }
        if focusedField != nil {
            return // Let system handle text cut
        }
        // Copy scenes to clipboard, then delete
        performCopyCommand()
        performDeleteCommand()
        #endif
    }

    private func performCopyCommand() {
        #if os(macOS)
        // Check if text field has focus - let system handle copy
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text copy
            }
        }
        if focusedField != nil {
            return // Let system handle text copy
        }
        // Copy selected scene IDs to clipboard
        let targets = !selectedSceneIDs.isEmpty ? Array(selectedSceneIDs) : (selectedSceneID.map { [$0] } ?? [])
        guard !targets.isEmpty else { return }
        sceneClipboard = targets
        #endif
    }

    private func performPasteCommand() {
        #if os(macOS)
        // Check if text field has focus - let system handle paste
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text paste
            }
        }
        if focusedField != nil {
            return // Let system handle text paste
        }
        // Paste scenes from clipboard
        guard !sceneClipboard.isEmpty else { return }

        context.undoManager?.beginUndoGrouping()

        var newSceneIDs: [NSManagedObjectID] = []
        for id in sceneClipboard {
            guard let original = stripStore.scenes.first(where: { $0.objectID == id }) else { continue }

            // Create a duplicate scene
            let newScene = SceneEntity(context: context)
            newScene.id = UUID()
            newScene.number = (original.number ?? "") + " (copy)"
            newScene.sceneSlug = original.sceneSlug
            newScene.scriptLocation = original.scriptLocation
            newScene.locationType = original.locationType
            newScene.timeOfDay = original.timeOfDay
            newScene.pageEighths = original.pageEighths
            newScene.scriptDay = original.scriptDay
            newScene.project = original.project

            // Copy additional attributes if they exist
            if original.entity.attributesByName.keys.contains("heading"),
               let heading = original.value(forKey: "heading") as? String {
                newScene.setValue(heading, forKey: "heading")
            }
            if original.entity.attributesByName.keys.contains("synopsis"),
               let synopsis = original.value(forKey: "synopsis") as? String {
                newScene.setValue(synopsis, forKey: "synopsis")
            }
            if original.entity.attributesByName.keys.contains("sceneDescription"),
               let desc = original.value(forKey: "sceneDescription") as? String {
                newScene.setValue(desc, forKey: "sceneDescription")
            }

            // Set sort index to place after original
            if original.entity.attributesByName.keys.contains("sortIndex"),
               let sortVal = original.value(forKey: "sortIndex") as? NSNumber {
                newScene.setValue(NSNumber(value: sortVal.intValue + 1), forKey: "sortIndex")
            }

            // Calculate displayOrder - place new scenes at the end
            let maxOrder = stripStore.scenes.map { $0.displayOrder }.max() ?? 0
            newScene.displayOrder = maxOrder + Int32(newSceneIDs.count) + 1

            newSceneIDs.append(newScene.objectID)
        }

        saveContext()
        context.undoManager?.endUndoGrouping()

        // Select the newly pasted scenes
        selectedSceneIDs = Set(newSceneIDs)
        if let first = newSceneIDs.first {
            selectedSceneID = first
            selectedScene = stripStore.scenes.first(where: { $0.objectID == first })
        }

        NotificationCenter.default.post(name: .breakdownsSceneOrderChanged, object: nil)
        sidebarRefreshID = UUID()
        #endif
    }

    // MARK: - Scene Reordering
    private func reindexAllScenes() {
        print("🔄 [SceneNumberDebug] Breakdowns.reindexAllScenes() called")
        print("🔄 Reindexing all scenes in sequential order...")
        
        // Get all scenes for this project
        let allScenes = Array(stripStore.scenes)
        
        // Check if scenes already have sequential ordinals (from import)
        // If so, preserve that order rather than re-sorting by scene number
        let hasSequentialOrdinals: Bool = {
            let hasSortIndex = allScenes.first?.entity.attributesByName.keys.contains("sortIndex") ?? false
            guard hasSortIndex else { return false }
            
            let ordinals = allScenes.compactMap { scene -> Int? in
                guard let val = scene.value(forKey: "sortIndex") as? NSNumber else { return nil }
                return val.intValue
            }
            
            // Check if ordinals are sequential (1, 2, 3, 4, ...) without gaps
            guard ordinals.count == allScenes.count else { return false }
            let sorted = ordinals.sorted()
            for (index, value) in sorted.enumerated() {
                if value != index + 1 { return false }
            }
            return true
        }()
        
        let sortedScenes: [SceneEntity]
        if hasSequentialOrdinals {
            // Preserve existing import order by sorting by the ordinal values
            print("  ✓ Preserving existing sequential import order")
            sortedScenes = allScenes.sorted { scene1, scene2 in
                let order1 = (scene1.value(forKey: "sortIndex") as? NSNumber)?.intValue ?? Int.max
                let order2 = (scene2.value(forKey: "sortIndex") as? NSNumber)?.intValue ?? Int.max
                return order1 < order2
            }
        } else {
            // Sort by scene number using natural/localized comparison (1, 2, 3, 10, 11 not 1, 10, 11, 2, 3)
            print("  ✓ Sorting by scene number")
            sortedScenes = allScenes.sorted { scene1, scene2 in
                let num1 = scene1.number ?? ""
                let num2 = scene2.number ?? ""
                return num1.localizedStandardCompare(num2) == .orderedAscending
            }
        }
        
        // Re-assign sequential order values (only if needed)
        var needsUpdate = false
        for (index, scene) in sortedScenes.enumerated() {
            let newOrder = index + 1
            if scene.entity.attributesByName.keys.contains("sortIndex") {
                let current = (scene.value(forKey: "sortIndex") as? NSNumber)?.intValue ?? -1
                if current != newOrder {
                    scene.setValue(newOrder, forKey: "sortIndex")
                    needsUpdate = true
                }
            }
            if scene.entity.attributesByName.keys.contains("displayOrder") {
                let current = (scene.value(forKey: "displayOrder") as? NSNumber)?.intValue ?? -1
                if current != newOrder {
                    scene.setValue(newOrder, forKey: "displayOrder")
                    needsUpdate = true
                }
            }
            print("  [SceneNumberDebug] Scene number='\(scene.number ?? "?")' id=\(scene.id?.uuidString ?? "nil"): displayOrder=\(newOrder), sortIndex=\(newOrder)")
        }
        
        if needsUpdate {
            saveContext()
        }
        
        // Force UI refresh
        sidebarRefreshID = UUID()
        
        print("✅ Reindexing complete - \(sortedScenes.count) scenes ordered")
    }
    
    // MARK: - Helpers
    private func ensureUniqueSceneNumber(_ candidate: String?) -> String {
        let trimmed = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nextAutoSceneNumber() }
        let existing = Set(stripStore.scenes.compactMap { $0.number?.trimmingCharacters(in: .whitespacesAndNewlines) })
        if !existing.contains(trimmed) { return trimmed }
        return nextAutoSceneNumber()
    }
    
    private func nextAutoSceneNumber() -> String {
        var used = Set<Int>()
        for s in stripStore.scenes {
            guard let raw = s.number?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            var digits = ""
            for ch in raw {
                if ch.isNumber { digits.append(ch) } else { break }
            }
            if let val = Int(digits), val > 0 { used.insert(val) }
        }
        if used.isEmpty { return "1" }
        var n = 1
        while used.contains(n) { n += 1 }
        return String(n)
    }
    
    private func currentMaxDisplayOrder() -> Int {
        let rows: [NSManagedObject] = stripStore.scenes.map { $0 as NSManagedObject }
        let maxSort = rows.compactMap { ($0.value(forKey: "sortIndex") as? NSNumber)?.intValue }.max() ?? 0
        let maxDisp = rows.compactMap { ($0.value(forKey: "displayOrder") as? NSNumber)?.intValue }.max() ?? 0
        return max(maxSort, maxDisp)
    }
    
    private func syncSceneToShotLister(_ scene: SceneEntity) {
        NotificationCenter.default.post(name: .breakdownsSceneSynced, object: scene.objectID)
    }
    
    private func removeFromShotLister(_ scene: SceneEntity) {
        NotificationCenter.default.post(name: .breakdownsSceneSynced, object: scene.objectID)
    }
    
    private func syncSceneToScheduler(_ scene: SceneEntity) {
        NotificationCenter.default.post(name: .breakdownsSceneSynced, object: scene.objectID)
    }
    
    private func removeFromScheduler(_ scene: SceneEntity) {
        NotificationCenter.default.post(name: .breakdownsSceneSynced, object: scene.objectID)
    }

    // MARK: - Schedule Sync Helpers

    private func getSceneScheduleDate(_ scene: SceneEntity) -> Date? {
        // Try to get schedule date from various possible attribute names
        let dateKeys = ["shootDate", "scheduledDate", "productionDate", "filmingDate", "scheduleDate"]
        let available = Set(scene.entity.attributesByName.keys)

        for key in dateKeys where available.contains(key) {
            if let date = scene.value(forKey: key) as? Date {
                return date
            }
        }

        // Also check if there's a day number that can be used to calculate date
        let dayKeys = ["shootDay", "dayNumber", "productionDay"]
        for key in dayKeys where available.contains(key) {
            if let dayNumber = scene.value(forKey: key) as? Int, dayNumber > 0 {
                // If we have a day number, we could calculate but would need production start date
                // For now, just return nil to indicate "scheduled but date unknown"
                return nil
            }
        }

        return nil
    }

    // MARK: - Budget Sync Helpers

    private func getSceneBudgetEstimate(_ scene: SceneEntity) -> Double {
        // Try to get budget estimate from various possible attribute names
        let budgetKeys = ["budgetEstimate", "estimatedCost", "sceneBudget", "cost", "budget"]
        let available = Set(scene.entity.attributesByName.keys)

        for key in budgetKeys where available.contains(key) {
            if let budget = scene.value(forKey: key) as? Double, budget > 0 {
                return budget
            }
            if let budget = scene.value(forKey: key) as? NSNumber {
                let value = budget.doubleValue
                if value > 0 { return value }
            }
        }

        // Calculate estimate based on page length if available
        // Standard industry estimate: ~$10,000-50,000 per page depending on production level
        let pageLengthKeys = ["pageLengthEighths", "pageLength", "eighths", "pages"]
        for key in pageLengthKeys where available.contains(key) {
            if let value = scene.value(forKey: key) as? Int, value > 0 {
                let pages = Double(value) / 8.0
                // Basic estimate: $15,000 per page (can be adjusted based on production scale)
                return pages * 15000.0
            }
            if let value = scene.value(forKey: key) as? NSNumber {
                let intValue = value.intValue
                if intValue > 0 {
                    let pages = Double(intValue) / 8.0
                    return pages * 15000.0
                }
            }
        }

        return 0
    }

    private func syncSceneToBudget(_ scene: SceneEntity) {
        // Post notification for budget app to pick up
        NotificationCenter.default.post(name: .breakdownsSceneSynced, object: scene.objectID)

        // Also update the budget estimate if not already set
        let budgetKeys = ["budgetEstimate", "estimatedCost", "sceneBudget"]
        let available = Set(scene.entity.attributesByName.keys)

        // Check if budget is already set
        var hasBudget = false
        for key in budgetKeys where available.contains(key) {
            if let budget = scene.value(forKey: key) as? Double, budget > 0 {
                hasBudget = true
                break
            }
        }

        // If no budget, calculate and store estimate
        if !hasBudget {
            let estimate = getSceneBudgetEstimate(scene)
            if estimate > 0, let key = budgetKeys.first(where: { available.contains($0) }) {
                scene.setValue(estimate, forKey: key)
                saveContext()
            }
        }
    }

    /// Helper to save context with proper error handling
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            NSLog("❌ Breakdowns save error: \(error.localizedDescription)")
            // Additional debugging
            if let detailedError = error as NSError? {
                NSLog("❌ Error details: \(detailedError.userInfo)")
            }
        }
    }

    private func locationDisplayName(_ loc: NSManagedObject) -> String {
        let keys = ["name", "title", "label"]
        for k in keys {
            if loc.entity.attributesByName.keys.contains(k),
               let v = loc.value(forKey: k) as? String,
               !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return v
            }
        }
        if loc.entity.attributesByName.keys.contains("address"),
           let v = loc.value(forKey: "address") as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return v
        }
        return "Untitled Location"
    }
    
    // MARK: - FDX Script Rendering
    
    private func getDescription(from scene: SceneEntity) -> String {
        let descriptionAttributeCandidates = ["descriptionText", "sceneDescription", "description", "synopsis", "summary", "logline",
                                              "notes", "sceneNotes", "notesText", "details", "textDescription"]
        for key in descriptionAttributeCandidates {
            if scene.entity.attributesByName.keys.contains(key),
               let v = scene.value(forKey: key) as? String,
               !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return v
            }
        }
        return ""
    }
    
    private func lastPageFraction(from totalEighths: Int) -> CGFloat {
        guard totalEighths > 0 else { return 1.0 }
        let pages = totalEighths / 8
        let rem = totalEighths % 8
        if pages == 0 {
            return max(0.125, CGFloat(rem) / 8.0)
        }
        return rem == 0 ? 1.0 : CGFloat(rem) / 8.0
    }
    
    // MARK: - FDX Paragraph Parsing
    
    private struct FDXPara { let type: String; let text: String }
    
    private final class FDXPageCollector: NSObject, XMLParserDelegate {
        var paras: [FDXPara] = []
        private var curType = ""
        private var curIsParagraph = false
        private var curText = ""
        private var bufferingText = false
        private var strikeDepth = 0

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String : String] = [:]) {
            if name == "Paragraph" {
                curIsParagraph = true
                curType = (attributes["Type"] ?? attributes["type"] ?? "").lowercased()
                curText = ""
            }
            if curIsParagraph && name == "Text" { bufferingText = true }
            if curIsParagraph && bufferingText && name == "Style" {
                let strikeAttr = (attributes["Strikeout"] ?? attributes["strikeout"] ?? attributes["STRIKEOUT"] ?? "")
                if strikeAttr.lowercased() == "yes" {
                    strikeDepth += 1
                    curText.append("\u{F001}")
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if bufferingText { curText += string }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
            if name == "Style", strikeDepth > 0 {
                strikeDepth -= 1
                curText.append("\u{F002}")
            }
            if name == "Text" { bufferingText = false }
            if name == "Paragraph" && curIsParagraph {
                let trimmed = curText.replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                paras.append(FDXPara(type: curType, text: trimmed))
                curIsParagraph = false
                curType = ""
                curText = ""
            }
        }
    }
    
    private func parseFDXParagraphs(_ xml: String) -> [FDXPara] {
        let wrapped = "<SceneFragment>\n\(xml)\n</SceneFragment>"
        guard let data = wrapped.data(using: .utf8) else { return [] }
        let c = FDXPageCollector()
        let p = XMLParser(data: data)
        p.delegate = c
        _ = p.parse()
        return c.paras
    }
    
    #if os(macOS)
    private func makeScriptAttributedString(from paras: [FDXPara]) -> NSAttributedString {
        let pagePT: CGFloat = 72
        let contentWidth: CGFloat = (612 - 108 - 72)
        let actionLeft: CGFloat     = 0.0
        let actionRight: CGFloat    = 0.0
        let parenthLeft: CGFloat    = pagePT * (3.1 - 1.5)
        let parenthRight: CGFloat   = pagePT * 2.5
        let dialogueLeft: CGFloat   = pagePT * (2.5 - 1.5)
        let dialogueRight: CGFloat  = pagePT * 2.0
        let dialogueWidth: CGFloat  = contentWidth - dialogueLeft - dialogueRight
        let dialogueCenterX: CGFloat = dialogueLeft + (dialogueWidth / 2.0)
        let characterBlockWidth: CGFloat = pagePT * 2.0
        let characterLeft: CGFloat  = max(0, dialogueCenterX - (characterBlockWidth / 2.0))
        let characterRight: CGFloat = max(0, contentWidth - (characterLeft + characterBlockWidth))
        let transitionRight: CGFloat = 0.0
        let headingLeft: CGFloat    = 0.0
        let headingRight: CGFloat   = 0.0

        let body = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.black
        ]

        func style(_ left: CGFloat, _ right: CGFloat, align: NSTextAlignment = .left, spaceBefore: CGFloat = 0, spaceAfter: CGFloat = 6) -> [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.alignment = align
            style.firstLineHeadIndent = left
            style.headIndent = left
            style.tailIndent = -(right)
            style.paragraphSpacingBefore = spaceBefore
            style.paragraphSpacing = spaceAfter
            style.lineBreakMode = .byWordWrapping
            return baseAttrs.merging([.paragraphStyle: style]) { _, new in new }
        }

        let firstNonEmptyIndex: Int = {
            for (i, para) in paras.enumerated() {
                if !para.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return i }
            }
            return 0
        }()

        func cleanTextAndStrikeRanges(_ s: String) -> (String, [NSRange]) {
            let startMarker: Character = "\u{F001}"
            let endMarker: Character = "\u{F002}"
            var clean = ""
            var ranges: [NSRange] = []
            var inStrike = false
            var strikeStartOut = 0
            var outIndex = 0
            for ch in s {
                if ch == startMarker {
                    if !inStrike { inStrike = true; strikeStartOut = outIndex }
                    continue
                }
                if ch == endMarker {
                    if inStrike {
                        inStrike = false
                        let length = outIndex - strikeStartOut
                        if length > 0 { ranges.append(NSRange(location: strikeStartOut, length: length)) }
                    }
                    continue
                }
                clean.append(ch)
                outIndex += 1
            }
            if inStrike {
                let length = outIndex - strikeStartOut
                if length > 0 { ranges.append(NSRange(location: strikeStartOut, length: length)) }
            }
            return (clean, ranges)
        }

        for i in firstNonEmptyIndex..<paras.count {
            let p = paras[i]
            let t = p.text
            let lower = p.type
            let isFirst = (i == firstNonEmptyIndex)
            let attrs: [NSAttributedString.Key: Any]
            if lower.contains("scene heading") {
                attrs = style(headingLeft, headingRight, align: .left, spaceBefore: isFirst ? 0 : 6, spaceAfter: 6)
            } else if lower.contains("character") {
                attrs = style(characterLeft, characterRight, align: .center, spaceBefore: isFirst ? 0 : 6, spaceAfter: 0)
            } else if lower.contains("parenthetical") {
                attrs = style(parenthLeft, parenthRight, align: .left, spaceBefore: 0, spaceAfter: 0)
            } else if lower.contains("dialogue") {
                attrs = style(dialogueLeft, dialogueRight, align: .left, spaceBefore: 0, spaceAfter: 6)
            } else if lower.contains("transition") {
                attrs = style(actionLeft, transitionRight, align: .right, spaceBefore: isFirst ? 0 : 6, spaceAfter: 6)
            } else {
                attrs = style(actionLeft, actionRight, align: .left, spaceBefore: isFirst ? 0 : 6, spaceAfter: 6)
            }
            let (clean, strikeRanges) = cleanTextAndStrikeRanges(t)
            let rendered = NSMutableAttributedString(string: clean + "\n", attributes: attrs)
            if !strikeRanges.isEmpty {
                let strikeAttrs: [NSAttributedString.Key: Any] = [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: NSColor.systemPink
                ]
                for r in strikeRanges where NSMaxRange(r) <= rendered.length {
                    rendered.addAttributes(strikeAttrs, range: r)
                }
            }
            body.append(rendered)
        }
        return body
    }

    private struct AttributedTextView: NSViewRepresentable {
        let text: NSAttributedString
        let contentWidth: CGFloat
        let contentHeight: CGFloat
        func makeNSView(context: Context) -> NSTextView {
            let tv = NSTextView(frame: .init(x: 0, y: 0, width: contentWidth, height: contentHeight))
            tv.isEditable = false
            tv.isSelectable = true
            tv.drawsBackground = false
            tv.isVerticallyResizable = false
            tv.isHorizontallyResizable = false
            tv.textContainerInset = NSSize(width: 0, height: 0)
            tv.textContainer?.lineFragmentPadding = 0
            tv.textContainer?.widthTracksTextView = true
            tv.textContainer?.containerSize = NSSize(width: contentWidth, height: contentHeight)
            tv.textStorage?.setAttributedString(text)
            return tv
        }
        func updateNSView(_ nsView: NSTextView, context: Context) {
            nsView.setFrameSize(.init(width: contentWidth, height: contentHeight))
            nsView.textContainer?.containerSize = NSSize(width: contentWidth, height: contentHeight)
            nsView.textStorage?.setAttributedString(text)
        }
    }

    private final class TextKitPaginator {
        static func paginate(
            attributedText: NSAttributedString,
            contentSize: CGSize,
            lastPageFraction: CGFloat
        ) -> [NSAttributedString] {
            let storage = NSTextStorage(attributedString: attributedText)
            let layout = NSLayoutManager()
            storage.addLayoutManager(layout)

            func makeContainer(height: CGFloat) -> NSTextContainer {
                let container = NSTextContainer(size: CGSize(width: contentSize.width, height: height))
                container.lineFragmentPadding = 0
                layout.addTextContainer(container)
                return container
            }

            var pages: [NSAttributedString] = []
            let fullHeight = contentSize.height

            while true {
                let container = makeContainer(height: fullHeight)
                layout.ensureLayout(for: container)
                let glyphRange = layout.glyphRange(for: container)
                let charRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                if charRange.length == 0 {
                    layout.removeTextContainer(at: layout.textContainers.count - 1)
                    break
                }
                let sub = storage.attributedSubstring(from: charRange)
                pages.append(sub)

                let end = charRange.location + charRange.length
                if end >= storage.length { break }
            }

            if pages.count >= 2, lastPageFraction > 0, lastPageFraction < 1 {
                let last = pages.removeLast()
                let lastStorage = NSTextStorage(attributedString: last)
                let lastLayout = NSLayoutManager()
                lastStorage.addLayoutManager(lastLayout)

                let fracHeight = max(24, contentSize.height * lastPageFraction + 12)
                let fracContainer = NSTextContainer(size: CGSize(width: contentSize.width, height: fracHeight))
                fracContainer.lineFragmentPadding = 0
                lastLayout.addTextContainer(fracContainer)
                lastLayout.ensureLayout(for: fracContainer)

                let glyphRange = lastLayout.glyphRange(for: fracContainer)
                let charRange = lastLayout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                let clipped = lastStorage.attributedSubstring(from: charRange)
                pages.append(clipped)
            }

            return pages
        }
    }
    #endif

    private func plainTextFromFDXParas(_ paras: [FDXPara]) -> String {
        paras.map { $0.text }.joined(separator: "\n")
    }

    @ViewBuilder
    private func scriptFDXPagesView(_ fdxXML: String, pageEighths: Int, startingPageNumber: Int) -> some View {
        #if os(macOS)
        // ✨ ENHANCED RENDERER - Now with professional features:
        // • Bold, Italic, Underline text styles
        // • Revision marks with colored highlighting
        // • Optional script headers
        // • Raw XML display mode
        // • Sequential page numbering
        // • Highlight Element tagging support
        EnhancedFDXScriptView(
            fdxXML: fdxXML,
            pageEighths: pageEighths,
            showRevisionMarks: true,       // Show colored revision highlights
            showSceneNumbers: false,        // Scene numbers hidden in margins
            includeHeader: false,           // Set true to show script title/date on first page
            showRawXML: showRawXML,         // Toggle between formatted and raw XML
            startingPageNumber: startingPageNumber,  // Sequential page number from script
            sceneID: selectedScene?.objectID.uriRepresentation().absoluteString  // Scene identifier for highlight tagging
        )
        #else
        let plain = plainTextFromFDXParas(parseFDXParagraphs(fdxXML))
        scriptPageView(plain)
        #endif
    }

    private func injectSceneNumber(into fdxXML: String, scene: SceneEntity?) -> String {
        guard let scene = scene else {
            print("⚠️ injectSceneNumber: No scene provided")
            return fdxXML
        }

        // Debug: print available attributes
        print("🔍 Scene attributes available: \(scene.entity.attributesByName.keys.sorted())")

        // Get the scene number from the database
        let sceneNumberKeys = ["number", "sceneNumber", "numberRaw"]
        var sceneNumber: String? = nil
        for key in sceneNumberKeys {
            if scene.entity.attributesByName.keys.contains(key) {
                let value = scene.value(forKey: key)
                print("🔍 Checking key '\(key)': \(String(describing: value))")
                if let num = value as? String, !num.isEmpty {
                    sceneNumber = num
                    print("✅ Found scene number: '\(num)' from key '\(key)'")
                    break
                } else if let num = value as? Int {
                    sceneNumber = "\(num)"
                    print("✅ Found scene number: '\(num)' from key '\(key)'")
                    break
                }
            }
        }

        guard let number = sceneNumber, !number.isEmpty else {
            print("⚠️ No scene number found in database")
            return fdxXML
        }

        print("📝 Injecting scene number '\(number)' into FDX XML")

        // Inject the scene number into the first <Paragraph> tag if it's a Scene Heading
        // Look for the first Paragraph tag that is a Scene Heading
        let pattern = #"(<Paragraph[^>]*Type="[^"]*Scene Heading[^"]*"[^>]*?)(>)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(fdxXML.startIndex..<fdxXML.endIndex, in: fdxXML)
            if let match = regex.firstMatch(in: fdxXML, options: [], range: range) {
                let matchRange = match.range
                if let swiftRange = Range(matchRange, in: fdxXML) {
                    let originalTag = String(fdxXML[swiftRange])
                    print("🔍 Found Paragraph tag: \(originalTag)")
                    // Check if Number attribute already exists
                    if !originalTag.contains("Number=\"") {
                        // Insert Number attribute before the closing >
                        let modifiedTag = originalTag.replacingOccurrences(of: ">", with: " Number=\"\(number)\">")
                        print("✅ Modified tag to: \(modifiedTag)")
                        return fdxXML.replacingCharacters(in: swiftRange, with: modifiedTag)
                    } else {
                        print("⚠️ Number attribute already exists in tag")
                    }
                }
            } else {
                print("⚠️ No Scene Heading Paragraph found in XML")
            }
        }

        return fdxXML
    }

    private func getPageNumber(_ scene: SceneEntity?) -> Int {
        guard let scene = scene else {
            print("⚠️ getPageNumber: No scene provided, defaulting to 1")
            return 1
        }

        // Try various page number attribute names
        let pageNumKeys = ["pageNumber", "page", "scriptPage", "startPage"]
        for key in pageNumKeys {
            if scene.entity.attributesByName.keys.contains(key) {
                let value = scene.value(forKey: key)
                print("🔍 getPageNumber - Checking key '\(key)': \(String(describing: value))")
                if let pageStr = value as? String,
                   let pageNum = Int(pageStr) {
                    print("✅ Found page number: \(pageNum) from key '\(key)'")
                    return pageNum
                } else if let pageNum = value as? Int {
                    print("✅ Found page number: \(pageNum) from key '\(key)'")
                    return pageNum
                }
            }
        }

        // Default to 1 if no page number found
        print("⚠️ No page number found in database, defaulting to 1")
        return 1
    }

    @ViewBuilder
    private func scriptPageView(_ text: String) -> some View {
        #if os(macOS)
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        #else
        let pageWidth: CGFloat = 560
        let pageHeight: CGFloat = 560 * (11.0/8.5)
        #endif

        // Parse text into screenplay elements
        let elements = parseScriptText(text)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                        formattedElementView(element, pageWidth: pageWidth)
                    }
                }
                .frame(width: pageWidth - 108 - 72, alignment: .topLeading)
                .padding(.init(top: 72, leading: 108, bottom: 72, trailing: 72))
            }
        }
        .frame(width: pageWidth, height: pageHeight)
    }

    // MARK: - Script Text Parser

    private enum ParsedElementType {
        case sceneHeading
        case action
        case character
        case parenthetical
        case dialogue
        case transition
        case shot
        case general
    }

    private struct ParsedElement {
        let type: ParsedElementType
        let text: String
    }

    private func parseScriptText(_ text: String) -> [ParsedElement] {
        var elements: [ParsedElement] = []
        let lines = text.components(separatedBy: .newlines)
        var currentType: ParsedElementType = .action
        var currentText = ""
        var previousType: ParsedElementType = .action

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines but finalize current element
            if trimmed.isEmpty {
                if !currentText.isEmpty {
                    elements.append(ParsedElement(type: currentType, text: currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    previousType = currentType
                    currentText = ""
                }
                continue
            }

            // Detect element type based on content patterns
            let detectedType = detectElementType(trimmed, previousType: previousType)

            // If type changed, finalize previous element
            if detectedType != currentType && !currentText.isEmpty {
                elements.append(ParsedElement(type: currentType, text: currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                previousType = currentType
                currentText = ""
            }

            currentType = detectedType

            // Append line to current element
            if currentText.isEmpty {
                currentText = trimmed
            } else {
                currentText += "\n" + trimmed
            }
        }

        // Finalize last element
        if !currentText.isEmpty {
            elements.append(ParsedElement(type: currentType, text: currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return elements
    }

    private func detectElementType(_ line: String, previousType: ParsedElementType) -> ParsedElementType {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let upper = trimmed.uppercased()

        // Scene Heading patterns: INT., EXT., INT/EXT, I/E
        if upper.hasPrefix("INT.") || upper.hasPrefix("EXT.") ||
           upper.hasPrefix("INT/EXT") || upper.hasPrefix("I/E") ||
           upper.hasPrefix("INT -") || upper.hasPrefix("EXT -") {
            return .sceneHeading
        }

        // Transition patterns: CUT TO:, FADE TO:, DISSOLVE TO:, FADE OUT, FADE IN, etc.
        if upper.hasSuffix("TO:") || upper.hasSuffix("TO BLACK.") ||
           upper == "FADE OUT." || upper == "FADE IN:" || upper == "FADE IN." ||
           upper == "CUT TO BLACK." || upper == "SMASH CUT:" || upper == "MATCH CUT:" {
            return .transition
        }

        // Shot patterns: ANGLE ON, CLOSE ON, POV, BACK TO SCENE, INSERT, etc.
        let shotPatterns = ["ANGLE ON", "CLOSE ON", "WIDE ON", "TIGHT ON", "POV",
                           "BACK TO SCENE", "BACK TO:", "INSERT", "FLASHBACK",
                           "END FLASHBACK", "INTERCUT", "CONTINUOUS", "LATER",
                           "MOMENTS LATER", "TIME CUT", "SAME TIME", "SAME SCENE",
                           "BLACK SCREEN", "WHITE SCREEN", "TITLE CARD", "INSERT CARD",
                           "SUPER:", "SUPERIMPOSE:", "CHYRON:"]
        for pattern in shotPatterns {
            if upper.hasPrefix(pattern) || upper == pattern {
                return .shot
            }
        }

        // Parenthetical: wrapped in parentheses
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            return .parenthetical
        }

        // Character name patterns: ALL CAPS with possible extension (V.O.), (O.S.), (CONT'D)
        // Must be relatively short (character names are typically 1-3 words)
        let characterPattern = #"^[A-Z][A-Z0-9\s'\.]+(\s*\([A-Z\.\s']+\))?$"#
        if let _ = trimmed.range(of: characterPattern, options: .regularExpression),
           trimmed.count < 40,
           !trimmed.contains(".") || trimmed.contains("(") || trimmed.hasSuffix(".") == false {
            // Additional check: if previous was dialogue and this looks like continuation
            // or if it ends with character extension like (V.O.), (O.S.), (CONT'D)
            let hasExtension = trimmed.contains("(V.O.)") || trimmed.contains("(O.S.)") ||
                              trimmed.contains("(O.C.)") || trimmed.contains("(CONT'D)") ||
                              trimmed.contains("(V.O)") || trimmed.contains("(O.S)")

            // Check if it's all caps and reasonable length for a name
            if trimmed == trimmed.uppercased() && trimmed.count >= 2 {
                // Exclude common action words that might be all caps
                let actionWords = ["THE", "A", "AN", "AND", "BUT", "OR", "HE", "SHE", "IT", "THEY", "WE", "POW!", "BANG!", "BOOM!"]
                if !actionWords.contains(trimmed.replacingOccurrences(of: " ", with: "")) || hasExtension {
                    return .character
                }
            }
        }

        // Dialogue: follows a character name
        if previousType == .character || previousType == .parenthetical {
            // If it starts lowercase or is mixed case, likely dialogue
            if let firstChar = trimmed.first, firstChar.isLowercase || !trimmed.allSatisfy({ $0.isUppercase || $0.isWhitespace || $0.isPunctuation }) {
                return .dialogue
            }
        }

        // Default to action
        return .action
    }

    @ViewBuilder
    private func formattedElementView(_ element: ParsedElement, pageWidth: CGFloat) -> some View {
        let contentWidth = pageWidth - 108 - 72  // Total content width

        switch element.type {
        case .sceneHeading:
            Text(element.text.uppercased())
                .font(.custom("Courier", size: 12).bold())
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

        case .action:
            Text(element.text)
                .font(.custom("Courier", size: 12))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

        case .character:
            Text(element.text.uppercased())
                .font(.custom("Courier", size: 12))
                .foregroundColor(.black)
                .frame(width: contentWidth, alignment: .center)
                .padding(.leading, 72)  // Character name indented from left
                .padding(.top, 12)

        case .parenthetical:
            Text(element.text)
                .font(.custom("Courier", size: 12))
                .foregroundColor(.black)
                .frame(width: contentWidth * 0.5, alignment: .leading)
                .padding(.leading, 60)  // Parenthetical indented less than dialogue

        case .dialogue:
            Text(element.text)
                .font(.custom("Courier", size: 12))
                .foregroundColor(.black)
                .frame(width: contentWidth * 0.6, alignment: .leading)
                .padding(.leading, 36)  // Dialogue indented

        case .transition:
            Text(element.text.uppercased())
                .font(.custom("Courier", size: 12))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 12)

        case .shot:
            Text(element.text.uppercased())
                .font(.custom("Courier", size: 12))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

        case .general:
            Text(element.text)
                .font(.custom("Courier", size: 12))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
    }

    // MARK: - Version Management Functions

    private func selectBreakdownVersion(_ version: BreakdownVersion) {
        selectedVersion = version
        saveBreakdownVersions()
    }

    private func createNewBreakdownVersion(name: String, fromDraft: ScreenplayDraftInfo? = nil) {
        // New versions start empty (sceneCount: 0) - user can then load/import a script
        let newVersion = BreakdownVersion(
            name: name,
            scriptDraftId: fromDraft?.id,
            scriptTitle: fromDraft?.title ?? "",
            sceneCount: 0  // Start with no scenes - user will load/import
        )

        breakdownVersions.append(newVersion)
        selectBreakdownVersion(newVersion)
        saveBreakdownVersions()
    }

    private func renameBreakdownVersion(_ version: BreakdownVersion, to newName: String) {
        if let index = breakdownVersions.firstIndex(where: { $0.id == version.id }) {
            breakdownVersions[index].name = newName
            if selectedVersion?.id == version.id {
                selectedVersion?.name = newName
            }
            saveBreakdownVersions()
        }
    }

    private func deleteBreakdownVersion(_ version: BreakdownVersion) {
        breakdownVersions.removeAll { $0.id == version.id }

        // If we deleted the selected version, select another
        if selectedVersion?.id == version.id {
            if let first = breakdownVersions.first {
                selectBreakdownVersion(first)
            } else {
                // Create a new default version if all were deleted
                let defaultVersion = BreakdownVersion(name: "Breakdown v1.0")
                breakdownVersions = [defaultVersion]
                selectBreakdownVersion(defaultVersion)
            }
        }

        saveBreakdownVersions()
    }

    private func duplicateBreakdownVersion(_ version: BreakdownVersion) {
        let newVersion = version.duplicate()
        breakdownVersions.append(newVersion)
        selectBreakdownVersion(newVersion)
    }

    /// Updates the scene count in the currently selected breakdown version
    private func updateVersionSceneCount() {
        guard let versionId = selectedVersion?.id,
              let index = breakdownVersions.firstIndex(where: { $0.id == versionId }) else { return }

        let count = filteredScenes.count
        breakdownVersions[index].sceneCount = count
        selectedVersion?.sceneCount = count
        saveBreakdownVersions()
    }

    private func saveBreakdownVersions() {
        let ctx = PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        req.fetchLimit = 1

        guard let project = try? ctx.fetch(req).first else { return }

        if let encoded = try? JSONEncoder().encode(breakdownVersions) {
            project.setValue(encoded, forKey: "breakdownVersionsData")
        }
        if let selectedEncoded = try? JSONEncoder().encode(selectedVersion) {
            project.setValue(selectedEncoded, forKey: "selectedBreakdownVersionData")
        }

        do {
            try ctx.save()
        } catch {
            NSLog("❌ Failed to save breakdown versions: \(error)")
        }
    }

    private func loadBreakdownVersions() {
        let ctx = PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        req.fetchLimit = 1

        guard let project = try? ctx.fetch(req).first else { return }

        // Load versions
        if let data = project.value(forKey: "breakdownVersionsData") as? Data,
           let decoded = try? JSONDecoder().decode([BreakdownVersion].self, from: data) {
            breakdownVersions = decoded
        }

        // Load selected version
        if let selectedData = project.value(forKey: "selectedBreakdownVersionData") as? Data,
           let decoded = try? JSONDecoder().decode(BreakdownVersion.self, from: selectedData) {
            selectedVersion = decoded
        }

        // Create default version if none exist
        if breakdownVersions.isEmpty {
            let defaultVersion = BreakdownVersion(name: "Breakdown v1.0")
            breakdownVersions = [defaultVersion]
            selectBreakdownVersion(defaultVersion)
        } else if selectedVersion == nil {
            selectBreakdownVersion(breakdownVersions[0])
        }
    }

    // MARK: - FDX Generation for Script Preview

    /// Generate FDX content from a ScreenplayDocument scene
    private func generateFDXFromScreenplayScene(document: ScreenplayDocument, sceneIndex: Int, sceneNumber: String) -> String {
        var paragraphs: [String] = []

        // Start from the scene heading at sceneIndex
        var currentIndex = sceneIndex

        while currentIndex < document.elements.count {
            let element = document.elements[currentIndex]

            // Stop at the next scene heading (unless it's the first one)
            if currentIndex > sceneIndex && element.type == .sceneHeading {
                break
            }

            let text = escapeXML(element.text)
            let elementType: String

            switch element.type {
            case .sceneHeading:
                elementType = "Scene Heading"
            case .action:
                elementType = "Action"
            case .character:
                elementType = "Character"
            case .dialogue:
                elementType = "Dialogue"
            case .parenthetical:
                elementType = "Parenthetical"
            case .transition:
                elementType = "Transition"
            case .shot:
                elementType = "Shot"
            case .general, .titlePage:
                elementType = "General"
            }

            // Build paragraph with optional scene number for headings
            var paragraph = "<Paragraph Type=\"\(elementType)\""
            if element.type == .sceneHeading, let num = element.sceneNumber ?? (currentIndex == sceneIndex ? sceneNumber : nil) {
                paragraph += " Number=\"\(escapeXML(num))\""
            }
            paragraph += ">\n"
            paragraph += "      <Text>\(text)</Text>\n"
            paragraph += "    </Paragraph>"

            paragraphs.append(paragraph)
            currentIndex += 1
        }

        // Build the full FDX structure
        let fdx = """
<?xml version="1.0" encoding="UTF-8"?>
<FinalDraft DocumentType="Script" Template="No" Version="5">
  <Content>
    \(paragraphs.joined(separator: "\n    "))
  </Content>
</FinalDraft>
"""
        print("[Breakdowns] Generated FDX from ScreenplayDocument scene \(sceneNumber) with \(paragraphs.count) paragraphs")
        return fdx
    }

    /// Generate FDX content from plain text (fallback when no ScreenplayDocument is available)
    private func generateFDXFromPlainText(text: String, heading: String, sceneNumber: String) -> String {
        var paragraphs: [String] = []

        // Add scene heading
        paragraphs.append("""
    <Paragraph Type="Scene Heading" Number="\(escapeXML(sceneNumber))">
      <Text>\(escapeXML(heading))</Text>
    </Paragraph>
""")

        // Parse the text and create appropriate paragraphs
        let lines = text.components(separatedBy: "\n\n")
        var currentCharacter: String? = nil

        for block in lines {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Detect element type based on content patterns
            let elementType: String
            let displayText: String

            // Check if this is a character cue (all caps, short line)
            if isCharacterCue(trimmed) {
                elementType = "Character"
                displayText = trimmed.uppercased()
                currentCharacter = displayText
            }
            // Check if this is a parenthetical
            else if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
                elementType = "Parenthetical"
                displayText = trimmed
            }
            // If we just had a character, this is likely dialogue
            else if currentCharacter != nil {
                elementType = "Dialogue"
                displayText = trimmed
                currentCharacter = nil  // Reset after dialogue
            }
            // Default to action
            else {
                elementType = "Action"
                displayText = trimmed
                currentCharacter = nil
            }

            paragraphs.append("""
    <Paragraph Type="\(elementType)">
      <Text>\(escapeXML(displayText))</Text>
    </Paragraph>
""")
        }

        let fdx = """
<?xml version="1.0" encoding="UTF-8"?>
<FinalDraft DocumentType="Script" Template="No" Version="5">
  <Content>
\(paragraphs.joined(separator: "\n"))
  </Content>
</FinalDraft>
"""
        print("[Breakdowns] Generated FDX from plain text with \(paragraphs.count) paragraphs")
        return fdx
    }

    /// Check if a line is likely a character cue
    private func isCharacterCue(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        // Character cues are typically:
        // - All uppercase (or mostly uppercase)
        // - Short (under 40 characters)
        // - May have (V.O.), (O.S.), (CONT'D), etc.

        guard !trimmed.isEmpty && trimmed.count < 50 else { return false }

        // Remove parenthetical extensions
        var name = trimmed
        if let parenStart = name.firstIndex(of: "(") {
            name = String(name[..<parenStart]).trimmingCharacters(in: .whitespaces)
        }

        // Must have at least 2 characters
        guard name.count >= 2 else { return false }

        // Check if mostly uppercase letters
        let letters = name.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }

        let uppercaseCount = letters.filter { $0.isUppercase }.count
        let ratio = Double(uppercaseCount) / Double(letters.count)

        return ratio > 0.8  // 80% or more uppercase letters
    }

    /// Escape special XML characters
    private func escapeXML(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }
}
