//
//  ScreenplayEditorView.swift
//  Production Runner
//
//  Pages-style screenplay editor with Final Draft formatting.
//  Supports scripts up to 500+ pages with Core Data persistence.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Main Editor View

struct ScreenplayEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataManager = ScreenplayDataManager.shared
    @StateObject private var revisionImporter = FDXRevisionImporter.shared

    // Editor State
    @State private var currentElementType: ScriptElementType = .sceneHeading
    @State private var zoomLevel: CGFloat = 1.2
    @State private var showInspector = true
    @AppStorage("screenplayEditorAppearance") private var editorAppearance: EditorAppearance = .system

    /// Editor appearance mode - independent of system setting
    enum EditorAppearance: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }
    }

    @State private var inspectorTab: InspectorTab = .scenes
    @State private var pageCount: Int = 1
    @State private var wordCount: Int = 0
    @State private var sceneCount: Int = 0
    @State private var sceneHeadingPositions: [(sceneNumber: String, y: CGFloat, height: CGFloat)] = []

    // Revisions Inspector State
    @State private var selectedRevisionId: UUID?
    @State private var showFDXImportSheet = false
    @State private var showSaveRevisionSheet = false
    @State private var selectedRevisionColor: String = "Blue"
    @State private var revisionNotes: String = ""
    @State private var showDeleteConfirmation = false
    @State private var revisionToDelete: UUID?
    @State private var revisionColorToDelete: String?
    @State private var showRevisionSwitchAlert = false
    @State private var pendingRevisionColor: RevisionColor?

    // Script State
    @State private var sceneNumberPosition: SceneNumberPosition = .none
    // Lock state is now persisted in the document (currentDocument?.isLocked)
    @State private var currentRevision: RevisionColor = .white
    @State private var selectedSceneIndex: Int? = nil // For locked-mode operations (from inspector)
    @State private var currentSceneElementIndex: Int? = nil // Scene element index from cursor position
    @State private var forceDocumentReload: UUID = UUID() // Trigger to force editor reload

    // Export State
    @State private var showExportPDFSheet = false
    @State private var exportOptions = ScreenplayExportOptions()
    @State private var showScriptSidesSheet = false

    /// Computed property for script lock state (persisted in document)
    private var isScriptLocked: Bool {
        currentDocument?.isLocked ?? false
    }
    @State private var scrollToElementIndex: Int? = nil // For jumping to scene from inspector

    // Industry Standard Revision Colors
    enum RevisionColor: String, CaseIterable, Identifiable {
        case white = "White"
        case blue = "Blue"
        case pink = "Pink"
        case yellow = "Yellow"
        case green = "Green"
        case goldenrod = "Goldenrod"
        case buff = "Buff"
        case salmon = "Salmon"
        case cherry = "Cherry"
        case tan = "Tan"
        case gray = "Gray"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .white: return Color(red: 1.0, green: 1.0, blue: 1.0)
            case .blue: return Color(red: 0.68, green: 0.85, blue: 0.90)
            case .pink: return Color(red: 1.0, green: 0.75, blue: 0.80)
            case .yellow: return Color(red: 1.0, green: 1.0, blue: 0.60)
            case .green: return Color(red: 0.60, green: 0.98, blue: 0.60)
            case .goldenrod: return Color(red: 0.93, green: 0.79, blue: 0.45)
            case .buff: return Color(red: 0.94, green: 0.86, blue: 0.70)
            case .salmon: return Color(red: 1.0, green: 0.63, blue: 0.48)
            case .cherry: return Color(red: 0.87, green: 0.44, blue: 0.63)
            case .tan: return Color(red: 0.82, green: 0.71, blue: 0.55)
            case .gray: return Color(red: 0.83, green: 0.83, blue: 0.83)
            }
        }

        var textColor: Color {
            switch self {
            case .cherry: return .white
            default: return .black
            }
        }

        var revisionNumber: Int {
            switch self {
            case .white: return 0
            case .blue: return 1
            case .pink: return 2
            case .yellow: return 3
            case .green: return 4
            case .goldenrod: return 5
            case .buff: return 6
            case .salmon: return 7
            case .cherry: return 8
            case .tan: return 9
            case .gray: return 10
            }
        }

        var displayName: String {
            if self == .white {
                return "Original"
            }
            return "\(rawValue) Revision"
        }
    }

    // Document State
    @State private var showWelcomeSheet = false
    @State private var showRenameSheet = false
    @State private var renameText: String = ""
    @State private var selectedDraftId: UUID?
    @State private var currentDocument: ScreenplayDocument?
    @State private var hasAppeared = false

    // Persist the last opened document ID so it survives view recreation (switching apps)
    @AppStorage("screenplay_lastOpenedDocumentId") private var lastOpenedDocumentId: String = ""

    // Track if welcome sheet has been shown this app session (not persisted across launches)
    private static var welcomeShownThisSession = false

    // Comments
    @State private var comments: [ScriptComment] = []
    @State private var showNewCommentSheet = false
    @State private var selectedText: String = ""
    @State private var selectedRange: NSRange?
    @State private var scrollToCommentId: UUID? = nil

    enum InspectorTab: String, CaseIterable {
        case scenes = "Scenes"
        case comments = "Comments"
        case revisions = "Revisions"
    }

    // Left Inspector Tab options
    enum LeftInspectorTab: String, CaseIterable {
        case storyNotes = "Notes"
        case beatBoard = "Beats"
    }

    // Left Inspector State
    @State private var showLeftInspector = true
    @State private var leftInspectorTab: LeftInspectorTab = .storyNotes
    @State private var noteSections: [NoteSection] = []  // Structured story notes
    @State private var collapsedSectionIds: Set<UUID> = []  // Track collapsed sections
    @State private var selectedNoteColor: Color = .primary  // Current font color for notes

    // Note Section model for collapsible ACT/BEAT sections
    struct NoteSection: Identifiable, Equatable {
        let id: UUID
        var sectionType: NoteSectionType
        var title: String
        var content: String
        var colorIndex: Int  // Index into noteColors array

        init(id: UUID = UUID(), sectionType: NoteSectionType, title: String = "", content: String = "", colorIndex: Int = 1) {
            self.id = id
            self.sectionType = sectionType
            self.title = title
            self.content = content
            self.colorIndex = colorIndex  // Default to blue (index 1)
        }

        static func == (lhs: NoteSection, rhs: NoteSection) -> Bool {
            lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.content == rhs.content &&
            lhs.colorIndex == rhs.colorIndex &&
            lhs.sectionType == rhs.sectionType
        }

        enum NoteSectionType: String {
            case act = "ACT"
            case beat = "BEAT"
            case freeform = "NOTES"

            var icon: String {
                switch self {
                case .act: return "theatermasks"
                case .beat: return "music.note"
                case .freeform: return "note.text"
                }
            }
        }
    }

    // Available note section colors
    static let noteColors: [(name: String, color: Color)] = [
        ("Purple", .purple),
        ("Blue", .blue),
        ("Cyan", .cyan),
        ("Green", .green),
        ("Yellow", .yellow),
        ("Orange", .orange),
        ("Red", .red),
        ("Pink", .pink),
        ("Gray", .gray)
    ]

    // Dragging state for note sections
    @State private var draggingNoteSection: NoteSection?

    // Beat Board State
    @State private var beats: [BeatCard] = []
    @State private var draggingBeat: BeatCard?  // For drag and drop reordering
    @State private var beatViewColumns: Int = 2  // 1 or 2 columns

    /// Computed grid columns based on beatViewColumns state
    private var beatGridColumns: [GridItem] {
        if beatViewColumns == 1 {
            return [GridItem(.flexible())]
        } else {
            return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        }
    }

    // Beat Card model
    struct BeatCard: Identifiable, Equatable {
        let id: UUID
        var title: String
        var text: String
        var colorIndex: Int  // Index into beatColors array

        init(id: UUID = UUID(), title: String = "", text: String = "", colorIndex: Int = 1) {
            self.id = id
            self.title = title
            self.text = text
            self.colorIndex = colorIndex  // Default to blue (index 1)
        }

        static func == (lhs: BeatCard, rhs: BeatCard) -> Bool {
            lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.text == rhs.text &&
            lhs.colorIndex == rhs.colorIndex
        }
    }

    // Available beat colors
    static let beatColors: [(name: String, color: Color)] = [
        ("Purple", .purple),
        ("Blue", .blue),
        ("Cyan", .cyan),
        ("Green", .green),
        ("Yellow", .yellow),
        ("Orange", .orange),
        ("Red", .red),
        ("Pink", .pink),
        ("Gray", .gray)
    ]

    // Comment model
    struct ScriptComment: Identifiable {
        let id: UUID
        var taggedText: String
        var note: String
        var createdAt: Date
        var elementIndex: Int?

        init(id: UUID = UUID(), taggedText: String, note: String, elementIndex: Int? = nil) {
            self.id = id
            self.taggedText = taggedText
            self.note = note
            self.createdAt = Date()
            self.elementIndex = elementIndex
        }
    }

    var body: some View {
        #if os(macOS)
        Group {
            if dataManager.isLoading {
                // Loading indicator
                ProgressView("Loading script...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if currentDocument != nil {
                // Editor view when document is loaded
                editorContent
            } else {
                // Placeholder when no document
                noDocumentView
            }
        }
        .onAppear {
            print("[Screenplay DEBUG] onAppear - hasAppeared: \(hasAppeared), welcomeShownThisSession: \(Self.welcomeShownThisSession)")
            dataManager.configure(with: viewContext)
            revisionImporter.configure(with: viewContext)

            // Always try to restore the last opened document when view appears
            if currentDocument == nil && !lastOpenedDocumentId.isEmpty {
                if let uuid = UUID(uuidString: lastOpenedDocumentId) {
                    print("[Screenplay DEBUG] Restoring last opened document: \(lastOpenedDocumentId)")
                    loadDocument(id: uuid)
                }
            }

            if !hasAppeared {
                hasAppeared = true
                print("[Screenplay DEBUG] Configured dataManager, hasDrafts: \(dataManager.hasDrafts), drafts count: \(dataManager.drafts.count)")

                // Only show welcome sheet on first app launch, not when switching apps
                // Show if: no drafts exist OR (no current document AND haven't shown yet this session)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("[Screenplay DEBUG] After delay - hasDrafts: \(dataManager.hasDrafts), currentDocument: \(currentDocument != nil), welcomeShown: \(Self.welcomeShownThisSession)")
                    if !dataManager.hasDrafts {
                        // First time user - always show welcome sheet
                        print("[Screenplay DEBUG] No drafts - showing welcome sheet")
                        showWelcomeSheet = true
                        Self.welcomeShownThisSession = true
                    } else if currentDocument == nil && !Self.welcomeShownThisSession {
                        // Has drafts but nothing loaded - show once per session
                        print("[Screenplay DEBUG] Has drafts but no doc loaded - showing welcome sheet")
                        showWelcomeSheet = true
                        Self.welcomeShownThisSession = true
                    } else {
                        print("[Screenplay DEBUG] Not showing welcome sheet - already shown or doc loaded")
                    }
                }
            }
        }
        .onChange(of: selectedDraftId) { newId in
            if let id = newId {
                loadDocument(id: id)
            }
            // NOTE: We no longer clear document state when selectedDraftId becomes nil
            // This prevents the document from closing when switching apps or when SwiftUI
            // recreates the view. Document closure is now only done explicitly via closeCurrentDocument()
        }
        .sheet(isPresented: $showWelcomeSheet) {
            ScreenplayWelcomeSheet(
                selectedDraftId: $selectedDraftId,
                dataManager: dataManager
            )
        }
        .sheet(isPresented: $showRenameSheet) {
            renameScriptSheet
        }
        .sheet(isPresented: $showExportPDFSheet) {
            exportPDFSheet
        }
        .sheet(isPresented: $showScriptSidesSheet) {
            if let doc = currentDocument {
                ScriptSidesView(document: doc)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
            performDeleteCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
            performSelectAllCommand()
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
        #else
        Text("Screenplay Editor requires macOS")
            .foregroundColor(.secondary)
        #endif
    }

    // MARK: - Global Keyboard Shortcut Handlers
    #if os(macOS)
    private func performDeleteCommand() {
        // Check if text field has focus - let system handle delete
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text delete
            }
        }
        // No-op - text editing uses system delete
    }

    private func performSelectAllCommand() {
        // Check if text field has focus - let system handle select all
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text select all
            }
        }
        // No-op - text editing uses system select all
    }

    private func performCutCommand() {
        // Check if text field has focus - let system handle cut
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text cut
            }
        }
        // No-op - text editing uses system cut
    }

    private func performCopyCommand() {
        // Check if text field has focus - let system handle copy
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text copy
            }
        }
        // No-op - text editing uses system copy
    }

    private func performPasteCommand() {
        // Check if text field has focus - let system handle paste
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text paste
            }
        }
        // No-op - text editing uses system paste
    }
    #endif

    #if os(macOS)
    private var editorContent: some View {
        VStack(spacing: 0) {
            // Custom toolbar at top
            screenplayToolbar

            Divider()

            // Main content with inspectors
            HStack(spacing: 0) {
                // Left Inspector Pane (collapsible)
                if showLeftInspector {
                    leftInspectorPanel

                    Divider()
                }

                // Main content area
                mainContentArea
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Right Inspector Pane (collapsible)
                if showInspector {
                    Divider()

                    inspectorPanel
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showLeftInspector)
            .animation(.easeInOut(duration: 0.2), value: showInspector)

            Divider()

            // Bottom toolbar with stats and zoom
            bottomToolbar
        }
    }

    @ViewBuilder
    private var mainContentArea: some View {
        ZStack(alignment: .topTrailing) {
            editorCanvas

            // Comment icons overlay in right margin
            commentIconsOverlay
        }
    }

    /// Overlay showing comment icons in the right margin for elements with comments
    private var commentIconsOverlay: some View {
        GeometryReader { geometry in
            let rightMarginX: CGFloat = 20  // Position from right edge

            ForEach(comments.filter { $0.elementIndex != nil }) { comment in
                if let elementIndex = comment.elementIndex,
                   let doc = currentDocument,
                   elementIndex < doc.elements.count {
                    let yPosition = calculateElementY(at: elementIndex, in: doc) * zoomLevel

                    Button(action: {
                        // Switch to Comments tab and scroll to this comment
                        inspectorTab = .comments
                        showInspector = true
                        scrollToCommentId = comment.id
                    }) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                    .customTooltip("View comment: \(comment.note.prefix(50))...")
                    .position(x: geometry.size.width - rightMarginX, y: yPosition + 10)
                }
            }
        }
        .allowsHitTesting(true)
    }

    private var noDocumentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Script Open")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary)

            Text("Create a new screenplay or import an existing one")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))

            Button(action: { showWelcomeSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Get Started")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func loadDocument(id: UUID) {
        print("[Screenplay DEBUG] loadDocument called with id: \(id)")
        if let document = dataManager.loadDocument(id: id) {
            print("[Screenplay DEBUG] Document loaded: '\(document.title)' with \(document.elements.count) elements")
            currentDocument = document
            selectedDraftId = id
            lastOpenedDocumentId = id.uuidString  // Persist for app switching
            pageCount = document.estimatedPageCount
            sceneCount = document.scenes.count
            wordCount = document.elements.reduce(0) { $0 + $1.text.split(separator: " ").count }

            // Restore revision state from document
            if let revColorName = document.currentRevisionColor,
               let revColor = RevisionColor(rawValue: revColorName) {
                print("[Screenplay DEBUG] Restoring revision color: \(revColorName)")
                currentRevision = revColor
            } else {
                // No saved revision color, default to white
                currentRevision = .white
            }
        } else {
            print("[Screenplay DEBUG] Failed to load document with id: \(id)")
        }
    }

    /// Explicitly close the current document - clears all state and persisted ID
    private func closeCurrentDocument() {
        print("[Screenplay DEBUG] closeCurrentDocument called - explicitly closing document")
        currentDocument = nil
        selectedDraftId = nil
        lastOpenedDocumentId = ""  // Clear persisted ID when explicitly closing

        // Reset editor state to defaults
        pageCount = 1
        wordCount = 0
        sceneCount = 0
        sceneHeadingPositions = []
        comments = []
        selectedRevisionId = nil
        currentRevision = .white
        selectedSceneIndex = nil

        // Reset revision importer state
        revisionImporter.resetState()
    }
    #endif

    // MARK: - Custom Toolbar

    #if os(macOS)
    private var screenplayToolbar: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                toolbarContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)

                Divider()
            }
            .frame(height: geometry.size.height)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(height: NSScreen.main.map { $0.frame.height * 0.05 } ?? 44)
    }

    private var toolbarContent: some View {
        HStack(spacing: 12) {
            // Left section: Left Inspector toggle
            leftInspectorToggleButton

            Spacer()

            // Center section: Main controls
            HStack(spacing: 10) {
                // Script/File menu
                scriptFileMenu

                Divider().frame(height: 32)

                // Element selector dropdown
                scriptElementMenu

                Divider().frame(height: 32)

                // Quick element buttons
                quickElementButtons

                Divider().frame(height: 32)

                // Locked script button (before numbering)
                lockedScriptButton

                // Scene numbering button
                sceneNumberingMenu

                // Omit scene button (always visible)
                omitSceneButton

                Divider().frame(height: 32)

                // Revision color button
                revisionColorButton
            }
            .fixedSize()

            Spacer()

            // Right section: Inspector toggle
            inspectorToggleButton
        }
    }

    // MARK: - Scene Numbering Menu

    private var sceneNumberingMenu: some View {
        Menu {
            // Position options
            Text("Position")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach([SceneNumberPosition.left, .right, .both], id: \.self) { position in
                Button(action: {
                    sceneNumberPosition = position
                    numberAllScenes()
                }) {
                    HStack {
                        Text(position.rawValue)
                        if sceneNumberPosition == position {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Button(action: {
                sceneNumberPosition = .none
                removeSceneNumbers()
            }) {
                HStack {
                    Text("None")
                    if sceneNumberPosition == .none {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Re-number option - assigns fresh sequential numbers, removing any letter suffixes/prefixes
            Button(action: {
                renumberAllScenes()
            }) {
                Label("Re-number Scenes", systemImage: "arrow.clockwise")
            }
            .disabled(currentDocument == nil)
            .customTooltip("Re-assign sequential numbers (1, 2, 3...) to all scenes, removing any inserted scene letters (A, B, etc.)")

        } label: {
            VStack(spacing: 2) {
                Image(systemName: sceneNumberPosition.isEnabled ? "number.circle.fill" : "number.circle")
                    .font(.system(size: 20, weight: .medium))
                Text("Numbers")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(sceneNumberPosition.isEnabled ? .white : .secondary)
            .frame(width: 56, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(sceneNumberPosition.isEnabled ? Color.accentColor : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(sceneNumberPosition.isEnabled ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .customTooltip("Scene Numbering Options")
    }

    // MARK: - Locked Script Button

    private var lockedScriptButton: some View {
        Button(action: {
            toggleScriptLock()
        }) {
            VStack(spacing: 2) {
                Image(systemName: isScriptLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 18, weight: .medium))
                Text(isScriptLocked ? "Locked" : "Lock")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(isScriptLocked ? .white : .secondary)
            .frame(width: 56, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isScriptLocked ? Color.orange : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isScriptLocked ? Color.orange.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .customTooltip(isScriptLocked ? Tooltips.ScreenplayEditor.unlockScript : Tooltips.ScreenplayEditor.lockScript)
    }

    /// Toggle the script lock state and persist it
    private func toggleScriptLock() {
        guard var doc = currentDocument else { return }

        if doc.isLocked {
            // Unlocking
            doc.isLocked = false
            doc.lockedAt = nil
        } else {
            // Locking - freeze scene numbers
            doc.isLocked = true
            doc.lockedAt = Date()

            // Ensure all scenes have scene numbers before locking
            assignSceneNumbersIfNeeded(&doc)
        }

        currentDocument = doc
        dataManager.saveDocumentAsync(doc)
    }

    /// Assign sequential scene numbers to any scenes that don't have them
    private func assignSceneNumbersIfNeeded(_ doc: inout ScreenplayDocument) {
        var sceneNumber = 1
        for i in 0..<doc.elements.count {
            if doc.elements[i].type == .sceneHeading {
                if doc.elements[i].sceneNumber == nil || doc.elements[i].sceneNumber?.isEmpty == true {
                    doc.elements[i].sceneNumber = "\(sceneNumber)"
                }
                sceneNumber += 1
            }
        }
    }

    // MARK: - Omit Scene Button (Locked Mode Only)

    /// Check if there's a valid scene to omit (any non-omitted scene in document)
    private var hasSceneToOmit: Bool {
        guard let doc = currentDocument else { return false }
        return doc.elements.contains { $0.type == .sceneHeading && !$0.isOmitted }
    }

    /// Check if there's an omitted scene to restore
    private var hasSceneToRestore: Bool {
        guard let doc = currentDocument else { return false }
        return doc.elements.contains { $0.type == .sceneHeading && $0.isOmitted }
    }

    private var omitSceneButton: some View {
        Menu {
            Button(action: {
                omitSelectedScene()
            }) {
                Label("Omit Current Scene", systemImage: "eye.slash")
            }
            .disabled(!hasSceneToOmit)

            Button(action: {
                restoreOmittedScene()
            }) {
                Label("Restore Omitted Scene", systemImage: "eye")
            }
            .disabled(!hasSceneToRestore)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 18, weight: .medium))
                Text("Omit")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: 56, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .customTooltip("Omit or restore the scene at cursor position")
    }

    // MARK: - Insert Scene Menu (Locked Mode Only)

    private var insertSceneButton: some View {
        Menu {
            Button(action: {
                insertSceneBeforeSelected()
            }) {
                Label("Insert Before (A12, B12...)", systemImage: "arrow.up.doc")
            }

            Button(action: {
                insertSceneAfterSelected()
            }) {
                Label("Insert After (12A, 12B...)", systemImage: "arrow.down.doc")
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 18, weight: .medium))
                Text("Insert")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: 56, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(selectedSceneIndex == nil || !sceneNumberPosition.isEnabled)
        .customTooltip("Insert a new scene before or after selected scene")
    }

    // MARK: - Revision Color Button

    private var revisionColorButton: some View {
        Menu {
            // Revision color selection section
            Section {
                ForEach(RevisionColor.allCases) { revision in
                    Button(action: {
                        setRevisionMode(revision)
                    }) {
                        HStack {
                            Circle()
                                .fill(revision.color)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5)
                                )
                            Text(revision.displayName)
                            if currentRevision == revision {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            // Revision actions section
            Section {
                Button(action: {
                    goToPreviousRevision()
                }) {
                    Label("Previous Revision", systemImage: "arrow.left.circle")
                }
                .disabled(currentRevision == .white)

                Button(action: {
                    advanceToNextRevision()
                }) {
                    Label("Next Revision", systemImage: "arrow.right.circle")
                }
                .disabled(currentRevision == .gray)

                Divider()

                Button(role: .destructive, action: {
                    clearAllRevisions()
                }) {
                    Label("Clear All Revisions", systemImage: "arrow.counterclockwise")
                }
                .disabled(currentRevision == .white)
            }
        } label: {
            VStack(spacing: 2) {
                // Revision icon with color indicator
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "doc.badge.clock")
                        .font(.system(size: 18, weight: .medium))

                    // Color indicator dot
                    Circle()
                        .fill(currentRevision.color)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.3), lineWidth: 0.5)
                        )
                        .offset(x: 3, y: 3)
                }

                Text("Revision")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(currentRevision == .white ? .secondary : currentRevision.textColor)
            .frame(width: 56, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentRevision == .white ? Color.secondary.opacity(0.08) : currentRevision.color.opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(currentRevision != .white ? currentRevision.color.opacity(0.6) : Color.secondary.opacity(0.15), lineWidth: currentRevision != .white ? 1.5 : 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .customTooltip("Revision Color Options")
    }

    /// Set revision mode - prompts user about existing revisions when switching
    private func setRevisionMode(_ revision: RevisionColor) {
        // Don't do anything if selecting the same revision
        guard revision != currentRevision else { return }

        // If switching to white (original), just do it
        if revision == .white {
            currentRevision = revision
            return
        }

        // Check if there are existing revision marks in the document
        let hasExistingRevisions = currentDocument?.revisedElementCount ?? 0 > 0

        if hasExistingRevisions {
            // Show alert asking user what to do with existing revisions
            pendingRevisionColor = revision
            showRevisionSwitchAlert = true
        } else {
            // No existing revisions, just switch and auto-save
            performRevisionSwitch(to: revision, mergeExisting: false)
        }
    }

    /// Perform the actual revision switch after user decision
    private func performRevisionSwitch(to revision: RevisionColor, mergeExisting: Bool) {
        print("[REVISION DEBUG] performRevisionSwitch: revision=\(revision.rawValue), mergeExisting=\(mergeExisting)")

        if mergeExisting {
            // Merge/clear all existing revision marks first
            guard var doc = currentDocument else { return }
            doc.clearAllRevisionMarks()
            currentDocument = doc
            dataManager.saveDocument(doc)
        }

        // Set the new revision color
        print("[REVISION DEBUG] performRevisionSwitch: setting currentRevision to \(revision.rawValue)")
        currentRevision = revision

        // Auto-save a revision snapshot for the new color
        guard var doc = currentDocument else { return }

        // IMPORTANT: Persist the current revision color in the document
        // This ensures it survives app switching and view recreation
        doc.currentRevisionColor = revision == .white ? nil : revision.rawValue
        doc.isRevisionMode = revision != .white

        // Save revision snapshot with the color name
        doc.saveRevisionSnapshot(notes: "\(revision.rawValue) Revision")

        currentDocument = doc
        dataManager.saveDocument(doc)

        // Also save to the stored revisions (FDXRevisionImporter)
        Task {
            let _ = await revisionImporter.createRevisionFromScreenplay(
                document: doc,
                colorName: revision.rawValue,
                notes: nil
            )
        }

        // Force reload the editor to apply text color changes
        print("[REVISION DEBUG] performRevisionSwitch: triggering forceDocumentReload")
        forceDocumentReload = UUID()
    }

    private func goToPreviousRevision() {
        let allCases = RevisionColor.allCases
        if let currentIndex = allCases.firstIndex(of: currentRevision),
           currentIndex > 0 {
            let newRevision = allCases[currentIndex - 1]
            currentRevision = newRevision

            // Save the revision state change
            guard var doc = currentDocument else { return }
            doc.currentRevisionColor = newRevision == .white ? nil : newRevision.rawValue
            doc.isRevisionMode = newRevision != .white
            currentDocument = doc
            dataManager.saveDocumentAsync(doc)
        }
    }

    private func advanceToNextRevision() {
        let allCases = RevisionColor.allCases
        if let currentIndex = allCases.firstIndex(of: currentRevision),
           currentIndex < allCases.count - 1 {
            // Use setRevisionMode to automatically save
            setRevisionMode(allCases[currentIndex + 1])
        }
        // No wrap around - once at the last revision, stay there
    }

    /// Clear all revision marks and reset to original state
    private func clearAllRevisions() {
        guard var doc = currentDocument else { return }

        // Clear all revision marks from elements
        doc.clearAllRevisionMarks()

        // Reset to white (original)
        currentRevision = .white

        // Clear the revision state in document
        doc.currentRevisionColor = nil
        doc.isRevisionMode = false

        // Save the document
        currentDocument = doc
        dataManager.saveDocument(doc)

        // Force reload the editor to apply text color changes (back to original black)
        forceDocumentReload = UUID()
    }

    /// Clear revision marks for a specific color (merge that revision back to original)
    private func clearRevisionMarksForColor(_ colorName: String) {
        guard var doc = currentDocument else { return }

        // Clear revision marks for this specific color
        doc.clearRevisionMarks(forColor: colorName)

        // If we just cleared the current revision color, reset to white
        if colorName == currentRevision.rawValue {
            currentRevision = .white
            doc.currentRevisionColor = nil
            doc.isRevisionMode = false
        }

        // Save the document
        currentDocument = doc
        dataManager.saveDocument(doc)

        // Force reload the editor to apply text color changes (back to original black)
        forceDocumentReload = UUID()
    }

    // MARK: - Scene Numbering Functions

    private func numberAllScenes() {
        guard var doc = currentDocument else { return }

        var sceneNum = 1
        for i in 0..<doc.elements.count {
            if doc.elements[i].type == .sceneHeading {
                doc.elements[i].sceneNumber = "\(sceneNum)"
                sceneNum += 1
            }
        }

        currentDocument = doc
        sceneCount = sceneNum - 1
        dataManager.saveDocumentAsync(doc)
    }

    private func removeSceneNumbers() {
        guard var doc = currentDocument else { return }

        for i in 0..<doc.elements.count {
            if doc.elements[i].type == .sceneHeading {
                doc.elements[i].sceneNumber = nil
            }
        }

        currentDocument = doc
        dataManager.saveDocumentAsync(doc)
    }

    /// Re-number all scenes sequentially (1, 2, 3...), removing any letter suffixes/prefixes from inserted scenes.
    /// This is used when the user wants to "flatten" scene numbers after inserting scenes (2A, 2B become 3, 4, etc.)
    /// Industry standard: After a locked script is unlocked and scenes are finalized, re-numbering assigns fresh numbers.
    private func renumberAllScenes() {
        guard var doc = currentDocument else { return }

        // Count how many scenes have letter suffixes/prefixes (inserted scenes)
        var insertedSceneCount = 0
        for element in doc.elements where element.type == .sceneHeading {
            if let sceneNum = element.sceneNumber, let parsed = SceneNumber(from: sceneNum) {
                if !parsed.isSimple {
                    insertedSceneCount += 1
                }
            }
        }

        print("[Screenplay] Re-numbering scenes - found \(insertedSceneCount) inserted scenes to renumber")

        // Assign fresh sequential numbers to all scenes
        var newSceneNum = 1
        for i in 0..<doc.elements.count {
            if doc.elements[i].type == .sceneHeading && !doc.elements[i].isOmitted {
                doc.elements[i].sceneNumber = "\(newSceneNum)"
                newSceneNum += 1
            }
            // Keep omitted scenes with their original numbers (they're placeholders)
        }

        currentDocument = doc
        sceneCount = newSceneNum - 1
        dataManager.saveDocumentAsync(doc)

        // If we have scene numbering enabled, ensure the position setting is applied
        if sceneNumberPosition != .none {
            // Numbers are already assigned, just need to save
            print("[Screenplay] Re-numbered \(sceneCount) scenes")
        }
    }

    // MARK: - Omit Scene Function

    private func omitSelectedScene() {
        guard var doc = currentDocument else {
            print("[OMIT DEBUG] Guard failed - no document")
            return
        }

        // Use selectedSceneIndex (from inspector) - falls back to first scene if nothing selected
        let sceneHeadingIndex: Int
        if let selected = selectedSceneIndex, selected < doc.elements.count, doc.elements[selected].type == .sceneHeading {
            sceneHeadingIndex = selected
            print("[OMIT DEBUG] Using selectedSceneIndex from inspector: \(selected)")
        } else {
            // Fall back to first scene in document
            if let firstScene = doc.elements.firstIndex(where: { $0.type == .sceneHeading && !$0.isOmitted }) {
                sceneHeadingIndex = firstScene
                print("[OMIT DEBUG] Using first non-omitted scene: \(firstScene)")
            } else {
                print("[OMIT DEBUG] Guard failed - no scenes available to omit")
                return
            }
        }

        guard sceneHeadingIndex < doc.elements.count, doc.elements[sceneHeadingIndex].type == .sceneHeading else {
            print("[OMIT DEBUG] Guard failed - index \(sceneHeadingIndex) is not a scene heading")
            return
        }

        print("[OMIT DEBUG] Omitting scene starting at element index: \(sceneHeadingIndex)")

        // Find the end of this scene (next scene heading or end of document)
        var endIndex = sceneHeadingIndex + 1
        while endIndex < doc.elements.count && doc.elements[endIndex].type != .sceneHeading {
            endIndex += 1
        }

        print("[OMIT DEBUG] Scene spans elements \(sceneHeadingIndex) to \(endIndex - 1)")

        // Mark the scene heading and ALL elements in this scene as omitted
        for i in sceneHeadingIndex..<endIndex {
            // Store original text before omitting (for revision tracking)
            if doc.isRevisionMode && doc.elements[i].originalText == nil {
                doc.elements[i].originalText = doc.elements[i].text
            }

            // Mark as omitted
            doc.elements[i].isOmitted = true

            // Mark with revision color if in revision mode
            if doc.isRevisionMode, let color = doc.currentRevisionColor {
                doc.elements[i].revisionColor = color
                doc.elements[i].revisionID = doc.currentRevisionID
            }
        }

        doc.updatedAt = Date()

        currentDocument = doc
        dataManager.saveDocumentAsync(doc)

        // Force reload to update the display
        forceDocumentReload = UUID()
        print("[OMIT DEBUG] Scene omitted successfully - \(endIndex - sceneHeadingIndex) elements hidden")
    }

    private func restoreOmittedScene() {
        guard var doc = currentDocument else {
            print("[RESTORE DEBUG] Guard failed - no document")
            return
        }

        // Use selectedSceneIndex (from inspector) - falls back to first omitted scene if nothing selected
        let sceneHeadingIndex: Int
        if let selected = selectedSceneIndex, selected < doc.elements.count, doc.elements[selected].type == .sceneHeading {
            sceneHeadingIndex = selected
            print("[RESTORE DEBUG] Using selectedSceneIndex from inspector: \(selected)")
        } else {
            // Fall back to first omitted scene in document
            if let firstOmitted = doc.elements.firstIndex(where: { $0.type == .sceneHeading && $0.isOmitted }) {
                sceneHeadingIndex = firstOmitted
                print("[RESTORE DEBUG] Using first omitted scene: \(firstOmitted)")
            } else {
                print("[RESTORE DEBUG] Guard failed - no omitted scenes to restore")
                return
            }
        }

        guard sceneHeadingIndex < doc.elements.count, doc.elements[sceneHeadingIndex].type == .sceneHeading else {
            print("[RESTORE DEBUG] Guard failed - index \(sceneHeadingIndex) is not a scene heading")
            return
        }

        print("[RESTORE DEBUG] Restoring scene starting at element index: \(sceneHeadingIndex)")

        // Find the end of this scene (next scene heading or end of document)
        var endIndex = sceneHeadingIndex + 1
        while endIndex < doc.elements.count && doc.elements[endIndex].type != .sceneHeading {
            endIndex += 1
        }

        print("[RESTORE DEBUG] Scene spans elements \(sceneHeadingIndex) to \(endIndex - 1)")

        // Restore ALL elements in this scene
        for i in sceneHeadingIndex..<endIndex {
            // Restore original text if available
            if let originalText = doc.elements[i].originalText {
                doc.elements[i].text = originalText
            }

            // Unmark as omitted
            doc.elements[i].isOmitted = false

            // Mark with revision color if in revision mode (restoring is a change)
            if doc.isRevisionMode, let color = doc.currentRevisionColor {
                doc.elements[i].revisionColor = color
                doc.elements[i].revisionID = doc.currentRevisionID
            }
        }

        doc.updatedAt = Date()

        currentDocument = doc
        dataManager.saveDocumentAsync(doc)

        // Force reload to update the display
        forceDocumentReload = UUID()
        print("[RESTORE DEBUG] Scene restored successfully - \(endIndex - sceneHeadingIndex) elements restored")
    }

    /// Find the scene heading index for any element in a document
    /// Walks backwards from the given element index to find the nearest scene heading
    private func findSceneHeadingIndex(for elementIndex: Int, in document: ScreenplayDocument) -> Int {
        // If this element is a scene heading, return it
        if elementIndex < document.elements.count && document.elements[elementIndex].type == .sceneHeading {
            return elementIndex
        }

        // Walk backwards to find the scene heading
        var idx = elementIndex
        while idx > 0 {
            idx -= 1
            if document.elements[idx].type == .sceneHeading {
                return idx
            }
        }

        // If no scene heading found above, find the first scene heading in the document
        for i in 0..<document.elements.count {
            if document.elements[i].type == .sceneHeading {
                return i
            }
        }

        // No scene headings at all, return 0
        return 0
    }

    // MARK: - Insert Scene Function

    private func insertSceneAfterSelected() {
        guard var doc = currentDocument,
              let sceneIndex = selectedSceneIndex,
              sceneIndex < doc.elements.count,
              doc.elements[sceneIndex].type == .sceneHeading,
              let currentSceneNumber = doc.elements[sceneIndex].sceneNumber else { return }

        // Get all existing scene numbers
        let existingNumbers = SceneNumberUtils.allSceneNumbers(in: doc)

        // Find the next scene number (if any)
        var nextSceneNumber: String? = nil
        for i in (sceneIndex + 1)..<doc.elements.count {
            if doc.elements[i].type == .sceneHeading {
                nextSceneNumber = doc.elements[i].sceneNumber
                break
            }
        }

        // Generate the new inserted scene number
        let newSceneNumber = SceneNumberUtils.nextInsertedNumber(
            after: currentSceneNumber,
            before: nextSceneNumber,
            existingNumbers: existingNumbers
        )

        // Find the insertion point (after all elements belonging to current scene)
        var insertionIndex = sceneIndex + 1
        for i in (sceneIndex + 1)..<doc.elements.count {
            if doc.elements[i].type == .sceneHeading {
                break
            }
            insertionIndex = i + 1
        }

        // Create the new scene heading
        let newScene = ScriptElement(
            type: .sceneHeading,
            text: "INT. NEW LOCATION - DAY",
            sceneNumber: newSceneNumber
        )

        // Create an action element for the new scene
        let newAction = ScriptElement(
            type: .action,
            text: ""
        )

        // Insert the new elements
        doc.elements.insert(newAction, at: insertionIndex)
        doc.elements.insert(newScene, at: insertionIndex)

        // Update counts
        sceneCount = doc.scenes.count

        currentDocument = doc
        dataManager.saveDocumentAsync(doc)

        // Select the newly inserted scene
        selectedSceneIndex = insertionIndex
    }

    /// Insert a new scene BEFORE the selected scene
    /// Uses industry-standard numbering: 12 -> A12, A12 -> B12, etc.
    private func insertSceneBeforeSelected() {
        guard var doc = currentDocument,
              let sceneIndex = selectedSceneIndex,
              sceneIndex < doc.elements.count,
              doc.elements[sceneIndex].type == .sceneHeading,
              let currentSceneNumber = doc.elements[sceneIndex].sceneNumber else { return }

        // Get all existing scene numbers
        let existingNumbers = SceneNumberUtils.allSceneNumbers(in: doc)

        // Generate the new inserted scene number (prefix format: A12, B12, etc.)
        let newSceneNumber = SceneNumberUtils.nextNumberBefore(currentSceneNumber, existingNumbers: existingNumbers)

        // Insert at the current scene's position (pushing it down)
        let insertionIndex = sceneIndex

        // Create the new scene heading
        let newScene = ScriptElement(
            type: .sceneHeading,
            text: "INT. NEW LOCATION - DAY",
            sceneNumber: newSceneNumber
        )

        // Create an action element for the new scene
        let newAction = ScriptElement(
            type: .action,
            text: ""
        )

        // Insert the new elements (scene heading first, then action)
        doc.elements.insert(newAction, at: insertionIndex)
        doc.elements.insert(newScene, at: insertionIndex)

        // Update counts
        sceneCount = doc.scenes.count

        currentDocument = doc
        dataManager.saveDocumentAsync(doc)

        // Select the newly inserted scene
        selectedSceneIndex = insertionIndex
    }

    // MARK: - Get Scene Index at Element Index

    private func sceneIndexForElement(at elementIndex: Int) -> Int? {
        guard let doc = currentDocument else { return nil }

        // Find the scene heading at or before this element index
        for i in stride(from: elementIndex, through: 0, by: -1) {
            if doc.elements[i].type == .sceneHeading {
                return i
            }
        }
        return nil
    }

    private var scriptFileMenu: some View {
        Menu {
            Button(action: { showWelcomeSheet = true }) {
                Label("New Script...", systemImage: "plus")
            }

            Button(action: { showWelcomeSheet = true }) {
                Label("Open Script...", systemImage: "folder")
            }

            Divider()

            if !dataManager.drafts.isEmpty {
                Menu("Recent Scripts") {
                    ForEach(dataManager.drafts.prefix(5)) { draft in
                        Button(action: {
                            selectedDraftId = draft.id
                        }) {
                            Label(draft.title, systemImage: "doc.text")
                        }
                    }
                }

                Divider()
            }

            if currentDocument != nil {
                Button(action: {
                    if let doc = currentDocument {
                        dataManager.saveDocument(doc)
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Button(action: {
                    renameText = currentDocument?.title ?? ""
                    showRenameSheet = true
                }) {
                    Label("Rename...", systemImage: "pencil")
                }

                Divider()

                // Export submenu
                Menu("Export") {
                    Button(action: {
                        if currentDocument != nil {
                            showExportPDFSheet = true
                        }
                    }) {
                        Label("Export as PDF...", systemImage: "doc.richtext")
                    }

                    Button(action: {
                        if let doc = currentDocument {
                            ScreenplayExporter.exportToFDXWithPanel(document: doc)
                        }
                    }) {
                        Label("Export as Final Draft (.fdx)...", systemImage: "doc.text")
                    }

                    Button(action: {
                        if let doc = currentDocument {
                            ScreenplayExporter.exportToFountainWithPanel(document: doc)
                        }
                    }) {
                        Label("Export as Fountain (.fountain)...", systemImage: "text.alignleft")
                    }

                    Divider()

                    Button(action: {
                        showScriptSidesSheet = true
                    }) {
                        Label("Generate Sides...", systemImage: "doc.on.doc")
                    }
                }

                Button(action: {
                    if let doc = currentDocument {
                        ScreenplayExporter.printScreenplay(document: doc)
                    }
                }) {
                    Label("Print...", systemImage: "printer")
                }
                .keyboardShortcut("p", modifiers: .command)

                Divider()

                Button(role: .destructive, action: closeCurrentDocument) {
                    Label("Close Script", systemImage: "xmark")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Select Script")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(currentDocument?.title ?? "No Script")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .customTooltip("Script options")
    }

    // MARK: - Rename Script Sheet

    private var renameScriptSheet: some View {
        VStack(spacing: 20) {
            Text("Rename Script")
                .font(.headline)

            TextField("Script Title", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack(spacing: 16) {
                Button("Cancel") {
                    showRenameSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    if var doc = currentDocument, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        doc.title = renameText.trimmingCharacters(in: .whitespaces)
                        doc.updatedAt = Date()
                        currentDocument = doc
                        dataManager.saveDocument(doc)
                    }
                    showRenameSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 400)
    }

    // MARK: - Export PDF Sheet

    private var exportPDFSheet: some View {
        VStack(spacing: 20) {
            Text("Export as PDF")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                // Title page toggle
                Toggle("Include Title Page", isOn: $exportOptions.includeTitlePage)

                // Revision options
                Toggle("Include Revision Marks (asterisks)", isOn: $exportOptions.includeRevisionMarks)
                Toggle("Include Revision Headers", isOn: $exportOptions.includeRevisionHeaders)

                // Scene numbers
                HStack {
                    Text("Scene Numbers:")
                    Picker("", selection: $exportOptions.sceneNumbers) {
                        Text("None").tag(SceneNumberPosition.none)
                        Text("Left").tag(SceneNumberPosition.left)
                        Text("Right").tag(SceneNumberPosition.right)
                        Text("Both").tag(SceneNumberPosition.both)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                // Paper size
                HStack {
                    Text("Paper Size:")
                    Picker("", selection: $exportOptions.paperSize) {
                        ForEach(ScreenplayExportOptions.PaperSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .frame(width: 120)
                }

                // Watermark
                HStack {
                    Text("Watermark:")
                    TextField("Optional", text: Binding(
                        get: { exportOptions.watermarkText ?? "" },
                        set: { exportOptions.watermarkText = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button("Cancel") {
                    showExportPDFSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Export") {
                    if let doc = currentDocument {
                        ScreenplayExporter.exportToPDFWithPanel(
                            document: doc,
                            options: exportOptions
                        )
                    }
                    showExportPDFSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(minWidth: 450)
    }

    private var scriptElementMenu: some View {
        Menu {
            ForEach(ScriptElementType.allCases) { type in
                Button(action: { currentElementType = type }) {
                    HStack {
                        Label(type.rawValue, systemImage: iconForElement(type))
                        if currentElementType == type {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconForElement(currentElementType))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(colorForElement(currentElementType))
                    )
                Text(currentElementType.rawValue)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .customTooltip("Current: \(currentElementType.rawValue) - Click to change")
    }

    private var quickElementButtons: some View {
        HStack(spacing: 4) {
            ForEach(ScriptElementType.allCases.prefix(6)) { type in
                Button(action: { currentElementType = type }) {
                    Image(systemName: iconForElement(type))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(currentElementType == type ? .white : colorForElement(type))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(currentElementType == type ? colorForElement(type) : colorForElement(type).opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(currentElementType == type ? Color.clear : colorForElement(type).opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(type.rawValue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            // Left: Page and Scene counts
            HStack(spacing: 20) {
                // Page count
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(pageCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(pageCount == 1 ? "Page" : "Pages")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Scene count
                HStack(spacing: 6) {
                    Image(systemName: "film")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(sceneCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(sceneCount == 1 ? "Scene" : "Scenes")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Word count (bonus)
                HStack(spacing: 6) {
                    Image(systemName: "text.word.spacing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(wordCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Words")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 16)

            Spacer()

            // Center: Script title
            if let doc = currentDocument {
                Text(doc.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            // Right: Appearance toggle and Zoom controls
            HStack(spacing: 16) {
                // Appearance toggle (Light/Dark/System)
                HStack(spacing: 4) {
                    ForEach(EditorAppearance.allCases, id: \.self) { appearance in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                editorAppearance = appearance
                            }
                        }) {
                            Image(systemName: appearance.icon)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(editorAppearance == appearance ? .white : .secondary)
                                .frame(width: 26, height: 22)
                                .background(
                                    editorAppearance == appearance
                                        ? Color.accentColor
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .customTooltip("\(appearance.rawValue) mode")
                    }
                }
                .padding(2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 16)

                // Zoom controls
                HStack(spacing: 8) {
                    // Zoom out button
                    Button(action: { zoomLevel = max(0.5, zoomLevel - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Zoom out")

                    // Zoom slider
                    Slider(value: $zoomLevel, in: 0.5...2.0, step: 0.1)
                        .frame(width: 100)
                        .controlSize(.small)

                    // Zoom in button
                    Button(action: { zoomLevel = min(2.0, zoomLevel + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Zoom in")

                    // Zoom percentage menu
                    Menu {
                        Button("50%") { zoomLevel = 0.5 }
                        Button("75%") { zoomLevel = 0.75 }
                        Button("100%") { zoomLevel = 1.0 }
                        Button("125%") { zoomLevel = 1.25 }
                        Button("150%") { zoomLevel = 1.5 }
                        Button("200%") { zoomLevel = 2.0 }
                    } label: {
                        Text("\(Int(zoomLevel * 100))%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 45, alignment: .trailing)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 32)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var inspectorToggleButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showInspector.toggle()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: showInspector ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Script Notes")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(showInspector ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                showInspector
                    ? Color.accentColor
                    : Color.secondary.opacity(0.15)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        showInspector ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .shadow(color: showInspector ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .customTooltip(Tooltips.ScreenplayEditor.showInspector)
    }

    // MARK: - Left Inspector Toggle Button

    private var leftInspectorToggleButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showLeftInspector.toggle()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: showLeftInspector ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Story Notes")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(showLeftInspector ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                showLeftInspector
                    ? Color.accentColor
                    : Color.secondary.opacity(0.15)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        showLeftInspector ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .shadow(color: showLeftInspector ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .customTooltip("Toggle left inspector panel")
    }
    #endif

    // MARK: - Editor Canvas

    #if os(macOS)
    private var editorCanvas: some View {
        PaginatedScreenplayEditor(
            document: $currentDocument,
            currentElementType: $currentElementType,
            pageCount: $pageCount,
            sceneNumberPosition: $sceneNumberPosition,
            scrollToElementIndex: $scrollToElementIndex,
            currentRevisionColor: currentRevision == .white ? nil : currentRevision.rawValue,
            editorAppearanceMode: editorAppearance.rawValue,
            forceReload: forceDocumentReload,
            onDocumentChanged: { updatedDocument in
                print("[ScreenplayEditorView] Document changed - \(updatedDocument.elements.count) elements")
                currentDocument = updatedDocument
                // Update stats
                sceneCount = updatedDocument.scenes.count
                wordCount = updatedDocument.elements.reduce(0) { $0 + $1.text.split(separator: " ").count }
                // Auto-save with debouncing
                dataManager.saveDocumentAsync(updatedDocument)
            }
        )
        .scaleEffect(zoomLevel, anchor: .top)
    }

    /// Overlay showing scene numbers in the right margin
    /// Uses actual Y positions from the text view's layout manager
    private func sceneNumbersOverlay() -> some View {
        // Scene number X positions in the margins
        let rightMarginX: CGFloat = ScreenplayFormat.pageWidth - ScreenplayFormat.marginRight / 2
        let leftMarginX: CGFloat = ScreenplayFormat.marginLeft / 2

        return ZStack(alignment: .topLeading) {
            // Use actual positions from the text view layout
            ForEach(Array(sceneHeadingPositions.enumerated()), id: \.offset) { index, position in
                // Use the actual height from layout for perfect vertical centering
                let centerY = ScreenplayFormat.marginTop + position.y + position.height / 2

                // Scene number text at right margin
                Text(position.sceneNumber)
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)
                    .position(
                        x: rightMarginX,
                        y: centerY
                    )
                    .onTapGesture {
                        selectedSceneIndex = index
                    }

                // Also show at left margin for dual-display (industry standard)
                Text(position.sceneNumber)
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)
                    .position(
                        x: leftMarginX,
                        y: centerY
                    )
                    .onTapGesture {
                        selectedSceneIndex = index
                    }
            }
        }
    }

    /// Calculate approximate Y position for an element
    private func calculateElementY(at index: Int, in document: ScreenplayDocument) -> CGFloat {
        let lineHeight: CGFloat = ScreenplayFormat.lineHeight
        var y: CGFloat = ScreenplayFormat.marginTop

        for i in 0..<index {
            let element = document.elements[i]

            // Add space before based on element type
            switch element.type {
            case .sceneHeading:
                y += ScreenplayFormat.sceneHeadingSpaceBefore
                // Estimate lines for the text (rough: 60 chars per line)
                let lines = max(1, (element.text.count / 60) + 1)
                y += CGFloat(lines) * lineHeight
                y += ScreenplayFormat.sceneHeadingSpaceAfter

            case .action:
                y += ScreenplayFormat.actionSpaceBefore
                let lines = max(1, (element.text.count / 60) + 1)
                y += CGFloat(lines) * lineHeight
                y += ScreenplayFormat.actionSpaceAfter

            case .character:
                y += ScreenplayFormat.characterSpaceBefore
                y += lineHeight
                y += ScreenplayFormat.characterSpaceAfter

            case .dialogue:
                y += ScreenplayFormat.dialogueSpaceBefore
                // Dialogue is narrower (about 35 chars per line)
                let lines = max(1, (element.text.count / 35) + 1)
                y += CGFloat(lines) * lineHeight
                y += ScreenplayFormat.dialogueSpaceAfter

            case .parenthetical:
                y += ScreenplayFormat.parentheticalSpaceBefore
                y += lineHeight
                y += ScreenplayFormat.parentheticalSpaceAfter

            case .transition:
                y += ScreenplayFormat.transitionSpaceBefore
                y += lineHeight
                y += ScreenplayFormat.transitionSpaceAfter

            default:
                y += lineHeight + ScreenplayFormat.blankLine
            }
        }

        // Add space before the target element
        if index < document.elements.count {
            let element = document.elements[index]
            switch element.type {
            case .sceneHeading:
                y += ScreenplayFormat.sceneHeadingSpaceBefore
            case .action:
                y += ScreenplayFormat.actionSpaceBefore
            case .character:
                y += ScreenplayFormat.characterSpaceBefore
            case .dialogue:
                y += ScreenplayFormat.dialogueSpaceBefore
            case .parenthetical:
                y += ScreenplayFormat.parentheticalSpaceBefore
            case .transition:
                y += ScreenplayFormat.transitionSpaceBefore
            default:
                break
            }
        }

        return y
    }
    #endif

    // MARK: - Inspector Panel

    #if os(macOS)
    private var inspectorPanel: some View {
        let _ = print("[Screenplay DEBUG] inspectorPanel - evaluating, tab: \(inspectorTab.rawValue), showInspector: \(showInspector)")
        return VStack(spacing: 0) {
            // Tab Picker (matches Scheduler pattern)
            Picker("", selection: $inspectorTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Tab content
            switch inspectorTab {
            case .scenes:
                scenesInspector
            case .comments:
                commentsInspector
            case .revisions:
                revisionsInspector
            }
        }
        .frame(width: 450)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Left Inspector Panel

    private var leftInspectorPanel: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("", selection: $leftInspectorTab) {
                ForEach(LeftInspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Tab content
            switch leftInspectorTab {
            case .storyNotes:
                storyNotesInspector
            case .beatBoard:
                beatBoardInspector
            }
        }
        .frame(width: 450)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Story Notes Inspector

    private var storyNotesInspector: some View {
        return VStack(spacing: 0) {
            // Mini toolbar
            HStack(spacing: 8) {
                // Add Act button
                Button(action: {
                    addNoteSection(.act)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Act")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .customTooltip("Add new Act section")

                // Add Beat button
                Button(action: {
                    addNoteSection(.beat)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Beat")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .customTooltip("Add new Beat section")

                // Add Notes button
                Button(action: {
                    addNoteSection(.freeform)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Note")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gray)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .customTooltip("Add new freeform note")

                Spacer()

                // Expand/Collapse all
                Button(action: {
                    if collapsedSectionIds.count == noteSections.count {
                        collapsedSectionIds.removeAll()
                    } else {
                        collapsedSectionIds = Set(noteSections.map { $0.id })
                    }
                }) {
                    Image(systemName: collapsedSectionIds.count == noteSections.count ? "chevron.down.circle" : "chevron.up.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .customTooltip(collapsedSectionIds.count == noteSections.count ? "Expand all" : "Collapse all")
                .opacity(noteSections.isEmpty ? 0.3 : 1)
                .disabled(noteSections.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Collapsible sections list with drag and drop
            if noteSections.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No notes yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Add an Act, Beat, or Note to get started")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(noteSections.enumerated()), id: \.element.id) { index, section in
                            noteSectionRow(section: section, index: index)
                                .opacity(draggingNoteSection?.id == section.id ? 0.5 : 1.0)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDrop(of: [.text], delegate: NoteSectionListDropDelegate(
                    items: $noteSections,
                    draggingItem: $draggingNoteSection
                ))
            }

            Divider()

            // Section count footer
            HStack {
                let totalWords = noteSections.reduce(0) { $0 + $1.content.split(whereSeparator: { $0.isWhitespace }).count }
                Text("\(noteSections.count) section\(noteSections.count == 1 ? "" : "s") • \(totalWords) word\(totalWords == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    /// Get the current color for a note section
    private func noteColor(for section: NoteSection) -> Color {
        guard section.colorIndex >= 0 && section.colorIndex < Self.noteColors.count else {
            return .blue
        }
        return Self.noteColors[section.colorIndex].color
    }

    /// Individual collapsible note section row
    private func noteSectionRow(section: NoteSection, index: Int) -> some View {
        let sectionId = section.id
        let isCollapsed = collapsedSectionIds.contains(sectionId)
        let currentColor = noteColor(for: section)

        return VStack(spacing: 0) {
            // Colored header bar
            HStack(spacing: 8) {
                // Drag handle - apply onDrag only to this element
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .onDrag {
                        self.draggingNoteSection = section
                        return NSItemProvider(object: sectionId.uuidString as NSString)
                    }

                // Collapse/expand chevron
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isCollapsed {
                            collapsedSectionIds.remove(sectionId)
                        } else {
                            collapsedSectionIds.insert(sectionId)
                        }
                    }
                }) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                // Section type badge
                HStack(spacing: 3) {
                    Image(systemName: section.sectionType.icon)
                        .font(.system(size: 9))
                    Text(section.sectionType.rawValue)
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(currentColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.9))
                .cornerRadius(3)

                // Editable title - use ID-based lookup for reliable binding
                TextField(section.sectionType == .act ? "Act Title" : section.sectionType == .beat ? "Beat Title" : "Note Title",
                          text: Binding(
                            get: { noteSections.first(where: { $0.id == sectionId })?.title ?? "" },
                            set: { newValue in
                                if let idx = noteSections.firstIndex(where: { $0.id == sectionId }) {
                                    noteSections[idx].title = newValue
                                }
                            }
                          ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Color picker - use ID-based lookup
                Menu {
                    ForEach(Array(Self.noteColors.enumerated()), id: \.offset) { colorIndex, colorInfo in
                        Button {
                            if let idx = noteSections.firstIndex(where: { $0.id == sectionId }) {
                                noteSections[idx].colorIndex = colorIndex
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(colorInfo.color)
                                    .frame(width: 12, height: 12)
                                Text(colorInfo.name)
                                if noteSections.first(where: { $0.id == sectionId })?.colorIndex == colorIndex {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(currentColor)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
                .customTooltip("Change color")

                // Delete button - use ID-based lookup
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        noteSections.removeAll { $0.id == sectionId }
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .customTooltip("Delete section")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(currentColor)

            // Content area (hidden when collapsed) - use ID-based lookup
            if !isCollapsed {
                ZStack(alignment: .topLeading) {
                    // Background
                    Color(NSColor.textBackgroundColor)

                    // Text editor
                    TextEditor(text: Binding(
                        get: { noteSections.first(where: { $0.id == sectionId })?.content ?? "" },
                        set: { newValue in
                            if let idx = noteSections.firstIndex(where: { $0.id == sectionId }) {
                                noteSections[idx].content = newValue
                            }
                        }
                    ))
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
                .frame(minHeight: 80, maxHeight: 200)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(currentColor.opacity(0.3), lineWidth: 1)
                .allowsHitTesting(false)  // Don't block events through overlay
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    /// Add a new note section
    private func addNoteSection(_ type: NoteSection.NoteSectionType) {
        // Different default colors for each type:
        // Act = Purple (0), Beat = Blue (1), Note = Green (3)
        let defaultColorIndex: Int
        switch type {
        case .act:
            defaultColorIndex = 0  // Purple
        case .beat:
            defaultColorIndex = 1  // Blue
        case .freeform:
            defaultColorIndex = 3  // Green
        }
        let newSection = NoteSection(sectionType: type, colorIndex: defaultColorIndex)
        withAnimation(.easeInOut(duration: 0.2)) {
            noteSections.append(newSection)
        }
    }

    // MARK: - Note Section Drop Delegates

    /// Simple drop delegate for the note section list - just handles drop completion
    struct NoteSectionListDropDelegate: DropDelegate {
        @Binding var items: [NoteSection]
        @Binding var draggingItem: NoteSection?

        func performDrop(info: DropInfo) -> Bool {
            draggingItem = nil
            return true
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            return DropProposal(operation: .move)
        }
    }

    /// Drop delegate for header bar - handles reordering
    struct NoteSectionHeaderDropDelegate: DropDelegate {
        let item: NoteSection
        @Binding var items: [NoteSection]
        @Binding var draggingItem: NoteSection?

        func performDrop(info: DropInfo) -> Bool {
            draggingItem = nil
            return true
        }

        func dropEntered(info: DropInfo) {
            guard let draggingItem = draggingItem,
                  draggingItem.id != item.id,
                  let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
                  let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            return DropProposal(operation: .move)
        }
    }

    // MARK: - Beat Board Inspector

    private var beatBoardInspector: some View {
        return VStack(spacing: 0) {
            // Toolbar with Add Beat button
            HStack(spacing: 8) {
                Button(action: {
                    addNewBeat()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add Beat")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .customTooltip("Add a new beat card")

                Spacer()

                // View toggle: 1 column vs 2 columns
                HStack(spacing: 2) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            beatViewColumns = 1
                        }
                    }) {
                        Image(systemName: "rectangle.grid.1x2")
                            .font(.system(size: 12))
                            .foregroundColor(beatViewColumns == 1 ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Single column view")

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            beatViewColumns = 2
                        }
                    }) {
                        Image(systemName: "rectangle.grid.2x2")
                            .font(.system(size: 12))
                            .foregroundColor(beatViewColumns == 2 ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Two column view")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(4)
                .animation(.easeInOut(duration: 0.2), value: beatViewColumns)

                // Beat count
                Text("\(beats.count) beat\(beats.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Beat grid - dynamic columns with drag and drop
            if beats.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))

                    Text("No beats yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Click \"Add Beat\" to create your first beat card.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: beatGridColumns, spacing: 8) {
                        ForEach(beats) { beat in
                            beatCardView(beatId: beat.id)
                                .opacity(draggingBeat?.id == beat.id ? 0.5 : 1.0)
                                .onDrag {
                                    self.draggingBeat = beat
                                    return NSItemProvider(object: beat.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: BeatDropDelegate(
                                    item: beat,
                                    items: $beats,
                                    draggingItem: $draggingBeat
                                ))
                        }
                    }
                    .padding(12)
                    .animation(.easeInOut(duration: 0.2), value: beatViewColumns)
                }
                .id(beatViewColumns)  // Force ScrollView re-render when columns change
            }
        }
    }

    /// Add a new beat card
    private func addNewBeat() {
        // Always default to blue (index 1)
        let newBeat = BeatCard(colorIndex: 1)
        withAnimation(.easeInOut(duration: 0.2)) {
            beats.append(newBeat)
        }
    }

    /// Delete a beat card by ID
    private func deleteBeat(id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            beats.removeAll { $0.id == id }
        }
    }

    // MARK: - Beat Drop Delegate

    struct BeatDropDelegate: DropDelegate {
        let item: BeatCard
        @Binding var items: [BeatCard]
        @Binding var draggingItem: BeatCard?

        func performDrop(info: DropInfo) -> Bool {
            draggingItem = nil
            return true
        }

        func dropEntered(info: DropInfo) {
            guard let draggingItem = draggingItem,
                  draggingItem.id != item.id,
                  let fromIndex = items.firstIndex(where: { $0.id == draggingItem.id }),
                  let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            return DropProposal(operation: .move)
        }
    }

    // MARK: - Beat Card View

    @State private var hoveringBeatId: UUID? = nil

    /// Helper to get a binding for a beat by ID
    private func bindingForBeat(id: UUID) -> Binding<BeatCard>? {
        guard let index = beats.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.beats[index] },
            set: { self.beats[index] = $0 }
        )
    }

    private func beatCardView(beatId: UUID) -> some View {
        let beatIndex = beats.firstIndex(where: { $0.id == beatId })
        let beat = beatIndex.map { beats[$0] } ?? BeatCard(colorIndex: 1)
        let currentColor: Color = {
            guard beat.colorIndex >= 0 && beat.colorIndex < Self.beatColors.count else {
                return .blue
            }
            return Self.beatColors[beat.colorIndex].color
        }()

        return VStack(alignment: .leading, spacing: 0) {
            // Colored header bar
            HStack(spacing: 6) {
                // Color picker menu
                Menu {
                    ForEach(Array(Self.beatColors.enumerated()), id: \.offset) { colorIdx, colorInfo in
                        Button(action: {
                            if let idx = beats.firstIndex(where: { $0.id == beatId }) {
                                beats[idx].colorIndex = colorIdx
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(colorInfo.color)
                                    .frame(width: 12, height: 12)
                                Text(colorInfo.name)
                                if beat.colorIndex == colorIdx {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(currentColor)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .customTooltip("Change beat color")

                // Editable title field
                TextField("Beat Title", text: Binding(
                    get: {
                        beats.first(where: { $0.id == beatId })?.title ?? ""
                    },
                    set: { newValue in
                        if let idx = beats.firstIndex(where: { $0.id == beatId }) {
                            beats[idx].title = newValue
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)

                Spacer()

                // Drag handle indicator
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))

                // Delete button
                Button(action: {
                    deleteBeat(id: beatId)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .customTooltip("Delete beat")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(currentColor)

            // Editable text area
            TextEditor(text: Binding(
                get: {
                    beats.first(where: { $0.id == beatId })?.text ?? ""
                },
                set: { newValue in
                    if let idx = beats.firstIndex(where: { $0.id == beatId }) {
                        beats[idx].text = newValue
                    }
                }
            ))
            .font(.system(size: 11))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 60, maxHeight: 100)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: currentColor.opacity(0.3), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(currentColor.opacity(0.5), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Revisions Inspector

    private var revisionsInspector: some View {
        VStack(spacing: 0) {
            // Header with current revision info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CURRENT REVISION")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // Current revision indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentRevision.color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5)
                        )

                    Text(currentRevision.displayName)
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    if currentRevision != .white {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                .padding(10)
                .background(currentRevision.color.opacity(0.2))
                .cornerRadius(8)

                // Revised elements count
                if let doc = currentDocument {
                    let revisedCount = doc.revisedElementCount
                    if revisedCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("\(revisedCount) element\(revisedCount == 1 ? "" : "s") marked")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(12)

            Divider()

            // Import FDX Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("IMPORT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Import FDX button
                    Button(action: { showFDXImportSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10, weight: .medium))
                            Text("Import FDX")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Import a Final Draft FDX file as a revision")
                }
            }
            .padding(12)

            Divider()

            // Script Versions Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SCRIPT VERSIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(dataManager.drafts.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                }

                if dataManager.drafts.isEmpty {
                    Text("No saved versions")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(dataManager.drafts) { draft in
                                Button(action: {
                                    selectedDraftId = draft.id
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.blue)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(draft.title)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)

                                            HStack(spacing: 6) {
                                                Text("\(draft.pageCount) pgs")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)

                                                Text("•")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary.opacity(0.5))

                                                Text(draft.updatedAt, style: .date)
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if currentDocument?.id == draft.id {
                                            Text("CURRENT")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(currentDocument?.id == draft.id ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            .padding(12)

            Divider()

            // Script Revisions List (project snapshots by revision color)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SCRIPT REVISIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(revisionImporter.revisions.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if revisionImporter.revisions.isEmpty {
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No Revisions")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Switch to a revision color to save a project snapshot")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(revisionImporter.revisions, selection: $selectedRevisionId) { revision in
                    StoredRevisionRow(revision: revision)
                        .contextMenu {
                            Button(action: {
                                loadRevisionIntoEditor(revision)
                            }) {
                                Label("Open in Editor", systemImage: "doc.text")
                            }

                            Button(action: {
                                sendRevisionToApps(revision)
                            }) {
                                Label("Send to Apps", systemImage: "paperplane.fill")
                            }

                            Divider()

                            Button(role: .destructive) {
                                revisionToDelete = revision.id
                                revisionColorToDelete = revision.colorName
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete & Merge Revision", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.sidebar)
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            revisionImporter.configure(with: viewContext)
        }
        .fileImporter(
            isPresented: $showFDXImportSheet,
            allowedContentTypes: [.xml, UTType(filenameExtension: "fdx") ?? .xml],
            allowsMultipleSelection: false
        ) { result in
            handleFDXImport(result)
        }
        .sheet(isPresented: $showSaveRevisionSheet) {
            SaveRevisionSheet(
                selectedColor: $selectedRevisionColor,
                notes: $revisionNotes,
                onSave: {
                    Task {
                        await saveRevisionFromCurrentDocument()
                    }
                    showSaveRevisionSheet = false
                },
                onCancel: {
                    showSaveRevisionSheet = false
                }
            )
        }
        .alert("Delete & Merge Revision?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                revisionToDelete = nil
                revisionColorToDelete = nil
            }
            Button("Delete & Merge", role: .destructive) {
                if let id = revisionToDelete {
                    // Clear revision marks of this color from the current document
                    if let colorName = revisionColorToDelete {
                        clearRevisionMarksForColor(colorName)
                    }

                    // Delete the stored revision
                    revisionImporter.deleteRevision(id: id)
                    if selectedRevisionId == id {
                        selectedRevisionId = nil
                    }
                }
                revisionToDelete = nil
                revisionColorToDelete = nil
            }
        } message: {
            Text("This will merge the revision changes back to the original script and delete the revision snapshot.")
        }
        .alert("Switch Revision Color?", isPresented: $showRevisionSwitchAlert) {
            Button("Cancel", role: .cancel) {
                pendingRevisionColor = nil
            }
            Button("Keep Revisions") {
                if let newColor = pendingRevisionColor {
                    performRevisionSwitch(to: newColor, mergeExisting: false)
                }
                pendingRevisionColor = nil
            }
            Button("Merge to Original", role: .destructive) {
                if let newColor = pendingRevisionColor {
                    performRevisionSwitch(to: newColor, mergeExisting: true)
                }
                pendingRevisionColor = nil
            }
        } message: {
            if let newColor = pendingRevisionColor {
                Text("You have existing revision marks. Do you want to merge them back to original before starting \(newColor.rawValue) Revision, or keep them?")
            } else {
                Text("You have existing revision marks.")
            }
        }
    }

    private func handleFDXImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            Task {
                let _ = await revisionImporter.importRevision(
                    from: url,
                    colorName: "Blue",
                    notes: nil
                )
            }
        case .failure(let error):
            print("[ScreenplayEditorView] File selection failed: \(error)")
        }
    }

    private func saveRevisionFromCurrentDocument() async {
        guard let document = currentDocument else { return }
        let _ = await revisionImporter.createRevisionFromScreenplay(
            document: document,
            colorName: selectedRevisionColor,
            notes: revisionNotes.isEmpty ? nil : revisionNotes
        )
        revisionNotes = ""
    }

    private func loadRevisionIntoEditor(_ revision: StoredRevision) {
        guard let document = revisionImporter.loadRevisionDocument(id: revision.id) else {
            print("[ScreenplayEditorView] Failed to load revision document")
            return
        }
        currentDocument = document
    }

    /// Send a revision to Scheduler, Shots, and Breakdowns for syncing
    private func sendRevisionToApps(_ revision: StoredRevision) {
        Task {
            guard let document = revisionImporter.loadRevisionDocument(id: revision.id) else {
                print("[ScreenplayEditorView] Failed to load revision document for sync")
                return
            }
            await ScriptRevisionSyncService.shared.sendRevision(revision, document: document)
        }
    }

    private func revisionSnapshotRow(_ snapshot: RevisionSnapshot) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(snapshot.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(snapshot.formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("\(snapshot.elementCount) elements")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("\(snapshot.pageCount) pg")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(snapshot.color.opacity(0.3), lineWidth: 1)
        )
    }

    /// Returns the active document
    private var activeDocument: ScreenplayDocument? {
        return currentDocument
    }

    private var scenesInspector: some View {
        let _ = print("[Screenplay DEBUG] scenesInspector - evaluating view")
        return VStack(spacing: 0) {
            if let document = activeDocument {
                let _ = print("[Screenplay DEBUG] scenesInspector - document exists: '\(document.title)', checking scenes...")
                let scenesList = document.scenes
                let _ = print("[Screenplay DEBUG] scenesInspector - got \(scenesList.count) scenes")
                // Document Info Section at top
                VStack(alignment: .leading, spacing: 8) {
                    Text("DOCUMENT INFO")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        statRow(icon: "doc.text", label: "Pages", value: "\(pageCount)")
                        statRow(icon: "film", label: "Scenes", value: "\(sceneCount)")
                        statRow(icon: "text.word.spacing", label: "Words", value: "\(wordCount)")
                    }
                }
                .padding(12)

                Divider()

                // Scenes List
                if scenesList.isEmpty {
                    emptyScenesList
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SCENES")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(scenesList.enumerated()), id: \.offset) { index, scene in
                                    sceneRow(number: scene.number, heading: scene.heading, index: scene.index, pageEighths: scene.pageEighths)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else {
                emptyScenesList
            }
        }
    }

    private var emptyScenesList: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "film.stack")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Scenes")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text("Scene headings will appear here as you write")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }

    private func sceneRow(number: String, heading: String, index: Int, pageEighths: Int) -> some View {
        Button(action: {
            print("[SCENE SELECT DEBUG] Button pressed - setting selectedSceneIndex to \(index)")
            selectedSceneIndex = index
            // Scroll to scene in editor
            scrollToElementIndex = index
        }) {
            HStack(alignment: .top, spacing: 8) {
                Text(number)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)

                Text(heading.uppercased())
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Spacer()

                // Page length in eighths
                Text(formatPageEighths(pageEighths))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(selectedSceneIndex == index ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    /// Format page eighths as a string (e.g., "1 2/8" or "2/8")
    private func formatPageEighths(_ eighths: Int) -> String {
        let wholePages = eighths / 8
        let remainingEighths = eighths % 8
        if wholePages > 0 && remainingEighths > 0 {
            return "\(wholePages) \(remainingEighths)/8"
        } else if wholePages > 0 {
            return "\(wholePages)"
        } else {
            return "\(remainingEighths)/8"
        }
    }


    private var commentsInspector: some View {
        VStack(spacing: 0) {
            // Header with add button
            HStack {
                Text("SCRIPT NOTES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { showNewCommentSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .customTooltip("Add new comment")
            }
            .padding(12)

            Divider()

            // Comments list
            if comments.isEmpty {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No Comments")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Tag text in your script and add notes")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: { showNewCommentSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Add Comment")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(comments) { comment in
                                CommentCard(
                                    comment: comment,
                                    onDelete: { deleteComment(comment.id) },
                                    isHighlighted: scrollToCommentId == comment.id
                                )
                                .id(comment.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: scrollToCommentId) { newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                            // Clear the scroll target after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                scrollToCommentId = nil
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewCommentSheet) {
            NewCommentSheet(
                taggedText: $selectedText,
                onSave: { taggedText, note in
                    addComment(taggedText: taggedText, note: note)
                    showNewCommentSheet = false
                },
                onCancel: { showNewCommentSheet = false }
            )
        }
    }

    private func addComment(taggedText: String, note: String, elementIndex: Int? = nil) {
        let comment = ScriptComment(taggedText: taggedText, note: note, elementIndex: elementIndex ?? selectedSceneIndex)
        comments.append(comment)
    }

    private func deleteComment(_ id: UUID) {
        comments.removeAll { $0.id == id }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
    }

    #endif

    // MARK: - Helpers

    private func iconForElement(_ type: ScriptElementType) -> String {
        switch type {
        case .sceneHeading: return "film"
        case .action: return "figure.walk"
        case .character: return "person.fill"
        case .parenthetical: return "text.bubble"
        case .dialogue: return "quote.bubble"
        case .transition: return "arrow.right"
        case .shot: return "camera"
        case .general: return "text.alignleft"
        case .titlePage: return "doc.text"
        }
    }

    private func colorForElement(_ type: ScriptElementType) -> Color {
        switch type {
        case .sceneHeading: return .blue
        case .action: return .green
        case .character: return .purple
        case .parenthetical: return .orange
        case .dialogue: return .pink
        case .transition: return .red
        case .shot: return .teal
        case .general: return .gray
        case .titlePage: return .indigo
        }
    }
}

// MARK: - Save Revision Sheet

struct SaveRevisionSheet: View {
    @Binding var selectedColor: String
    @Binding var notes: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private let revisionColors = [
        "White", "Blue", "Pink", "Yellow", "Green",
        "Goldenrod", "Buff", "Salmon", "Cherry", "Tan", "Gray"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Save Script Revision")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Revision Color")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(revisionColors, id: \.self) { colorName in
                        Button(action: { selectedColor = colorName }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(colorForName(colorName))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(selectedColor == colorName ? Color.accentColor : Color.black.opacity(0.2), lineWidth: selectedColor == colorName ? 2 : 0.5)
                                    )

                                Text(colorName)
                                    .font(.system(size: 9))
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                TextEditor(text: $notes)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button("Save Revision") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
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
        case "gray": return Color(red: 0.83, green: 0.83, blue: 0.83)
        default: return Color.white
        }
    }
}

// MARK: - Stored Revision Row

struct StoredRevisionRow: View {
    let revision: StoredRevision

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(revision.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(revision.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(revision.importDate, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    if revision.scenesModified > 0 {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("\(revision.scenesModified) changes")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Comment Card

struct CommentCard: View {
    let comment: ScreenplayEditorView.ScriptComment
    let onDelete: () -> Void
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with date, linked indicator, and delete button
            HStack {
                if comment.elementIndex != nil {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }

                Text(comment.createdAt, style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            // Tagged text
            if !comment.taggedText.isEmpty {
                Text(comment.taggedText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }

            // Note
            Text(comment.note)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(isHighlighted ? Color.orange.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHighlighted ? Color.orange : Color.secondary.opacity(0.2), lineWidth: isHighlighted ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}

// MARK: - New Comment Sheet

struct NewCommentSheet: View {
    @Binding var taggedText: String
    @State private var taggedTextInput: String = ""
    @State private var noteInput: String = ""
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Script Note")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Tagged Text (Optional)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                TextField("Paste or type text from script", text: $taggedTextInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                TextEditor(text: $noteInput)
                    .font(.system(size: 13))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button("Add Note") {
                    onSave(taggedTextInput, noteInput)
                }
                .buttonStyle(.borderedProminent)
                .disabled(noteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450)
        .onAppear {
            taggedTextInput = taggedText
        }
    }
}

// MARK: - Preview

#Preview {
    ScreenplayEditorView()
        .frame(width: 1200, height: 800)
}
