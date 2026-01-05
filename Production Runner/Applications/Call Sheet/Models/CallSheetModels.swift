// MARK: - Call Sheet Models
// Production Runner - Call Sheet Module
// Models, Enums, and Templates for Call Sheets

import SwiftUI
import Foundation

// MARK: - Call Sheet Status

enum CallSheetStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "Draft"
    case ready = "Ready"
    case sent = "Sent"
    case revised = "Revised"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .draft: return .orange
        case .ready: return .green
        case .sent: return .blue
        case .revised: return .purple
        }
    }

    var icon: String {
        switch self {
        case .draft: return "pencil.circle"
        case .ready: return "checkmark.circle"
        case .sent: return "paperplane.circle"
        case .revised: return "arrow.triangle.2.circlepath.circle"
        }
    }
}

// MARK: - Call Sheet Section Type

enum CallSheetSectionType: String, Codable, CaseIterable, Identifiable {
    case header = "Header"
    case productionInfo = "Production Info"
    case callTimes = "Call Times"
    case location = "Location"
    case weather = "Weather"
    case schedule = "Shooting Schedule"
    case cast = "Cast"
    case crew = "Crew"
    case background = "Background/Extras"
    case productionNotes = "Production Notes"
    case advanceSchedule = "Advance Schedule"
    case safetyInfo = "Safety Information"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .header: return "doc.text"
        case .productionInfo: return "film"
        case .callTimes: return "clock"
        case .location: return "mappin.and.ellipse"
        case .weather: return "cloud.sun"
        case .schedule: return "list.bullet.rectangle"
        case .cast: return "person.2"
        case .crew: return "person.3"
        case .background: return "person.3.sequence"
        case .productionNotes: return "note.text"
        case .advanceSchedule: return "calendar.badge.clock"
        case .safetyInfo: return "cross.circle"
        }
    }

    var defaultVisible: Bool {
        switch self {
        case .background: return false // Often not needed
        default: return true
        }
    }
}

// MARK: - Call Sheet Template Type

enum CallSheetTemplateType: String, Codable, CaseIterable, Identifiable {
    case featureFilm = "Feature Film"
    case tvEpisode = "TV Episode"
    case commercial = "Commercial"
    case musicVideo = "Music Video"
    case documentary = "Documentary"
    case shortFilm = "Short Film"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .featureFilm: return "film"
        case .tvEpisode: return "tv"
        case .commercial: return "megaphone"
        case .musicVideo: return "music.note"
        case .documentary: return "video"
        case .shortFilm: return "film.stack"
        case .custom: return "slider.horizontal.3"
        }
    }

    var description: String {
        switch self {
        case .featureFilm: return "Full crew grid, detailed schedule, all departments"
        case .tvEpisode: return "Episode info, series regulars, day players"
        case .commercial: return "Client info, agency contacts, product details"
        case .musicVideo: return "Artist info, playback times, choreography notes"
        case .documentary: return "Interview schedule, B-roll notes, minimal crew"
        case .shortFilm: return "Streamlined layout for smaller productions"
        case .custom: return "Build your own template from scratch"
        }
    }

    /// Default section order for this template type
    var defaultSectionOrder: [CallSheetSectionType] {
        switch self {
        case .featureFilm, .tvEpisode:
            return [
                .header, .productionInfo, .callTimes, .weather,
                .location, .schedule, .cast, .background,
                .crew, .productionNotes, .advanceSchedule, .safetyInfo
            ]
        case .commercial:
            return [
                .header, .productionInfo, .callTimes, .weather,
                .location, .schedule, .cast, .crew,
                .productionNotes, .safetyInfo
            ]
        case .musicVideo:
            return [
                .header, .productionInfo, .callTimes, .weather,
                .location, .schedule, .cast, .crew,
                .productionNotes, .safetyInfo
            ]
        case .documentary:
            return [
                .header, .productionInfo, .callTimes, .weather,
                .location, .schedule, .crew,
                .productionNotes, .safetyInfo
            ]
        case .shortFilm:
            return [
                .header, .callTimes, .weather, .location,
                .schedule, .cast, .crew, .productionNotes, .safetyInfo
            ]
        case .custom:
            return CallSheetSectionType.allCases
        }
    }

    /// Default visible sections for this template
    var defaultVisibleSections: Set<CallSheetSectionType> {
        switch self {
        case .featureFilm, .tvEpisode:
            return Set(CallSheetSectionType.allCases)
        case .commercial, .musicVideo:
            return Set(CallSheetSectionType.allCases.filter { $0 != .background && $0 != .advanceSchedule })
        case .documentary:
            return Set([.header, .productionInfo, .callTimes, .weather, .location, .schedule, .crew, .productionNotes, .safetyInfo])
        case .shortFilm:
            return Set([.header, .callTimes, .weather, .location, .schedule, .cast, .crew, .productionNotes, .safetyInfo])
        case .custom:
            return Set(CallSheetSectionType.allCases)
        }
    }
}

// MARK: - Section Configuration

struct CallSheetSectionConfig: Codable, Identifiable, Hashable {
    var id: String { sectionType.rawValue }
    var sectionType: CallSheetSectionType
    var isVisible: Bool
    var isCollapsed: Bool
    var customTitle: String?

    init(sectionType: CallSheetSectionType, isVisible: Bool = true, isCollapsed: Bool = false, customTitle: String? = nil) {
        self.sectionType = sectionType
        self.isVisible = isVisible
        self.isCollapsed = isCollapsed
        self.customTitle = customTitle
    }

    var displayTitle: String {
        customTitle ?? sectionType.rawValue
    }
}

// MARK: - Main Call Sheet Model

struct CallSheet: Identifiable, Hashable, Codable {
    var id: UUID = UUID()

    // MARK: Basic Info
    var title: String
    var projectName: String
    var productionCompany: String
    var productionCompanyImageData: Data?
    var shootDate: Date
    var dayNumber: Int
    var totalDays: Int
    var status: CallSheetStatus
    var templateType: CallSheetTemplateType

    // MARK: Section Configuration
    var sectionOrder: [CallSheetSectionType]
    var sectionConfigs: [CallSheetSectionConfig]

    // MARK: Key Personnel
    var director: String
    var firstAD: String
    var secondAD: String
    var producer: String
    var lineProducer: String
    var upm: String // Unit Production Manager
    var dop: String
    var productionManager: String
    var productionCoordinator: String

    // MARK: Call Times
    var crewCall: Date?
    var onSetCall: Date?
    var shootingCall: Date?
    var firstShotCall: Date?
    var breakfast: Date?
    var lunch: Date?
    var secondMeal: Date?
    var estimatedWrap: Date?
    var hardOut: Date? // Union-mandated or location hard out
    var gracePeriod: String // e.g., "12-hour turnaround"

    // MARK: Location Info
    var shootingLocation: String
    var locationAddress: String
    var locationContact: String
    var locationPhone: String
    var parkingInstructions: String
    var basecamp: String
    var basecampAddress: String
    var crewParking: String
    var talentParking: String
    var nearestHospital: String
    var hospitalAddress: String
    var hospitalPhone: String

    // MARK: Weather
    var weatherHigh: String
    var weatherLow: String
    var weatherConditions: String
    var sunrise: String
    var sunset: String
    var humidity: String
    var windSpeed: String
    var precipitation: String

    // MARK: Content Arrays
    var scheduleItems: [ScheduleItem]
    var castMembers: [CastMember]
    var crewMembers: [CrewMember]
    var backgroundActors: [BackgroundActor]

    // MARK: Notes
    var productionNotes: String
    var safetyNotes: String
    var advanceSchedule: String
    var specialEquipment: String
    var walkie: String // Walkie-talkie channel assignments

    // MARK: Metadata
    var createdDate: Date
    var lastModified: Date
    var revisionNumber: Int
    var revisionColor: RevisionColor

    // MARK: - Initialization

    static func empty(template: CallSheetTemplateType = .featureFilm) -> CallSheet {
        let calendar = Calendar.current
        let now = Date()

        let sectionOrder = template.defaultSectionOrder
        let visibleSections = template.defaultVisibleSections
        let configs = sectionOrder.map { section in
            CallSheetSectionConfig(
                sectionType: section,
                isVisible: visibleSections.contains(section)
            )
        }

        return CallSheet(
            title: "Untitled Call Sheet",
            projectName: "",
            productionCompany: "",
            productionCompanyImageData: nil,
            shootDate: Date(),
            dayNumber: 1,
            totalDays: 1,
            status: .draft,
            templateType: template,
            sectionOrder: sectionOrder,
            sectionConfigs: configs,
            director: "",
            firstAD: "",
            secondAD: "",
            producer: "",
            lineProducer: "",
            upm: "",
            dop: "",
            productionManager: "",
            productionCoordinator: "",
            crewCall: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now),
            onSetCall: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now),
            shootingCall: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now),
            firstShotCall: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: now),
            breakfast: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now),
            lunch: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: now),
            secondMeal: nil,
            estimatedWrap: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now),
            hardOut: nil,
            gracePeriod: "12-hour turnaround",
            shootingLocation: "",
            locationAddress: "",
            locationContact: "",
            locationPhone: "",
            parkingInstructions: "",
            basecamp: "",
            basecampAddress: "",
            crewParking: "",
            talentParking: "",
            nearestHospital: "",
            hospitalAddress: "",
            hospitalPhone: "",
            weatherHigh: "",
            weatherLow: "",
            weatherConditions: "",
            sunrise: "",
            sunset: "",
            humidity: "",
            windSpeed: "",
            precipitation: "",
            scheduleItems: [],
            castMembers: [],
            crewMembers: [],
            backgroundActors: [],
            productionNotes: "",
            safetyNotes: "SAFETY FIRST | NO SMOKING ON SET | NO VISITORS WITHOUT PRIOR APPROVAL",
            advanceSchedule: "",
            specialEquipment: "",
            walkie: "",
            createdDate: Date(),
            lastModified: Date(),
            revisionNumber: 0,
            revisionColor: .white
        )
    }

    // MARK: - Helpers

    var visibleSections: [CallSheetSectionType] {
        sectionOrder.filter { section in
            sectionConfigs.first { $0.sectionType == section }?.isVisible ?? true
        }
    }

    mutating func toggleSection(_ section: CallSheetSectionType) {
        if let index = sectionConfigs.firstIndex(where: { $0.sectionType == section }) {
            sectionConfigs[index].isVisible.toggle()
        }
    }

    mutating func moveSection(from source: IndexSet, to destination: Int) {
        sectionOrder.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Schedule Item

struct ScheduleItem: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var sceneNumber: String
    var setDescription: String
    var intExt: IntExt
    var dayNight: DayNight
    var pages: Double
    var estimatedTime: String
    var castIds: [String] // Character numbers or names
    var location: String
    var notes: String
    var specialRequirements: String
    var sortOrder: Int

    enum IntExt: String, Codable, CaseIterable {
        case int = "INT"
        case ext = "EXT"
        case intExt = "INT/EXT"

        var color: Color {
            switch self {
            case .int: return .orange
            case .ext: return .green
            case .intExt: return .blue
            }
        }
    }

    enum DayNight: String, Codable, CaseIterable {
        case day = "DAY"
        case night = "NIGHT"
        case dawn = "DAWN"
        case dusk = "DUSK"
        case morning = "MORNING"
        case afternoon = "AFTERNOON"
        case evening = "EVENING"
        case continuous = "CONTINUOUS"
        case later = "LATER"
        case momentsLater = "MOMENTS LATER"
        case sameTime = "SAME TIME"

        var color: Color {
            switch self {
            case .day, .morning, .afternoon: return .yellow
            case .night, .evening: return .indigo
            case .dawn, .dusk: return .orange
            default: return .gray
            }
        }
    }

    static func empty() -> ScheduleItem {
        ScheduleItem(
            sceneNumber: "",
            setDescription: "",
            intExt: .int,
            dayNight: .day,
            pages: 0,
            estimatedTime: "",
            castIds: [],
            location: "",
            notes: "",
            specialRequirements: "",
            sortOrder: 0
        )
    }
}

// MARK: - Cast Member

struct CastMember: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var castNumber: Int
    var role: String  // Character/role name (pulled from Contacts for cast members)
    var actorName: String
    var status: CastStatus
    var pickupTime: String
    var reportToMakeup: String
    var reportToSet: String
    var remarks: String
    var phone: String
    var email: String
    var daysWorked: Int
    var isStunt: Bool
    var isPhotoDouble: Bool

    // Legacy support for existing data stored as "characterName"
    enum CodingKeys: String, CodingKey {
        case id, castNumber, actorName, status, pickupTime, reportToMakeup
        case reportToSet, remarks, phone, email, daysWorked, isStunt, isPhotoDouble
        case role = "characterName"  // Map old key to new property
    }

    enum CastStatus: String, Codable, CaseIterable {
        case work = "W"      // Working
        case hold = "H"      // On hold
        case start = "SW"    // Start Work
        case finish = "WF"   // Work Finish
        case travel = "T"    // Travel
        case rehearse = "R"  // Rehearse
        case fitting = "F"   // Wardrobe Fitting
        case test = "WT"     // Wardrobe/Test

        var fullName: String {
            switch self {
            case .work: return "Work"
            case .hold: return "Hold"
            case .start: return "Start Work"
            case .finish: return "Work Finish"
            case .travel: return "Travel"
            case .rehearse: return "Rehearse"
            case .fitting: return "Fitting"
            case .test: return "Wardrobe/Test"
            }
        }

        var color: Color {
            switch self {
            case .work: return .green
            case .hold: return .orange
            case .start: return .blue
            case .finish: return .purple
            case .travel: return .gray
            case .rehearse: return .cyan
            case .fitting: return .pink
            case .test: return .yellow
            }
        }
    }

    static func empty() -> CastMember {
        CastMember(
            castNumber: 1,
            role: "",
            actorName: "",
            status: .work,
            pickupTime: "",
            reportToMakeup: "",
            reportToSet: "",
            remarks: "",
            phone: "",
            email: "",
            daysWorked: 1,
            isStunt: false,
            isPhotoDouble: false
        )
    }
}

// MARK: - Crew Member

struct CrewMember: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var department: CrewDepartment
    var position: String
    var name: String
    var phone: String
    var email: String
    var callTime: String
    var notes: String

    static func empty() -> CrewMember {
        CrewMember(
            department: .production,
            position: "",
            name: "",
            phone: "",
            email: "",
            callTime: "",
            notes: ""
        )
    }
}

// MARK: - Crew Department

enum CrewDepartment: String, Codable, CaseIterable, Identifiable {
    case production = "Production"
    case direction = "Direction"
    case camera = "Camera"
    case sound = "Sound"
    case electric = "Electric"
    case grip = "Grip"
    case art = "Art"
    case setDec = "Set Dec"
    case props = "Props"
    case costume = "Costume"
    case hairMakeup = "Hair & Makeup"
    case locations = "Locations"
    case transportation = "Transportation"
    case catering = "Catering/Craft Services"
    case medic = "Medic/Safety"
    case postProduction = "Post Production"
    case stunts = "Stunts"
    case specialEffects = "Special Effects"
    case visualEffects = "Visual Effects"
    case animals = "Animal Wrangling"
    case publicist = "Publicity"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .production: return "building.2"
        case .direction: return "megaphone"
        case .camera: return "camera"
        case .sound: return "waveform"
        case .electric: return "bolt"
        case .grip: return "wrench.and.screwdriver"
        case .art: return "paintbrush"
        case .setDec: return "sofa"
        case .props: return "cube"
        case .costume: return "tshirt"
        case .hairMakeup: return "comb"
        case .locations: return "map"
        case .transportation: return "car"
        case .catering: return "fork.knife"
        case .medic: return "cross.case"
        case .postProduction: return "film.stack"
        case .stunts: return "figure.run"
        case .specialEffects: return "sparkles"
        case .visualEffects: return "wand.and.stars"
        case .animals: return "pawprint"
        case .publicist: return "newspaper"
        case .other: return "ellipsis.circle"
        }
    }

    var sortOrder: Int {
        switch self {
        case .production: return 0
        case .direction: return 1
        case .camera: return 2
        case .sound: return 3
        case .electric: return 4
        case .grip: return 5
        case .art: return 6
        case .setDec: return 7
        case .props: return 8
        case .costume: return 9
        case .hairMakeup: return 10
        case .locations: return 11
        case .transportation: return 12
        case .catering: return 13
        case .medic: return 14
        case .stunts: return 15
        case .specialEffects: return 16
        case .visualEffects: return 17
        case .animals: return 18
        case .publicist: return 19
        case .postProduction: return 20
        case .other: return 99
        }
    }

    /// Keywords to match contacts by role for this department
    var roleKeywords: [String] {
        switch self {
        case .production: return ["producer", "production", "upm", "coordinator", "accountant", "assistant"]
        case .direction: return ["director", "ad", "assistant director", "1st ad", "2nd ad", "script supervisor"]
        case .camera: return ["camera", "dp", "dop", "cinematographer", "operator", "focus", "loader", "dit"]
        case .sound: return ["sound", "audio", "mixer", "boom"]
        case .electric: return ["electric", "gaffer", "best boy", "lighting", "electrician"]
        case .grip: return ["grip", "key grip", "dolly", "rigging"]
        case .art: return ["art", "production designer", "art director"]
        case .setDec: return ["set dec", "decorator", "leadman", "buyer"]
        case .props: return ["prop", "props"]
        case .costume: return ["costume", "wardrobe", "stylist"]
        case .hairMakeup: return ["hair", "makeup", "mua", "hmu"]
        case .locations: return ["location", "scout"]
        case .transportation: return ["transport", "driver", "teamster"]
        case .catering: return ["catering", "craft", "chef"]
        case .medic: return ["medic", "nurse", "safety", "emt"]
        case .stunts: return ["stunt", "coordinator", "performer"]
        case .specialEffects: return ["sfx", "special effect", "pyro"]
        case .visualEffects: return ["vfx", "visual effect", "cgi"]
        case .animals: return ["animal", "wrangler", "trainer"]
        case .publicist: return ["publicist", "publicity", "press"]
        case .postProduction: return ["post", "editor", "color", "conform"]
        case .other: return []
        }
    }
}

// MARK: - Background Actor

struct BackgroundActor: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var count: Int
    var description: String
    var callTime: String
    var wrapTime: String
    var wardrobeNotes: String
    var reportTo: String
    var scenes: [String]

    static func empty() -> BackgroundActor {
        BackgroundActor(
            count: 1,
            description: "",
            callTime: "",
            wrapTime: "",
            wardrobeNotes: "",
            reportTo: "",
            scenes: []
        )
    }
}

// MARK: - Revision Color (Industry Standard)

enum RevisionColor: String, Codable, CaseIterable, Identifiable {
    case white = "White"      // Original
    case blue = "Blue"        // 1st Revision
    case pink = "Pink"        // 2nd Revision
    case yellow = "Yellow"    // 3rd Revision
    case green = "Green"      // 4th Revision
    case goldenrod = "Goldenrod" // 5th Revision
    case buff = "Buff"        // 6th Revision
    case salmon = "Salmon"    // 7th Revision
    case cherry = "Cherry"    // 8th Revision
    case tan = "Tan"          // 9th Revision
    case ivory = "Ivory"      // 10th Revision (then back to blue)

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white: return Color(white: 1.0)
        case .blue: return Color(red: 0.7, green: 0.85, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.8, blue: 0.85)
        case .yellow: return Color(red: 1.0, green: 1.0, blue: 0.7)
        case .green: return Color(red: 0.7, green: 1.0, blue: 0.7)
        case .goldenrod: return Color(red: 0.98, green: 0.85, blue: 0.4)
        case .buff: return Color(red: 0.96, green: 0.87, blue: 0.7)
        case .salmon: return Color(red: 1.0, green: 0.7, blue: 0.65)
        case .cherry: return Color(red: 1.0, green: 0.6, blue: 0.6)
        case .tan: return Color(red: 0.82, green: 0.71, blue: 0.55)
        case .ivory: return Color(red: 1.0, green: 1.0, blue: 0.94)
        }
    }

    var revisionNumber: Int {
        switch self {
        case .white: return 0
        case .blue: return 1
        case .pink: return 2
        case .yellow: return 3
        case .green: return 4
        case .goldenrod: return 5
        case .buff: return 6
        case .salmon: return 7
        case .cherry: return 8
        case .tan: return 9
        case .ivory: return 10
        }
    }

    static func forRevision(_ number: Int) -> RevisionColor {
        let cycled = number % 11
        return RevisionColor.allCases.first { $0.revisionNumber == cycled } ?? .white
    }

    var next: RevisionColor {
        RevisionColor.forRevision(revisionNumber + 1)
    }
}

// MARK: - Sample Data

extension CallSheet {
    static func sample() -> CallSheet {
        var sheet = CallSheet.empty(template: .featureFilm)
        sheet.title = "Day 2 Call Sheet"
        sheet.projectName = "\"THE LAST HORIZON\""
        sheet.productionCompany = "SUNSET FILMS"
        sheet.dayNumber = 2
        sheet.totalDays = 25
        sheet.status = .ready

        sheet.director = "Sarah Mitchell"
        sheet.firstAD = "James Chen"
        sheet.secondAD = "Maria Garcia"
        sheet.producer = "Robert Williams"
        sheet.dop = "Alex Turner"
        sheet.upm = "Lisa Park"

        sheet.shootingLocation = "Fernlea House"
        sheet.locationAddress = "18627 Fernlea Dr.\nMacomb, MI 48044"
        sheet.parkingInstructions = "Street parking - Camera & G&E park closest to house"
        sheet.basecamp = "Community Center Lot"
        sheet.basecampAddress = "15855 19 Mile Rd\nClinton Twp, MI 48038"
        sheet.nearestHospital = "McLaren Macomb"
        sheet.hospitalAddress = "11800 E 12 Mile Rd"
        sheet.hospitalPhone = "(586) 493-8000"

        sheet.weatherHigh = "53°F"
        sheet.weatherLow = "44°F"
        sheet.weatherConditions = "Partly Cloudy"
        sheet.sunrise = "7:16 AM"
        sheet.sunset = "5:16 PM"
        sheet.humidity = "65%"
        sheet.windSpeed = "8 mph NW"
        sheet.precipitation = "10%"

        sheet.scheduleItems = [
            ScheduleItem(
                sceneNumber: "17",
                setDescription: "TINA'S CAR (PARKED) - BOBBY'S ROADSIDE MEMORIAL",
                intExt: .int,
                dayNight: .later,
                pages: 1.0,
                estimatedTime: "2 hrs",
                castIds: ["1", "2", "3"],
                location: "Fernlea House Driveway",
                notes: "Rick berates Eric in the car while Tina adjusts the memorial",
                specialRequirements: "Car rig needed",
                sortOrder: 0
            ),
            ScheduleItem(
                sceneNumber: "18",
                setDescription: "WOODS - NEAR ROADSIDE MEMORIAL",
                intExt: .ext,
                dayNight: .momentsLater,
                pages: 0.375,
                estimatedTime: "45 min",
                castIds: ["1"],
                location: "Woods behind house",
                notes: "Eric finds Bobby's closet key",
                specialRequirements: "Prop key, flashlight",
                sortOrder: 1
            )
        ]

        sheet.castMembers = [
            CastMember(
                castNumber: 1,
                role: "Eric",
                actorName: "John Smith",
                status: .work,
                pickupTime: "8:30 AM",
                reportToMakeup: "9:00 AM",
                reportToSet: "10:00 AM",
                remarks: "Scenes 17, 18",
                phone: "(555) 123-4567",
                email: "john@example.com",
                daysWorked: 2,
                isStunt: false,
                isPhotoDouble: false
            ),
            CastMember(
                castNumber: 2,
                role: "Tina",
                actorName: "Jane Doe",
                status: .work,
                pickupTime: "9:00 AM",
                reportToMakeup: "9:30 AM",
                reportToSet: "10:30 AM",
                remarks: "Scene 17 only",
                phone: "(555) 234-5678",
                email: "jane@example.com",
                daysWorked: 2,
                isStunt: false,
                isPhotoDouble: false
            ),
            CastMember(
                castNumber: 3,
                role: "Rick",
                actorName: "Mike Johnson",
                status: .start,
                pickupTime: "9:30 AM",
                reportToMakeup: "10:00 AM",
                reportToSet: "11:00 AM",
                remarks: "First day - Scene 17",
                phone: "(555) 345-6789",
                email: "mike@example.com",
                daysWorked: 1,
                isStunt: false,
                isPhotoDouble: false
            )
        ]

        sheet.crewMembers = [
            CrewMember(department: .camera, position: "1st AC", name: "Tom Baker", phone: "(555) 111-2222", email: "", callTime: "7:00 AM", notes: ""),
            CrewMember(department: .camera, position: "2nd AC", name: "Amy Lee", phone: "(555) 222-3333", email: "", callTime: "7:00 AM", notes: ""),
            CrewMember(department: .sound, position: "Sound Mixer", name: "David Kim", phone: "(555) 333-4444", email: "", callTime: "7:30 AM", notes: ""),
            CrewMember(department: .grip, position: "Key Grip", name: "Steve Brown", phone: "(555) 444-5555", email: "", callTime: "6:30 AM", notes: ""),
            CrewMember(department: .electric, position: "Gaffer", name: "Chris White", phone: "(555) 555-6666", email: "", callTime: "6:30 AM", notes: "")
        ]

        sheet.productionNotes = "• Car rig required for Scene 17 - coordinate with camera dept\n• Quiet on set - residential neighborhood\n• Walkie Channel 1: Production, Channel 2: Camera/Electric"
        sheet.advanceSchedule = "DAY 3: INT. BOBBY'S HOUSE - LIVING ROOM (Scenes 19-22)"

        return sheet
    }
}

// MARK: - Delivery Tracking Models

/// Method of delivery for call sheets
enum DeliveryMethod: String, Codable, CaseIterable, Identifiable {
    case email = "Email"
    case sms = "SMS"

    var id: String { rawValue }
}

/// Status of a delivery
enum DeliveryStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case sending = "Sending"
    case sent = "Sent"
    case delivered = "Delivered"
    case viewed = "Viewed"
    case confirmed = "Confirmed"
    case failed = "Failed"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .sending: return .orange
        case .sent: return .blue
        case .delivered: return .cyan
        case .viewed: return .purple
        case .confirmed: return .green
        case .failed: return .red
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .sending: return "arrow.up.circle"
        case .sent: return "paperplane"
        case .delivered: return "checkmark"
        case .viewed: return "eye"
        case .confirmed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }

    /// Whether this is a terminal state
    var isFinal: Bool {
        switch self {
        case .confirmed, .failed:
            return true
        default:
            return false
        }
    }
}

/// A recipient for call sheet delivery
struct DeliveryRecipient: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var email: String?
    var phone: String?
    var method: DeliveryMethod
    var status: DeliveryStatus
    var isSelected: Bool
    var sentAt: Date?
    var deliveredAt: Date?
    var viewedAt: Date?
    var confirmedAt: Date?
    var failureReason: String?
    var twilioMessageSid: String?  // For SMS tracking

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        phone: String? = nil,
        method: DeliveryMethod = .email,
        status: DeliveryStatus = .pending,
        isSelected: Bool = true,
        sentAt: Date? = nil,
        deliveredAt: Date? = nil,
        viewedAt: Date? = nil,
        confirmedAt: Date? = nil,
        failureReason: String? = nil,
        twilioMessageSid: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.method = method
        self.status = status
        self.isSelected = isSelected
        self.sentAt = sentAt
        self.deliveredAt = deliveredAt
        self.viewedAt = viewedAt
        self.confirmedAt = confirmedAt
        self.failureReason = failureReason
        self.twilioMessageSid = twilioMessageSid
    }

    /// Check if this recipient can receive via the selected method
    var canDeliver: Bool {
        switch method {
        case .email:
            return email != nil && !email!.isEmpty
        case .sms:
            return phone != nil && !phone!.isEmpty
        }
    }

    /// Contact info for the selected delivery method
    var contactInfo: String {
        switch method {
        case .email:
            return email ?? "No email"
        case .sms:
            return phone ?? "No phone"
        }
    }
}

/// A record of a call sheet delivery batch
struct CallSheetDelivery: Identifiable, Codable {
    let id: UUID
    let callSheetID: UUID
    var recipients: [DeliveryRecipient]
    var sentAt: Date?
    var pdfURL: URL?  // Local URL to the PDF file
    var notes: String?

    init(
        id: UUID = UUID(),
        callSheetID: UUID,
        recipients: [DeliveryRecipient] = [],
        sentAt: Date? = nil,
        pdfURL: URL? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.callSheetID = callSheetID
        self.recipients = recipients
        self.sentAt = sentAt
        self.pdfURL = pdfURL
        self.notes = notes
    }

    /// Number of recipients
    var recipientCount: Int {
        recipients.count
    }

    /// Number of successful deliveries
    var successCount: Int {
        recipients.filter { $0.status == .sent || $0.status == .delivered || $0.status == .viewed || $0.status == .confirmed }.count
    }

    /// Number of failed deliveries
    var failureCount: Int {
        recipients.filter { $0.status == .failed }.count
    }

    /// Number of pending deliveries
    var pendingCount: Int {
        recipients.filter { $0.status == .pending || $0.status == .sending }.count
    }

    /// Number of confirmations
    var confirmationCount: Int {
        recipients.filter { $0.status == .confirmed }.count
    }

    /// Overall status summary
    var statusSummary: String {
        if failureCount > 0 {
            return "\(successCount)/\(recipientCount) sent, \(failureCount) failed"
        } else if pendingCount > 0 {
            return "\(successCount)/\(recipientCount) sent"
        } else {
            return "All \(recipientCount) sent"
        }
    }
}
