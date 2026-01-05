import EventKit
import SwiftUI

/// Service for syncing Production Runner calendar events to the system calendar (iOS/macOS).
/// Events synced here will automatically appear in Google Calendar, iCloud, Outlook, etc.
/// depending on which calendar accounts the user has configured on their device.
@MainActor
class EventKitService: ObservableObject {
    static let shared = EventKitService()

    private let eventStore = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIdentifier: String? {
        didSet {
            if let id = selectedCalendarIdentifier {
                UserDefaults.standard.set(id, forKey: "EventKitSelectedCalendarID")
            }
        }
    }
    @Published var lastSyncError: String?

    var isAuthorized: Bool {
        if #available(macOS 14.0, iOS 17.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .authorized
        } else {
            return authorizationStatus == .authorized
        }
    }

    private init() {
        // Load saved calendar selection
        selectedCalendarIdentifier = UserDefaults.standard.string(forKey: "EventKitSelectedCalendarID")
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    private func updateAuthorizationStatus() {
        if #available(iOS 17.0, macOS 14.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }

        if isAuthorized {
            loadCalendars()
        }
    }

    /// Request access to the user's calendar
    /// - Returns: true if access was granted
    func requestAccess() async -> Bool {
        print("[EventKitService] requestAccess() called")
        print("[EventKitService] Current authorization status: \(authorizationStatus.rawValue)")

        do {
            var granted: Bool
            if #available(iOS 17.0, macOS 14.0, *) {
                print("[EventKitService] Requesting full access (macOS 14+/iOS 17+)")
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                print("[EventKitService] Requesting legacy access")
                granted = try await eventStore.requestAccess(to: .event)
            }

            print("[EventKitService] Access granted: \(granted)")
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return granted
        } catch {
            print("[EventKitService] Error requesting access: \(error)")
            lastSyncError = "Calendar access error: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Calendar Management

    /// Load available calendars that support events
    func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }

        // Auto-select default calendar if none selected
        if selectedCalendarIdentifier == nil {
            selectedCalendarIdentifier = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        }

        // Verify selected calendar still exists
        if let selectedID = selectedCalendarIdentifier,
           !availableCalendars.contains(where: { $0.calendarIdentifier == selectedID }) {
            selectedCalendarIdentifier = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        }
    }

    /// Get the currently selected calendar
    var selectedCalendar: EKCalendar? {
        guard let id = selectedCalendarIdentifier else {
            return eventStore.defaultCalendarForNewEvents
        }
        return availableCalendars.first { $0.calendarIdentifier == id }
    }

    // MARK: - Event Sync Operations

    /// Push a ProductionEvent to the system calendar
    /// - Parameter event: The production event to sync
    /// - Returns: The EventKit event identifier (store this for updates/deletes)
    func pushEvent(_ event: ProductionEvent) async throws -> String {
        guard isAuthorized else {
            throw EventKitError.notAuthorized
        }

        guard let calendar = selectedCalendar else {
            throw EventKitError.noCalendarSelected
        }

        let ekEvent = mapToEKEvent(event, calendar: calendar)

        try eventStore.save(ekEvent, span: .thisEvent)

        return ekEvent.eventIdentifier
    }

    /// Update an existing event in the system calendar
    /// - Parameters:
    ///   - event: The updated production event
    ///   - ekEventId: The EventKit event identifier from the original push
    func updateEvent(_ event: ProductionEvent, ekEventId: String) async throws {
        guard isAuthorized else {
            throw EventKitError.notAuthorized
        }

        guard let ekEvent = eventStore.event(withIdentifier: ekEventId) else {
            // Event was deleted from system calendar - create new one
            _ = try await pushEvent(event)
            return
        }

        // Update fields
        ekEvent.title = formatEventTitle(event)
        ekEvent.startDate = event.date
        ekEvent.endDate = event.endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: event.date)
        ekEvent.location = event.location
        ekEvent.notes = formatEventNotes(event)

        try eventStore.save(ekEvent, span: .thisEvent)
    }

    /// Delete an event from the system calendar
    /// - Parameter ekEventId: The EventKit event identifier
    func deleteEvent(ekEventId: String) async throws {
        guard isAuthorized else {
            throw EventKitError.notAuthorized
        }

        guard let ekEvent = eventStore.event(withIdentifier: ekEventId) else {
            // Already deleted - nothing to do
            return
        }

        try eventStore.remove(ekEvent, span: .thisEvent)
    }

    // MARK: - Event Mapping

    /// Convert a ProductionEvent to an EKEvent
    private func mapToEKEvent(_ event: ProductionEvent, calendar: EKCalendar) -> EKEvent {
        let ekEvent = EKEvent(eventStore: eventStore)

        ekEvent.title = formatEventTitle(event)
        ekEvent.startDate = event.date

        // Handle end date - default to 1 hour if not specified
        if let endDate = event.endDate {
            ekEvent.endDate = endDate
        } else if let callTime = event.callTime, let wrapTime = event.wrapTime {
            // Use call/wrap times if available
            ekEvent.startDate = callTime
            ekEvent.endDate = wrapTime
        } else {
            ekEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.date)
        }

        ekEvent.location = event.location
        ekEvent.notes = formatEventNotes(event)
        ekEvent.calendar = calendar

        return ekEvent
    }

    /// Format the event title with type prefix
    private func formatEventTitle(_ event: ProductionEvent) -> String {
        "[\(event.type.rawValue)] \(event.title)"
    }

    /// Format event notes with production-specific details
    private func formatEventNotes(_ event: ProductionEvent) -> String {
        var notes = event.notes

        if !event.scenes.isEmpty {
            notes += "\n\nScenes: \(event.scenes.joined(separator: ", "))"
        }

        if !event.crew.isEmpty {
            notes += "\n\nCrew: \(event.crew.joined(separator: ", "))"
        }

        if let callTime = event.callTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            notes += "\n\nCall Time: \(formatter.string(from: callTime))"
        }

        if let wrapTime = event.wrapTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            notes += "\n\nWrap Time: \(formatter.string(from: wrapTime))"
        }

        notes += "\n\n—\nSynced from Production Runner"

        return notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum EventKitError: LocalizedError {
    case notAuthorized
    case noCalendarSelected
    case eventNotFound
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized. Please enable calendar access in Settings."
        case .noCalendarSelected:
            return "No calendar selected. Please select a calendar to sync events to."
        case .eventNotFound:
            return "Event not found in calendar. It may have been deleted."
        case .saveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        }
    }
}
