import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct ScriptSupervisingViewer: View {
    @Environment(\.managedObjectContext) private var context

    @State private var selectedSection: ScriptyViewerSection = .linedScript

    enum ScriptyViewerSection: String, CaseIterable, Identifiable {
        case linedScript = "Lined Script"
        case sceneTiming = "Scene Timing"
        case coverageChecklist = "Coverage"
        case scriptNotes = "Script Notes"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .linedScript: return "text.line.first.and.arrowtriangle.forward"
            case .sceneTiming: return "clock.fill"
            case .coverageChecklist: return "checkmark.circle.fill"
            case .scriptNotes: return "note.text"
            }
        }

        var color: Color {
            switch self {
            case .linedScript: return .pink
            case .sceneTiming: return .orange
            case .coverageChecklist: return .green
            case .scriptNotes: return .purple
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section picker
            sectionPicker

            Divider()

            // Content
            switch selectedSection {
            case .linedScript:
                LinedScriptViewerContent()
            case .sceneTiming:
                SceneTimingViewerContent()
            case .coverageChecklist:
                CoverageChecklistViewerContent()
            case .scriptNotes:
                ScriptNotesViewerContent()
            }
        }
    }

    // MARK: - Section Picker

    @ViewBuilder
    private var sectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(ScriptyViewerSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.system(size: 14))
                        Text(section.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSection == section ? section.color.opacity(0.15) : Color.clear)
                    )
                    .foregroundStyle(selectedSection == section ? section.color : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(12)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }
}

// MARK: - Lined Script Viewer Content

struct LinedScriptViewerContent: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SceneEntity.sortIndex, ascending: true)],
        animation: .default
    )
    private var scenes: FetchedResults<SceneEntity>

    @State private var zoomLevel: Double = 1.0

    var body: some View {
        if scenes.isEmpty {
            EmptyStateView(
                "No Script Loaded",
                systemImage: "text.page.fill",
                description: "Import a screenplay to view lined script"
            )
        } else {
            VStack(spacing: 0) {
                // View Only banner + zoom controls
                HStack {
                    // View Only indicator
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 11))
                        Text("VIEW ONLY")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )

                    Spacer()

                    // Page count
                    Text("\(scenes.count) scenes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()
                        .frame(height: 16)

                    // Zoom controls
                    HStack(spacing: 8) {
                        Button {
                            withAnimation { zoomLevel = max(0.5, zoomLevel - 0.1) }
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(zoomLevel * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 40)

                        Button {
                            withAnimation { zoomLevel = min(2.0, zoomLevel + 0.1) }
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation { zoomLevel = 1.0 }
                        } label: {
                            Text("Reset")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                #if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
                #else
                .background(Color(uiColor: .secondarySystemBackground))
                #endif

                Divider()

                // Script content - PDF style
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        ForEach(scenes) { scene in
                            ScriptPageView(scene: scene)
                        }
                    }
                    .padding(40)
                    .scaleEffect(zoomLevel)
                    .frame(
                        width: 612 * zoomLevel, // US Letter width in points
                        alignment: .top
                    )
                }
                #if os(macOS)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                #else
                .background(Color(uiColor: .systemGroupedBackground).opacity(0.5))
                #endif
            }
        }
    }
}

// MARK: - Script Page View (PDF-style)

struct ScriptPageView: View {
    let scene: SceneEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scene heading
            sceneHeading
                .padding(.bottom, 12)

            // Script content
            if let scriptText = scene.scriptText, !scriptText.isEmpty {
                scriptContent(scriptText)
            } else {
                Text("(No script content)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(.horizontal, 72) // Standard screenplay margins (1 inch)
        .padding(.vertical, 24)
        .frame(width: 612, alignment: .leading) // US Letter width
        .background(Color.white)
        .overlay(
            Rectangle()
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var sceneHeading: some View {
        HStack(spacing: 0) {
            // Scene number (left margin)
            Text(scene.number ?? "")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 40, alignment: .leading)

            // Scene slug (uppercase, as per screenplay format)
            Text((scene.sceneSlug ?? "INT. LOCATION - DAY").uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))

            Spacer()

            // Scene number (right margin - traditional format)
            Text(scene.number ?? "")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 40, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func scriptContent(_ text: String) -> some View {
        // Parse and display script text with proper formatting
        let lines = text.components(separatedBy: .newlines)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                scriptLine(line)
            }
        }
    }

    @ViewBuilder
    private func scriptLine(_ line: String) -> some View {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        if trimmedLine.isEmpty {
            // Empty line
            Text(" ")
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 14)
        } else if isCharacterName(trimmedLine) {
            // Character name - centered
            Text(trimmedLine.uppercased())
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.leading, 144) // Character names indented ~2.5 inches from action
                .padding(.trailing, 72)
                .padding(.top, 12)
        } else if isParenthetical(trimmedLine) {
            // Parenthetical - under character name
            Text(trimmedLine)
                .font(.system(size: 12, design: .monospaced))
                .padding(.leading, 120)
                .padding(.trailing, 144)
        } else if isDialogue(line) {
            // Dialogue - indented
            Text(trimmedLine)
                .font(.system(size: 12, design: .monospaced))
                .padding(.leading, 72)
                .padding(.trailing, 72)
        } else if isTransition(trimmedLine) {
            // Transition - right aligned
            Text(trimmedLine.uppercased())
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 12)
                .padding(.bottom, 12)
        } else {
            // Action/description - full width
            Text(trimmedLine)
                .font(.system(size: 12, design: .monospaced))
                .padding(.top, line.hasPrefix("\n\n") ? 12 : 0)
        }
    }

    // MARK: - Line Type Detection

    private func isCharacterName(_ line: String) -> Bool {
        // Character names are typically all caps, no punctuation except (V.O.) or (O.S.)
        let cleaned = line.replacingOccurrences(of: "(V.O.)", with: "")
            .replacingOccurrences(of: "(O.S.)", with: "")
            .replacingOccurrences(of: "(O.C.)", with: "")
            .replacingOccurrences(of: "(CONT'D)", with: "")
            .trimmingCharacters(in: .whitespaces)

        return cleaned == cleaned.uppercased() &&
               cleaned.count > 1 &&
               cleaned.count < 40 &&
               !cleaned.contains(":") &&
               !isTransition(line)
    }

    private func isParenthetical(_ line: String) -> Bool {
        line.hasPrefix("(") && line.hasSuffix(")")
    }

    private func isDialogue(_ line: String) -> Bool {
        // Dialogue typically has leading whitespace (indented)
        line.hasPrefix("    ") || line.hasPrefix("\t")
    }

    private func isTransition(_ line: String) -> Bool {
        let transitions = ["CUT TO:", "FADE OUT.", "FADE IN:", "DISSOLVE TO:",
                          "SMASH CUT TO:", "MATCH CUT TO:", "JUMP CUT TO:",
                          "FADE TO BLACK.", "THE END", "CONTINUED:"]
        return transitions.contains { line.uppercased().contains($0) }
    }
}

// MARK: - Scene Timing Viewer Content

struct SceneTimingViewerContent: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SceneEntity.sortIndex, ascending: true)],
        animation: .default
    )
    private var scenes: FetchedResults<SceneEntity>

    var body: some View {
        if scenes.isEmpty {
            EmptyStateView(
                "No Scenes",
                systemImage: "clock.fill",
                description: "Import scenes to track timing"
            )
        } else {
            VStack(spacing: 0) {
                // Summary bar
                HStack(spacing: 24) {
                    TimingSummary(title: "Est. Total", value: estimatedTotal, color: .orange)
                    TimingSummary(title: "Actual Total", value: "—", color: .green)
                    TimingSummary(title: "Variance", value: "—", color: .gray)
                    Spacer()
                }
                .padding(16)
                #if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
                #else
                .background(Color(uiColor: .secondarySystemBackground))
                #endif

                Divider()

                // Scene list
                List {
                    ForEach(scenes) { scene in
                        LiveSceneTimingRow(scene: scene)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var estimatedTotal: String {
        let totalEighths = scenes.reduce(0) { $0 + Int($1.pageEighths) }
        let minutes = totalEighths // Rough estimate: 1 eighth = 1 minute
        return "\(minutes) min"
    }
}

struct TimingSummary: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

struct LiveSceneTimingRow: View {
    let scene: SceneEntity

    var body: some View {
        HStack {
            Text(scene.number ?? "—")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(scene.sceneSlug ?? "Scene")
                    .font(.subheadline)
                if let pageEighths = scene.pageEighthsString {
                    Text(pageEighths)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Timing info (placeholder)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Est: \(scene.pageEighths) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Actual: —")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Coverage Checklist Viewer Content

struct CoverageChecklistViewerContent: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SceneEntity.sortIndex, ascending: true)],
        animation: .default
    )
    private var scenes: FetchedResults<SceneEntity>

    var body: some View {
        if scenes.isEmpty {
            EmptyStateView(
                "No Scenes",
                systemImage: "checkmark.circle.fill",
                description: "Import scenes to track coverage"
            )
        } else {
            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 16) {
                    Text("Coverage Progress")
                        .font(.headline)

                    ProgressView(value: 0.0)
                        .frame(maxWidth: 200)

                    Text("0%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(16)
                #if os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
                #else
                .background(Color(uiColor: .secondarySystemBackground))
                #endif

                Divider()

                // Scene list with coverage
                List {
                    ForEach(scenes) { scene in
                        CoverageSceneRow(scene: scene)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct CoverageSceneRow: View {
    let scene: SceneEntity

    private var shots: [ShotEntity] {
        let shotSet = scene.shots as? Set<ShotEntity>
        return (shotSet ?? []).sorted { $0.index < $1.index }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scene \(scene.number ?? "—")")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(shots.count) shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if shots.isEmpty {
                Text("No shots defined")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60), spacing: 8)
                ], spacing: 8) {
                    ForEach(shots) { shot in
                        CoverageShotBadge(shot: shot)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct CoverageShotBadge: View {
    let shot: ShotEntity

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle")
                .font(.system(size: 10))
            Text(shot.code ?? "—")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }
}

// MARK: - Script Notes Viewer Content

struct ScriptNotesViewerContent: View {
    var body: some View {
        EmptyStateView(
            "Script Notes",
            systemImage: "note.text",
            description: "Script supervisor notes will appear here"
        )
    }
}

#Preview {
    ScriptSupervisingViewer()
}
