import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Top Down Shot Planner
// A Keynote-style editor for creating top-down shot diagrams with rooms, cameras, actors, and lighting

// MARK: - Helper Shape for Camera Cone
private struct ConePathShape: Shape {
    let coneLength: CGFloat
    let coneWidth: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: centerX, y: centerY))
        path.addLine(to: CGPoint(x: centerX + coneLength, y: centerY - coneWidth/2))
        path.addLine(to: CGPoint(x: centerX + coneLength, y: centerY + coneWidth/2))
        path.closeSubpath()
        return path
    }
}

struct TopDownShotPlanner: View {
    @Environment(\.managedObjectContext) private var moc
    let selectedScene: NSManagedObject?

    // Canvas State
    @State private var canvasElements: [CanvasElement] = []
    @State private var selectedElementID: UUID?
    @State private var selectedTool: PlannerTool = .select
    @State private var canvasOffset: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var showRoomPicker = false
    @State private var showInspector = true
    @State private var gridSpacing: CGFloat = 20

    // Grid and snap settings
    @State private var showGrid = true
    @State private var snapToGrid = true

    // Tool-specific settings
    @State private var cameraFOV: Double = 60
    @State private var showCameraCone = true
    @State private var lightIntensity: Double = 100
    @State private var showLightBeam = true
    @State private var wallThickness: Int = 1 // 0=Thin, 1=Medium, 2=Thick

    // Creation state
    @State private var isCreating = false
    @State private var creationStart: CGPoint = .zero

    // Undo/Redo support
    @StateObject private var undoRedoManager = UndoRedoManager<[CanvasElement]>()

    var body: some View {
        contentView
            .sheet(isPresented: $showRoomPicker) {
                RoomTemplatePicker { template in
                    addRoomTemplate(template)
                    showRoomPicker = false
                }
            }
            .onAppear {
                loadCanvasElements()
            }
            .onDisappear {
                saveCanvasElements()
            }
            .onChange(of: canvasElements) { _ in
                // Auto-save on changes (debounced)
                saveCanvasElements()
            }
            #if os(macOS)
            .undoRedoSupport(
                canUndo: undoRedoManager.canUndo,
                canRedo: undoRedoManager.canRedo,
                onUndo: performUndo,
                onRedo: performRedo
            )
            // Delete selected element
            .onDeleteCommand {
                if let id = selectedElementID {
                    deleteElement(id)
                }
            }
            // Escape to deselect
            .onExitCommand {
                selectedElementID = nil
                selectedTool = .select
            }
            // Keyboard shortcuts for tools
            .background(
                KeyboardShortcutHandler(
                    onKeyPress: handleKeyPress
                )
            )
            #endif
    }

    // MARK: - Canvas Persistence
    private var canvasStorageKey: String {
        guard let scene = selectedScene else { return "topdown_canvas_default" }
        return "topdown_canvas_\(scene.objectID.uriRepresentation().absoluteString.hashValue)"
    }

    private func saveCanvasElements() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(canvasElements)
            UserDefaults.standard.set(data, forKey: canvasStorageKey)
            NSLog("[TopDownPlanner] Saved \(canvasElements.count) elements")
        } catch {
            NSLog("[TopDownPlanner] Failed to save canvas: \(error)")
        }
    }

    private func loadCanvasElements() {
        guard let data = UserDefaults.standard.data(forKey: canvasStorageKey) else {
            NSLog("[TopDownPlanner] No saved canvas data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            canvasElements = try decoder.decode([CanvasElement].self, from: data)
            NSLog("[TopDownPlanner] Loaded \(canvasElements.count) elements")
        } catch {
            NSLog("[TopDownPlanner] Failed to load canvas: \(error)")
        }
    }

    #if os(macOS)
    private func handleKeyPress(_ key: String) -> Bool {
        switch key.lowercased() {
        case "v":
            selectedTool = .select
            return true
        case "w":
            selectedTool = .wall
            return true
        case "d":
            selectedTool = .door
            return true
        case "t":
            showRoomPicker = true
            return true
        case "c":
            selectedTool = .camera
            return true
        case "a":
            selectedTool = .actor
            return true
        case "l":
            selectedTool = .light
            return true
        case "p":
            selectedTool = .prop
            return true
        default:
            return false
        }
    }
    #endif

    // MARK: - Undo/Redo
    private func saveStateForUndo() {
        undoRedoManager.saveState(canvasElements)
    }

    private func performUndo() {
        guard let previousState = undoRedoManager.undo(currentState: canvasElements) else { return }
        canvasElements = previousState
        selectedElementID = nil
    }

    private func performRedo() {
        guard let nextState = undoRedoManager.redo(currentState: canvasElements) else { return }
        canvasElements = nextState
        selectedElementID = nil
    }

    @ViewBuilder
    private var contentView: some View {
        #if os(macOS)
        HSplitView {
            mainCanvasArea
                .frame(minWidth: 500)

            // Inspector panel
            if showInspector {
                PlannerInspectorView(
                    elements: $canvasElements,
                    selectedElementID: $selectedElementID,
                    selectedScene: selectedScene,
                    onDelete: deleteElement,
                    onDuplicate: duplicateElement
                )
                .frame(minWidth: 280, maxWidth: 350)
            }
        }
        #else
        NavigationSplitView {
            if showInspector {
                PlannerInspectorView(
                    elements: $canvasElements,
                    selectedElementID: $selectedElementID,
                    selectedScene: selectedScene,
                    onDelete: deleteElement,
                    onDuplicate: duplicateElement
                )
            }
        } detail: {
            mainCanvasArea
        }
        #endif
    }

    // MARK: - Main Canvas Area
    @ViewBuilder
    private var mainCanvasArea: some View {
        VStack(spacing: 0) {
            plannerToolbar

            GeometryReader { geometry in
                ZStack {
                    // Grid background (conditionally visible)
                    if showGrid {
                        PlannerGridView(spacing: gridSpacing, scale: canvasScale)
                    }

                    // Background color
                    #if os(macOS)
                    Color(NSColor.controlBackgroundColor)
                    #else
                    Color(UIColor.secondarySystemBackground)
                    #endif

                    // Room elements (walls, furniture) - render first
                    ForEach($canvasElements.filter { $0.wrappedValue.category == .room }) { $element in
                        PlannerElementView(
                            element: $element,
                            isSelected: selectedElementID == element.id,
                            onSelect: { selectedElementID = element.id },
                            onDragStart: saveStateForUndo,
                            onMove: { delta in moveElement(element.id, by: delta) },
                            onRotate: { angle in rotateElement(element.id, by: angle) },
                            onResize: { handle, delta in resizeElement(element.id, handle: handle, delta: delta) }
                        )
                    }

                    // Production elements (cameras, actors, lights) - render on top
                    ForEach($canvasElements.filter { $0.wrappedValue.category != .room }) { $element in
                        PlannerElementView(
                            element: $element,
                            isSelected: selectedElementID == element.id,
                            onSelect: { selectedElementID = element.id },
                            onDragStart: saveStateForUndo,
                            onMove: { delta in moveElement(element.id, by: delta) },
                            onRotate: { angle in rotateElement(element.id, by: angle) },
                            onResize: { handle, delta in resizeElement(element.id, handle: handle, delta: delta) }
                        )
                    }
                }
                .gesture(canvasGesture(in: geometry.size))
                .onTapGesture {
                    if selectedTool == .select {
                        selectedElementID = nil
                    }
                }
            }
        }
    }

    // MARK: - Professional Toolbar
    private var plannerToolbar: some View {
        VStack(spacing: 0) {
            // Main toolbar row
            GeometryReader { geometry in
                let isCompact = geometry.size.width < 900

                HStack(spacing: 0) {
                    // Left section - Core tools
                    HStack(spacing: 2) {
                        // Selection tool
                        ProToolbarButton(
                            icon: "cursorarrow",
                            label: "Move",
                            shortcut: "V",
                            isSelected: selectedTool == .select,
                            action: { selectedTool = .select }
                        )

                        ProToolbarDivider()

                        // Room tools group
                        ProToolbarGroup(title: "Room", isCompact: isCompact) {
                            ProToolbarButton(
                                icon: "square.split.2x2",
                                label: "Templates",
                                shortcut: "T",
                                isSelected: false,
                                action: { showRoomPicker = true }
                            )
                            ProToolbarButton(
                                icon: "rectangle",
                                label: "Wall",
                                shortcut: "W",
                                isSelected: selectedTool == .wall,
                                action: { selectedTool = .wall }
                            )
                            ProToolbarButton(
                                icon: "door.left.hand.open",
                                label: "Door",
                                shortcut: "D",
                                isSelected: selectedTool == .door,
                                action: { selectedTool = .door }
                            )
                            ProToolbarButton(
                                icon: "window.vertical.open",
                                label: "Window",
                                shortcut: nil,
                                isSelected: selectedTool == .window,
                                action: { selectedTool = .window }
                            )
                        }

                        ProToolbarDivider()

                        // Furniture tools group
                        ProToolbarGroup(title: "Furniture", isCompact: isCompact) {
                            ProToolbarButton(
                                icon: "table.furniture",
                                label: "Table",
                                shortcut: nil,
                                isSelected: selectedTool == .table,
                                action: { selectedTool = .table }
                            )
                            ProToolbarButton(
                                icon: "chair",
                                label: "Chair",
                                shortcut: nil,
                                isSelected: selectedTool == .chair,
                                action: { selectedTool = .chair }
                            )
                            ProToolbarButton(
                                icon: "sofa",
                                label: "Sofa",
                                shortcut: nil,
                                isSelected: selectedTool == .sofa,
                                action: { selectedTool = .sofa }
                            )
                            ProToolbarButton(
                                icon: "bed.double",
                                label: "Bed",
                                shortcut: nil,
                                isSelected: selectedTool == .bed,
                                action: { selectedTool = .bed }
                            )
                        }

                        ProToolbarDivider()

                        // Production tools group
                        ProToolbarGroup(title: "Production", isCompact: isCompact) {
                            ProToolbarButton(
                                icon: "video.fill",
                                label: "Camera",
                                shortcut: "C",
                                isSelected: selectedTool == .camera,
                                action: { selectedTool = .camera }
                            )
                            ProToolbarButton(
                                icon: "figure.stand",
                                label: "Actor",
                                shortcut: "A",
                                isSelected: selectedTool == .actor,
                                action: { selectedTool = .actor }
                            )
                            ProToolbarButton(
                                icon: "lightbulb.fill",
                                label: "Light",
                                shortcut: "L",
                                isSelected: selectedTool == .light,
                                action: { selectedTool = .light }
                            )
                            ProToolbarButton(
                                icon: "cube",
                                label: "Prop",
                                shortcut: "P",
                                isSelected: selectedTool == .prop,
                                action: { selectedTool = .prop }
                            )
                        }
                    }
                    .padding(.leading, 8)

                    Spacer(minLength: 16)

                    // Right section - View controls
                    HStack(spacing: 12) {
                        // Zoom controls with slider
                        ProZoomControl(scale: $canvasScale)

                        ProToolbarDivider()

                        // Grid toggle
                        ProToolbarIconButton(
                            icon: showGrid ? "grid" : "grid.circle",
                            label: "Grid",
                            isActive: showGrid
                        ) {
                            showGrid.toggle()
                        }

                        // Snap to grid
                        ProToolbarIconButton(
                            icon: snapToGrid ? "arrow.up.left.and.arrow.down.right" : "arrow.up.left.and.arrow.down.right.circle",
                            label: "Snap",
                            isActive: snapToGrid
                        ) {
                            snapToGrid.toggle()
                        }

                        ProToolbarDivider()

                        // Undo/Redo
                        HStack(spacing: 4) {
                            ProToolbarIconButton(
                                icon: "arrow.uturn.backward",
                                label: "Undo",
                                isActive: undoRedoManager.canUndo
                            ) {
                                performUndo()
                            }
                            .disabled(!undoRedoManager.canUndo)

                            ProToolbarIconButton(
                                icon: "arrow.uturn.forward",
                                label: "Redo",
                                isActive: undoRedoManager.canRedo
                            ) {
                                performRedo()
                            }
                            .disabled(!undoRedoManager.canRedo)
                        }

                        ProToolbarDivider()

                        // Inspector toggle
                        ProToolbarIconButton(
                            icon: showInspector ? "sidebar.trailing" : "sidebar.trailing",
                            label: "Inspector",
                            isActive: showInspector
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showInspector.toggle()
                            }
                        }
                    }
                    .padding(.trailing, 12)
                }
                .frame(height: 44)
            }
            .frame(height: 44)

            // Context-sensitive options bar
            toolOptionsBar
        }
        #if os(macOS)
        .background(
            VisualEffectBlur(material: .headerView, blendingMode: .behindWindow)
        )
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Tool Options Bar
    @ViewBuilder
    private var toolOptionsBar: some View {
        HStack(spacing: 16) {
            // Tool name and info
            HStack(spacing: 8) {
                Image(systemName: selectedTool.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(selectedTool.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Divider().frame(height: 16)

            // Tool-specific options
            switch selectedTool {
            case .select:
                selectToolOptions
            case .camera:
                cameraToolOptions
            case .light:
                lightToolOptions
            case .wall:
                wallToolOptions
            default:
                defaultToolOptions
            }

            Spacer()

            // Quick actions for selected element
            if selectedElementID != nil {
                selectedElementQuickActions
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 32)
        .background(Color.primary.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var selectToolOptions: some View {
        HStack(spacing: 12) {
            OptionsLabel(text: "Click to select elements, drag to move")
        }
    }

    @ViewBuilder
    private var cameraToolOptions: some View {
        HStack(spacing: 12) {
            OptionsLabel(text: "FOV:")
            OptionsSlider(value: $cameraFOV, range: 20...120, label: "\(Int(cameraFOV))°")

            OptionsLabel(text: "Cone:")
            OptionsToggle(isOn: $showCameraCone, label: "Show")
        }
    }

    @ViewBuilder
    private var lightToolOptions: some View {
        HStack(spacing: 12) {
            OptionsLabel(text: "Intensity:")
            OptionsSlider(value: $lightIntensity, range: 0...100, label: "\(Int(lightIntensity))%")

            OptionsLabel(text: "Beam:")
            OptionsToggle(isOn: $showLightBeam, label: "Show")
        }
    }

    @ViewBuilder
    private var wallToolOptions: some View {
        HStack(spacing: 12) {
            OptionsLabel(text: "Thickness:")
            OptionsSegment(options: ["Thin", "Medium", "Thick"], selected: $wallThickness)
        }
    }

    @ViewBuilder
    private var defaultToolOptions: some View {
        HStack(spacing: 12) {
            OptionsLabel(text: "Click and drag to create element")
        }
    }

    @ViewBuilder
    private var selectedElementQuickActions: some View {
        HStack(spacing: 8) {
            Divider().frame(height: 16)

            Button(action: {
                if let id = selectedElementID {
                    duplicateElement(id)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                    Text("Duplicate")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                if let id = selectedElementID {
                    deleteElement(id)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                    Text("Delete")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Canvas Gestures
    private func canvasGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard selectedTool != .select else { return }
                handleCreationDrag(value, in: size)
            }
            .onEnded { value in
                guard selectedTool != .select else { return }
                finishCreation()
            }
    }

    private func handleCreationDrag(_ value: DragGesture.Value, in size: CGSize) {
        if !isCreating {
            isCreating = true
            creationStart = value.startLocation
            saveStateForUndo() // Save state before adding new element

            let newElement = CanvasElement(
                type: selectedTool.toElementType(),
                position: value.startLocation,
                size: CGSize(width: 1, height: 1),
                rotation: 0
            )
            canvasElements.append(newElement)
            selectedElementID = newElement.id
        } else {
            guard let index = canvasElements.firstIndex(where: { $0.id == selectedElementID }) else { return }

            let width = abs(value.location.x - creationStart.x)
            let height = abs(value.location.y - creationStart.y)
            let minX = min(value.location.x, creationStart.x)
            let minY = min(value.location.y, creationStart.y)

            canvasElements[index].position = CGPoint(x: minX + width/2, y: minY + height/2)
            canvasElements[index].size = CGSize(width: max(width, 20), height: max(height, 20))
        }
    }

    private func finishCreation() {
        isCreating = false
        creationStart = .zero
        selectedTool = .select
    }

    // MARK: - Element Operations
    private func moveElement(_ id: UUID, by delta: CGSize) {
        guard let index = canvasElements.firstIndex(where: { $0.id == id }) else { return }
        canvasElements[index].position.x += delta.width
        canvasElements[index].position.y += delta.height
    }

    private func rotateElement(_ id: UUID, by angle: Double) {
        guard let index = canvasElements.firstIndex(where: { $0.id == id }) else { return }
        canvasElements[index].rotation += angle
    }

    private func resizeElement(_ id: UUID, handle: ResizeHandlePosition, delta: CGSize) {
        guard let index = canvasElements.firstIndex(where: { $0.id == id }) else { return }
        var element = canvasElements[index]

        switch handle {
        case .topLeft:
            element.position.x += delta.width / 2
            element.position.y += delta.height / 2
            element.size.width -= delta.width
            element.size.height -= delta.height
        case .topRight:
            element.position.x += delta.width / 2
            element.position.y += delta.height / 2
            element.size.width += delta.width
            element.size.height -= delta.height
        case .bottomLeft:
            element.position.x += delta.width / 2
            element.position.y += delta.height / 2
            element.size.width -= delta.width
            element.size.height += delta.height
        case .bottomRight:
            element.position.x += delta.width / 2
            element.position.y += delta.height / 2
            element.size.width += delta.width
            element.size.height += delta.height
        }

        element.size.width = max(20, element.size.width)
        element.size.height = max(20, element.size.height)
        canvasElements[index] = element
    }

    private func deleteElement(_ id: UUID) {
        saveStateForUndo()
        canvasElements.removeAll { $0.id == id }
        if selectedElementID == id { selectedElementID = nil }
    }

    private func duplicateElement(_ id: UUID) {
        guard let element = canvasElements.first(where: { $0.id == id }) else { return }
        saveStateForUndo()
        var duplicate = element
        duplicate.id = UUID()
        duplicate.position.x += 30
        duplicate.position.y += 30
        duplicate.name = "\(element.name) Copy"
        canvasElements.append(duplicate)
        selectedElementID = duplicate.id
    }

    private func addRoomTemplate(_ template: RoomTemplate) {
        saveStateForUndo()
        let elements = template.generateElements(at: CGPoint(x: 300, y: 300))
        canvasElements.append(contentsOf: elements)
    }
}

// MARK: - Canvas Element Model
struct CanvasElement: Identifiable, Codable, Equatable {
    static func == (lhs: CanvasElement, rhs: CanvasElement) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.position == rhs.position &&
        lhs.size == rhs.size &&
        lhs.rotation == rhs.rotation &&
        lhs.colorHex == rhs.colorHex &&
        lhs.name == rhs.name &&
        lhs.label == rhs.label &&
        lhs.attachedShotIDString == rhs.attachedShotIDString
    }

    var id = UUID()
    var type: ElementType
    var position: CGPoint
    var size: CGSize
    var rotation: Double // in degrees
    var colorHex: String = "#000000"
    var name: String = ""
    var label: String = ""
    var attachedShotIDString: String? // Store as URI string for Codable

    var color: Color {
        get { Color(hex: colorHex) ?? .primary }
        set { colorHex = newValue.toHex() ?? "#000000" }
    }

    var attachedShotID: NSManagedObjectID? {
        get {
            guard let urlString = attachedShotIDString,
                  let url = URL(string: urlString) else { return nil }
            return PersistenceController.shared.container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url)
        }
        set {
            attachedShotIDString = newValue?.uriRepresentation().absoluteString
        }
    }

    var category: ElementCategory {
        type.category
    }

    enum CodingKeys: String, CodingKey {
        case id, type, position, size, rotation, colorHex, name, label, attachedShotIDString
    }

    init(type: ElementType, position: CGPoint, size: CGSize, rotation: Double, color: Color = .primary, name: String = "") {
        self.type = type
        self.position = position
        self.size = size
        self.rotation = rotation
        self.colorHex = color.toHex() ?? "#000000"
        self.name = name.isEmpty ? type.defaultName : name
    }
}

// MARK: - Element Types
enum ElementType: Codable, CaseIterable {
    // Room elements
    case wall, door, window
    // Furniture
    case table, chair, sofa, bed, desk, cabinet
    // Production
    case camera, actor, light, prop

    var category: ElementCategory {
        switch self {
        case .wall, .door, .window: return .room
        case .table, .chair, .sofa, .bed, .desk, .cabinet: return .furniture
        case .camera, .actor, .light, .prop: return .production
        }
    }

    var defaultName: String {
        switch self {
        case .wall: return "Wall"
        case .door: return "Door"
        case .window: return "Window"
        case .table: return "Table"
        case .chair: return "Chair"
        case .sofa: return "Sofa"
        case .bed: return "Bed"
        case .desk: return "Desk"
        case .cabinet: return "Cabinet"
        case .camera: return "Camera"
        case .actor: return "Actor"
        case .light: return "Light"
        case .prop: return "Prop"
        }
    }

    var icon: String {
        switch self {
        case .wall: return "rectangle"
        case .door: return "door.left.hand.open"
        case .window: return "window.vertical.open"
        case .table: return "table.furniture"
        case .chair: return "chair"
        case .sofa: return "sofa"
        case .bed: return "bed.double"
        case .desk: return "desktopcomputer"
        case .cabinet: return "cabinet"
        case .camera: return "video.fill"
        case .actor: return "figure.stand"
        case .light: return "lightbulb.fill"
        case .prop: return "cube"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .wall: return CGSize(width: 200, height: 15)
        case .door: return CGSize(width: 60, height: 15)
        case .window: return CGSize(width: 80, height: 15)
        case .table: return CGSize(width: 100, height: 60)
        case .chair: return CGSize(width: 40, height: 40)
        case .sofa: return CGSize(width: 120, height: 50)
        case .bed: return CGSize(width: 80, height: 120)
        case .desk: return CGSize(width: 100, height: 50)
        case .cabinet: return CGSize(width: 60, height: 30)
        case .camera: return CGSize(width: 50, height: 50)
        case .actor: return CGSize(width: 40, height: 40)
        case .light: return CGSize(width: 45, height: 45)
        case .prop: return CGSize(width: 40, height: 40)
        }
    }

    var defaultColor: Color {
        switch self {
        #if os(macOS)
        case .wall: return Color(nsColor: .darkGray)
        #else
        case .wall: return Color(uiColor: .darkGray)
        #endif
        case .door: return Color.brown
        case .window: return Color.cyan.opacity(0.7)
        case .table, .desk, .cabinet: return Color.brown.opacity(0.7)
        case .chair: return Color.orange.opacity(0.7)
        case .sofa, .bed: return Color.purple.opacity(0.5)
        case .camera: return Color.blue
        case .actor: return Color.green
        case .light: return Color.yellow
        case .prop: return Color.gray
        }
    }
}

enum ElementCategory {
    case room, furniture, production
}

// MARK: - Planner Tools
enum PlannerTool: String, CaseIterable {
    case select
    case wall, door, window
    case table, chair, sofa, bed
    case camera, actor, light, prop

    func toElementType() -> ElementType {
        switch self {
        case .select: return .wall // shouldn't be used
        case .wall: return .wall
        case .door: return .door
        case .window: return .window
        case .table: return .table
        case .chair: return .chair
        case .sofa: return .sofa
        case .bed: return .bed
        case .camera: return .camera
        case .actor: return .actor
        case .light: return .light
        case .prop: return .prop
        }
    }

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .wall: return "rectangle"
        case .door: return "door.left.hand.open"
        case .window: return "window.vertical.open"
        case .table: return "table.furniture"
        case .chair: return "chair"
        case .sofa: return "sofa"
        case .bed: return "bed.double"
        case .camera: return "video.fill"
        case .actor: return "figure.stand"
        case .light: return "lightbulb.fill"
        case .prop: return "cube"
        }
    }

    var displayName: String {
        switch self {
        case .select: return "Move Tool"
        case .wall: return "Wall Tool"
        case .door: return "Door Tool"
        case .window: return "Window Tool"
        case .table: return "Table Tool"
        case .chair: return "Chair Tool"
        case .sofa: return "Sofa Tool"
        case .bed: return "Bed Tool"
        case .camera: return "Camera Tool"
        case .actor: return "Actor Tool"
        case .light: return "Light Tool"
        case .prop: return "Prop Tool"
        }
    }
}

// MARK: - Grid View
private struct PlannerGridView: View {
    let spacing: CGFloat
    let scale: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let adjustedSpacing = spacing * scale
            let rows = Int(geometry.size.height / adjustedSpacing) + 1
            let cols = Int(geometry.size.width / adjustedSpacing) + 1

            Canvas { context, size in
                for row in 0...rows {
                    for col in 0...cols {
                        let x = CGFloat(col) * adjustedSpacing
                        let y = CGFloat(row) * adjustedSpacing
                        let dotSize: CGFloat = scale > 0.5 ? 2 : 1.5
                        let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: rect), with: .color(.gray.opacity(0.3)))
                    }
                }
            }
        }
    }
}

// MARK: - Element View
private struct PlannerElementView: View {
    @Binding var element: CanvasElement
    let isSelected: Bool
    let onSelect: () -> Void
    let onDragStart: () -> Void
    let onMove: (CGSize) -> Void
    let onRotate: (Double) -> Void
    let onResize: (ResizeHandlePosition, CGSize) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isRotating = false
    @State private var rotationStartAngle: Double = 0

    var body: some View {
        ZStack {
            // Main element shape
            elementShape
                .rotationEffect(.degrees(element.rotation))
                .position(x: element.position.x + dragOffset.width, y: element.position.y + dragOffset.height)
                .gesture(dragGesture)

            // Selection overlay and handles
            if isSelected {
                selectionOverlay
                rotationHandle
                resizeHandles
            }
        }
    }

    @ViewBuilder
    private var elementShape: some View {
        switch element.type {
        case .wall:
            WallShape(size: element.size, color: element.type.defaultColor)
        case .door:
            DoorShape(size: element.size)
        case .window:
            WindowShape(size: element.size)
        case .table:
            TableShape(size: element.size)
        case .chair:
            ChairShape(size: element.size, rotation: element.rotation)
        case .sofa:
            SofaShape(size: element.size)
        case .bed:
            BedShape(size: element.size)
        case .desk:
            DeskShape(size: element.size)
        case .cabinet:
            CabinetShape(size: element.size)
        case .camera:
            DirectionalCameraShape(size: element.size, rotation: element.rotation, label: element.label)
        case .actor:
            StickFigureShape(size: element.size, rotation: element.rotation, label: element.label)
        case .light:
            DirectionalLightShape(size: element.size, rotation: element.rotation, label: element.label)
        case .prop:
            PropShape(size: element.size, label: element.label)
        }
    }

    private var selectionOverlay: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            .frame(width: element.size.width + 10, height: element.size.height + 10)
            .rotationEffect(.degrees(element.rotation))
            .position(element.position)
    }

    private var rotationHandle: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .position(
                x: element.position.x,
                y: element.position.y - element.size.height/2 - 30
            )
            .gesture(rotationGesture)
    }

    private var resizeHandles: some View {
        Group {
            ForEach(ResizeHandlePosition.allCases, id: \.self) { handle in
                PlannerResizeHandleView(
                    element: element,
                    handle: handle,
                    onDragStart: onDragStart,
                    onResize: onResize
                )
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    onDragStart() // Save state for undo
                    onSelect()
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                onMove(value.translation)
                isDragging = false
                dragOffset = .zero
            }
    }

    private var rotationGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isRotating {
                    isRotating = true
                    rotationStartAngle = element.rotation
                    onDragStart() // Save state for undo
                }
                let center = element.position
                let currentPoint = CGPoint(
                    x: center.x + value.translation.width,
                    y: center.y - element.size.height/2 - 30 + value.translation.height
                )
                let angle = atan2(currentPoint.y - center.y, currentPoint.x - center.x)
                let degrees = angle * 180 / .pi + 90
                onRotate(degrees - element.rotation)
            }
            .onEnded { _ in
                isRotating = false
            }
    }
}

// MARK: - Resize Handle
enum ResizeHandlePosition: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct PlannerResizeHandleView: View {
    let element: CanvasElement
    let handle: ResizeHandlePosition
    let onDragStart: () -> Void
    let onResize: (ResizeHandlePosition, CGSize) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .frame(width: 10, height: 10)
            .position(handlePosition)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStart() // Save state for undo
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        onResize(handle, value.translation)
                        dragOffset = .zero
                        isDragging = false
                    }
            )
            .offset(dragOffset)
    }

    private var handlePosition: CGPoint {
        let hw = element.size.width / 2
        let hh = element.size.height / 2
        let center = element.position

        switch handle {
        case .topLeft: return CGPoint(x: center.x - hw, y: center.y - hh)
        case .topRight: return CGPoint(x: center.x + hw, y: center.y - hh)
        case .bottomLeft: return CGPoint(x: center.x - hw, y: center.y + hh)
        case .bottomRight: return CGPoint(x: center.x + hw, y: center.y + hh)
        }
    }
}

// MARK: - Room Shapes

private struct WallShape: View {
    let size: CGSize
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size.width, height: size.height)
            .overlay(
                Rectangle()
                    .stroke(Color.black.opacity(0.5), lineWidth: 1)
            )
    }
}

private struct DoorShape: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Door frame
            Rectangle()
                .fill(Color.brown.opacity(0.6))
                .frame(width: size.width, height: size.height)

            // Door swing arc
            Path { path in
                path.addArc(
                    center: CGPoint(x: -size.width/2, y: 0),
                    radius: size.width,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            }
            .stroke(Color.brown.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct WindowShape: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Window frame
            Rectangle()
                .fill(Color.cyan.opacity(0.3))
                .frame(width: size.width, height: size.height)

            // Window panes
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .stroke(Color.gray, lineWidth: 1)
                }
            }
            .padding(2)
        }
        .frame(width: size.width, height: size.height)
        .overlay(Rectangle().stroke(Color.gray, lineWidth: 2))
    }
}

// MARK: - Furniture Shapes

private struct TableShape: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Table top
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.brown.opacity(0.6))

            // Table edge highlight
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.brown, lineWidth: 2)
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct ChairShape: View {
    let size: CGSize
    let rotation: Double

    var body: some View {
        ZStack {
            // Seat
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange.opacity(0.5))
                .frame(width: size.width * 0.8, height: size.height * 0.8)

            // Backrest indicator (shows direction)
            Rectangle()
                .fill(Color.orange.opacity(0.8))
                .frame(width: size.width * 0.8, height: 6)
                .offset(y: -size.height * 0.35)
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.orange, lineWidth: 1.5)
        )
    }
}

private struct SofaShape: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Main body
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.4))

            // Backrest
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.purple.opacity(0.6))
                .frame(width: size.width - 10, height: 12)
                .offset(y: -size.height/2 + 10)

            // Seat cushions
            HStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 14)
        }
        .frame(width: size.width, height: size.height)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 2))
    }
}

private struct BedShape: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Mattress
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.2))

            // Headboard
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.brown.opacity(0.7))
                .frame(width: size.width, height: 12)
                .offset(y: -size.height/2 + 6)

            // Pillows
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: size.width * 0.4, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: size.width * 0.4, height: 16)
            }
            .offset(y: -size.height/2 + 24)
        }
        .frame(width: size.width, height: size.height)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.brown.opacity(0.5), lineWidth: 2))
    }
}

private struct DeskShape: View {
    let size: CGSize

    var body: some View {
        ZStack {
            // Desk surface
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.brown.opacity(0.5))

            // Keyboard area indicator
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                .frame(width: size.width * 0.5, height: size.height * 0.3)
                .offset(y: size.height * 0.15)
        }
        .frame(width: size.width, height: size.height)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.brown, lineWidth: 2))
    }
}

private struct CabinetShape: View {
    let size: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.brown.opacity(0.6))

            // Drawer lines
            VStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.brown.opacity(0.3))
                        .frame(height: 2)
                }
            }
            .padding(4)
        }
        .frame(width: size.width, height: size.height)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.brown, lineWidth: 1.5))
    }
}

// MARK: - Production Shapes with Direction

private struct DirectionalCameraShape: View {
    let size: CGSize
    let rotation: Double
    let label: String

    var body: some View {
        ZStack {
            // Camera field of view cone
            ZStack {
                ConePathShape(coneLength: size.width * 1.5, coneWidth: size.width * 1.2, centerX: size.width/2, centerY: size.height/2)
                    .fill(Color.blue.opacity(0.15))

                ConePathShape(coneLength: size.width * 1.5, coneWidth: size.width * 1.2, centerX: size.width/2, centerY: size.height/2)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            }

            // Camera body
            ZStack {
                // Main body
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: size.width * 0.7, height: size.height * 0.6)

                // Lens
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: size.width * 0.35, height: size.width * 0.35)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                    )

                // Direction indicator arrow
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: size.width * 0.25))
                    .foregroundColor(.blue)
                    .offset(x: size.width * 0.35)
            }

            // Camera outline
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: size.width, height: size.height)

            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(3)
                    .offset(y: size.height/2 + 12)
            }
        }
        .frame(width: size.width * 2.5, height: size.height * 2)
    }
}

private struct StickFigureShape: View {
    let size: CGSize
    let rotation: Double
    let label: String

    var body: some View {
        ZStack {
            // Direction indicator (facing direction)
            Path { path in
                path.move(to: CGPoint(x: size.width/2, y: size.height/2 - 5))
                path.addLine(to: CGPoint(x: size.width/2 + size.width * 0.6, y: size.height/2 - 5))
            }
            .stroke(Color.green.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [4, 2]))

            // Arrow head
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 8))
                .foregroundColor(.green.opacity(0.6))
                .offset(x: size.width * 0.55, y: -5)

            // Stick figure
            Canvas { context, canvasSize in
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                let scale = min(canvasSize.width, canvasSize.height) / 40

                // Head
                let headRadius = 6 * scale
                let headCenter = CGPoint(x: centerX, y: centerY - 12 * scale)
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: headCenter.x - headRadius,
                        y: headCenter.y - headRadius,
                        width: headRadius * 2,
                        height: headRadius * 2
                    )),
                    with: .color(.green),
                    lineWidth: 2
                )
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: headCenter.x - headRadius,
                        y: headCenter.y - headRadius,
                        width: headRadius * 2,
                        height: headRadius * 2
                    )),
                    with: .color(.green.opacity(0.3))
                )

                // Body
                var bodyPath = Path()
                bodyPath.move(to: CGPoint(x: centerX, y: centerY - 6 * scale))
                bodyPath.addLine(to: CGPoint(x: centerX, y: centerY + 6 * scale))
                context.stroke(bodyPath, with: .color(.green), lineWidth: 2.5)

                // Arms
                var armsPath = Path()
                armsPath.move(to: CGPoint(x: centerX - 8 * scale, y: centerY - 2 * scale))
                armsPath.addLine(to: CGPoint(x: centerX + 8 * scale, y: centerY - 2 * scale))
                context.stroke(armsPath, with: .color(.green), lineWidth: 2)

                // Legs
                var leftLeg = Path()
                leftLeg.move(to: CGPoint(x: centerX, y: centerY + 6 * scale))
                leftLeg.addLine(to: CGPoint(x: centerX - 6 * scale, y: centerY + 16 * scale))
                context.stroke(leftLeg, with: .color(.green), lineWidth: 2)

                var rightLeg = Path()
                rightLeg.move(to: CGPoint(x: centerX, y: centerY + 6 * scale))
                rightLeg.addLine(to: CGPoint(x: centerX + 6 * scale, y: centerY + 16 * scale))
                context.stroke(rightLeg, with: .color(.green), lineWidth: 2)
            }
            .frame(width: size.width, height: size.height)

            // Background circle
            Circle()
                .stroke(Color.green, lineWidth: 2)
                .frame(width: size.width, height: size.height)
                .background(Circle().fill(Color.green.opacity(0.1)))

            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(3)
                    .offset(y: size.height/2 + 12)
            }
        }
        .frame(width: size.width * 1.8, height: size.height * 1.5)
    }
}

private struct DirectionalLightShape: View {
    let size: CGSize
    let rotation: Double
    let label: String

    var body: some View {
        ZStack {
            // Light beam cone
            Path { path in
                let beamLength = size.width * 2
                let beamWidth = size.width * 1.5
                path.move(to: CGPoint(x: size.width/2, y: size.height/2))
                path.addLine(to: CGPoint(x: size.width/2 + beamLength, y: size.height/2 - beamWidth/2))
                path.addLine(to: CGPoint(x: size.width/2 + beamLength, y: size.height/2 + beamWidth/2))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.4), Color.yellow.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Light source circle
            Circle()
                .fill(Color.yellow)
                .frame(width: size.width * 0.6, height: size.height * 0.6)
                .overlay(
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                )

            // Rays emanating from light
            ForEach(0..<6, id: \.self) { i in
                Rectangle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 3, height: size.height * 0.25)
                    .offset(y: -size.height * 0.35)
                    .rotationEffect(.degrees(Double(i) * 60))
            }

            // Light fixture outline
            Circle()
                .stroke(Color.orange, lineWidth: 2)
                .frame(width: size.width, height: size.height)

            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(3)
                    .offset(y: size.height/2 + 12)
            }
        }
        .frame(width: size.width * 3, height: size.height * 2)
    }
}

private struct PropShape: View {
    let size: CGSize
    let label: String

    var body: some View {
        ZStack {
            // Prop box
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size.width, height: size.height)

            Image(systemName: "cube")
                .font(.system(size: min(size.width, size.height) * 0.5))
                .foregroundColor(.gray)

            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray, lineWidth: 2)
                .frame(width: size.width, height: size.height)

            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(3)
                    .offset(y: size.height/2 + 10)
            }
        }
    }
}

// MARK: - Professional Toolbar Components

/// Professional toolbar button with icon, label, and optional keyboard shortcut
private struct ProToolbarButton: View {
    let icon: String
    let label: String
    let shortcut: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(height: 16)

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 44, height: 38)
            .foregroundStyle(isSelected ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(shortcut != nil ? "\(label) (\(shortcut!))" : label)
    }
}

/// Compact icon-only toolbar button for view controls
private struct ProToolbarIconButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isActive ? Color.accentColor.opacity(0.1) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
    }
}

/// Toolbar divider with proper spacing
private struct ProToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 24)
            .padding(.horizontal, 6)
    }
}

/// Toolbar group with optional label header
private struct ProToolbarGroup<Content: View>: View {
    let title: String
    let isCompact: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if !isCompact {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                    .frame(height: 10)
            }

            HStack(spacing: 2) {
                content
            }
        }
    }
}

/// Professional zoom control with slider
private struct ProZoomControl: View {
    @Binding var scale: CGFloat

    @State private var isHovered = false
    @State private var showSlider = false

    private let zoomLevels: [CGFloat] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]

    var body: some View {
        HStack(spacing: 4) {
            // Zoom out button
            Button(action: { zoomOut() }) {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Zoom level display / slider toggle
            Button(action: { showSlider.toggle() }) {
                Text("\(Int(scale * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .frame(width: 42)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSlider) {
                VStack(spacing: 8) {
                    Text("Zoom Level")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Slider(value: $scale, in: 0.25...3.0, step: 0.05)
                        .frame(width: 150)

                    HStack {
                        ForEach(zoomLevels, id: \.self) { level in
                            Button("\(Int(level * 100))%") {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    scale = level
                                }
                            }
                            .font(.system(size: 9))
                            .buttonStyle(.plain)
                            .foregroundStyle(scale == level ? .primary : .secondary)
                        }
                    }
                }
                .padding(12)
            }

            // Zoom in button
            Button(action: { zoomIn() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Fit to view button
            Button(action: { scale = 1.0 }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Fit to View (100%)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(isHovered ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
    }

    private func zoomIn() {
        let nextLevel = zoomLevels.first { $0 > scale } ?? 3.0
        withAnimation(.easeInOut(duration: 0.15)) {
            scale = nextLevel
        }
    }

    private func zoomOut() {
        let prevLevel = zoomLevels.last { $0 < scale } ?? 0.25
        withAnimation(.easeInOut(duration: 0.15)) {
            scale = prevLevel
        }
    }
}

// MARK: - Options Bar Helper Views

private struct OptionsLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }
}

private struct OptionsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Slider(value: $value, in: range)
                .frame(width: 80)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 35)
        }
    }
}

private struct OptionsToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: 10))
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }
}

private struct OptionsSegment: View {
    let options: [String]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: { selected = index }) {
                    Text(options[index])
                        .font(.system(size: 9, weight: selected == index ? .semibold : .regular))
                        .foregroundStyle(selected == index ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selected == index ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Keyboard Shortcut Handler
#if os(macOS)
private struct KeyboardShortcutHandler: NSViewRepresentable {
    let onKeyPress: (String) -> Bool

    func makeNSView(context: Context) -> KeyboardEventView {
        let view = KeyboardEventView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: KeyboardEventView, context: Context) {
        nsView.onKeyPress = onKeyPress
    }

    class KeyboardEventView: NSView {
        var onKeyPress: ((String) -> Bool)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard let characters = event.charactersIgnoringModifiers,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  let handler = onKeyPress,
                  handler(characters) else {
                super.keyDown(with: event)
                return
            }
        }
    }
}
#else
// iOS Keyboard Handler - Uses hardware keyboard commands on iPadOS
// On iPhone, the toolbar buttons are used instead
import UIKit

private struct KeyboardShortcutHandler: UIViewRepresentable {
    let onKeyPress: (String) -> Bool

    func makeUIView(context: Context) -> KeyboardEventViewiOS {
        let view = KeyboardEventViewiOS()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateUIView(_ uiView: KeyboardEventViewiOS, context: Context) {
        uiView.onKeyPress = onKeyPress
    }

    class KeyboardEventViewiOS: UIView {
        var onKeyPress: ((String) -> Bool)?

        override var canBecomeFirstResponder: Bool { true }

        // Hardware keyboard support on iPadOS
        override var keyCommands: [UIKeyCommand]? {
            let shortcuts: [(String, UIKeyModifierFlags, Selector)] = [
                ("v", [], #selector(handleV)),
                ("w", [], #selector(handleW)),
                ("d", [], #selector(handleD)),
                ("t", [], #selector(handleT)),
                ("c", [], #selector(handleC)),
                ("a", [], #selector(handleA)),
                ("l", [], #selector(handleL)),
                ("p", [], #selector(handleP))
            ]

            return shortcuts.map { input, modifiers, selector in
                UIKeyCommand(input: input, modifierFlags: modifiers, action: selector)
            }
        }

        @objc private func handleV() { _ = onKeyPress?("v") }
        @objc private func handleW() { _ = onKeyPress?("w") }
        @objc private func handleD() { _ = onKeyPress?("d") }
        @objc private func handleT() { _ = onKeyPress?("t") }
        @objc private func handleC() { _ = onKeyPress?("c") }
        @objc private func handleA() { _ = onKeyPress?("a") }
        @objc private func handleL() { _ = onKeyPress?("l") }
        @objc private func handleP() { _ = onKeyPress?("p") }
    }
}
#endif

// MARK: - Inspector View
private struct PlannerInspectorView: View {
    @Binding var elements: [CanvasElement]
    @Binding var selectedElementID: UUID?
    let selectedScene: NSManagedObject?
    let onDelete: (UUID) -> Void
    let onDuplicate: (UUID) -> Void

    var selectedElement: CanvasElement? {
        elements.first { $0.id == selectedElementID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inspector")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(elements.count) elements")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.03))
            .overlay(Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1), alignment: .bottom)

            ScrollView {
                VStack(spacing: 12) {
                    // Selected element properties
                    if let element = selectedElement,
                       let index = elements.firstIndex(where: { $0.id == element.id }) {
                        selectedElementProperties(element: element, index: index)
                    }

                    Divider()

                    // Layers list
                    layersList
                }
                .padding(12)
            }
        }
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
    }

    @ViewBuilder
    private func selectedElementProperties(element: CanvasElement, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Element type and name
            HStack {
                Image(systemName: element.type.icon)
                    .foregroundColor(element.type.defaultColor)
                Text(element.type.defaultName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            // Name field
            HStack {
                Text("Name")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField("Name", text: Binding(
                    get: { elements[index].name },
                    set: { elements[index].name = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            }

            // Label field (for production elements)
            if element.category == .production {
                HStack {
                    Text("Label")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("A, B, Key...", text: Binding(
                        get: { elements[index].label },
                        set: { elements[index].label = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                }
            }

            // Rotation control
            HStack {
                Text("Rotation")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Slider(value: Binding(
                    get: { elements[index].rotation },
                    set: { elements[index].rotation = $0 }
                ), in: 0...360, step: 15)

                Text("\(Int(element.rotation))°")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 35)
            }

            // Position
            HStack {
                Text("Position")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text("X: \(Int(element.position.x))")
                    .font(.system(size: 10))
                    .frame(width: 50)
                Text("Y: \(Int(element.position.y))")
                    .font(.system(size: 10))
                    .frame(width: 50)
                Spacer()
            }

            // Size
            HStack {
                Text("Size")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Text("W: \(Int(element.size.width))")
                    .font(.system(size: 10))
                    .frame(width: 50)
                Text("H: \(Int(element.size.height))")
                    .font(.system(size: 10))
                    .frame(width: 50)
                Spacer()
            }

            // Actions
            HStack(spacing: 8) {
                Button(action: { onDuplicate(element.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Duplicate")
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Button(action: { onDelete(element.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }

    private var layersList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Layers")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(elements.enumerated().reversed()), id: \.element.id) { index, element in
                HStack(spacing: 8) {
                    Image(systemName: element.type.icon)
                        .font(.system(size: 11))
                        .foregroundColor(element.type.defaultColor)
                        .frame(width: 20)

                    Text(element.name)
                        .font(.system(size: 11))
                        .lineLimit(1)

                    Spacer()

                    if !element.label.isEmpty {
                        Text(element.label)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(element.type.defaultColor.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(selectedElementID == element.id ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(selectedElementID == element.id ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedElementID = element.id
                }
            }
        }
    }
}

// MARK: - Room Templates
struct RoomTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let walls: [WallConfig]
    let furniture: [FurnitureConfig]

    struct WallConfig {
        let offset: CGPoint
        let size: CGSize
        let rotation: Double
    }

    struct FurnitureConfig {
        let type: ElementType
        let offset: CGPoint
        let size: CGSize
        let rotation: Double
    }

    func generateElements(at center: CGPoint) -> [CanvasElement] {
        var elements: [CanvasElement] = []

        // Generate walls
        for (index, wall) in walls.enumerated() {
            elements.append(CanvasElement(
                type: .wall,
                position: CGPoint(x: center.x + wall.offset.x, y: center.y + wall.offset.y),
                size: wall.size,
                rotation: wall.rotation,
                name: "Wall \(index + 1)"
            ))
        }

        // Generate furniture
        for furniture in furniture {
            elements.append(CanvasElement(
                type: furniture.type,
                position: CGPoint(x: center.x + furniture.offset.x, y: center.y + furniture.offset.y),
                size: furniture.size,
                rotation: furniture.rotation
            ))
        }

        return elements
    }

    // MARK: - Preset Templates
    static let livingRoom = RoomTemplate(
        name: "Living Room",
        icon: "sofa",
        description: "Standard living room with sofa and TV area",
        walls: [
            WallConfig(offset: CGPoint(x: 0, y: -100), size: CGSize(width: 250, height: 12), rotation: 0),     // Top
            WallConfig(offset: CGPoint(x: 0, y: 100), size: CGSize(width: 250, height: 12), rotation: 0),      // Bottom
            WallConfig(offset: CGPoint(x: -125, y: 0), size: CGSize(width: 200, height: 12), rotation: 90),    // Left
            WallConfig(offset: CGPoint(x: 125, y: 0), size: CGSize(width: 200, height: 12), rotation: 90),     // Right
        ],
        furniture: [
            FurnitureConfig(type: .sofa, offset: CGPoint(x: 0, y: 50), size: CGSize(width: 120, height: 50), rotation: 0),
            FurnitureConfig(type: .table, offset: CGPoint(x: 0, y: 0), size: CGSize(width: 80, height: 50), rotation: 0),
            FurnitureConfig(type: .chair, offset: CGPoint(x: -70, y: 0), size: CGSize(width: 40, height: 40), rotation: 90),
            FurnitureConfig(type: .chair, offset: CGPoint(x: 70, y: 0), size: CGSize(width: 40, height: 40), rotation: -90),
        ]
    )

    static let bedroom = RoomTemplate(
        name: "Bedroom",
        icon: "bed.double",
        description: "Master bedroom with bed and nightstands",
        walls: [
            WallConfig(offset: CGPoint(x: 0, y: -100), size: CGSize(width: 220, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: 0, y: 100), size: CGSize(width: 220, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: -110, y: 0), size: CGSize(width: 200, height: 12), rotation: 90),
            WallConfig(offset: CGPoint(x: 110, y: 0), size: CGSize(width: 200, height: 12), rotation: 90),
        ],
        furniture: [
            FurnitureConfig(type: .bed, offset: CGPoint(x: 0, y: -30), size: CGSize(width: 90, height: 130), rotation: 0),
            FurnitureConfig(type: .cabinet, offset: CGPoint(x: -60, y: -60), size: CGSize(width: 35, height: 35), rotation: 0),
            FurnitureConfig(type: .cabinet, offset: CGPoint(x: 60, y: -60), size: CGSize(width: 35, height: 35), rotation: 0),
        ]
    )

    static let kitchen = RoomTemplate(
        name: "Kitchen",
        icon: "refrigerator",
        description: "Kitchen with counter and dining area",
        walls: [
            WallConfig(offset: CGPoint(x: 0, y: -80), size: CGSize(width: 200, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: 0, y: 80), size: CGSize(width: 200, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: -100, y: 0), size: CGSize(width: 160, height: 12), rotation: 90),
            WallConfig(offset: CGPoint(x: 100, y: 0), size: CGSize(width: 160, height: 12), rotation: 90),
        ],
        furniture: [
            FurnitureConfig(type: .cabinet, offset: CGPoint(x: -70, y: -50), size: CGSize(width: 50, height: 25), rotation: 0),
            FurnitureConfig(type: .cabinet, offset: CGPoint(x: -70, y: -20), size: CGSize(width: 50, height: 25), rotation: 0),
            FurnitureConfig(type: .table, offset: CGPoint(x: 30, y: 30), size: CGSize(width: 70, height: 70), rotation: 0),
            FurnitureConfig(type: .chair, offset: CGPoint(x: 0, y: 30), size: CGSize(width: 30, height: 30), rotation: 90),
            FurnitureConfig(type: .chair, offset: CGPoint(x: 60, y: 30), size: CGSize(width: 30, height: 30), rotation: -90),
            FurnitureConfig(type: .chair, offset: CGPoint(x: 30, y: 0), size: CGSize(width: 30, height: 30), rotation: 180),
            FurnitureConfig(type: .chair, offset: CGPoint(x: 30, y: 60), size: CGSize(width: 30, height: 30), rotation: 0),
        ]
    )

    static let office = RoomTemplate(
        name: "Office",
        icon: "desktopcomputer",
        description: "Office space with desk and meeting area",
        walls: [
            WallConfig(offset: CGPoint(x: 0, y: -90), size: CGSize(width: 240, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: 0, y: 90), size: CGSize(width: 240, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: -120, y: 0), size: CGSize(width: 180, height: 12), rotation: 90),
            WallConfig(offset: CGPoint(x: 120, y: 0), size: CGSize(width: 180, height: 12), rotation: 90),
        ],
        furniture: [
            FurnitureConfig(type: .desk, offset: CGPoint(x: -50, y: -40), size: CGSize(width: 100, height: 50), rotation: 0),
            FurnitureConfig(type: .chair, offset: CGPoint(x: -50, y: -10), size: CGSize(width: 35, height: 35), rotation: 180),
            FurnitureConfig(type: .table, offset: CGPoint(x: 50, y: 30), size: CGSize(width: 80, height: 60), rotation: 0),
            FurnitureConfig(type: .chair, offset: CGPoint(x: 20, y: 30), size: CGSize(width: 30, height: 30), rotation: 90),
            FurnitureConfig(type: .chair, offset: CGPoint(x: 80, y: 30), size: CGSize(width: 30, height: 30), rotation: -90),
        ]
    )

    static let bathroom = RoomTemplate(
        name: "Bathroom",
        icon: "shower",
        description: "Small bathroom layout",
        walls: [
            WallConfig(offset: CGPoint(x: 0, y: -60), size: CGSize(width: 140, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: 0, y: 60), size: CGSize(width: 140, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: -70, y: 0), size: CGSize(width: 120, height: 12), rotation: 90),
            WallConfig(offset: CGPoint(x: 70, y: 0), size: CGSize(width: 120, height: 12), rotation: 90),
        ],
        furniture: []
    )

    static let hallway = RoomTemplate(
        name: "Hallway",
        icon: "arrow.left.and.right",
        description: "Long corridor",
        walls: [
            WallConfig(offset: CGPoint(x: 0, y: -30), size: CGSize(width: 300, height: 12), rotation: 0),
            WallConfig(offset: CGPoint(x: 0, y: 30), size: CGSize(width: 300, height: 12), rotation: 0),
        ],
        furniture: []
    )

    static let exterior = RoomTemplate(
        name: "Exterior",
        icon: "tree",
        description: "Outdoor space (no walls)",
        walls: [],
        furniture: []
    )

    static let staircase = RoomTemplate(
        name: "Staircase",
        icon: "stairs",
        description: "Stairwell area",
        walls: [
            WallConfig(offset: CGPoint(x: -50, y: 0), size: CGSize(width: 120, height: 12), rotation: 90),
            WallConfig(offset: CGPoint(x: 50, y: 0), size: CGSize(width: 120, height: 12), rotation: 90),
        ],
        furniture: []
    )

    static let allTemplates: [RoomTemplate] = [
        livingRoom, bedroom, kitchen, office, bathroom, hallway, exterior, staircase
    ]
}

// MARK: - Room Template Picker
private struct RoomTemplatePicker: View {
    let onSelect: (RoomTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Room Template")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.primary.opacity(0.03))

            // Grid of templates
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(RoomTemplate.allTemplates) { template in
                        RoomTemplateCard(template: template) {
                            onSelect(template)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }
}

private struct RoomTemplateCard: View {
    let template: RoomTemplate
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: template.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                    .frame(height: 40)

                // Name
                Text(template.name)
                    .font(.system(size: 13, weight: .semibold))

                // Description
                Text(template.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isHovered ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview
#Preview {
    TopDownShotPlanner(selectedScene: nil)
        .frame(width: 1000, height: 700)
}
