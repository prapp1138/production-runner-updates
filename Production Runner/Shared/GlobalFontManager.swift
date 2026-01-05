import SwiftUI

// MARK: - Global Font Manager
class GlobalFontManager: ObservableObject {
    static let shared = GlobalFontManager()
    
    @Published var fontDesign: Font.Design = .default
    @Published var fontSize: CGFloat = 64
    
    private init() {
        loadFontSettings()
        
        // Listen for font changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("GlobalFontDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadFontSettings()
        }
    }
    
    // Default typeface for the app
    static let defaultTypeface = "Helvetica Neue"

    @Published var typeface: String = defaultTypeface

    private func loadFontSettings() {
        typeface = UserDefaults.standard.string(forKey: "global_typeface") ?? Self.defaultTypeface
        let size = UserDefaults.standard.double(forKey: "global_typeface_size")

        fontDesign = fontDesignForTypeface(typeface)
        fontSize = size > 0 ? CGFloat(size) : 64
    }

    private func fontDesignForTypeface(_ typeface: String) -> Font.Design {
        switch typeface {
        case "Courier", "Menlo":
            return .monospaced
        case "Georgia", "Baskerville", "Palatino":
            return .serif
        case "Helvetica Neue", "Helvetica", "Arial":
            return .default  // Use system default design for sans-serif fonts
        default:
            return .default
        }
    }

    /// Get a Font with the global typeface
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .custom(typeface, size: size).weight(weight)
    }
}

// MARK: - Global Font Modifier
struct GlobalFontModifier: ViewModifier {
    @ObservedObject var fontManager = GlobalFontManager.shared
    let weight: Font.Weight
    let baseSize: CGFloat

    init(weight: Font.Weight = .semibold, size: CGFloat = 64) {
        self.weight = weight
        self.baseSize = size
    }

    func body(content: Content) -> some View {
        content
            .font(.custom(fontManager.typeface, size: baseSize).weight(weight))
    }
}

// MARK: - View Extension
extension View {
    /// Apply global font settings with specified weight and size
    func globalFont(weight: Font.Weight = .semibold, size: CGFloat = 64) -> some View {
        modifier(GlobalFontModifier(weight: weight, size: size))
    }
    
    /// Apply global font settings for project titles (uses dynamic size from settings)
    func projectTitleFont() -> some View {
        ProjectTitleFontModifier(content: self)
    }
}

// MARK: - Project Title Font Modifier
struct ProjectTitleFontModifier: View {
    @ObservedObject var fontManager = GlobalFontManager.shared
    let content: any View

    init(content: any View) {
        self.content = content
    }

    var body: some View {
        AnyView(content)
            .font(.custom(fontManager.typeface, size: fontManager.fontSize).weight(.semibold))
    }
}
