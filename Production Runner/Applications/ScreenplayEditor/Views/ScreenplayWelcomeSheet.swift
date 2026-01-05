//
//  ScreenplayWelcomeSheet.swift
//  Production Runner
//
//  Welcome sheet for creating new scripts or importing existing ones.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Welcome Sheet

struct ScreenplayWelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedDraftId: UUID?
    @ObservedObject var dataManager: ScreenplayDataManager

    @State private var showNewScriptSheet = false
    @State private var showImportPicker = false
    @State private var importType: ImportType = .finalDraft
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showDeleteConfirmation = false
    @State private var draftToDelete: ScreenplayDraftInfo?
    @State private var fdxDataForBreakdowns: Data? // Store FDX data to sync to Breakdowns
    @State private var importProgress: Double = 0.0
    @State private var importStatusMessage: String = "Reading file..."

    // Sync prompt state
    @State private var showSyncPrompt = false
    @State private var pendingSyncDraftId: UUID?
    @State private var pendingSyncDocument: ScreenplayDocument?
    @State private var pendingSyncFdxData: Data?
    @State private var isSyncingDraft = false
    @State private var syncingDraftId: UUID?
    @ObservedObject private var syncPrefManager = ScriptSyncPreferenceManager.shared

    enum ImportType: String, CaseIterable {
        case finalDraft = "Final Draft (.fdx)"
        case fountain = "Fountain (.fountain)"

        var fileExtension: String {
            switch self {
            case .finalDraft: return "fdx"
            case .fountain: return "fountain"
            }
        }

        var utType: UTType {
            switch self {
            case .finalDraft: return UTType(filenameExtension: "fdx") ?? .xml
            case .fountain: return UTType(filenameExtension: "fountain") ?? .plainText
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            HStack(spacing: 0) {
                // Left side - Recent Scripts
                recentScriptsView
                    .frame(minWidth: 280, maxWidth: 320)

                Divider()

                // Right side - Options
                optionsView
                    .frame(minWidth: 400)
            }
        }
        .frame(width: 720, height: 480)
        .sheet(isPresented: $showNewScriptSheet) {
            NewScriptSheet(dataManager: dataManager, selectedDraftId: $selectedDraftId, onCreated: {
                dismiss()
            })
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [importType.utType],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "An unknown error occurred")
        }
        .alert("Delete Script", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                draftToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let draft = draftToDelete {
                    // Clear selection if we're deleting the currently selected draft
                    if selectedDraftId == draft.id {
                        selectedDraftId = nil
                    }
                    dataManager.deleteDraft(id: draft.id)
                    draftToDelete = nil
                }
            }
        } message: {
            if let draft = draftToDelete {
                Text("Are you sure you want to delete \"\(draft.title)\"? This action cannot be undone.")
            }
        }
        .overlay {
            // Import loading overlay
            if isImporting {
                importLoadingOverlay
            }
        }
        .sheet(isPresented: $showSyncPrompt) {
            if let draftId = pendingSyncDraftId,
               let document = pendingSyncDocument {
                ScriptSyncPromptSheet(
                    draftId: draftId,
                    scriptTitle: document.title,
                    isImport: true,
                    onChoice: { mode in
                        handleSyncChoice(mode: mode, document: document, fdxData: pendingSyncFdxData)
                    }
                )
            }
        }
    }

    // MARK: - Import Loading Overlay

    private var importLoadingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Importing Script")
                    .font(.system(size: 18, weight: .semibold))

                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: importProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text(importStatusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Animated dots indicator
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .opacity(importProgress > Double(index) * 0.33 ? 1.0 : 0.3)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isImporting)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Screenplay Editor")
                    .font(.system(size: 20, weight: .semibold))
                Text("Create a new screenplay or open an existing one")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Recent Scripts

    private var recentScriptsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT SCRIPTS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)

            if dataManager.drafts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No scripts yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Create a new script or import one to get started")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(dataManager.drafts) { draft in
                            recentScriptRow(draft)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func recentScriptRow(_ draft: ScreenplayDraftInfo) -> some View {
        HStack(spacing: 8) {
            // Main button to open the script
            Button(action: {
                print("[Screenplay DEBUG] Selected script: '\(draft.title)' with id: \(draft.id)")
                selectedDraftId = draft.id
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text("\(draft.pageCount) pages")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))

                            Text(draft.updatedAt, style: .date)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: {
                draftToDelete = draft
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.7))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Delete Script")
        }
        .contextMenu {
            Button {
                syncDraftToBreakdowns(draft)
            } label: {
                Label("Sync to Breakdowns", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isSyncingDraft)

            Divider()

            Button(role: .destructive) {
                draftToDelete = draft
                showDeleteConfirmation = true
            } label: {
                Label("Delete Script", systemImage: "trash")
            }
        }
        .overlay {
            if isSyncingDraft && syncingDraftId == draft.id {
                ZStack {
                    Color.black.opacity(0.3)
                        .cornerRadius(8)
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }

    /// Sync an existing draft to Breakdowns manually
    private func syncDraftToBreakdowns(_ draft: ScreenplayDraftInfo) {
        print("🔶🔶🔶 [MANUAL SYNC] syncDraftToBreakdowns CALLED for: \(draft.title) (id: \(draft.id))")

        guard let document = dataManager.loadDocument(id: draft.id) else {
            print("🔶 [MANUAL SYNC] ERROR: Could not load document for draft \(draft.id)")
            return
        }

        print("🔶 [MANUAL SYNC] Loaded document: '\(document.title)'")
        print("🔶 [MANUAL SYNC] document.elements.count = \(document.elements.count)")
        print("🔶 [MANUAL SYNC] document.scenes.count = \(document.scenes.count)")

        // Debug: show first few scenes
        for (i, scene) in document.scenes.prefix(3).enumerated() {
            print("🔶 [MANUAL SYNC] Scene[\(i)]: number='\(scene.number)' heading='\(scene.heading.prefix(50))'")
        }

        isSyncingDraft = true
        syncingDraftId = draft.id

        Task {
            await syncToBreakdowns(document: document, fdxData: nil)

            await MainActor.run {
                isSyncingDraft = false
                syncingDraftId = nil
                print("🔶 [MANUAL SYNC] Sync complete")
            }
        }
    }

    // MARK: - Options

    private var optionsView: some View {
        VStack(spacing: 24) {
            // New Script Card
            optionCard(
                icon: "plus.circle.fill",
                iconColor: .green,
                title: "New Script",
                description: "Start writing a new screenplay from scratch",
                action: { showNewScriptSheet = true }
            )

            // Import Section
            VStack(alignment: .leading, spacing: 12) {
                Text("IMPORT SCRIPT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    importButton(
                        icon: "doc.badge.arrow.up",
                        title: "Final Draft",
                        subtitle: ".fdx files",
                        type: .finalDraft
                    )

                    importButton(
                        icon: "text.alignleft",
                        title: "Fountain",
                        subtitle: ".fountain files",
                        type: .fountain
                    )
                }
            }

            Spacer()

            // Info footer
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Scripts are saved automatically as you type")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 11))
                    Text("Supports scripts up to 500+ pages")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
    }

    private func optionCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func importButton(
        icon: String,
        title: String,
        subtitle: String,
        type: ImportType
    ) -> some View {
        Button(action: {
            importType = type
            showImportPicker = true
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
    }

    // MARK: - Import Handler

    private func handleImport(result: Result<[URL], Error>) {
        print("🔶🔶🔶 [IMPORT DEBUG] handleImport CALLED")
        switch result {
        case .success(let urls):
            print("🔶 [IMPORT DEBUG] Success - urls count: \(urls.count)")
            guard let url = urls.first else {
                print("🔶 [IMPORT DEBUG] No URL in array - returning")
                return
            }
            print("🔶 [IMPORT DEBUG] URL: \(url.path)")
            print("🔶 [IMPORT DEBUG] importType: \(importType.rawValue)")

            // Reset progress state
            importProgress = 0.0
            importStatusMessage = "Reading file..."
            isImporting = true

            Task {
                do {
                    // Step 1: Access file
                    await MainActor.run {
                        importProgress = 0.1
                        importStatusMessage = "Accessing file..."
                    }

                    let securityAccessed = url.startAccessingSecurityScopedResource()
                    defer { if securityAccessed { url.stopAccessingSecurityScopedResource() } }

                    // Step 2: Read file data
                    await MainActor.run {
                        importProgress = 0.2
                        importStatusMessage = "Reading file data..."
                    }

                    let fileData = try Data(contentsOf: url)

                    // Step 3: Parse script
                    await MainActor.run {
                        importProgress = 0.4
                        importStatusMessage = "Parsing script elements..."
                    }

                    let document = try await importScript(from: url, type: importType)

                    // Step 4: Create draft
                    await MainActor.run {
                        importProgress = 0.6
                        importStatusMessage = "Creating screenplay document..."
                    }

                    // Small delay for visual feedback
                    try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

                    await MainActor.run {
                        importProgress = 0.8
                        importStatusMessage = "Saving to database..."

                        if let id = dataManager.createDraft(
                            title: document.title,
                            author: document.author,
                            elements: document.elements,
                            importedFrom: importType.rawValue
                        ) {
                            selectedDraftId = id

                            // Complete the import progress
                            importProgress = 1.0
                            importStatusMessage = "Complete!"

                            Task {
                                // Brief pause to show completion
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                                await MainActor.run {
                                    isImporting = false

                                    print("🔶🔶🔶 [IMPORT DEBUG] Import complete - checking sync settings")
                                    print("🔶 [IMPORT DEBUG] askOnNewScript = \(syncPrefManager.askOnNewScript)")
                                    print("🔶 [IMPORT DEBUG] defaultMode = \(syncPrefManager.defaultMode.rawValue)")
                                    print("🔶 [IMPORT DEBUG] draft id = \(id)")
                                    print("🔶 [IMPORT DEBUG] document.title = \(document.title)")
                                    print("🔶 [IMPORT DEBUG] document.scenes.count = \(document.scenes.count)")

                                    // Check if we should show the sync prompt
                                    if syncPrefManager.askOnNewScript {
                                        print("🔶 [IMPORT DEBUG] Will show sync prompt")
                                        // Store pending sync data and show prompt
                                        pendingSyncDraftId = id
                                        pendingSyncDocument = document
                                        pendingSyncFdxData = importType == .finalDraft ? fileData : nil
                                        showSyncPrompt = true
                                    } else {
                                        print("🔶 [IMPORT DEBUG] Using default mode without prompt")
                                        // Use default preference without asking
                                        let defaultMode = syncPrefManager.defaultMode
                                        syncPrefManager.setSyncMode(defaultMode, for: id)

                                        if defaultMode == .autoSync {
                                            print("🔶 [IMPORT DEBUG] Default mode is autoSync - syncing...")
                                            // Auto-sync to Breakdowns
                                            Task {
                                                await syncToBreakdowns(
                                                    document: document,
                                                    fdxData: importType == .finalDraft ? fileData : nil
                                                )
                                            }
                                        } else {
                                            print("🔶 [IMPORT DEBUG] Default mode is NOT autoSync - skipping")
                                        }
                                        dismiss()
                                    }
                                }
                            }
                        } else {
                            isImporting = false
                        }
                    }
                } catch {
                    print("[Import DEBUG] Import failed with error: \(error)")
                    print("[Import DEBUG] Error localized: \(error.localizedDescription)")
                    await MainActor.run {
                        importError = error.localizedDescription
                        isImporting = false
                        importProgress = 0.0
                    }
                }
            }

        case .failure(let error):
            print("[Import DEBUG] File picker failed: \(error)")
            importError = error.localizedDescription
        }
    }

    /// Handle the user's sync choice from the prompt
    private func handleSyncChoice(mode: ScriptSyncMode, document: ScreenplayDocument, fdxData: Data?) {
        print("🔶🔶🔶 [SYNC DEBUG] handleSyncChoice CALLED")
        print("🔶 [SYNC DEBUG] mode = \(mode.rawValue)")
        print("🔶 [SYNC DEBUG] document.title = \(document.title)")
        print("🔶 [SYNC DEBUG] document.scenes.count = \(document.scenes.count)")
        print("🔶 [SYNC DEBUG] fdxData = \(fdxData != nil ? "\(fdxData!.count) bytes" : "nil")")

        // Clear pending state
        pendingSyncDraftId = nil
        pendingSyncDocument = nil
        pendingSyncFdxData = nil

        if mode == .autoSync {
            print("🔶 [SYNC DEBUG] Mode is autoSync - will call syncToBreakdowns")
            // Sync to Breakdowns - wait for completion before dismissing
            Task {
                print("🔶 [SYNC DEBUG] Inside Task - about to call syncToBreakdowns")
                await syncToBreakdowns(document: document, fdxData: fdxData)
                print("🔶 [SYNC DEBUG] syncToBreakdowns returned - now dismissing")
                await MainActor.run {
                    dismiss()
                }
            }
        } else {
            print("🔶 [SYNC DEBUG] Mode is NOT autoSync (\(mode.rawValue)) - skipping sync")
            // Dismiss immediately if not syncing
            print("🔶 [SYNC DEBUG] About to dismiss welcome sheet")
            dismiss()
        }
    }

    /// Sync imported script to all apps (Breakdowns, Scheduler, Shot List, Design, etc.)
    /// These apps share SceneEntity via Core Data and auto-update through StripStore
    private func syncToBreakdowns(document: ScreenplayDocument, fdxData: Data?) async {
        print("🔶🔶🔶 [SYNC DEBUG] syncToBreakdowns ENTERED")
        print("🔶 [SYNC DEBUG] fdxData = \(fdxData != nil ? "\(fdxData!.count) bytes" : "nil")")
        print("🔶 [SYNC DEBUG] document.scenes.count = \(document.scenes.count)")

        // Use the shared persistence controller's context to ensure consistency across all apps
        // This is more reliable than the environment context which may not be set up properly in sheets
        let syncContext = PersistenceController.shared.container.viewContext
        print("🔶 [SYNC DEBUG] Got syncContext from PersistenceController.shared")

        // Debug: Check if project exists
        let projectFetch = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        projectFetch.fetchLimit = 1
        do {
            let projects = try syncContext.fetch(projectFetch)
            print("🔶 [SYNC DEBUG] Found \(projects.count) ProjectEntity in database")
            if let project = projects.first {
                print("🔶 [SYNC DEBUG] Project ID: \(project.value(forKey: "id") ?? "nil")")
            }
        } catch {
            print("🔶 [SYNC DEBUG] ERROR fetching projects: \(error)")
        }

        // Debug: Check scene count BEFORE sync
        let sceneFetchBefore = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
        do {
            let scenesBefore = try syncContext.fetch(sceneFetchBefore)
            print("🔶 [SYNC DEBUG] Scene count BEFORE sync: \(scenesBefore.count)")
        } catch {
            print("🔶 [SYNC DEBUG] ERROR fetching scenes before: \(error)")
        }

        do {
            var syncedCount = 0

            if let fdxData = fdxData {
                // Use FDX data directly for best fidelity (preserves scene numbers, page lengths, etc.)
                print("🔶 [SYNC DEBUG] Taking FDX path - calling syncFDXToBreakdowns...")
                syncedCount = try await ScreenplayBreakdownSync.shared.syncFDXToBreakdowns(
                    fdxData: fdxData,
                    context: syncContext
                )
                print("🔶 [SYNC DEBUG] syncFDXToBreakdowns returned: \(syncedCount) scenes")
            } else {
                // Fall back to document-based sync for non-FDX imports
                print("🔶 [SYNC DEBUG] Taking document path - calling syncToBreakdowns...")
                syncedCount = try await ScreenplayBreakdownSync.shared.syncToBreakdowns(
                    document: document,
                    context: syncContext,
                    clearExisting: true  // Clear existing scenes to prevent duplicates
                )
                print("🔶 [SYNC DEBUG] syncToBreakdowns returned: \(syncedCount) scenes")
            }

            // Debug: Check scene count AFTER sync
            let sceneFetchAfter = NSFetchRequest<NSManagedObject>(entityName: "SceneEntity")
            let scenesAfter = try syncContext.fetch(sceneFetchAfter)
            print("🔶 [SYNC DEBUG] Scene count AFTER sync: \(scenesAfter.count)")

            // Debug: Check if scriptText is populated
            if let firstScene = scenesAfter.first {
                let scriptText = firstScene.value(forKey: "scriptText") as? String
                print("🔶 [SYNC DEBUG] First scene scriptText: \(scriptText != nil ? "\(scriptText!.prefix(100))..." : "nil")")
            }

            // Notify all apps that screenplay sync is complete
            // Add a small delay to ensure context is fully synced
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            print("🔶 [SYNC DEBUG] Posting screenplayBreakdownSyncCompleted notification")
            await MainActor.run {
                NotificationCenter.default.post(name: .screenplayBreakdownSyncCompleted, object: nil)
                // Also post prStoreDidSwitch to trigger app-wide refresh
                NotificationCenter.default.post(name: .prStoreDidSwitch, object: nil)
            }
            print("🔶 [SYNC DEBUG] ✅ SYNC COMPLETE - \(syncedCount) scenes synced")
        } catch {
            print("🔶🔶🔶 [SYNC DEBUG] ❌❌❌ SYNC FAILED")
            print("🔶 [SYNC DEBUG] Error: \(error)")
            print("🔶 [SYNC DEBUG] Error localized: \(error.localizedDescription)")
        }
        print("🔶🔶🔶 [SYNC DEBUG] syncToBreakdowns EXITING")
    }

    private func importScript(from url: URL, type: ImportType) async throws -> ScreenplayDocument {
        print("[Import DEBUG] importScript called for URL: \(url.lastPathComponent), type: \(type.rawValue)")

        guard url.startAccessingSecurityScopedResource() else {
            print("[Import DEBUG] Failed to access security scoped resource")
            throw ImportError.accessDenied
        }
        defer {
            url.stopAccessingSecurityScopedResource()
            print("[Import DEBUG] Released security scoped resource")
        }

        print("[Import DEBUG] Reading file data...")
        let data = try Data(contentsOf: url)
        print("[Import DEBUG] Read \(data.count) bytes")

        switch type {
        case .finalDraft:
            print("[Import DEBUG] Parsing as Final Draft...")
            return try parseFinalDraft(data: data, filename: url.lastPathComponent)
        case .fountain:
            print("[Import DEBUG] Parsing as Fountain...")
            return try parseFountain(data: data, filename: url.lastPathComponent)
        }
    }

    private func parseFinalDraft(data: Data, filename: String) throws -> ScreenplayDocument {
        print("[Import DEBUG] parseFinalDraft called with \(data.count) bytes, filename: \(filename)")

        // Use the robust FDXConverter which properly handles multiple Text elements per paragraph
        let converter = FDXConverter()

        // DEBUG: Enable verbose logging via FDX_DEBUG=1 environment variable
        converter.debugMode = ProcessInfo.processInfo.environment["FDX_DEBUG"] == "1"

        print("[Import DEBUG] Trying FDXConverter...")
        if let result = converter.convert(from: data) {
            print("[Import DEBUG] FDXConverter succeeded - title: '\(result.document.title)', elements: \(result.document.elements.count)")
            return result.document
        }
        print("[Import DEBUG] FDXConverter returned nil, falling back to simple parser...")

        // Fallback to simple parsing if FDXConverter fails
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("[Import DEBUG] Could not convert data to UTF-8 string")
            throw ImportError.invalidFormat
        }
        print("[Import DEBUG] Converted to XML string, length: \(xmlString.count)")

        var elements: [ScriptElement] = []
        var title = filename.replacingOccurrences(of: ".fdx", with: "")
        var author = ""

        // Simple XML parsing for FDX
        let parser = FDXSimpleParser(xmlString: xmlString)
        let result = parser.parse()

        title = result.title.isEmpty ? title : result.title
        author = result.author
        elements = result.elements

        return ScreenplayDocument(
            title: title,
            author: author,
            elements: elements
        )
    }

    private func parseFountain(data: Data, filename: String) throws -> ScreenplayDocument {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidFormat
        }

        var elements: [ScriptElement] = []
        var title = filename.replacingOccurrences(of: ".fountain", with: "")
        var author = ""

        let lines = text.components(separatedBy: .newlines)
        var inTitlePage = true
        var previousLineEmpty = true

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Title page handling
            if inTitlePage {
                if trimmed.isEmpty {
                    inTitlePage = false
                    continue
                }
                if trimmed.lowercased().hasPrefix("title:") {
                    title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    continue
                }
                if trimmed.lowercased().hasPrefix("author:") {
                    author = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    continue
                }
                if !trimmed.contains(":") {
                    inTitlePage = false
                }
            }

            // Skip empty lines but track them
            if trimmed.isEmpty {
                previousLineEmpty = true
                continue
            }

            // Detect element type
            let elementType: ScriptElementType
            var elementText = trimmed

            if let detected = ScriptElementType.detect(from: trimmed) {
                elementType = detected
            } else if trimmed.hasPrefix("@") {
                // Forced character
                elementType = .character
                elementText = String(trimmed.dropFirst())
            } else if trimmed.hasPrefix("!") {
                // Forced action
                elementType = .action
                elementText = String(trimmed.dropFirst())
            } else if trimmed.hasPrefix(">") && !trimmed.hasSuffix("<") {
                // Transition
                elementType = .transition
                elementText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if previousLineEmpty && trimmed == trimmed.uppercased() && trimmed.count > 1 && !trimmed.contains(".") {
                // Likely a character name (all caps after blank line)
                elementType = .character
            } else if elements.last?.type == .character || elements.last?.type == .parenthetical {
                // Following character or parenthetical, likely dialogue
                elementType = .dialogue
            } else {
                elementType = .action
            }

            elements.append(ScriptElement(type: elementType, text: elementText))
            previousLineEmpty = false
        }

        return ScreenplayDocument(
            title: title,
            author: author,
            elements: elements.isEmpty ? [ScriptElement(type: .action, text: "")] : elements
        )
    }

    enum ImportError: LocalizedError {
        case accessDenied
        case invalidFormat
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Could not access the selected file"
            case .invalidFormat: return "The file format is not supported"
            case .parsingFailed: return "Failed to parse the script file"
            }
        }
    }
}

// MARK: - Simple FDX Parser

private class FDXSimpleParser {
    private let xmlString: String

    init(xmlString: String) {
        self.xmlString = xmlString
    }

    struct ParseResult {
        var title: String = ""
        var author: String = ""
        var elements: [ScriptElement] = []
    }

    func parse() -> ParseResult {
        var result = ParseResult()

        // Extract title - capture all Text elements in the title paragraph
        do {
            let titlePattern = "<TitlePage>.*?<Content>.*?<Paragraph>(.*?)</Paragraph>"
            let titleRegex = try NSRegularExpression(pattern: titlePattern, options: .dotMatchesLineSeparators)
            let range = NSRange(xmlString.startIndex..., in: xmlString)
            if let titleMatch = titleRegex.firstMatch(in: xmlString, options: [], range: range),
               let matchRange = Range(titleMatch.range, in: xmlString) {
                let fullMatch = String(xmlString[matchRange])
                let titleText = extractAllTextContent(from: fullMatch)
                if !titleText.isEmpty {
                    result.title = titleText
                }
            }
        } catch {
            print("[FDXSimpleParser] ERROR: Failed to parse title: \(error)")
        }

        // Parse paragraphs - capture the entire paragraph content to extract all Text elements
        let paragraphPattern = "<Paragraph[^>]*Type=\"([^\"]+)\"[^>]*>(.*?)</Paragraph>"

        do {
            let regex = try NSRegularExpression(pattern: paragraphPattern, options: .dotMatchesLineSeparators)
            let range = NSRange(xmlString.startIndex..., in: xmlString)
            let matches = regex.matches(in: xmlString, options: [], range: range)

            for match in matches {
                if let typeRange = Range(match.range(at: 1), in: xmlString),
                   let contentRange = Range(match.range(at: 2), in: xmlString) {
                    let typeString = String(xmlString[typeRange])
                    let paragraphContent = String(xmlString[contentRange])

                    // Extract ALL text from multiple <Text> elements within this paragraph
                    let text = extractAllTextContent(from: paragraphContent)

                    guard !text.isEmpty else { continue }

                    let elementType = mapFDXType(typeString)
                    result.elements.append(ScriptElement(type: elementType, text: text))
                }
            }
        } catch {
            print("[ScreenplayWelcomeSheet] ERROR: Failed to create regex for FDX parsing: \(error)")
        }

        if result.elements.isEmpty {
            result.elements = [ScriptElement(type: .action, text: "")]
        }

        return result
    }

    /// Extract all text content from multiple <Text> elements within a paragraph
    private func extractAllTextContent(from content: String) -> String {
        var combinedText = ""

        // Match all <Text>...</Text> elements and concatenate their content
        let textPattern = "<Text[^>]*>(.*?)</Text>"
        do {
            let textRegex = try NSRegularExpression(pattern: textPattern, options: [.dotMatchesLineSeparators])
            let range = NSRange(content.startIndex..., in: content)
            let textMatches = textRegex.matches(in: content, options: [], range: range)

            for textMatch in textMatches {
                if let textRange = Range(textMatch.range(at: 1), in: content) {
                    combinedText += String(content[textRange])
                }
            }
        } catch {
            print("[FDXSimpleParser] ERROR: Failed to extract text content: \(error)")
        }

        // Clean up XML entities
        combinedText = combinedText.replacingOccurrences(of: "&amp;", with: "&")
        combinedText = combinedText.replacingOccurrences(of: "&lt;", with: "<")
        combinedText = combinedText.replacingOccurrences(of: "&gt;", with: ">")
        combinedText = combinedText.replacingOccurrences(of: "&apos;", with: "'")
        combinedText = combinedText.replacingOccurrences(of: "&quot;", with: "\"")

        // Also handle nested Style elements that might contain text
        // Remove any remaining XML tags that might have slipped through
        combinedText = combinedText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return combinedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mapFDXType(_ fdxType: String) -> ScriptElementType {
        switch fdxType.lowercased() {
        case "scene heading", "slug line": return .sceneHeading
        case "action", "description": return .action
        case "character": return .character
        case "dialogue": return .dialogue
        case "parenthetical": return .parenthetical
        case "transition": return .transition
        case "shot": return .shot
        default: return .action
        }
    }
}

// MARK: - New Script Sheet

struct NewScriptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dataManager: ScreenplayDataManager
    @Binding var selectedDraftId: UUID?
    var onCreated: () -> Void

    @State private var scriptTitle = ""
    @State private var authorName = ""
    @State private var isCreating = false
    @FocusState private var isTitleFocused: Bool

    // Sync prompt state
    @State private var showSyncPrompt = false
    @State private var pendingSyncDraftId: UUID?
    @State private var pendingScriptTitle: String = ""
    @ObservedObject private var syncPrefManager = ScriptSyncPreferenceManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Screenplay")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(16)

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Untitled Screenplay", text: $scriptTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                        .focused($isTitleFocused)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Author (optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Your name", text: $authorName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                }
            }
            .padding(20)

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Create Script") {
                    createScript()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
            }
            .padding(16)
        }
        .frame(width: 400, height: 280)
        .onAppear {
            isTitleFocused = true
        }
        .sheet(isPresented: $showSyncPrompt) {
            ScriptSyncPromptSheet(
                draftId: pendingSyncDraftId ?? UUID(),
                scriptTitle: pendingScriptTitle,
                isImport: false,
                onChoice: { mode in
                    handleSyncChoice(mode: mode)
                }
            )
        }
    }

    private func createScript() {
        isCreating = true

        let title = scriptTitle.isEmpty ? "Untitled Screenplay" : scriptTitle

        if let id = dataManager.createDraft(
            title: title,
            author: authorName,
            elements: nil,
            importedFrom: nil
        ) {
            selectedDraftId = id

            // Check if we should show the sync prompt
            if syncPrefManager.askOnNewScript {
                // Store pending sync data and show prompt
                pendingSyncDraftId = id
                pendingScriptTitle = title
                isCreating = false
                showSyncPrompt = true
            } else {
                // Use default preference without asking
                let defaultMode = syncPrefManager.defaultMode
                syncPrefManager.setSyncMode(defaultMode, for: id)

                // For new empty scripts, we don't sync immediately since there's no content
                // The sync will happen when the user adds content and it makes sense

                isCreating = false
                onCreated()
            }
        } else {
            isCreating = false
        }
    }

    private func handleSyncChoice(mode: ScriptSyncMode) {
        print("[NewScriptSheet] User chose sync mode: \(mode.rawValue)")

        // Clear pending state
        pendingSyncDraftId = nil
        pendingScriptTitle = ""

        // Call the completion handler
        onCreated()
    }
}

// MARK: - Preview

#Preview {
    ScreenplayWelcomeSheet(
        selectedDraftId: .constant(nil),
        dataManager: ScreenplayDataManager.shared
    )
}
