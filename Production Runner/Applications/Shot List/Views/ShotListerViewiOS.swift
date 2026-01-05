import SwiftUI
import CoreData

// iOS Shots View - Re-enabled
#if os(iOS)
import UIKit

// Shim: Provide Color.tertiary as a Color (not ShapeStyle) for compatibility
extension Color {
    static var tertiary: Color {
        #if canImport(UIKit)
        return Color(UIColor.tertiaryLabel)
        #elseif canImport(AppKit)
        return Color(NSColor.tertiaryLabelColor)
        #else
        return .secondary
        #endif
    }
}

/// Shots — Sleek scene-based stripboard with modern UI design for iOS
struct ShotsView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.horizontalSizeClass) var sizeClass
    let projectID: NSManagedObjectID

    @State private var scenes: [NSManagedObject] = []
    @State private var selectedScene: NSManagedObject? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sceneSidebar
                .navigationTitle("Shots")
                .navigationBarTitleDisplayMode(.large)
        } detail: {
            shotDetailPane
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    @ViewBuilder
    private var sceneSidebar: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(scenes, id: \.objectID) { scene in
                    ModernSceneCardIOS(
                        scene: scene,
                        isSelected: selectedScene?.objectID == scene.objectID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedScene = scene
                            if sizeClass == .compact {
                                columnVisibility = .detailOnly
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onDisappear { moc.pr_save() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: moc)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("breakdownsSceneOrderChanged"))) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("breakdownsSceneSynced"))) { _ in reload() }
        .onAppear { reload() }
        .onChange(of: projectID) { _ in reload() }
    }
    
    @ViewBuilder
    private var shotDetailPane: some View {
        if let scene = selectedScene {
            ModernShotListPaneIOS(scene: scene, projectID: projectID)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if sizeClass == .compact {
                            Button(action: {
                                columnVisibility = .doubleColumn
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Scenes")
                                }
                            }
                        }
                    }
                }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundStyle(.quaternary)
                Text("Select a scene")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Choose a scene to view and edit shots")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private func reload() {
        moc.perform {
            guard let entityName = preferredSceneEntityName(moc: moc) else {
                DispatchQueue.main.async {
                    self.scenes = []
                    self.selectedScene = nil
                }
                return
            }
            
            let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let project = try? moc.existingObject(with: projectID),
               let model = moc.persistentStoreCoordinator?.managedObjectModel,
               let entity = model.entitiesByName[entityName] {
                // Exclude day breaks and off days from Shots app
                let projectPredicate = NSPredicate(format: "project == %@", project)

                // Check for sceneHeading or scriptLocation attributes to filter out dividers
                let hasSceneHeading = entity.attributesByName.keys.contains("sceneHeading")
                let hasScriptLocation = entity.attributesByName.keys.contains("scriptLocation")

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
            }

            // Performance optimizations
            req.fetchBatchSize = 20
            req.returnsObjectsAsFaults = true
            req.relationshipKeyPathsForPrefetching = ["project"]
            req.sortDescriptors = []

            var fetched = (try? moc.fetch(req)) ?? []
            if fetched.isEmpty {
                let allReq = NSFetchRequest<NSManagedObject>(entityName: entityName)

                // Performance optimizations for fallback
                allReq.fetchBatchSize = 20
                allReq.returnsObjectsAsFaults = true
                allReq.relationshipKeyPathsForPrefetching = ["project"]

                // Also exclude day breaks from fallback fetch
                if let model = moc.persistentStoreCoordinator?.managedObjectModel,
                   let entity = model.entitiesByName[entityName] {
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
                }

                fetched = (try? moc.fetch(allReq)) ?? []
            }
            
            let normalized = normalizeSceneOrdering(fetched, in: moc)
            DispatchQueue.main.async {
                self.scenes = normalized
                if let sel = self.selectedScene, normalized.contains(where: { $0.objectID == sel.objectID }) {
                    // keep selection
                } else {
                    self.selectedScene = normalized.first
                }
            }
        }
    }
}

// MARK: - Modern Scene Card for iOS
private struct ModernSceneCardIOS: View {
    let scene: NSManagedObject
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color strip indicator
            Rectangle()
                .fill(sceneColorGradient)
                .frame(height: 3)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))
            
            HStack(spacing: 12) {
                // Scene number
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(UIColor.tertiarySystemFill))
                        .frame(width: 36, height: 36)
                    Text(firstString(scene, keys: ["number"]) ?? "—")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        // INT/EXT badge
                        if let intExt = firstString(scene, keys: ["locationType", "intExt"]) {
                            Text(intExt.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.white.opacity(0.2) : Color(UIColor.tertiarySystemFill))
                                )
                        }
                        
                        // Time of day
                        if let tod = firstString(scene, keys: ["timeOfDay", "time"]) {
                            Text(tod.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isSelected ? .white.opacity(0.9) : .tertiary)
                        }
                    }
                    
                    // Location
                    Text(firstString(scene, keys: ["scriptLocation", "heading"]) ?? "Untitled Scene")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    // Description if available
                    if let desc = firstString(scene, keys: ["descriptionText", "sceneDescription"]), !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Shot count if available
                if let shots = scene.value(forKey: "shots") as? NSSet, shots.count > 0 {
                    VStack {
                        Text("\(shots.count)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .primary)
                        Text("shots")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : .tertiary)
                    }
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color(UIColor.secondarySystemGroupedBackground))
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4)
    }
    
    private var sceneColorGradient: LinearGradient {
        let lt = ((scene.value(forKey: "locationType") as? String) ?? "").uppercased()
        let tod = ((scene.value(forKey: "timeOfDay") as? String) ?? "").uppercased()
        
        let isExt = lt.contains("EXT")
        let isInt = lt.contains("INT")
        let isDay = tod.contains("DAY")
        let isNight = tod.contains("NIGHT")
        
        var colors: [Color]
        switch (isInt, isExt, isDay, isNight) {
        case (true, _, true, _):
            colors = [Color.orange, Color.yellow]
        case (_, true, true, _):
            colors = [Color.yellow, Color.green.opacity(0.8)]
        case (true, _, _, true):
            colors = [Color.blue, Color.indigo]
        case (_, true, _, true):
            colors = [Color.green, Color.teal]
        default:
            colors = [Color(UIColor.tertiarySystemFill), Color(UIColor.quaternarySystemFill)]
        }
        
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
    
    private func firstString(_ obj: NSManagedObject, keys: [String]) -> String? {
        for k in keys {
            if obj.entity.attributesByName.keys.contains(k) {
                if let s = obj.value(forKey: k) as? String {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { return t }
                }
            }
        }
        return nil
    }
}

// MARK: - Modern Shot List Pane for iOS
private struct ModernShotListPaneIOS: View {
    let scene: NSManagedObject
    let projectID: NSManagedObjectID
    @Environment(\.managedObjectContext) private var moc
    
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var listRefreshID = UUID()
    
    private let shotOrderKeys = ["index", "order", "position"]
    private let shotTitleKeys = ["code", "title", "name"]
    private let shotTypeKeys = ["type", "shotType"]
    private let shotCamKeys = ["cam", "camera"]
    private let shotLensKeys = ["lens", "focalLength"]
    
    private var baseShots: [NSManagedObject] {
        let relNames = ["shots", "shotItems", "sceneShots"]
        var set: NSSet? = nil
        for r in relNames where scene.entity.relationshipsByName.keys.contains(r) {
            set = scene.value(forKey: r) as? NSSet
            if set != nil { break }
        }
        let arr = (set?.allObjects as? [NSManagedObject]) ?? []
        return arr.sorted { a, b in
            let ai = (a.value(forKey: "index") as? NSNumber)?.intValue ?? Int.max
            let bi = (b.value(forKey: "index") as? NSNumber)?.intValue ?? Int.max
            return ai < bi
        }
    }
    
    private var filteredShots: [NSManagedObject] {
        if searchText.isEmpty { return baseShots }
        let lower = searchText.lowercased()
        return baseShots.filter { shot in
            let title = (shot.value(forKey: "title") as? String ?? "").lowercased()
            let code = (shot.value(forKey: "code") as? String ?? "").lowercased()
            return title.contains(lower) || code.contains(lower)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.sceneSlug)
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            if let num = scene.value(forKey: "number") as? String {
                                Badge(text: "Scene \(num)", color: .accentColor)
                            }
                            if let tod = scene.value(forKey: "timeOfDay") as? String {
                                Badge(text: tod.uppercased(), color: .blue)
                            }
                            Badge(text: "\(baseShots.count) shots", color: .green)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField("Search shots...", text: $searchText)
                }
                .padding(8)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            
            // Shot list
            if baseShots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredShots, id: \.objectID) { shot in
                            ModernShotCardIOS(
                                shot: shot,
                                orderKeys: shotOrderKeys,
                                titleKeys: shotTitleKeys,
                                typeKeys: shotTypeKeys,
                                camKeys: shotCamKeys,
                                lensKeys: shotLensKeys,
                                onDelete: { delete(shot) },
                                onCommit: save
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showingAddSheet) {
            AddShotSheetIOS(scene: scene, onAdd: { addShot() })
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: moc)) { _ in
            listRefreshID = UUID()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("No shots yet")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Add your first shot to begin")
                .font(.body)
                .foregroundStyle(.tertiary)
            
            Button(action: { showingAddSheet = true }) {
                Label("Add First Shot", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private struct Badge: View {
        let text: String
        let color: Color
        
        var body: some View {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                )
        }
    }
    
    private func save() {
        moc.perform {
            guard moc.hasChanges else { return }
            do {
                try moc.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    private func addShot() {
        guard let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName["ShotEntity"] else { return }
        let shot = NSManagedObject(entity: entity, insertInto: moc)
        
        let next = (baseShots.compactMap { ($0.value(forKey: "index") as? NSNumber)?.intValue }.max() ?? 0) + 1
        shot.setValue(next, forKey: "index")
        shot.setValue("A", forKey: "cam")
        
        if shot.entity.propertiesByName.keys.contains("scene") {
            shot.setValue(scene, forKey: "scene")
        }
        
        save()
        listRefreshID = UUID()
    }
    
    private func delete(_ shot: NSManagedObject) {
        moc.delete(shot)
        save()
        listRefreshID = UUID()
    }
}

// MARK: - Modern Shot Card for iOS
private struct ModernShotCardIOS: View {
    let shot: NSManagedObject
    let orderKeys: [String]
    let titleKeys: [String]
    let typeKeys: [String]
    let camKeys: [String]
    let lensKeys: [String]
    var onDelete: () -> Void
    var onCommit: () -> Void
    
    @State private var titleText = ""
    @State private var typeText = ""
    @State private var camText = ""
    @State private var lensText = ""
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Shot number
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(shot.numberString(for: orderKeys) ?? "•")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Shot Name", text: Binding(
                        get: { titleText.isEmpty ? (shot.string(for: titleKeys) ?? "") : titleText },
                        set: { titleText = $0; shot.setString($0, for: titleKeys); onCommit() }
                    ))
                    .font(.system(size: 15, weight: .medium))
                    
                    HStack(spacing: 8) {
                        MetadataTagIOS(label: "Type", value: typeText.isEmpty ? (shot.string(for: typeKeys) ?? "—") : typeText)
                        MetadataTagIOS(label: "Cam", value: camText.isEmpty ? (shot.string(for: camKeys) ?? "—") : camText)
                        MetadataTagIOS(label: "Lens", value: lensText.isEmpty ? (shot.string(for: lensKeys) ?? "—") : lensText)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .onAppear {
            titleText = shot.string(for: titleKeys) ?? ""
            typeText = shot.string(for: typeKeys) ?? ""
            camText = shot.string(for: camKeys) ?? ""
            lensText = shot.string(for: lensKeys) ?? ""
        }
    }
    
    private struct MetadataTagIOS: View {
        let label: String
        let value: String
        
        var body: some View {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemFill))
            )
        }
    }
}

// MARK: - Add Shot Sheet for iOS
private struct AddShotSheetIOS: View {
    let scene: NSManagedObject
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Shot details coming soon")
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .navigationTitle("Add Shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// Note: preferredSceneEntityName, normalizeSceneOrdering, and firstString
// are defined in ShotListComponents.swift and shared across files

// MARK: - Extensions (iOS)
private extension NSManagedObject {
    var sceneSlug: String {
        if entity.propertiesByName.keys.contains("heading"),
           let h = value(forKey: "heading") as? String, !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return h
        }
        
        let locType = (value(forKey: "locationType") as? String)?.uppercased()
        let locName = (value(forKey: "scriptLocation") as? String)?.uppercased()
        let tod = (value(forKey: "timeOfDay") as? String)?.uppercased()
        
        var parts: [String] = []
        if let lt = locType, !lt.isEmpty { parts.append(lt) }
        if let ln = locName, !ln.isEmpty { parts.append(ln) }
        
        let left = parts.isEmpty ? nil : parts.joined(separator: " ")
        if let left, let tod, !tod.isEmpty { return left + " — " + tod }
        if let left { return left }
        
        return "Untitled Scene"
    }
    
    func string(for keys: [String]) -> String? {
        for k in keys where entity.propertiesByName[k] != nil {
            if let v = value(forKey: k) as? String, !v.isEmpty { return v }
        }
        return nil
    }
    
    func numberString(for keys: [String]) -> String? {
        for k in keys where entity.propertiesByName[k] != nil {
            if let n = value(forKey: k) as? NSNumber { return n.stringValue }
            if let s = value(forKey: k) as? String, let _ = Int(s) { return s }
        }
        return nil
    }
    
    func setString(_ value: String, for keys: [String]) {
        for k in keys where entity.propertiesByName[k] != nil {
            setValue(value, forKey: k)
            return
        }
    }
}

private extension NSManagedObjectContext {
    func pr_save() {
        performAndWait {
            guard hasChanges else { return }
            do {
                try save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}

#endif
