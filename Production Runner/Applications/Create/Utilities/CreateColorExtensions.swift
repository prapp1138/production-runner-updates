import SwiftUI

// MARK: - Color Extensions for Create Module
// Namespaced to avoid conflicts with other Color extensions in the codebase

extension Color {
    /// Initialize Color from hex string (Create module specific)
    /// - Parameter createHex: Hex color string (e.g., "#FF0000" or "FF0000")
    init?(createHex: String) {
        var hexSanitized = createHex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    /// Convert Color to hex string (Create module specific)
    /// - Returns: Hex color string (e.g., "#FF0000")
    func createToHex() -> String? {
        #if os(macOS)
        let cgColor = NSColor(self).cgColor
        guard let components = cgColor.components,
              components.count >= 3 else { return nil }
        #else
        let cgColor = UIColor(self).cgColor
        guard let components = cgColor.components,
              components.count >= 3 else { return nil }
        #endif

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
