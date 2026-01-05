import SwiftUI

// MARK: - Color View Style
public enum ColorViewStyle: String, CaseIterable, Identifiable {
    case macOS = "macOS"
    case defaultStyle = "Default"
    case neon = "Neon"
    
    public var id: String { rawValue }
}

// MARK: - Color Style Environment Key
private struct ColorStyleKey: EnvironmentKey {
    static let defaultValue = ColorViewStyle.macOS
}

extension EnvironmentValues {
    var colorStyle: ColorViewStyle {
        get { self[ColorStyleKey.self] }
        set { self[ColorStyleKey.self] = newValue }
    }
}

// MARK: - Color Style Modifiers
extension View {
    /// Applies the current color style to the view hierarchy
    func colorStyle(_ style: ColorViewStyle) -> some View {
        environment(\.colorStyle, style)
    }
}

// MARK: - App Color Definitions
struct AppColors {
    let style: ColorViewStyle
    
    init(style: ColorViewStyle = .macOS) {
        self.style = style
    }
    
    // MARK: - Card Colors
    var cardBackground: Color {
        switch style {
        case .macOS:
            return Color.primary.opacity(0.03)
        case .defaultStyle:
            return Color.black.opacity(0.6)
        case .neon:
            return Color.black.opacity(0.4)
        }
    }
    
    var cardBorder: Color {
        switch style {
        case .macOS:
            return Color.primary.opacity(0.08)
        case .defaultStyle:
            return Color.primary.opacity(0.15)
        case .neon:
            return Color.cyan.opacity(0.6)
        }
    }
    
    var cardBorderWidth: CGFloat {
        switch style {
        case .macOS:
            return 1
        case .defaultStyle:
            return 1
        case .neon:
            return 1.5
        }
    }
    
    var cardShadow: (color: Color, radius: CGFloat) {
        switch style {
        case .macOS:
            return (Color.black.opacity(0.02), 2)
        case .defaultStyle:
            return (Color.black.opacity(0.15), 4)
        case .neon:
            return (Color.cyan.opacity(0.3), 8)
        }
    }
    
    // MARK: - Selected State Colors
    var selectedBackground: Color {
        switch style {
        case .macOS:
            return Color.accentColor
        case .defaultStyle:
            return Color.accentColor.opacity(0.8)
        case .neon:
            return Color.cyan.opacity(0.3)
        }
    }
    
    var selectedBorder: Color {
        switch style {
        case .macOS:
            return Color.accentColor.opacity(0.3)
        case .defaultStyle:
            return Color.accentColor.opacity(0.5)
        case .neon:
            return Color.cyan
        }
    }
    
    var selectedShadow: (color: Color, radius: CGFloat) {
        switch style {
        case .macOS:
            return (Color.accentColor.opacity(0.15), 6)
        case .defaultStyle:
            return (Color.accentColor.opacity(0.3), 8)
        case .neon:
            return (Color.cyan.opacity(0.6), 12)
        }
    }
    
    // MARK: - Header Colors
    var headerBackground: LinearGradient {
        switch style {
        case .macOS:
            return LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.04),
                    Color.accentColor.opacity(0.01)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .defaultStyle:
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.5),
                    Color.black.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .neon:
            return LinearGradient(
                colors: [
                    Color.cyan.opacity(0.2),
                    Color.blue.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var headerDivider: LinearGradient {
        switch style {
        case .macOS:
            return LinearGradient(
                colors: [Color.primary.opacity(0.06), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .defaultStyle:
            return LinearGradient(
                colors: [Color.primary.opacity(0.2), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .neon:
            return LinearGradient(
                colors: [Color.cyan.opacity(0.4), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    // MARK: - Badge Colors
    func badgeStyle(for color: BadgeColor) -> (background: Color, foreground: Color, border: Color, shadow: (Color, CGFloat)) {
        switch style {
        case .macOS:
            let bg = color.defaultColor.opacity(0.15)
            let fg = color.defaultColor
            let border = Color.clear
            let shadow: (Color, CGFloat) = (Color.clear, 0.0)
            return (bg, fg, border, shadow)
            
        case .defaultStyle:
            let bg = color.defaultColor.opacity(0.2)
            let fg = color.defaultColor.opacity(0.9)
            let border = color.defaultColor.opacity(0.3)
            let shadow: (Color, CGFloat) = (color.defaultColor.opacity(0.2), 4.0)
            return (bg, fg, border, shadow)
            
        case .neon:
            let bg = color.neonColor.opacity(0.2)
            let fg = color.neonColor
            let border = color.neonColor.opacity(0.8)
            let shadow: (Color, CGFloat) = (color.neonColor.opacity(0.4), 6.0)
            return (bg, fg, border, shadow)
        }
    }
    
    // MARK: - Number Badge Colors
    var numberBadgeBackground: Color {
        switch style {
        case .macOS:
            return Color.primary.opacity(0.08)
        case .defaultStyle:
            return Color.primary.opacity(0.15)
        case .neon:
            return Color.cyan.opacity(0.2)
        }
    }
    
    var numberBadgeForeground: Color {
        switch style {
        case .macOS:
            return Color.primary
        case .defaultStyle:
            return Color.primary
        case .neon:
            return Color.cyan
        }
    }
    
    var numberBadgeGradient: LinearGradient? {
        switch style {
        case .macOS:
            return nil
        case .defaultStyle:
            return nil
        case .neon:
            return LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Button Colors
    func primaryButtonStyle() -> (background: Color, foreground: Color, shadow: (Color, CGFloat)) {
        switch style {
        case .macOS:
            return (
                Color.accentColor,
                Color.white,
                (Color.accentColor.opacity(0.3), 4)
            )
        case .defaultStyle:
            return (
                Color.accentColor.opacity(0.9),
                Color.white,
                (Color.accentColor.opacity(0.4), 6)
            )
        case .neon:
            return (
                Color.cyan.opacity(0.3),
                Color.cyan,
                (Color.cyan.opacity(0.6), 8)
            )
        }
    }
    
    func secondaryButtonStyle() -> (background: Color, foreground: Color, shadow: (Color, CGFloat)) {
        switch style {
        case .macOS:
            return (
                Color.primary.opacity(0.08),
                Color.primary,
                (Color.clear, 0)
            )
        case .defaultStyle:
            return (
                Color.primary.opacity(0.15),
                Color.primary,
                (Color.black.opacity(0.2), 2)
            )
        case .neon:
            return (
                Color.gray.opacity(0.2),
                Color.gray,
                (Color.gray.opacity(0.3), 4)
            )
        }
    }
    
    func destructiveButtonStyle() -> (background: Color, foreground: Color, shadow: (Color, CGFloat)) {
        switch style {
        case .macOS:
            return (
                Color.red.opacity(0.1),
                Color.red,
                (Color.clear, 0)
            )
        case .defaultStyle:
            return (
                Color.red.opacity(0.2),
                Color.red,
                (Color.red.opacity(0.2), 4)
            )
        case .neon:
            return (
                Color.red.opacity(0.2),
                Color.red,
                (Color.red.opacity(0.4), 6)
            )
        }
    }
    
    // MARK: - Text Field Colors
    var textFieldBackground: Color {
        switch style {
        case .macOS:
            return Color.primary.opacity(0.02)
        case .defaultStyle:
            return Color.black.opacity(0.4)
        case .neon:
            return Color.black.opacity(0.3)
        }
    }
    
    var textFieldBorder: Color {
        switch style {
        case .macOS:
            return Color.primary.opacity(0.08)
        case .defaultStyle:
            return Color.primary.opacity(0.2)
        case .neon:
            return Color.cyan.opacity(0.4)
        }
    }
    
    // MARK: - Stat Colors
    func statStyle(for color: StatColor) -> (background: Color, foreground: Color, dot: Color, shadow: (Color, CGFloat)) {
        switch style {
        case .macOS:
            let baseColor = color.defaultColor
            return (
                baseColor.opacity(0.08),
                baseColor,
                baseColor,
                (Color.clear, 0)
            )
            
        case .defaultStyle:
            let baseColor = color.defaultColor
            return (
                baseColor.opacity(0.15),
                baseColor,
                baseColor,
                (baseColor.opacity(0.2), 3)
            )
            
        case .neon:
            let baseColor = color.neonColor
            return (
                baseColor.opacity(0.2),
                baseColor,
                baseColor,
                (baseColor.opacity(0.3), 6)
            )
        }
    }
    
    // MARK: - Scene Color Indicator
    func sceneColorGradient(isInt: Bool, isExt: Bool, isDay: Bool, isNight: Bool) -> LinearGradient {
        let colors: [Color]
        
        switch style {
        case .macOS:
            switch (isInt, isExt, isDay, isNight) {
            case (true, _, true, _):
                colors = [Color.orange, Color.yellow]
            case (_, true, true, _):
                colors = [Color.yellow, Color.green.opacity(0.8)]
            case (true, _, _, true):
                colors = [Color.blue, Color.indigo]
            case (_, true, _, true):
                colors = [Color.green, Color.teal]
            default:
                colors = [Color.primary.opacity(0.2), Color.primary.opacity(0.1)]
            }
            
        case .defaultStyle:
            switch (isInt, isExt, isDay, isNight) {
            case (true, _, true, _):
                colors = [Color.orange, Color.yellow]
            case (_, true, true, _):
                colors = [Color.yellow, Color.green]
            case (true, _, _, true):
                colors = [Color.blue, Color.indigo]
            case (_, true, _, true):
                colors = [Color.green, Color.teal]
            default:
                colors = [Color.primary.opacity(0.3), Color.primary.opacity(0.2)]
            }
            
        case .neon:
            switch (isInt, isExt, isDay, isNight) {
            case (true, _, true, _):
                colors = [Color.orange, Color.yellow]
            case (_, true, true, _):
                colors = [Color.yellow, Color.green]
            case (true, _, _, true):
                colors = [Color.blue, Color.purple]
            case (_, true, _, true):
                colors = [Color.green, Color.cyan]
            default:
                colors = [Color.cyan.opacity(0.5), Color.blue.opacity(0.3)]
            }
        }
        
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Badge Color Enum
enum BadgeColor {
    case green, blue, purple, orange, red, cyan, yellow
    
    var defaultColor: Color {
        switch self {
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .red: return .red
        case .cyan: return .cyan
        case .yellow: return .yellow
        }
    }
    
    var neonColor: Color {
        switch self {
        case .green: return Color(red: 0, green: 1, blue: 0.3)
        case .blue: return Color(red: 0, green: 0.5, blue: 1)
        case .purple: return Color(red: 0.7, green: 0, blue: 1)
        case .orange: return Color(red: 1, green: 0.5, blue: 0)
        case .red: return Color(red: 1, green: 0, blue: 0.3)
        case .cyan: return Color(red: 0, green: 1, blue: 1)
        case .yellow: return Color(red: 1, green: 1, blue: 0)
        }
    }
}

// MARK: - Stat Color Enum
enum StatColor {
    case blue, green, purple, orange
    
    var defaultColor: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        }
    }
    
    var neonColor: Color {
        switch self {
        case .blue: return Color(red: 0, green: 0.7, blue: 1)
        case .green: return Color(red: 0, green: 1, blue: 0.3)
        case .purple: return Color(red: 0.7, green: 0, blue: 1)
        case .orange: return Color(red: 1, green: 0.5, blue: 0)
        }
    }
}

// MARK: - View Extension for Easy Access
extension View {
    func appColors(_ style: ColorViewStyle) -> AppColors {
        return AppColors(style: style)
    }
}

// MARK: - Environment-based Color Access
struct AppColorsEnvironment: ViewModifier {
    @AppStorage("color_view_style") private var colorViewStyle: String = ColorViewStyle.macOS.rawValue
    
    var currentStyle: ColorViewStyle {
        ColorViewStyle(rawValue: colorViewStyle) ?? .macOS
    }
    
    var colors: AppColors {
        AppColors(style: currentStyle)
    }
    
    func body(content: Content) -> some View {
        content
            .environment(\.colorStyle, currentStyle)
    }
}

extension View {
    func withAppColors() -> some View {
        modifier(AppColorsEnvironment())
    }
}
