import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct TeleprompterView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: LiveModeStore

    @State private var settings = TeleprompterSettings.default
    @State private var isPlaying: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showSettings: Bool = false
    @State private var selectedScenes: Set<String> = []
    @State private var isFullScreen: Bool = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SceneEntity.sortIndex, ascending: true)],
        animation: .default
    )
    private var scenes: FetchedResults<SceneEntity>

    var body: some View {
        contentView
            .sheet(isPresented: $showSettings) {
                TeleprompterSettingsSheet(settings: $settings, isPresented: $showSettings)
            }
    }

    @ViewBuilder
    private var contentView: some View {
        #if os(macOS)
        HSplitView {
            // Left: Scene selector
            if !isFullScreen {
                sceneSelector
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
            }

            // Right: Teleprompter display
            teleprompterDisplay
                .frame(minWidth: 500)
        }
        #else
        NavigationSplitView {
            if !isFullScreen {
                sceneSelector
            }
        } detail: {
            teleprompterDisplay
        }
        #endif
    }

    // MARK: - Scene Selector

    @ViewBuilder
    private var sceneSelector: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scenes")
                    .font(.headline)

                Spacer()

                Button {
                    if selectedScenes.count == scenes.count {
                        selectedScenes.removeAll()
                    } else {
                        selectedScenes = Set(scenes.compactMap { $0.number })
                    }
                } label: {
                    Text(selectedScenes.count == scenes.count ? "Deselect All" : "Select All")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif

            Divider()

            // Scene list
            if scenes.isEmpty {
                EmptyStateView(
                    "No Scenes",
                    systemImage: "doc.text",
                    description: "Import a screenplay to use the teleprompter"
                )
            } else {
                List(selection: $selectedScenes) {
                    ForEach(scenes) { scene in
                        SceneSelectionRow(scene: scene, isSelected: selectedScenes.contains(scene.number ?? ""))
                            .tag(scene.number ?? "")
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Selected count
            HStack {
                Text("\(selectedScenes.count) scenes selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemBackground))
            #endif
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    // MARK: - Teleprompter Display

    @ViewBuilder
    private var teleprompterDisplay: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Controls bar (when not fullscreen)
                if !isFullScreen {
                    controlsBar
                }

                // Script display
                GeometryReader { geometry in
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            scriptContent
                                .frame(minHeight: geometry.size.height)
                                .id("scriptContent")
                        }
                        .onChange(of: scrollOffset) { newOffset in
                            // Handle auto-scroll when playing
                        }
                    }
                }

                // Playback controls
                playbackControls
            }
        }
        .onTapGesture(count: 2) {
            withAnimation {
                isFullScreen.toggle()
            }
        }
    }

    // MARK: - Controls Bar

    @ViewBuilder
    private var controlsBar: some View {
        HStack(spacing: 16) {
            // Mirror toggle
            Toggle(isOn: $settings.mirrorMode) {
                Label("Mirror", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
            }
            .toggleStyle(.button)

            Divider()
                .frame(height: 20)

            // Font size
            HStack(spacing: 8) {
                Text("Size:")
                    .foregroundStyle(.secondary)
                Slider(value: $settings.fontSize, in: 24...96, step: 4)
                    .frame(width: 100)
                Text("\(Int(settings.fontSize))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }

            Divider()
                .frame(height: 20)

            // Speed
            HStack(spacing: 8) {
                Text("Speed:")
                    .foregroundStyle(.secondary)
                Slider(value: $settings.scrollSpeed, in: 10...150, step: 5)
                    .frame(width: 100)
                Text("\(Int(settings.scrollSpeed))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }

            Spacer()

            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)

            // Fullscreen button
            Button {
                withAnimation {
                    isFullScreen = true
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .foregroundStyle(.white)
    }

    // MARK: - Script Content

    @ViewBuilder
    private var scriptContent: some View {
        VStack(alignment: textAlignment, spacing: settings.lineSpacing * 20) {
            // Leading space
            Spacer()
                .frame(height: 100)

            ForEach(selectedScenesList) { scene in
                VStack(alignment: textAlignment, spacing: 16) {
                    // Scene header
                    if settings.showSceneHeaders {
                        Text(scene.sceneSlug ?? "SCENE \(scene.number ?? "")")
                            .font(.system(size: settings.fontSize * 0.6, weight: .bold))
                            .foregroundStyle(.gray)
                            .padding(.bottom, 8)
                    }

                    // Scene text
                    Text(scene.scriptText ?? "")
                        .font(.system(size: settings.fontSize, weight: .medium))
                        .foregroundStyle(.white)
                        .lineSpacing(settings.lineSpacing * 10)
                        .multilineTextAlignment(textMultilineAlignment)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
            }

            // Trailing space
            Spacer()
                .frame(height: 200)
        }
        .scaleEffect(x: settings.mirrorMode ? -1 : 1, y: 1)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Playback Controls

    @ViewBuilder
    private var playbackControls: some View {
        HStack(spacing: 24) {
            // Rewind
            Button {
                scrollOffset = 0
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            // Stop
            Button {
                isPlaying = false
                scrollOffset = 0
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)

            Spacer()

            // Current time
            Text(store.currentTimeString)
                .font(.system(size: 16, weight: .medium, design: .monospaced))

            // Exit fullscreen (when in fullscreen)
            if isFullScreen {
                Button {
                    withAnimation {
                        isFullScreen = false
                    }
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Helpers

    private var selectedScenesList: [SceneEntity] {
        scenes.filter { selectedScenes.contains($0.number ?? "") }
    }

    private var textAlignment: HorizontalAlignment {
        switch settings.textAlignment {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private var textMultilineAlignment: TextAlignment {
        switch settings.textAlignment {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }
}

// MARK: - Scene Selection Row

struct SceneSelectionRow: View {
    let scene: SceneEntity
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)

            // Scene info
            VStack(alignment: .leading, spacing: 2) {
                Text(scene.number ?? "—")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.blue)

                if let slug = scene.sceneSlug {
                    Text(slug)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Page count
            if let pageEighths = scene.pageEighthsString {
                Text(pageEighths)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Sheet

struct TeleprompterSettingsSheet: View {
    @Binding var settings: TeleprompterSettings
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Teleprompter Settings")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                Section("Display") {
                    Slider(value: $settings.fontSize, in: 24...96, step: 4) {
                        Text("Font Size: \(Int(settings.fontSize))pt")
                    }

                    Slider(value: $settings.lineSpacing, in: 1...3, step: 0.25) {
                        Text("Line Spacing: \(String(format: "%.2f", settings.lineSpacing))")
                    }

                    Picker("Text Alignment", selection: $settings.textAlignment) {
                        Text("Left").tag("leading")
                        Text("Center").tag("center")
                        Text("Right").tag("trailing")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Playback") {
                    Slider(value: $settings.scrollSpeed, in: 10...150, step: 5) {
                        Text("Scroll Speed: \(Int(settings.scrollSpeed)) wpm")
                    }

                    Stepper("Countdown: \(settings.countdownSeconds)s", value: $settings.countdownSeconds, in: 0...10)
                }

                Section("Options") {
                    Toggle("Mirror Mode", isOn: $settings.mirrorMode)
                    Toggle("Show Scene Headers", isOn: $settings.showSceneHeaders)
                    Toggle("Highlight Current Line", isOn: $settings.highlightCurrentLine)
                    Toggle("Show Timecode", isOn: $settings.showTimecode)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    settings = TeleprompterSettings.default
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
    }
}

#Preview {
    TeleprompterView()
        .environmentObject(LiveModeStore())
}
