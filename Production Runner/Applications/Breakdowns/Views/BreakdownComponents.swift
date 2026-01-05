//
//  BreakdownComponents.swift
//  Production Runner
//
//  Reusable UI components for the Breakdowns module.
//  Extracted from Breakdowns.swift for better organization.
//

import SwiftUI

// MARK: - Clean Card Style (Calendar-inspired)

struct CleanCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.03)
            : Color.black.opacity(0.015)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    func body(content: Content) -> some View {
        content
            .padding(BreakdownsDesign.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: BreakdownsDesign.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BreakdownsDesign.cornerRadius, style: .continuous)
                    .strokeBorder(cardBorderColor, lineWidth: BreakdownsDesign.borderWidth)
            )
    }
}

extension View {
    func cleanCard() -> some View {
        self.modifier(CleanCard())
    }
}

// MARK: - Simple List Item

struct SimpleListItem: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(BreakdownsPlatformColor.secondarySystemBackground))
        .cornerRadius(6)
    }
}

// MARK: - Section Header

struct BreakdownSectionHeader: View {
    let title: String
    let icon: String?
    var action: (() -> Void)?

    init(title: String, icon: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if let action {
                Button(action: action) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Premium Button Component

struct PremiumButton: View {
    let title: String?
    let icon: String
    let style: ButtonStyle
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    init(title: String? = nil, icon: String, style: ButtonStyle, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    enum ButtonStyle {
        case primary, secondary, destructive, green, blue, purple, orange

        var backgroundColor: Color {
            return Color.primary.opacity(0.04)
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return .primary
            case .secondary: return .primary
            case .destructive: return .red
            case .green: return .green
            case .blue: return .blue
            case .purple: return .purple
            case .orange: return .orange
            }
        }

        var borderColor: Color {
            return Color.primary.opacity(0.1)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: title != nil ? 6 : 0) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                if let title = title {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .foregroundStyle(isEnabled ? style.foregroundColor : style.foregroundColor.opacity(0.5))
            .frame(width: title != nil ? nil : 32, height: title != nil ? nil : 32)
            .padding(.horizontal, title != nil ? 12 : 0)
            .padding(.vertical, title != nil ? 6 : 0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(style.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(style.borderColor, lineWidth: 1)
            )
            .opacity(isHovered && isEnabled ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Cast Member Row

struct BreakdownCastMemberRow: View {
    let member: BreakdownCastMember
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Cast ID Badge
            Text(member.castID)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                )

            // Name
            Text(member.name)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // Edit Button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(BreakdownsPlatformColor.secondarySystemBackground))
        .cornerRadius(6)
    }
}

// MARK: - Cast Management Row

struct CastManagementRow: View {
    let member: BreakdownCastMember
    let isEditing: Bool
    @Binding var editedCastID: String
    @Binding var editedName: String
    let onStartEdit: () -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.7))
                .frame(width: 20)

            if isEditing {
                // Edit mode
                HStack(spacing: 8) {
                    TextField("ID", text: $editedCastID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 50)

                    TextField("Name", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    Button(action: onSaveEdit) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(editedCastID.isEmpty || editedName.isEmpty)

                    Button(action: onCancelEdit) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Display mode
                HStack(spacing: 10) {
                    // Cast ID Badge
                    Text(member.castID)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue)
                        )
                        .fixedSize()

                    // Name
                    Text(member.name)
                        .font(.system(size: 14))
                        .lineLimit(1)

                    Spacer()

                    // Edit button
                    Button(action: onStartEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue.opacity(isHovered ? 1 : 0.7))
                    }
                    .buttonStyle(.plain)

                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(isHovered ? 1 : 0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .dark
                      ? Color.white.opacity(isHovered ? 0.08 : 0.04)
                      : Color.black.opacity(isHovered ? 0.06 : 0.03))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
