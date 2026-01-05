//
//  AddUser.swift
//  Production Runner
//
//  Created by Brandon on 11/23/25.
//

import SwiftUI
import CoreData

// MARK: - Models
struct TeamRole: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: Color

    init(id: UUID = UUID(), name: String, color: Color = .blue) {
        self.id = id
        self.name = name
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        color = Color.fromHex(colorHex)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color.toHex(), forKey: .colorHex)
    }
}

struct TeamManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc

    @FetchRequest(
        entity: NSEntityDescription.entity(forEntityName: "ContactEntity", in: PersistenceController.shared.container.viewContext)!,
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) private var contacts: FetchedResults<NSManagedObject>

    @AppStorage("team_roles") private var rolesData: Data = Data()
    @State private var roles: [TeamRole] = []

    @State private var newRoleName = ""
    @State private var selectedColor: Color = .blue

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            contentSection
        }
        .frame(width: 780, height: 620)
        .onAppear {
            loadRoles()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Team Management")
                    .font(.system(size: 22, weight: .bold))
                Text("Manage team members and assign roles")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var contentSection: some View {
        HStack(alignment: .top, spacing: 0) {
            membersSection
            Divider()
            rolesSection
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Team Members")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(contacts.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 24)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(contacts), id: \.objectID) { contact in
                        memberRow(contact: contact)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func memberRow(contact: NSManagedObject) -> some View {
        let name = (contact.value(forKey: "name") as? String) ?? "Unknown"
        let email = (contact.value(forKey: "email") as? String) ?? ""
        let roleStr = (contact.value(forKey: "role") as? String) ?? ""
        let category = (contact.value(forKey: "category") as? String) ?? "Crew"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.6),
                                    Color.accentColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Text(initials(from: name))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                    if !email.isEmpty {
                        Text(email)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Category badge
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(categoryColor(category))
                        .frame(width: 6, height: 6)
                    Text(category)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(categoryColor(category).opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(categoryColor(category).opacity(0.3), lineWidth: 1)
                )
                .foregroundStyle(categoryColor(category))

                if !roleStr.isEmpty {
                    Text(roleStr)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            createRoleCard
            availableRolesView
            rolesHelpText
            Spacer()
        }
        .frame(width: 340)
        .padding(24)
    }

    private var createRoleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Role")
                .font(.system(size: 15, weight: .semibold))

            VStack(spacing: 10) {
                TextField("Role name (e.g., Director, Producer)", text: $newRoleName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                HStack {
                    Text("Color")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                }

                createRoleButton
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var createRoleButton: some View {
        Button(action: createRole) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                Text("Create Role")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(newRoleName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
            )
            .foregroundStyle(newRoleName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color.white)
        }
        .buttonStyle(.plain)
        .disabled(newRoleName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private var availableRolesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available Roles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if roles.isEmpty {
                Text("No roles created yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                RoleFlowLayout(spacing: 8) {
                    ForEach(roles) { role in
                        roleChip(role: role)
                    }
                }
            }
        }
    }

    private func roleChip(role: TeamRole) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(role.color)
                .frame(width: 6, height: 6)
            Text(role.name)
                .font(.system(size: 12, weight: .medium))

            Button(action: {
                deleteRole(role)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(role.color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(role.color.opacity(0.3), lineWidth: 1)
        )
        .foregroundStyle(role.color)
    }

    private var rolesHelpText: some View {
        Text("Create custom roles to organize your production team. Roles help identify responsibilities and can be assigned to team members.")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .lineSpacing(3)
    }

    // MARK: - Helper Functions

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Cast": return .purple
        case "Crew": return .blue
        case "Vendor": return .orange
        default: return .gray
        }
    }

    private func createRole() {
        let name = newRoleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let role = TeamRole(name: name, color: selectedColor)
        roles.append(role)
        saveRoles()

        newRoleName = ""
        selectedColor = .blue
    }

    private func deleteRole(_ role: TeamRole) {
        roles.removeAll { $0.id == role.id }
        saveRoles()
    }

    private func loadRoles() {
        guard !rolesData.isEmpty else { return }
        if let decoded = try? JSONDecoder().decode([TeamRole].self, from: rolesData) {
            roles = decoded
        }
    }

    private func saveRoles() {
        if let encoded = try? JSONEncoder().encode(roles) {
            rolesData = encoded
        }
    }
}

// MARK: - Flow Layout for role chips
private struct RoleFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            content()
                .alignmentGuide(.leading) { d in
                    if (abs(width - d.width) > geometry.size.width) {
                        width = 0
                        height -= d.height + spacing
                    }
                    let result = width
                    width -= d.width + spacing
                    return result
                }
                .alignmentGuide(.top) { _ in
                    let result = height
                    return result
                }
        }
    }
}

// MARK: - Color Extensions
extension Color {
    static func fromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
