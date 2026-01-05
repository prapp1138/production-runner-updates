//
//  CalendarCommands.swift
//  Production Runner
//
//  Created by Editing on 11/11/25.
//

import SwiftUI

#if os(macOS)
struct CalendarCommands: Commands {
    var body: some Commands {
        CommandMenu("Calendar") {
            Button("New Event") {
                NotificationCenter.default.post(name: .prNewCalendarEvent, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Edit Event") {
                NotificationCenter.default.post(name: .prEditCalendarEvent, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command])

            Button("Open Event Details") {
                NotificationCenter.default.post(name: .prEditCalendarEvent, object: nil)
            }
            .keyboardShortcut(.return, modifiers: [])

            Button("Delete Event") {
                NotificationCenter.default.post(name: .prDeleteCalendarEvent, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: [])

            Divider()

            Button("Cut") {
                NotificationCenter.default.post(name: .prCut, object: nil)
            }
            .keyboardShortcut("x", modifiers: [.command])

            Button("Copy") {
                NotificationCenter.default.post(name: .prCopy, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command])

            Button("Paste") {
                NotificationCenter.default.post(name: .prPaste, object: nil)
            }
            .keyboardShortcut("v", modifiers: [.command])

            Divider()

            Button("Refresh Calendar") {
                NotificationCenter.default.post(name: .prRefreshCalendar, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
    }
}
#endif

// MARK: - Notification Names
extension Notification.Name {
    static let prNewCalendarEvent = Notification.Name("pr.newCalendarEvent")
    static let prEditCalendarEvent = Notification.Name("pr.editCalendarEvent")
    static let prDeleteCalendarEvent = Notification.Name("pr.deleteCalendarEvent")
    static let prRefreshCalendar = Notification.Name("pr.refreshCalendar")
}
