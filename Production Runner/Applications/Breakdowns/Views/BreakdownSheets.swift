//
//  BreakdownSheets.swift
//  Production Runner
//
//  Sheet views for the Breakdowns module.
//  Extracted from Breakdowns.swift for better organization.
//

import SwiftUI

// MARK: - Add Custom Category Sheet

struct AddCustomCategorySheet: View {
    @Binding var categoryName: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Add Custom Category")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Category Name")
                    .font(.system(size: 15, weight: .semibold))

                TextField("e.g., Stunts, Animals, Special Effects", text: $categoryName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add Category") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
        )
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    let locations: [LocationItem]
    let onSelect: (LocationItem) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""

    private var filteredLocations: [LocationItem] {
        if searchText.isEmpty {
            return locations
        }
        let query = searchText.lowercased()
        return locations.filter { location in
            location.name.lowercased().contains(query) ||
            location.address.lowercased().contains(query) ||
            location.locationInFilm.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Link Location")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search locations...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(BreakdownsPlatformColor.tertiarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Location List
            if filteredLocations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(locations.isEmpty ? "No locations in Locations app" : "No matching locations")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredLocations) { location in
                            Button(action: { onSelect(location) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.blue)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(location.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        if !location.address.isEmpty {
                                            Text(location.address)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        if !location.locationInFilm.isEmpty {
                                            Text("Script: \(location.locationInFilm)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.blue)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    // Permit status badge
                                    Text(location.permitStatus)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(permitStatusColor(location.permitStatus).opacity(0.2))
                                        .foregroundStyle(permitStatusColor(location.permitStatus))
                                        .cornerRadius(4)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(Color(BreakdownsPlatformColor.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 500, height: 500)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
        )
    }

    private func permitStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "approved": return .green
        case "pending": return .orange
        case "denied": return .red
        case "needs scout": return .blue
        default: return .secondary
        }
    }
}

// MARK: - Cast ID Editor Sheet

struct CastIDEditorSheet: View {
    let member: BreakdownCastMember
    let onSave: (BreakdownCastMember) -> Void
    let onCancel: () -> Void

    @State private var editedCastID: String
    @State private var editedName: String

    init(member: BreakdownCastMember, onSave: @escaping (BreakdownCastMember) -> Void, onCancel: @escaping () -> Void) {
        self.member = member
        self.onSave = onSave
        self.onCancel = onCancel
        _editedCastID = State(initialValue: member.castID)
        _editedName = State(initialValue: member.name)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Edit Cast Member")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Form Fields
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cast ID")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g., 1, 2A, 3B", text: $editedCastID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Character / Actor Name")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                }
            }

            Spacer()

            Divider()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    var updated = member
                    updated.castID = editedCastID
                    updated.name = editedName
                    onSave(updated)
                }
                .buttonStyle(.borderedProminent)
                .disabled(editedCastID.isEmpty || editedName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
}

// MARK: - Cast Management Popup

struct CastManagementPopup: View {
    @Binding var castMembers: [BreakdownCastMember]
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var editingMember: BreakdownCastMember? = nil
    @State private var editedCastID: String = ""
    @State private var editedName: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Manage Cast")
                        .font(.system(size: 18, weight: .bold))
                    Text("\(castMembers.count) cast member\(castMembers.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Cast List with drag-to-reorder
            if castMembers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.7))
                    Text("No cast members")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(castMembers) { member in
                        CastManagementRow(
                            member: member,
                            isEditing: editingMember?.id == member.id,
                            editedCastID: $editedCastID,
                            editedName: $editedName,
                            onStartEdit: {
                                editingMember = member
                                editedCastID = member.castID
                                editedName = member.name
                            },
                            onSaveEdit: {
                                if let index = castMembers.firstIndex(where: { $0.id == member.id }) {
                                    castMembers[index].castID = editedCastID
                                    castMembers[index].name = editedName
                                }
                                editingMember = nil
                            },
                            onCancelEdit: {
                                editingMember = nil
                            },
                            onDelete: {
                                castMembers.removeAll { $0.id == member.id }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { indices, newOffset in
                        castMembers.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Divider()

            // Footer with buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Text("Drag to reorder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.7))

                Spacer()

                Button("Save Changes") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 420, height: 450)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98))
        )
    }
}
