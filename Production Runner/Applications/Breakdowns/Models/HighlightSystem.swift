//
//  HighlightSystem.swift
//  Production Runner
//
//  Stable highlight system using standard text selection + explicit tagging
//

import Foundation
import SwiftUI
import Combine
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Production Element Type

/// Represents the different types of production elements that can be highlighted in scripts
enum ProductionElementType: String, CaseIterable, Identifiable, Codable {
    case cast = "Cast"
    case stunts = "Stunts"
    case extras = "Extras"
    case props = "Props"
    case wardrobe = "Wardrobe"
    case makeupHair = "Makeup/Hair"
    case setDressing = "Set Dressing"
    case specialEffects = "Special Effects"
    case visualEffects = "Visual Effects"
    case animals = "Animals"
    case vehicles = "Vehicles"
    case specialEquipment = "Special Equipment"
    case sound = "Sound"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cast: return "person.2.fill"
        case .stunts: return "figure.run"
        case .extras: return "person.3.fill"
        case .props: return "cube.fill"
        case .wardrobe: return "tshirt.fill"
        case .makeupHair: return "sparkles"
        case .setDressing: return "sofa.fill"
        case .specialEffects: return "flame.fill"
        case .visualEffects: return "wand.and.stars"
        case .animals: return "pawprint.fill"
        case .vehicles: return "car.fill"
        case .specialEquipment: return "case.fill"
        case .sound: return "waveform"
        }
    }

    var color: Color {
        switch self {
        case .cast: return .blue
        case .stunts: return .orange
        case .extras: return .mint
        case .props: return .purple
        case .wardrobe: return .pink
        case .makeupHair: return .green
        case .setDressing: return .brown
        case .specialEffects: return .red
        case .visualEffects: return .cyan
        case .animals: return .yellow
        case .vehicles: return .teal
        case .specialEquipment: return .indigo
        case .sound: return .gray
        }
    }

    #if canImport(AppKit)
    var nsColor: NSColor {
        switch self {
        case .cast: return .systemBlue
        case .stunts: return .systemOrange
        case .extras: return .systemMint
        case .props: return .systemPurple
        case .wardrobe: return .systemPink
        case .makeupHair: return .systemGreen
        case .setDressing: return .brown
        case .specialEffects: return .systemRed
        case .visualEffects: return .systemTeal
        case .animals: return .systemYellow
        case .vehicles: return .cyan
        case .specialEquipment: return .systemIndigo
        case .sound: return .systemGray
        }
    }
    #endif

    #if os(iOS)
    var uiColor: UIColor {
        switch self {
        case .cast: return .systemBlue
        case .stunts: return .systemOrange
        case .extras: return .systemMint
        case .props: return .systemPurple
        case .wardrobe: return .systemPink
        case .makeupHair: return .systemGreen
        case .setDressing: return .brown
        case .specialEffects: return .systemRed
        case .visualEffects: return .systemTeal
        case .animals: return .systemYellow
        case .vehicles: return .cyan
        case .specialEquipment: return .systemIndigo
        case .sound: return .systemGray
        }
    }
    #endif
}

// MARK: - Script Highlight Model

/// Represents a highlighted text in the script tagged as a production element
struct ScriptHighlight: Identifiable, Codable, Equatable {
    let id: UUID
    let sceneID: String
    let elementType: ProductionElementType
    let highlightedText: String
    let dateCreated: Date

    init(id: UUID = UUID(), sceneID: String, elementType: ProductionElementType, highlightedText: String) {
        self.id = id
        self.sceneID = sceneID
        self.elementType = elementType
        self.highlightedText = highlightedText
        self.dateCreated = Date()
    }
}

// MARK: - Highlight Manager (Singleton)

/// Singleton manager for script highlights - avoids reference issues with SwiftUI views
final class HighlightManager: ObservableObject {
    static let shared = HighlightManager()

    @Published var highlights: [ScriptHighlight] = []
    @Published var selectedElementType: ProductionElementType? = nil
    @Published var currentSelection: String = ""
    @Published var currentSceneID: String = ""

    /// Callback when a new element is highlighted - set by Breakdowns view
    var onElementHighlighted: ((ProductionElementType, String, String) -> Void)?

    private let userDefaultsKey = "scriptHighlights_v2"

    private init() {
        loadHighlights()
    }

    // MARK: - Persistence

    func loadHighlights() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([ScriptHighlight].self, from: data) else {
            return
        }
        highlights = decoded
    }

    func saveHighlights() {
        guard let encoded = try? JSONEncoder().encode(highlights) else { return }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }

    // MARK: - Selection Management

    func setSelection(_ text: String, sceneID: String) {
        // Dispatch to avoid publishing changes during view updates
        DispatchQueue.main.async { [weak self] in
            self?.currentSelection = text.trimmingCharacters(in: .whitespacesAndNewlines)
            self?.currentSceneID = sceneID
        }
    }

    func clearSelection() {
        // Dispatch to avoid publishing changes during view updates
        DispatchQueue.main.async { [weak self] in
            self?.currentSelection = ""
        }
    }

    var hasSelection: Bool {
        !currentSelection.isEmpty && selectedElementType != nil
    }

    // MARK: - Auto-Tag (called directly when user selects text with element type active)

    func autoTag(text: String, sceneID: String) {
        guard let elementType = selectedElementType else {
            print("⚠️ Cannot auto-tag: no element type selected")
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let highlight = ScriptHighlight(
            sceneID: sceneID,
            elementType: elementType,
            highlightedText: trimmedText
        )

        highlights.append(highlight)
        saveHighlights()

        print("✅ Auto-tagged '\(trimmedText)' as \(elementType.rawValue)")

        // Notify Breakdowns to add to Core Data
        onElementHighlighted?(elementType, trimmedText, sceneID)
    }

    // MARK: - Tag Current Selection (legacy - for manual tag button)

    func tagCurrentSelection() {
        guard !currentSelection.isEmpty,
              !currentSceneID.isEmpty,
              let elementType = selectedElementType else {
            print("⚠️ Cannot tag: missing selection, sceneID, or element type")
            return
        }

        let highlight = ScriptHighlight(
            sceneID: currentSceneID,
            elementType: elementType,
            highlightedText: currentSelection
        )

        highlights.append(highlight)
        saveHighlights()

        print("✅ Tagged '\(currentSelection)' as \(elementType.rawValue)")

        // Notify Breakdowns to add to Core Data
        onElementHighlighted?(elementType, currentSelection, currentSceneID)

        // Clear selection after tagging
        currentSelection = ""
    }

    // MARK: - CRUD

    func removeHighlight(_ highlight: ScriptHighlight) {
        highlights.removeAll { $0.id == highlight.id }
        saveHighlights()
    }

    func highlightsForScene(_ sceneID: String) -> [ScriptHighlight] {
        highlights.filter { $0.sceneID == sceneID }
    }

    func clearHighlightsForScene(_ sceneID: String) {
        highlights.removeAll { $0.sceneID == sceneID }
        saveHighlights()
    }
}

// MARK: - Highlight Toolbar View

struct HighlightToolbar: View {
    @ObservedObject var manager = HighlightManager.shared
    let sceneID: String

    var body: some View {
        // Element Type Picker - fixed size, no compression
        Menu {
            ForEach(ProductionElementType.allCases) { type in
                Button(action: { manager.selectedElementType = type }) {
                    Label(type.rawValue, systemImage: type.icon)
                }
            }

            if manager.selectedElementType != nil {
                Divider()
                Button("Stop Highlighting", role: .destructive) {
                    manager.selectedElementType = nil
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let selected = manager.selectedElementType {
                    Image(systemName: selected.icon)
                        .foregroundColor(selected.color)
                    Text(selected.rawValue)
                        .foregroundColor(selected.color)
                } else {
                    Image(systemName: "highlighter")
                    Text("Highlight Element")
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(manager.selectedElementType != nil
                          ? manager.selectedElementType!.color.opacity(0.1)
                          : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(manager.selectedElementType?.color.opacity(0.3) ?? Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onAppear {
            manager.currentSceneID = sceneID
        }
    }
}

// MARK: - Selectable Script Text View (macOS)

#if canImport(AppKit)
/// NSViewRepresentable that properly tracks text selection
struct SelectableScriptView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let sceneID: String
    @ObservedObject var manager = HighlightManager.shared

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 10, height: 10)

        // Apply highlighted text with colors
        let highlightedText = applyHighlightColors(to: attributedText)
        textView.textStorage?.setAttributedString(highlightedText)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Update coordinator's sceneID when it changes
        context.coordinator.sceneID = sceneID

        // Only update text if content changed
        let highlightedText = applyHighlightColors(to: attributedText)
        if textView.textStorage?.string != highlightedText.string {
            textView.textStorage?.setAttributedString(highlightedText)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneID: sceneID)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var sceneID: String

        init(sceneID: String) {
            self.sceneID = sceneID
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let range = textView.selectedRange()
            if range.length > 0, let storage = textView.textStorage {
                let selectedText = storage.attributedSubstring(from: range).string
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !selectedText.isEmpty {
                    HighlightManager.shared.setSelection(selectedText, sceneID: sceneID)
                }
            } else {
                HighlightManager.shared.clearSelection()
            }
        }
    }

    private func applyHighlightColors(to text: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let fullText = mutable.string
        let highlights = manager.highlightsForScene(sceneID)

        for highlight in highlights {
            var searchStart = fullText.startIndex
            while let range = fullText.range(of: highlight.highlightedText,
                                              options: .caseInsensitive,
                                              range: searchStart..<fullText.endIndex) {
                let nsRange = NSRange(range, in: fullText)
                mutable.addAttribute(.backgroundColor,
                                    value: highlight.elementType.nsColor.withAlphaComponent(0.3),
                                    range: nsRange)
                searchStart = range.upperBound
            }
        }

        return mutable
    }
}
#endif

// MARK: - Selectable Script Text View (iOS)

#if os(iOS)
/// UIViewRepresentable that properly tracks text selection on iOS
struct SelectableScriptView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let sceneID: String
    @ObservedObject var manager = HighlightManager.shared

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.showsVerticalScrollIndicator = true

        // Apply highlighted text with colors
        let highlightedText = applyHighlightColors(to: attributedText)
        textView.attributedText = highlightedText

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update coordinator's sceneID when it changes
        context.coordinator.sceneID = sceneID

        // Only update text if content changed
        let highlightedText = applyHighlightColors(to: attributedText)
        if uiView.attributedText?.string != highlightedText.string {
            uiView.attributedText = highlightedText
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneID: sceneID)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var sceneID: String

        init(sceneID: String) {
            self.sceneID = sceneID
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let selectedRange = textView.selectedTextRange,
               !selectedRange.isEmpty {
                let selectedText = textView.text(in: selectedRange)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !selectedText.isEmpty {
                    HighlightManager.shared.setSelection(selectedText, sceneID: sceneID)
                }
            } else {
                HighlightManager.shared.clearSelection()
            }
        }
    }

    private func applyHighlightColors(to text: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let fullText = mutable.string
        let highlights = manager.highlightsForScene(sceneID)

        for highlight in highlights {
            var searchStart = fullText.startIndex
            while let range = fullText.range(of: highlight.highlightedText,
                                              options: .caseInsensitive,
                                              range: searchStart..<fullText.endIndex) {
                let nsRange = NSRange(range, in: fullText)
                mutable.addAttribute(.backgroundColor,
                                    value: highlight.elementType.uiColor.withAlphaComponent(0.3),
                                    range: nsRange)
                searchStart = range.upperBound
            }
        }

        return mutable
    }
}
#endif

// MARK: - Highlighted Elements Summary

struct HighlightedElementsSummary: View {
    @ObservedObject var manager = HighlightManager.shared
    let sceneID: String

    private var sceneHighlights: [ScriptHighlight] {
        manager.highlightsForScene(sceneID)
    }

    private var groupedHighlights: [ProductionElementType: [ScriptHighlight]] {
        Dictionary(grouping: sceneHighlights) { $0.elementType }
    }

    var body: some View {
        if !sceneHighlights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tagged Elements")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(ProductionElementType.allCases) { type in
                    if let highlights = groupedHighlights[type], !highlights.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(type.rawValue, systemImage: type.icon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(type.color)

                            HighlightFlowLayout(spacing: 4) {
                                ForEach(highlights) { highlight in
                                    TagBadge(text: highlight.highlightedText, color: type.color) {
                                        manager.removeHighlight(highlight)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
        }
    }
}

// MARK: - Tag Badge

struct TagBadge: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 10))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)))
    }
}

// MARK: - Highlight Flow Layout

struct HighlightFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(in: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func computeLayout(in maxWidth: CGFloat, subviews: Subviews) -> (positions: [CGPoint], width: CGFloat, height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, maxX, y + rowHeight)
    }
}
