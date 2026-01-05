//
//  BreakdownModels.swift
//  Production Runner
//
//  Models, enums, and constants for the Breakdowns module.
//  Extracted from Breakdowns.swift for better organization.
//

import SwiftUI
import MapKit
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

// MARK: - Cast Member Model

struct BreakdownCastMember: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var castID: String
}

// MARK: - Design Constants

enum BreakdownsDesign {
    static let spacing: CGFloat = 20
    static let compactSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 14
    static let sectionSpacing: CGFloat = 20
    static let borderWidth: CGFloat = 0.5
}

// MARK: - Platform Color Abstraction

#if os(iOS)
typealias BreakdownsPlatformColor = UIColor
#elseif os(macOS)
typealias BreakdownsPlatformColor = NSColor
extension NSColor {
    static var systemBackground: NSColor { NSColor.windowBackgroundColor }
    static var secondarySystemBackground: NSColor { NSColor.underPageBackgroundColor }
    static var tertiarySystemBackground: NSColor { NSColor.controlBackgroundColor }
    static var systemGray6: NSColor { NSColor.controlBackgroundColor }
}
#endif

// MARK: - Breakdown Enums

enum LocationType: String, CaseIterable, Identifiable {
    case int = "INT."
    case ext = "EXT."

    var id: String { rawValue }
}

enum TimeOfDay: String, CaseIterable, Identifiable {
    case day = "DAY"
    case night = "NIGHT"
    case dawn = "DAWN"
    case dusk = "DUSK"

    var id: String { rawValue }
}

enum BreakdownTab: String, CaseIterable, Identifiable {
    case elements = "Elements"
    case reports = "Reports"

    var id: String { rawValue }
}

enum LocationSearchProvider: String, CaseIterable, Identifiable {
    case apple = "Apple"
    case google = "Google"

    var id: String { rawValue }
}

// MARK: - Location Suggestion

struct LocationSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

// MARK: - Apple Autocomplete Service

final class AppleAutocomplete: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [LocationSuggestion] = []

    private let completer: MKLocalSearchCompleter = {
        let c = MKLocalSearchCompleter()
        c.resultTypes = [.address, .pointOfInterest]
        return c
    }()

    override init() {
        super.init()
        completer.delegate = self
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.prefix(8).map {
            LocationSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let breakdownsSceneSynced = Notification.Name("breakdownsSceneSynced")
    static let breakdownsSceneOrderChanged = Notification.Name("breakdownsSceneOrderChanged")
    static let breakdownsCastTokenTapped = Notification.Name("breakdownsCastTokenTapped")
    static let breakdownsImportCompleted = Notification.Name("breakdownsImportCompleted")
}
