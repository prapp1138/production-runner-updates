import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - FocusedValue Key for Active App Section
struct ActiveAppSectionKey: FocusedValueKey {
    typealias Value = AppSection
}

extension FocusedValues {
    var activeAppSection: ActiveAppSectionKey.Value? {
        get { self[ActiveAppSectionKey.self] }
        set { self[ActiveAppSectionKey.self] = newValue }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case productionRunner = "Dashboard"
    case screenplay = "Screenplay"
    #if INCLUDE_PLAN
    case plan = "Plan"
    #endif
    #if INCLUDE_CALENDAR
    case calendar = "Calendar"
    #endif
    case contacts = "Contacts"
    case breakdowns = "Breakdowns"
    #if INCLUDE_SCRIPTY
    case scripty = "Scripty"
    #endif
    #if INCLUDE_BUDGETING
    case budget = "Budgeting"
    #endif
    case shotLister = "Shots"
    case locations = "Locations"
    case scheduler = "Scheduler"
    case callSheets = "Call Sheets"
    case tasks = "Tasks"
    #if INCLUDE_CHAT
    case chat = "Chat"
    #endif
    #if INCLUDE_PAPERWORK
    case paperwork = "Paperwork"
    #endif
    #if INCLUDE_LIVE_MODE
    case liveMode = "Live Mode"
    #endif

    var id: String { rawValue }

    /// Apps available on iOS (excluding Dashboard which is handled separately)
    static var iOSAvailableCases: [AppSection] {
        [.screenplay, .contacts]
    }

    var icon: String {
        switch self {
        case .productionRunner: return "square.grid.2x2.fill"
        case .screenplay: return "text.page.fill"
        #if INCLUDE_CALENDAR
        case .calendar: return "calendar"
        #endif
        case .contacts: return "person.2.fill"
        case .breakdowns: return "list.clipboard.fill"
        #if INCLUDE_SCRIPTY
        case .scripty: return "pencil.and.list.clipboard"
        #endif
        #if INCLUDE_BUDGETING
        case .budget: return "dollarsign.circle.fill"
        #endif
        case .shotLister: return "video.fill"
        case .locations: return "mappin.circle.fill"
        case .scheduler: return "calendar.circle.fill"
        case .callSheets: return "doc.text.fill"
        case .tasks: return "checklist.checked"
        #if INCLUDE_CHAT
        case .chat: return "bubble.left.and.bubble.right"
        #endif
        #if INCLUDE_PAPERWORK
        case .paperwork: return "doc.badge.ellipsis"
        #endif
        #if INCLUDE_LIVE_MODE
        case .liveMode: return "record.circle"
        #endif
        #if INCLUDE_PLAN
        case .plan: return "list.bullet.clipboard"
        #endif
        }
    }

    // Assign each section a unique accent color
    var accentColor: Color {
        switch self {
        case .productionRunner: return .blue
        case .screenplay: return .indigo
        #if INCLUDE_CALENDAR
        case .calendar: return .green
        #endif
        case .contacts: return .purple
        case .breakdowns: return .orange
        #if INCLUDE_SCRIPTY
        case .scripty: return .pink
        #endif
        #if INCLUDE_BUDGETING
        case .budget: return .mint
        #endif
        case .shotLister: return .red
        case .locations: return .teal
        case .scheduler: return .cyan
        case .callSheets: return .yellow
        case .tasks: return .pink
        #if INCLUDE_CHAT
        case .chat: return .blue
        #endif
        #if INCLUDE_PAPERWORK
        case .paperwork: return .indigo
        #endif
        #if INCLUDE_LIVE_MODE
        case .liveMode: return .red
        #endif
        #if INCLUDE_PLAN
        case .plan: return .purple
        #endif
        }
    }
}

// MARK: - App Section Panel (bindable selection)
struct AppSectionPanel: View {
    @Binding var selected: AppSection
    @AppStorage("AppSectionSelected") private var selectedRaw: String = ""
    @AppStorage("app_theme") private var appTheme: String = "Standard"
    @Environment(\.colorScheme) private var colorScheme
    var onSelect: ((AppSection) -> Void)? = nil

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(AppSection.allCases) { s in
                AppSectionTile(section: s, isSelected: s == selected) {
                    selectedRaw = s.rawValue
                    selected = s
                    onSelect?(s)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(themedSidebarBackground)
        .onAppear {
            // Initialize from persisted value if present, otherwise default to Dashboard
            if let persisted = AppSection(rawValue: selectedRaw), !selectedRaw.isEmpty {
                selected = persisted
            } else {
                // Default to Dashboard
                selected = .productionRunner
                selectedRaw = AppSection.productionRunner.rawValue
            }
        }
        .onChange(of: selected) { newValue in
            // Keep persistence in sync with external navigation
            selectedRaw = newValue.rawValue
        }
    }

    @ViewBuilder
    private var themedSidebarBackground: some View {
        switch currentTheme {
        case .aqua:
            // Dark brushed metal - simple gradient that fills entire space
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.26),
                    Color(red: 0.18, green: 0.20, blue: 0.22),
                    Color(red: 0.15, green: 0.17, blue: 0.19),
                    Color(red: 0.12, green: 0.14, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .retro:
            // Pure computer terminal black
            Color.black
        case .neon:
            // Black gradient with subtle RGB hints
            ZStack {
                // Base black
                Color.black
                // Subtle colored gradient hints
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.black,
                        Color.red.opacity(0.06),
                        Color.black,
                        Color.green.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Additional diagonal color sweep
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.blue.opacity(0.04),
                        Color.clear,
                        Color.red.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        case .cinema:
            // Letterboxd dark background #14181c
            Color(red: 0.078, green: 0.094, blue: 0.110)
        case .standard:
            // Standard - no custom background (use system default)
            Color.clear
        }
    }
}

// MARK: - Modern, Sleek App Section Tile
struct AppSectionTile: View {
    var section: AppSection
    var isSelected: Bool = false
    @AppStorage("AppSectionSelected") private var selectedRaw: String = ""
    @AppStorage("app_theme") private var appTheme: String = "Standard"
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    var body: some View {
        let active = isSelected || selectedRaw == section.rawValue

        Button(action: {
            selectedRaw = section.rawValue
            action()
        }) {
            switch currentTheme {
            case .aqua:
                aquaTileContent(active: active)
            case .retro:
                retroTileContent(active: active)
            case .neon:
                neonTileContent(active: active)
            case .cinema:
                cinemaTileContent(active: active)
            case .standard:
                standardTileContent(active: active)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Standard Theme (Minimal, Clean Style)
    @ViewBuilder
    private func standardTileContent(active: Bool) -> some View {
        let sectionColor = section.accentColor

        HStack(spacing: 0) {
            // Vertical accent bar (left edge)
            Rectangle()
                .fill(active ? sectionColor : Color.clear)
                .frame(width: 3)
                .clipShape(Capsule())

            HStack(spacing: 12) {
                // Icon - no background
                Image(systemName: section.icon)
                    .renderingMode(.template)
                    .font(.system(size: 18, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? sectionColor : Color.secondary)
                    .frame(width: 38, height: 38)

                // Title
                Text(section.rawValue)
                    .font(.system(size: 14, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                    .lineLimit(1)

                Spacer()

                // Chevron indicator
                if active {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(sectionColor.opacity(0.6))
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            // Subtle background on hover/active
            Rectangle()
                .fill(
                    active
                        ? sectionColor.opacity(colorScheme == .dark ? 0.08 : 0.06)
                        : (isHovered ? Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.03) : Color.clear)
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .applyHoverEffect($isHovered)
    }

    // MARK: - Aqua Theme (Dark Brushed Metal)
    @ViewBuilder
    private func aquaTileContent(active: Bool) -> some View {
        let aquaBlue = Color(red: 0.3, green: 0.6, blue: 1.0)

        HStack(spacing: 14) {
            // Classic Aqua-style icon with gel effect
            ZStack {
                // Outer glow/shadow
                Circle()
                    .fill(
                        active
                            ? RadialGradient(
                                colors: [aquaBlue.opacity(0.5), aquaBlue.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 12,
                                endRadius: 22
                            )
                            : RadialGradient(
                                colors: [Color.white.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 12,
                                endRadius: 20
                            )
                    )
                    .frame(width: 38, height: 38)

                // Gel button base
                Circle()
                    .fill(
                        LinearGradient(
                            colors: active
                                ? [Color(red: 0.4, green: 0.7, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)]
                                : [Color(red: 0.45, green: 0.48, blue: 0.52), Color(red: 0.30, green: 0.33, blue: 0.38)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        // Top highlight (gel shine)
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 24, height: 12)
                            .offset(y: -5)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.black.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )

                // Icon
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(active ? .white : Color(red: 0.75, green: 0.78, blue: 0.82))
                    .shadow(color: active ? Color.black.opacity(0.4) : Color.black.opacity(0.3), radius: 1, y: 1)
            }
            .frame(width: 38, height: 38)

            // Label - light text for dark background
            Text(section.rawValue)
                .font(.system(size: 14, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Color.white : Color(red: 0.75, green: 0.78, blue: 0.82))
                .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)

            Spacer()

            if active {
                // Aqua-style chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(aquaBlue)
                    .shadow(color: aquaBlue.opacity(0.5), radius: 3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .background(
            ZStack {
                if active {
                    // Aqua selection highlight - darker style
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.45, blue: 0.75),
                                    Color(red: 0.15, green: 0.35, blue: 0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color.black.opacity(0.4)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                }
            }
        )
        .scaleEffect(isHovered && !active ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: active)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .applyHoverEffect($isHovered)
    }

    // MARK: - Retro Theme (80s Terminal)
    @ViewBuilder
    private func retroTileContent(active: Bool) -> some View {
        let terminalGreen = Color(red: 0.2, green: 1.0, blue: 0.3)
        let dimGreen = Color(red: 0.1, green: 0.5, blue: 0.15)

        HStack(spacing: 12) {
            // Terminal-style icon
            ZStack {
                // Phosphor glow effect
                if active {
                    Circle()
                        .fill(terminalGreen.opacity(0.3))
                        .frame(width: 38, height: 38)
                        .blur(radius: 4)
                }

                // Icon border (like old terminal graphics)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        active ? terminalGreen : dimGreen,
                        lineWidth: active ? 2 : 1
                    )
                    .frame(width: 32, height: 32)

                // Icon
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(active ? terminalGreen : dimGreen)
                    .shadow(color: active ? terminalGreen.opacity(0.8) : Color.clear, radius: 4)
            }

            // Monospace label
            Text(section.rawValue.uppercased())
                .font(.system(size: 12, weight: active ? .bold : .medium, design: .monospaced))
                .foregroundStyle(active ? terminalGreen : dimGreen)
                .shadow(color: active ? terminalGreen.opacity(0.5) : Color.clear, radius: 3)
                .tracking(1)

            Spacer()

            if active {
                // Blinking cursor effect
                Text(">")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(terminalGreen)
                    .shadow(color: terminalGreen.opacity(0.8), radius: 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .background(
            ZStack {
                if active {
                    // Selected state - subtle green border
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(terminalGreen.opacity(0.6), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(terminalGreen.opacity(0.08))
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(dimGreen.opacity(0.5), lineWidth: 1)
                }
            }
        )
        .animation(.easeInOut(duration: 0.15), value: active)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .applyHoverEffect($isHovered)
    }

    // MARK: - Neon Theme (Cyberpunk)
    @ViewBuilder
    private func neonTileContent(active: Bool) -> some View {
        let neonPink = Color(red: 1.0, green: 0.2, blue: 0.6)
        let neonPurple = Color(red: 0.6, green: 0.2, blue: 1.0)
        let dimColor = Color(red: 0.5, green: 0.3, blue: 0.6)

        HStack(spacing: 14) {
            // Neon icon with glow
            ZStack {
                // Outer glow
                if active {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [neonPink.opacity(0.5), neonPurple.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                        .blur(radius: 3)
                }

                // Icon container
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                active
                                    ? LinearGradient(colors: [neonPink, neonPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [dimColor.opacity(0.5), dimColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: active ? 2 : 1
                            )
                    )

                // Icon
                Image(systemName: section.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(
                        active
                            ? LinearGradient(colors: [neonPink, neonPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [dimColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: active ? neonPink.opacity(0.8) : Color.clear, radius: 6)
            }

            // Label with neon glow
            Text(section.rawValue)
                .font(.system(size: 14, weight: active ? .bold : .medium))
                .foregroundStyle(active ? neonPink : dimColor)
                .shadow(color: active ? neonPink.opacity(0.6) : Color.clear, radius: 4)

            Spacer()

            if active {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(neonPurple)
                    .shadow(color: neonPurple.opacity(0.8), radius: 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .background(
            ZStack {
                if active {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.4))
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(colors: [neonPink.opacity(0.6), neonPurple.opacity(0.4)], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1
                        )
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(dimColor.opacity(0.3), lineWidth: 1)
                }
            }
        )
        .scaleEffect(isHovered && !active ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: active)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .applyHoverEffect($isHovered)
    }

    // MARK: - Cinema Theme (Letterboxd Style)
    @ViewBuilder
    private func cinemaTileContent(active: Bool) -> some View {
        // Letterboxd colors
        let lbGreen = Color(red: 0.0, green: 0.878, blue: 0.329)      // #00e054
        let lbOrange = Color(red: 1.0, green: 0.502, blue: 0.0)       // #ff8000
        // lbBlue: #40bcf4 - Color(red: 0.251, green: 0.737, blue: 0.957)
        let lbDarkBg = Color(red: 0.078, green: 0.094, blue: 0.110)   // #14181c
        let lbCardBg = Color(red: 0.110, green: 0.133, blue: 0.157)   // #1c2228
        let lbGray = Color(red: 0.6, green: 0.6, blue: 0.6)           // Muted gray for inactive

        HStack(spacing: 14) {
            // Letterboxd-style icon - clean, minimal
            ZStack {
                // Subtle glow for active state
                if active {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [lbGreen.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 8,
                                endRadius: 22
                            )
                        )
                        .frame(width: 40, height: 40)
                }

                // Clean rounded icon container
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? lbCardBg : lbDarkBg.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                active ? lbGreen.opacity(0.6) : lbGray.opacity(0.2),
                                lineWidth: active ? 1.5 : 1
                            )
                    )

                // Icon
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(active ? lbGreen : lbGray)
                    .shadow(color: active ? lbGreen.opacity(0.4) : Color.clear, radius: 2)
            }
            .frame(width: 36, height: 36)

            // Label - clean Letterboxd style
            Text(section.rawValue)
                .font(.system(size: 14, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? .white : lbGray)

            Spacer()

            if active {
                // Orange accent indicator (Letterboxd uses orange for interactions)
                Circle()
                    .fill(lbOrange)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(
            ZStack {
                if active {
                    // Letterboxd-style selection - subtle card background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lbCardBg)
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(lbGreen.opacity(0.3), lineWidth: 1)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                }
            }
        )
        .scaleEffect(isHovered && !active ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: active)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .applyHoverEffect($isHovered)
    }
}

// MARK: - Hover Effect Extension
extension View {
    func applyHoverEffect(_ isHovered: Binding<Bool>) -> some View {
        #if os(macOS)
        self.onHover { hovering in
            isHovered.wrappedValue = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #else
        self
        #endif
    }
}
