//
//  DOODModels.swift
//  Production Runner
//
//  Shared models for Day Out of Days (DOOD) reports.
//  Used by SchedulerView and DOODReportPDF.
//

import SwiftUI

// MARK: - DOOD Status Codes (Industry Standard)

/// Industry-standard Day Out of Days status codes
public enum DOODStatus: String, CaseIterable, Codable {
    case start = "SW"        // Start Work
    case work = "W"          // Work
    case finish = "WF"       // Work Finish
    case startFinish = "SWF" // Start Work Finish (single day)
    case hold = "H"          // Hold (on call but not working)
    case travel = "T"        // Travel day
    case rehearsal = "R"     // Rehearsal
    case fitting = "F"       // Wardrobe fitting
    case holiday = "HOL"     // Holiday
    case drop = "D"          // Dropped from schedule
    case pickup = "P"        // Pickup (after being dropped)
    case none = ""           // Not scheduled

    /// Display color for the status
    public var color: Color {
        switch self {
        case .start, .startFinish: return Color.green
        case .work: return Color.blue
        case .finish: return Color.orange
        case .hold: return Color.yellow
        case .travel: return Color.purple
        case .rehearsal: return Color.cyan
        case .fitting: return Color.pink
        case .holiday: return Color.gray
        case .drop: return Color.red.opacity(0.5)
        case .pickup: return Color.teal
        case .none: return Color.clear
        }
    }

    /// Text color for readability on the status background
    public var textColor: Color {
        switch self {
        case .none: return .clear
        case .hold, .holiday: return .black
        default: return .white
        }
    }

    /// Full description of the status
    public var displayName: String {
        switch self {
        case .start: return "Start Work"
        case .work: return "Work"
        case .finish: return "Work Finish"
        case .startFinish: return "Start/Finish"
        case .hold: return "Hold"
        case .travel: return "Travel"
        case .rehearsal: return "Rehearsal"
        case .fitting: return "Fitting"
        case .holiday: return "Holiday"
        case .drop: return "Drop"
        case .pickup: return "Pickup"
        case .none: return ""
        }
    }

    #if os(macOS)
    /// NSColor for PDF generation
    public var nsColor: NSColor {
        switch self {
        case .start, .startFinish: return NSColor.systemGreen
        case .work: return NSColor.systemBlue
        case .finish: return NSColor.systemOrange
        case .hold: return NSColor.systemYellow
        case .travel: return NSColor.systemPurple
        case .rehearsal: return NSColor.systemCyan
        case .fitting: return NSColor.systemPink
        case .holiday: return NSColor.systemGray
        case .drop: return NSColor.systemRed.withAlphaComponent(0.5)
        case .pickup: return NSColor.systemTeal
        case .none: return NSColor.clear
        }
    }
    #endif
}

// MARK: - DOOD Data Models

/// Represents a cast member in the DOOD report
public struct DOODCastMember: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let role: String

    public init(id: String, name: String, role: String = "") {
        self.id = id
        self.name = name
        self.role = role
    }
}

/// Represents a shoot day in the DOOD report
public struct DOODShootDay: Identifiable, Hashable, Codable {
    public let id: UUID
    public let date: Date
    public let dayNumber: Int

    public init(id: UUID = UUID(), date: Date, dayNumber: Int) {
        self.id = id
        self.date = date
        self.dayNumber = dayNumber
    }
}

/// Statistics for a cast member across all shoot days
public struct DOODCastStats: Codable {
    public var total: Int = 0
    public var startDays: Int = 0
    public var workDays: Int = 0
    public var holdDays: Int = 0

    public init(total: Int = 0, startDays: Int = 0, workDays: Int = 0, holdDays: Int = 0) {
        self.total = total
        self.startDays = startDays
        self.workDays = workDays
        self.holdDays = holdDays
    }
}

// MARK: - DOOD Report Data

/// Complete data for generating a DOOD report
public struct DOODReportData {
    public let productionName: String
    public let castMembers: [DOODCastMember]
    public let shootDays: [DOODShootDay]
    public let statusGrid: [[DOODStatus]]  // [castIndex][dayIndex]
    public let stats: [DOODCastStats]      // One per cast member
    public let generatedDate: Date

    public init(
        productionName: String,
        castMembers: [DOODCastMember],
        shootDays: [DOODShootDay],
        statusGrid: [[DOODStatus]],
        stats: [DOODCastStats],
        generatedDate: Date = Date()
    ) {
        self.productionName = productionName
        self.castMembers = castMembers
        self.shootDays = shootDays
        self.statusGrid = statusGrid
        self.stats = stats
        self.generatedDate = generatedDate
    }

    /// Total work days across all cast members
    public var totalWorkDays: Int {
        stats.reduce(0) { $0 + $1.total }
    }
}
