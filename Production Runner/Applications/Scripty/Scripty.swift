import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Drawing Stroke Model (from Directors Notebook)

/// A single point in a drawing stroke
struct ScriptyDrawingPoint: Codable, Equatable {
    let x: CGFloat
    let y: CGFloat

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

/// A freeform drawing stroke on the script
struct ScriptyDrawingStroke: Codable, Identifiable, Equatable {
    let id: UUID
    var points: [ScriptyDrawingPoint]
    var color: StrokeColor
    var tool: DrawingTool
    var lineWidth: CGFloat
    var createdAt: Date

    init(id: UUID = UUID(), points: [ScriptyDrawingPoint] = [], color: StrokeColor = .yellow, tool: DrawingTool = .pen, lineWidth: CGFloat = 3.0) {
        self.id = id
        self.points = points
        self.color = color
        self.tool = tool
        self.lineWidth = lineWidth
        self.createdAt = Date()
    }

    enum StrokeColor: String, Codable, CaseIterable {
        case yellow, green, blue, pink, orange, purple, red, black

        var color: Color {
            switch self {
            case .yellow: return .yellow
            case .green: return .green
            case .blue: return .blue
            case .pink: return .pink
            case .orange: return .orange
            case .purple: return .purple
            case .red: return .red
            case .black: return .black
            }
        }

        #if os(macOS)
        var nsColor: NSColor {
            switch self {
            case .yellow: return .systemYellow
            case .green: return .systemGreen
            case .blue: return .systemBlue
            case .pink: return .systemPink
            case .orange: return .systemOrange
            case .purple: return .systemPurple
            case .red: return .systemRed
            case .black: return .black
            }
        }
        #endif
    }

    enum DrawingTool: String, Codable, CaseIterable {
        case pen
        case highlighter
        case eraser

        var icon: String {
            switch self {
            case .pen: return "pencil.tip"
            case .highlighter: return "highlighter"
            case .eraser: return "eraser"
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .pen: return 2.0
            case .highlighter: return 20.0
            case .eraser: return 30.0
            }
        }

        var opacity: CGFloat {
            switch self {
            case .pen: return 1.0
            case .highlighter: return 0.4
            case .eraser: return 1.0
            }
        }
    }
}

// MARK: - Scripty Drawings Store

/// Manages persistence of freeform drawings on scripts in Scripty
class ScriptyDrawingsStore: ObservableObject {
    static let shared = ScriptyDrawingsStore()

    @Published var drawings: [String: [ScriptyDrawingStroke]] = [:]  // keyed by sceneID

    private let userDefaultsKey = "ScriptyScriptDrawings"

    private init() {
        loadDrawings()
    }

    private func key(sceneID: String) -> String {
        sceneID
    }

    func getDrawings(for sceneID: String) -> [ScriptyDrawingStroke] {
        let k = key(sceneID: sceneID)
        return drawings[k] ?? []
    }

    func addStroke(sceneID: String, stroke: ScriptyDrawingStroke) {
        let k = key(sceneID: sceneID)
        var strokes = drawings[k] ?? []
        strokes.append(stroke)
        drawings[k] = strokes
        saveDrawings()
    }

    func updateStroke(sceneID: String, stroke: ScriptyDrawingStroke) {
        let k = key(sceneID: sceneID)
        guard var strokes = drawings[k],
              let index = strokes.firstIndex(where: { $0.id == stroke.id }) else { return }
        strokes[index] = stroke
        drawings[k] = strokes
        saveDrawings()
    }

    func removeStroke(sceneID: String, strokeID: UUID) {
        let k = key(sceneID: sceneID)
        guard var strokes = drawings[k] else { return }
        strokes.removeAll { $0.id == strokeID }
        if strokes.isEmpty {
            drawings.removeValue(forKey: k)
        } else {
            drawings[k] = strokes
        }
        saveDrawings()
    }

    func undoLastStroke(sceneID: String) {
        let k = key(sceneID: sceneID)
        guard var strokes = drawings[k], !strokes.isEmpty else { return }
        strokes.removeLast()
        if strokes.isEmpty {
            drawings.removeValue(forKey: k)
        } else {
            drawings[k] = strokes
        }
        saveDrawings()
    }

    func clearAllDrawings(for sceneID: String) {
        let k = key(sceneID: sceneID)
        drawings.removeValue(forKey: k)
        saveDrawings()
    }

    func hasDrawings(for sceneID: String) -> Bool {
        let k = key(sceneID: sceneID)
        return !(drawings[k]?.isEmpty ?? true)
    }

    func strokeCount(for sceneID: String) -> Int {
        let k = key(sceneID: sceneID)
        return drawings[k]?.count ?? 0
    }

    private func saveDrawings() {
        do {
            let data = try JSONEncoder().encode(drawings)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("[ScriptyDrawingsStore] Failed to save drawings: \(error)")
        }
    }

    private func loadDrawings() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            drawings = try JSONDecoder().decode([String: [ScriptyDrawingStroke]].self, from: data)
        } catch {
            print("[ScriptyDrawingsStore] Failed to load drawings: \(error)")
        }
    }
}

// MARK: - Scripty Drawing Canvas View

/// A transparent canvas for freeform drawing over the script
struct ScriptyDrawingCanvasView: View {
    let sceneID: String
    @Binding var isMarkingMode: Bool
    @Binding var selectedTool: ScriptyDrawingStroke.DrawingTool
    @Binding var selectedColor: ScriptyDrawingStroke.StrokeColor
    @ObservedObject var drawingsStore: ScriptyDrawingsStore

    @State private var currentStroke: ScriptyDrawingStroke? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render existing strokes
                ForEach(drawingsStore.getDrawings(for: sceneID)) { stroke in
                    ScriptyStrokePath(stroke: stroke)
                }

                // Render current stroke being drawn
                if let stroke = currentStroke {
                    ScriptyStrokePath(stroke: stroke)
                }

                // Invisible overlay to capture gestures when in marking mode
                if isMarkingMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDragChanged(value, in: geometry.size)
                                }
                                .onEnded { value in
                                    handleDragEnded(value)
                                }
                        )
                }
            }
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        let point = ScriptyDrawingPoint(value.location)

        if currentStroke == nil {
            // Start new stroke
            var stroke = ScriptyDrawingStroke(
                color: selectedColor,
                tool: selectedTool,
                lineWidth: selectedTool.lineWidth
            )
            stroke.points.append(point)
            currentStroke = stroke
        } else {
            // Continue stroke
            currentStroke?.points.append(point)
        }

        // Handle eraser
        if selectedTool == .eraser {
            eraseStrokesNear(point.cgPoint)
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        if let stroke = currentStroke, selectedTool != .eraser {
            // Only save if we have more than one point
            if stroke.points.count > 1 {
                drawingsStore.addStroke(sceneID: sceneID, stroke: stroke)
            }
        }
        currentStroke = nil
    }

    private func eraseStrokesNear(_ point: CGPoint) {
        let eraserRadius: CGFloat = 15.0
        let strokes = drawingsStore.getDrawings(for: sceneID)

        for stroke in strokes {
            for strokePoint in stroke.points {
                let distance = hypot(strokePoint.x - point.x, strokePoint.y - point.y)
                if distance < eraserRadius {
                    drawingsStore.removeStroke(sceneID: sceneID, strokeID: stroke.id)
                    break
                }
            }
        }
    }
}

/// Renders a single stroke path
struct ScriptyStrokePath: View {
    let stroke: ScriptyDrawingStroke

    var body: some View {
        Path { path in
            guard stroke.points.count > 1 else { return }

            path.move(to: stroke.points[0].cgPoint)
            for point in stroke.points.dropFirst() {
                path.addLine(to: point.cgPoint)
            }
        }
        .stroke(
            stroke.color.color.opacity(stroke.tool.opacity),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}

// MARK: - Scripty Store (loads scenes from Core Data)
@MainActor
class ScriptyStore: ObservableObject {
    @Published var scenes: [SceneEntity] = []

    private let context: NSManagedObjectContext
    private var project: ProjectEntity?
    private var observer: NSObjectProtocol?

    init(context: NSManagedObjectContext, project: ProjectEntity?) {
        self.context = context
        self.project = project
        reload()
        setupObserver()
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? Set()
            let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? Set()
            let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? Set()

            let hasSceneChanges = inserted.contains(where: { $0 is SceneEntity }) ||
                                   deleted.contains(where: { $0 is SceneEntity }) ||
                                   updated.contains(where: { $0 is SceneEntity })

            if hasSceneChanges {
                Task { @MainActor in
                    self.reload()
                }
            }
        }
    }

    func setProject(_ project: ProjectEntity?) {
        self.project = project
        reload()
    }

    func reload() {
        guard let project else {
            scenes = []
            return
        }
        let req: NSFetchRequest<SceneEntity> = SceneEntity.fetchRequest()
        req.predicate = NSPredicate(format: "project == %@", project)
        req.sortDescriptors = [
            NSSortDescriptor(key: "displayOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        do {
            scenes = try context.fetch(req)
            print("[Scripty] Loaded \(scenes.count) scenes from Core Data")
        } catch {
            print("[Scripty] Failed to fetch scenes: \(error)")
            scenes = []
        }
    }
}

// MARK: - Page Length Formatting Helper
func formatPageEighths(_ eighths: Int16) -> String {
    guard eighths > 0 else { return "N/A" }

    let fullPages = Int(eighths) / 8
    let remainingEighths = Int(eighths) % 8

    if fullPages == 0 {
        // Less than 1 page: "3/8 pg"
        return "\(remainingEighths)/8 pg"
    } else if remainingEighths == 0 {
        // Exact pages: "2 pgs" or "1 pg"
        return fullPages == 1 ? "1 pg" : "\(fullPages) pgs"
    } else {
        // Pages + eighths: "1 3/8 pgs"
        return "\(fullPages) \(remainingEighths)/8 pgs"
    }
}

// MARK: - Scripty Section
enum ScriptySection: String, CaseIterable, Identifiable {
    case linedScript = "Lined Script"
    case sceneTiming = "Scene Timing"
    case coverageChecklist = "Coverage Checklist"
    case scriptNotes = "Script Notes"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .linedScript: return "doc.text.fill"
        case .sceneTiming: return "clock.arrow.circlepath"
        case .coverageChecklist: return "checklist"
        case .scriptNotes: return "note.text"
        }
    }

    var description: String {
        switch self {
        case .linedScript: return "Mark coverage and camera setups on script pages"
        case .sceneTiming: return "Track actual vs. estimated scene duration"
        case .coverageChecklist: return "Ensure all required shots are captured"
        case .scriptNotes: return "Add annotations and dialogue changes"
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

// MARK: - Scripty View
struct Scripty: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSceneID: NSManagedObjectID?
    @StateObject private var scriptyStore: ScriptyStore

    init(project: NSManagedObject?) {
        let ctx = PersistenceController.shared.container.viewContext
        let projectEntity = project as? ProjectEntity
        _scriptyStore = StateObject(wrappedValue: ScriptyStore(context: ctx, project: projectEntity))
    }

    private var selectedScene: SceneEntity? {
        guard let id = selectedSceneID else { return nil }
        return scriptyStore.scenes.first { $0.objectID == id }
    }

    var body: some View {
        if scriptyStore.scenes.isEmpty {
            emptyState
        } else {
            HStack(spacing: 0) {
                // Left sidebar - Scene list
                sceneSidebar
                    .frame(width: 340)

                Divider()

                // Right pane - Unified scene detail
                if let scene = selectedScene {
                    SceneDetailPane(scene: scene, allScenes: scriptyStore.scenes)
                } else {
                    selectScenePrompt
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.text.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink.opacity(0.7))

            Text("Scripty")
                .font(.title.bold())

            Text("Import a screenplay in the Screenplay app to begin tracking script supervision data")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Select Scene Prompt
    private var selectScenePrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundStyle(.pink.opacity(0.5))

            Text("Select a Scene")
                .font(.title2.bold())

            Text("Choose a scene from the sidebar to view script supervision data")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scene Sidebar
    private var sceneSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Script Pages")
                    .font(.headline)

                Text("(\(scriptyStore.scenes.count) scenes)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Scene list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(scriptyStore.scenes, id: \.objectID) { scene in
                        ScriptySidebarRow(
                            scene: scene,
                            isSelected: selectedSceneID == scene.objectID
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSceneID = scene.objectID
                        }
                        .background(selectedSceneID == scene.objectID
                            ? Color.pink.opacity(0.15)
                            : Color.clear)
                    }
                }
            }
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97))
    }
}

// MARK: - Scripty Sidebar Row
struct ScriptySidebarRow: View {
    let scene: SceneEntity
    var isSelected: Bool = false
    var accentColor: Color = .pink

    var body: some View {
        HStack(spacing: 12) {
            // Scene number badge
            Text(scene.number ?? "?")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(accentColor))

            VStack(alignment: .leading, spacing: 3) {
                Text((scene.sceneSlug ?? "Untitled Scene").uppercased())
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if scene.pageEighths > 0 {
                        Text(formatPageEighths(scene.pageEighths))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Take Log Models

struct TakeLogEntry: Identifiable {
    let id: UUID
    var takeNumber: Int
    var camera: String
    var rating: TakeRating
    var notes: String
    var timestamp: Date

    var displayLabel: String {
        "\(camera)\(takeNumber)"
    }
}

enum TakeRating: String, CaseIterable {
    case none = "None"
    case print = "Print"
    case circled = "Circled"
    case hold = "Hold"
    case noGood = "NG"

    var icon: String {
        switch self {
        case .none: return "minus.circle"
        case .print: return "checkmark.circle.fill"
        case .circled: return "circle.circle.fill"
        case .hold: return "pause.circle.fill"
        case .noGood: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .none: return .gray
        case .print: return .green
        case .circled: return .blue
        case .hold: return .orange
        case .noGood: return .red
        }
    }
}

// MARK: - Take Log Card View
struct TakeLogCard: View {
    let take: TakeLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(take.displayLabel)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))

                Spacer()

                Image(systemName: take.rating.icon)
                    .foregroundStyle(take.rating.color)
            }

            if !take.notes.isEmpty {
                Text(take.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(take.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(take.rating == .print || take.rating == .circled
                    ? take.rating.color.opacity(0.1)
                    : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(take.rating.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Continuity Check Item
struct ContinuityCheckItem: View {
    let label: String
    let icon: String
    @State private var isChecked: Bool = false

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isChecked ? .primary : .secondary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(isChecked ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isChecked ? Color.green.opacity(0.1) : Color.primary.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coverage Line Style
enum CoverageLineStyle: String, CaseIterable, Identifiable {
    case straight = "Straight"
    case wavy = "Wavy"
    case dashed = "Dashed"
    case dotted = "Dotted"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .straight: return "line.diagonal"
        case .wavy: return "water.waves"
        case .dashed: return "line.horizontal.3"
        case .dotted: return "ellipsis"
        }
    }
}

// MARK: - Camera Setup
struct CameraSetup: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var color: Color

    static let defaultSetups: [CameraSetup] = [
        CameraSetup(name: "A", color: .red),
        CameraSetup(name: "B", color: .blue),
        CameraSetup(name: "C", color: .green),
        CameraSetup(name: "D", color: .orange),
        CameraSetup(name: "E", color: .purple),
        CameraSetup(name: "F", color: .pink)
    ]
}

// MARK: - Coverage Line
struct CoverageLine: Identifiable {
    let id = UUID()
    var camera: CameraSetup
    var lineStyle: CoverageLineStyle
    var startLine: Int
    var endLine: Int
}

// MARK: - Unified Scene Detail Pane
struct SceneDetailPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let scene: SceneEntity
    let allScenes: [SceneEntity]

    // Drawings store
    @StateObject private var drawingsStore = ScriptyDrawingsStore.shared

    // State for timing
    @State private var actualMinutes: String = ""
    @State private var actualSeconds: String = ""
    @State private var timingNotes: String = ""

    // State for coverage
    @State private var shots: [CoverageShot] = []
    @State private var newShotType = "Master"
    @State private var newShotDescription = ""
    private let shotTypes = ["Master", "Wide", "Medium", "CU", "ECU", "OTS", "Insert", "POV", "Two-Shot", "Single"]

    // State for notes
    @State private var notes: [ScriptNote] = []
    @State private var newNoteType: ScriptNoteType = .dialogue
    @State private var newNoteContent: String = ""

    // State for line style menu
    @State private var selectedLineStyle: CoverageLineStyle = .straight
    @State private var selectedCamera: CameraSetup = CameraSetup.defaultSetups[0]
    @State private var coverageLines: [CoverageLine] = []
    @State private var isDrawingMode: Bool = false

    // State for mark script (freeform drawing from Directors Notebook)
    @State private var isMarkingMode: Bool = false
    @State private var selectedDrawingTool: ScriptyDrawingStroke.DrawingTool = .pen
    @State private var selectedDrawingColor: ScriptyDrawingStroke.StrokeColor = .red
    @State private var scriptZoomLevel: CGFloat = 1.0

    // Zoom limits
    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 2.0

    // State for Set View / Continuity
    @State private var takeLog: [TakeLogEntry] = []
    @State private var continuityNotes: String = ""
    @State private var selectedTakeNumber: Int = 1
    @State private var selectedCameraLetter: String = "A"
    @State private var takeRating: TakeRating = .none
    @State private var takeNotes: String = ""

    // Scene ID for drawings storage
    private var sceneID: String {
        scene.objectID.uriRepresentation().absoluteString
    }

    private var estimatedSeconds: Int {
        Int(scene.pageEighths) * 8  // 8 seconds per eighth
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Scene Header
                sceneHeader
                    .padding(20)

                Divider()

                // Main content sections
                VStack(alignment: .leading, spacing: 24) {
                    // Script Content Section
                    scriptContentSection

                    // Timing Section
                    timingSection

                    // Coverage Checklist Section
                    coverageSection

                    // Set/Continuity Section
                    setViewSection

                    // Script Notes Section
                    notesSection
                }
                .padding(20)
            }
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
    }

    // MARK: - Scene Header
    private var sceneHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Text(scene.number ?? "?")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.pink))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scene \(scene.number ?? "?")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text((scene.sceneSlug ?? "Untitled Scene").uppercased())
                        .font(.system(size: 18, weight: .semibold))
                }

                Spacer()

                // Coverage completion badge
                if !shots.isEmpty {
                    let completed = shots.filter { $0.isCaptured }.count
                    Text("\(completed)/\(shots.count) shots")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(completed == shots.count ? Color.green : Color.orange)
                        )
                }
            }

            // Metadata cards row
            HStack(spacing: 10) {
                MetadataCard(
                    title: "Page Length",
                    value: formatPageEighths(scene.pageEighths),
                    icon: "doc.text",
                    color: .blue
                )
                .frame(width: 130)

                MetadataCard(
                    title: "Est. Duration",
                    value: formatDuration(estimatedSeconds),
                    icon: "clock",
                    color: .orange
                )
                .frame(width: 130)

                MetadataCard(
                    title: "Coverage",
                    value: shots.isEmpty ? "0 lines" : "\(shots.filter { $0.isCaptured }.count)/\(shots.count)",
                    icon: "line.diagonal",
                    color: .pink
                )
                .frame(width: 130)

                MetadataCard(
                    title: "Notes",
                    value: "\(notes.count)",
                    icon: "note.text",
                    color: .purple
                )
                .frame(width: 130)

                Spacer()
            }
        }
    }

    // MARK: - Script Content Section
    private var scriptContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with mark script button, zoom controls, and line style menu
            HStack {
                sectionHeader(title: "Lined Script", icon: "doc.text.fill", color: .pink)

                Spacer()

                // Zoom controls
                zoomControls

                // Mark Script button (from Directors Notebook)
                markScriptButton

                Divider()
                    .frame(height: 20)

                // Line Style Menu (for coverage lines)
                lineStyleMenu
            }

            // Drawing toolbar (when marking mode is active)
            if isMarkingMode {
                drawingToolbar
            }

            // Professional screenplay page view with EnhancedFDXScriptView (matching Directors Notebook)
            if let scriptText = scene.scriptText, !scriptText.isEmpty {
                scriptViewWithDrawingOverlay(scriptText: scriptText)
            } else {
                // No script content placeholder - styled as a page
                ZStack {
                    // Page background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(.pink.opacity(0.4))

                        Text("No Script Content")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))

                        Text("Import a screenplay with scene content to view and mark coverage lines here.")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 60)

                        // Tip
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                            Text("Import your screenplay in the Screenplay app")
                                .font(.system(size: 11))
                                .foregroundColor(.black.opacity(0.5))
                        }
                        .padding(10)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.vertical, 60)
                }
                .frame(width: 612, height: 400)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Zoom Controls
    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    scriptZoomLevel = max(minZoom, scriptZoomLevel - 0.25)
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(scriptZoomLevel <= minZoom)

            Text("\(Int(scriptZoomLevel * 100))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 40)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    scriptZoomLevel = min(maxZoom, scriptZoomLevel + 0.25)
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(scriptZoomLevel >= maxZoom)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92))
        )
    }

    // MARK: - Mark Script Button
    private var markScriptButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isMarkingMode.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isMarkingMode ? "pencil.slash" : "pencil.and.scribble")
                Text(isMarkingMode ? "Done Marking" : "Mark Script")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isMarkingMode ? Color.orange : Color.secondary.opacity(0.15))
            .foregroundColor(isMarkingMode ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drawing Toolbar (from Directors Notebook)
    private var drawingToolbar: some View {
        HStack(spacing: 16) {
            // Tool selection
            HStack(spacing: 4) {
                ForEach(ScriptyDrawingStroke.DrawingTool.allCases, id: \.rawValue) { tool in
                    Button {
                        selectedDrawingTool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .font(.system(size: 14))
                            .frame(width: 36, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedDrawingTool == tool ? Color.accentColor : Color.clear)
                            )
                            .foregroundColor(selectedDrawingTool == tool ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(tool.rawValue.capitalized)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92))
            )

            Divider()
                .frame(height: 24)

            // Color selection (not for eraser)
            if selectedDrawingTool != .eraser {
                HStack(spacing: 6) {
                    ForEach(ScriptyDrawingStroke.StrokeColor.allCases, id: \.rawValue) { strokeColor in
                        Button {
                            selectedDrawingColor = strokeColor
                        } label: {
                            Circle()
                                .fill(strokeColor.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(selectedDrawingColor == strokeColor ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedDrawingColor == strokeColor ? 1 : 0)
                                        .padding(2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 24)
            }

            // Undo button
            Button {
                drawingsStore.undoLastStroke(sceneID: sceneID)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
            .help("Undo last stroke")
            .disabled(drawingsStore.strokeCount(for: sceneID) == 0)

            Spacer()

            // Stroke count
            let strokeCount = drawingsStore.strokeCount(for: sceneID)
            if strokeCount > 0 {
                Text("\(strokeCount) stroke\(strokeCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Instructions
            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Draw on script to mark")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Clear all drawings button
            Button {
                drawingsStore.clearAllDrawings(for: sceneID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Clear All")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.1))
                )
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            colorScheme == .dark
                ? Color.orange.opacity(0.1)
                : Color.orange.opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Script View with Drawing Overlay (matching Directors Notebook)
    @ViewBuilder
    private func scriptViewWithDrawingOverlay(scriptText: String) -> some View {
        let fdxContent = generateFDXFromScriptText(scriptText)

        ZStack {
            // Script content using EnhancedFDXScriptView (same as Directors Notebook)
            #if os(macOS)
            EnhancedFDXScriptView(
                fdxXML: fdxContent,
                pageEighths: Int(scene.pageEighths),
                showRevisionMarks: true,
                showSceneNumbers: true,
                includeHeader: false,
                showRawXML: false,
                startingPageNumber: 1,
                sceneID: nil
            )
            .scaleEffect(scriptZoomLevel, anchor: .top)
            .frame(maxWidth: .infinity, alignment: .center)
            #else
            // iOS fallback - use existing ScriptPagePreview
            ScriptPagePreview(
                sceneNumber: scene.number ?? "",
                sceneSlug: scene.sceneSlug ?? "INT. LOCATION - DAY",
                scriptText: scriptText,
                coverageLines: $coverageLines,
                selectedCamera: selectedCamera,
                selectedLineStyle: selectedLineStyle,
                isDrawingMode: isDrawingMode
            )
            .scaleEffect(scriptZoomLevel, anchor: .top)
            #endif

            // Drawing canvas overlay (when marking mode is active OR there are existing drawings)
            ScriptyDrawingCanvasView(
                sceneID: sceneID,
                isMarkingMode: $isMarkingMode,
                selectedTool: $selectedDrawingTool,
                selectedColor: $selectedDrawingColor,
                drawingsStore: drawingsStore
            )
            .allowsHitTesting(isMarkingMode)  // Only capture input when in marking mode
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Generate FDX from Script Text
    private func generateFDXFromScriptText(_ scriptText: String) -> String {
        // Parse the script text into FDX format
        // This creates a basic FDX structure from plain text
        let lines = scriptText.components(separatedBy: .newlines)
        var paragraphs: [String] = []

        // Add scene heading first
        let sceneHeading = (scene.sceneSlug ?? "INT. LOCATION - DAY").uppercased()
        let sceneNum = scene.number ?? ""
        paragraphs.append("<Paragraph Type=\"Scene Heading\" Number=\"\(escapeXML(sceneNum))\"><Text>\(escapeXML(sceneHeading))</Text></Paragraph>")

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }

            let elementType: String
            let text = escapeXML(trimmedLine)

            // Simple heuristics to detect element types
            if isCharacterName(trimmedLine) {
                elementType = "Character"
            } else if isParenthetical(trimmedLine) {
                elementType = "Parenthetical"
            } else if isDialogue(line) {
                elementType = "Dialogue"
            } else if isTransition(trimmedLine) {
                elementType = "Transition"
            } else {
                elementType = "Action"
            }

            paragraphs.append("<Paragraph Type=\"\(elementType)\"><Text>\(text)</Text></Paragraph>")
        }

        return paragraphs.joined(separator: "\n")
    }

    private func escapeXML(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }

    private func isCharacterName(_ line: String) -> Bool {
        let cleaned = line
            .replacingOccurrences(of: "(V.O.)", with: "")
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
        line.hasPrefix("    ") || line.hasPrefix("\t")
    }

    private func isTransition(_ line: String) -> Bool {
        let transitions = ["CUT TO:", "FADE OUT.", "FADE IN:", "DISSOLVE TO:",
                          "SMASH CUT TO:", "MATCH CUT TO:", "JUMP CUT TO:",
                          "FADE TO BLACK.", "THE END", "CONTINUED:"]
        return transitions.contains { line.uppercased().contains($0) }
    }

    // MARK: - Line Style Menu
    private var lineStyleMenu: some View {
        HStack(spacing: 12) {
            // Drawing mode toggle
            Button {
                isDrawingMode.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isDrawingMode ? "pencil.circle.fill" : "pencil.circle")
                        .font(.system(size: 14))
                    Text(isDrawingMode ? "Drawing" : "Draw")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isDrawingMode ? .white : .pink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDrawingMode ? Color.pink : Color.pink.opacity(0.15))
                )
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)

            // Camera picker
            Menu {
                ForEach(CameraSetup.defaultSetups) { camera in
                    Button {
                        selectedCamera = camera
                    } label: {
                        HStack {
                            Circle()
                                .fill(camera.color)
                                .frame(width: 10, height: 10)
                            Text("Camera \(camera.name)")
                            if selectedCamera.name == camera.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(selectedCamera.color)
                        .frame(width: 12, height: 12)
                    Text("Cam \(selectedCamera.name)")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                )
            }

            // Line style picker
            Menu {
                ForEach(CoverageLineStyle.allCases) { style in
                    Button {
                        selectedLineStyle = style
                    } label: {
                        HStack {
                            Image(systemName: style.icon)
                            Text(style.rawValue)
                            if selectedLineStyle == style {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedLineStyle.icon)
                        .font(.system(size: 12))
                    Text(selectedLineStyle.rawValue)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                )
            }

            // Clear lines button
            if !coverageLines.isEmpty {
                Button {
                    coverageLines.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Timing Section
    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Scene Timing", icon: "clock.arrow.circlepath", color: .orange)

            HStack(spacing: 16) {
                // Estimated time
                VStack(alignment: .leading, spacing: 6) {
                    Text("Estimated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(estimatedSeconds))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.blue)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )

                // Actual time input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("0", text: $actualMinutes)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                        Text(":")
                            .font(.system(size: 18, weight: .semibold))
                        TextField("00", text: $actualSeconds)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                    }
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Timing notes
            VStack(alignment: .leading, spacing: 6) {
                Text("Timing Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $timingNotes)
                    .frame(height: 60)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
            }
        }
    }

    // MARK: - Coverage Section
    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Coverage Checklist", icon: "checklist", color: .green)

            if shots.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checklist")
                        .font(.system(size: 28))
                        .foregroundStyle(.green.opacity(0.5))
                    Text("No shots added yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                )
            } else {
                VStack(spacing: 6) {
                    ForEach($shots) { $shot in
                        HStack(spacing: 10) {
                            Button {
                                shot.isCaptured.toggle()
                            } label: {
                                Image(systemName: shot.isCaptured ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(shot.isCaptured ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(shot.shotType)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                )

                            Text(shot.description)
                                .font(.body)
                                .strikethrough(shot.isCaptured, color: .secondary)
                                .foregroundStyle(shot.isCaptured ? .secondary : .primary)

                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97))
                        )
                    }
                }
            }

            // Add shot row
            HStack(spacing: 10) {
                Picker("Type", selection: $newShotType) {
                    ForEach(shotTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .frame(width: 110)

                TextField("Shot description", text: $newShotDescription)
                    .textFieldStyle(.roundedBorder)

                Button {
                    if !newShotDescription.isEmpty {
                        shots.append(CoverageShot(
                            shotType: newShotType,
                            description: newShotDescription,
                            isCaptured: false
                        ))
                        newShotDescription = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(newShotDescription.isEmpty)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.93))
            )
        }
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Script Notes", icon: "note.text", color: .purple)

            if notes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple.opacity(0.5))
                    Text("No notes for this scene")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: note.type.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(note.type.color))

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(note.type.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(note.type.color)
                                    Spacer()
                                    Text(note.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(note.content)
                                    .font(.callout)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97))
                        )
                    }
                }
            }

            // Note type picker + add note
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(ScriptNoteType.allCases) { type in
                        Button {
                            newNoteType = type
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 10))
                                Text(type.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(newNoteType == type ? type.color : Color.clear)
                            )
                            .foregroundStyle(newNoteType == type ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    TextField("Enter note...", text: $newNoteContent)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        if !newNoteContent.isEmpty {
                            notes.append(ScriptNote(
                                sceneNumber: scene.number ?? "?",
                                pageNumber: "",
                                type: newNoteType,
                                content: newNoteContent,
                                timestamp: Date()
                            ))
                            newNoteContent = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(newNoteContent.isEmpty)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.93))
            )
        }
    }

    // MARK: - Set View / Continuity Section
    private var setViewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Set View / Continuity", icon: "video.badge.checkmark", color: .teal)

            // Take Log
            VStack(alignment: .leading, spacing: 8) {
                Text("Take Log")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                // Take entries list
                if takeLog.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.teal.opacity(0.5))
                        Text("No takes logged for this scene")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(takeLog) { take in
                                TakeLogCard(take: take)
                            }
                        }
                    }
                }

                // Add Take Form
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        // Take Number
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Take")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Stepper(value: $selectedTakeNumber, in: 1...99) {
                                Text("\(selectedTakeNumber)")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                            .frame(width: 100)
                        }

                        // Camera
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Camera")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Camera", selection: $selectedCameraLetter) {
                                ForEach(["A", "B", "C", "D"], id: \.self) { letter in
                                    Text(letter).tag(letter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }

                        // Rating
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rating")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                ForEach(TakeRating.allCases, id: \.self) { rating in
                                    Button {
                                        takeRating = rating
                                    } label: {
                                        Image(systemName: rating.icon)
                                            .font(.system(size: 16))
                                            .foregroundStyle(takeRating == rating ? rating.color : .secondary)
                                            .frame(width: 28, height: 28)
                                            .background(
                                                Circle().fill(takeRating == rating ? rating.color.opacity(0.15) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer()
                    }

                    HStack(spacing: 10) {
                        TextField("Take notes (false start, good energy, etc.)", text: $takeNotes)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            addTake()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.teal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.93))
                )
            }

            Divider()
                .padding(.vertical, 8)

            // Continuity Notes
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Continuity Notes")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !continuityNotes.isEmpty {
                        Text("\(continuityNotes.count) chars")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                TextEditor(text: $continuityNotes)
                    .font(.callout)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.08) : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if continuityNotes.isEmpty {
                            Text("Props, wardrobe, hair/makeup notes, actor positions, weather conditions...")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                    }
            }

            // Quick Continuity Checklist
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Checklist")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ContinuityCheckItem(label: "Props Matched", icon: "cube.box")
                    ContinuityCheckItem(label: "Wardrobe OK", icon: "tshirt")
                    ContinuityCheckItem(label: "Hair/Makeup", icon: "paintbrush")
                    ContinuityCheckItem(label: "Lighting", icon: "sun.max")
                    ContinuityCheckItem(label: "Sound", icon: "waveform")
                    ContinuityCheckItem(label: "Eyeline", icon: "eye")
                }
            }
        }
    }

    private func addTake() {
        let take = TakeLogEntry(
            id: UUID(),
            takeNumber: selectedTakeNumber,
            camera: selectedCameraLetter,
            rating: takeRating,
            notes: takeNotes,
            timestamp: Date()
        )
        takeLog.append(take)

        // Increment take number for next take
        selectedTakeNumber += 1
        takeNotes = ""
        takeRating = .none
    }

    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return "\(secs)s"
    }
}

// MARK: - Lined Script Detail Pane (Legacy - kept for reference)
struct LinedScriptDetailPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let scene: SceneEntity

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Section
                sceneHeader

                Divider()

                // Script Content Section
                scriptContent

                Spacer()
            }
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
    }

    // MARK: - Scene Header
    private var sceneHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Scene number and heading
            HStack(spacing: 14) {
                // Scene number badge
                Text(scene.number ?? "?")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.pink))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scene \(scene.number ?? "?")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(scene.sceneSlug ?? "Untitled Scene")
                        .font(.system(size: 18, weight: .semibold))
                }

                Spacer()
            }

            // Metadata cards
            HStack(spacing: 10) {
                // Page length
                MetadataCard(
                    title: "Page Length",
                    value: formatPageEighths(scene.pageEighths),
                    icon: "doc.text",
                    color: .blue
                )
                .frame(width: 130)

                // Estimated duration (1 page = 1 minute = 60 seconds)
                MetadataCard(
                    title: "Est. Duration",
                    value: formatDuration(Int(scene.pageEighths) * 8),
                    icon: "clock",
                    color: .orange
                )
                .frame(width: 130)

                // Coverage status
                MetadataCard(
                    title: "Coverage",
                    value: "0 lines",
                    icon: "line.diagonal",
                    color: .pink
                )
                .frame(width: 130)

                Spacer()
            }
        }
        .padding(20)
    }

    // MARK: - Script Content
    private var scriptContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Full Script")
                .font(.title3.bold())
                .padding(.horizontal, 24)
                .padding(.top, 24)

            // Script page preview (placeholder for now)
            VStack(alignment: .leading, spacing: 16) {
                Text(scene.sceneSlug ?? "")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 60)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Script content will be displayed here when screenplay text data is available.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 60)

                Text("Coverage lines and camera assignments can be marked directly on the script page using the line tools in the toolbar.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 60)

                // Coverage lines placeholder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coverage Lines")
                        .font(.headline)
                        .padding(.horizontal, 60)
                        .padding(.top, 16)

                    Text("No coverage lines marked yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 60)

                    // Instructions
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.pink)
                        Text("Use the Line Style menu above to select a line style and camera, then draw on the script page")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.pink.opacity(0.1))
                    )
                    .padding(.horizontal, 60)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.9), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return "\(secs)s"
    }
}

// MARK: - Metadata Card
struct MetadataCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Scene Timing Detail Pane
struct SceneTimingDetailPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let scene: SceneEntity
    let scenes: [SceneEntity]

    @State private var actualMinutes: String = ""
    @State private var actualSeconds: String = ""
    @State private var timingNotes: String = ""

    private var estimatedSeconds: Int {
        Int(scene.pageEighths) * 8  // 8 seconds per eighth
    }

    private var totalEstimated: Int {
        scenes.reduce(0) { $0 + Int($1.pageEighths) * 8 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Scene Header
                sceneHeader

                Divider()

                // Timing Input Section
                timingInputSection

                // Summary Section
                summarySection
            }
            .padding(20)
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
    }

    private var sceneHeader: some View {
        HStack(spacing: 14) {
            Text(scene.number ?? "?")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.orange))

            VStack(alignment: .leading, spacing: 2) {
                Text("Scene \(scene.number ?? "?")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(scene.sceneSlug ?? "Untitled Scene")
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer()
        }
    }

    private var timingInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scene Timing")
                .font(.title3.bold())

            HStack(spacing: 20) {
                // Estimated time card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Estimated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(estimatedSeconds))
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.blue)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                )

                // Actual time input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("0", text: $actualMinutes)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text(":")
                            .font(.system(size: 20, weight: .semibold))
                        TextField("00", text: $actualSeconds)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                    }
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $timingNotes)
                    .frame(height: 80)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Summary")
                .font(.title3.bold())

            HStack(spacing: 16) {
                MetadataCard(
                    title: "Total Estimated",
                    value: formatDuration(totalEstimated),
                    icon: "clock",
                    color: .blue
                )
                .frame(width: 140)

                MetadataCard(
                    title: "Scenes",
                    value: "\(scenes.count)",
                    icon: "film",
                    color: .purple
                )
                .frame(width: 140)

                Spacer()
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Coverage Checklist Detail Pane
struct CoverageChecklistDetailPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let scene: SceneEntity

    @State private var shots: [CoverageShot] = []
    @State private var showingAddShot = false
    @State private var newShotType = "Master"
    @State private var newShotDescription = ""

    private let shotTypes = ["Master", "Wide", "Medium", "CU", "ECU", "OTS", "Insert", "POV", "Two-Shot", "Single"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Scene Header
                sceneHeader

                Divider()

                // Coverage Section
                coverageSection

                // Add Shot Section
                addShotSection
            }
            .padding(20)
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
    }

    private var sceneHeader: some View {
        HStack(spacing: 14) {
            Text(scene.number ?? "?")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.green))

            VStack(alignment: .leading, spacing: 2) {
                Text("Scene \(scene.number ?? "?")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(scene.sceneSlug ?? "Untitled Scene")
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer()

            // Completion badge
            if !shots.isEmpty {
                let completed = shots.filter { $0.isCaptured }.count
                Text("\(completed)/\(shots.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(completed == shots.count ? Color.green : Color.orange)
                    )
            }
        }
    }

    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shot Checklist")
                .font(.title3.bold())

            if shots.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 32))
                        .foregroundStyle(.green.opacity(0.5))
                    Text("No shots added yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Add shots below to track coverage")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                )
            } else {
                VStack(spacing: 8) {
                    ForEach($shots) { $shot in
                        HStack(spacing: 12) {
                            Button {
                                shot.isCaptured.toggle()
                            } label: {
                                Image(systemName: shot.isCaptured ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(shot.isCaptured ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(shot.shotType)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                )

                            Text(shot.description)
                                .font(.body)
                                .strikethrough(shot.isCaptured, color: .secondary)
                                .foregroundStyle(shot.isCaptured ? .secondary : .primary)

                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97))
                        )
                    }
                }
            }
        }
    }

    private var addShotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Shot")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Type", selection: $newShotType) {
                    ForEach(shotTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .frame(width: 120)

                TextField("Description", text: $newShotDescription)
                    .textFieldStyle(.roundedBorder)

                Button {
                    if !newShotDescription.isEmpty {
                        shots.append(CoverageShot(
                            shotType: newShotType,
                            description: newShotDescription,
                            isCaptured: false
                        ))
                        newShotDescription = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(newShotDescription.isEmpty)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        )
    }
}

// MARK: - Coverage Shot Model
struct CoverageShot: Identifiable {
    let id = UUID()
    var shotType: String
    var description: String
    var isCaptured: Bool
}

// MARK: - Script Notes Detail Pane
struct ScriptNotesDetailPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let scene: SceneEntity

    @State private var notes: [ScriptNote] = []
    @State private var newNoteType: ScriptNoteType = .dialogue
    @State private var newNoteContent: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Scene Header
                sceneHeader

                Divider()

                // Notes List
                notesSection

                // Add Note Section
                addNoteSection
            }
            .padding(20)
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
    }

    private var sceneHeader: some View {
        HStack(spacing: 14) {
            Text(scene.number ?? "?")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.purple))

            VStack(alignment: .leading, spacing: 2) {
                Text("Scene \(scene.number ?? "?")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(scene.sceneSlug ?? "Untitled Scene")
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer()

            if !notes.isEmpty {
                Text("\(notes.count) notes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Script Notes")
                .font(.title3.bold())

            if notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.purple.opacity(0.5))
                    Text("No notes for this scene")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Add dialogue changes, continuity notes, or director comments")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(notes) { note in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: note.type.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(note.type.color))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(note.type.rawValue)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(note.type.color)
                                    Spacer()
                                    Text(note.timestamp, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(note.content)
                                    .font(.body)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97))
                        )
                    }
                }
            }
        }
    }

    private var addNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Note")
                .font(.headline)

            // Note type picker
            HStack(spacing: 8) {
                ForEach(ScriptNoteType.allCases) { type in
                    Button {
                        newNoteType = type
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 11))
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(newNoteType == type ? type.color : Color.clear)
                        )
                        .foregroundStyle(newNoteType == type ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                TextField("Enter note...", text: $newNoteContent)
                    .textFieldStyle(.roundedBorder)

                Button {
                    if !newNoteContent.isEmpty {
                        notes.append(ScriptNote(
                            sceneNumber: scene.number ?? "?",
                            pageNumber: "",
                            type: newNoteType,
                            content: newNoteContent,
                            timestamp: Date()
                        ))
                        newNoteContent = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .disabled(newNoteContent.isEmpty)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        )
    }
}

// MARK: - Script Note Models
enum ScriptNoteType: String, CaseIterable, Identifiable {
    case dialogue = "Dialogue"
    case action = "Action"
    case continuity = "Continuity"
    case director = "Director"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dialogue: return "text.quote"
        case .action: return "figure.walk"
        case .continuity: return "arrow.triangle.2.circlepath"
        case .director: return "megaphone"
        }
    }

    var color: Color {
        switch self {
        case .dialogue: return .blue
        case .action: return .orange
        case .continuity: return .green
        case .director: return .purple
        }
    }
}

struct ScriptNote: Identifiable {
    let id = UUID()
    var sceneNumber: String
    var pageNumber: String
    var type: ScriptNoteType
    var content: String
    var timestamp: Date

    static var sampleData: [ScriptNote] {
        [
            ScriptNote(sceneNumber: "1", pageNumber: "2", type: .dialogue, content: "Changed 'Hello' to 'Hey there' - actor preference", timestamp: Date().addingTimeInterval(-3600)),
            ScriptNote(sceneNumber: "1", pageNumber: "3", type: .continuity, content: "Coffee cup half-full in master, ensure match in coverage", timestamp: Date().addingTimeInterval(-3000)),
            ScriptNote(sceneNumber: "2", pageNumber: "5", type: .action, content: "Added beat before exit - character looks back at door", timestamp: Date().addingTimeInterval(-2400)),
            ScriptNote(sceneNumber: "3", pageNumber: "8", type: .director, content: "Play this scene faster, more urgency needed", timestamp: Date().addingTimeInterval(-1800)),
            ScriptNote(sceneNumber: "3", pageNumber: "9", type: .dialogue, content: "Improvised line: 'That's not what I meant' - keeping it", timestamp: Date().addingTimeInterval(-1200))
        ]
    }
}

// MARK: - Script Page Preview (Breakdowns-style with Drag-to-Draw)
struct ScriptPagePreview: View {
    let sceneNumber: String
    let sceneSlug: String
    let scriptText: String
    @Binding var coverageLines: [CoverageLine]
    let selectedCamera: CameraSetup
    let selectedLineStyle: CoverageLineStyle
    let isDrawingMode: Bool

    // Page dimensions (US Letter)
    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let leftMargin: CGFloat = 108  // 1.5 inches
    private let rightMargin: CGFloat = 72  // 1 inch
    private let topMargin: CGFloat = 72    // 1 inch
    private let bottomMargin: CGFloat = 72 // 1 inch
    private let lineHeight: CGFloat = 16   // Height per script line

    private var contentWidth: CGFloat { pageWidth - leftMargin - rightMargin }

    // Drawing state
    @State private var isDragging: Bool = false
    @State private var dragStartY: CGFloat = 0
    @State private var dragCurrentY: CGFloat = 0
    @State private var dragStartLine: Int? = nil
    @State private var dragCurrentLine: Int? = nil

    private var lines: [String] {
        scriptText.components(separatedBy: .newlines)
    }

    // Calculate which line index corresponds to a Y position
    private func lineIndex(for yPosition: CGFloat) -> Int {
        // Account for top margin and scene heading
        let adjustedY = yPosition - topMargin - 28 // 28 for scene heading + padding
        let index = Int(adjustedY / lineHeight)
        return max(0, min(index, lines.count - 1))
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            // Script page with gesture overlay
            ZStack(alignment: .topLeading) {
                // Page background with shadow
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                // Script content
                VStack(alignment: .leading, spacing: 0) {
                    // Scene heading with scene numbers in margins
                    sceneHeadingRow
                        .padding(.bottom, 12)

                    // Script lines
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            ScriptPageLineView(
                                lineNumber: index,
                                text: line,
                                coverageLines: coverageLines.filter { $0.startLine <= index && $0.endLine >= index },
                                isHovered: isLineInCurrentDrag(index),
                                isDrawingMode: isDrawingMode,
                                isDragStart: dragStartLine == index,
                                contentWidth: contentWidth
                            )
                        }
                    }
                }
                .padding(.top, topMargin)
                .padding(.leading, leftMargin)
                .padding(.trailing, rightMargin)
                .padding(.bottom, bottomMargin)

                // Live drawing preview overlay
                if isDrawingMode && isDragging, let startLine = dragStartLine, let currentLine = dragCurrentLine {
                    liveDrawingPreview(startLine: startLine, currentLine: currentLine)
                }

                // Invisible gesture layer for drawing (only active in drawing mode)
                if isDrawingMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    if !isDragging {
                                        // Start of drag
                                        isDragging = true
                                        dragStartY = value.startLocation.y
                                        dragStartLine = lineIndex(for: value.startLocation.y)
                                    }
                                    dragCurrentY = value.location.y
                                    dragCurrentLine = lineIndex(for: value.location.y)
                                }
                                .onEnded { value in
                                    // Complete the line
                                    if let start = dragStartLine {
                                        let endLine = lineIndex(for: value.location.y)
                                        let actualStart = min(start, endLine)
                                        let actualEnd = max(start, endLine)

                                        // Only add if we have a valid range
                                        if actualEnd >= actualStart {
                                            coverageLines.append(CoverageLine(
                                                camera: selectedCamera,
                                                lineStyle: selectedLineStyle,
                                                startLine: actualStart,
                                                endLine: actualEnd
                                            ))
                                        }
                                    }

                                    // Reset drag state
                                    isDragging = false
                                    dragStartLine = nil
                                    dragCurrentLine = nil
                                }
                        )
                }
            }
            .frame(width: pageWidth, height: max(pageHeight, CGFloat(lines.count) * lineHeight + topMargin + bottomMargin + 50))
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        #else
        .background(Color(uiColor: .systemGroupedBackground).opacity(0.5))
        #endif
    }

    // Check if a line is within the current drag selection
    private func isLineInCurrentDrag(_ index: Int) -> Bool {
        guard isDragging, let start = dragStartLine, let current = dragCurrentLine else {
            return false
        }
        let minLine = min(start, current)
        let maxLine = max(start, current)
        return index >= minLine && index <= maxLine
    }

    // Live preview of the line being drawn
    @ViewBuilder
    private func liveDrawingPreview(startLine: Int, currentLine: Int) -> some View {
        let minLine = min(startLine, currentLine)
        let maxLine = max(startLine, currentLine)

        // Position the preview line in the left margin area
        let yOffset = topMargin + 28 + CGFloat(minLine) * lineHeight
        let height = CGFloat(maxLine - minLine + 1) * lineHeight

        // Draw preview line with selected camera color and style
        ZStack(alignment: .leading) {
            // Background highlight for selected lines
            Rectangle()
                .fill(selectedCamera.color.opacity(0.1))
                .frame(width: contentWidth, height: height)

            // The actual line preview
            Rectangle()
                .fill(selectedCamera.color.opacity(0.7))
                .frame(width: 4, height: height)
                .overlay(lineStyleOverlay(height: height))
        }
        .offset(x: leftMargin - 20, y: yOffset)
        .allowsHitTesting(false) // Don't interfere with gestures
    }

    // Apply line style to the preview
    @ViewBuilder
    private func lineStyleOverlay(height: CGFloat) -> some View {
        switch selectedLineStyle {
        case .straight:
            EmptyView()
        case .wavy:
            // Wavy pattern
            GeometryReader { _ in
                Path { path in
                    let waveHeight: CGFloat = 3
                    let waveLength: CGFloat = 8
                    path.move(to: CGPoint(x: 2, y: 0))
                    var y: CGFloat = 0
                    var direction: CGFloat = 1
                    while y < height {
                        path.addLine(to: CGPoint(x: 2 + direction * waveHeight, y: y + waveLength / 2))
                        direction *= -1
                        y += waveLength / 2
                    }
                }
                .stroke(selectedCamera.color, lineWidth: 2)
            }
        case .dashed:
            // Dashed pattern using mask
            Rectangle()
                .fill(selectedCamera.color)
                .mask(
                    VStack(spacing: 4) {
                        ForEach(0..<Int(height / 10), id: \.self) { _ in
                            Rectangle().frame(height: 6)
                        }
                    }
                )
        case .dotted:
            // Dotted pattern using mask
            Rectangle()
                .fill(selectedCamera.color)
                .mask(
                    VStack(spacing: 5) {
                        ForEach(0..<Int(height / 8), id: \.self) { _ in
                            Circle().frame(width: 4, height: 4)
                        }
                    }
                )
        }
    }

    // Scene heading with scene numbers in both margins (traditional screenplay format)
    private var sceneHeadingRow: some View {
        HStack(spacing: 0) {
            // Left scene number (in margin)
            Text(sceneNumber)
                .font(.custom("Courier", size: 12))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(width: 36, alignment: .leading)

            // Scene slug (uppercase)
            Text(sceneSlug.uppercased())
                .font(.custom("Courier", size: 12))
                .fontWeight(.bold)
                .foregroundColor(.black)

            Spacer()

            // Right scene number (in margin)
            Text(sceneNumber)
                .font(.custom("Courier", size: 12))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(width: 36, alignment: .trailing)
        }
        .frame(width: contentWidth)
    }
}

// MARK: - Script Page Line View (Professional screenplay formatting)
struct ScriptPageLineView: View {
    let lineNumber: Int
    let text: String
    let coverageLines: [CoverageLine]
    let isHovered: Bool
    let isDrawingMode: Bool
    let isDragStart: Bool
    let contentWidth: CGFloat

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespaces)
    }

    private var lineType: ScriptLineType {
        if trimmedText.isEmpty {
            return .empty
        } else if isCharacterName(trimmedText) {
            return .character
        } else if isParenthetical(trimmedText) {
            return .parenthetical
        } else if isDialogue(text) {
            return .dialogue
        } else if isTransition(trimmedText) {
            return .transition
        } else {
            return .action
        }
    }

    enum ScriptLineType {
        case empty, character, parenthetical, dialogue, transition, action
    }

    var body: some View {
        HStack(spacing: 0) {
            // Coverage lines indicator (left margin area)
            ZStack(alignment: .leading) {
                ForEach(coverageLines) { line in
                    coverageLineIndicator(for: line)
                }
            }
            .frame(width: 36)

            // Script text with proper screenplay indentation
            scriptTextView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: contentWidth)
        .frame(height: 16) // Fixed height ensures consistent layout when drawing lines
        .background(
            Group {
                if isDragStart {
                    Color.pink.opacity(0.2)
                } else if isHovered && isDrawingMode {
                    Color.pink.opacity(0.1)
                } else {
                    Color.clear
                }
            }
        )
    }

    @ViewBuilder
    private func coverageLineIndicator(for line: CoverageLine) -> some View {
        let offset = CGFloat(coverageLines.firstIndex(where: { $0.id == line.id }) ?? 0) * 5

        // Draw the line style
        switch line.lineStyle {
        case .straight:
            Rectangle()
                .fill(line.camera.color)
                .frame(width: 3)
                .offset(x: offset)
        case .wavy:
            // Simplified wavy line representation
            Rectangle()
                .fill(line.camera.color)
                .frame(width: 3)
                .overlay(
                    GeometryReader { geo in
                        Path { path in
                            let height = geo.size.height
                            let waveHeight: CGFloat = 2
                            let waveLength: CGFloat = 6
                            path.move(to: CGPoint(x: 1.5, y: 0))
                            var y: CGFloat = 0
                            var direction: CGFloat = 1
                            while y < height {
                                path.addLine(to: CGPoint(x: 1.5 + direction * waveHeight, y: y + waveLength / 2))
                                direction *= -1
                                y += waveLength / 2
                            }
                        }
                        .stroke(line.camera.color, lineWidth: 2)
                    }
                )
                .offset(x: offset)
        case .dashed:
            Rectangle()
                .fill(line.camera.color)
                .frame(width: 3)
                .mask(
                    VStack(spacing: 3) {
                        ForEach(0..<20, id: \.self) { _ in
                            Rectangle().frame(height: 6)
                        }
                    }
                )
                .offset(x: offset)
        case .dotted:
            Rectangle()
                .fill(line.camera.color)
                .frame(width: 3)
                .mask(
                    VStack(spacing: 4) {
                        ForEach(0..<30, id: \.self) { _ in
                            Circle().frame(width: 3, height: 3)
                        }
                    }
                )
                .offset(x: offset)
        }
    }

    @ViewBuilder
    private var scriptTextView: some View {
        // Use fixed height for all line types to ensure consistent spacing
        // This prevents the text layout from changing when coverage lines are drawn
        Group {
            switch lineType {
            case .empty:
                Text(" ")
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)

            case .character:
                // Character names: centered, ~3.7" from left edge of content
                Text(trimmedText.uppercased())
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)
                    .padding(.leading, 144) // Indent for character name

            case .parenthetical:
                // Parentheticals: centered under character name
                Text(trimmedText)
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)
                    .padding(.leading, 108)

            case .dialogue:
                // Dialogue: 2.5" left margin, 2.5" right margin from content area
                Text(trimmedText)
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)
                    .padding(.leading, 72)
                    .padding(.trailing, 72)

            case .transition:
                // Transitions: right-aligned
                Text(trimmedText.uppercased())
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .trailing)

            case .action:
                // Action: full width
                Text(trimmedText)
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(.black)
            }
        }
        .frame(height: 16, alignment: .center) // Fixed height for all lines
    }

    // MARK: - Line Type Detection

    private func isCharacterName(_ line: String) -> Bool {
        let cleaned = line
            .replacingOccurrences(of: "(V.O.)", with: "")
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
        line.hasPrefix("    ") || line.hasPrefix("\t")
    }

    private func isTransition(_ line: String) -> Bool {
        let transitions = ["CUT TO:", "FADE OUT.", "FADE IN:", "DISSOLVE TO:",
                          "SMASH CUT TO:", "MATCH CUT TO:", "JUMP CUT TO:",
                          "FADE TO BLACK.", "THE END", "CONTINUED:"]
        return transitions.contains { line.uppercased().contains($0) }
    }
}

// MARK: - Previews
#Preview {
    Scripty(project: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
