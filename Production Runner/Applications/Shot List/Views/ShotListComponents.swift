//
//  ShotListComponents.swift
//  Production Runner
//
//  Component views for the Shot List module.
//  Extracted from ShotListerView.swift for better organization.
//

import SwiftUI
import CoreData
import WebKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-Platform Image Loading Helpers

/// Creates a SwiftUI Image from Data, handling platform differences
private func platformImage(from data: Data) -> Image? {
    #if os(macOS)
    if let nsImage = NSImage(data: data) {
        return Image(nsImage: nsImage)
    }
    return nil
    #else
    if let uiImage = UIImage(data: data) {
        return Image(uiImage: uiImage)
    }
    return nil
    #endif
}

/// Creates a SwiftUI Image from a URL, handling platform differences
private func platformImage(from url: URL) -> Image? {
    #if os(macOS)
    if let nsImage = NSImage(contentsOf: url) {
        return Image(nsImage: nsImage)
    }
    return nil
    #else
    if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
        return Image(uiImage: uiImage)
    }
    return nil
    #endif
}

/// Checks if image data is valid for the current platform
private func isValidImageData(_ data: Data) -> Bool {
    #if os(macOS)
    return NSImage(data: data) != nil
    #else
    return UIImage(data: data) != nil
    #endif
}

/// Checks if a URL contains a valid image for the current platform
private func isValidImageURL(_ url: URL) -> Bool {
    #if os(macOS)
    return NSImage(contentsOf: url) != nil
    #else
    guard let data = try? Data(contentsOf: url) else { return false }
    return UIImage(data: data) != nil
    #endif
}

// MARK: - Compact Scene Card (For Top Down View)
struct CompactSceneCard: View {
    let scene: NSManagedObject
    let isSelected: Bool
    var accentColor: Color = .red
    var textColor: Color = .primary
    var secondaryTextColor: Color = .secondary

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // Scene number
            Text(sceneNumber)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : textColor)

            Spacer()

            // Shot count
            Text("\(shotCount)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white.opacity(0.8) : secondaryTextColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? accentColor : (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isSelected ? accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var sceneNumber: String {
        if let num = scene.value(forKey: "number") as? String, !num.isEmpty {
            return num
        }
        return "—"
    }

    private var shotCount: Int {
        if let shots = scene.value(forKey: "shots") as? NSSet {
            return shots.count
        }
        return 0
    }
}

// MARK: - Refined Scene Card (Matching App Style)
struct RefinedSceneCard: View {
    let scene: NSManagedObject
    let isSelected: Bool
    var theme: AppAppearance.Theme = .standard
    var accentColor: Color = .red
    var textColor: Color = .primary
    var secondaryTextColor: Color = .secondary

    @State private var isHovered = false

    // Theme-aware card background color
    private var cardBg: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.03)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.06)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.05)
        case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157)
        }
    }

    var body: some View {
        sceneCardContent
        .background(cardBackground)
        .overlay(cardBorder)
        .scaleEffect(isHovered ? 1.01 : 1)
        .shadow(color: isSelected ? accentColor.opacity(0.15) : Color.black.opacity(0.02), radius: isSelected ? 6 : 2, y: isSelected ? 2 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var sceneCardContent: some View {
        HStack(spacing: 12) {
            sceneNumberBadge
            sceneDetailsColumn
            shotCountIndicator
        }
        .padding(12)
    }

    private var sceneNumberBadge: some View {
        ZStack {
            Circle()
                .fill(isSelected ? accentColor : cardBg)
                .frame(width: 36, height: 36)
            Text(firstString(scene, keys: ["number"]) ?? "—")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : textColor)
        }
    }

    private var sceneDetailsColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main scene heading line: INT. SCENE HEADING - NIGHT 4/8
            Text(formattedSceneHeading)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : textColor)
                .lineLimit(1)
                .truncationMode(.tail)

            // Description if available
            if let desc = firstString(scene, keys: ["descriptionText", "sceneDescription"]), !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : secondaryTextColor)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedSceneHeading: String {
        var parts: [String] = []

        // INT/EXT
        if let intExt = firstString(scene, keys: ["locationType", "intExt", "interiorExterior"]) {
            let locType = intExt.uppercased()
            parts.append(locType.hasSuffix(".") ? locType : locType + ".")
        }

        // Scene Location
        if let location = firstString(scene, keys: ["scriptLocation", "sceneHeading", "heading"]) {
            // Remove leading period to avoid double periods like "INT. . SCENE"
            var cleanedLocation = location.uppercased()
            if cleanedLocation.hasPrefix(".") {
                cleanedLocation = String(cleanedLocation.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !cleanedLocation.isEmpty {
                parts.append(cleanedLocation)
            }
        }

        // Time of Day
        if let tod = firstString(scene, keys: ["timeOfDay", "time"]) {
            parts.append("— " + tod.uppercased())
        }

        // Page Length removed from display

        return parts.isEmpty ? "Untitled Scene" : parts.joined(separator: " ")
    }
    
    @ViewBuilder
    private var shotCountIndicator: some View {
        if let shots = scene.value(forKey: "shots") as? NSSet, shots.count > 0 {
            VStack(spacing: 2) {
                Text("\(shots.count)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : textColor)
                    .monospacedDigit()
                Text("shots")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.6) : secondaryTextColor.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? accentColor : cardBg)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isSelected ? accentColor.opacity(0.3) : (isHovered ? accentColor.opacity(0.15) : accentColor.opacity(0.08)),
                lineWidth: 1
            )
    }
    
    private var sceneColorGradient: LinearGradient {
        let lt = ((scene.value(forKey: "locationType") as? String) ?? (scene.value(forKey: "intExt") as? String) ?? "").uppercased()
        let tod = ((scene.value(forKey: "timeOfDay") as? String) ?? (scene.value(forKey: "time") as? String) ?? "").uppercased()
        
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
            colors = [Color.primary.opacity(0.2), Color.primary.opacity(0.1)]
        }
        
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
    
    func firstString(_ obj: NSManagedObject, keys: [String]) -> String? {
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

// MARK: - Refined Shot List Pane (Matching App Style)
struct RefinedShotListPane: View {
    let scene: NSManagedObject
    let projectID: NSManagedObjectID
    let aspectRatio: String
    @Binding var showStoryboard: Bool
    @Environment(\.managedObjectContext) private var moc

    // Theme support
    @AppStorage("app_theme") private var appTheme: String = "Standard"

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    // Theme-aware colors
    private var themedAccentColor: Color {
        switch currentTheme {
        case .standard: return .accentColor
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .cinema: return Color(red: 0.0, green: 0.878, blue: 0.329)
        }
    }

    private var themedBackgroundColor: Color {
        switch currentTheme {
        case .standard: return Color(NSColor.controlBackgroundColor)
        case .aqua: return Color(red: 0.14, green: 0.16, blue: 0.18)
        case .neon: return Color(red: 0.05, green: 0.05, blue: 0.08)
        case .retro: return Color.black
        case .cinema: return Color(red: 0.078, green: 0.094, blue: 0.110)
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
        case .cinema: return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }

    @State private var selection = Set<NSManagedObjectID>()
    @State private var searchText: String = ""
    @State private var listRefreshID = UUID()
    @State private var project: NSManagedObject? = nil
    @State private var showBrowserPopup: Bool = false
    @State private var browserURL: String = "https://www.pinterest.com/search/pins/?q=film%20storyboard%20reference"

    // Image editing state
    @State private var editingImageForShot: NSManagedObjectID? = nil
    @State private var dragStartLocation: CGPoint = .zero
    @State private var currentDragOffset: CGSize = .zero

    // Computed storyboard card dimensions based on aspect ratio
    private var storyboardCardWidth: CGFloat {
        return 280
    }

    private var storyboardCardHeight: CGFloat {
        let components = aspectRatio.split(separator: ":")
        guard components.count == 2,
              let widthRatio = Double(components[0]),
              let heightRatio = Double(components[1]),
              widthRatio > 0, heightRatio > 0 else {
            return 180
        }
        let ratio = widthRatio / heightRatio
        return storyboardCardWidth / ratio
    }

    // Computed storyboard popup height based on card height plus padding
    private var storyboardHeight: CGFloat {
        // Card height + shot details (approx 100px) + header/padding (60px top + 40px bottom)
        return storyboardCardHeight + 200
    }

    #if os(macOS)
    private let pasteboard = NSPasteboard.general
    #else
    private let pasteboard = UIPasteboard.general
    #endif

    private let shotTitleKeys = ["code", "title", "name", "notes"]
    private let shotTypeKeys = ["type", "shotType"]
    private let shotCamKeys = ["cam", "camera"]
    private let shotLensKeys = ["lens", "focalLength"]
    private let shotRigKeys = ["rig", "stabilizer", "support"]
    private let shotSetupKeys = ["setupMinutes", "setupTime", "setup"]
    private let shotShootKeys = ["shootMinutes", "shootTime", "duration", "minutes", "durationMinutes"]
    private let shotOrderKeys = ["index", "order", "position"]
    private let shotDescriptionKeys = ["descriptionText", "shotDescription", "desc"]
    private let shotProductionNotesKeys = ["productionNotes", "prodNotes", "notesProduction", "notes"]
    private let shotScreenRefKeys = ["screenReference", "screenRef", "reference", "ref"]
    private let shotLightingNotesKeys = ["lightingNotes", "lighting", "lightNotes"]
    private let shotCastIDKeys = ["castID", "castId", "cast", "castMember"]
    private let shotColorKeys = ["color", "shotColor", "setupColor"]

    private var baseShots: [NSManagedObject] {
        let relNames = ["shots", "shotItems", "sceneShots", "shotsSet"]
        var set: NSSet? = nil
        for r in relNames where scene.entity.relationshipsByName.keys.contains(r) {
            set = scene.value(forKey: r) as? NSSet
            if set != nil { break }
        }
        let arr = (set?.allObjects as? [NSManagedObject]) ?? []
        return arr.sorted { a, b in
            let ai = (a.value(forKey: "index") as? NSNumber)?.intValue
                 ?? (a.value(forKey: "order") as? NSNumber)?.intValue
                 ?? (a.value(forKey: "position") as? NSNumber)?.intValue
                 ?? Int.max
            let bi = (b.value(forKey: "index") as? NSNumber)?.intValue
                 ?? (b.value(forKey: "order") as? NSNumber)?.intValue
                 ?? (b.value(forKey: "position") as? NSNumber)?.intValue
                 ?? Int.max
            if ai != bi { return ai < bi }
            let at = (a.value(forKey: "descriptionText") as? String) ?? (a.value(forKey: "code") as? String) ?? ""
            let bt = (b.value(forKey: "descriptionText") as? String) ?? (b.value(forKey: "code") as? String) ?? ""
            return at.localizedStandardCompare(bt) == .orderedAscending
        }
    }

    private var filteredShots: [NSManagedObject] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return baseShots }
        let lower = q.lowercased()
        func contains(_ s: String?) -> Bool { (s ?? "").lowercased().contains(lower) }
        return baseShots.filter { shot in
            contains(shot.string(for: shotTitleKeys)) ||
            contains(shot.string(for: shotTypeKeys)) ||
            contains(shot.string(for: shotCamKeys)) ||
            contains(shot.string(for: shotLensKeys)) ||
            contains(shot.string(for: shotRigKeys))
        }
    }

    private var totalDuration: Double {
        baseShots.reduce(0) { acc, s in
            for k in shotShootKeys where s.entity.propertiesByName[k] != nil {
                if let n = s.value(forKey: k) as? NSNumber { return acc + n.doubleValue }
                if let str = s.value(forKey: k) as? String, let d = Double(str) { return acc + d }
            }
            return acc
        }
    }

    private var totalSetups: Int {
        // Count unique setups - shots with the same color count as one setup
        // If no colors are set, estimate based on shot type changes
        var setupColors = Set<String>()
        var hasColors = false

        for shot in baseShots {
            if let color = shot.value(forKey: "color") as? String, !color.isEmpty {
                setupColors.insert(color)
                hasColors = true
            }
        }

        // If colors are used, return color count
        if hasColors {
            return setupColors.count
        }

        // Otherwise, estimate setups by counting shot type changes
        // Different shot types (Wide, Medium, Close-up) typically mean different setups
        var previousType: String? = nil
        var estimatedSetups = 0

        for shot in baseShots {
            let currentType = shot.string(for: shotTypeKeys) ?? ""
            if currentType != previousType {
                estimatedSetups += 1
                previousType = currentType
            }
        }

        return max(estimatedSetups, 1)
    }

    /// Extract cast IDs from scene's castMembersJSON
    private var sceneCastIDs: [String] {
        // Try to load cast members from JSON format
        if let castData = scene.value(forKey: "castMembersJSON") as? String,
           let data = castData.data(using: .utf8),
           let members = try? JSONDecoder().decode([BreakdownCastMember].self, from: data) {
            return members.map { $0.castID }.sorted { a, b in
                // Sort numerically if possible, otherwise alphabetically
                if let aNum = Int(a), let bNum = Int(b) {
                    return aNum < bNum
                }
                return a.localizedStandardCompare(b) == .orderedAscending
            }
        }
        return []
    }

    private var scenesWithoutShots: Int {
        guard let project = project else { return 0 }

        // Get all scenes from project
        let relNames = ["scenes", "sceneItems", "projectScenes"]
        var allScenes: [NSManagedObject] = []
        for r in relNames where project.entity.relationshipsByName.keys.contains(r) {
            if let set = project.value(forKey: r) as? NSSet {
                allScenes = set.allObjects as? [NSManagedObject] ?? []
                break
            }
        }

        // Count scenes without shots
        var count = 0
        for scene in allScenes {
            let shotRelNames = ["shots", "shotItems", "sceneShots", "shotsSet"]
            var hasShots = false
            for r in shotRelNames where scene.entity.relationshipsByName.keys.contains(r) {
                if let shotSet = scene.value(forKey: r) as? NSSet, shotSet.count > 0 {
                    hasShots = true
                    break
                }
            }
            if !hasShots {
                count += 1
            }
        }

        return count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                refinedHeader

                #if os(macOS)
                VStack(spacing: 0) {
                    // Top section: Shots grid
                    VStack(spacing: 0) {
                        if baseShots.isEmpty {
                            emptyState
                        } else {
                            shotGrid
                        }
                    }
                    .frame(minHeight: 300)

                    // Bottom section: Storyboard popup with slide animation
                    if showStoryboard {
                        storyboardPane
                            .frame(height: storyboardHeight)
                            .clipped()
                            .transition(.move(edge: .bottom))
                    }
                }
                #else
                if baseShots.isEmpty {
                    emptyState
                } else {
                    shotGrid
                }
                #endif
            }

            // Browser popup pane at bottom (on top of storyboard if both are open)
            if showBrowserPopup {
                browserPopupPane
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(themedBackgroundColor)
        .onReceive(NotificationCenter.default.publisher(for: .breakdownsSceneSynced)) { _ in
            listRefreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .breakdownsSceneOrderChanged)) { _ in
            listRefreshID = UUID()
        }
        .onAppear { loadProject() }
        .onChange(of: projectID) { _ in loadProject() }
        #if os(macOS)
        .onDeleteCommand(perform: deleteSelected)
        #endif
    }

    private var refinedHeader: some View {
        VStack(spacing: 0) {
            // Main header section matching Contacts style
            VStack(spacing: 16) {
                // Top row: Scene info and stats
                HStack(alignment: .top, spacing: 16) {
                    // Scene number badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [themedAccentColor, themedAccentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: themedAccentColor.opacity(0.2), radius: 6, y: 2)
                        Text((scene.value(forKey: "number") as? String) ?? "—")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(scene.sceneSlug)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(themedTextColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer()

                    // Stats section matching Dashboard CompactStatCard style
                    HStack(spacing: 12) {
                        CompactStat(value: "\(baseShots.count)", label: "Shots", icon: "camera.fill", color: themedAccentColor, theme: currentTheme)
                        CompactStat(value: formatDuration(totalDuration), label: "Duration", icon: "clock.fill", color: .green, theme: currentTheme)
                        if let pages = scene.pageEighthsString {
                            CompactStat(value: pages, label: "Pages", icon: "doc.text.fill", color: .purple, theme: currentTheme)
                        }
                    }
                }
                
                // Action buttons row matching Contacts button style
                HStack(spacing: 12) {
                    // Primary action button
                    PremiumButton(title: "Add Shot", icon: "plus", style: .primary) {
                        addShot()
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    
                    PremiumButton(title: "Duplicate", icon: "doc.on.doc", style: .secondary) {
                        duplicateSelected()
                    }
                    .disabled(selection.isEmpty)
                    .keyboardShortcut("d", modifiers: .command)
                    
                    PremiumButton(title: "Delete", icon: "trash", style: .destructive) {
                        deleteSelected()
                    }
                    .disabled(selection.isEmpty)
                    .keyboardShortcut(.delete, modifiers: [])
                    
                    Spacer()

                    // Storyboard toggle button
                    #if os(macOS)
                    Button(action: {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                            showStoryboard.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showStoryboard ? "rectangle.grid.2x2.fill" : "rectangle.grid.2x2")
                                .font(.system(size: 14, weight: .medium))
                            Text("Reference Shot")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(showStoryboard ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(showStoryboard ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(showStoryboard ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    #endif
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            themedAccentColor.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .background(currentTheme == .standard ? AnyView(Color.clear.background(.ultraThinMaterial)) : AnyView(Color.clear))
                }
            )
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [themedAccentColor.opacity(0.06), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1),
                alignment: .bottom
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(themedSecondaryTextColor.opacity(0.5))
            Text("No shots yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(themedSecondaryTextColor)
            Text("Add your first shot to begin building this scene")
                .font(.body)
                .foregroundStyle(themedSecondaryTextColor.opacity(0.7))
            
            PremiumButton(title: "Add First Shot", icon: "plus.circle.fill", style: .primary) {
                addShot()
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
    
    private var shotGrid: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredShots, id: \.objectID) { shot in
                    RefinedShotCard(
                        shot: shot,
                        isSelected: selection.contains(shot.objectID),
                        orderKeys: shotOrderKeys,
                        typeKeys: shotTypeKeys,
                        camKeys: shotCamKeys,
                        titleKeys: shotTitleKeys,
                        lensKeys: shotLensKeys,
                        rigKeys: shotRigKeys,
                        setupKeys: shotSetupKeys,
                        shootKeys: shotShootKeys,
                        descriptionKeys: shotDescriptionKeys,
                        productionNotesKeys: shotProductionNotesKeys,
                        screenRefKeys: shotScreenRefKeys,
                        lightingNotesKeys: shotLightingNotesKeys,
                        castIDKeys: shotCastIDKeys,
                        colorKeys: shotColorKeys,
                        availableCastIDs: sceneCastIDs,
                        theme: currentTheme,
                        onDuplicate: { duplicate(shot) },
                        onDelete: { delete([shot]) },
                        onCommit: save
                    )
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selection = [shot.objectID]
                            }
                        }
                    )
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Helper Components
    
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
    
    private struct CompactStat: View {
        let value: String
        let label: String
        let icon: String
        let color: Color
        var theme: AppAppearance.Theme = .standard

        private var cardBg: Color {
            switch theme {
            case .standard: return color.opacity(0.08)
            case .aqua: return color.opacity(0.12)
            case .neon: return color.opacity(0.10)
            case .retro: return color.opacity(0.08)
            case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157)
            }
        }

        private var labelColor: Color {
            switch theme {
            case .standard: return .secondary
            case .aqua: return Color(red: 0.6, green: 0.65, blue: 0.72)
            case .neon: return Color(red: 0.7, green: 0.7, blue: 0.8)
            case .retro: return Color(red: 0.1, green: 0.5, blue: 0.15)
            case .cinema: return Color(red: 0.6, green: 0.6, blue: 0.6)
            }
        }

        var body: some View {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(labelColor)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cardBg)
            )
        }
    }
    
    private struct PremiumButton: View {
        let title: String
        let icon: String
        let style: ButtonStyle
        let action: () -> Void
        
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled
        
        enum ButtonStyle {
            case primary, secondary, destructive
            
            var backgroundColor: Color {
                switch self {
                case .primary: return .accentColor
                case .secondary: return .primary.opacity(0.08)
                case .destructive: return .red.opacity(0.1)
                }
            }
            
            var foregroundColor: Color {
                switch self {
                case .primary: return .white
                case .secondary: return .primary
                case .destructive: return .red
                }
            }
        }
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(style.backgroundColor.opacity(isEnabled ? 1 : 0.5))
                        
                        if style == .primary && isEnabled {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                )
                .foregroundStyle(style.foregroundColor.opacity(isEnabled ? 1 : 0.5))
                .shadow(color: style == .primary && isEnabled ? Color.accentColor.opacity(0.3) : Color.clear, radius: isHovered ? 8 : 4, x: 0, y: 2)
                .scaleEffect(isHovered && isEnabled ? 1.02 : 1)
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ minutes: Double) -> String {
        if minutes <= 0 { return "0m" }
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
    
    func firstString(_ obj: NSManagedObject, keys: [String]) -> String? {
        for k in keys where obj.entity.propertiesByName[k] != nil {
            if let v = obj.value(forKey: k) as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return v
            }
        }
        return nil
    }

    // MARK: - Storyboard Pane

    private var storyboardPane: some View {
        VStack(spacing: 0) {
            // Reference Shot header
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
                    // Search Web button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            self.showBrowserPopup.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: self.showBrowserPopup ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                            Text(self.showBrowserPopup ? "Close Browser" : "Search Web")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(self.showBrowserPopup ? .blue : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(self.showBrowserPopup ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)

                    // Close button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showStoryboard = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
            )

            // Storyboard content
            if filteredShots.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("No Shots")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Add shots to this scene to see them in the storyboard")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 16) {
                        ForEach(filteredShots, id: \.objectID) { shot in
                            storyboardCard(for: shot)
                        }
                    }
                    .padding(20)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
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
            }
            .padding(16)
            .background(
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
            )

            // Web view
            WebView(url: $browserURL)
                .frame(height: 500)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 12, y: -4)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func storyboardCard(for shot: NSManagedObject) -> some View {
        let cardWidth = self.storyboardCardWidth
        let cardHeight = self.storyboardCardHeight

        return VStack(alignment: .leading, spacing: 12) {
            storyboardCardImageSection(for: shot, cardWidth: cardWidth, cardHeight: cardHeight)
            storyboardCardDetailsSection(for: shot)
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
    private func storyboardCardImageSection(for shot: NSManagedObject, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let placeholderGradient = LinearGradient(
            colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(placeholderGradient)
                .frame(width: cardWidth, height: cardHeight)

            storyboardCardImageContent(for: shot, cardWidth: cardWidth, cardHeight: cardHeight)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func storyboardCardImageContent(for shot: NSManagedObject, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        if let imageData = shot.value(forKey: "storyboardImageData") as? Data,
           isValidImageData(imageData) {
            storyboardEditableImage(for: shot, imageData: imageData, cardWidth: cardWidth, cardHeight: cardHeight)
        } else if let screenRef = shot.string(for: shotScreenRefKeys),
                  !screenRef.isEmpty,
                  let url = URL(string: screenRef),
                  isValidImageURL(url),
                  let image = platformImage(from: url) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No Reference")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func storyboardEditableImage(for shot: NSManagedObject, imageData: Data, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let isEditing = editingImageForShot == shot.objectID
        let offsetX = (shot.value(forKey: "storyboardImageOffsetX") as? Double) ?? 0.0
        let offsetY = (shot.value(forKey: "storyboardImageOffsetY") as? Double) ?? 0.0
        let totalOffsetX = offsetX + (isEditing ? currentDragOffset.width : 0)
        let totalOffsetY = offsetY + (isEditing ? currentDragOffset.height : 0)
        let borderColor: Color = isEditing ? .blue : .clear

        if let image = platformImage(from: imageData) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .offset(x: totalOffsetX, y: totalOffsetY)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 3)
                )
                .onTapGesture(count: 2) {
                    editingImageForShot = shot.objectID
                    currentDragOffset = .zero
                }
                .gesture(
                    isEditing ? DragGesture()
                        .onChanged { value in
                            currentDragOffset = CGSize(
                                width: value.translation.width,
                                height: value.translation.height
                            )
                        }
                        .onEnded { _ in
                            let newOffsetX = offsetX + currentDragOffset.width
                            let newOffsetY = offsetY + currentDragOffset.height
                            shot.setValue(newOffsetX, forKey: "storyboardImageOffsetX")
                            shot.setValue(newOffsetY, forKey: "storyboardImageOffsetY")
                            moc.pr_save()
                            editingImageForShot = nil
                            currentDragOffset = .zero
                            listRefreshID = UUID()
                        }
                    : nil
                )
                .contextMenu {
                    Button(action: {
                        shot.setValue(nil, forKey: "storyboardImageData")
                        shot.setValue(0.0, forKey: "storyboardImageOffsetX")
                        shot.setValue(0.0, forKey: "storyboardImageOffsetY")
                        editingImageForShot = nil
                        moc.pr_save()
                        listRefreshID = UUID()
                    }) {
                        Label("Delete Storyboard Image", systemImage: "trash")
                    }

                    Button(action: {
                        shot.setValue(0.0, forKey: "storyboardImageOffsetX")
                        shot.setValue(0.0, forKey: "storyboardImageOffsetY")
                        editingImageForShot = nil
                        moc.pr_save()
                        listRefreshID = UUID()
                    }) {
                        Label("Reset Image Position", systemImage: "arrow.counterclockwise")
                    }
                }
                #if os(macOS)
                .focusable()
                .onDeleteCommand {
                    shot.setValue(nil, forKey: "storyboardImageData")
                    shot.setValue(0.0, forKey: "storyboardImageOffsetX")
                    shot.setValue(0.0, forKey: "storyboardImageOffsetY")
                    editingImageForShot = nil
                    moc.pr_save()
                    listRefreshID = UUID()
                }
                #endif
        }
    }

    @ViewBuilder
    private func storyboardCardDetailsSection(for shot: NSManagedObject) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Shot title/code
            if let title = shot.string(for: shotTitleKeys), !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            } else {
                Text("Untitled Shot")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // Shot type and camera
            HStack(spacing: 8) {
                if let type = shot.string(for: shotTypeKeys), !type.isEmpty {
                    CompactBadge(text: type, color: .blue)
                }
                if let cam = shot.string(for: shotCamKeys), !cam.isEmpty {
                    CompactBadge(text: cam, color: .green)
                }
            }

            // Lens and Rig info
            HStack(spacing: 8) {
                if let lens = shot.string(for: shotLensKeys), !lens.isEmpty {
                    CompactBadge(text: lens, color: .purple)
                }
                if let rig = shot.string(for: shotRigKeys), !rig.isEmpty {
                    CompactBadge(text: rig, color: .orange)
                }
            }

            // Shot description
            if let desc = shot.string(for: shotDescriptionKeys), !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(width: 280, alignment: .leading)
            }
        }
    }

    // MARK: - Storyboard Card Helper View
    private struct StoryboardCardView: View {
        let shot: NSManagedObject
        let shotTitleKeys: [String]
        let shotTypeKeys: [String]
        let shotCamKeys: [String]
        let shotDescriptionKeys: [String]
        let shotScreenRefKeys: [String]
        let aspectRatio: String

        // Computed dimensions based on aspect ratio
        private var cardWidth: CGFloat { 280 }
        private var cardHeight: CGFloat {
            let components = aspectRatio.split(separator: ":")
            guard components.count == 2,
                  let widthRatio = Double(components[0]),
                  let heightRatio = Double(components[1]),
                  widthRatio > 0, heightRatio > 0 else {
                return 180
            }
            let ratio = widthRatio / heightRatio
            return cardWidth / ratio
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                imageSection
                detailsSection
            }
            .padding(12)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        }

        private var cardBackground: some View {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        }

        private var cardBorder: some View {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }

        @ViewBuilder
        private var imageSection: some View {
            let placeholderGradient = LinearGradient(
                colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(placeholderGradient)
                    .frame(width: cardWidth, height: cardHeight)

                imageContent
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }

        @ViewBuilder
        private var imageContent: some View {
            if let imageData = shot.value(forKey: "storyboardImageData") as? Data,
               isValidImageData(imageData),
               let image = platformImage(from: imageData) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let screenRef = shot.string(for: shotScreenRefKeys),
                      !screenRef.isEmpty,
                      let url = URL(string: screenRef),
                      isValidImageURL(url),
                      let image = platformImage(from: url) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Reference")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }

        @ViewBuilder
        private var detailsSection: some View {
            VStack(alignment: .leading, spacing: 6) {
                titleView
                badgesRow
                descriptionView
            }
        }

        @ViewBuilder
        private var titleView: some View {
            if let title = shot.string(for: shotTitleKeys), !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            } else {
                Text("Untitled Shot")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }

        @ViewBuilder
        private var badgesRow: some View {
            HStack(spacing: 8) {
                if let type = shot.string(for: shotTypeKeys), !type.isEmpty {
                    CompactBadge(text: type, color: .blue)
                }
                if let cam = shot.string(for: shotCamKeys), !cam.isEmpty {
                    CompactBadge(text: cam, color: .green)
                }
            }
        }

        @ViewBuilder
        private var descriptionView: some View {
            if let desc = shot.string(for: shotDescriptionKeys), !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(width: 280, alignment: .leading)
            }
        }
    }

    private func loadProject() {
        moc.perform {
            let obj = try? moc.existingObject(with: projectID)
            DispatchQueue.main.async { self.project = obj }
        }
    }
    
    private func save() {
        moc.perform {
            do {
                let inserted = Array(self.moc.insertedObjects)
                if !inserted.isEmpty {
                    try self.moc.obtainPermanentIDs(for: Array(inserted))
                }
                try self.moc.save()
                var p = self.moc.parent
                while let parent = p {
                    try parent.performAndWait {
                        if parent.hasChanges { try parent.save() }
                    }
                    p = parent.parent
                }
                DispatchQueue.main.async {
                    self.listRefreshID = UUID() // Refresh UI in real-time
                }
            } catch {
                NSLog("Shot save error: \(error)")
            }
        }
    }
    
    private func addShot() {
        guard let entity = moc.persistentStoreCoordinator?.managedObjectModel.entitiesByName["ShotEntity"] else { return }
        let shot = NSManagedObject(entity: entity, insertInto: moc)
        
        let next = (
            baseShots.compactMap { s in
                (s.value(forKey: "index") as? NSNumber)?.intValue ??
                (s.value(forKey: "order") as? NSNumber)?.intValue ??
                (s.value(forKey: "position") as? NSNumber)?.intValue
            }.max() ?? 0
        ) + 1
        
        shot.setValue(next, forKey: "index")
        
        // Clear placeholder strings
        for key in ["descriptionText", "shotDescription", "desc", "code", "notes", "title", "name"] {
            if shot.entity.propertiesByName.keys.contains(key) {
                shot.setValue("", forKey: key)
            }
        }
        
        // Set default camera to "A"
        if shot.entity.propertiesByName.keys.contains("cam") {
            shot.setValue("A", forKey: "cam")
        } else if shot.entity.propertiesByName.keys.contains("camera") {
            shot.setValue("A", forKey: "camera")
        }
        
        attach(shot: shot)
        try? moc.obtainPermanentIDs(for: [shot])
        selection = [shot.objectID]
        save()
    }
    
    private func attach(shot: NSManagedObject) {
        if shot.entity.propertiesByName.keys.contains("scene") {
            shot.setValue(scene, forKey: "scene")
            _ = (scene.value(forKey: "shots") as? NSSet)?.count
            return
        }
        let relNames = ["shots", "shotItems", "sceneShots", "shotsSet"]
        for r in relNames where scene.entity.relationshipsByName.keys.contains(r) {
            let mset = scene.mutableSetValue(forKey: r)
            mset.add(shot)
            return
        }
    }
    
    private func duplicate(_ shot: NSManagedObject) {
        let copy = NSManagedObject(entity: shot.entity, insertInto: moc)
        
        // Copy key fields
        for key in ["code", "descriptionText", "lens", "focalLength", "type", "cam", "rig"] {
            if let value = shot.value(forKey: key) {
                copy.setValue(value, forKey: key)
            }
        }
        
        let next = (
            baseShots.compactMap { s in
                (s.value(forKey: "index") as? NSNumber)?.intValue ??
                (s.value(forKey: "order") as? NSNumber)?.intValue ??
                (s.value(forKey: "position") as? NSNumber)?.intValue
            }.max() ?? 0
        ) + 1
        
        copy.setValue(next, forKey: "index")
        attach(shot: copy)
        selection = [copy.objectID]
        save()
    }
    
    private func deleteSelected() {
        let items = baseShots.filter { selection.contains($0.objectID) }
        delete(items)
    }
    
    private func delete(_ items: [NSManagedObject]) {
        items.forEach { moc.delete($0) }
        save()
        selection.removeAll()
        listRefreshID = UUID()
    }
    
    private func duplicateSelected() {
        let items = baseShots.filter { selection.contains($0.objectID) }
        items.forEach { duplicate($0) }
    }
}

// MARK: - Refined Shot Card (Matching App Style)
struct RefinedShotCard: View {
    let shot: NSManagedObject
    let isSelected: Bool
    let orderKeys: [String]
    let typeKeys: [String]
    let camKeys: [String]
    let titleKeys: [String]
    let lensKeys: [String]
    let rigKeys: [String]
    let setupKeys: [String]
    let shootKeys: [String]
    let descriptionKeys: [String]
    let productionNotesKeys: [String]
    let screenRefKeys: [String]
    let lightingNotesKeys: [String]
    let castIDKeys: [String]
    let colorKeys: [String]
    let availableCastIDs: [String]
    var theme: AppAppearance.Theme = .standard

    var onDuplicate: () -> Void
    var onDelete: () -> Void
    var onCommit: () -> Void

    // Theme-aware colors
    private var themedAccentColor: Color {
        switch theme {
        case .standard: return .accentColor
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .cinema: return Color(red: 0.0, green: 0.878, blue: 0.329)
        }
    }

    private var themedTextColor: Color {
        switch theme {
        case .standard: return .primary
        case .aqua: return Color(red: 0.85, green: 0.88, blue: 0.92)
        case .neon: return .white
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .cinema: return .white
        }
    }

    private var themedSecondaryTextColor: Color {
        switch theme {
        case .standard: return .secondary
        case .aqua: return Color(red: 0.6, green: 0.65, blue: 0.72)
        case .neon: return Color(red: 0.7, green: 0.7, blue: 0.8)
        case .retro: return Color(red: 0.1, green: 0.5, blue: 0.15)
        case .cinema: return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }

    private var themedCardBg: Color {
        switch theme {
        case .standard: return Color.primary.opacity(0.03)
        case .aqua: return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.06)
        case .neon: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.04)
        case .retro: return Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.03)
        case .cinema: return Color(red: 0.110, green: 0.133, blue: 0.157)
        }
    }

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var titleText = ""
    @State private var descriptionText = ""
    @State private var typeText = ""
    @State private var camText = ""
    @State private var lensText = ""
    @State private var rigText = ""
    @State private var setupText = ""
    @State private var shootText = ""
    @State private var prodNotesText = ""
    @State private var screenRefText = ""
    @State private var lightingNotesText = ""
    @State private var castIDText = ""
    @State private var colorText = ""

    @State private var showTypeSheet = false
    @State private var showCamSheet = false
    @State private var showLensSheet = false
    @State private var showRigSheet = false
    @State private var showProdNotesSheet = false
    @State private var showScreenRefSheet = false
    @State private var showColorSheet = false
    @State private var showCastIDSheet = false

    private let typeOptions = ["W", "MW", "LS", "MS", "MCU", "CU", "ECU", "OTS", "2S"]
    private let camOptions = ["A", "B", "C", "D", "E", "F", "G"]
    private let lensOptions = [
        // Ultra Wide Primes
        "8mm", "10mm", "12mm", "14mm", "16mm", "18mm", "20mm", "21mm",
        // Wide Primes
        "24mm", "25mm", "27mm", "28mm", "29mm", "32mm", "35mm",
        // Standard Primes
        "40mm", "50mm", "55mm", "65mm",
        // Portrait/Medium Telephoto Primes
        "75mm", "85mm", "100mm", "135mm",
        // Telephoto Primes
        "150mm", "180mm", "200mm", "300mm",
        // Common Zooms
        "15-40mm", "17-35mm", "24-70mm", "24-105mm", "28-76mm", "45-250mm", "70-200mm", "70-300mm",
        // Anamorphic (2x squeeze)
        "25mm Anamorphic", "32mm Anamorphic", "40mm Anamorphic", "50mm Anamorphic", "65mm Anamorphic", "75mm Anamorphic", "100mm Anamorphic", "135mm Anamorphic",
        // Macro
        "50mm Macro", "100mm Macro",
        // Specialty
        "Fisheye", "Tilt-Shift", "Lensbaby", "Probe Lens",
        // Custom option
        "Custom"
    ]
    private let rigOptions = ["Handheld", "Tripod", "Slider", "Gimbal", "Steadicam", "Dolly", "Jib", "Crane", "Drone"]
    private let colorOptions = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Gray"]

    private var cardBorderColor: Color {
        if !colorText.isEmpty {
            return colorForName(colorText)
        } else if isSelected {
            return themedAccentColor
        } else if isHovered {
            return themedAccentColor.opacity(0.12)
        } else {
            return themedAccentColor.opacity(0.08)
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "gray": return .gray
        default: return .gray.opacity(0.3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content area with refined styling
            HStack(alignment: .top, spacing: 16) {
                // Shot number badge matching scene card style
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isSelected ? [themedAccentColor, themedAccentColor.opacity(0.8)] : [themedCardBg, themedCardBg.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Text(shot.numberString(for: orderKeys) ?? "•")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : themedTextColor)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    // Title row with refined styling
                    HStack {
                        TextField("Shot Name", text: Binding(
                            get: { titleText.isEmpty ? (shot.string(for: titleKeys) ?? "") : titleText },
                            set: { titleText = $0 }
                        ), onCommit: {
                            shot.setString(titleText, for: titleKeys)
                            onCommit()
                        })
                        .textFieldStyle(CleanTextFieldStyle())
                        .frame(maxWidth: 280)
                        
                        Spacer()
                        
                        // Quick metadata tags with refined styling
                        HStack(spacing: 8) {
                            CleanMetadataTag(label: "Type", value: typeText.isEmpty ? (shot.string(for: typeKeys) ?? "—") : typeText)
                                .onTapGesture { showTypeSheet = true }
                            CleanMetadataTag(label: "Cam", value: camText.isEmpty ? (shot.string(for: camKeys) ?? "—") : camText)
                                .onTapGesture { showCamSheet = true }
                            CleanMetadataTag(label: "Lens", value: lensText.isEmpty ? (shot.string(for: lensKeys) ?? "—") : lensText)
                                .onTapGesture { showLensSheet = true }
                            CleanMetadataTag(label: "Rig", value: rigText.isEmpty ? (shot.string(for: rigKeys) ?? "—") : rigText)
                                .onTapGesture { showRigSheet = true }

                            // Cast ID selector
                            CleanMetadataTag(label: "Cast", value: castIDText.isEmpty ? (shot.string(for: castIDKeys) ?? "—") : castIDText)
                                .onTapGesture { showCastIDSheet = true }

                            // Color picker button
                            ColorPickerTag(
                                color: colorText.isEmpty ? (shot.string(for: colorKeys) ?? "") : colorText
                            )
                            .onTapGesture { showColorSheet = true }
                        }
                        
                        // Time fields with refined styling
                        HStack(spacing: 10) {
                            CleanTimeField(
                                label: "Setup",
                                value: Binding(
                                    get: { setupText.isEmpty ? (shot.string(for: setupKeys) ?? "") : setupText },
                                    set: { setupText = $0 }
                                ),
                                onCommit: {
                                    shot.setString(setupText, for: setupKeys)
                                    onCommit()
                                }
                            )
                            CleanTimeField(
                                label: "Shoot",
                                value: Binding(
                                    get: { shootText.isEmpty ? (shot.string(for: shootKeys) ?? "") : shootText },
                                    set: { shootText = $0 }
                                ),
                                onCommit: {
                                    shot.setString(shootText, for: shootKeys)
                                    onCommit()
                                }
                            )
                        }
                        
                        // Actions with refined icons
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Description preview when not expanded
                    if !isExpanded && !descriptionText.isEmpty {
                        Text(descriptionText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
            
            // Expanded details with refined styling
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)

                    HStack(alignment: .top, spacing: 16) {
                        // Description field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            TextEditor(text: Binding(
                                get: { descriptionText.isEmpty ? (shot.string(for: descriptionKeys) ?? "") : descriptionText },
                                set: {
                                    descriptionText = $0
                                    shot.setString($0, for: descriptionKeys)
                                }
                            ))
                            .font(.system(size: 13))
                            .frame(minHeight: 100, maxHeight: 200)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .onChange(of: descriptionText) { _ in
                                onCommit()
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Lighting Notes field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Lighting Notes")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            TextEditor(text: Binding(
                                get: { lightingNotesText.isEmpty ? (shot.string(for: lightingNotesKeys) ?? "") : lightingNotesText },
                                set: {
                                    lightingNotesText = $0
                                    shot.setString($0, for: lightingNotesKeys)
                                }
                            ))
                            .font(.system(size: 13))
                            .frame(minHeight: 100, maxHeight: 200)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .onChange(of: lightingNotesText) { _ in
                                onCommit()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .padding(.top, -8)
                }
                .clipped()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    cardBorderColor,
                    lineWidth: !colorText.isEmpty ? 3 : (isSelected ? 2 : 1)
                )
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.1) : Color.black.opacity(0.02), radius: isSelected ? 6 : 2, y: isSelected ? 2 : 1)
        .scaleEffect(isHovered ? 1.005 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            titleText = shot.string(for: titleKeys) ?? ""
            descriptionText = shot.string(for: descriptionKeys) ?? ""
            typeText = shot.string(for: typeKeys) ?? ""
            camText = shot.string(for: camKeys) ?? ""
            lensText = shot.string(for: lensKeys) ?? ""
            rigText = shot.string(for: rigKeys) ?? ""
            setupText = shot.string(for: setupKeys) ?? ""
            shootText = shot.string(for: shootKeys) ?? ""
            prodNotesText = shot.string(for: productionNotesKeys) ?? ""
            screenRefText = shot.string(for: screenRefKeys) ?? ""
            lightingNotesText = shot.string(for: lightingNotesKeys) ?? ""
            castIDText = shot.string(for: castIDKeys) ?? ""
            colorText = shot.string(for: colorKeys) ?? ""
        }
        .sheet(isPresented: $showTypeSheet) {
            OptionPickerSheet(
                title: "Select Shot Type",
                options: typeOptions,
                selected: typeText,
                onSelect: { typeText = $0; shot.setString($0, for: typeKeys); onCommit() }
            )
        }
        .sheet(isPresented: $showCamSheet) {
            OptionPickerSheet(
                title: "Select Camera",
                options: camOptions,
                selected: camText,
                onSelect: { camText = $0; shot.setString($0, for: camKeys); onCommit() }
            )
        }
        .sheet(isPresented: $showLensSheet) {
            OptionPickerSheet(
                title: "Select Lens",
                options: lensOptions,
                selected: lensText,
                onSelect: { lensText = $0; shot.setString($0, for: lensKeys); onCommit() }
            )
        }
        .sheet(isPresented: $showRigSheet) {
            OptionPickerSheet(
                title: "Select Rig",
                options: rigOptions,
                selected: rigText,
                onSelect: { rigText = $0; shot.setString($0, for: rigKeys); onCommit() }
            )
        }
        .sheet(isPresented: $showColorSheet) {
            ColorPickerSheet(
                selectedColor: colorText.isEmpty ? (shot.string(for: colorKeys) ?? "") : colorText,
                onSelect: { colorText = $0; shot.setString($0, for: colorKeys); onCommit() }
            )
        }
        .sheet(isPresented: $showCastIDSheet) {
            CastIDPickerSheet(
                availableCastIDs: availableCastIDs,
                selected: castIDText.isEmpty ? (shot.string(for: castIDKeys) ?? "") : castIDText,
                onSelect: { castIDText = $0; shot.setString($0, for: castIDKeys); onCommit() }
            )
        }
    }
    
    private struct CleanMetadataTag: View {
        let label: String
        let value: String

        var body: some View {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
    }
    
    private struct CleanTimeField: View {
        let label: String
        @Binding var value: String
        var onCommit: (() -> Void)? = nil

        var body: some View {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                TextField("0", text: $value, onCommit: {
                    onCommit?()
                })
                    .textFieldStyle(CleanTextFieldStyle())
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private struct CleanTextFieldStyle: TextFieldStyle {
        func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
    
    private struct OptionPickerSheet: View {
        let title: String
        let options: [String]
        let selected: String
        let onSelect: (String) -> Void
        @Environment(\.dismiss) var dismiss
        @State private var customText = ""
        @State private var showCustomField = false
        @FocusState private var isCustomFieldFocused: Bool

        // Filter out "Custom" from displayed options since we handle it specially
        private var displayOptions: [String] {
            options.filter { $0 != "Custom" }
        }

        private var hasCustomOption: Bool {
            options.contains("Custom")
        }

        var body: some View {
            VStack(spacing: 20) {
                Text(title)
                    .font(.title3.weight(.semibold))

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        ForEach(displayOptions, id: \.self) { option in
                            Button(action: {
                                onSelect(option)
                                dismiss()
                            }) {
                                Text(option)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selected == option ? Color.accentColor : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(selected == option ? .white : .primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                selected == option ? Color.clear : Color.primary.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        // Custom button that activates the text field
                        if hasCustomOption {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCustomField = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isCustomFieldFocused = true
                                }
                            }) {
                                Text("Custom")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(showCustomField ? Color.accentColor : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(showCustomField ? .white : .primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                showCustomField ? Color.clear : Color.primary.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 300)

                // Custom value input section
                if showCustomField || !hasCustomOption {
                    VStack(alignment: .leading, spacing: 8) {
                        if showCustomField {
                            Text("Enter custom value:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField("Custom value", text: $customText)
                                .textFieldStyle(.roundedBorder)
                                .focused($isCustomFieldFocused)
                                .onSubmit {
                                    if !customText.isEmpty {
                                        onSelect(customText)
                                        dismiss()
                                    }
                                }

                            Button("Add") {
                                guard !customText.isEmpty else { return }
                                onSelect(customText)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(customText.isEmpty)
                        }
                    }
                    .padding(.top, showCustomField ? 8 : 0)
                }

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
            .padding(24)
            .frame(width: 500, height: showCustomField ? 480 : 420)
            .animation(.easeInOut(duration: 0.2), value: showCustomField)
        }
    }

    private struct CastIDPickerSheet: View {
        let availableCastIDs: [String]
        let selected: String
        let onSelect: (String) -> Void
        @Environment(\.dismiss) var dismiss
        @State private var customText = ""

        var body: some View {
            VStack(spacing: 20) {
                Text("Select Cast ID")
                    .font(.title3.weight(.semibold))

                if availableCastIDs.isEmpty {
                    Text("No cast members in this scene")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                            // "None" option to clear selection
                            Button(action: {
                                onSelect("")
                                dismiss()
                            }) {
                                Text("—")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selected.isEmpty ? Color.accentColor : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(selected.isEmpty ? .white : .primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                selected.isEmpty ? Color.clear : Color.primary.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)

                            ForEach(availableCastIDs, id: \.self) { castID in
                                Button(action: {
                                    onSelect(castID)
                                    dismiss()
                                }) {
                                    Text(castID)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(selected == castID ? Color.accentColor : Color.primary.opacity(0.06))
                                        )
                                        .foregroundStyle(selected == castID ? .white : .primary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(
                                                    selected == castID ? Color.clear : Color.primary.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }

                HStack {
                    TextField("Custom ID", text: $customText)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        guard !customText.isEmpty else { return }
                        onSelect(customText)
                        dismiss()
                    }
                    .disabled(customText.isEmpty)
                }

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
    }

    private struct ColorPickerTag: View {
        let color: String

        var body: some View {
            Circle()
                .fill(color.isEmpty ? Color.gray.opacity(0.3) : colorForName(color))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1.5)
                )
                .contentShape(Circle())
        }

        private func colorForName(_ name: String) -> Color {
            switch name.lowercased() {
            case "red": return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green": return .green
            case "blue": return .blue
            case "purple": return .purple
            case "pink": return .pink
            case "gray": return .gray
            default: return .gray.opacity(0.3)
            }
        }
    }

    private struct ColorPickerSheet: View {
        let selectedColor: String
        let onSelect: (String) -> Void
        @Environment(\.dismiss) var dismiss

        private let colors = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Gray"]

        var body: some View {
            VStack(spacing: 20) {
                Text("Select Color")
                    .font(.title3.weight(.semibold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(colors, id: \.self) { color in
                        Button(action: {
                            onSelect(color)
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(colorForName(color))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                selectedColor == color ? Color.accentColor : Color.primary.opacity(0.2),
                                                lineWidth: selectedColor == color ? 3 : 1
                                            )
                                    )
                                Text(color)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(selectedColor == color ? .primary : .secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Clear Color") {
                    onSelect("")
                    dismiss()
                }
                .foregroundStyle(.secondary)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(24)
            .frame(width: 400)
        }

        private func colorForName(_ name: String) -> Color {
            switch name.lowercased() {
            case "red": return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green": return .green
            case "blue": return .blue
            case "purple": return .purple
            case "pink": return .pink
            case "gray": return .gray
            default: return .gray
            }
        }
    }
}

// MARK: - Helper Functions
func preferredSceneEntityName(moc: NSManagedObjectContext) -> String? {
    guard let model = moc.persistentStoreCoordinator?.managedObjectModel else { return nil }
    if model.entitiesByName.keys.contains("SceneEntity") { return "SceneEntity" }
    if model.entitiesByName.keys.contains("StripEntity") { return "StripEntity" }
    return model.entities.first(where: { $0.name?.localizedCaseInsensitiveContains("scene") == true })?.name
}

func normalizeSceneOrdering(_ scenes: [NSManagedObject], in moc: NSManagedObjectContext) -> [NSManagedObject] {
    var changed = false
    for (i, scene) in scenes.enumerated() {
        let idx = i + 1
        let attrs = scene.entity.attributesByName
        if attrs.keys.contains("sortIndex") {
            let cur = (scene.value(forKey: "sortIndex") as? NSNumber)?.intValue
            if cur != idx { scene.setValue(idx, forKey: "sortIndex"); changed = true }
        } else if attrs.keys.contains("displayOrder") {
            let cur = (scene.value(forKey: "displayOrder") as? NSNumber)?.intValue
            if cur != idx { scene.setValue(idx, forKey: "displayOrder"); changed = true }
        }
        if attrs.keys.contains("number") {
            let raw = scene.value(forKey: "number") as? String
            let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let isDigits = !trimmed.isEmpty && trimmed.allSatisfy { $0.isNumber }
            if trimmed.isEmpty || isDigits {
                let next = String(idx)
                if trimmed != next { scene.setValue(next, forKey: "number"); changed = true }
            }
        }
    }
    if changed { try? moc.save() }
    return scenes
}

func firstString(_ obj: NSManagedObject, keys: [String]) -> String? {
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

func formatEighths(_ v: Int) -> String {
    guard v > 0 else { return "—" }
    let whole = v / 8
    let rem = v % 8
    if rem == 0 { return "\(whole)" }
    if whole == 0 { return "\(rem)/8" }
    return "\(whole) \(rem)/8"
}

// MARK: - Extensions
private extension NSManagedObject {
    var sceneSlug: String {
        if entity.propertiesByName.keys.contains("heading"),
           let h = value(forKey: "heading") as? String, !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return h
        }

        let locType = (value(forKey: "locationType") as? String)?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let locName = (value(forKey: "scriptLocation") as? String)?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let tod = (value(forKey: "timeOfDay") as? String)?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if let lt = locType, !lt.isEmpty { parts.append(lt.hasSuffix(".") ? lt : lt + ".") }

        // Remove leading period from location name to avoid double periods like "INT. . SCENE"
        if let locName, !locName.isEmpty {
            var cleanedName = locName
            if cleanedName.hasPrefix(".") {
                cleanedName = String(cleanedName.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !cleanedName.isEmpty {
                parts.append(cleanedName)
            }
        }

        let left = parts.isEmpty ? nil : parts.joined(separator: " ")
        if let left, let tod, !tod.isEmpty { return left + " — " + tod }
        if let left { return left }

        return "Untitled Scene"
    }
    
    var pageEighthsString: String? {
        let keys = ["pageEighths", "pagesEighths", "scriptPages"]
        for k in keys where entity.propertiesByName[k] != nil {
            if let n = value(forKey: k) as? NSNumber { return formatEighths(n.intValue) }
            if let s = value(forKey: k) as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if let v = Int(t) { return formatEighths(v) }
                if !t.isEmpty { return t }
            }
        }
        return nil
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

// MARK: - Shot View Types
enum ShotView {
    case shots
    case storyboard
    case topDown
}

struct ViewSwitcherButton: View {
    let view: ShotView
    @Binding var selectedView: ShotView
    let icon: String
    let title: String
    var accentColor: Color = .accentColor
    var textColor: Color = .primary

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedView = view
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selectedView == view ? accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(selectedView == view ? accentColor : textColor.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Canvas Supporting Types
enum DrawingTool: String {
    case select
    case rectangle
    case circle
    case triangle
    case line
    case arrow
    case text
    case camera
    case lighting
    case actor

    func toShapeType() -> ShapeType {
        switch self {
        case .rectangle: return .rectangle
        case .circle: return .circle
        case .triangle: return .triangle
        case .line: return .line
        case .arrow: return .arrow
        case .text: return .text
        case .camera: return .camera
        case .lighting: return .lighting
        case .actor: return .actor
        default: return .rectangle
        }
    }
}

enum ShapeType: Codable {
    case rectangle
    case circle
    case triangle
    case line
    case arrow
    case text
    case camera
    case lighting
    case actor
}

enum ResizeHandle {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct CanvasShape: Identifiable {
    var id = UUID()
    var type: ShapeType
    var position: CGPoint
    var size: CGSize
    var color: Color
    var text: String = ""
    var name: String = ""
    var attachedShotID: NSManagedObjectID? = nil

    init(type: ShapeType, position: CGPoint, size: CGSize, color: Color, text: String = "", name: String = "") {
        self.type = type
        self.position = position
        self.size = size
        self.color = color
        self.text = text
        self.name = name.isEmpty ? type.defaultName : name
    }
}

extension ShapeType {
    var defaultName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .triangle: return "Triangle"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .text: return "Text"
        case .camera: return "Camera"
        case .lighting: return "Light"
        case .actor: return "Actor"
        }
    }

    var icon: String {
        switch self {
        case .rectangle: return "square"
        case .circle: return "circle"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .text: return "textformat"
        case .camera: return "camera.fill"
        case .lighting: return "light.max"
        case .actor: return "person.fill"
        }
    }
}

// MARK: - Canvas Views
struct DottedGridView: View {
    let spacing: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let rows = Int(geometry.size.height / spacing)
            let cols = Int(geometry.size.width / spacing)

            Canvas { context, size in
                for row in 0...rows {
                    for col in 0...cols {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.gray.opacity(0.3)))
                    }
                }
            }
        }
    }
}

struct ShapeView: View {
    let shape: CanvasShape
    let isSelected: Bool

    var body: some View {
        Group {
            switch shape.type {
            case .rectangle:
                Rectangle()
                    .fill(shape.color.opacity(0.3))
                    .overlay(Rectangle().stroke(shape.color, lineWidth: 2))
            case .circle:
                Circle()
                    .fill(shape.color.opacity(0.3))
                    .overlay(Circle().stroke(shape.color, lineWidth: 2))
            case .triangle:
                Triangle()
                    .fill(shape.color.opacity(0.3))
                    .overlay(Triangle().stroke(shape.color, lineWidth: 2))
            case .line:
                Path { path in
                    path.move(to: CGPoint(x: 0, y: shape.size.height / 2))
                    path.addLine(to: CGPoint(x: shape.size.width, y: shape.size.height / 2))
                }
                .stroke(shape.color, lineWidth: 3)
            case .arrow:
                ArrowShape()
                    .stroke(shape.color, lineWidth: 3)
            case .text:
                Text(shape.text)
                    .font(.system(size: 16))
                    .foregroundColor(shape.color)
            case .camera:
                CameraShapeView()
                    .foregroundStyle(shape.color)
            case .lighting:
                LightingShapeView()
                    .foregroundStyle(shape.color)
            case .actor:
                ActorShapeView()
                    .foregroundStyle(shape.color)
            }
        }
        .frame(width: shape.size.width, height: shape.size.height)
        .position(shape.position)
        .overlay(
            isSelected ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: shape.size.width + 8, height: shape.size.height + 8)
                    .position(shape.position)
                : nil
        )
    }
}

// MARK: - Production Shape Views
struct CameraShapeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera body
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary, lineWidth: 2))

                // Lens
                Circle()
                    .fill(Color.primary.opacity(0.3))
                    .overlay(Circle().stroke(Color.primary, lineWidth: 2))
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)

                // Camera icon overlay
                Image(systemName: "camera.fill")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3))
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct LightingShapeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Light rays
                ForEach(0..<8) { i in
                    Rectangle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 2, height: geometry.size.height * 0.4)
                        .offset(y: -geometry.size.height * 0.2)
                        .rotationEffect(.degrees(Double(i) * 45))
                }

                // Light source
                Circle()
                    .fill(Color.yellow)
                    .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)

                // Light icon
                Image(systemName: "light.max")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.25))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct ActorShapeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Body circle
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .overlay(Circle().stroke(Color.purple, lineWidth: 2))

                // Person icon
                Image(systemName: "person.fill")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.5))
                    .foregroundStyle(.purple)
            }
        }
    }
}

// MARK: - Resizable Shape View with Handles
struct ResizableShapeView: View {
    @Binding var shape: CanvasShape
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (CGSize) -> Void
    let onResize: (ResizeHandle, CGSize) -> Void

    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // Main shape
            ShapeView(shape: shape, isSelected: false)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                onSelect()
                            }
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            onMove(value.translation)
                            isDragging = false
                            dragOffset = .zero
                        }
                )
                .offset(dragOffset)

            // Resize handles (only when selected)
            if isSelected {
                resizeHandles
            }
        }
    }

    private var resizeHandles: some View {
        Group {
            // Top-left handle
            ResizeHandleView(handle: .topLeft, shape: shape, onResize: onResize)
            // Top-right handle
            ResizeHandleView(handle: .topRight, shape: shape, onResize: onResize)
            // Bottom-left handle
            ResizeHandleView(handle: .bottomLeft, shape: shape, onResize: onResize)
            // Bottom-right handle
            ResizeHandleView(handle: .bottomRight, shape: shape, onResize: onResize)
        }
    }
}

struct ResizeHandleView: View {
    let handle: ResizeHandle
    let shape: CanvasShape
    let onResize: (ResizeHandle, CGSize) -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .frame(width: 12, height: 12)
            .position(handlePosition)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        onResize(handle, value.translation)
                        dragOffset = .zero
                    }
            )
            .offset(dragOffset)
    }

    private var handlePosition: CGPoint {
        let halfWidth = shape.size.width / 2
        let halfHeight = shape.size.height / 2

        switch handle {
        case .topLeft:
            return CGPoint(
                x: shape.position.x - halfWidth,
                y: shape.position.y - halfHeight
            )
        case .topRight:
            return CGPoint(
                x: shape.position.x + halfWidth,
                y: shape.position.y - halfHeight
            )
        case .bottomLeft:
            return CGPoint(
                x: shape.position.x - halfWidth,
                y: shape.position.y + halfHeight
            )
        case .bottomRight:
            return CGPoint(
                x: shape.position.x + halfWidth,
                y: shape.position.y + halfHeight
            )
        }
    }
}

// MARK: - Layer Row (Photoshop-style)
struct LayerRow: View {
    let shape: CanvasShape
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Shape icon
            Image(systemName: shape.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(shape.color)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shape.color.opacity(0.15))
                )

            // Layer name
            VStack(alignment: .leading, spacing: 2) {
                Text(shape.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(shape.type.defaultName)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Action buttons (visible on hover or when selected)
            if isHovered || isSelected {
                HStack(spacing: 4) {
                    Button(action: onDuplicate) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Duplicate")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arrowHeadSize: CGFloat = 15

        // Line
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - arrowHeadSize, y: rect.midY))

        // Arrow head
        path.addLine(to: CGPoint(x: rect.maxX - arrowHeadSize, y: rect.midY - arrowHeadSize / 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - arrowHeadSize, y: rect.midY + arrowHeadSize / 2))

        return path
    }
}

struct ToolButton: View {
    let tool: DrawingTool
    @Binding var selectedTool: DrawingTool
    let icon: String
    let title: String

    var body: some View {
        Button(action: {
            selectedTool = tool
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 10))
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(selectedTool == tool ? Color.accentColor : Color.secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        selectedTool == tool ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var theme: AppAppearance.Theme = .standard
    var textColor: Color = .primary
    var secondaryTextColor: Color = .secondary

    private var badgeBg: Color {
        switch theme {
        case .standard:
            return color.opacity(0.06)
        case .aqua:
            return color.opacity(0.12)
        case .neon:
            return color.opacity(0.10)
        case .retro:
            return color.opacity(0.08)
        case .cinema:
            return Color(red: 0.110, green: 0.133, blue: 0.157)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.20), color.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(textColor)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(badgeBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - ManagedObjectContext Extension
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

// MARK: - WebView Wrapper
#if os(macOS)
struct WebView: NSViewRepresentable {
    @Binding var url: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Enable drag operations from web view
        webView.allowsMagnification = true

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: url) else { return }

        // Only load if no page loaded yet or if the host/path changed significantly
        // This prevents reloading during form submissions
        if webView.url == nil {
            let request = URLRequest(url: url)
            webView.load(request)
        } else if let currentURL = webView.url,
                  currentURL.host != url.host {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Update the URL binding when navigation finishes
            if let currentURL = webView.url?.absoluteString {
                DispatchQueue.main.async {
                    self.parent.url = currentURL
                }
            }
        }

        // Handle JavaScript window.open() and target="_blank" links
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Load the request in the same webview instead of opening a new window
            if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == false {
                if let url = navigationAction.request.url {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }

        // Allow all navigation decisions
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
#else
// MARK: - WebView Wrapper (iOS)
import UIKit

struct WebView: UIViewRepresentable {
    @Binding var url: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let targetURL = URL(string: url) else { return }

        // Only load if no page loaded yet or if the host changed
        if uiView.url == nil {
            let request = URLRequest(url: targetURL)
            uiView.load(request)
        } else if let currentURL = uiView.url,
                  currentURL.host != targetURL.host {
            let request = URLRequest(url: targetURL)
            uiView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Update the URL binding when navigation finishes
            if let currentURL = webView.url?.absoluteString {
                DispatchQueue.main.async {
                    self.parent.url = currentURL
                }
            }
        }

        // Handle JavaScript window.open() and target="_blank" links
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Load the request in the same webview instead of opening a new window
            if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == false {
                if let url = navigationAction.request.url {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }

        // Allow all navigation decisions
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
#endif
