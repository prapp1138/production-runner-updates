//
//  DashboardDragDropTypes.swift
//  Production Runner
//
//  Drag & drop transfer types for dashboard app card reordering
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Dashboard App Card Drag Item

/// Transferable wrapper for dragging app cards to reorder them on the dashboard
struct AppCardDragItem: Codable, Transferable {
    let sectionRawValue: String

    init(section: AppSection) {
        self.sectionRawValue = section.rawValue
    }

    var section: AppSection? {
        AppSection(rawValue: sectionRawValue)
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .appCardDragItem)
    }
}

// MARK: - UTType Extension

extension UTType {
    static var appCardDragItem: UTType {
        UTType(exportedAs: "com.productionrunner.app-card-drag-item")
    }
}

// MARK: - Dashboard Order Manager

/// Manages the order of app cards on the dashboard with persistence
@MainActor
final class DashboardOrderManager: ObservableObject {
    @Published var orderedSections: [AppSection] = []

    private let storageKey = "dashboard_app_order"

    /// Default order matching the original hardcoded layout
    static let defaultOrder: [AppSection] = {
        var order: [AppSection] = [
        ]
        #if INCLUDE_CALENDAR
        order.append(.calendar)
        #endif
        order.append(contentsOf: [
            .contacts,
            .breakdowns
        ])
        #if INCLUDE_BUDGETING
        order.append(.budget)
        #endif
        order.append(.shotLister)
        #if INCLUDE_SCRIPTY
        order.append(.scripty)
        #endif
        order.append(contentsOf: [
            .locations,
            .scheduler,
            .callSheets,
            .tasks
        ])
        #if INCLUDE_CHAT
        order.append(.chat)
        #endif
        #if INCLUDE_PAPERWORK
        order.append(.paperwork)
        #endif
        #if INCLUDE_PLAN
        order.append(.plan)
        #endif
        return order
    }()

    init() {
        loadOrder()
    }

    func loadOrder() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let rawValues = try? JSONDecoder().decode([String].self, from: data) {
            let sections = rawValues.compactMap { AppSection(rawValue: $0) }
            // Merge with defaults to handle new apps added in updates
            orderedSections = mergeWithDefaults(saved: sections)
        } else {
            orderedSections = Self.defaultOrder
        }
    }

    func saveOrder() {
        let rawValues = orderedSections.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func resetToDefault() {
        orderedSections = Self.defaultOrder
        saveOrder()
    }

    /// Move a section from one position to another
    func move(from source: AppSection, to destination: AppSection) {
        guard let sourceIndex = orderedSections.firstIndex(of: source),
              let destIndex = orderedSections.firstIndex(of: destination),
              sourceIndex != destIndex else { return }

        orderedSections.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex
        )
        saveOrder()
    }

    /// Merge saved order with defaults to handle app updates that add new sections
    private func mergeWithDefaults(saved: [AppSection]) -> [AppSection] {
        var result = saved
        // Add any new sections from default that aren't in saved
        for section in Self.defaultOrder {
            if !result.contains(section) {
                result.append(section)
            }
        }
        // Remove any sections that no longer exist in defaults
        result = result.filter { Self.defaultOrder.contains($0) }
        return result
    }
}
