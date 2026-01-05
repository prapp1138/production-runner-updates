import SwiftUI

// MARK: - Live Mode Category
enum LiveModeCategory: String, CaseIterable, Identifiable {
    case realTime = "Real Time"
    case viewOnly = "View Only"
    case newApps = "Reports & Admin"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .realTime: return "bolt.fill"
        case .viewOnly: return "eye.fill"
        case .newApps: return "doc.text.fill"
        }
    }

    var description: String {
        switch self {
        case .realTime: return "Editable during production"
        case .viewOnly: return "Reference during production"
        case .newApps: return "End of day paperwork"
        }
    }

    var color: Color {
        switch self {
        case .realTime: return .red
        case .viewOnly: return .blue
        case .newApps: return .green
        }
    }
}

// MARK: - Live Mode Section
enum LiveModeSection: String, CaseIterable, Identifiable {
    // Real Time
    case digitalCallSheetShotList = "Call Sheet + Shots"
    case dayByDayBudget = "Daily Budget"
    case addTimes = "Time Tracker"
    case teleprompter = "Teleprompter"
    case scriptSupervising = "Script Supervising"

    // View Only
    case directorsNotes = "Director's Notes"
    case storyboard = "Reference Shot"
    case cameraNotes = "Camera Notes"
    case soundNotes = "Sound Notes"
    case projectNotes = "Project Notes"

    // New Apps
    case wrapReport = "Wrap Report"
    case productionReport = "Production Report"
    case signatures = "Signatures"

    var id: String { rawValue }

    var category: LiveModeCategory {
        switch self {
        case .digitalCallSheetShotList, .dayByDayBudget, .addTimes, .teleprompter, .scriptSupervising:
            return .realTime
        case .directorsNotes, .storyboard, .cameraNotes, .soundNotes, .projectNotes:
            return .viewOnly
        case .wrapReport, .productionReport, .signatures:
            return .newApps
        }
    }

    var icon: String {
        switch self {
        case .digitalCallSheetShotList: return "doc.text.fill"
        case .dayByDayBudget: return "dollarsign.circle.fill"
        case .addTimes: return "clock.fill"
        case .teleprompter: return "text.alignleft"
        case .directorsNotes: return "book.fill"
        case .storyboard: return "rectangle.3.group.fill"
        case .scriptSupervising: return "pencil.and.list.clipboard"
        case .cameraNotes: return "camera.fill"
        case .soundNotes: return "waveform"
        case .projectNotes: return "note.text"
        case .wrapReport: return "checkmark.circle.fill"
        case .productionReport: return "doc.badge.clock.fill"
        case .signatures: return "signature"
        }
    }

    var color: Color {
        switch self {
        case .digitalCallSheetShotList: return .blue
        case .dayByDayBudget: return .green
        case .addTimes: return .orange
        case .teleprompter: return .purple
        case .directorsNotes: return .indigo
        case .storyboard: return .cyan
        case .scriptSupervising: return .pink
        case .cameraNotes: return .red
        case .soundNotes: return .teal
        case .projectNotes: return .brown
        case .wrapReport: return .mint
        case .productionReport: return .blue
        case .signatures: return .purple
        }
    }

    var isReadOnly: Bool {
        category == .viewOnly
    }

    var description: String {
        switch self {
        case .digitalCallSheetShotList: return "View call sheet and shot list for today"
        case .dayByDayBudget: return "Track daily expenses and receipts"
        case .addTimes: return "Log crew call, meals, wrap times"
        case .teleprompter: return "Scrolling script with speed controls"
        case .directorsNotes: return "View director's scene notes"
        case .storyboard: return "View storyboard frames"
        case .scriptSupervising: return "Lined script, timing, coverage"
        case .cameraNotes: return "View camera department notes"
        case .soundNotes: return "View sound department notes"
        case .projectNotes: return "View project notes and outlines"
        case .wrapReport: return "Create end-of-day wrap report"
        case .productionReport: return "Generate daily production report"
        case .signatures: return "Capture signatures for paperwork"
        }
    }

    // Get all sections for a given category
    static func sections(for category: LiveModeCategory) -> [LiveModeSection] {
        allCases.filter { $0.category == category }
    }
}
