import SwiftUI

enum ProjectStatus: String, CaseIterable, Identifiable {
    case development = "Development"
    case preProduction = "Pre-Production"
    case production = "Production"
    case postProduction = "Post-Production"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .production: return Color.green.opacity(0.7)
        case .preProduction: return Color.yellow.opacity(0.7)
        case .development: return Color.red.opacity(0.7)
        case .postProduction: return Color.purple.opacity(0.7)
        }
    }

    var icon: String {
        switch self {
        case .production: return "camera.on.rectangle"
        case .preProduction: return "arrow.triangle.2.circlepath"
        case .development: return "list.bullet.rectangle"
        case .postProduction: return "scissors"
        }
    }
}
