// MARK: - Call Sheet UI Components
// Production Runner - Call Sheet Module
// Celtx-inspired minimal white design with clean typography

import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - Adaptive Color Extension

extension Color {
    /// Creates a color that adapts to light and dark mode
    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #else
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #endif
    }
}

// MARK: - Design Constants

struct CallSheetDesign {
    // Colors - Adaptive for light/dark mode
    // Light mode: Celtx-inspired minimal white design
    // Dark mode: Professional dark appearance

    static var background: Color {
        Color(light: Color(white: 0.98), dark: Color(white: 0.11))
    }

    static var cardBackground: Color {
        Color(light: .white, dark: Color(white: 0.15))
    }

    static var sectionHeader: Color {
        Color(light: Color(white: 0.96), dark: Color(white: 0.13))
    }

    static var border: Color {
        Color(light: Color(white: 0.88), dark: Color(white: 0.25))
    }

    static var divider: Color {
        Color(light: Color(white: 0.92), dark: Color(white: 0.22))
    }

    static let accent = Color(red: 0.2, green: 0.4, blue: 0.8) // Celtx blue

    static var textPrimary: Color {
        Color(light: Color(white: 0.1), dark: Color(white: 0.95))
    }

    static var textSecondary: Color {
        Color(light: Color(white: 0.45), dark: Color(white: 0.65))
    }

    static var textTertiary: Color {
        Color(light: Color(white: 0.6), dark: Color(white: 0.45))
    }

    // Spacing
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    static let contentPadding: CGFloat = 16
    static let cardPadding: CGFloat = 20

    // Corner Radius
    static let cornerRadius: CGFloat = 8
    static let cardCornerRadius: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 6

    // Typography
    static let titleFont = Font.system(size: 24, weight: .bold, design: .default)
    static let sectionTitleFont = Font.system(size: 13, weight: .semibold, design: .default)
    static let labelFont = Font.system(size: 11, weight: .medium, design: .default)
    static let bodyFont = Font.system(size: 13, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 11, weight: .regular, design: .default)

    // Shadows
    static let cardShadow = (color: Color.black.opacity(0.04), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
    static let buttonShadow = (color: Color.black.opacity(0.06), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(1))
}

// MARK: - Section Card Container

struct CallSheetSectionCard<Content: View>: View {
    let title: String
    let icon: String
    var isCollapsible: Bool = true
    var isCollapsed: Binding<Bool>?
    var headerAction: (() -> Void)? = nil
    var headerActionIcon: String? = nil
    @ViewBuilder let content: () -> Content

    @State private var localCollapsed = false

    private var collapsed: Bool {
        isCollapsed?.wrappedValue ?? localCollapsed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                if isCollapsible {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if let binding = isCollapsed {
                            binding.wrappedValue.toggle()
                        } else {
                            localCollapsed.toggle()
                        }
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CallSheetDesign.accent)
                        .frame(width: 20)

                    Text(title.uppercased())
                        .font(CallSheetDesign.sectionTitleFont)
                        .foregroundColor(CallSheetDesign.textSecondary)
                        .tracking(0.5)

                    Spacer()

                    if let actionIcon = headerActionIcon, let action = headerAction {
                        Button(action: action) {
                            Image(systemName: actionIcon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(CallSheetDesign.accent)
                                .padding(6)
                                .background(CallSheetDesign.accent.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    if isCollapsible {
                        Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(CallSheetDesign.textTertiary)
                    }
                }
                .padding(.horizontal, CallSheetDesign.contentPadding)
                .padding(.vertical, 12)
                .background(CallSheetDesign.sectionHeader)
            }
            .buttonStyle(.plain)

            // Content
            if !collapsed {
                Divider()
                    .background(CallSheetDesign.divider)

                content()
                    .padding(CallSheetDesign.contentPadding)
            }
        }
        .background(CallSheetDesign.cardBackground)
        .cornerRadius(CallSheetDesign.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CallSheetDesign.cardCornerRadius)
                .stroke(CallSheetDesign.border, lineWidth: 1)
        )
        .shadow(
            color: CallSheetDesign.cardShadow.color,
            radius: CallSheetDesign.cardShadow.radius,
            x: CallSheetDesign.cardShadow.x,
            y: CallSheetDesign.cardShadow.y
        )
    }
}

// MARK: - Inline Editable Text Field

struct InlineEditableField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isMultiline: Bool = false
    var labelWidth: CGFloat = 100

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            Text(label)
                .font(CallSheetDesign.labelFont)
                .foregroundColor(CallSheetDesign.textSecondary)
                .frame(width: labelWidth, alignment: .trailing)

            if isMultiline {
                TextEditor(text: $text)
                    .font(CallSheetDesign.bodyFont)
                    .foregroundColor(CallSheetDesign.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isFocused ? CallSheetDesign.accent.opacity(0.05) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isFocused ? CallSheetDesign.accent.opacity(0.3) : CallSheetDesign.border, lineWidth: 1)
                    )
                    .frame(minHeight: 60)
                    .focused($isFocused)
            } else {
                TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                    .font(CallSheetDesign.bodyFont)
                    .foregroundColor(CallSheetDesign.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isFocused ? CallSheetDesign.accent.opacity(0.05) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isFocused ? CallSheetDesign.accent.opacity(0.3) : CallSheetDesign.border, lineWidth: 1)
                    )
                    .focused($isFocused)
            }
        }
    }
}

// MARK: - Time Picker Field

private struct QuickTime: Identifiable {
    let id: String
    let hour: Int
    let minute: Int

    var label: String { id }
}

struct TimePickerField: View {
    let label: String
    @Binding var date: Date?
    var labelWidth: CGFloat = 100

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    // Common call times for quick selection
    private var morningTimes: [QuickTime] {
        [
            QuickTime(id: "5:00 AM", hour: 5, minute: 0),
            QuickTime(id: "5:30 AM", hour: 5, minute: 30),
            QuickTime(id: "6:00 AM", hour: 6, minute: 0),
            QuickTime(id: "6:30 AM", hour: 6, minute: 30),
            QuickTime(id: "7:00 AM", hour: 7, minute: 0),
            QuickTime(id: "7:30 AM", hour: 7, minute: 30),
            QuickTime(id: "8:00 AM", hour: 8, minute: 0),
            QuickTime(id: "8:30 AM", hour: 8, minute: 30),
            QuickTime(id: "9:00 AM", hour: 9, minute: 0),
            QuickTime(id: "9:30 AM", hour: 9, minute: 30),
            QuickTime(id: "10:00 AM", hour: 10, minute: 0),
            QuickTime(id: "10:30 AM", hour: 10, minute: 30),
            QuickTime(id: "11:00 AM", hour: 11, minute: 0),
            QuickTime(id: "11:30 AM", hour: 11, minute: 30)
        ]
    }

    private var afternoonTimes: [QuickTime] {
        [
            QuickTime(id: "12:00 PM", hour: 12, minute: 0),
            QuickTime(id: "12:30 PM", hour: 12, minute: 30),
            QuickTime(id: "1:00 PM", hour: 13, minute: 0),
            QuickTime(id: "1:30 PM", hour: 13, minute: 30),
            QuickTime(id: "2:00 PM", hour: 14, minute: 0),
            QuickTime(id: "2:30 PM", hour: 14, minute: 30),
            QuickTime(id: "3:00 PM", hour: 15, minute: 0),
            QuickTime(id: "3:30 PM", hour: 15, minute: 30),
            QuickTime(id: "4:00 PM", hour: 16, minute: 0),
            QuickTime(id: "4:30 PM", hour: 16, minute: 30)
        ]
    }

    private var eveningTimes: [QuickTime] {
        [
            QuickTime(id: "5:00 PM", hour: 17, minute: 0),
            QuickTime(id: "5:30 PM", hour: 17, minute: 30),
            QuickTime(id: "6:00 PM", hour: 18, minute: 0),
            QuickTime(id: "6:30 PM", hour: 18, minute: 30),
            QuickTime(id: "7:00 PM", hour: 19, minute: 0),
            QuickTime(id: "7:30 PM", hour: 19, minute: 30),
            QuickTime(id: "8:00 PM", hour: 20, minute: 0),
            QuickTime(id: "8:30 PM", hour: 20, minute: 30),
            QuickTime(id: "9:00 PM", hour: 21, minute: 0),
            QuickTime(id: "9:30 PM", hour: 21, minute: 30),
            QuickTime(id: "10:00 PM", hour: 22, minute: 0),
            QuickTime(id: "10:30 PM", hour: 22, minute: 30)
        ]
    }

    private var displayText: String {
        if let d = date {
            return timeFormatter.string(from: d)
        }
        return "Set time"
    }

    private var hasValue: Bool {
        date != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(CallSheetDesign.labelFont)
                .foregroundColor(CallSheetDesign.textSecondary)
                .frame(width: labelWidth, alignment: .trailing)

            Menu {
                Section("Morning") {
                    ForEach(morningTimes) { time in
                        Button(time.label) {
                            date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())
                        }
                    }
                }

                Section("Afternoon") {
                    ForEach(afternoonTimes) { time in
                        Button(time.label) {
                            date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())
                        }
                    }
                }

                Section("Evening") {
                    ForEach(eveningTimes) { time in
                        Button(time.label) {
                            date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())
                        }
                    }
                }

                Divider()

                if hasValue {
                    Button(role: .destructive) {
                        date = nil
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(hasValue ? CallSheetDesign.accent : CallSheetDesign.textTertiary)

                    Text(displayText)
                        .font(CallSheetDesign.bodyFont)
                        .foregroundColor(hasValue ? CallSheetDesign.textPrimary : CallSheetDesign.textTertiary)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(CallSheetDesign.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(CallSheetDesign.sectionHeader)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CallSheetDesign.border, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 110)

            Spacer()
        }
    }
}

// MARK: - Status Badge

struct CallSheetStatusBadge: View {
    let status: CallSheetStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(status.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.color.opacity(0.12))
        .cornerRadius(12)
    }
}

// MARK: - Strip Color Indicator

struct StripColorIndicator: View {
    let intExt: ScheduleItem.IntExt
    let dayNight: ScheduleItem.DayNight

    var gradient: LinearGradient {
        let colors: [Color]
        switch (intExt, dayNight) {
        case (.int, .day), (.int, .morning), (.int, .afternoon):
            colors = [Color.orange.opacity(0.8), Color.yellow.opacity(0.7)]
        case (.ext, .day), (.ext, .morning), (.ext, .afternoon):
            colors = [Color.yellow.opacity(0.8), Color.green.opacity(0.7)]
        case (.int, .night), (.int, .evening):
            colors = [Color.blue.opacity(0.8), Color.indigo.opacity(0.7)]
        case (.ext, .night), (.ext, .evening):
            colors = [Color.green.opacity(0.8), Color.teal.opacity(0.7)]
        case (.int, .dawn), (.int, .dusk):
            colors = [Color.orange.opacity(0.8), Color.pink.opacity(0.7)]
        case (.ext, .dawn), (.ext, .dusk):
            colors = [Color.pink.opacity(0.8), Color.purple.opacity(0.7)]
        default:
            colors = [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(gradient)
            .frame(width: 6)
    }
}

// MARK: - Action Button

struct CallSheetButton: View {
    enum Style {
        case primary, secondary, destructive
    }

    let title: String
    var icon: String? = nil
    var style: Style = .secondary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .cornerRadius(CallSheetDesign.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CallSheetDesign.buttonCornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(
                color: CallSheetDesign.buttonShadow.color,
                radius: CallSheetDesign.buttonShadow.radius,
                x: CallSheetDesign.buttonShadow.x,
                y: CallSheetDesign.buttonShadow.y
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return CallSheetDesign.textPrimary
        case .destructive: return .red
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return CallSheetDesign.accent
        case .secondary: return CallSheetDesign.cardBackground
        case .destructive: return Color.red.opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return CallSheetDesign.accent
        case .secondary: return CallSheetDesign.border
        case .destructive: return Color.red.opacity(0.2)
        }
    }
}

// MARK: - Data Grid Row

struct DataGridRow: View {
    let columns: [(label: String, width: CGFloat)]
    let values: [String]
    var isHeader: Bool = false
    var stripColor: LinearGradient? = nil

    var body: some View {
        HStack(spacing: 0) {
            if let strip = stripColor {
                RoundedRectangle(cornerRadius: 2)
                    .fill(strip)
                    .frame(width: 4)
                    .padding(.vertical, 2)
            }

            ForEach(Array(zip(columns.indices, columns)), id: \.0) { index, column in
                Text(index < values.count ? values[index] : "")
                    .font(isHeader ? CallSheetDesign.labelFont : CallSheetDesign.bodyFont)
                    .fontWeight(isHeader ? .semibold : .regular)
                    .foregroundColor(isHeader ? CallSheetDesign.textSecondary : CallSheetDesign.textPrimary)
                    .frame(width: column.width, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, isHeader ? 8 : 10)

                if index < columns.count - 1 {
                    Divider()
                        .background(CallSheetDesign.divider)
                }
            }
        }
        .background(isHeader ? CallSheetDesign.sectionHeader : CallSheetDesign.cardBackground)
    }
}

// MARK: - Empty State View

struct CallSheetEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(CallSheetDesign.textTertiary)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CallSheetDesign.textPrimary)

                Text(message)
                    .font(CallSheetDesign.bodyFont)
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                CallSheetButton(title: actionTitle, icon: "plus", style: .primary, action: action)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Department Tag

struct DepartmentTag: View {
    let department: CrewDepartment

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: department.icon)
                .font(.system(size: 10))
            Text(department.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(CallSheetDesign.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(CallSheetDesign.accent.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Revision Color Badge

struct RevisionColorBadge: View {
    let revision: RevisionColor

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(revision.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )

            Text(revision.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(CallSheetDesign.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(revision.color.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Toolbar Button

struct CallSheetToolbarButton: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? CallSheetDesign.accent : CallSheetDesign.textSecondary)
            .frame(width: 60, height: 50)
            .background(isSelected ? CallSheetDesign.accent.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Field

struct CallSheetSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CallSheetDesign.textTertiary)

            TextField(placeholder, text: $text)
                .font(CallSheetDesign.bodyFont)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(CallSheetDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CallSheetDesign.cardBackground)
        .cornerRadius(CallSheetDesign.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CallSheetDesign.cornerRadius)
                .stroke(CallSheetDesign.border, lineWidth: 1)
        )
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = CallSheetDesign.textPrimary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(CallSheetDesign.textTertiary)
                .frame(width: 16)

            Text(label)
                .font(CallSheetDesign.labelFont)
                .foregroundColor(CallSheetDesign.textSecondary)

            Spacer()

            Text(value)
                .font(CallSheetDesign.bodyFont)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Cast Status Picker

struct CastStatusPicker: View {
    @Binding var status: CastMember.CastStatus

    var body: some View {
        Menu {
            ForEach(CastMember.CastStatus.allCases, id: \.self) { s in
                Button(action: { status = s }) {
                    HStack {
                        Text("\(s.rawValue) - \(s.fullName)")
                        if status == s {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(status.rawValue)
                    .font(.system(size: 11, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .cornerRadius(4)
        }
    }
}

// MARK: - Template Picker Card

struct TemplatePickerCard: View {
    let template: CallSheetTemplateType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : CallSheetDesign.accent)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }

                Text(template.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : CallSheetDesign.textPrimary)

                Text(template.description)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : CallSheetDesign.textSecondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? CallSheetDesign.accent : CallSheetDesign.cardBackground)
            .cornerRadius(CallSheetDesign.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CallSheetDesign.cardCornerRadius)
                    .stroke(isSelected ? CallSheetDesign.accent : CallSheetDesign.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Reorder Handle

struct SectionReorderHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(CallSheetDesign.textTertiary)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
    }
}

// MARK: - View Modifiers

extension View {
    func callSheetCard() -> some View {
        self
            .background(CallSheetDesign.cardBackground)
            .cornerRadius(CallSheetDesign.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CallSheetDesign.cardCornerRadius)
                    .stroke(CallSheetDesign.border, lineWidth: 1)
            )
            .shadow(
                color: CallSheetDesign.cardShadow.color,
                radius: CallSheetDesign.cardShadow.radius,
                x: CallSheetDesign.cardShadow.x,
                y: CallSheetDesign.cardShadow.y
            )
    }

    func callSheetBackground() -> some View {
        self.background(CallSheetDesign.background)
    }
}
