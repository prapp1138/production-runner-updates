//
//  CalendarSheets.swift
//  Production Runner
//
//  Sheet views for the Calendar module.
//  Extracted from CalendarView.swift for better organization.
//

import SwiftUI
import CoreData
import EventKit

// MARK: - Add Event Sheet
struct AddEventSheet: View {
    let project: NSManagedObject
    let initialDate: Date
    let initialPhase: ProductionPhase?
    let initialSubcategoryID: String?
    var onSave: (ProductionEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @StateObject private var eventKitService = EventKitService.shared

    @State private var title: String = ""
    @State private var type: ProductionEventType = .shootDay
    @State private var productionPhase: ProductionPhase = .development
    @State private var date: Date
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var hasCallTime: Bool = false
    @State private var callTime: Date
    @State private var hasWrapTime: Bool = false
    @State private var wrapTime: Date
    @State private var customColor: Color = Color(red: 1.0, green: 0.23, blue: 0.19)
    @State private var useCustomColor: Bool = false

    // Subcategory State
    @State private var subcategoryID: String?
    @State private var eventItems: [EventItemEntity] = []

    // Sync State
    @State private var linkedLocationID: UUID?
    @State private var linkedTaskIDs: Set<UUID> = []
    @State private var availableLocations: [LocationItem] = []
    @State private var availableTasks: [TaskEntity] = []

    // Calendar Sync State
    @State private var syncToCalendar: Bool = false
    @State private var isSyncing: Bool = false

    init(project: NSManagedObject, initialDate: Date, initialPhase: ProductionPhase? = nil, initialSubcategoryID: String? = nil, onSave: @escaping (ProductionEvent) -> Void) {
        self.project = project
        self.initialDate = initialDate
        self.initialPhase = initialPhase
        self.initialSubcategoryID = initialSubcategoryID
        self.onSave = onSave
        _date = State(initialValue: initialDate)
        _endDate = State(initialValue: initialDate)
        _callTime = State(initialValue: initialDate)
        _wrapTime = State(initialValue: initialDate)
        _productionPhase = State(initialValue: initialPhase ?? .development)
        _subcategoryID = State(initialValue: initialSubcategoryID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Text("Add Event")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event Title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        TextField("Enter event title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Event Type, Production Phase, and Timeline Row on one line
                    HStack(alignment: .top, spacing: 12) {
                        // Event Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event Type")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Picker("", selection: $type) {
                                ForEach(ProductionEventType.allCases, id: \.self) { eventType in
                                    Label {
                                        Text(eventType.rawValue)
                                    } icon: {
                                        Image(systemName: eventType.icon)
                                            .foregroundStyle(eventType.color)
                                    }
                                    .tag(eventType)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)

                        // Production Phase
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Production Phase")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Picker("", selection: $productionPhase) {
                                ForEach(ProductionPhase.allCases, id: \.self) { phase in
                                    Label {
                                        Text(phase.rawValue)
                                    } icon: {
                                        Image(systemName: phase.icon)
                                            .foregroundStyle(phase.color)
                                    }
                                    .tag(phase)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .onChange(of: productionPhase) { _ in
                                // Reset subcategory when phase changes
                                subcategoryID = subcategoriesForPhase.first?.id
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Subcategory (Timeline Row)
                        if !subcategoriesForPhase.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Timeline Row")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Picker("", selection: $subcategoryID) {
                                    ForEach(subcategoriesForPhase) { subcategory in
                                        Text(subcategory.name)
                                            .tag(subcategory.id as String?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Day Color and Date on one line
                    HStack(alignment: .top, spacing: 12) {
                        // Color Picker for Shoot Day
                        if type == .shootDay {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Day Color")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Toggle(isOn: $useCustomColor) {
                                    Text("Use Custom Color")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(.switch)

                                if useCustomColor {
                                    ColorPicker("", selection: $customColor, supportsOpacity: false)
                                        .labelsHidden()
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.primary.opacity(0.05))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                        )

                                    // Color Preview
                                    HStack(spacing: 8) {
                                        Text("Preview:")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.secondary)

                                        Circle()
                                            .fill(customColor)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                            )

                                        Text(customColor.toHex() ?? "")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(Color.primary.opacity(0.05))
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Dates
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Date")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            DatePicker("Start Date", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )

                            Toggle(isOn: $hasEndDate) {
                                Text("Multi-day event")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .toggleStyle(.switch)

                            if hasEndDate {
                                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Story Location and Sync Location on one line
                    HStack(alignment: .top, spacing: 12) {
                        // Story Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Story Location")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            TextField("Enter location", text: $location)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity)

                        // Sync Location (moved from below)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sync Location")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            if availableLocations.isEmpty {
                                HStack {
                                    Image(systemName: "mappin.slash")
                                        .foregroundStyle(.secondary)
                                    Text("No locations available")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )
                            } else {
                                Menu {
                                    Button(action: { linkedLocationID = nil }) {
                                        Label("None", systemImage: "xmark.circle")
                                    }

                                    Divider()

                                    ForEach(availableLocations, id: \.id) { location in
                                        Button(action: { linkedLocationID = location.id }) {
                                            Label {
                                                VStack(alignment: .leading) {
                                                    Text(location.name)
                                                    if !location.address.isEmpty {
                                                        Text(location.address)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                            } icon: {
                                                Image(systemName: linkedLocationID == location.id ? "checkmark.circle.fill" : "mappin.circle")
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(.blue)

                                        if let selectedID = linkedLocationID,
                                           let selectedLocation = availableLocations.first(where: { $0.id == selectedID }) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(selectedLocation.name)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.primary)
                                                if !selectedLocation.address.isEmpty {
                                                    Text(selectedLocation.address)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        } else {
                                            Text("Select a location")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Times
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Times")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            // Call Time
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $hasCallTime) {
                                    Text("Call Time")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(.switch)

                                if hasCallTime {
                                    DatePicker("", selection: $callTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.primary.opacity(0.05))
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Wrap Time
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $hasWrapTime) {
                                    Text("Wrap Time")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(.switch)

                                if hasWrapTime {
                                    DatePicker("", selection: $wrapTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.primary.opacity(0.05))
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        TextEditor(text: $notes)
                            .font(.system(size: 15))
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Location Details (Display Only)
                    if let selectedID = linkedLocationID,
                       let selectedLocation = availableLocations.first(where: { $0.id == selectedID }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location Details")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            VStack(alignment: .leading, spacing: 12) {
                                // Location Name
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.blue)

                                    Text(selectedLocation.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }

                                // Address
                                if !selectedLocation.address.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Address")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.address)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Contact Person
                                if !selectedLocation.contact.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Contact Person")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.contact)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Phone
                                if !selectedLocation.phone.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Phone")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "phone.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.phone)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Email
                                if !selectedLocation.email.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Email")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.email)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Permit Status
                                if !selectedLocation.permitStatus.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Permit Status")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.permitStatus)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.blue.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }


                    // Sync Tasks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sync Tasks")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if availableTasks.isEmpty {
                            HStack {
                                Image(systemName: "checklist")
                                    .foregroundStyle(.secondary)
                                Text("No tasks available")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(availableTasks, id: \.id) { task in
                                    Button(action: {
                                        if linkedTaskIDs.contains(task.id!) {
                                            linkedTaskIDs.remove(task.id!)
                                        } else {
                                            linkedTaskIDs.insert(task.id!)
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: linkedTaskIDs.contains(task.id!) ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(linkedTaskIDs.contains(task.id!) ? .blue : .secondary)
                                                .font(.system(size: 18))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(task.title ?? "Untitled Task")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.primary)

                                                if let notes = task.notes, !notes.isEmpty {
                                                    Text(notes)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            if task.isCompleted {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                                    .font(.system(size: 14))
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(linkedTaskIDs.contains(task.id!) ? Color.blue.opacity(0.08) : Color.primary.opacity(0.05))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(linkedTaskIDs.contains(task.id!) ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Sync to Calendar
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calendar Sync")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if eventKitService.isAuthorized {
                            Toggle(isOn: $syncToCalendar) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.plus")
                                        .foregroundStyle(.blue)
                                    Text("Sync to Device Calendar")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .toggleStyle(.switch)

                            if syncToCalendar {
                                // Calendar Picker
                                HStack {
                                    Text("Destination:")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)

                                    Picker("", selection: $eventKitService.selectedCalendarIdentifier) {
                                        ForEach(eventKitService.availableCalendars, id: \.calendarIdentifier) { calendar in
                                            HStack {
                                                Circle()
                                                    .fill(Color(cgColor: calendar.cgColor))
                                                    .frame(width: 10, height: 10)
                                                Text(calendar.title)
                                            }
                                            .tag(calendar.calendarIdentifier as String?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.blue.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                                )

                                Text("Event will appear in Google Calendar, iCloud, or other services synced to this calendar.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await eventKitService.requestAccess()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundStyle(.orange)
                                    Text("Enable Calendar Access")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.orange.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Grant calendar access to sync events to Google Calendar, iCloud, and other calendar services.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer Actions
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button(action: { saveEvent() }) {
                    Text("Save Event")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(title.isEmpty ? Color.gray : Color.green)
                        )
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.primary.opacity(0.03))
        }
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            loadLocations()
            loadTasks()
            loadEventItems()
        }
    }

    private func saveEvent() {
        var event = ProductionEvent(
            title: title,
            type: type,
            productionPhase: productionPhase,
            date: date,
            endDate: hasEndDate ? endDate : nil,
            notes: notes,
            location: location,
            callTime: hasCallTime ? callTime : nil,
            wrapTime: hasWrapTime ? wrapTime : nil
        )

        // Save custom color if enabled for Shoot Day
        if type == .shootDay && useCustomColor {
            event.customColor = customColor.toHex()
        }

        // Auto-link location by name if not already linked
        var finalLinkedLocationID = linkedLocationID
        if finalLinkedLocationID == nil && !location.isEmpty {
            if let matchedLocation = LocationDataManager.shared.getLocation(byName: location) {
                finalLinkedLocationID = matchedLocation.id
            }
        }

        // Save linked location and tasks
        event.linkedLocationID = finalLinkedLocationID
        event.linkedTaskIDs = Array(linkedTaskIDs)

        // Save subcategory ID for timeline placement
        event.subcategoryID = subcategoryID

        // Sync to device calendar if enabled
        if syncToCalendar && eventKitService.isAuthorized {
            Task {
                do {
                    let ekEventId = try await eventKitService.pushEvent(event)
                    print("[CalendarSync] Event synced to calendar: \(ekEventId)")
                } catch {
                    print("[CalendarSync] Failed to sync event: \(error)")
                }
            }
        }

        onSave(event)
        dismiss()
    }

    // MARK: - Computed Properties
    private var subcategoriesForPhase: [ProductionSubcategory] {
        let phaseItems = eventItems.filter { $0.productionPhase == productionPhase.categoryID }
            .sorted { $0.sortOrder < $1.sortOrder }

        if phaseItems.isEmpty {
            // Fall back to default subcategories
            return ProductionCategory.defaultCategories
                .first(where: { $0.id == productionPhase.categoryID })?
                .subcategories ?? []
        }

        return phaseItems.compactMap { item in
            guard let itemID = item.id, let name = item.name else { return nil }
            return ProductionSubcategory(
                id: itemID.uuidString,
                name: name,
                categoryID: productionPhase.categoryID
            )
        }
    }

    // MARK: - Data Loading
    private func loadLocations() {
        availableLocations = LocationDataManager.shared.locations
    }

    private func loadTasks() {
        // Load tasks from Core Data
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)]

        do {
            availableTasks = try moc.fetch(fetchRequest)
        } catch {
            print("Failed to fetch tasks: \(error)")
            availableTasks = []
        }
    }

    private func loadEventItems() {
        // Load event items from Core Data
        let fetchRequest: NSFetchRequest<EventItemEntity> = EventItemEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EventItemEntity.sortOrder, ascending: true)]

        // Filter by current project
        if let projectID = (project.value(forKey: "id") as? UUID) {
            fetchRequest.predicate = NSPredicate(format: "project.id == %@", projectID as CVarArg)
        }

        do {
            eventItems = try moc.fetch(fetchRequest)
            // Set default subcategory
            if subcategoryID == nil {
                subcategoryID = subcategoriesForPhase.first?.id
            }
        } catch {
            print("Failed to fetch event items: \(error)")
            eventItems = []
        }
    }
}

// MARK: - Event Detail Sheet
struct EventDetailSheet: View {
    let event: ProductionEvent
    let project: NSManagedObject
    var onUpdate: (ProductionEvent) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @StateObject private var eventKitService = EventKitService.shared

    @State private var title: String
    @State private var type: ProductionEventType
    @State private var productionPhase: ProductionPhase
    @State private var date: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var notes: String
    @State private var location: String
    @State private var hasCallTime: Bool
    @State private var callTime: Date
    @State private var hasWrapTime: Bool
    @State private var wrapTime: Date
    @State private var customColor: Color
    @State private var useCustomColor: Bool
    @State private var showDeleteAlert = false

    // Subcategory State
    @State private var subcategoryID: String?
    @State private var eventItems: [EventItemEntity] = []

    // Sync State
    @State private var linkedLocationID: UUID?
    @State private var linkedTaskIDs: Set<UUID> = []
    @State private var availableLocations: [LocationItem] = []
    @State private var availableTasks: [TaskEntity] = []

    // Calendar Sync State
    @State private var syncToCalendar: Bool = false

    init(event: ProductionEvent, project: NSManagedObject, onUpdate: @escaping (ProductionEvent) -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.project = project
        self.onUpdate = onUpdate
        self.onDelete = onDelete

        _title = State(initialValue: event.title)
        _type = State(initialValue: event.type)
        _productionPhase = State(initialValue: event.productionPhase)
        _date = State(initialValue: event.date)
        _hasEndDate = State(initialValue: event.endDate != nil)
        _endDate = State(initialValue: event.endDate ?? event.date)
        _notes = State(initialValue: event.notes)
        _location = State(initialValue: event.location)
        _hasCallTime = State(initialValue: event.callTime != nil)
        _callTime = State(initialValue: event.callTime ?? event.date)
        _hasWrapTime = State(initialValue: event.wrapTime != nil)
        _wrapTime = State(initialValue: event.wrapTime ?? event.date)

        // Initialize linked data
        _linkedLocationID = State(initialValue: event.linkedLocationID)
        _linkedTaskIDs = State(initialValue: Set(event.linkedTaskIDs))

        // Initialize subcategory
        _subcategoryID = State(initialValue: event.subcategoryID)

        // Initialize custom color state
        if let hexColor = event.customColor, let color = Color(hex: hexColor) {
            _customColor = State(initialValue: color)
            _useCustomColor = State(initialValue: true)
        } else {
            _customColor = State(initialValue: Color(red: 1.0, green: 0.23, blue: 0.19))
            _useCustomColor = State(initialValue: false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Text("Edit Event")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event Title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        TextField("Enter event title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Event Type & Production Phase (side by side)
                    HStack(alignment: .top, spacing: 16) {
                        // Event Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event Type")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Picker("", selection: $type) {
                                ForEach(ProductionEventType.allCases, id: \.self) { eventType in
                                    Label {
                                        Text(eventType.rawValue)
                                    } icon: {
                                        Image(systemName: eventType.icon)
                                            .foregroundStyle(eventType.color)
                                    }
                                    .tag(eventType)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)

                        // Production Phase
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Production Phase")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Picker("", selection: $productionPhase) {
                                ForEach(ProductionPhase.allCases, id: \.self) { phase in
                                    Label {
                                        Text(phase.rawValue)
                                    } icon: {
                                        Image(systemName: phase.icon)
                                            .foregroundStyle(phase.color)
                                    }
                                    .tag(phase)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .onChange(of: productionPhase) { _ in
                                // Reset subcategory when phase changes
                                subcategoryID = subcategoriesForPhase.first?.id
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Subcategory (Timeline Row)
                    if !subcategoriesForPhase.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timeline Row")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Picker("", selection: $subcategoryID) {
                                ForEach(subcategoriesForPhase) { subcategory in
                                    Text(subcategory.name)
                                        .tag(subcategory.id as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }

                    // Date & Shoot Day Color (side by side)
                    HStack(alignment: .top, spacing: 16) {
                        // Date section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Date")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            DatePicker("Start Date", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )

                            Toggle(isOn: $hasEndDate) {
                                Text("Multi-day event")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .toggleStyle(.switch)
                        }
                        .frame(maxWidth: .infinity)

                        // Shoot Day Color (or empty space)
                        if type == .shootDay {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Shoot Day Color")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Toggle(isOn: $useCustomColor) {
                                    Text("Use Custom Color")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(.switch)

                                if useCustomColor {
                                    HStack(spacing: 12) {
                                        ColorPicker("", selection: $customColor, supportsOpacity: false)
                                            .labelsHidden()

                                        Circle()
                                            .fill(customColor)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                            )

                                        Text(customColor.toHex() ?? "")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // End Date (if multi-day)
                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        TextField("Enter location", text: $location)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Times
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Times")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            // Call Time
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $hasCallTime) {
                                    Text("Call Time")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(.switch)

                                if hasCallTime {
                                    DatePicker("", selection: $callTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.primary.opacity(0.05))
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Wrap Time
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $hasWrapTime) {
                                    Text("Wrap Time")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(.switch)

                                if hasWrapTime {
                                    DatePicker("", selection: $wrapTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.primary.opacity(0.05))
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        TextEditor(text: $notes)
                            .font(.system(size: 15))
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Location Details (Display Only)
                    if let selectedID = linkedLocationID,
                       let selectedLocation = availableLocations.first(where: { $0.id == selectedID }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location Details")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            VStack(alignment: .leading, spacing: 12) {
                                // Location Name
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.blue)

                                    Text(selectedLocation.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }

                                // Address
                                if !selectedLocation.address.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Address")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.address)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Contact Person
                                if !selectedLocation.contact.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Contact Person")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.contact)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Phone
                                if !selectedLocation.phone.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Phone")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "phone.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.phone)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Email
                                if !selectedLocation.email.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Email")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.email)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Permit Status
                                if !selectedLocation.permitStatus.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Permit Status")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: 6) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                            Text(selectedLocation.permitStatus)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.blue.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }


                    // Sync Tasks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sync Tasks")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if availableTasks.isEmpty {
                            HStack {
                                Image(systemName: "checklist")
                                    .foregroundStyle(.secondary)
                                Text("No tasks available")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(availableTasks, id: \.id) { task in
                                    Button(action: {
                                        if linkedTaskIDs.contains(task.id!) {
                                            linkedTaskIDs.remove(task.id!)
                                        } else {
                                            linkedTaskIDs.insert(task.id!)
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: linkedTaskIDs.contains(task.id!) ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(linkedTaskIDs.contains(task.id!) ? .blue : .secondary)
                                                .font(.system(size: 18))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(task.title ?? "Untitled Task")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.primary)

                                                if let notes = task.notes, !notes.isEmpty {
                                                    Text(notes)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            if task.isCompleted {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                                    .font(.system(size: 14))
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(linkedTaskIDs.contains(task.id!) ? Color.blue.opacity(0.08) : Color.primary.opacity(0.05))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(linkedTaskIDs.contains(task.id!) ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Sync to Calendar
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calendar Sync")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if eventKitService.isAuthorized {
                            Toggle(isOn: $syncToCalendar) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.plus")
                                        .foregroundStyle(.blue)
                                    Text("Sync to Device Calendar")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .toggleStyle(.switch)

                            if syncToCalendar {
                                // Calendar Picker
                                HStack {
                                    Text("Destination:")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)

                                    Picker("", selection: $eventKitService.selectedCalendarIdentifier) {
                                        ForEach(eventKitService.availableCalendars, id: \.calendarIdentifier) { calendar in
                                            HStack {
                                                Circle()
                                                    .fill(Color(cgColor: calendar.cgColor))
                                                    .frame(width: 10, height: 10)
                                                Text(calendar.title)
                                            }
                                            .tag(calendar.calendarIdentifier as String?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.blue.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                                )

                                Text("Event will appear in Google Calendar, iCloud, or other services synced to this calendar.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await eventKitService.requestAccess()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundStyle(.orange)
                                    Text("Enable Calendar Access")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.orange.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Grant calendar access to sync events to Google Calendar, iCloud, and other calendar services.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Delete Button
                    Button(action: { showDeleteAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Event")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.red)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }

            Divider()

            // Footer Actions
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button(action: { saveChanges() }) {
                    Text("Save Changes")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(title.isEmpty ? Color.gray : Color.green)
                        )
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.primary.opacity(0.03))
        }
        .frame(minWidth: 600, minHeight: 700)
        .alert("Delete Event", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this event? This action cannot be undone.")
        }
        .onAppear {
            loadLocations()
            loadTasks()
            loadEventItems()
        }
    }

    // MARK: - Data Loading
    private func loadLocations() {
        availableLocations = LocationDataManager.shared.locations
    }

    private func loadTasks() {
        // Load tasks from Core Data
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)]

        do {
            availableTasks = try moc.fetch(fetchRequest)
        } catch {
            print("Failed to fetch tasks: \(error)")
            availableTasks = []
        }
    }

    private func saveChanges() {
        var updated = event
        updated.title = title
        updated.type = type
        updated.productionPhase = productionPhase
        updated.date = date
        updated.endDate = hasEndDate ? endDate : nil
        updated.notes = notes
        updated.location = location
        updated.callTime = hasCallTime ? callTime : nil
        updated.wrapTime = hasWrapTime ? wrapTime : nil

        // Save custom color if enabled for Shoot Day
        if type == .shootDay && useCustomColor {
            updated.customColor = customColor.toHex()
        } else {
            updated.customColor = nil
        }

        // Auto-link location by name if not already linked
        var finalLinkedLocationID = linkedLocationID
        if finalLinkedLocationID == nil && !location.isEmpty {
            if let matchedLocation = LocationDataManager.shared.getLocation(byName: location) {
                finalLinkedLocationID = matchedLocation.id
            }
        }

        // Save linked location and tasks
        updated.linkedLocationID = finalLinkedLocationID
        updated.linkedTaskIDs = Array(linkedTaskIDs)

        // Save subcategory ID for timeline placement
        updated.subcategoryID = subcategoryID

        // Sync to device calendar if enabled
        if syncToCalendar && eventKitService.isAuthorized {
            Task {
                do {
                    let ekEventId = try await eventKitService.pushEvent(updated)
                    print("[CalendarSync] Event synced to calendar: \(ekEventId)")
                } catch {
                    print("[CalendarSync] Failed to sync event: \(error)")
                }
            }
        }

        onUpdate(updated)
        dismiss()
    }

    // MARK: - Computed Properties
    private var subcategoriesForPhase: [ProductionSubcategory] {
        let phaseItems = eventItems.filter { $0.productionPhase == productionPhase.categoryID }
            .sorted { $0.sortOrder < $1.sortOrder }

        if phaseItems.isEmpty {
            // Fall back to default subcategories
            return ProductionCategory.defaultCategories
                .first(where: { $0.id == productionPhase.categoryID })?
                .subcategories ?? []
        }

        return phaseItems.compactMap { item in
            guard let itemID = item.id, let name = item.name else { return nil }
            return ProductionSubcategory(
                id: itemID.uuidString,
                name: name,
                categoryID: productionPhase.categoryID
            )
        }
    }

    private func loadEventItems() {
        // Load event items from Core Data
        let fetchRequest: NSFetchRequest<EventItemEntity> = EventItemEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EventItemEntity.sortOrder, ascending: true)]

        // Filter by current project
        if let projectID = (project.value(forKey: "id") as? UUID) {
            fetchRequest.predicate = NSPredicate(format: "project.id == %@", projectID as CVarArg)
        }

        do {
            eventItems = try moc.fetch(fetchRequest)
        } catch {
            print("Failed to fetch event items: \(error)")
            eventItems = []
        }
    }
}

// MARK: - Event Items Manager Sheet
struct EventItemsManagerSheet: View {
    let project: NSManagedObject
    @Binding var eventItems: [EventItemEntity]
    var onDismiss: () -> Void

    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhase: ProductionPhase = .development
    @State private var newItemName: String = ""
    @State private var editingItem: EventItemEntity?
    @State private var editingName: String = ""
    @State private var showDefaultsDropdown = false

    // Default subcategories from the original static categories
    private var defaultSubcategoriesForPhase: [ProductionSubcategory] {
        ProductionCategory.defaultCategories
            .first(where: { $0.id == selectedPhase.categoryID })?
            .subcategories ?? []
    }

    // Filter out defaults that are already added
    private var availableDefaults: [ProductionSubcategory] {
        let existingNames = Set(itemsForPhase(selectedPhase).compactMap { $0.name?.lowercased() })
        return defaultSubcategoriesForPhase.filter { !existingNames.contains($0.name.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header (matching AddEventSheet style)
            HStack {
                Text("Event Items")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {
                    dismiss()
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Phase Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Production Phase")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Picker("", selection: $selectedPhase) {
                            ForEach(ProductionPhase.allCases, id: \.self) { phase in
                                Label {
                                    Text(phase.rawValue)
                                } icon: {
                                    Image(systemName: phase.icon)
                                        .foregroundStyle(phase.color)
                                }
                                .tag(phase)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Current Items Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: selectedPhase.icon)
                                .foregroundStyle(selectedPhase.color)
                            Text(selectedPhase.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                        }

                        VStack(spacing: 8) {
                            if itemsForPhase(selectedPhase).isEmpty {
                                Text("No event items yet. Add from defaults or create custom items below.")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 14))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.primary.opacity(0.03))
                                    )
                            } else {
                                ForEach(itemsForPhase(selectedPhase), id: \.objectID) { item in
                                    eventItemRow(item)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    // Suggested Items Section
                    if !availableDefaults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Items")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            VStack(spacing: 8) {
                                ForEach(availableDefaults, id: \.id) { subcategory in
                                    Button(action: { addFromDefault(subcategory) }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(selectedPhase.color)

                                            Text(subcategory.name)
                                                .font(.system(size: 15))
                                                .foregroundStyle(.primary)

                                            Spacer()

                                            Text("Add")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.primary.opacity(0.03))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Add Custom Item Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Custom Item")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            TextField("Custom event item name...", text: $newItemName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .onSubmit {
                                    addNewItem()
                                }

                            Button(action: addNewItem) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.5) : selectedPhase.color)
                            }
                            .buttonStyle(.plain)
                            .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }

    @ViewBuilder
    private func eventItemRow(_ item: EventItemEntity) -> some View {
        HStack(spacing: 12) {
            if editingItem?.objectID == item.objectID {
                TextField("Item name", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .onSubmit {
                        saveEdit(item)
                    }

                Button(action: { saveEdit(item) }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                Button(action: { editingItem = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(colorForItem(item))
                    .frame(width: 10, height: 10)

                Text(item.name ?? "Untitled")
                    .font(.system(size: 15))

                Spacer()

                Button(action: { startEditing(item) }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)

                Button(action: { deleteItem(item) }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func addFromDefault(_ subcategory: ProductionSubcategory) {
        let newItem = EventItemEntity(context: moc)
        newItem.id = UUID()
        newItem.name = subcategory.name
        newItem.productionPhase = selectedPhase.categoryID
        newItem.sortOrder = Int16(itemsForPhase(selectedPhase).count)
        newItem.createdAt = Date()
        newItem.updatedAt = Date()
        newItem.project = project as? ProjectEntity

        do {
            try moc.save()
            reloadItems()
        } catch {
            print("[EventItemsManager] Failed to add from default: \(error)")
        }
    }

    private func itemsForPhase(_ phase: ProductionPhase) -> [EventItemEntity] {
        eventItems.filter { $0.productionPhase == phase.categoryID }
            .sorted { ($0.sortOrder) < ($1.sortOrder) }
    }

    private func colorForItem(_ item: EventItemEntity) -> Color {
        if let hex = item.colorHex, let color = Color(hex: hex) {
            return color
        }
        if let phaseStr = item.productionPhase,
           let phase = ProductionPhase.allCases.first(where: { $0.categoryID == phaseStr }) {
            return phase.color
        }
        return .gray
    }

    private func addNewItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newItem = EventItemEntity(context: moc)
        newItem.id = UUID()
        newItem.name = trimmedName
        newItem.productionPhase = selectedPhase.categoryID
        newItem.sortOrder = Int16(itemsForPhase(selectedPhase).count)
        newItem.createdAt = Date()
        newItem.updatedAt = Date()
        newItem.project = project as? ProjectEntity

        do {
            try moc.save()
            reloadItems()
            newItemName = ""
        } catch {
            print("[EventItemsManager] Failed to save new item: \(error)")
        }
    }

    private func startEditing(_ item: EventItemEntity) {
        editingItem = item
        editingName = item.name ?? ""
    }

    private func saveEdit(_ item: EventItemEntity) {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            editingItem = nil
            return
        }

        item.name = trimmedName
        item.updatedAt = Date()

        do {
            try moc.save()
            reloadItems()
        } catch {
            print("[EventItemsManager] Failed to save edit: \(error)")
        }
        editingItem = nil
    }

    private func deleteItem(_ item: EventItemEntity) {
        moc.delete(item)
        do {
            try moc.save()
            reloadItems()
        } catch {
            print("[EventItemsManager] Failed to delete item: \(error)")
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = itemsForPhase(selectedPhase)
        items.move(fromOffsets: source, toOffset: destination)

        for (index, item) in items.enumerated() {
            item.sortOrder = Int16(index)
            item.updatedAt = Date()
        }

        do {
            try moc.save()
            reloadItems()
        } catch {
            print("[EventItemsManager] Failed to reorder items: \(error)")
        }
    }

    private func reloadItems() {
        let req = NSFetchRequest<NSManagedObject>(entityName: "EventItemEntity")
        req.predicate = NSPredicate(format: "project == %@", project)
        req.sortDescriptors = [
            NSSortDescriptor(key: "productionPhase", ascending: true),
            NSSortDescriptor(key: "sortOrder", ascending: true)
        ]

        guard let results = try? moc.fetch(req) else {
            eventItems = []
            return
        }
        eventItems = results.compactMap { $0 as? EventItemEntity }
    }
}


// MARK: - Undo/Redo Responder
// Now uses the global UndoRedoResponder from UndoRedoManager.swift
// which also listens to prUndo and prRedo notifications
