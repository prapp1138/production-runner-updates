import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Centralized appearance applier for macOS/iOS so light/dark can be toggled.
enum AppAppearance {
    enum Option: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    /// Custom theme options for accent colors
    enum Theme: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case aqua = "Aqua"
        case neon = "Neon"
        case retro = "Retro"
        case cinema = "Cinema"

        var id: String { rawValue }

        var accentColor: Color {
            switch self {
            case .standard:
                return .accentColor
            case .aqua:
                // Cyan/teal - tropical water vibes
                return Color(red: 0.0, green: 0.75, blue: 0.85)
            case .neon:
                // Vibrant magenta/pink
                return Color(red: 1.0, green: 0.2, blue: 0.6)
            case .retro:
                // Warm amber/orange - vintage film vibes
                return Color(red: 0.95, green: 0.6, blue: 0.2)
            case .cinema:
                // Letterboxd green #00e054
                return Color(red: 0.0, green: 0.878, blue: 0.329)
            }
        }

        var secondaryColor: Color {
            switch self {
            case .standard:
                return .accentColor.opacity(0.7)
            case .aqua:
                return Color(red: 0.0, green: 0.55, blue: 0.70)
            case .neon:
                return Color(red: 0.6, green: 0.0, blue: 1.0)
            case .retro:
                return Color(red: 0.80, green: 0.45, blue: 0.45)
            case .cinema:
                // Letterboxd orange #ff8000
                return Color(red: 1.0, green: 0.502, blue: 0.0)
            }
        }

        #if os(macOS)
        var nsColor: NSColor {
            switch self {
            case .standard:
                return .controlAccentColor
            case .aqua:
                return NSColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 1.0)
            case .neon:
                return NSColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)
            case .retro:
                return NSColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 1.0)
            case .cinema:
                // Letterboxd green #00e054
                return NSColor(red: 0.0, green: 0.878, blue: 0.329, alpha: 1.0)
            }
        }
        #endif

        #if os(iOS)
        var uiColor: UIColor {
            switch self {
            case .standard:
                return .tintColor
            case .aqua:
                return UIColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 1.0)
            case .neon:
                return UIColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)
            case .retro:
                return UIColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 1.0)
            case .cinema:
                // Letterboxd green #00e054
                return UIColor(red: 0.0, green: 0.878, blue: 0.329, alpha: 1.0)
            }
        }
        #endif
    }

    static func apply(_ rawValue: String) {
        let option = Option(rawValue: rawValue) ?? .system
        apply(option)
    }

    private static func apply(_ option: Option) {
        #if os(macOS)
        let newAppearance: NSAppearance?
        switch option {
        case .system:
            newAppearance = nil
        case .light:
            newAppearance = NSAppearance(named: .aqua)
        case .dark:
            newAppearance = NSAppearance(named: .darkAqua)
        }

        // Delay slightly to ensure windows are ready at launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Apply with 2-second fade transition
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 2.0
                context.allowsImplicitAnimation = true

                NSApp.appearance = newAppearance
                for window in NSApp.windows {
                    window.appearance = newAppearance
                    window.invalidateShadow()
                    window.displayIfNeeded()
                }
            }
            print("🎨 Applied macOS appearance: \(option.rawValue) to \(NSApp.windows.count) windows")
        }
        #elseif os(iOS)
        let style: UIUserInterfaceStyle
        switch option {
        case .system:
            style = .unspecified
        case .light:
            style = .light
        case .dark:
            style = .dark
        }

        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                for window in scene.windows {
                    // Apply with 2-second fade transition
                    UIView.animate(withDuration: 2.0) {
                        window.overrideUserInterfaceStyle = style
                    }
                }
            }
            print("🎨 Applied iOS appearance: \(option.rawValue) to \(scenes.count) scenes")
        }
        #endif
    }

    /// Apply a custom theme's accent color
    static func applyTheme(_ rawValue: String) {
        let theme = Theme(rawValue: rawValue) ?? .standard
        applyTheme(theme)
    }

    private static func applyTheme(_ theme: Theme) {
        // Store theme for retrieval by views
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")

        #if os(macOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Post notification so views can update their tint colors
            NotificationCenter.default.post(name: Notification.Name("AppThemeDidChange"), object: theme)
            print("🎨 Applied theme: \(theme.rawValue)")
        }
        #elseif os(iOS)
        DispatchQueue.main.async {
            // Set the window tint color
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                for window in scene.windows {
                    UIView.animate(withDuration: 0.5) {
                        window.tintColor = theme.uiColor
                    }
                }
            }
            NotificationCenter.default.post(name: Notification.Name("AppThemeDidChange"), object: theme)
            print("🎨 Applied iOS theme: \(theme.rawValue)")
        }
        #endif
    }

    /// Get the current theme
    static var currentTheme: Theme {
        let rawValue = UserDefaults.standard.string(forKey: "app_theme") ?? "Standard"
        return Theme(rawValue: rawValue) ?? .standard
    }
}

// MARK: - Theme Environment Key
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppAppearance.Theme = .standard
}

extension EnvironmentValues {
    var appTheme: AppAppearance.Theme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - View Extension for Theme Colors
extension View {
    /// Apply the current app theme's accent color as tint
    func themedAccentColor() -> some View {
        self.tint(AppAppearance.currentTheme.accentColor)
    }
}
