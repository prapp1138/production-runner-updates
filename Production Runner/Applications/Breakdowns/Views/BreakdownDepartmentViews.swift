import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Breakdown Department Enum
enum BreakdownDepartment: String, CaseIterable, Identifiable {
    case script = "Script"
    case art = "Art"
    case camera = "Camera"
    case sound = "Sound"
    case lighting = "Lighting"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .script: return "doc.text.fill"
        case .art: return "paintbrush.fill"
        case .camera: return "camera.fill"
        case .sound: return "waveform"
        case .lighting: return "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .script: return .blue
        case .art: return .orange
        case .camera: return .cyan
        case .sound: return .green
        case .lighting: return .yellow
        }
    }

    var description: String {
        switch self {
        case .script: return "Scene breakdowns with cast, props, and elements"
        case .art: return "Props, set dressing, and art department notes"
        case .camera: return "Camera setups, lenses, and framing notes"
        case .sound: return "Audio notes, mic placements, and sound design"
        case .lighting: return "Lighting setups, fixtures, and electrical notes"
        }
    }
}

// MARK: - Scene Heading Helper
private func sceneHeading(for scene: SceneEntity) -> String {
    let locType = (scene.locationType ?? "INT.").trimmingCharacters(in: .whitespacesAndNewlines)
    let tod = (scene.timeOfDay ?? "DAY").trimmingCharacters(in: .whitespacesAndNewlines)

    var location = ""
    if scene.entity.attributesByName.keys.contains("heading"),
       let h = scene.value(forKey: "heading") as? String,
       !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        location = h.trimmingCharacters(in: .whitespacesAndNewlines)
    } else if let loc = scene.scriptLocation?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
        location = loc
    } else {
        location = "Untitled Scene"
    }

    return "\(locType) \(location) - \(tod)".uppercased()
}

// MARK: - Art Breakdown View
struct ArtBreakdownView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    let scenes: [SceneEntity]
    @Binding var selectedSceneID: NSManagedObjectID?

    @State private var sidebarWidth: CGFloat = 300
    @State private var searchText: String = ""

    private var selectedScene: SceneEntity? {
        guard let id = selectedSceneID else { return nil }
        return scenes.first { $0.objectID == id }
    }

    private var filteredScenes: [SceneEntity] {
        if searchText.isEmpty {
            return scenes
        }
        return scenes.filter { scene in
            let number = scene.number ?? ""
            let heading = sceneHeading(for: scene)
            return number.localizedCaseInsensitiveContains(searchText) ||
                   heading.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalProps: Int {
        scenes.compactMap { $0.breakdown?.getProps().count }.reduce(0, +)
    }

    private var totalArtItems: Int {
        scenes.compactMap { $0.breakdown?.getArt().count }.reduce(0, +)
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            sceneSidebar
                .frame(minWidth: 260, idealWidth: sidebarWidth, maxWidth: 400)

            artDetailPane
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        NavigationSplitView {
            sceneSidebarContent
        } detail: {
            artDetailPane
        }
        #endif
    }

    #if os(macOS)
    private var sceneSidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scenes")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(scenes.count) total • \(totalProps) props • \(totalArtItems) art items")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                colorScheme == .dark
                    ? Color(white: 0.12)
                    : Color(white: 0.98)
            )

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.94))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            sceneSidebarContent
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.96))
    }
    #endif

    private var sceneSidebarContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredScenes, id: \.objectID) { scene in
                    ArtSceneRow(
                        scene: scene,
                        isSelected: selectedSceneID == scene.objectID
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSceneID = scene.objectID
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var artDetailPane: some View {
        Group {
            if let scene = selectedScene {
                ArtDetailView(scene: scene)
            } else {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "paintbrush.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange.opacity(0.7))

            Text("Art Department")
                .font(.title.bold())

            Text("Select a scene to view props, set dressing, and art department continuity")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Art Scene Row
private struct ArtSceneRow: View {
    @ObservedObject var scene: SceneEntity
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var propsCount: Int {
        scene.breakdown?.getProps().count ?? 0
    }

    private var artCount: Int {
        scene.breakdown?.getArt().count ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(scene.number ?? "—")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 40, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(sceneHeading(for: scene))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if propsCount > 0 {
                        Label("\(propsCount)", systemImage: "cube.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if artCount > 0 {
                        Label("\(artCount)", systemImage: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if propsCount == 0 && artCount == 0 {
                        Text("No items")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected
                    ? Color.orange.opacity(0.15)
                    : (colorScheme == .dark ? Color(white: 0.14) : Color(white: 0.98)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Art Budget Item Model
private struct ArtBudgetItem: Identifiable {
    let id = UUID()
    var name: String
    var itemType: ArtBudgetItemType
    var cost: Double
    var quantity: Int
    var source: String
    var isReady: Bool
    var category: ArtBudgetCategory
    var imageData: Data?
    var notes: String

    enum ArtBudgetItemType: String {
        case prop = "Prop"
        case setDressing = "Set Dressing"
    }

    init(name: String, itemType: ArtBudgetItemType, cost: Double = 0, quantity: Int = 1,
         source: String = "", isReady: Bool = false, category: ArtBudgetCategory = .purchase,
         imageData: Data? = nil, notes: String = "") {
        self.name = name
        self.itemType = itemType
        self.cost = cost
        self.quantity = quantity
        self.source = source
        self.isReady = isReady
        self.category = category
        self.imageData = imageData
        self.notes = notes
    }
}

private enum ArtBudgetCategory: String, CaseIterable, Identifiable {
    case purchase = "Purchase"
    case rental = "Rental"
    case fabrication = "Fabrication"
    case owned = "Owned"
    case borrowed = "Borrowed"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .purchase: return .blue
        case .rental: return .orange
        case .fabrication: return .purple
        case .owned: return .green
        case .borrowed: return .teal
        }
    }
}

// MARK: - Equipment Budget Category (for Camera, Sound, Lighting)
private enum EquipmentBudgetCategory: String, CaseIterable, Identifiable {
    case purchase = "Purchase"
    case rental = "Rental"
    case fabrication = "Fabrication"
    case owned = "Owned"
    case borrowed = "Borrowed"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .purchase: return .blue
        case .rental: return .orange
        case .fabrication: return .purple
        case .owned: return .green
        case .borrowed: return .teal
        }
    }
}

// MARK: - Equipment Budget Item Model (for Camera, Sound, Lighting)
private struct EquipmentBudgetItem: Identifiable {
    let id = UUID()
    var name: String
    var department: BreakdownDepartment
    var cost: Double
    var quantity: Int
    var source: String
    var isReady: Bool
    var category: EquipmentBudgetCategory
    var imageData: Data?
    var notes: String

    init(name: String, department: BreakdownDepartment, cost: Double = 0, quantity: Int = 1,
         source: String = "", isReady: Bool = false, category: EquipmentBudgetCategory = .rental,
         imageData: Data? = nil, notes: String = "") {
        self.name = name
        self.department = department
        self.cost = cost
        self.quantity = quantity
        self.source = source
        self.isReady = isReady
        self.category = category
        self.imageData = imageData
        self.notes = notes
    }
}

// MARK: - Art Detail View
private struct ArtDetailView: View {
    @ObservedObject var scene: SceneEntity
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var context

    @State private var newPropText: String = ""
    @State private var newArtText: String = ""
    @State private var budgetItems: [ArtBudgetItem] = []

    private var props: [String] {
        scene.breakdown?.getProps() ?? []
    }

    private var artItems: [String] {
        scene.breakdown?.getArt() ?? []
    }

    // Additional Script elements synced from Script breakdown
    private var wardrobe: [String] {
        scene.breakdown?.getWardrobe() ?? []
    }

    private var vehicles: [String] {
        scene.breakdown?.getVehicles() ?? []
    }

    private var hasAdditionalScriptElements: Bool {
        !wardrobe.isEmpty || !vehicles.isEmpty
    }

    private var allBudgetItems: [ArtBudgetItem] {
        var items: [ArtBudgetItem] = []

        for prop in props {
            if let existing = budgetItems.first(where: { $0.name == prop && $0.itemType == .prop }) {
                items.append(existing)
            } else {
                items.append(ArtBudgetItem(name: prop, itemType: .prop))
            }
        }

        for art in artItems {
            if let existing = budgetItems.first(where: { $0.name == art && $0.itemType == .setDressing }) {
                items.append(existing)
            } else {
                items.append(ArtBudgetItem(name: art, itemType: .setDressing))
            }
        }

        return items
    }

    private var propsBudgetItems: [ArtBudgetItem] {
        allBudgetItems.filter { $0.itemType == .prop }
    }

    private var artBudgetItems: [ArtBudgetItem] {
        allBudgetItems.filter { $0.itemType == .setDressing }
    }

    private var propsBudgetTotal: Double {
        propsBudgetItems.reduce(0) { $0 + ($1.cost * Double($1.quantity)) }
    }

    private var artBudgetTotal: Double {
        artBudgetItems.reduce(0) { $0 + ($1.cost * Double($1.quantity)) }
    }

    private var totalBudget: Double {
        allBudgetItems.reduce(0) { $0 + ($1.cost * Double($1.quantity)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sceneHeader

                // Additional Script Elements Section (wardrobe, vehicles)
                if hasAdditionalScriptElements {
                    Divider()
                    additionalScriptElementsSection
                }

                Divider()

                // Props section with integrated gallery and budget
                propsSection

                Divider()

                // Set Dressing section with integrated gallery and budget
                artSection

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(colorScheme == .dark ? Color(white: 0.08) : Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sceneHeader: some View {
        HStack(spacing: 16) {
            Text(scene.number ?? "—")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(sceneHeading(for: scene))
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    Label("\(props.count) Props", systemImage: "cube.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Label("\(artItems.count) Art Items", systemImage: "paintpalette.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    if !wardrobe.isEmpty {
                        Label("\(wardrobe.count) Wardrobe", systemImage: "tshirt.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    if !vehicles.isEmpty {
                        Label("\(vehicles.count) Vehicles", systemImage: "car.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }

    private var additionalScriptElementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Additional Script Elements", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Spacer()

                Text("Synced from Script Breakdown")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            if !wardrobe.isEmpty {
                DepartmentElementsRow(
                    title: "Wardrobe",
                    icon: "tshirt.fill",
                    color: .pink,
                    items: wardrobe
                )
            }

            if !vehicles.isEmpty {
                DepartmentElementsRow(
                    title: "Vehicles",
                    icon: "car.fill",
                    color: .indigo,
                    items: vehicles
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var propsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count and budget total
            HStack {
                Label("Props", systemImage: "cube.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Spacer()

                if propsBudgetTotal > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.mint)
                        Text(propsBudgetTotal, format: .currency(code: "USD"))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
                }

                Text("\(props.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            // Add new prop input
            HStack(spacing: 8) {
                TextField("Add prop...", text: $newPropText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
                    .onSubmit {
                        addProp()
                    }

                Button {
                    addProp()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(newPropText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if props.isEmpty {
                Text("No props added")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                // Category legend
                HStack(spacing: 12) {
                    ForEach(ArtBudgetCategory.allCases) { cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 6, height: 6)
                            Text(cat.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                // Item gallery grid with integrated budget
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                ], spacing: 16) {
                    ForEach(propsBudgetItems) { item in
                        IntegratedArtItemCard(item: item, onUpdate: updateBudgetItem, onRemove: {
                            removeProp(item.name)
                        })
                    }
                }

                // Total summary row
                propsTotalRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
    }

    private var propsTotalRow: some View {
        let readyCount = propsBudgetItems.filter { $0.isReady }.count
        let totalCount = propsBudgetItems.count

        return HStack(spacing: 16) {
            Spacer()

            // Items count
            HStack(spacing: 6) {
                Image(systemName: "cube.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text("\(totalCount) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Ready count
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
                Text("\(readyCount)/\(totalCount) ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
            }

            // Total budget
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.mint)
                Text("Total:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(propsBudgetTotal, format: .currency(code: "USD"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.mint)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private var artSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count and budget total
            HStack {
                Label("Set Dressing", systemImage: "paintpalette.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)

                Spacer()

                if artBudgetTotal > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.mint)
                        Text(artBudgetTotal, format: .currency(code: "USD"))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
                }

                Text("\(artItems.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            // Add new item input
            HStack(spacing: 8) {
                TextField("Add item...", text: $newArtText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
                    .onSubmit {
                        addArtItem()
                    }

                Button {
                    addArtItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .disabled(newArtText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if artItems.isEmpty {
                Text("No items added")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                // Category legend
                HStack(spacing: 12) {
                    ForEach(ArtBudgetCategory.allCases) { cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 6, height: 6)
                            Text(cat.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                // Item gallery grid with integrated budget
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                ], spacing: 16) {
                    ForEach(artBudgetItems) { item in
                        IntegratedArtItemCard(item: item, onUpdate: updateBudgetItem, onRemove: {
                            removeArtItem(item.name)
                        })
                    }
                }

                // Total summary row
                artTotalRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
    }

    private var artTotalRow: some View {
        let readyCount = artBudgetItems.filter { $0.isReady }.count
        let totalCount = artBudgetItems.count

        return HStack(spacing: 16) {
            Spacer()

            // Items count
            HStack(spacing: 6) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)
                Text("\(totalCount) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Ready count
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
                Text("\(readyCount)/\(totalCount) ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
            }

            // Total budget
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.mint)
                Text("Total:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(artBudgetTotal, format: .currency(code: "USD"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.mint)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private func updateBudgetItem(_ item: ArtBudgetItem) {
        if let index = budgetItems.firstIndex(where: { $0.id == item.id }) {
            budgetItems[index] = item
        } else {
            budgetItems.append(item)
        }
    }

    private func addProp() {
        let trimmed = newPropText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let breakdown = BreakdownEntity.getOrCreate(for: scene, in: context)
        var currentProps = breakdown.getProps()
        if !currentProps.contains(trimmed) {
            currentProps.append(trimmed)
            breakdown.setProps(currentProps)
            try? context.save()
            notifyBreakdownChanged()
        }
        newPropText = ""
    }

    private func removeProp(_ prop: String) {
        guard let breakdown = scene.breakdown else { return }
        var currentProps = breakdown.getProps()
        currentProps.removeAll { $0 == prop }
        breakdown.setProps(currentProps)
        try? context.save()
        notifyBreakdownChanged()
    }

    private func addArtItem() {
        let trimmed = newArtText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let breakdown = BreakdownEntity.getOrCreate(for: scene, in: context)
        var currentArt = breakdown.getArt()
        if !currentArt.contains(trimmed) {
            currentArt.append(trimmed)
            breakdown.setArt(currentArt)
            try? context.save()
            notifyBreakdownChanged()
        }
        newArtText = ""
    }

    private func removeArtItem(_ item: String) {
        guard let breakdown = scene.breakdown else { return }
        var currentArt = breakdown.getArt()
        currentArt.removeAll { $0 == item }
        breakdown.setArt(currentArt)
        try? context.save()
        notifyBreakdownChanged()
    }

    private func notifyBreakdownChanged() {
        NotificationCenter.default.post(name: .breakdownsSceneSynced, object: scene.objectID)
    }
}

// MARK: - Compact Budget Row
private struct CompactBudgetRow: View {
    let item: ArtBudgetItem
    let onUpdate: (ArtBudgetItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var cost: String = ""
    @State private var quantity: Int = 1
    @State private var isReady: Bool = false
    @State private var category: ArtBudgetCategory = .purchase
    @State private var isHovering: Bool = false

    private var itemColor: Color {
        item.itemType == .prop ? .orange : .purple
    }

    var body: some View {
        HStack(spacing: 0) {
            // Category indicator bar
            Rectangle()
                .fill(category.color)
                .frame(width: 3)

            HStack(spacing: 12) {
                // Item type dot + name
                HStack(spacing: 8) {
                    Circle()
                        .fill(itemColor)
                        .frame(width: 6, height: 6)

                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 100, maxWidth: .infinity)

                // Category picker - compact
                Menu {
                    ForEach(ArtBudgetCategory.allCases) { cat in
                        Button {
                            category = cat
                            var updated = item
                            updated.category = cat
                            onUpdate(updated)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(cat.color)
                                    .frame(width: 8, height: 8)
                                Text(cat.rawValue)
                                if category == cat {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(category.rawValue.prefix(3).uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(category.color)
                        .frame(width: 32)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Quantity stepper - minimal
                HStack(spacing: 4) {
                    Button {
                        if quantity > 1 {
                            quantity -= 1
                            var updated = item
                            updated.quantity = quantity
                            onUpdate(updated)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .opacity(quantity > 1 ? 1 : 0.3)

                    Text("\(quantity)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 20)
                        .foregroundStyle(.primary)

                    Button {
                        quantity += 1
                        var updated = item
                        updated.quantity = quantity
                        onUpdate(updated)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                // Cost field - compact
                HStack(spacing: 2) {
                    Text("$")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("0", text: $cost)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: cost) { newValue in
                            let cleaned = newValue.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                            if let value = Double(cleaned) {
                                var updated = item
                                updated.cost = value
                                onUpdate(updated)
                            }
                        }
                }

                // Line total
                if item.cost > 0 {
                    Text(item.cost * Double(item.quantity), format: .currency(code: "USD"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                } else {
                    Text("—")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(width: 60, alignment: .trailing)
                }

                // Ready checkbox
                Button {
                    isReady.toggle()
                    var updated = item
                    updated.isReady = isReady
                    onUpdate(updated)
                } label: {
                    Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isReady ? .green : Color.gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(
            colorScheme == .dark
                ? Color(white: isHovering ? 0.16 : 0.13)
                : Color(white: isHovering ? 0.98 : 1.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .onAppear {
            cost = item.cost > 0 ? String(format: "%.2f", item.cost) : ""
            quantity = item.quantity
            isReady = item.isReady
            category = item.category
        }
    }
}

// MARK: - Budget Item Card (Legacy - kept for gallery use)
private struct BudgetItemCard: View {
    let item: ArtBudgetItem
    let onUpdate: (ArtBudgetItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var cost: String = ""
    @State private var quantity: String = ""
    @State private var source: String = ""
    @State private var isReady: Bool = false
    @State private var category: ArtBudgetCategory = .purchase

    private var itemColor: Color {
        item.itemType == .prop ? .orange : .purple
    }

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(itemColor)
                    .frame(width: 8, height: 8)

                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .frame(minWidth: 120, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Cost")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                HStack(spacing: 2) {
                    Text("$")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $cost)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .frame(width: 56)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: cost) { newValue in
                            if let value = Double(newValue.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                                var updated = item
                                updated.cost = value
                                onUpdate(updated)
                            }
                        }
                }
            }

            VStack(alignment: .center, spacing: 2) {
                Text("Qty")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                TextField("1", text: $quantity)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
                    .onChange(of: quantity) { newValue in
                        if let value = Int(newValue) {
                            var updated = item
                            updated.quantity = value
                            onUpdate(updated)
                        }
                    }
            }

            Menu {
                ForEach(ArtBudgetCategory.allCases) { cat in
                    Button {
                        category = cat
                        var updated = item
                        updated.category = cat
                        onUpdate(updated)
                    } label: {
                        HStack {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 8, height: 8)
                            Text(cat.rawValue)
                            if category == cat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Circle()
                    .fill(category.color)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .strokeBorder(category.color.opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    )
            }
            .help(category.rawValue)

            Button {
                isReady.toggle()
                var updated = item
                updated.isReady = isReady
                onUpdate(updated)
            } label: {
                Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isReady ? .green : Color.gray.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(white: 0.14) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isReady ? Color.green.opacity(0.5) : (colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.88)),
                    lineWidth: isReady ? 1.5 : 1
                )
        )
        .onAppear {
            cost = item.cost > 0 ? String(format: "%.2f", item.cost) : ""
            quantity = "\(item.quantity)"
            source = item.source
            isReady = item.isReady
            category = item.category
        }
    }
}

// MARK: - Art Item Card
private struct ArtItemCard: View {
    let item: ArtBudgetItem
    let onUpdate: (ArtBudgetItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var notes: String = ""

    private let cardWidth: CGFloat = 220
    private let imageHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea
            infoArea
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.14) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    item.isReady ? Color.green.opacity(0.5) : (colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.85)),
                    lineWidth: item.isReady ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onAppear {
            notes = item.notes
        }
        #if os(macOS)
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result)
        }
        #endif
    }

    private var imageArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                .frame(height: imageHeight)

            if let imageData = item.imageData {
                #if os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                }
                #else
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                }
                #endif

                if isHovering {
                    VStack {
                        HStack {
                            Spacer()

                            Button {
                                showImagePicker = true
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                var updated = item
                                updated.imageData = nil
                                onUpdate(updated)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.red.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)

                        Spacer()
                    }
                    .transition(.opacity)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(item.itemType == .prop ? Color.orange.opacity(0.5) : Color.purple.opacity(0.5))

                    Text("Add Reference Image")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Button {
                        showImagePicker = true
                    } label: {
                        Text("Browse")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(item.itemType == .prop ? .orange : .purple)
                }
                .frame(height: imageHeight)
            }

            VStack {
                HStack {
                    Text(item.itemType.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(item.itemType == .prop ? Color.orange : Color.purple)
                        )
                    Spacer()

                    if item.isReady {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                            )
                    }
                }
                .padding(10)

                Spacer()
            }
        }
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack {
                Text(item.category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(item.category.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.category.color.opacity(0.15))
                    )

                Spacer()

                if item.cost > 0 {
                    Text(item.cost * Double(item.quantity), format: .currency(code: "USD"))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if !item.source.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(item.source)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TextField("Add notes...", text: $notes, axis: .vertical)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2...3)
                .textFieldStyle(.plain)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                )
                .onChange(of: notes) { newValue in
                    var updated = item
                    updated.notes = newValue
                    onUpdate(updated)
                }

            if item.quantity > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Qty: \(item.quantity)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }

    private func handleImageImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            if let data = try? Data(contentsOf: url) {
                var updated = item
                updated.imageData = data
                onUpdate(updated)
            }
        case .failure(let error):
            print("Image import error: \(error)")
        }
    }
}

// MARK: - Integrated Art Item Card (Gallery + Budget + Remove)
private struct IntegratedArtItemCard: View {
    let item: ArtBudgetItem
    let onUpdate: (ArtBudgetItem) -> Void
    let onRemove: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var notes: String = ""
    @State private var cost: String = ""
    @State private var quantity: String = "1"
    @State private var category: ArtBudgetCategory = .purchase
    @State private var isReady: Bool = false

    private let cardWidth: CGFloat = 220
    private let imageHeight: CGFloat = 140

    private var itemColor: Color {
        item.itemType == .prop ? .orange : .purple
    }

    private var itemTotal: Double {
        let costValue = Double(cost.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
        let qtyValue = Double(Int(quantity) ?? 1)
        return costValue * qtyValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea
            infoArea
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.14) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isReady ? Color.green.opacity(0.5) : (colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.85)),
                    lineWidth: isReady ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onAppear {
            notes = item.notes
            cost = item.cost > 0 ? String(format: "%.0f", item.cost) : ""
            quantity = String(item.quantity)
            category = item.category
            isReady = item.isReady
        }
        #if os(macOS)
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result)
        }
        #endif
    }

    private var imageArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                .frame(height: imageHeight)

            if let imageData = item.imageData {
                #if os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                }
                #else
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                }
                #endif

                if isHovering {
                    VStack {
                        HStack {
                            Spacer()

                            Button {
                                showImagePicker = true
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                var updated = item
                                updated.imageData = nil
                                onUpdate(updated)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.red.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)

                        Spacer()
                    }
                    .transition(.opacity)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(itemColor.opacity(0.5))

                    Button {
                        showImagePicker = true
                    } label: {
                        Text("Add Image")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(itemColor)
                }
                .frame(height: imageHeight)
            }

            // Ready badge overlay
            if isReady {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                            )
                    }
                    .padding(8)
                    Spacer()
                }
            }
        }
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item name with remove button
            HStack {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(itemColor.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Remove item")
            }

            // Category and cost row
            HStack(spacing: 8) {
                // Category picker
                Menu {
                    ForEach(ArtBudgetCategory.allCases) { cat in
                        Button {
                            category = cat
                            var updated = item
                            updated.category = cat
                            onUpdate(updated)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(cat.color)
                                    .frame(width: 8, height: 8)
                                Text(cat.rawValue)
                                if category == cat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 6, height: 6)
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(category.color)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(category.color.opacity(0.15))
                    )
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Cost input
                HStack(spacing: 2) {
                    Text("$")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $cost)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: cost) { newValue in
                            if let value = Double(newValue.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                                var updated = item
                                updated.cost = value
                                onUpdate(updated)
                            }
                        }
                }

                // Quantity
                HStack(spacing: 2) {
                    Text("×")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("1", text: $quantity)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20)
                        .multilineTextAlignment(.center)
                        .onChange(of: quantity) { newValue in
                            if let value = Int(newValue), value > 0 {
                                var updated = item
                                updated.quantity = value
                                onUpdate(updated)
                            }
                        }
                }
            }

            // Item total (cost × quantity)
            if itemTotal > 0 {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Total:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(itemTotal, format: .currency(code: "USD"))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.mint.opacity(0.15) : Color.mint.opacity(0.1))
                    )
                }
            }

            // Notes field
            TextField("Notes...", text: $notes, axis: .vertical)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textFieldStyle(.plain)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                )
                .onChange(of: notes) { newValue in
                    var updated = item
                    updated.notes = newValue
                    onUpdate(updated)
                }

            // Ready toggle
            HStack {
                Spacer()

                Button {
                    isReady.toggle()
                    var updated = item
                    updated.isReady = isReady
                    onUpdate(updated)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(isReady ? .green : .secondary)
                        Text("Ready")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isReady ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }

    private func handleImageImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            if let data = try? Data(contentsOf: url) {
                var updated = item
                updated.imageData = data
                onUpdate(updated)
            }
        case .failure(let error):
            print("Image import error: \(error)")
        }
    }
}

// MARK: - Art Item Tag
private struct ArtItemTag: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .medium))

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(color.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(colorScheme == .dark ? 0.2 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Flow Layout
private struct BreakdownFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

// MARK: - Integrated Equipment Item Card (for Camera, Sound, Lighting)
private struct IntegratedEquipmentItemCard: View {
    let item: EquipmentBudgetItem
    let accentColor: Color
    let onUpdate: (EquipmentBudgetItem) -> Void
    let onRemove: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var notes: String = ""
    @State private var cost: String = ""
    @State private var quantity: String = "1"
    @State private var category: EquipmentBudgetCategory = .rental
    @State private var isReady: Bool = false

    private let cardWidth: CGFloat = 220
    private let imageHeight: CGFloat = 140

    private var itemTotal: Double {
        let costValue = Double(cost.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
        let qtyValue = Double(Int(quantity) ?? 1)
        return costValue * qtyValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea
            infoArea
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.14) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isReady ? Color.green.opacity(0.5) : (colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.85)),
                    lineWidth: isReady ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onAppear {
            notes = item.notes
            cost = item.cost > 0 ? String(format: "%.0f", item.cost) : ""
            quantity = String(item.quantity)
            category = item.category
            isReady = item.isReady
        }
        #if os(macOS)
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result)
        }
        #endif
    }

    private var imageArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                .frame(height: imageHeight)

            if let imageData = item.imageData {
                #if os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                }
                #else
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: imageHeight)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                }
                #endif

                if isHovering {
                    VStack {
                        HStack {
                            Spacer()

                            Button {
                                showImagePicker = true
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                var updated = item
                                updated.imageData = nil
                                onUpdate(updated)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.red.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)

                        Spacer()
                    }
                    .transition(.opacity)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(accentColor.opacity(0.5))

                    Button {
                        showImagePicker = true
                    } label: {
                        Text("Add Image")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)
                }
                .frame(height: imageHeight)
            }

            // Ready badge overlay
            if isReady {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                            )
                    }
                    .padding(8)
                    Spacer()
                }
            }
        }
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item name with remove button
            HStack {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Remove item")
            }

            // Category and cost row
            HStack(spacing: 8) {
                // Category picker
                Menu {
                    ForEach(EquipmentBudgetCategory.allCases) { cat in
                        Button {
                            category = cat
                            var updated = item
                            updated.category = cat
                            onUpdate(updated)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(cat.color)
                                    .frame(width: 8, height: 8)
                                Text(cat.rawValue)
                                if category == cat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 6, height: 6)
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(category.color)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(category.color.opacity(0.15))
                    )
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Cost input
                HStack(spacing: 2) {
                    Text("$")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $cost)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: cost) { newValue in
                            if let value = Double(newValue.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                                var updated = item
                                updated.cost = value
                                onUpdate(updated)
                            }
                        }
                }

                // Quantity
                HStack(spacing: 2) {
                    Text("×")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("1", text: $quantity)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20)
                        .multilineTextAlignment(.center)
                        .onChange(of: quantity) { newValue in
                            if let value = Int(newValue), value > 0 {
                                var updated = item
                                updated.quantity = value
                                onUpdate(updated)
                            }
                        }
                }
            }

            // Item total (cost × quantity)
            if itemTotal > 0 {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Total:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(itemTotal, format: .currency(code: "USD"))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.mint.opacity(0.15) : Color.mint.opacity(0.1))
                    )
                }
            }

            // Notes field
            TextField("Notes...", text: $notes, axis: .vertical)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textFieldStyle(.plain)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                )
                .onChange(of: notes) { newValue in
                    var updated = item
                    updated.notes = newValue
                    onUpdate(updated)
                }

            // Ready toggle
            HStack {
                Spacer()

                Button {
                    isReady.toggle()
                    var updated = item
                    updated.isReady = isReady
                    onUpdate(updated)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(isReady ? .green : .secondary)
                        Text("Ready")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isReady ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }

    private func handleImageImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            if let data = try? Data(contentsOf: url) {
                var updated = item
                updated.imageData = data
                onUpdate(updated)
            }
        case .failure(let error):
            print("Image import error: \(error)")
        }
    }
}

// MARK: - Camera Breakdown View
struct CameraBreakdownView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    let scenes: [SceneEntity]
    @Binding var selectedSceneID: NSManagedObjectID?

    @State private var searchText: String = ""

    private var selectedScene: SceneEntity? {
        guard let id = selectedSceneID else { return nil }
        return scenes.first { $0.objectID == id }
    }

    private var filteredScenes: [SceneEntity] {
        if searchText.isEmpty {
            return scenes
        }
        return scenes.filter { scene in
            let number = scene.number ?? ""
            let heading = sceneHeading(for: scene)
            return number.localizedCaseInsensitiveContains(searchText) ||
                   heading.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            cameraSidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)

            cameraDetailPane
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        NavigationSplitView {
            cameraSidebarContent
        } detail: {
            cameraDetailPane
        }
        #endif
    }

    #if os(macOS)
    private var cameraSidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scenes")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(scenes.count) scenes")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                colorScheme == .dark
                    ? Color(white: 0.12)
                    : Color(white: 0.98)
            )

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.94))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            cameraSidebarContent
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.96))
    }
    #endif

    private var cameraSidebarContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredScenes, id: \.objectID) { scene in
                    DepartmentSceneRow(
                        scene: scene,
                        isSelected: selectedSceneID == scene.objectID,
                        accentColor: .cyan
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSceneID = scene.objectID
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var cameraDetailPane: some View {
        Group {
            if let scene = selectedScene {
                CameraDetailView(scene: scene)
            } else {
                cameraEmptyStateView
            }
        }
    }

    private var cameraEmptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.cyan.opacity(0.7))

            Text("Camera Department")
                .font(.title.bold())

            Text("Select a scene to document camera setups, lens choices, angles, and framing for scene matching")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Camera Detail View
private struct CameraDetailView: View {
    @ObservedObject var scene: SceneEntity
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var context

    @State private var lensNotes: String = ""
    @State private var frameNotes: String = ""
    @State private var movementNotes: String = ""
    @State private var setupNotes: String = ""

    // Equipment budgeting
    @State private var equipmentItems: [EquipmentBudgetItem] = []
    @State private var newEquipmentText: String = ""

    // Script elements synced from Script breakdown
    private var visualEffects: [String] {
        scene.breakdown?.getVisualEffects() ?? []
    }

    private var hasScriptElements: Bool {
        !visualEffects.isEmpty
    }

    private var equipmentBudgetTotal: Double {
        equipmentItems.reduce(0) { $0 + ($1.cost * Double($1.quantity)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sceneHeader

                // Script Elements Section (synced from Script breakdown)
                if hasScriptElements {
                    Divider()
                    scriptElementsSection
                }

                Divider()

                // Equipment Budget Section
                equipmentSection

                Divider()
                lensSection
                Divider()
                framingSection
                Divider()
                movementSection
                Divider()
                setupSection
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(colorScheme == .dark ? Color(white: 0.08) : Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sceneHeader: some View {
        HStack(spacing: 16) {
            Text(scene.number ?? "—")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cyan)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(sceneHeading(for: scene))
                    .font(.title2.bold())

                HStack(spacing: 8) {
                    Text("Camera Department Breakdown")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    if hasScriptElements {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(visualEffects.count) VFX")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.purple)
                    }

                    if !equipmentItems.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(equipmentItems.count) Equipment")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.cyan)
                    }
                }
            }

            Spacer()
        }
    }

    private var scriptElementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Script Elements", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Spacer()

                Text("Synced from Script Breakdown")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            if !visualEffects.isEmpty {
                DepartmentElementsRow(
                    title: "Visual Effects",
                    icon: "sparkles",
                    color: .purple,
                    items: visualEffects
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count and budget total
            HStack {
                Label("Camera Equipment", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(.cyan)

                Spacer()

                if equipmentBudgetTotal > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.mint)
                        Text(equipmentBudgetTotal, format: .currency(code: "USD"))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
                }

                Text("\(equipmentItems.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            // Add new equipment input
            HStack(spacing: 8) {
                TextField("Add camera, lens, tripod, dolly...", text: $newEquipmentText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
                    .onSubmit {
                        addEquipment()
                    }

                Button {
                    addEquipment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .disabled(newEquipmentText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if equipmentItems.isEmpty {
                Text("No equipment added")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                // Category legend
                HStack(spacing: 12) {
                    ForEach(EquipmentBudgetCategory.allCases) { cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 6, height: 6)
                            Text(cat.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                // Equipment grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                ], spacing: 16) {
                    ForEach(equipmentItems) { item in
                        IntegratedEquipmentItemCard(
                            item: item,
                            accentColor: .cyan,
                            onUpdate: updateEquipmentItem,
                            onRemove: { removeEquipment(item) }
                        )
                    }
                }

                // Total summary row
                equipmentTotalRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
    }

    private var equipmentTotalRow: some View {
        let readyCount = equipmentItems.filter { $0.isReady }.count
        let totalCount = equipmentItems.count

        return HStack(spacing: 16) {
            Spacer()

            // Items count
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text("\(totalCount) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Ready count
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
                Text("\(readyCount)/\(totalCount) ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
            }

            // Total budget
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.mint)
                Text("Total:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(equipmentBudgetTotal, format: .currency(code: "USD"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.mint)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private func addEquipment() {
        let trimmed = newEquipmentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let newItem = EquipmentBudgetItem(name: trimmed, department: .camera)
        equipmentItems.append(newItem)
        newEquipmentText = ""
    }

    private func removeEquipment(_ item: EquipmentBudgetItem) {
        equipmentItems.removeAll { $0.id == item.id }
    }

    private func updateEquipmentItem(_ item: EquipmentBudgetItem) {
        if let index = equipmentItems.firstIndex(where: { $0.id == item.id }) {
            equipmentItems[index] = item
        }
    }

    private var lensSection: some View {
        DepartmentNotesSection(
            title: "Lenses",
            icon: "circle.dashed",
            color: .cyan,
            placeholder: "Document lens choices, focal lengths, filters...",
            text: $lensNotes
        )
    }

    private var framingSection: some View {
        DepartmentNotesSection(
            title: "Framing & Composition",
            icon: "viewfinder",
            color: .blue,
            placeholder: "Note shot sizes, angles, composition details...",
            text: $frameNotes
        )
    }

    private var movementSection: some View {
        DepartmentNotesSection(
            title: "Camera Movement",
            icon: "arrow.up.and.down.and.arrow.left.and.right",
            color: .indigo,
            placeholder: "Document dolly, crane, steadicam, handheld notes...",
            text: $movementNotes
        )
    }

    private var setupSection: some View {
        DepartmentNotesSection(
            title: "Setup Notes",
            icon: "camera.on.rectangle",
            color: .purple,
            placeholder: "General camera setup notes, equipment requirements...",
            text: $setupNotes
        )
    }
}

// MARK: - Sound Breakdown View
struct SoundBreakdownView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    let scenes: [SceneEntity]
    @Binding var selectedSceneID: NSManagedObjectID?

    @State private var searchText: String = ""

    private var selectedScene: SceneEntity? {
        guard let id = selectedSceneID else { return nil }
        return scenes.first { $0.objectID == id }
    }

    private var filteredScenes: [SceneEntity] {
        if searchText.isEmpty {
            return scenes
        }
        return scenes.filter { scene in
            let number = scene.number ?? ""
            let heading = sceneHeading(for: scene)
            return number.localizedCaseInsensitiveContains(searchText) ||
                   heading.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            soundSidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)

            soundDetailPane
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        NavigationSplitView {
            soundSidebarContent
        } detail: {
            soundDetailPane
        }
        #endif
    }

    #if os(macOS)
    private var soundSidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scenes")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(scenes.count) scenes")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                colorScheme == .dark
                    ? Color(white: 0.12)
                    : Color(white: 0.98)
            )

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.94))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            soundSidebarContent
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.96))
    }
    #endif

    private var soundSidebarContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredScenes, id: \.objectID) { scene in
                    DepartmentSceneRow(
                        scene: scene,
                        isSelected: selectedSceneID == scene.objectID,
                        accentColor: .green
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSceneID = scene.objectID
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var soundDetailPane: some View {
        Group {
            if let scene = selectedScene {
                SoundDetailView(scene: scene)
            } else {
                soundEmptyStateView
            }
        }
    }

    private var soundEmptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundStyle(.green.opacity(0.7))

            Text("Sound Department")
                .font(.title.bold())

            Text("Select a scene to record audio notes, mic placements, ambient sound, and dialogue requirements")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sound Detail View
private struct SoundDetailView: View {
    @ObservedObject var scene: SceneEntity
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var context

    @State private var dialogueNotes: String = ""
    @State private var ambientNotes: String = ""
    @State private var micNotes: String = ""
    @State private var sfxNotes: String = ""

    // Equipment budgeting
    @State private var equipmentItems: [EquipmentBudgetItem] = []
    @State private var newEquipmentText: String = ""

    // Script elements synced from Script breakdown
    private var soundFX: [String] {
        scene.breakdown?.getSoundFX() ?? []
    }

    private var hasScriptElements: Bool {
        !soundFX.isEmpty
    }

    private var equipmentBudgetTotal: Double {
        equipmentItems.reduce(0) { $0 + ($1.cost * Double($1.quantity)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sceneHeader

                // Script Elements Section (synced from Script breakdown)
                if hasScriptElements {
                    Divider()
                    scriptElementsSection
                }

                Divider()

                // Equipment Budget Section
                equipmentSection

                Divider()
                dialogueSection
                Divider()
                ambientSection
                Divider()
                micSection
                Divider()
                sfxSection
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(colorScheme == .dark ? Color(white: 0.08) : Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sceneHeader: some View {
        HStack(spacing: 16) {
            Text(scene.number ?? "—")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(sceneHeading(for: scene))
                    .font(.title2.bold())

                HStack(spacing: 8) {
                    Text("Sound Department Breakdown")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    if hasScriptElements {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(soundFX.count) SFX")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.cyan)
                    }

                    if !equipmentItems.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(equipmentItems.count) Equipment")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()
        }
    }

    private var scriptElementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Script Elements", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Spacer()

                Text("Synced from Script Breakdown")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            if !soundFX.isEmpty {
                DepartmentElementsRow(
                    title: "Sound Effects",
                    icon: "speaker.wave.3.fill",
                    color: .cyan,
                    items: soundFX
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count and budget total
            HStack {
                Label("Sound Equipment", systemImage: "waveform")
                    .font(.headline)
                    .foregroundStyle(.green)

                Spacer()

                if equipmentBudgetTotal > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.mint)
                        Text(equipmentBudgetTotal, format: .currency(code: "USD"))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
                }

                Text("\(equipmentItems.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            // Add new equipment input
            HStack(spacing: 8) {
                TextField("Add microphone, boom, mixer, recorder...", text: $newEquipmentText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
                    .onSubmit {
                        addEquipment()
                    }

                Button {
                    addEquipment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(newEquipmentText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if equipmentItems.isEmpty {
                Text("No equipment added")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                // Category legend
                HStack(spacing: 12) {
                    ForEach(EquipmentBudgetCategory.allCases) { cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 6, height: 6)
                            Text(cat.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                // Equipment grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                ], spacing: 16) {
                    ForEach(equipmentItems) { item in
                        IntegratedEquipmentItemCard(
                            item: item,
                            accentColor: .green,
                            onUpdate: updateEquipmentItem,
                            onRemove: { removeEquipment(item) }
                        )
                    }
                }

                // Total summary row
                equipmentTotalRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
    }

    private var equipmentTotalRow: some View {
        let readyCount = equipmentItems.filter { $0.isReady }.count
        let totalCount = equipmentItems.count

        return HStack(spacing: 16) {
            Spacer()

            // Items count
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text("\(totalCount) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Ready count
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
                Text("\(readyCount)/\(totalCount) ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
            }

            // Total budget
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.mint)
                Text("Total:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(equipmentBudgetTotal, format: .currency(code: "USD"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.mint)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private func addEquipment() {
        let trimmed = newEquipmentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let newItem = EquipmentBudgetItem(name: trimmed, department: .sound)
        equipmentItems.append(newItem)
        newEquipmentText = ""
    }

    private func removeEquipment(_ item: EquipmentBudgetItem) {
        equipmentItems.removeAll { $0.id == item.id }
    }

    private func updateEquipmentItem(_ item: EquipmentBudgetItem) {
        if let index = equipmentItems.firstIndex(where: { $0.id == item.id }) {
            equipmentItems[index] = item
        }
    }

    private var dialogueSection: some View {
        DepartmentNotesSection(
            title: "Dialogue",
            icon: "text.bubble.fill",
            color: .green,
            placeholder: "Document dialogue requirements, ADR notes...",
            text: $dialogueNotes
        )
    }

    private var ambientSection: some View {
        DepartmentNotesSection(
            title: "Ambient Sound",
            icon: "waveform.circle.fill",
            color: .teal,
            placeholder: "Note ambient sound, room tone, background audio...",
            text: $ambientNotes
        )
    }

    private var micSection: some View {
        DepartmentNotesSection(
            title: "Mic Placement",
            icon: "mic.fill",
            color: .mint,
            placeholder: "Document boom positions, lavs, wireless setup...",
            text: $micNotes
        )
    }

    private var sfxSection: some View {
        DepartmentNotesSection(
            title: "Sound Effects",
            icon: "speaker.wave.3.fill",
            color: .cyan,
            placeholder: "List sound effects needed, foley notes...",
            text: $sfxNotes
        )
    }
}

// MARK: - Lighting Breakdown View
struct LightingBreakdownView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    let scenes: [SceneEntity]
    @Binding var selectedSceneID: NSManagedObjectID?

    @State private var searchText: String = ""

    private var selectedScene: SceneEntity? {
        guard let id = selectedSceneID else { return nil }
        return scenes.first { $0.objectID == id }
    }

    private var filteredScenes: [SceneEntity] {
        if searchText.isEmpty {
            return scenes
        }
        return scenes.filter { scene in
            let number = scene.number ?? ""
            let heading = sceneHeading(for: scene)
            return number.localizedCaseInsensitiveContains(searchText) ||
                   heading.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            lightingSidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)

            lightingDetailPane
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        NavigationSplitView {
            lightingSidebarContent
        } detail: {
            lightingDetailPane
        }
        #endif
    }

    #if os(macOS)
    private var lightingSidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scenes")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(scenes.count) scenes")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                colorScheme == .dark
                    ? Color(white: 0.12)
                    : Color(white: 0.98)
            )

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.94))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            lightingSidebarContent
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.96))
    }
    #endif

    private var lightingSidebarContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredScenes, id: \.objectID) { scene in
                    DepartmentSceneRow(
                        scene: scene,
                        isSelected: selectedSceneID == scene.objectID,
                        accentColor: .yellow
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSceneID = scene.objectID
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var lightingDetailPane: some View {
        Group {
            if let scene = selectedScene {
                LightingDetailView(scene: scene)
            } else {
                lightingEmptyStateView
            }
        }
    }

    private var lightingEmptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow.opacity(0.8))

            Text("Lighting Department")
                .font(.title.bold())

            Text("Select a scene to track lighting setups, fixture positions, gel colors, and electrical notes")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lighting Detail View
private struct LightingDetailView: View {
    @ObservedObject var scene: SceneEntity
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var context

    @State private var keyLightNotes: String = ""
    @State private var fillLightNotes: String = ""
    @State private var practicalNotes: String = ""
    @State private var electricalNotes: String = ""

    // Equipment budgeting
    @State private var equipmentItems: [EquipmentBudgetItem] = []
    @State private var newEquipmentText: String = ""

    // Script elements synced from Script breakdown
    private var specialEffects: [String] {
        scene.breakdown?.getSPFX() ?? []
    }

    private var hasScriptElements: Bool {
        !specialEffects.isEmpty
    }

    private var equipmentBudgetTotal: Double {
        equipmentItems.reduce(0) { $0 + ($1.cost * Double($1.quantity)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sceneHeader

                // Script Elements Section (synced from Script breakdown)
                if hasScriptElements {
                    Divider()
                    scriptElementsSection
                }

                Divider()

                // Equipment Budget Section
                equipmentSection

                Divider()
                keyLightSection
                Divider()
                fillLightSection
                Divider()
                practicalSection
                Divider()
                electricalSection
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(colorScheme == .dark ? Color(white: 0.08) : Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sceneHeader: some View {
        HStack(spacing: 16) {
            Text(scene.number ?? "—")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(sceneHeading(for: scene))
                    .font(.title2.bold())

                HStack(spacing: 8) {
                    Text("Lighting Department Breakdown")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    if hasScriptElements {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(specialEffects.count) SPFX")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    if !equipmentItems.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(equipmentItems.count) Equipment")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer()
        }
    }

    private var scriptElementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Script Elements", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Spacer()

                Text("Synced from Script Breakdown")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            if !specialEffects.isEmpty {
                DepartmentElementsRow(
                    title: "Special Effects",
                    icon: "flame.fill",
                    color: .red,
                    items: specialEffects
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count and budget total
            HStack {
                Label("Lighting Equipment", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)

                Spacer()

                if equipmentBudgetTotal > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.mint)
                        Text(equipmentBudgetTotal, format: .currency(code: "USD"))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
                }

                Text("\(equipmentItems.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.92))
                    )
            }

            // Add new equipment input
            HStack(spacing: 8) {
                TextField("Add light fixture, gel, stand, cable...", text: $newEquipmentText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
                    .onSubmit {
                        addEquipment()
                    }

                Button {
                    addEquipment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
                .disabled(newEquipmentText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if equipmentItems.isEmpty {
                Text("No equipment added")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                // Category legend
                HStack(spacing: 12) {
                    ForEach(EquipmentBudgetCategory.allCases) { cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 6, height: 6)
                            Text(cat.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                // Equipment grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                ], spacing: 16) {
                    ForEach(equipmentItems) { item in
                        IntegratedEquipmentItemCard(
                            item: item,
                            accentColor: .yellow,
                            onUpdate: updateEquipmentItem,
                            onRemove: { removeEquipment(item) }
                        )
                    }
                }

                // Total summary row
                equipmentTotalRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
    }

    private var equipmentTotalRow: some View {
        let readyCount = equipmentItems.filter { $0.isReady }.count
        let totalCount = equipmentItems.count

        return HStack(spacing: 16) {
            Spacer()

            // Items count
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
                Text("\(totalCount) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Ready count
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
                Text("\(readyCount)/\(totalCount) ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(readyCount == totalCount && totalCount > 0 ? .green : .secondary)
            }

            // Total budget
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.mint)
                Text("Total:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(equipmentBudgetTotal, format: .currency(code: "USD"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.mint)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private func addEquipment() {
        let trimmed = newEquipmentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let newItem = EquipmentBudgetItem(name: trimmed, department: .lighting)
        equipmentItems.append(newItem)
        newEquipmentText = ""
    }

    private func removeEquipment(_ item: EquipmentBudgetItem) {
        equipmentItems.removeAll { $0.id == item.id }
    }

    private func updateEquipmentItem(_ item: EquipmentBudgetItem) {
        if let index = equipmentItems.firstIndex(where: { $0.id == item.id }) {
            equipmentItems[index] = item
        }
    }

    private var keyLightSection: some View {
        DepartmentNotesSection(
            title: "Key Light",
            icon: "sun.max.fill",
            color: .yellow,
            placeholder: "Document key light setup, fixtures, intensity...",
            text: $keyLightNotes
        )
    }

    private var fillLightSection: some View {
        DepartmentNotesSection(
            title: "Fill & Accent Lights",
            icon: "lightbulb.fill",
            color: .orange,
            placeholder: "Note fill lights, accent lighting, bounce setup...",
            text: $fillLightNotes
        )
    }

    private var practicalSection: some View {
        DepartmentNotesSection(
            title: "Practicals",
            icon: "lamp.desk.fill",
            color: .brown,
            placeholder: "Document practical lights in scene, dimmers...",
            text: $practicalNotes
        )
    }

    private var electricalSection: some View {
        DepartmentNotesSection(
            title: "Electrical & Rigging",
            icon: "bolt.fill",
            color: .red,
            placeholder: "Power requirements, cable runs, rigging notes...",
            text: $electricalNotes
        )
    }
}

// MARK: - Shared Department Components

private struct DepartmentSceneRow: View {
    @ObservedObject var scene: SceneEntity
    let isSelected: Bool
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text(scene.number ?? "—")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 40, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(sceneHeading(for: scene))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(scene.locationType ?? "INT.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected
                    ? accentColor.opacity(0.15)
                    : (colorScheme == .dark ? Color(white: 0.14) : Color(white: 0.98)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

private struct DepartmentNotesSection: View {
    let title: String
    let icon: String
    let color: Color
    let placeholder: String
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)

                Spacer()
            }

            TextEditor(text: $text)
                .font(.system(size: 14))
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                )
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.97))
        )
    }
}

// MARK: - Department Elements Row (for synced Script elements)
private struct DepartmentElementsRow: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("(\(items.count))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            BreakdownFlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(color.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(color.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
    }
}
