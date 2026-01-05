//
//  ScriptSyncPreference.swift
//  Production Runner
//
//  Model and storage for script auto-sync preferences.
//  Tracks whether scripts should automatically sync to Breakdowns and other apps.
//

import Foundation
import SwiftUI

// MARK: - Script Sync Mode

/// The user's preference for how scripts sync to other Production Runner apps
enum ScriptSyncMode: String, Codable, CaseIterable {
    case autoSync = "auto"      // Automatically sync to all apps
    case manual = "manual"      // User manually loads script in each app

    var displayName: String {
        switch self {
        case .autoSync: return "Auto-Sync"
        case .manual: return "Manual"
        }
    }

    var description: String {
        switch self {
        case .autoSync:
            return "Your script will automatically sync to Breakdowns, Scheduler, and other apps in Production Runner."
        case .manual:
            return "You'll manually load the script in each app when you're ready."
        }
    }

    var icon: String {
        switch self {
        case .autoSync: return "arrow.triangle.2.circlepath"
        case .manual: return "hand.tap"
        }
    }
}

// MARK: - Script Sync Preference

/// Stores the sync preference for a specific screenplay draft
struct ScriptSyncPreference: Codable, Identifiable {
    let id: UUID                    // The screenplay draft ID
    var syncMode: ScriptSyncMode
    var createdAt: Date
    var updatedAt: Date

    init(draftId: UUID, syncMode: ScriptSyncMode) {
        self.id = draftId
        self.syncMode = syncMode
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Script Sync Preference Manager

/// Manages script sync preferences across all drafts
@MainActor
final class ScriptSyncPreferenceManager: ObservableObject {
    static let shared = ScriptSyncPreferenceManager()

    /// Key for storing preferences in UserDefaults
    private let storageKey = "scriptSyncPreferences"

    /// All stored preferences
    @Published private(set) var preferences: [UUID: ScriptSyncPreference] = [:]

    /// Default sync mode for new scripts (can be set by user in settings)
    @AppStorage("defaultScriptSyncMode") var defaultSyncMode: String = ScriptSyncMode.autoSync.rawValue

    /// Whether to ask the user for their preference on each new script
    /// If false, uses defaultSyncMode automatically
    @AppStorage("askScriptSyncPreference") var askOnNewScript: Bool = true

    private init() {
        loadPreferences()
    }

    // MARK: - Public API

    /// Get the sync mode for a specific draft
    func syncMode(for draftId: UUID) -> ScriptSyncMode {
        preferences[draftId]?.syncMode ?? ScriptSyncMode(rawValue: defaultSyncMode) ?? .autoSync
    }

    /// Check if auto-sync is enabled for a draft
    func isAutoSyncEnabled(for draftId: UUID) -> Bool {
        syncMode(for: draftId) == .autoSync
    }

    /// Set the sync mode for a draft
    func setSyncMode(_ mode: ScriptSyncMode, for draftId: UUID) {
        if var existing = preferences[draftId] {
            existing.syncMode = mode
            existing.updatedAt = Date()
            preferences[draftId] = existing
        } else {
            preferences[draftId] = ScriptSyncPreference(draftId: draftId, syncMode: mode)
        }
        savePreferences()
        print("[ScriptSyncPreferenceManager] Set sync mode '\(mode.rawValue)' for draft \(draftId)")
    }

    /// Remove preference for a draft (when draft is deleted)
    func removePreference(for draftId: UUID) {
        preferences.removeValue(forKey: draftId)
        savePreferences()
    }

    /// Check if we have a preference stored for a draft
    func hasPreference(for draftId: UUID) -> Bool {
        preferences[draftId] != nil
    }

    /// Get the default sync mode
    var defaultMode: ScriptSyncMode {
        ScriptSyncMode(rawValue: defaultSyncMode) ?? .autoSync
    }

    // MARK: - Persistence

    private func loadPreferences() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        do {
            let decoded = try JSONDecoder().decode([ScriptSyncPreference].self, from: data)
            preferences = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
            print("[ScriptSyncPreferenceManager] Loaded \(preferences.count) sync preferences")
        } catch {
            print("[ScriptSyncPreferenceManager] ERROR: Failed to load preferences: \(error)")
        }
    }

    private func savePreferences() {
        do {
            let array = Array(preferences.values)
            let data = try JSONEncoder().encode(array)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[ScriptSyncPreferenceManager] ERROR: Failed to save preferences: \(error)")
        }
    }
}
