import SwiftUI
import CoreData
import UniformTypeIdentifiers
import WebKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Shots — Modern scene-based stripboard with refined UI design
#if os(macOS)
struct ShotListerView: View {
    @Environment(\.managedObjectContext) private var moc
    let projectID: NSManagedObjectID

    @State private var scenes: [NSManagedObject] = []
    @State private var selectedScene: NSManagedObject? = nil
    @State private var sidebarWidth: CGFloat = 340
    @State private var selectedView: ShotView = .shots
    @State private var searchText: String = ""
    @State private var refreshID = UUID()

    // Theme support
    @AppStorage("app_theme") private var appTheme: String = "Standard"

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    // Theme-aware colors - Using macOS accent color for highlights
    private var themedAccentColor: Color {
        return Color.accentColor
    }

    private var themedSecondaryAccent: Color {
        return Color.accentColor.opacity(0.7)
    }

    private var themedBackgroundColor: Color {
        switch currentTheme {
        case .standard: return Color(NSColor.controlBackgroundColor)
        case .aqua: return Color(red: 0.14, green: 0.16, blue: 0.18)
        case .neon: return Color(red: 0.05, green: 0.05, blue: 0.08)
        case .retro: return Color.black
        case .cinema: return Color(red: 0.078, green: 0.094, blue: 0.110)  // Letterboxd dark
        }
    }

    private var themedCardBackground: Color {
        switch currentTheme {
        case .standard: return Color.primary.opacity(0.03)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.06)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.05)
        case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157)  // Letterboxd card bg
        }
    }

    private var themedTextColor: Color {
        switch currentTheme {
        case .standard: return .primary
        case .aqua: return Color(red: 0.85, green: 0.88, blue: 0.92)
        case .neon: return .white
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .cinema: return .white
        }
    }

    private var themedSecondaryTextColor: Color {
        switch currentTheme {
        case .standard: return .secondary
        case .aqua: return Color(red: 0.6, green: 0.65, blue: 0.72)
        case .neon: return Color(red: 0.7, green: 0.7, blue: 0.8)
        case .retro: return Color(red: 0.1, green: 0.5, blue: 0.15)
        case .cinema: return Color(red: 0.6, green: 0.6, blue: 0.6)  // Letterboxd gray
        }
    }

    @ViewBuilder
    private var sidebarHeaderBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themedAccentColor.opacity(0.04),
                    themedAccentColor.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if currentTheme == .standard {
                Color.clear.background(.ultraThinMaterial)
            }
        }
    }

    // Top-level toolbar state
    @State private var aspectRatio: String = "4:3"  // Matches default camera sensor
    @State private var selectedCamera: String = "ARRI Alexa Mini"
    @State private var selectedLensPackage: String = "Zeiss Supreme Primes"

    // Top Down canvas state
    @State private var canvasShapes: [CanvasShape] = []
    @State private var selectedShapeID: UUID? = nil
    @State private var selectedTool: DrawingTool = .select
    @State private var showInspectorPanel: Bool = true
    @State private var draggedHandle: ResizeHandle? = nil
    @State private var inspectorWidth: CGFloat = 280
    @State private var isCreatingShape: Bool = false
    @State private var creatingShapeStartPoint: CGPoint = .zero

    // Storyboard expanded scenes state
    @State private var expandedScenes: Set<NSManagedObjectID> = []

    // Storyboard popup state (moved to parent level to persist across refreshes)
    @State private var showStoryboard: Bool = false

    // Storyboard zoom state (persists across view switches)
    @State private var storyboardZoomLevel: CGFloat = 1.0

    // Script Revision Sync
    @ObservedObject private var scriptSyncService = ScriptRevisionSyncService.shared
    @State private var currentScriptRevision: SentRevision? = nil
    @State private var showMergeResultAlert = false
    @State private var lastMergeResult: MergeResult? = nil
    @State private var isLoadingScriptRevision = false

    // Browser popup state
    @State private var showBrowserPopup: Bool = false
    @State private var browserURL: String = "https://www.pinterest.com/search/pins/?q=film%20storyboard%20reference"

    // Clipboard state for cut/copy/paste
    @State private var copiedImageData: Data? = nil
    @State private var copiedShotID: NSManagedObjectID? = nil
    @State private var isCutOperation: Bool = false

    // Shot clipboard for full shot copy/paste
    @State private var copiedShotData: [String: Any]? = nil
    @State private var selectedShotForClipboard: NSManagedObjectID? = nil

    // Computed storyboard card dimensions based on aspect ratio
    private var storyboardCardWidth: CGFloat {
        return 280
    }

    private var storyboardCardHeight: CGFloat {
        // Parse aspect ratio string (e.g., "2.39:1", "16:9", "4:3")
        let components = aspectRatio.split(separator: ":")
        guard components.count == 2,
              let widthRatio = Double(components[0]),
              let heightRatio = Double(components[1]),
              widthRatio > 0, heightRatio > 0 else {
            return 180 // Default height if parsing fails
        }

        let ratio = widthRatio / heightRatio
        return storyboardCardWidth / ratio
    }

    // Camera sensor native aspect ratios
    private func sensorAspectRatio(for camera: String) -> String {
        switch camera {
        // ARRI - Various sensor sizes
        case "ARRI Alexa Mini", "ARRI Alexa SXT W", "ARRI Amira":
            return "4:3"  // Super 35 4-perf (1.55:1 open gate, commonly used in 4:3 mode)
        case "ARRI Alexa Mini LF", "ARRI Alexa LF":
            return "1.44:1"  // Large Format open gate
        case "ARRI Alexa 35":
            return "4:3"  // Super 35 4:3 open gate
        case "ARRI Alexa 65":
            return "16:9"  // 65mm format, 1.78:1 native

        // RED - Mostly 16:9 sensors
        case "RED Komodo", "RED Komodo-X":
            return "16:9"  // Super 35, 6K
        case "RED V-Raptor", "RED V-Raptor XL":
            return "16:9"  // Vista Vision 8K
        case "RED Ranger":
            return "16:9"  // Monstro/Helium sensor options
        case "RED DSMC2":
            return "16:9"  // Various sensors, 16:9 common
        case "RED Monstro 8K VV":
            return "16:9"  // Vista Vision
        case "RED Helium 8K S35", "RED Gemini 5K S35", "RED Dragon-X 5K S35":
            return "16:9"  // Super 35

        // Blackmagic - Mix of 16:9 and wider
        case "Blackmagic URSA Mini Pro 12K":
            return "16:9"  // Super 35, 12K
        case "Blackmagic URSA Mini Pro 4.6K G2":
            return "16:9"  // Super 35
        case "Blackmagic URSA Cine 12K":
            return "16:9"  // Full frame
        case "Blackmagic URSA Broadcast G2":
            return "16:9"  // Broadcast format
        case "Blackmagic Pocket Cinema Camera 6K Pro", "Blackmagic Pocket Cinema Camera 6K G2":
            return "16:9"  // Super 35
        case "Blackmagic Pocket Cinema Camera 4K":
            return "16:9"  // Micro Four Thirds
        case "Blackmagic Cinema Camera 6K":
            return "16:9"  // Full frame
        case "Blackmagic Pyxis 6K":
            return "16:9"  // Full frame

        // Sony - Full frame 3:2 and Cinema line
        case "Sony Venice", "Sony Venice 2":
            return "3:2"  // Full frame 6K (1.5:1)
        case "Sony FX9":
            return "3:2"  // Full frame
        case "Sony FX6", "Sony FX3":
            return "3:2"  // Full frame
        case "Sony FX30":
            return "16:9"  // APS-C / Super 35
        case "Sony A7S III", "Sony A7 IV", "Sony A7R V", "Sony A1", "Sony A9 III":
            return "3:2"  // Full frame stills/video
        case "Sony FS7 II", "Sony FS5 II":
            return "16:9"  // Super 35
        case "Sony Burano":
            return "3:2"  // Full frame

        // Canon - Cinema and mirrorless
        case "Canon EOS C500 Mark II", "Canon EOS C400":
            return "16:9"  // Full frame cinema
        case "Canon EOS C300 Mark III":
            return "16:9"  // Super 35 DGO
        case "Canon EOS C70", "Canon EOS C80":
            return "16:9"  // Super 35
        case "Canon EOS R5", "Canon EOS R5 C", "Canon EOS R6 Mark II", "Canon EOS R3", "Canon EOS R7", "Canon EOS R8":
            return "3:2"  // Full frame / APS-C stills format

        // Nikon - Full frame 3:2
        case "Nikon Z9", "Nikon Z8", "Nikon Z6 III", "Nikon Z7 II", "Nikon Z5", "Nikon Zf":
            return "3:2"  // Full frame
        case "Nikon Z30", "Nikon Z50":
            return "3:2"  // APS-C (DX)

        // GoPro - Wide action cameras
        case "GoPro HERO13 Black", "GoPro HERO12 Black", "GoPro HERO11 Black", "GoPro HERO11 Black Mini":
            return "16:9"  // Standard video mode (also supports 8:7 for MAX lens)
        case "GoPro MAX":
            return "16:9"  // 360 camera, outputs 16:9

        default:
            return "16:9"  // Default fallback
        }
    }

    // Helper to update camera and aspect ratio together
    private func selectCamera(_ camera: String) {
        selectedCamera = camera
        aspectRatio = sensorAspectRatio(for: camera)
    }

    // Computed statistics for toolbar (project-wide) - simplified to avoid hang
    private var totalShots: Int {
        let relNames = ["shots", "shotItems", "sceneShots", "shotsSet"]
        var total = 0
        for scene in scenes {
            for r in relNames where scene.entity.relationshipsByName.keys.contains(r) {
                if let set = scene.value(forKey: r) as? NSSet {
                    total += set.count
                    break
                }
            }
        }
        return total
    }

    private var totalSetups: Int {
        // Simple count - just return a reasonable estimate based on shots
        return max(totalShots / 3, 1)
    }

    private var scenesWithoutShots: Int {
        let relNames = ["shots", "shotItems", "sceneShots", "shotsSet"]
        return scenes.filter { scene in
            for r in relNames where scene.entity.relationshipsByName.keys.contains(r) {
                if let set = scene.value(forKey: r) as? NSSet, set.count > 0 {
                    return false
                }
            }
            return true
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Unified toolbar: View switcher and camera settings
            unifiedToolbar

            // Main content area
            HSplitView {
                // Left: Scenes sidebar with modern styling (hidden in Storyboard view)
                if selectedView == .topDown {
                    compactSceneSidebar
                        .frame(width: 80)
                } else if selectedView != .storyboard {
                    sceneSidebar
                        .frame(minWidth: 280, idealWidth: sidebarWidth, maxWidth: 420)
                }

                // Right: Content based on selected view
                Group {
                    switch selectedView {
                    case .shots:
                        shotDetailPane
                    case .storyboard:
                        StoryboardView(
                            scenes: scenes,
                            expandedScenes: $expandedScenes,
                            showBrowserPopup: $showBrowserPopup,
                            selectedScene: $selectedScene,
                            selectedView: $selectedView,
                            refreshID: $refreshID,
                            copiedImageData: $copiedImageData,
                            copiedShotID: $copiedShotID,
                            isCutOperation: $isCutOperation,
                            aspectRatio: $aspectRatio,
                            zoomLevel: $storyboardZoomLevel
                        )
                    case .topDown:
                        TopDownShotPlanner(selectedScene: selectedScene, selectedCamera: selectedCamera)
                            .id(selectedScene?.objectID)
                    }
                }
                .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
            }

            // Bottom bar with statistics
            bottomStatsBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accentColor(themedAccentColor)
        .background(themedSidebarBackground)
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: moc)) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("breakdownsSceneSynced"))) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("breakdownsSceneOrderChanged"))) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scriptRevisionSent)) { _ in
            // Refresh to show new revision available indicator
            // The @ObservedObject scriptSyncService will update automatically
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
        .alert("Script Revision Loaded", isPresented: $showMergeResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = lastMergeResult {
                Text(result.summary)
            } else {
                Text("Script revision loaded successfully.")
            }
        }
    }

    @ViewBuilder
    private var themedSidebarBackground: some View {
        switch currentTheme {
        case .aqua:
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.26),
                    Color(red: 0.18, green: 0.20, blue: 0.22),
                    Color(red: 0.15, green: 0.17, blue: 0.19),
                    Color(red: 0.12, green: 0.14, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .retro:
            Color.black
        case .neon:
            ZStack {
                Color.black
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.05),
                        Color.clear,
                        Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .cinema:
            Color(red: 0.078, green: 0.094, blue: 0.110)
        case .standard:
            Color.clear
        }
    }

    @ViewBuilder
    private var sceneSidebar: some View {
        VStack(spacing: 0) {
            // Modern header matching Contacts style
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scenes")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themedTextColor)
                        Text("\(scenes.count) total")
                            .font(.system(size: 11))
                            .foregroundStyle(themedSecondaryTextColor)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    Spacer()

                    // Script Version Menu
                    scriptVersionMenu

                    Button(action: {}) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(themedSecondaryTextColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(sidebarHeaderBackground)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [themedAccentColor.opacity(0.08), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1),
                alignment: .bottom
            )

            // Scene list with refined cards
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(scenes, id: \.objectID) { scene in
                        RefinedSceneCard(
                            scene: scene,
                            isSelected: selectedScene?.objectID == scene.objectID,
                            theme: currentTheme,
                            accentColor: themedAccentColor,
                            textColor: themedTextColor,
                            secondaryTextColor: themedSecondaryTextColor
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedScene = scene
                            }
                        }
                    }
                }
                .padding(12)
            }
            .scrollContentBackground(.hidden)
        }
        .background(themedSidebarBackground)
        .onDisappear { moc.pr_save() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: moc)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("breakdownsSceneOrderChanged"))) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("breakdownsSceneSynced"))) { _ in reload() }
        .onAppear { reload() }
        .onChange(of: projectID) { _ in reload() }
    }

    // MARK: - Compact Scene Sidebar (For Top Down View)
    private var compactSceneSidebar: some View {
        VStack(spacing: 0) {
            // Compact header
            Text("Sc")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themedSecondaryTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(sidebarHeaderBackground)

            Divider()

            // Compact scene list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(scenes, id: \.objectID) { scene in
                        CompactSceneCard(
                            scene: scene,
                            isSelected: selectedScene?.objectID == scene.objectID,
                            accentColor: themedAccentColor,
                            textColor: themedTextColor,
                            secondaryTextColor: themedSecondaryTextColor
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedScene = scene
                            }
                        }
                    }
                }
                .padding(6)
            }
            .scrollContentBackground(.hidden)
        }
        .background(themedSidebarBackground)
    }

    @ViewBuilder
    private var shotDetailPane: some View {
        if let scene = selectedScene {
            RefinedShotListPane(scene: scene, projectID: projectID, aspectRatio: aspectRatio, showStoryboard: $showStoryboard)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.quaternary)
                Text("Select a scene")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Choose a scene from the sidebar to view and edit shots")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Unified Toolbar: View Switcher and Camera Settings
    private var unifiedToolbar: some View {
        HStack(spacing: 16) {
            // View Switcher
            HStack(spacing: 4) {
                ViewSwitcherButton(view: .shots, selectedView: $selectedView, icon: "film.stack", title: "Shots", accentColor: themedAccentColor, textColor: themedTextColor)
                ViewSwitcherButton(view: .storyboard, selectedView: $selectedView, icon: "rectangle.grid.2x2", title: "Reference Shot", accentColor: themedAccentColor, textColor: themedTextColor)
                ViewSwitcherButton(view: .topDown, selectedView: $selectedView, icon: "square.grid.3x3.topleft.filled", title: "Top Down", accentColor: themedAccentColor, textColor: themedTextColor)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(themedCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(themedAccentColor.opacity(0.1), lineWidth: 1)
            )

            Divider()
                .frame(height: 24)

            // Aspect Ratio
            HStack(spacing: 6) {
                Image(systemName: "rectangle.ratio.16.to.9")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themedSecondaryTextColor)

                Menu {
                    Section("Widescreen Cinema") {
                        Button("2.76:1 (Ultra Panavision 70)") { aspectRatio = "2.76:1" }
                        Button("2.39:1 (Anamorphic)") { aspectRatio = "2.39:1" }
                        Button("2.35:1 (CinemaScope)") { aspectRatio = "2.35:1" }
                        Button("2:1 (Univisium)") { aspectRatio = "2:1" }
                        Button("1.85:1 (Flat)") { aspectRatio = "1.85:1" }
                    }
                    Section("IMAX") {
                        Button("1.90:1 (IMAX Digital)") { aspectRatio = "1.90:1" }
                        Button("1.43:1 (IMAX 70mm)") { aspectRatio = "1.43:1" }
                    }
                    Section("Standard") {
                        Button("16:9 (1.78:1)") { aspectRatio = "16:9" }
                        Button("4:3 (1.33:1)") { aspectRatio = "4:3" }
                        Button("1:1 (Square)") { aspectRatio = "1:1" }
                    }
                    Section("Vertical / Mobile") {
                        Button("9:16 (Vertical)") { aspectRatio = "9:16" }
                        Button("4:5 (Instagram Portrait)") { aspectRatio = "4:5" }
                        Button("2:3 (Photo Portrait)") { aspectRatio = "2:3" }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(aspectRatio)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(themedTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(themedAccentColor.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(themedAccentColor.opacity(0.1), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .frame(width: 90)
                .customTooltip(Tooltips.ShotList.aspectRatio)
            }

            Divider()
                .frame(height: 20)

            // Camera
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themedSecondaryTextColor)

                Menu {
                    Section("ARRI") {
                        Button("ARRI Alexa Mini") { selectCamera("ARRI Alexa Mini") }
                        Button("ARRI Alexa Mini LF") { selectCamera("ARRI Alexa Mini LF") }
                        Button("ARRI Alexa 35") { selectCamera("ARRI Alexa 35") }
                        Button("ARRI Alexa LF") { selectCamera("ARRI Alexa LF") }
                        Button("ARRI Alexa SXT W") { selectCamera("ARRI Alexa SXT W") }
                        Button("ARRI Alexa 65") { selectCamera("ARRI Alexa 65") }
                        Button("ARRI Amira") { selectCamera("ARRI Amira") }
                    }
                    Section("RED") {
                        Button("RED Komodo") { selectCamera("RED Komodo") }
                        Button("RED Komodo-X") { selectCamera("RED Komodo-X") }
                        Button("RED V-Raptor") { selectCamera("RED V-Raptor") }
                        Button("RED V-Raptor XL") { selectCamera("RED V-Raptor XL") }
                        Button("RED Ranger") { selectCamera("RED Ranger") }
                        Button("RED DSMC2") { selectCamera("RED DSMC2") }
                        Button("RED Monstro 8K VV") { selectCamera("RED Monstro 8K VV") }
                        Button("RED Helium 8K S35") { selectCamera("RED Helium 8K S35") }
                        Button("RED Gemini 5K S35") { selectCamera("RED Gemini 5K S35") }
                        Button("RED Dragon-X 5K S35") { selectCamera("RED Dragon-X 5K S35") }
                    }
                    Section("Blackmagic") {
                        Button("Blackmagic URSA Mini Pro 12K") { selectCamera("Blackmagic URSA Mini Pro 12K") }
                        Button("Blackmagic URSA Mini Pro 4.6K G2") { selectCamera("Blackmagic URSA Mini Pro 4.6K G2") }
                        Button("Blackmagic URSA Cine 12K") { selectCamera("Blackmagic URSA Cine 12K") }
                        Button("Blackmagic URSA Broadcast G2") { selectCamera("Blackmagic URSA Broadcast G2") }
                        Button("Blackmagic Pocket Cinema Camera 6K Pro") { selectCamera("Blackmagic Pocket Cinema Camera 6K Pro") }
                        Button("Blackmagic Pocket Cinema Camera 6K G2") { selectCamera("Blackmagic Pocket Cinema Camera 6K G2") }
                        Button("Blackmagic Pocket Cinema Camera 4K") { selectCamera("Blackmagic Pocket Cinema Camera 4K") }
                        Button("Blackmagic Cinema Camera 6K") { selectCamera("Blackmagic Cinema Camera 6K") }
                        Button("Blackmagic Pyxis 6K") { selectCamera("Blackmagic Pyxis 6K") }
                    }
                    Section("Sony") {
                        Button("Sony Venice") { selectCamera("Sony Venice") }
                        Button("Sony Venice 2") { selectCamera("Sony Venice 2") }
                        Button("Sony FX9") { selectCamera("Sony FX9") }
                        Button("Sony FX6") { selectCamera("Sony FX6") }
                        Button("Sony FX3") { selectCamera("Sony FX3") }
                        Button("Sony FX30") { selectCamera("Sony FX30") }
                        Button("Sony A7S III") { selectCamera("Sony A7S III") }
                        Button("Sony A7 IV") { selectCamera("Sony A7 IV") }
                        Button("Sony A7R V") { selectCamera("Sony A7R V") }
                        Button("Sony A1") { selectCamera("Sony A1") }
                        Button("Sony A9 III") { selectCamera("Sony A9 III") }
                        Button("Sony FS7 II") { selectCamera("Sony FS7 II") }
                        Button("Sony FS5 II") { selectCamera("Sony FS5 II") }
                        Button("Sony Burano") { selectCamera("Sony Burano") }
                    }
                    Section("Canon") {
                        Button("Canon EOS C500 Mark II") { selectCamera("Canon EOS C500 Mark II") }
                        Button("Canon EOS C400") { selectCamera("Canon EOS C400") }
                        Button("Canon EOS C300 Mark III") { selectCamera("Canon EOS C300 Mark III") }
                        Button("Canon EOS C70") { selectCamera("Canon EOS C70") }
                        Button("Canon EOS C80") { selectCamera("Canon EOS C80") }
                        Button("Canon EOS R5") { selectCamera("Canon EOS R5") }
                        Button("Canon EOS R5 C") { selectCamera("Canon EOS R5 C") }
                        Button("Canon EOS R6 Mark II") { selectCamera("Canon EOS R6 Mark II") }
                        Button("Canon EOS R3") { selectCamera("Canon EOS R3") }
                        Button("Canon EOS R7") { selectCamera("Canon EOS R7") }
                        Button("Canon EOS R8") { selectCamera("Canon EOS R8") }
                    }
                    Section("Nikon") {
                        Button("Nikon Z9") { selectCamera("Nikon Z9") }
                        Button("Nikon Z8") { selectCamera("Nikon Z8") }
                        Button("Nikon Z6 III") { selectCamera("Nikon Z6 III") }
                        Button("Nikon Z7 II") { selectCamera("Nikon Z7 II") }
                        Button("Nikon Z5") { selectCamera("Nikon Z5") }
                        Button("Nikon Zf") { selectCamera("Nikon Zf") }
                        Button("Nikon Z30") { selectCamera("Nikon Z30") }
                        Button("Nikon Z50") { selectCamera("Nikon Z50") }
                    }
                    Section("GoPro") {
                        Button("GoPro HERO13 Black") { selectCamera("GoPro HERO13 Black") }
                        Button("GoPro HERO12 Black") { selectCamera("GoPro HERO12 Black") }
                        Button("GoPro HERO11 Black") { selectCamera("GoPro HERO11 Black") }
                        Button("GoPro HERO11 Black Mini") { selectCamera("GoPro HERO11 Black Mini") }
                        Button("GoPro MAX") { selectCamera("GoPro MAX") }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCamera)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(themedTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(themedAccentColor.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(themedAccentColor.opacity(0.1), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .frame(width: 140)
                .customTooltip(Tooltips.ShotList.cameraSelector)
            }

            Divider()
                .frame(height: 20)

            // Lens Package with + button
            HStack(spacing: 6) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themedSecondaryTextColor)

                Menu {
                    // ZEISS
                    Section("Zeiss") {
                        Button("Zeiss Supreme Primes") { selectedLensPackage = "Zeiss Supreme Primes" }
                        Button("Zeiss Master Primes") { selectedLensPackage = "Zeiss Master Primes" }
                        Button("Zeiss Master Anamorphic") { selectedLensPackage = "Zeiss Master Anamorphic" }
                        Button("Zeiss CP.3") { selectedLensPackage = "Zeiss CP.3" }
                        Button("Zeiss CP.3 XD") { selectedLensPackage = "Zeiss CP.3 XD" }
                        Button("Zeiss Nano Primes") { selectedLensPackage = "Zeiss Nano Primes" }
                        Button("Zeiss Standard Primes") { selectedLensPackage = "Zeiss Standard Primes" }
                        Button("Zeiss Ultra Primes") { selectedLensPackage = "Zeiss Ultra Primes" }
                    }
                    // COOKE
                    Section("Cooke") {
                        Button("Cooke S4/i") { selectedLensPackage = "Cooke S4/i" }
                        Button("Cooke S5/i") { selectedLensPackage = "Cooke S5/i" }
                        Button("Cooke S7/i") { selectedLensPackage = "Cooke S7/i" }
                        Button("Cooke S8/i") { selectedLensPackage = "Cooke S8/i" }
                        Button("Cooke Panchro/i Classic") { selectedLensPackage = "Cooke Panchro/i Classic" }
                        Button("Cooke Anamorphic/i") { selectedLensPackage = "Cooke Anamorphic/i" }
                        Button("Cooke Anamorphic/i SF") { selectedLensPackage = "Cooke Anamorphic/i SF" }
                        Button("Cooke Anamorphic/i Full Frame+") { selectedLensPackage = "Cooke Anamorphic/i Full Frame+" }
                        Button("Cooke SP3") { selectedLensPackage = "Cooke SP3" }
                        Button("Cooke miniS4/i") { selectedLensPackage = "Cooke miniS4/i" }
                    }
                    // ARRI
                    Section("ARRI") {
                        Button("ARRI Signature Primes") { selectedLensPackage = "ARRI Signature Primes" }
                        Button("ARRI Signature Zooms") { selectedLensPackage = "ARRI Signature Zooms" }
                        Button("ARRI Master Primes") { selectedLensPackage = "ARRI Master Primes" }
                        Button("ARRI Master Anamorphic") { selectedLensPackage = "ARRI Master Anamorphic" }
                        Button("ARRI Ultra Primes") { selectedLensPackage = "ARRI Ultra Primes" }
                        Button("ARRI/Zeiss Ultra Wide Zoom") { selectedLensPackage = "ARRI/Zeiss Ultra Wide Zoom" }
                        Button("ARRI/Zeiss Lightweight Zoom") { selectedLensPackage = "ARRI/Zeiss Lightweight Zoom" }
                        Button("ARRI/Fujinon Alura Zooms") { selectedLensPackage = "ARRI/Fujinon Alura Zooms" }
                    }
                    // PANAVISION
                    Section("Panavision") {
                        Button("Panavision Primo 70") { selectedLensPackage = "Panavision Primo 70" }
                        Button("Panavision Primo Primes") { selectedLensPackage = "Panavision Primo Primes" }
                        Button("Panavision Primo Artiste") { selectedLensPackage = "Panavision Primo Artiste" }
                        Button("Panavision Ultra Vista") { selectedLensPackage = "Panavision Ultra Vista" }
                        Button("Panavision G Series Anamorphic") { selectedLensPackage = "Panavision G Series Anamorphic" }
                        Button("Panavision T Series Anamorphic") { selectedLensPackage = "Panavision T Series Anamorphic" }
                        Button("Panavision C Series Anamorphic") { selectedLensPackage = "Panavision C Series Anamorphic" }
                        Button("Panavision E Series Anamorphic") { selectedLensPackage = "Panavision E Series Anamorphic" }
                        Button("Panavision Ultra Panatar") { selectedLensPackage = "Panavision Ultra Panatar" }
                        Button("Panavision Sphero 65") { selectedLensPackage = "Panavision Sphero 65" }
                        Button("Panavision Super Speed Z") { selectedLensPackage = "Panavision Super Speed Z" }
                        Button("Panavision PVintage") { selectedLensPackage = "Panavision PVintage" }
                        Button("Panavision H Series") { selectedLensPackage = "Panavision H Series" }
                    }
                    // LEICA
                    Section("Leica") {
                        Button("Leica Summicron-C") { selectedLensPackage = "Leica Summicron-C" }
                        Button("Leica Summilux-C") { selectedLensPackage = "Leica Summilux-C" }
                        Button("Leica Thalia") { selectedLensPackage = "Leica Thalia" }
                        Button("Leica M 0.8") { selectedLensPackage = "Leica M 0.8" }
                        Button("Leitz Prime") { selectedLensPackage = "Leitz Prime" }
                        Button("Leitz Zoom") { selectedLensPackage = "Leitz Zoom" }
                        Button("Leitz HUGO") { selectedLensPackage = "Leitz HUGO" }
                    }
                    // SIGMA
                    Section("Sigma") {
                        Button("Sigma Cine FF High Speed Primes") { selectedLensPackage = "Sigma Cine FF High Speed Primes" }
                        Button("Sigma Cine FF Classic Primes") { selectedLensPackage = "Sigma Cine FF Classic Primes" }
                        Button("Sigma Cine Zooms") { selectedLensPackage = "Sigma Cine Zooms" }
                    }
                    // CANON
                    Section("Canon") {
                        Button("Canon Sumire Primes") { selectedLensPackage = "Canon Sumire Primes" }
                        Button("Canon CN-E Primes") { selectedLensPackage = "Canon CN-E Primes" }
                        Button("Canon CN-E Zooms") { selectedLensPackage = "Canon CN-E Zooms" }
                        Button("Canon K35") { selectedLensPackage = "Canon K35" }
                        Button("Canon Flex Zoom") { selectedLensPackage = "Canon Flex Zoom" }
                    }
                    // SONY
                    Section("Sony") {
                        Button("Sony CineAlta 4K Primes") { selectedLensPackage = "Sony CineAlta 4K Primes" }
                        Button("Sony CineAlta 4K Zooms") { selectedLensPackage = "Sony CineAlta 4K Zooms" }
                        Button("Sony G Master Primes") { selectedLensPackage = "Sony G Master Primes" }
                    }
                    // TOKINA
                    Section("Tokina") {
                        Button("Tokina Vista Primes") { selectedLensPackage = "Tokina Vista Primes" }
                        Button("Tokina Vista One") { selectedLensPackage = "Tokina Vista One" }
                        Button("Tokina Cinema ATX Zooms") { selectedLensPackage = "Tokina Cinema ATX Zooms" }
                    }
                    // ANGENIEUX
                    Section("Angénieux") {
                        Button("Angénieux Optimo Primes") { selectedLensPackage = "Angénieux Optimo Primes" }
                        Button("Angénieux Optimo Ultra 12x") { selectedLensPackage = "Angénieux Optimo Ultra 12x" }
                        Button("Angénieux Optimo Ultra Compact") { selectedLensPackage = "Angénieux Optimo Ultra Compact" }
                        Button("Angénieux EZ Zooms") { selectedLensPackage = "Angénieux EZ Zooms" }
                        Button("Angénieux Type EZ") { selectedLensPackage = "Angénieux Type EZ" }
                    }
                    // FUJINON
                    Section("Fujinon") {
                        Button("Fujinon Premista Zooms") { selectedLensPackage = "Fujinon Premista Zooms" }
                        Button("Fujinon Cabrio Zooms") { selectedLensPackage = "Fujinon Cabrio Zooms" }
                        Button("Fujinon XK Zooms") { selectedLensPackage = "Fujinon XK Zooms" }
                        Button("Fujinon MK Zooms") { selectedLensPackage = "Fujinon MK Zooms" }
                    }
                    // ANAMORPHIC SPECIALTY
                    Section("Anamorphic Specialty") {
                        Button("Atlas Orion Anamorphic") { selectedLensPackage = "Atlas Orion Anamorphic" }
                        Button("Atlas Mercury Anamorphic") { selectedLensPackage = "Atlas Mercury Anamorphic" }
                        Button("Hawk V-Lite Anamorphic") { selectedLensPackage = "Hawk V-Lite Anamorphic" }
                        Button("Hawk V-Plus Anamorphic") { selectedLensPackage = "Hawk V-Plus Anamorphic" }
                        Button("Hawk C-Series Anamorphic") { selectedLensPackage = "Hawk C-Series Anamorphic" }
                        Button("Hawk V-Lite 1.3x Anamorphic") { selectedLensPackage = "Hawk V-Lite 1.3x Anamorphic" }
                        Button("Kowa Anamorphic") { selectedLensPackage = "Kowa Anamorphic" }
                        Button("Lomo Anamorphic") { selectedLensPackage = "Lomo Anamorphic" }
                        Button("SLR Magic Anamorphot") { selectedLensPackage = "SLR Magic Anamorphot" }
                        Button("Sirui Anamorphic") { selectedLensPackage = "Sirui Anamorphic" }
                        Button("Vazen Anamorphic") { selectedLensPackage = "Vazen Anamorphic" }
                        Button("DZOFilm Pictor Anamorphic") { selectedLensPackage = "DZOFilm Pictor Anamorphic" }
                        Button("Great Joy Anamorphic") { selectedLensPackage = "Great Joy Anamorphic" }
                    }
                    // VINTAGE / REHOUSED
                    Section("Vintage / Rehoused") {
                        Button("Bausch & Lomb Super Baltar") { selectedLensPackage = "Bausch & Lomb Super Baltar" }
                        Button("Lomo Round Front Anamorphic") { selectedLensPackage = "Lomo Round Front Anamorphic" }
                        Button("Lomo Standard Speeds") { selectedLensPackage = "Lomo Standard Speeds" }
                        Button("Helios 44") { selectedLensPackage = "Helios 44" }
                        Button("Kowa Cine Prominar") { selectedLensPackage = "Kowa Cine Prominar" }
                        Button("Cooke Speed Panchro") { selectedLensPackage = "Cooke Speed Panchro" }
                        Button("Canon FD (Rehoused)") { selectedLensPackage = "Canon FD (Rehoused)" }
                        Button("Canon K35 (Rehoused)") { selectedLensPackage = "Canon K35 (Rehoused)" }
                        Button("Zeiss Contax (Rehoused)") { selectedLensPackage = "Zeiss Contax (Rehoused)" }
                        Button("Zeiss Super Speeds") { selectedLensPackage = "Zeiss Super Speeds" }
                        Button("Xeen CF") { selectedLensPackage = "Xeen CF" }
                        Button("TLS Morpheus") { selectedLensPackage = "TLS Morpheus" }
                        Button("TLS Kowa Evolution") { selectedLensPackage = "TLS Kowa Evolution" }
                        Button("GL Optics Rehoused") { selectedLensPackage = "GL Optics Rehoused" }
                        Button("Zero Optik Rehoused") { selectedLensPackage = "Zero Optik Rehoused" }
                        Button("P+S Technik Rehoused") { selectedLensPackage = "P+S Technik Rehoused" }
                    }
                    // MODERN PRIMES
                    Section("Modern Primes") {
                        Button("XEEN Meister Primes") { selectedLensPackage = "XEEN Meister Primes" }
                        Button("DZOFilm Vespid Primes") { selectedLensPackage = "DZOFilm Vespid Primes" }
                        Button("Meike Cine Primes") { selectedLensPackage = "Meike Cine Primes" }
                        Button("Meike Full Frame Primes") { selectedLensPackage = "Meike Full Frame Primes" }
                        Button("Viltrox Cine Primes") { selectedLensPackage = "Viltrox Cine Primes" }
                        Button("Laowa Ranger Zooms") { selectedLensPackage = "Laowa Ranger Zooms" }
                        Button("Laowa OOOM Zooms") { selectedLensPackage = "Laowa OOOM Zooms" }
                        Button("NiSi Athena Primes") { selectedLensPackage = "NiSi Athena Primes" }
                        Button("7Artisans Cine Primes") { selectedLensPackage = "7Artisans Cine Primes" }
                    }
                    // SPECIALTY / MACRO / PROBE
                    Section("Specialty") {
                        Button("Laowa Probe Lens") { selectedLensPackage = "Laowa Probe Lens" }
                        Button("Laowa Periprobe") { selectedLensPackage = "Laowa Periprobe" }
                        Button("Innovision Probe II+") { selectedLensPackage = "Innovision Probe II+" }
                        Button("Arri Macro") { selectedLensPackage = "Arri Macro" }
                        Button("Zeiss DigiPrime") { selectedLensPackage = "Zeiss DigiPrime" }
                        Button("Lensbaby (Various)") { selectedLensPackage = "Lensbaby (Various)" }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedLensPackage)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(themedTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(themedAccentColor.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(themedAccentColor.opacity(0.1), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .frame(width: 160)
                .customTooltip(Tooltips.ShotList.lensPackage)

                // Add lens button
                Button {
                    // Add lens action
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(themedAccentColor)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(themedAccentColor.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Add Lens")
            }

            Spacer()

            // Action buttons group
            HStack(spacing: 8) {
                // Cut button
                Button {
                    performCut()
                } label: {
                    Image(systemName: "scissors")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedTextColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(themedAccentColor.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(themedAccentColor.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Cut")

                // Copy button
                Button {
                    performCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedTextColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(themedAccentColor.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(themedAccentColor.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Copy")

                // Paste button
                Button {
                    performPaste()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedTextColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(themedAccentColor.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(themedAccentColor.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Paste")

                Divider()
                    .frame(height: 20)

                // Print button
                Button {
                    performPrint()
                } label: {
                    Image(systemName: "printer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedSecondaryAccent)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(themedSecondaryAccent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(themedSecondaryAccent.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Print")

                // Export button
                Button {
                    performExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themedAccentColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(themedAccentColor.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(themedAccentColor.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Export")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(currentTheme == .standard ? AnyView(Color.clear.background(.ultraThinMaterial)) : AnyView(themedBackgroundColor))
        .overlay(
            Rectangle()
                .fill(themedAccentColor.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Script Version Menu
    private var scriptVersionMenu: some View {
        Menu {
            Section("Script Revision") {
                // Current loaded script
                if let revision = currentScriptRevision {
                    HStack {
                        Circle()
                            .fill(revision.color)
                            .frame(width: 8, height: 8)
                        Text(revision.displayName)
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
                                if !revision.loadedInShots {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themedSecondaryTextColor)
                if scriptSyncService.hasUpdatesAvailable(for: .shots) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(themedAccentColor.opacity(0.1))
            )
        }
        .menuStyle(.borderlessButton)
    }

    /// Load a script revision into the shots view
    private func loadScriptRevision(_ revision: SentRevision) {
        guard !isLoadingScriptRevision else { return }
        isLoadingScriptRevision = true

        Task {
            do {
                let result = try await scriptSyncService.loadRevision(
                    revision,
                    into: .shots,
                    context: moc
                )

                currentScriptRevision = revision
                lastMergeResult = result
                showMergeResultAlert = true
            } catch {
                print("[ShotListerView] Failed to load script revision: \(error)")
            }
            isLoadingScriptRevision = false
        }
    }

    // MARK: - Bottom Stats Bar
    private var bottomStatsBar: some View {
        HStack(spacing: 24) {
            // Total Shots
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themedAccentColor)
                Text("\(totalShots)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(themedTextColor)
                Text("Shots")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themedSecondaryTextColor)
            }

            Divider()
                .frame(height: 16)

            // Total Setups
            HStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.purple)
                Text("\(totalSetups)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(themedTextColor)
                Text("Setups")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themedSecondaryTextColor)
            }

            Divider()
                .frame(height: 16)

            // Scenes Unscheduled
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
                Text("\(scenesWithoutShots)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(themedTextColor)
                Text("Scenes Unscheduled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themedSecondaryTextColor)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(currentTheme == .standard ? AnyView(Color(NSColor.windowBackgroundColor)) : AnyView(themedBackgroundColor.opacity(0.95)))
        .overlay(
            Rectangle()
                .fill(themedAccentColor.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Action Methods

    private func performCut() {
        guard let shotID = selectedShotForClipboard,
              let shot = try? moc.existingObject(with: shotID) else {
            NSLog("[ShotLister] Cut: No shot selected")
            return
        }

        // Copy shot data to clipboard
        copyShotToClipboard(shot)
        isCutOperation = true

        // Delete the original shot
        moc.delete(shot)
        moc.pr_save()
        refreshID = UUID()
        selectedShotForClipboard = nil

        NSLog("[ShotLister] Cut shot completed")
    }

    private func performCopy() {
        guard let shotID = selectedShotForClipboard,
              let shot = try? moc.existingObject(with: shotID) else {
            NSLog("[ShotLister] Copy: No shot selected")
            return
        }

        copyShotToClipboard(shot)
        isCutOperation = false
        NSLog("[ShotLister] Copy shot completed")
    }

    private func performPaste() {
        guard let shotData = copiedShotData,
              let scene = selectedScene else {
            NSLog("[ShotLister] Paste: No shot data or scene selected")
            return
        }

        // Create new shot in selected scene
        pasteShotFromClipboard(into: scene, data: shotData)

        // Clear clipboard if it was a cut operation
        if isCutOperation {
            copiedShotData = nil
            isCutOperation = false
        }

        refreshID = UUID()
        NSLog("[ShotLister] Paste shot completed")
    }

    private func copyShotToClipboard(_ shot: NSManagedObject) {
        var data: [String: Any] = [:]

        // Copy all relevant shot properties
        let propertyKeys = [
            "code", "title", "name", "type", "shotType",
            "cam", "camera", "lens", "focalLength",
            "rig", "stabilizer", "support",
            "setupMinutes", "setupTime", "setup",
            "shootMinutes", "shootTime", "duration", "minutes", "durationMinutes",
            "descriptionText", "shotDescription", "desc",
            "productionNotes", "prodNotes", "notesProduction", "notes",
            "screenReference", "screenRef", "reference", "ref",
            "lightingNotes", "lighting", "lightNotes",
            "castID", "castId", "cast", "castMember",
            "color", "shotColor", "setupColor",
            "storyboardImageData"
        ]

        for key in propertyKeys {
            if let value = shot.value(forKey: key) {
                data[key] = value
            }
        }

        copiedShotData = data
        copiedShotID = shot.objectID
    }

    private func pasteShotFromClipboard(into scene: NSManagedObject, data: [String: Any]) {
        // Find the Shot entity
        guard let entity = NSEntityDescription.entity(forEntityName: "Shot", in: moc) else {
            NSLog("[ShotLister] Paste: Could not find Shot entity")
            return
        }

        let newShot = NSManagedObject(entity: entity, insertInto: moc)

        // Set the scene relationship
        let sceneRelationKeys = ["scene", "sceneItem", "parentScene"]
        for key in sceneRelationKeys {
            if entity.relationshipsByName.keys.contains(key) {
                newShot.setValue(scene, forKey: key)
                break
            }
        }

        // Copy properties from clipboard data
        for (key, value) in data {
            if entity.attributesByName.keys.contains(key) {
                newShot.setValue(value, forKey: key)
            }
        }

        // Calculate new index (add to end)
        let shotsRelationKeys = ["shots", "shotItems", "sceneShots", "shotsSet"]
        var existingShots: [NSManagedObject] = []
        for relKey in shotsRelationKeys {
            if let set = scene.value(forKey: relKey) as? NSSet {
                existingShots = set.allObjects as? [NSManagedObject] ?? []
                break
            }
        }

        let maxIndex = existingShots.compactMap { shot in
            (shot.value(forKey: "index") as? Int) ??
            (shot.value(forKey: "order") as? Int) ??
            (shot.value(forKey: "position") as? Int)
        }.max() ?? -1

        // Set index for new shot
        let indexKeys = ["index", "order", "position"]
        for key in indexKeys {
            if entity.attributesByName.keys.contains(key) {
                newShot.setValue(maxIndex + 1, forKey: key)
                break
            }
        }

        // Append "(Copy)" to the shot code/title
        let titleKeys = ["code", "title", "name"]
        for key in titleKeys {
            if let originalTitle = data[key] as? String, entity.attributesByName.keys.contains(key) {
                newShot.setValue("\(originalTitle) (Copy)", forKey: key)
                break
            }
        }

        moc.pr_save()
    }

    private func performPrint() {
        guard let scene = selectedScene else {
            NSLog("[ShotLister] Print: No scene selected")
            return
        }

        // Generate printable shot list
        let printContent = generatePrintableContent(for: scene)
        printShotList(content: printContent)
    }

    private func generatePrintableContent(for scene: NSManagedObject) -> NSAttributedString {
        let content = NSMutableAttributedString()

        // Header style
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.alignment = .center
        headerStyle.paragraphSpacing = 12

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .paragraphStyle: headerStyle
        ]

        // Scene heading - check if key exists before accessing
        var sceneHeading = "Scene"
        if scene.entity.propertiesByName.keys.contains("sceneSlug") {
            sceneHeading = (scene.value(forKey: "sceneSlug") as? String) ?? sceneHeading
        } else if scene.entity.propertiesByName.keys.contains("sceneHeading") {
            sceneHeading = (scene.value(forKey: "sceneHeading") as? String) ?? sceneHeading
        } else if scene.entity.propertiesByName.keys.contains("heading") {
            sceneHeading = (scene.value(forKey: "heading") as? String) ?? sceneHeading
        }
        let sceneNumber = (scene.value(forKey: "number") as? Int) ?? 0

        content.append(NSAttributedString(string: "Scene \(sceneNumber): \(sceneHeading)\n\n", attributes: headerAttrs))

        // Shot list style
        let shotStyle = NSMutableParagraphStyle()
        shotStyle.paragraphSpacing = 8
        shotStyle.tabStops = [
            NSTextTab(textAlignment: .left, location: 60),
            NSTextTab(textAlignment: .left, location: 120),
            NSTextTab(textAlignment: .left, location: 180),
            NSTextTab(textAlignment: .left, location: 280)
        ]

        let shotAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .paragraphStyle: shotStyle
        ]

        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .paragraphStyle: shotStyle
        ]

        // Column headers
        content.append(NSAttributedString(string: "Shot\tType\tCamera\tLens\tDescription\n", attributes: boldAttrs))
        content.append(NSAttributedString(string: String(repeating: "─", count: 80) + "\n", attributes: shotAttrs))

        // Get shots for this scene
        let shotsRelationKeys = ["shots", "shotItems", "sceneShots", "shotsSet"]
        var shots: [NSManagedObject] = []
        for relKey in shotsRelationKeys {
            if let set = scene.value(forKey: relKey) as? NSSet {
                shots = (set.allObjects as? [NSManagedObject] ?? []).sorted { a, b in
                    let ai = (a.value(forKey: "index") as? Int) ?? (a.value(forKey: "order") as? Int) ?? 0
                    let bi = (b.value(forKey: "index") as? Int) ?? (b.value(forKey: "order") as? Int) ?? 0
                    return ai < bi
                }
                break
            }
        }

        // Add each shot
        for shot in shots {
            let code = (shot.value(forKey: "code") as? String) ??
                      (shot.value(forKey: "title") as? String) ?? "—"
            let type = (shot.value(forKey: "type") as? String) ??
                      (shot.value(forKey: "shotType") as? String) ?? "—"
            let cam = (shot.value(forKey: "cam") as? String) ??
                     (shot.value(forKey: "camera") as? String) ?? "—"
            let lens = (shot.value(forKey: "lens") as? String) ??
                      (shot.value(forKey: "focalLength") as? String) ?? "—"
            let desc = (shot.value(forKey: "descriptionText") as? String) ??
                      (shot.value(forKey: "shotDescription") as? String) ?? "—"

            let line = "\(code)\t\(type)\t\(cam)\t\(lens)\t\(desc)\n"
            content.append(NSAttributedString(string: line, attributes: shotAttrs))
        }

        return content
    }

    private func printShotList(content: NSAttributedString) {
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isVerticallyCentered = false
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: printInfo.paperSize.width - 100, height: 10000))
        textView.textStorage?.setAttributedString(content)
        textView.sizeToFit()

        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }

    private func performExport() {
        guard let scene = selectedScene else {
            NSLog("[ShotLister] Export: No scene selected")
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf, .commaSeparatedText]
        savePanel.nameFieldStringValue = "Shot List"
        savePanel.message = "Export shot list"
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            if url.pathExtension.lowercased() == "pdf" {
                self.exportToPDF(scene: scene, url: url)
            } else {
                self.exportToCSV(scene: scene, url: url)
            }
        }
    }

    private func exportToPDF(scene: NSManagedObject, url: URL) {
        let content = generatePrintableContent(for: scene)

        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792) // Letter size
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 512, height: 10000))
        textView.textStorage?.setAttributedString(content)
        textView.sizeToFit()

        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false

        // Create PDF data
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try? pdfData.write(to: url)
        NSLog("[ShotLister] Exported PDF to \(url.path)")

        // Open in Finder
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func exportToCSV(scene: NSManagedObject, url: URL) {
        var csv = "Shot,Type,Camera,Lens,Rig,Setup Time,Shoot Time,Description,Production Notes,Lighting Notes\n"

        // Get shots for this scene
        let shotsRelationKeys = ["shots", "shotItems", "sceneShots", "shotsSet"]
        var shots: [NSManagedObject] = []
        for relKey in shotsRelationKeys {
            if let set = scene.value(forKey: relKey) as? NSSet {
                shots = (set.allObjects as? [NSManagedObject] ?? []).sorted { a, b in
                    let ai = (a.value(forKey: "index") as? Int) ?? (a.value(forKey: "order") as? Int) ?? 0
                    let bi = (b.value(forKey: "index") as? Int) ?? (b.value(forKey: "order") as? Int) ?? 0
                    return ai < bi
                }
                break
            }
        }

        for shot in shots {
            let code = escapeCSV((shot.value(forKey: "code") as? String) ?? (shot.value(forKey: "title") as? String) ?? "")
            let type = escapeCSV((shot.value(forKey: "type") as? String) ?? (shot.value(forKey: "shotType") as? String) ?? "")
            let cam = escapeCSV((shot.value(forKey: "cam") as? String) ?? (shot.value(forKey: "camera") as? String) ?? "")
            let lens = escapeCSV((shot.value(forKey: "lens") as? String) ?? (shot.value(forKey: "focalLength") as? String) ?? "")
            let rig = escapeCSV((shot.value(forKey: "rig") as? String) ?? (shot.value(forKey: "stabilizer") as? String) ?? "")
            let setup = (shot.value(forKey: "setupMinutes") as? Int).map { "\($0)" } ?? ""
            let shoot = (shot.value(forKey: "shootMinutes") as? Int).map { "\($0)" } ?? ""
            let desc = escapeCSV((shot.value(forKey: "descriptionText") as? String) ?? (shot.value(forKey: "shotDescription") as? String) ?? "")
            let prodNotes = escapeCSV((shot.value(forKey: "productionNotes") as? String) ?? "")
            let lightNotes = escapeCSV((shot.value(forKey: "lightingNotes") as? String) ?? "")

            csv += "\(code),\(type),\(cam),\(lens),\(rig),\(setup),\(shoot),\(desc),\(prodNotes),\(lightNotes)\n"
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            NSLog("[ShotLister] Exported CSV to \(url.path)")

            // Open in Finder
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("[ShotLister] Failed to export CSV: \(error)")
        }
    }

    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }

    // MARK: - Browser Popup Pane
    private var browserPopupPane: some View {
        VStack(spacing: 0) {
            // Browser header with URL bar
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
                                    browserURL = "https://www.google.com/search?q=" + browserURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
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
                                    browserURL = "https://www.google.com/search?q=" + currentURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
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
                            browserURL = "https://www.pinterest.com/search/pins/?q=film%20storyboard%20reference"
                        }
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Clear browsing data")

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

            // Web view
            WebView(url: $browserURL)
                .frame(height: 400)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.3), radius: 20, y: -10)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Image Handling Helpers

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

    private func saveImageToShot(nsImage: NSImage, shot: NSManagedObject) {
        // Convert NSImage to Data (JPEG format with compression)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            print("Failed to convert image to data")
            return
        }

        // Save to Core Data
        shot.setValue(imageData, forKey: "storyboardImageData")

        // Save context
        moc.pr_save()

        // Force refresh
        refreshID = UUID()
    }

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

        // Remove from current shot
        shot.setValue(nil, forKey: "storyboardImageData")
        moc.pr_save()
        refreshID = UUID()
    }

    private func handlePasteFromClipboard(shot: NSManagedObject) {
        // First check internal clipboard
        if let imageData = copiedImageData {
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

    // MARK: - Global Keyboard Shortcut Handlers

    private func performDeleteCommand() {
        // Check if text field has focus - let system handle delete
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text delete
            }
        }
        // Delete selected shot if in the shot detail view
        // For now, this is a placeholder - specific deletion would depend on what's selected
    }

    private func performSelectAllCommand() {
        // Check if text field has focus - let system handle select all
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text select all
            }
        }
        // Select all scenes
        // For now, no multi-select is supported in this view
    }

    private func performCutCommand() {
        // Check if text field has focus - let system handle cut
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text cut
            }
        }
        // No-op since this app uses context menu cut for specific shots
    }

    private func performCopyCommand() {
        // Check if text field has focus - let system handle copy
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text copy
            }
        }
        // No-op since this app uses context menu copy for specific shots
    }

    private func performPasteCommand() {
        // Check if text field has focus - let system handle paste
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text paste
            }
        }
        // No-op since this app uses context menu paste for specific shots
    }

    // MARK: - Top Down Canvas View
    private var topDownCanvasView: some View {
        HSplitView {
            // Main canvas area
            VStack(spacing: 0) {
                // Canvas toolbar
                canvasToolbar

                // Canvas with dotted grid
                GeometryReader { geometry in
                    ZStack {
                        // Dotted grid background
                        DottedGridView()
                            .background(Color(NSColor.controlBackgroundColor))

                        // Shapes layer
                        ForEach($canvasShapes) { $shape in
                            ResizableShapeView(
                                shape: $shape,
                                isSelected: selectedShapeID == shape.id,
                                onSelect: {
                                    selectedShapeID = shape.id
                                },
                                onMove: { delta in
                                    if let index = canvasShapes.firstIndex(where: { $0.id == shape.id }) {
                                        canvasShapes[index].position.x += delta.width
                                        canvasShapes[index].position.y += delta.height
                                    }
                                },
                                onResize: { handle, delta in
                                    if let index = canvasShapes.firstIndex(where: { $0.id == shape.id }) {
                                        resizeShape(at: index, handle: handle, delta: delta)
                                    }
                                }
                            )
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if selectedTool != .select {
                                    handleCanvasDragChanged(value, in: geometry.size)
                                }
                            }
                            .onEnded { value in
                                if selectedTool != .select {
                                    handleCanvasDragEnded(value, in: geometry.size)
                                }
                            }
                    )
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .frame(minWidth: 400)

            // Inspector panel
            if showInspectorPanel {
                inspectorPanel
                    .frame(minWidth: 240, idealWidth: inspectorWidth, maxWidth: 400)
            }
        }
    }

    private var canvasToolbar: some View {
        HStack(spacing: 16) {
            // Drawing tools - Basic shapes
            HStack(spacing: 8) {
                ToolButton(tool: .select, selectedTool: $selectedTool, icon: "cursorarrow", title: "Select")
                ToolButton(tool: .rectangle, selectedTool: $selectedTool, icon: "square", title: "Rectangle")
                ToolButton(tool: .circle, selectedTool: $selectedTool, icon: "circle", title: "Circle")
                ToolButton(tool: .triangle, selectedTool: $selectedTool, icon: "triangle", title: "Triangle")
            }

            Divider()
                .frame(height: 20)

            // Production-specific tools
            HStack(spacing: 8) {
                ToolButton(tool: .camera, selectedTool: $selectedTool, icon: "camera.fill", title: "Camera")
                ToolButton(tool: .lighting, selectedTool: $selectedTool, icon: "light.max", title: "Lighting")
                ToolButton(tool: .actor, selectedTool: $selectedTool, icon: "person.fill", title: "Actor")
            }

            Divider()
                .frame(height: 20)

            // Delete button
            Button(action: deleteSelectedShape) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Delete")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selectedShapeID != nil ? Color.red.opacity(0.12) : Color.secondary.opacity(0.1))
                )
                .foregroundStyle(selectedShapeID != nil ? Color.red : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(selectedShapeID == nil)
            .opacity(selectedShapeID != nil ? 1.0 : 0.5)

            Spacer()

            // Inspector toggle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showInspectorPanel.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: showInspectorPanel ? "sidebar.right.fill" : "sidebar.right")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Inspector")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(showInspectorPanel ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1))
                )
                .foregroundStyle(showInspectorPanel ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func handleCanvasDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        guard selectedTool != .select else { return }

        if !isCreatingShape {
            // Start creating a new shape
            isCreatingShape = true
            creatingShapeStartPoint = value.startLocation

            let newShape = CanvasShape(
                type: selectedTool.toShapeType(),
                position: value.startLocation,
                size: CGSize(width: 1, height: 1),
                color: .blue
            )
            canvasShapes.append(newShape)
            selectedShapeID = newShape.id
        } else {
            // Update the size of the shape being created
            if let index = canvasShapes.firstIndex(where: { $0.id == selectedShapeID }) {
                let width = abs(value.location.x - creatingShapeStartPoint.x)
                let height = abs(value.location.y - creatingShapeStartPoint.y)

                // Update position to handle dragging in any direction
                let minX = min(value.location.x, creatingShapeStartPoint.x)
                let minY = min(value.location.y, creatingShapeStartPoint.y)

                canvasShapes[index].position = CGPoint(x: minX, y: minY)
                canvasShapes[index].size = CGSize(width: max(width, 10), height: max(height, 10))
            }
        }
    }

    private func handleCanvasDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        guard selectedTool != .select else { return }

        // Reset creation state
        isCreatingShape = false
        creatingShapeStartPoint = .zero

        // Switch back to select tool
        selectedTool = .select
    }

    // MARK: - Inspector Panel
    private var inspectorPanel: some View {
        VStack(spacing: 0) {
            // Inspector header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Layers")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(canvasShapes.count) objects")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.03))
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Layers list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(canvasShapes.enumerated().reversed()), id: \.element.id) { index, shape in
                        LayerRow(
                            shape: shape,
                            index: canvasShapes.count - 1 - index,
                            isSelected: selectedShapeID == shape.id,
                            onSelect: {
                                selectedShapeID = shape.id
                            },
                            onDelete: {
                                canvasShapes.removeAll { $0.id == shape.id }
                                if selectedShapeID == shape.id {
                                    selectedShapeID = nil
                                }
                            },
                            onDuplicate: {
                                var duplicated = shape
                                duplicated.position.x += 20
                                duplicated.position.y += 20
                                canvasShapes.append(duplicated)
                            }
                        )
                    }
                }
                .padding(8)
            }

            // Attach to shot section (if camera is selected)
            if let selectedID = selectedShapeID,
               let shape = canvasShapes.first(where: { $0.id == selectedID }),
               shape.type == .camera {
                attachToShotSection
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var attachToShotSection: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Attach to Shot")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if let scene = selectedScene {
                    let shots = shotsForScene(scene)
                    if !shots.isEmpty {
                        ForEach(shots, id: \.objectID) { shot in
                            Button(action: {
                                attachCameraToShot(cameraID: selectedShapeID, shot: shot)
                            }) {
                                HStack {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 11))
                                    Text(shotTitle(for: shot))
                                        .font(.system(size: 12))
                                    Spacer()
                                    Image(systemName: "link")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.08))
                                )
                                .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("No shots in this scene")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Select a scene first")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.02))
        }
    }

    private func resizeShape(at index: Int, handle: ResizeHandle, delta: CGSize) {
        var shape = canvasShapes[index]

        switch handle {
        case .topLeft:
            shape.position.x += delta.width
            shape.position.y += delta.height
            shape.size.width -= delta.width
            shape.size.height -= delta.height
        case .topRight:
            shape.position.y += delta.height
            shape.size.width += delta.width
            shape.size.height -= delta.height
        case .bottomLeft:
            shape.position.x += delta.width
            shape.size.width -= delta.width
            shape.size.height += delta.height
        case .bottomRight:
            shape.size.width += delta.width
            shape.size.height += delta.height
        }

        // Ensure minimum size
        shape.size.width = max(20, shape.size.width)
        shape.size.height = max(20, shape.size.height)

        canvasShapes[index] = shape
    }

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

    private func shotTitle(for shot: NSManagedObject) -> String {
        let titleKeys = ["code", "title", "name", "shotCode"]
        for key in titleKeys {
            if let value = shot.value(forKey: key) as? String, !value.isEmpty {
                return value
            }
        }
        return "Untitled Shot"
    }

    private func attachCameraToShot(cameraID: UUID?, shot: NSManagedObject) {
        guard let cameraID = cameraID else { return }
        // Store the camera ID in the shot's metadata
        shot.setValue(cameraID.uuidString, forKey: "attachedCameraID")
        moc.pr_save()
        NSLog("[TopDown] Attached camera \(cameraID) to shot \(shotTitle(for: shot))")
    }

    private func deleteSelectedShape() {
        guard let id = selectedShapeID else { return }
        canvasShapes.removeAll { $0.id == id }
        selectedShapeID = nil
    }

    private func reload() {
        moc.perform {
            let project = try? moc.existingObject(with: projectID)
            guard let entityName = preferredSceneEntityName(moc: moc) else {
                DispatchQueue.main.async {
                    self.scenes = []
                    self.selectedScene = nil
                }
                return
            }

            let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let model = moc.persistentStoreCoordinator?.managedObjectModel,
               let entity = model.entitiesByName[entityName],
               entity.relationshipsByName.keys.contains("project"),
               let project {
                // Exclude day breaks and off days from Shots app
                let projectPredicate = NSPredicate(format: "project == %@", project)

                // Check for sceneHeading or scriptLocation attributes to filter out dividers
                let hasSceneHeading = entity.attributesByName.keys.contains("sceneHeading")
                let hasScriptLocation = entity.attributesByName.keys.contains("scriptLocation")

                if hasSceneHeading || hasScriptLocation {
                    // Build predicate to exclude END OF DAY, DAY BREAK, and OFF DAY
                    var predicates: [NSPredicate] = [projectPredicate]

                    if hasSceneHeading {
                        let notDivider = NSPredicate(format: "NOT (sceneHeading CONTAINS[cd] 'END OF DAY' OR sceneHeading CONTAINS[cd] 'DAY BREAK' OR sceneHeading CONTAINS[cd] 'OFF DAY')")
                        predicates.append(notDivider)
                    }

                    if hasScriptLocation {
                        let notDividerLocation = NSPredicate(format: "NOT (scriptLocation CONTAINS[cd] 'END OF DAY' OR scriptLocation CONTAINS[cd] 'DAY BREAK' OR scriptLocation CONTAINS[cd] 'OFF DAY')")
                        predicates.append(notDividerLocation)
                    }

                    req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                } else {
                    req.predicate = projectPredicate
                }
            }

            // Performance optimizations
            req.fetchBatchSize = 20
            req.returnsObjectsAsFaults = true
            req.relationshipKeyPathsForPrefetching = ["project"]

            // Use exact same sorting logic as StripStore to keep scenes in sync with Breakdowns
            if let model = moc.persistentStoreCoordinator?.managedObjectModel,
               let entity = model.entitiesByName[entityName] {
                let attrs = Set(entity.attributesByName.keys)

                // Match StripStore exactly: displayOrder first, then createdAt
                if attrs.contains("displayOrder") {
                    if attrs.contains("createdAt") {
                        req.sortDescriptors = [
                            NSSortDescriptor(key: "displayOrder", ascending: true),
                            NSSortDescriptor(key: "createdAt", ascending: true)
                        ]
                    } else {
                        req.sortDescriptors = [
                            NSSortDescriptor(key: "displayOrder", ascending: true)
                        ]
                    }
                } else if attrs.contains("createdAt") {
                    req.sortDescriptors = [
                        NSSortDescriptor(key: "createdAt", ascending: true)
                    ]
                } else {
                    req.sortDescriptors = []
                }
            } else {
                req.sortDescriptors = []
            }

            var fetched = (try? moc.fetch(req)) ?? []
            if fetched.isEmpty {
                let allReq = NSFetchRequest<NSManagedObject>(entityName: entityName)

                // Performance optimizations for fallback fetch
                allReq.fetchBatchSize = 20
                allReq.returnsObjectsAsFaults = true
                allReq.relationshipKeyPathsForPrefetching = ["project"]

                // Use exact same sort descriptors as StripStore
                if let model = moc.persistentStoreCoordinator?.managedObjectModel,
                   let entity = model.entitiesByName[entityName] {
                    let attrs = Set(entity.attributesByName.keys)

                    // Match StripStore exactly: displayOrder first, then createdAt
                    if attrs.contains("displayOrder") {
                        if attrs.contains("createdAt") {
                            allReq.sortDescriptors = [
                                NSSortDescriptor(key: "displayOrder", ascending: true),
                                NSSortDescriptor(key: "createdAt", ascending: true)
                            ]
                        } else {
                            allReq.sortDescriptors = [
                                NSSortDescriptor(key: "displayOrder", ascending: true)
                            ]
                        }
                    } else if attrs.contains("createdAt") {
                        allReq.sortDescriptors = [
                            NSSortDescriptor(key: "createdAt", ascending: true)
                        ]
                    } else {
                        allReq.sortDescriptors = []
                    }

                    // Also exclude day breaks from fallback fetch
                    let hasSceneHeading = entity.attributesByName.keys.contains("sceneHeading")
                    let hasScriptLocation = entity.attributesByName.keys.contains("scriptLocation")

                    if hasSceneHeading || hasScriptLocation {
                        var predicates: [NSPredicate] = []

                        if hasSceneHeading {
                            predicates.append(NSPredicate(format: "NOT (sceneHeading CONTAINS[cd] 'END OF DAY' OR sceneHeading CONTAINS[cd] 'DAY BREAK' OR sceneHeading CONTAINS[cd] 'OFF DAY')"))
                        }

                        if hasScriptLocation {
                            predicates.append(NSPredicate(format: "NOT (scriptLocation CONTAINS[cd] 'END OF DAY' OR scriptLocation CONTAINS[cd] 'DAY BREAK' OR scriptLocation CONTAINS[cd] 'OFF DAY')"))
                        }

                        allReq.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                    }
                } else {
                    allReq.sortDescriptors = []
                }
                fetched = (try? moc.fetch(allReq)) ?? []
            }

            // Don't normalize scene ordering - preserve the sortIndex/displayOrder from Breakdowns
            DispatchQueue.main.async {
                self.scenes = fetched
                if let sel = self.selectedScene, fetched.contains(where: { $0.objectID == sel.objectID }) {
                    // keep current selection
                } else {
                    self.selectedScene = fetched.first
                }
            }
        }
    }
}

#else
// iOS version is in ShotListerViewiOS.swift
struct ShotListerView: View {
    let projectID: NSManagedObjectID
    @Environment(\.managedObjectContext) private var moc

    var body: some View {
        Text("Shot List - See ShotListerViewiOS")
    }
}
#endif
