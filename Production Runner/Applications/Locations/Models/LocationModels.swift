import SwiftUI
import MapKit

// MARK: - Location Folder Model
/// Represents a folder for organizing locations
struct LocationFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var parentFolderID: UUID?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#007AFF",
        iconName: String = "folder.fill",
        parentFolderID: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.parentFolderID = parentFolderID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Location Comment Model
/// Represents a comment/discussion entry for a location
struct LocationComment: Identifiable, Codable, Hashable {
    let id: UUID
    var locationID: UUID
    var authorName: String
    var authorEmail: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var parentCommentID: UUID?  // For threaded replies
    var isResolved: Bool
    var attachmentData: Data?   // Optional image/file attachment
    var attachmentName: String?

    init(
        id: UUID = UUID(),
        locationID: UUID,
        authorName: String,
        authorEmail: String = "",
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        parentCommentID: UUID? = nil,
        isResolved: Bool = false,
        attachmentData: Data? = nil,
        attachmentName: String? = nil
    ) {
        self.id = id
        self.locationID = locationID
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentCommentID = parentCommentID
        self.isResolved = isResolved
        self.attachmentData = attachmentData
        self.attachmentName = attachmentName
    }
}

// MARK: - Location Document Model
/// Represents an attached document (permit, contract, etc.)
struct LocationDocument: Identifiable, Codable, Hashable {
    let id: UUID
    var locationID: UUID
    var name: String
    var documentType: DocumentType
    var fileData: Data
    var fileExtension: String
    var createdAt: Date
    var updatedAt: Date
    var notes: String
    var expirationDate: Date?

    enum DocumentType: String, Codable, CaseIterable {
        case permit = "Permit"
        case contract = "Contract"
        case insurance = "Insurance"
        case release = "Release Form"
        case map = "Map"
        case photo = "Photo"
        case other = "Other"

        var icon: String {
            switch self {
            case .permit: return "doc.badge.checkmark"
            case .contract: return "doc.text.fill"
            case .insurance: return "shield.checkered"
            case .release: return "signature"
            case .map: return "map.fill"
            case .photo: return "photo.fill"
            case .other: return "doc.fill"
            }
        }

        var color: Color {
            switch self {
            case .permit: return .green
            case .contract: return .blue
            case .insurance: return .purple
            case .release: return .orange
            case .map: return .teal
            case .photo: return .pink
            case .other: return .gray
            }
        }
    }

    init(
        id: UUID = UUID(),
        locationID: UUID,
        name: String,
        documentType: DocumentType = .other,
        fileData: Data,
        fileExtension: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: String = "",
        expirationDate: Date? = nil
    ) {
        self.id = id
        self.locationID = locationID
        self.name = name
        self.documentType = documentType
        self.fileData = fileData
        self.fileExtension = fileExtension
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
        self.expirationDate = expirationDate
    }
}

// MARK: - Activity Log Entry Model
/// Represents a change/activity entry for tracking location history
struct ActivityLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var locationID: UUID
    var activityType: ActivityType
    var description: String
    var userName: String
    var timestamp: Date
    var previousValue: String?
    var newValue: String?
    var fieldName: String?

    enum ActivityType: String, Codable, CaseIterable {
        case created = "Created"
        case updated = "Updated"
        case statusChanged = "Status Changed"
        case photoAdded = "Photo Added"
        case photoRemoved = "Photo Removed"
        case documentAdded = "Document Added"
        case documentRemoved = "Document Removed"
        case commentAdded = "Comment Added"
        case assignmentChanged = "Assignment Changed"
        case scoutScheduled = "Scout Scheduled"
        case scouted = "Scouted"
        case approved = "Approved"
        case denied = "Denied"

        var icon: String {
            switch self {
            case .created: return "plus.circle.fill"
            case .updated: return "pencil.circle.fill"
            case .statusChanged: return "arrow.triangle.2.circlepath"
            case .photoAdded: return "photo.badge.plus"
            case .photoRemoved: return "photo.badge.minus"
            case .documentAdded: return "doc.badge.plus"
            case .documentRemoved: return "doc.badge.minus"
            case .commentAdded: return "text.bubble.fill"
            case .assignmentChanged: return "person.badge.clock"
            case .scoutScheduled: return "calendar.badge.plus"
            case .scouted: return "binoculars.fill"
            case .approved: return "checkmark.seal.fill"
            case .denied: return "xmark.seal.fill"
            }
        }

        var color: Color {
            switch self {
            case .created: return .green
            case .updated: return .blue
            case .statusChanged: return .orange
            case .photoAdded, .photoRemoved: return .purple
            case .documentAdded, .documentRemoved: return .teal
            case .commentAdded: return .indigo
            case .assignmentChanged: return .cyan
            case .scoutScheduled: return .mint
            case .scouted: return .yellow
            case .approved: return .green
            case .denied: return .red
            }
        }
    }

    init(
        id: UUID = UUID(),
        locationID: UUID,
        activityType: ActivityType,
        description: String,
        userName: String = "System",
        timestamp: Date = Date(),
        previousValue: String? = nil,
        newValue: String? = nil,
        fieldName: String? = nil
    ) {
        self.id = id
        self.locationID = locationID
        self.activityType = activityType
        self.description = description
        self.userName = userName
        self.timestamp = timestamp
        self.previousValue = previousValue
        self.newValue = newValue
        self.fieldName = fieldName
    }
}

// MARK: - Photo Tag Model
/// Represents a tag/category for organizing photos
struct PhotoTag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String = "#007AFF") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

// MARK: - Location Photo Model
/// Enhanced photo model with metadata and categorization
struct LocationPhoto: Identifiable, Codable, Hashable {
    let id: UUID
    var imageData: Data
    var thumbnailData: Data?
    var category: PhotoCategory
    var tagIDs: [UUID]
    var caption: String
    var takenAt: Date?
    var addedAt: Date
    var annotations: [PhotoAnnotation]

    enum PhotoCategory: String, Codable, CaseIterable {
        case exterior = "Exterior"
        case interior = "Interior"
        case parking = "Parking"
        case access = "Access Routes"
        case power = "Power/Utilities"
        case reference = "Reference"
        case before = "Before"
        case after = "After"
        case other = "Other"

        var icon: String {
            switch self {
            case .exterior: return "building.2.fill"
            case .interior: return "house.fill"
            case .parking: return "car.fill"
            case .access: return "arrow.triangle.turn.up.right.diamond.fill"
            case .power: return "bolt.fill"
            case .reference: return "photo.artframe"
            case .before: return "clock.arrow.circlepath"
            case .after: return "checkmark.circle.fill"
            case .other: return "photo.fill"
            }
        }

        var color: Color {
            switch self {
            case .exterior: return .blue
            case .interior: return .orange
            case .parking: return .green
            case .access: return .purple
            case .power: return .yellow
            case .reference: return .pink
            case .before: return .gray
            case .after: return .teal
            case .other: return .secondary
            }
        }
    }

    init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data? = nil,
        category: PhotoCategory = .other,
        tagIDs: [UUID] = [],
        caption: String = "",
        takenAt: Date? = nil,
        addedAt: Date = Date(),
        annotations: [PhotoAnnotation] = []
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.category = category
        self.tagIDs = tagIDs
        self.caption = caption
        self.takenAt = takenAt
        self.addedAt = addedAt
        self.annotations = annotations
    }
}

// MARK: - Photo Annotation Model
/// Represents an annotation drawn on a photo
struct PhotoAnnotation: Identifiable, Codable, Hashable {
    let id: UUID
    var type: AnnotationType
    var x: Double
    var y: Double
    var width: Double?
    var height: Double?
    var text: String?
    var colorHex: String
    var strokeWidth: Double

    enum AnnotationType: String, Codable {
        case text
        case arrow
        case circle
        case rectangle
        case freehand
    }

    init(
        id: UUID = UUID(),
        type: AnnotationType,
        x: Double,
        y: Double,
        width: Double? = nil,
        height: Double? = nil,
        text: String? = nil,
        colorHex: String = "#FF0000",
        strokeWidth: Double = 2.0
    ) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
        self.colorHex = colorHex
        self.strokeWidth = strokeWidth
    }
}

// MARK: - Assignment Model
/// Represents a person assigned to a location task
struct LocationAssignment: Identifiable, Codable, Hashable {
    let id: UUID
    var locationID: UUID
    var assigneeName: String
    var assigneeEmail: String
    var assigneePhone: String
    var role: AssignmentRole
    var taskDescription: String
    var dueDate: Date?
    var isCompleted: Bool
    var completedAt: Date?
    var notes: String
    var createdAt: Date
    var linkedTaskID: UUID?  // Link to TaskEntity in Tasks app

    enum AssignmentRole: String, Codable, CaseIterable {
        case locationManager = "Location Manager"
        case scout = "Scout"
        case productionDesigner = "Production Designer"
        case director = "Director"
        case producer = "Producer"
        case coordinator = "Coordinator"
        case other = "Other"

        var icon: String {
            switch self {
            case .locationManager: return "mappin.and.ellipse"
            case .scout: return "binoculars.fill"
            case .productionDesigner: return "paintpalette.fill"
            case .director: return "video.fill"
            case .producer: return "briefcase.fill"
            case .coordinator: return "person.crop.circle.badge.clock"
            case .other: return "person.fill"
            }
        }
    }

    init(
        id: UUID = UUID(),
        locationID: UUID,
        assigneeName: String,
        assigneeEmail: String = "",
        assigneePhone: String = "",
        role: AssignmentRole = .scout,
        taskDescription: String = "",
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        linkedTaskID: UUID? = nil
    ) {
        self.id = id
        self.locationID = locationID
        self.assigneeName = assigneeName
        self.assigneeEmail = assigneeEmail
        self.assigneePhone = assigneePhone
        self.role = role
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.notes = notes
        self.createdAt = createdAt
        self.linkedTaskID = linkedTaskID
    }
}

// MARK: - Approval Workflow Model
/// Represents an approval step in the location workflow
struct LocationApproval: Identifiable, Codable, Hashable {
    let id: UUID
    var locationID: UUID
    var approverName: String
    var approverRole: String
    var status: ApprovalStatus
    var comments: String
    var requestedAt: Date
    var respondedAt: Date?
    var order: Int  // Order in approval chain

    enum ApprovalStatus: String, Codable, CaseIterable {
        case pending = "Pending"
        case approved = "Approved"
        case denied = "Denied"
        case needsRevision = "Needs Revision"

        var icon: String {
            switch self {
            case .pending: return "clock.fill"
            case .approved: return "checkmark.circle.fill"
            case .denied: return "xmark.circle.fill"
            case .needsRevision: return "arrow.triangle.2.circlepath"
            }
        }

        var color: Color {
            switch self {
            case .pending: return .orange
            case .approved: return .green
            case .denied: return .red
            case .needsRevision: return .yellow
            }
        }
    }

    init(
        id: UUID = UUID(),
        locationID: UUID,
        approverName: String,
        approverRole: String,
        status: ApprovalStatus = .pending,
        comments: String = "",
        requestedAt: Date = Date(),
        respondedAt: Date? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.locationID = locationID
        self.approverName = approverName
        self.approverRole = approverRole
        self.status = status
        self.comments = comments
        self.requestedAt = requestedAt
        self.respondedAt = respondedAt
        self.order = order
    }
}

// MARK: - Weather Data Model
/// Represents weather information for a location/date
struct LocationWeather: Codable, Hashable {
    var temperature: Double?
    var temperatureUnit: String
    var condition: WeatherCondition
    var humidity: Double?
    var windSpeed: Double?
    var windDirection: String?
    var precipitation: Double?
    var sunrise: Date?
    var sunset: Date?
    var fetchedAt: Date

    enum WeatherCondition: String, Codable, CaseIterable {
        case clear = "Clear"
        case partlyCloudy = "Partly Cloudy"
        case cloudy = "Cloudy"
        case rain = "Rain"
        case heavyRain = "Heavy Rain"
        case thunderstorm = "Thunderstorm"
        case snow = "Snow"
        case fog = "Fog"
        case windy = "Windy"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .clear: return "sun.max.fill"
            case .partlyCloudy: return "cloud.sun.fill"
            case .cloudy: return "cloud.fill"
            case .rain: return "cloud.rain.fill"
            case .heavyRain: return "cloud.heavyrain.fill"
            case .thunderstorm: return "cloud.bolt.rain.fill"
            case .snow: return "cloud.snow.fill"
            case .fog: return "cloud.fog.fill"
            case .windy: return "wind"
            case .unknown: return "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .clear: return .yellow
            case .partlyCloudy: return .orange
            case .cloudy: return .gray
            case .rain, .heavyRain: return .blue
            case .thunderstorm: return .purple
            case .snow: return .cyan
            case .fog: return .secondary
            case .windy: return .teal
            case .unknown: return .gray
            }
        }
    }

    init(
        temperature: Double? = nil,
        temperatureUnit: String = "F",
        condition: WeatherCondition = .unknown,
        humidity: Double? = nil,
        windSpeed: Double? = nil,
        windDirection: String? = nil,
        precipitation: Double? = nil,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        fetchedAt: Date = Date()
    ) {
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.condition = condition
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.precipitation = precipitation
        self.sunrise = sunrise
        self.sunset = sunset
        self.fetchedAt = fetchedAt
    }
}

// MARK: - Availability Window Model
/// Represents when a location is available
struct AvailabilityWindow: Identifiable, Codable, Hashable {
    let id: UUID
    var startDate: Date
    var endDate: Date
    var isAvailable: Bool
    var notes: String
    var recurring: RecurringType

    enum RecurringType: String, Codable, CaseIterable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        isAvailable: Bool = true,
        notes: String = "",
        recurring: RecurringType = .none
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.isAvailable = isAvailable
        self.notes = notes
        self.recurring = recurring
    }
}

// MARK: - Filter Options Model
/// Represents filter options for location search
struct LocationFilterOptions: Codable, Hashable {
    var searchText: String
    var permitStatuses: [String]
    var folderIDs: [UUID]
    var tagIDs: [UUID]
    var showFavoritesOnly: Bool
    var showScoutedOnly: Bool
    var showUnscoutedOnly: Bool
    var dateRange: DateRange?
    var proximityCenter: CLLocationCoordinate2D?
    var proximityRadiusMiles: Double?
    var assigneeNames: [String]
    var sortBy: SortOption
    var sortAscending: Bool

    struct DateRange: Codable, Hashable {
        var start: Date
        var end: Date
    }

    enum SortOption: String, Codable, CaseIterable {
        case name = "Name"
        case dateAdded = "Date Added"
        case dateModified = "Date Modified"
        case scoutDate = "Scout Date"
        case status = "Status"
        case distance = "Distance"
    }

    init(
        searchText: String = "",
        permitStatuses: [String] = [],
        folderIDs: [UUID] = [],
        tagIDs: [UUID] = [],
        showFavoritesOnly: Bool = false,
        showScoutedOnly: Bool = false,
        showUnscoutedOnly: Bool = false,
        dateRange: DateRange? = nil,
        proximityCenter: CLLocationCoordinate2D? = nil,
        proximityRadiusMiles: Double? = nil,
        assigneeNames: [String] = [],
        sortBy: SortOption = .name,
        sortAscending: Bool = true
    ) {
        self.searchText = searchText
        self.permitStatuses = permitStatuses
        self.folderIDs = folderIDs
        self.tagIDs = tagIDs
        self.showFavoritesOnly = showFavoritesOnly
        self.showScoutedOnly = showScoutedOnly
        self.showUnscoutedOnly = showUnscoutedOnly
        self.dateRange = dateRange
        self.proximityCenter = proximityCenter
        self.proximityRadiusMiles = proximityRadiusMiles
        self.assigneeNames = assigneeNames
        self.sortBy = sortBy
        self.sortAscending = sortAscending
    }
}

// MARK: - Export Format
enum LocationExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .pdf: return "pdf"
        }
    }

    var icon: String {
        switch self {
        case .json: return "doc.text"
        case .csv: return "tablecells"
        case .pdf: return "doc.richtext"
        }
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension
extension CLLocationCoordinate2D: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
