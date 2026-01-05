//
//  StoryboardView.swift
//  Production Runner
//
//  Created by Editing on 11/21/25.
//

import SwiftUI
import CoreData
#if os(macOS)
import AppKit
import WebKit

/// Storyboard view for visualizing shots across all scenes
struct StoryboardView: View {
    @Environment(\.managedObjectContext) private var moc

    let scenes: [NSManagedObject]
    @Binding var expandedScenes: Set<NSManagedObjectID>
    @Binding var showBrowserPopup: Bool
    @Binding var selectedScene: NSManagedObject?
    @Binding var selectedView: ShotView
    @Binding var refreshID: UUID
    @Binding var copiedImageData: Data?
    @Binding var copiedShotID: NSManagedObjectID?
    @Binding var isCutOperation: Bool
    @Binding var aspectRatio: String
    @Binding var zoomLevel: CGFloat

    // Browser state
    @State private var browserURL: String = "https://www.google.com"
    @State private var browserPaneHeight: CGFloat = 400 // Default height, user adjustable

    // Undo/Redo state for storyboard images
    @StateObject private var undoRedoManager = UndoRedoManager<[NSManagedObjectID: Data?]>(maxHistorySize: 10)
    @State private var selectedShotID: NSManagedObjectID? = nil

    // Computed storyboard card dimensions based on aspect ratio and zoom
    private var baseCardWidth: CGFloat {
        return 280
    }

    private var storyboardCardWidth: CGFloat {
        return baseCardWidth * zoomLevel
    }

    private var storyboardCardHeight: CGFloat {
        let components = aspectRatio.split(separator: ":")
        guard components.count == 2,
              let widthRatio = Double(components[0]),
              let heightRatio = Double(components[1]),
              widthRatio > 0, heightRatio > 0 else {
            return 180 * zoomLevel
        }
        let ratio = widthRatio / heightRatio
        return (baseCardWidth / ratio) * zoomLevel
    }

    // Shot field keys for flexible Core Data access
    private let shotTitleKeys = ["code", "title", "name", "notes"]
    private let shotTypeKeys = ["type", "shotType"]
    private let shotCamKeys = ["cam", "camera"]
    private let shotLensKeys = ["lens", "lensType"]
    private let shotRigKeys = ["rig", "rigType"]
    private let shotDescriptionKeys = ["descriptionText", "shotDescription", "desc"]
    private let shotScreenRefKeys = ["screenReference", "screenRef", "reference", "ref"]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main storyboard content
                VStack(spacing: 0) {
                    // Storyboard header
                    storyboardHeader

                    // Master storyboard view - all scenes
                    if scenes.isEmpty {
                        emptyScenesList
                    } else {
                        scenesList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Browser popup pane at bottom
                if showBrowserPopup {
                    VStack(spacing: 0) {
                        // Drag handle for resizing
                        BrowserPaneResizeHandle(height: $browserPaneHeight, minHeight: 200, maxHeight: geometry.size.height * 0.9)

                        browserPopupPane
                    }
                    .frame(height: min(browserPaneHeight, geometry.size.height * 0.9))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .undoRedoSupport(
            canUndo: undoRedoManager.canUndo,
            canRedo: undoRedoManager.canRedo,
            onUndo: performUndo,
            onRedo: performRedo
        )
        .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
            // Select all scenes - expand all
            expandedScenes = Set(scenes.map { $0.objectID })
        }
    }

    // MARK: - Undo/Redo Operations

    private func saveCurrentStateToUndo() {
        var state: [NSManagedObjectID: Data?] = [:]
        for scene in scenes {
            for shot in shotsForScene(scene) {
                let imageData = shot.value(forKey: "storyboardImageData") as? Data
                state[shot.objectID] = imageData
            }
        }
        undoRedoManager.saveState(state)
    }

    private func getCurrentState() -> [NSManagedObjectID: Data?] {
        var state: [NSManagedObjectID: Data?] = [:]
        for scene in scenes {
            for shot in shotsForScene(scene) {
                let imageData = shot.value(forKey: "storyboardImageData") as? Data
                state[shot.objectID] = imageData
            }
        }
        return state
    }

    private func performUndo() {
        guard let previousState = undoRedoManager.undo(currentState: getCurrentState()) else { return }
        restoreState(previousState)
    }

    private func performRedo() {
        guard let nextState = undoRedoManager.redo(currentState: getCurrentState()) else { return }
        restoreState(nextState)
    }

    private func restoreState(_ state: [NSManagedObjectID: Data?]) {
        for (objectID, imageData) in state {
            if let shot = try? moc.existingObject(with: objectID) {
                shot.setValue(imageData, forKey: "storyboardImageData")
            }
        }
        moc.pr_save()
        refreshID = UUID()
    }

    // MARK: - Header

    private var storyboardHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Reference Shot")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            HStack(spacing: 8) {
                // Web search button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showBrowserPopup.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showBrowserPopup ? "globe.americas.fill" : "globe.americas")
                            .font(.system(size: 11, weight: .medium))
                        Text("Web Search")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(showBrowserPopup ? Color.blue : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(showBrowserPopup ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(showBrowserPopup ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Zoom control
                HStack(spacing: 8) {
                    // Zoom out button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomLevel = max(1.0, zoomLevel - 0.25)
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(zoomLevel > 1.0 ? Color.secondary : Color.secondary.opacity(0.5))
                    .disabled(zoomLevel <= 1.0)

                    // Zoom percentage
                    Text("\(Int(zoomLevel * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 40)

                    // Zoom in button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomLevel = min(3.0, zoomLevel + 0.25)
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(zoomLevel < 3.0 ? Color.secondary : Color.secondary.opacity(0.5))
                    .disabled(zoomLevel >= 3.0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )

                // Expand/Collapse all button
                if !scenes.isEmpty {
                    Button(action: {
                        if expandedScenes.isEmpty {
                            expandedScenes = Set(scenes.map { $0.objectID })
                        } else {
                            expandedScenes.removeAll()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: expandedScenes.isEmpty ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .medium))
                            Text(expandedScenes.isEmpty ? "Expand All" : "Collapse All")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
        )
    }

    // MARK: - Empty State

    private var emptyScenesList: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No Scenes")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add scenes to your project to see their storyboards")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Scenes List

    private var scenesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(scenes, id: \.objectID) { scene in
                    sceneStoryboardSection(for: scene)
                }
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Scene Section

    @ViewBuilder
    private func sceneStoryboardSection(for scene: NSManagedObject) -> some View {
        let sceneShots = shotsForScene(scene)
        let isExpanded = expandedScenes.contains(scene.objectID)

        VStack(alignment: .leading, spacing: 0) {
            sceneHeader(for: scene, isExpanded: isExpanded, sceneShots: sceneShots)
            if isExpanded {
                sceneExpandedContent(sceneShots: sceneShots)
            }
        }
    }

    private func sceneHeader(for scene: NSManagedObject, isExpanded: Bool, sceneShots: [NSManagedObject]) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isExpanded {
                    expandedScenes.remove(scene.objectID)
                } else {
                    expandedScenes.insert(scene.objectID)
                }
            }
        }) {
            HStack(spacing: 12) {
                // Expand/collapse chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                // Scene number badge
                if scene.entity.attributesByName.keys.contains("number"),
                   let sceneNumber = scene.value(forKey: "number") as? String,
                   !sceneNumber.isEmpty {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 32, height: 32)
                        Text(sceneNumber)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                // Scene name
                Text(sceneName(for: scene))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .textCase(.uppercase)

                // Shot count badge
                Text("\(sceneShots.count) shot\(sceneShots.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                    )

                Spacer()

                // Quick actions
                if isExpanded {
                    Button(action: {
                        selectedScene = scene
                        selectedView = .shots
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                            Text("View Details")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Scene Content

    @ViewBuilder
    private func sceneExpandedContent(sceneShots: [NSManagedObject]) -> some View {
        if sceneShots.isEmpty {
            emptyStoryboardPlaceholder
        } else {
            storyboardScrollView(for: sceneShots)
        }
    }

    private var emptyStoryboardPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
            Text("No shots in this scene")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .padding(.top, 8)
    }

    @ViewBuilder
    private func storyboardScrollView(for sceneShots: [NSManagedObject]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 16) {
                ForEach(sceneShots, id: \.objectID) { shot in
                    sceneStoryboardCard(for: shot)
                }
            }
            .padding(20)
        }
        .frame(height: storyboardCardHeight + 140) // Card height + padding + details section
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.top, 8)
    }

    // MARK: - Storyboard Cards

    @ViewBuilder
    private func sceneStoryboardCard(for shot: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sceneCardImageArea(for: shot)
            sceneCardDetails(for: shot)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private func sceneCardImageArea(for shot: NSManagedObject) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: storyboardCardWidth, height: storyboardCardHeight)

            sceneCardImage(for: shot)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onDrop(of: [.image], isTargeted: nil) { providers in
            handleImageDrop(providers: providers, shot: shot)
            return true
        }
        .onPasteCommand(of: [.image, .tiff, .png]) { providers in
            handleImagePaste(providers: providers, shot: shot)
        }
        .contextMenu {
            sceneCardContextMenu(for: shot)
        }
    }

    @ViewBuilder
    private func sceneCardImage(for shot: NSManagedObject) -> some View {
        if let imageData = shot.value(forKey: "storyboardImageData") as? Data,
           let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: storyboardCardWidth, height: storyboardCardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let screenRef = stringValue(for: shot, keys: shotScreenRefKeys),
           !screenRef.isEmpty,
           let url = URL(string: screenRef),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: storyboardCardWidth, height: storyboardCardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Drop or Paste Image")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Right-click for options")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func sceneCardDetails(for shot: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = stringValue(for: shot, keys: shotTitleKeys), !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            } else {
                Text("Untitled Shot")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let type = stringValue(for: shot, keys: shotTypeKeys), !type.isEmpty {
                    CompactBadge(text: type, color: .blue)
                }
                if let cam = stringValue(for: shot, keys: shotCamKeys), !cam.isEmpty {
                    CompactBadge(text: cam, color: .green)
                }
                if let lens = stringValue(for: shot, keys: shotLensKeys), !lens.isEmpty {
                    CompactBadge(text: lens, color: .orange)
                }
                if let rig = stringValue(for: shot, keys: shotRigKeys), !rig.isEmpty {
                    CompactBadge(text: rig, color: .purple)
                }
            }

            if let desc = stringValue(for: shot, keys: shotDescriptionKeys), !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(width: storyboardCardWidth, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func sceneCardContextMenu(for shot: NSManagedObject) -> some View {
        Button("Copy Image") {
            handleCopy(shot: shot)
        }
        .disabled(shot.value(forKey: "storyboardImageData") == nil)

        Button("Cut Image") {
            handleCut(shot: shot)
        }
        .disabled(shot.value(forKey: "storyboardImageData") == nil)

        Button("Paste Image") {
            handlePasteFromClipboard(shot: shot)
        }
        .disabled(copiedImageData == nil && NSPasteboard.general.data(forType: .tiff) == nil)

        Divider()

        Button("Remove Image") {
            saveCurrentStateToUndo()
            shot.setValue(nil, forKey: "storyboardImageData")
            moc.pr_save()
            refreshID = UUID()
        }
        .disabled(shot.value(forKey: "storyboardImageData") == nil)
    }

    // MARK: - Helper Functions

    private func shotsForScene(_ scene: NSManagedObject) -> [NSManagedObject] {
        let relNames = ["shots", "shotItems", "sceneShots", "shotsSet"]
        for r in relNames where scene.entity.relationshipsByName.keys.contains(r) {
            if let set = scene.value(forKey: r) as? NSSet {
                let shots = set.allObjects as? [NSManagedObject] ?? []
                return shots.sorted { a, b in
                    let aIndex = (a.value(forKey: "index") as? NSNumber)?.intValue ?? 0
                    let bIndex = (b.value(forKey: "index") as? NSNumber)?.intValue ?? 0
                    return aIndex < bIndex
                }
            }
        }
        return []
    }

    private func sceneName(for scene: NSManagedObject) -> String {
        // Try various key names for scene name
        let nameKeys = ["sceneSlug", "slug", "name", "sceneName", "title"]
        for key in nameKeys {
            if let name = scene.value(forKey: key) as? String, !name.isEmpty {
                return name
            }
        }
        return "Scene"
    }

    // Helper to get string value from object using multiple key options
    private func stringValue(for object: NSManagedObject, keys: [String]) -> String? {
        for key in keys {
            // Check if the entity has this attribute/relationship
            guard object.entity.attributesByName.keys.contains(key) ||
                  object.entity.relationshipsByName.keys.contains(key) else {
                continue
            }

            if let value = object.value(forKey: key) as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    // MARK: - Image Handling

    private func handleImageDrop(providers: [NSItemProvider], shot: NSManagedObject) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, error in
                    guard let nsImage = image as? NSImage else { return }

                    DispatchQueue.main.async {
                        self.saveImageToShot(nsImage: nsImage, shot: shot)
                    }
                }
                break
            }
        }
    }

    private func handleImagePaste(providers: [NSItemProvider], shot: NSManagedObject) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, error in
                    guard let nsImage = image as? NSImage else { return }

                    DispatchQueue.main.async {
                        self.saveImageToShot(nsImage: nsImage, shot: shot)
                    }
                }
                break
            }
        }
    }

    #if os(macOS)
    private func saveImageToShot(nsImage: NSImage, shot: NSManagedObject) {
        // Convert NSImage to Data (JPEG format with compression)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            print("Failed to convert image to data")
            return
        }

        // Save current state for undo
        saveCurrentStateToUndo()

        // Save to Core Data
        shot.setValue(imageData, forKey: "storyboardImageData")

        // Save context
        moc.pr_save()

        // Force refresh
        refreshID = UUID()
    }
    #endif

    // MARK: - Clipboard Operations

    private func handleCopy(shot: NSManagedObject) {
        guard let imageData = shot.value(forKey: "storyboardImageData") as? Data,
              let nsImage = NSImage(data: imageData) else {
            return
        }

        // Copy to internal clipboard state
        copiedImageData = imageData
        copiedShotID = shot.objectID
        isCutOperation = false

        // Also copy to system clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }

    private func handleCut(shot: NSManagedObject) {
        guard let imageData = shot.value(forKey: "storyboardImageData") as? Data else {
            return
        }

        // Copy to internal clipboard state
        copiedImageData = imageData
        copiedShotID = shot.objectID
        isCutOperation = true

        // Also copy to system clipboard
        if let nsImage = NSImage(data: imageData) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
        }

        // Save current state for undo
        saveCurrentStateToUndo()

        // Remove from current shot
        shot.setValue(nil, forKey: "storyboardImageData")
        moc.pr_save()
        refreshID = UUID()
    }

    private func handlePasteFromClipboard(shot: NSManagedObject) {
        // First check internal clipboard
        if let imageData = copiedImageData {
            // Save current state for undo
            saveCurrentStateToUndo()

            shot.setValue(imageData, forKey: "storyboardImageData")

            // If it was a cut operation, clear the clipboard after paste
            if isCutOperation {
                copiedImageData = nil
                copiedShotID = nil
                isCutOperation = false
            }

            moc.pr_save()
            refreshID = UUID()
            return
        }

        // Otherwise try system clipboard
        let pasteboard = NSPasteboard.general
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            if let nsImage = NSImage(data: imageData) {
                saveImageToShot(nsImage: nsImage, shot: shot)
            }
        }
    }

    // MARK: - Browser Popup Pane

    private var browserPopupPane: some View {
        VStack(spacing: 0) {
            // Browser header with URL bar (fixed at top)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // URL text field
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Enter URL or search term", text: $browserURL, onCommit: {
                            // Ensure URL has a scheme
                            if !browserURL.hasPrefix("http://") && !browserURL.hasPrefix("https://") {
                                // If it looks like a search query, use Google
                                if !browserURL.contains(".") || browserURL.contains(" ") {
                                    browserURL = "https://www.google.com/search?q=" + (browserURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
                                } else {
                                    browserURL = "https://" + browserURL
                                }
                            }
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                        // Go button
                        Button(action: {
                            // Trigger the URL load by reassigning
                            let currentURL = browserURL
                            if !currentURL.hasPrefix("http://") && !currentURL.hasPrefix("https://") {
                                if !currentURL.contains(".") || currentURL.contains(" ") {
                                    browserURL = "https://www.google.com/search?q=" + (currentURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
                                } else {
                                    browserURL = "https://" + currentURL
                                }
                            }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )

                    // Delete browsing data button
                    Button(action: {
                        // Clear cookies and cache
                        let dataStore = WKWebsiteDataStore.default()
                        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
                        let date = Date(timeIntervalSince1970: 0)
                        dataStore.removeData(ofTypes: dataTypes, modifiedSince: date) {
                            // Reset URL to Google
                            browserURL = "https://www.google.com"
                        }
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Clear browsing data")

                    // Close button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showBrowserPopup = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(
                Rectangle()
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
            )

            // Help tip
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                Text("Right-click images to copy, then paste onto any shot card")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.05))

            // Web view - flexible height
            WebView(url: $browserURL)
                .frame(minHeight: 300, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.3), radius: 20, y: -10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Supporting Components

private struct CompactBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .textCase(.uppercase)
            .tracking(0.4)
    }
}

// MARK: - Browser Pane Resize Handle

private struct BrowserPaneResizeHandle: View {
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle area
            Rectangle()
                .fill(Color.clear)
                .frame(height: 12)
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isDragging ? Color.blue : Color.secondary.opacity(0.5))
                        .frame(width: 40, height: 4)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            // Dragging up increases height, dragging down decreases
                            let newHeight = height - value.translation.height
                            height = min(maxHeight, max(minHeight, newHeight))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
        )
    }
}
#endif
