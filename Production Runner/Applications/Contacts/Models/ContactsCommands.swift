//
//  ContactsCommands.swift
//  Production Runner
//
//  Created by Editing on 11/3/25.
//

import SwiftUI

struct ContactsCommands: Commands {
    @FocusedValue(\.activeAppSection) private var activeAppSection: AppSection?

    var body: some Commands {
        // Contacts-specific commands only - disabled when not in Contacts section
        CommandGroup(after: .newItem) {
            Button("New Contact") {
                NotificationCenter.default.post(name: .prNewContact, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(activeAppSection != .contacts)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let prImportContacts = Notification.Name("pr.importContacts")
    static let prExportContacts = Notification.Name("pr.exportContacts")
    static let prDeleteSelectedContacts = Notification.Name("pr.deleteSelectedContacts")
}
