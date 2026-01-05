//
//  ContactsViewiOS.swift
//  Production Runner
//
//  iOS-specific Contacts View - Stub placeholder
//

import SwiftUI
import CoreData

#if os(iOS)
/// Stub iOS Contacts View - minimal placeholder to get app launching on iPad
/// Original complex contacts code has been replaced with this simple placeholder
struct ContactsViewiOS: View {
    @Environment(\.managedObjectContext) private var ctx

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.purple.opacity(0.6))

            Text("Contacts")
                .font(.system(size: 28, weight: .bold))

            Text("iOS version coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
#endif
