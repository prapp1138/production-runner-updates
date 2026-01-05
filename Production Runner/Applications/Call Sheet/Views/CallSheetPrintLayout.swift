// MARK: - Call Sheet Print Layout
// Production Runner - Call Sheet Module
// Professional 8.5x11" PDF export layout for printing

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Print Design Constants

struct PrintDesign {
    // Page dimensions (8.5" x 11" at 72 dpi)
    static let pageWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792

    // Margins
    static let marginTop: CGFloat = 36
    static let marginBottom: CGFloat = 36
    static let marginLeft: CGFloat = 36
    static let marginRight: CGFloat = 36

    // Content area
    static let contentWidth: CGFloat = pageWidth - marginLeft - marginRight
    static let contentHeight: CGFloat = pageHeight - marginTop - marginBottom

    // Typography
    static let titleFont = Font.system(size: 14, weight: .bold)
    static let subtitleFont = Font.system(size: 10, weight: .semibold)
    static let headerFont = Font.system(size: 8, weight: .bold)
    static let bodyFont = Font.system(size: 8, weight: .regular)
    static let smallFont = Font.system(size: 7, weight: .regular)
    static let tinyFont = Font.system(size: 6, weight: .regular)

    // Colors
    static let black = Color.black
    static let darkGray = Color(white: 0.2)
    static let mediumGray = Color(white: 0.5)
    static let lightGray = Color(white: 0.85)
    static let veryLightGray = Color(white: 0.95)

    // Spacing
    static let sectionSpacing: CGFloat = 8
    static let itemSpacing: CGFloat = 4
    static let cellPadding: CGFloat = 4
    static let borderWidth: CGFloat = 0.5
}

// MARK: - Main Print Layout

struct CallSheetPrintLayout: View {
    let callSheet: CallSheet

    init(callSheet: CallSheet) {
        self.callSheet = callSheet
        print("📄 CallSheetPrintLayout: Initialized with '\(callSheet.title)'")
        print("📄 CallSheetPrintLayout: scheduleItems.count = \(callSheet.scheduleItems.count)")
        if callSheet.scheduleItems.count > 0 {
            print("📄 CallSheetPrintLayout: First item = '\(callSheet.scheduleItems[0].intExt.rawValue). \(callSheet.scheduleItems[0].setDescription)'")
        }
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            VStack(spacing: PrintDesign.sectionSpacing) {
                // Header
                PrintHeader(callSheet: callSheet, dateFormatter: dateFormatter)

                // Call Times & Weather Row
                HStack(alignment: .top, spacing: PrintDesign.sectionSpacing) {
                    PrintCallTimesBox(callSheet: callSheet, timeFormatter: timeFormatter)
                    PrintWeatherBox(callSheet: callSheet)
                }

                // Location & Hospital Row (height matches Weather row)
                HStack(alignment: .top, spacing: PrintDesign.sectionSpacing) {
                    PrintLocationBox(callSheet: callSheet)
                        .frame(maxWidth: .infinity)
                    PrintHospitalBox(callSheet: callSheet)
                        .frame(width: 180)
                }
                .frame(height: 58)

                // Shooting Schedule
                if !callSheet.scheduleItems.isEmpty {
                    PrintScheduleTable(items: callSheet.scheduleItems)
                }

                // Cast
                if !callSheet.castMembers.isEmpty {
                    PrintCastTable(cast: callSheet.castMembers)
                }

                // Crew (compact)
                if !callSheet.crewMembers.isEmpty {
                    PrintCrewSection(crew: callSheet.crewMembers)
                }

                // Notes Row
                HStack(alignment: .top, spacing: PrintDesign.sectionSpacing) {
                    if !callSheet.productionNotes.isEmpty {
                        PrintNotesBox(title: "PRODUCTION NOTES", content: callSheet.productionNotes)
                    }
                    if !callSheet.advanceSchedule.isEmpty {
                        PrintNotesBox(title: "ADVANCE SCHEDULE", content: callSheet.advanceSchedule)
                    }
                }

                Spacer(minLength: 0)

                // Safety Footer
                PrintSafetyFooter(notes: callSheet.safetyNotes)
            }
            .padding(.horizontal, PrintDesign.marginLeft)
            .padding(.top, PrintDesign.marginTop)
            .padding(.bottom, PrintDesign.marginBottom)
        }
        .frame(width: PrintDesign.pageWidth, height: PrintDesign.pageHeight)
        .background(Color.white)
    }
}

// MARK: - Print Header

struct PrintHeader: View {
    let callSheet: CallSheet
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with production info
            HStack(alignment: .top, spacing: 0) {
                // Left: Production Company + Logo
                VStack(alignment: .leading, spacing: 2) {
                    if let imageData = callSheet.productionCompanyImageData {
                        #if os(macOS)
                        if let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 30)
                        }
                        #else
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 30)
                        }
                        #endif
                    }
                    if !callSheet.productionCompany.isEmpty {
                        Text(callSheet.productionCompany.uppercased())
                            .font(PrintDesign.subtitleFont)
                            .foregroundColor(PrintDesign.black)
                    }
                }
                .frame(width: 150, alignment: .leading)

                Spacer()

                // Center: Project Title
                VStack(spacing: 2) {
                    Text(callSheet.projectName.uppercased())
                        .font(PrintDesign.titleFont)
                        .foregroundColor(PrintDesign.black)
                        .multilineTextAlignment(.center)

                    Text(callSheet.title)
                        .font(PrintDesign.subtitleFont)
                        .foregroundColor(PrintDesign.darkGray)
                }

                Spacer()

                // Right: Day/Date
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DAY \(callSheet.dayNumber) OF \(callSheet.totalDays)")
                        .font(PrintDesign.subtitleFont)
                        .foregroundColor(PrintDesign.black)

                    Text(dateFormatter.string(from: callSheet.shootDate))
                        .font(PrintDesign.bodyFont)
                        .foregroundColor(PrintDesign.darkGray)

                    // Revision badge
                    if callSheet.revisionNumber > 0 {
                        Text("\(callSheet.revisionColor.rawValue) REVISION")
                            .font(PrintDesign.tinyFont)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(callSheet.revisionColor.color)
                            .cornerRadius(2)
                    }
                }
                .frame(width: 150, alignment: .trailing)
            }
            .padding(.bottom, 6)

            // Key Personnel Row
            PrintDivider()

            HStack(spacing: 0) {
                PrintKeyPersonCell(title: "DIRECTOR", value: callSheet.director)
                PrintVerticalDivider()
                PrintKeyPersonCell(title: "1ST AD", value: callSheet.firstAD)
                PrintVerticalDivider()
                PrintKeyPersonCell(title: "PRODUCER", value: callSheet.producer)
                PrintVerticalDivider()
                PrintKeyPersonCell(title: "DOP", value: callSheet.dop)
                PrintVerticalDivider()
                PrintKeyPersonCell(title: "UPM", value: callSheet.upm)
            }
            .frame(height: 28)

            PrintDivider()
        }
    }
}

struct PrintKeyPersonCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(PrintDesign.tinyFont)
                .foregroundColor(PrintDesign.mediumGray)
            Text(value.isEmpty ? "—" : value)
                .font(PrintDesign.smallFont)
                .foregroundColor(PrintDesign.black)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

// MARK: - Call Times Box

struct PrintCallTimesBox: View {
    let callSheet: CallSheet
    let timeFormatter: DateFormatter

    var body: some View {
        PrintBox(title: "CALL TIMES") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 4) {
                PrintTimeCell(label: "CREW CALL", time: callSheet.crewCall, formatter: timeFormatter, highlight: true)
                PrintTimeCell(label: "SHOOTING", time: callSheet.shootingCall, formatter: timeFormatter)
                PrintTimeCell(label: "1ST SHOT", time: callSheet.firstShotCall, formatter: timeFormatter)
                PrintTimeCell(label: "BREAKFAST", time: callSheet.breakfast, formatter: timeFormatter)
                PrintTimeCell(label: "LUNCH", time: callSheet.lunch, formatter: timeFormatter)
                PrintTimeCell(label: "EST. WRAP", time: callSheet.estimatedWrap, formatter: timeFormatter)
            }
        }
    }
}

struct PrintTimeCell: View {
    let label: String
    let time: Date?
    let formatter: DateFormatter
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(PrintDesign.tinyFont)
                .foregroundColor(PrintDesign.mediumGray)

            Text(time.map { formatter.string(from: $0) } ?? "—")
                .font(highlight ? Font.system(size: 9, weight: .bold) : PrintDesign.bodyFont)
                .foregroundColor(PrintDesign.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(highlight ? PrintDesign.veryLightGray : Color.clear)
    }
}

// MARK: - Weather Box

struct PrintWeatherBox: View {
    let callSheet: CallSheet

    var body: some View {
        PrintBox(title: "WEATHER") {
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("HIGH")
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.mediumGray)
                    Text(callSheet.weatherHigh.isEmpty ? "—" : callSheet.weatherHigh)
                        .font(Font.system(size: 10, weight: .bold))
                }

                VStack(spacing: 2) {
                    Text("LOW")
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.mediumGray)
                    Text(callSheet.weatherLow.isEmpty ? "—" : callSheet.weatherLow)
                        .font(PrintDesign.bodyFont)
                }

                Divider()
                    .frame(height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(callSheet.weatherConditions.isEmpty ? "—" : callSheet.weatherConditions)
                        .font(PrintDesign.smallFont)

                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("☀")
                                .font(PrintDesign.tinyFont)
                            Text(callSheet.sunrise)
                                .font(PrintDesign.tinyFont)
                        }
                        HStack(spacing: 2) {
                            Text("☽")
                                .font(PrintDesign.tinyFont)
                            Text(callSheet.sunset)
                                .font(PrintDesign.tinyFont)
                        }
                    }
                    .foregroundColor(PrintDesign.mediumGray)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 180)
    }
}

// MARK: - Location Box

struct PrintLocationBox: View {
    let callSheet: CallSheet

    var body: some View {
        PrintBox(title: "LOCATION") {
            HStack(alignment: .top, spacing: 12) {
                // Shooting Location
                VStack(alignment: .leading, spacing: 1) {
                    Text("SHOOTING LOCATION")
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.mediumGray)

                    Text(callSheet.shootingLocation.isEmpty ? "TBD" : callSheet.shootingLocation)
                        .font(Font.system(size: 8, weight: .semibold))
                        .lineLimit(1)

                    Text(callSheet.locationAddress)
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.darkGray)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PrintVerticalDivider()

                // Basecamp/Parking
                VStack(alignment: .leading, spacing: 1) {
                    Text("BASECAMP")
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.mediumGray)

                    Text(callSheet.basecamp.isEmpty ? "—" : callSheet.basecamp)
                        .font(PrintDesign.tinyFont)
                        .lineLimit(1)

                    if !callSheet.parkingInstructions.isEmpty {
                        Text("PARKING: \(callSheet.parkingInstructions)")
                            .font(PrintDesign.tinyFont)
                            .foregroundColor(PrintDesign.mediumGray)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Hospital Box

struct PrintHospitalBox: View {
    let callSheet: CallSheet

    var body: some View {
        PrintBox(title: "NEAREST HOSPITAL", accent: .red) {
            VStack(alignment: .leading, spacing: 1) {
                Text(callSheet.nearestHospital.isEmpty ? "—" : callSheet.nearestHospital)
                    .font(Font.system(size: 8, weight: .semibold))
                    .lineLimit(1)

                if !callSheet.hospitalAddress.isEmpty {
                    Text(callSheet.hospitalAddress)
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.darkGray)
                        .lineLimit(1)
                }

                if !callSheet.hospitalPhone.isEmpty {
                    Text(callSheet.hospitalPhone)
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.black)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Schedule Table

struct PrintScheduleTable: View {
    let items: [ScheduleItem]

    init(items: [ScheduleItem]) {
        self.items = items
        print("📄 PrintScheduleTable: Initialized with \(items.count) items")
        for (index, item) in items.prefix(3).enumerated() {
            print("📄   [\(index)] Scene '\(item.sceneNumber)' - '\(item.intExt.rawValue). \(item.setDescription)'")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - compact to match row height
            HStack(spacing: 0) {
                Text("SC")
                    .frame(width: 30, alignment: .center)
                PrintVerticalDivider()
                Text("SET / DESCRIPTION")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 2)
                PrintVerticalDivider()
                Text("D/N")
                    .frame(width: 45, alignment: .center)
                PrintVerticalDivider()
                Text("PGS")
                    .frame(width: 30, alignment: .center)
                PrintVerticalDivider()
                Text("CAST")
                    .frame(width: 50, alignment: .center)
                PrintVerticalDivider()
                Text("LOCATION")
                    .frame(width: 80, alignment: .center)
            }
            .font(Font.system(size: 6, weight: .bold))
            .foregroundColor(PrintDesign.black)
            .frame(height: 12)
            .background(PrintDesign.lightGray)

            PrintDivider()

            // Rows - compact height for fitting more scenes
            ForEach(items) { item in
                HStack(spacing: 0) {
                    // Strip color (full row background)
                    Rectangle()
                        .fill(stripColor(item: item))
                        .frame(width: 4)

                    // Scene number
                    Text(item.sceneNumber)
                        .font(Font.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundColor(PrintDesign.black)
                        .frame(width: 26, alignment: .center)

                    PrintVerticalDivider()

                    // Description - single line for compactness
                    Text("\(item.intExt.rawValue). \(item.setDescription)")
                        .font(Font.system(size: 6))
                        .foregroundColor(PrintDesign.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 2)

                    PrintVerticalDivider()

                    // Day/Night
                    Text(item.dayNight.rawValue)
                        .font(Font.system(size: 5))
                        .foregroundColor(PrintDesign.black)
                        .frame(width: 45, alignment: .center)

                    PrintVerticalDivider()

                    // Pages
                    Text(String(format: "%.1f", item.pages))
                        .font(Font.system(size: 6))
                        .foregroundColor(PrintDesign.black)
                        .frame(width: 30, alignment: .center)

                    PrintVerticalDivider()

                    // Cast
                    Text(item.castIds.joined(separator: ","))
                        .font(Font.system(size: 5, design: .monospaced))
                        .foregroundColor(PrintDesign.black)
                        .frame(width: 50, alignment: .center)

                    PrintVerticalDivider()

                    // Location
                    Text(item.location)
                        .font(Font.system(size: 5))
                        .foregroundColor(PrintDesign.black)
                        .frame(width: 80, alignment: .center)
                        .lineLimit(1)
                }
                .frame(height: 12) // Compact row height
                .background(stripColor(item: item).opacity(0.3))

                PrintDivider()
            }
        }
        .overlay(
            Rectangle()
                .stroke(PrintDesign.black, lineWidth: PrintDesign.borderWidth)
        )
    }

    // Strip colors matching Scheduler defaults
    private func stripColor(item: ScheduleItem) -> Color {
        switch (item.intExt, item.dayNight) {
        case (.int, .day), (.int, .morning), (.int, .afternoon), (.int, .later), (.int, .sameTime), (.int, .continuous), (.int, .momentsLater):
            // INT DAY - warm white/cream (Scheduler default: 0.98,0.97,0.95)
            return Color(red: 0.98, green: 0.97, blue: 0.95)
        case (.ext, .day), (.ext, .morning), (.ext, .afternoon), (.ext, .later), (.ext, .sameTime), (.ext, .continuous), (.ext, .momentsLater):
            // EXT DAY - yellow (Scheduler default: 1.0,0.97,0.75)
            return Color(red: 1.0, green: 0.97, blue: 0.75)
        case (.int, .night), (.int, .evening), (.int, .dusk):
            // INT NIGHT - blue (Scheduler default: 0.88,0.92,0.98)
            return Color(red: 0.88, green: 0.92, blue: 0.98)
        case (.ext, .night), (.ext, .evening), (.ext, .dusk):
            // EXT NIGHT - green (Scheduler default: 0.90,0.96,0.89)
            return Color(red: 0.90, green: 0.96, blue: 0.89)
        case (.int, .dawn), (.ext, .dawn):
            // Dawn - orange tint
            return Color(red: 1.0, green: 0.9, blue: 0.8)
        default:
            return Color(white: 0.95)
        }
    }
}

// MARK: - Cast Table

struct PrintCastTable: View {
    let cast: [CastMember]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 20, alignment: .center)
                PrintVerticalDivider()
                Text("CHARACTER")
                    .frame(width: 80, alignment: .leading)
                    .padding(.leading, 4)
                PrintVerticalDivider()
                Text("ACTOR")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                PrintVerticalDivider()
                Text("STS")
                    .frame(width: 25, alignment: .center)
                PrintVerticalDivider()
                Text("PICKUP")
                    .frame(width: 50, alignment: .center)
                PrintVerticalDivider()
                Text("MU/HAIR")
                    .frame(width: 50, alignment: .center)
                PrintVerticalDivider()
                Text("ON SET")
                    .frame(width: 50, alignment: .center)
                PrintVerticalDivider()
                Text("REMARKS")
                    .frame(width: 100, alignment: .leading)
                    .padding(.leading, 4)
            }
            .font(PrintDesign.headerFont)
            .foregroundColor(PrintDesign.black)
            .padding(.vertical, 3)
            .background(PrintDesign.lightGray)

            PrintDivider()

            // Rows
            ForEach(cast) { member in
                HStack(spacing: 0) {
                    Text("\(member.castNumber)")
                        .font(Font.system(size: 8, weight: .bold, design: .monospaced))
                        .frame(width: 20, alignment: .center)

                    PrintVerticalDivider()

                    Text(member.role)
                        .font(Font.system(size: 7, weight: .semibold))
                        .frame(width: 80, alignment: .leading)
                        .padding(.leading, 4)
                        .lineLimit(1)

                    PrintVerticalDivider()

                    Text(member.actorName)
                        .font(PrintDesign.smallFont)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .lineLimit(1)

                    PrintVerticalDivider()

                    Text(member.status.rawValue)
                        .font(Font.system(size: 7, weight: .bold))
                        .foregroundColor(member.status.color)
                        .frame(width: 25, alignment: .center)

                    PrintVerticalDivider()

                    Text(member.pickupTime)
                        .font(PrintDesign.tinyFont)
                        .frame(width: 50, alignment: .center)

                    PrintVerticalDivider()

                    Text(member.reportToMakeup)
                        .font(PrintDesign.tinyFont)
                        .frame(width: 50, alignment: .center)

                    PrintVerticalDivider()

                    Text(member.reportToSet)
                        .font(PrintDesign.tinyFont)
                        .frame(width: 50, alignment: .center)

                    PrintVerticalDivider()

                    Text(member.remarks)
                        .font(PrintDesign.tinyFont)
                        .foregroundColor(PrintDesign.mediumGray)
                        .frame(width: 100, alignment: .leading)
                        .padding(.leading, 4)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)

                PrintDivider()
            }
        }
        .overlay(
            Rectangle()
                .stroke(PrintDesign.black, lineWidth: PrintDesign.borderWidth)
        )
    }
}

// MARK: - Crew Section (Compact)

struct PrintCrewSection: View {
    let crew: [CrewMember]

    private var groupedCrew: [(CrewDepartment, [CrewMember])] {
        let grouped = Dictionary(grouping: crew) { $0.department }
        return grouped.sorted { $0.key.sortOrder < $1.key.sortOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CREW")
                    .font(PrintDesign.headerFont)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(PrintDesign.lightGray)

            PrintDivider()

            // Crew in columns by department
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 4) {
                ForEach(groupedCrew, id: \.0) { dept, members in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(dept.rawValue.uppercased())
                            .font(PrintDesign.tinyFont)
                            .foregroundColor(PrintDesign.mediumGray)

                        ForEach(members) { member in
                            HStack(spacing: 4) {
                                Text(member.position)
                                    .font(PrintDesign.tinyFont)
                                    .foregroundColor(PrintDesign.mediumGray)
                                    .frame(width: 50, alignment: .trailing)
                                Text(member.name)
                                    .font(PrintDesign.smallFont)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(4)
                }
            }
            .padding(4)
        }
        .overlay(
            Rectangle()
                .stroke(PrintDesign.black, lineWidth: PrintDesign.borderWidth)
        )
    }
}

// MARK: - Notes Box

struct PrintNotesBox: View {
    let title: String
    let content: String

    var body: some View {
        PrintBox(title: title) {
            Text(content)
                .font(PrintDesign.smallFont)
                .foregroundColor(PrintDesign.darkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Safety Footer

struct PrintSafetyFooter: View {
    let notes: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)

            Text(notes.isEmpty ? "SAFETY FIRST | NO SMOKING ON SET | NO VISITORS WITHOUT PRIOR APPROVAL" : notes)
                .font(Font.system(size: 7, weight: .bold))
                .foregroundColor(PrintDesign.black)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Helper Components

struct PrintBox<Content: View>: View {
    let title: String
    var accent: Color = PrintDesign.black
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(PrintDesign.headerFont)
                    .foregroundColor(accent)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(PrintDesign.lightGray)

            PrintDivider()

            content()
                .padding(4)
        }
        .overlay(
            Rectangle()
                .stroke(accent, lineWidth: PrintDesign.borderWidth)
        )
    }
}

struct PrintDivider: View {
    var body: some View {
        Rectangle()
            .fill(PrintDesign.black)
            .frame(height: PrintDesign.borderWidth)
    }
}

struct PrintVerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(PrintDesign.black)
            .frame(width: PrintDesign.borderWidth)
    }
}

// MARK: - Preview

#if DEBUG
struct CallSheetPrintLayout_Previews: PreviewProvider {
    static var previews: some View {
        CallSheetPrintLayout(callSheet: CallSheet.sample())
            .previewLayout(.fixed(width: 612, height: 792))
    }
}
#endif
