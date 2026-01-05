import SwiftUI
import UniformTypeIdentifiers
import CoreData
#if canImport(AppKit)
import AppKit
#endif

/// Singleton manager for storing and accessing location data across the application
/// Supports file-based storage, iCloud sync, import/export functionality
class LocationDataManager: ObservableObject {
    static let shared = LocationDataManager()

    /// Call this early in app launch to ensure the manager is initialized
    /// and listening for project switch notifications
    static func initialize() {
        _ = shared
    }

    // MARK: - Published Properties
    @Published var locations: [LocationItem] = []
    @Published var folders: [LocationFolder] = []
    @Published var comments: [LocationComment] = []
    @Published var documents: [LocationDocument] = []
    @Published var activityLog: [ActivityLogEntry] = []
    @Published var assignments: [LocationAssignment] = []
    @Published var approvals: [LocationApproval] = []
    @Published var photoTags: [PhotoTag] = []
    @Published var filterOptions: LocationFilterOptions = LocationFilterOptions()
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?

    // MARK: - File URLs
    private var appSupportFolder: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("M42.Production-Central/Locations", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
        return appFolder
    }

    private var locationsFileURL: URL { appSupportFolder.appendingPathComponent("locations.json") }
    private var foldersFileURL: URL { appSupportFolder.appendingPathComponent("folders.json") }
    private var commentsFileURL: URL { appSupportFolder.appendingPathComponent("comments.json") }
    private var documentsFileURL: URL { appSupportFolder.appendingPathComponent("documents.json") }
    private var activityLogFileURL: URL { appSupportFolder.appendingPathComponent("activity_log.json") }
    private var assignmentsFileURL: URL { appSupportFolder.appendingPathComponent("assignments.json") }
    private var approvalsFileURL: URL { appSupportFolder.appendingPathComponent("approvals.json") }
    private var photoTagsFileURL: URL { appSupportFolder.appendingPathComponent("photo_tags.json") }

    // iCloud container URL
    private var iCloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/Locations", isDirectory: true)
    }

    // Current user name (for activity tracking)
    private var currentUserName: String {
        #if os(macOS)
        return NSFullUserName()
        #else
        return "User"
        #endif
    }

    // MARK: - Initialization
    private init() {
        migrateFromUserDefaults()
        loadAllData()

        // Initialize with sample data if empty
        if locations.isEmpty {
            initializeSampleData()
        }

        // Initialize default folders if empty
        if folders.isEmpty {
            initializeDefaultFolders()
        }

        // Initialize default photo tags if empty
        if photoTags.isEmpty {
            initializeDefaultPhotoTags()
        }

        // Setup iCloud sync observer
        setupiCloudObserver()

        // Listen for project switch notifications to clear data for new projects
        setupProjectSwitchObserver()
    }

    // MARK: - Project Switch Observer
    private func setupProjectSwitchObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("pr.storeDidSwitch"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleProjectSwitch()
        }
    }

    private func handleProjectSwitch() {
        print("📍 LocationDataManager: Received pr.storeDidSwitch notification")
        clearAllData()
    }

    // MARK: - Clear All Data (for new projects)
    /// Clears all location data to start fresh for a new project
    func clearAllData() {
        locations = []
        folders = []
        comments = []
        documents = []
        activityLog = []
        assignments = []
        approvals = []
        photoTags = []
        filterOptions = LocationFilterOptions()

        // Save empty data to files
        saveLocations()
        saveFolders()
        saveComments()
        saveDocuments()
        saveActivityLog()
        saveAssignments()
        saveApprovals()
        savePhotoTags()

        // Re-initialize default folders and photo tags for the new project
        initializeDefaultFolders()
        initializeDefaultPhotoTags()

        print("📍 LocationDataManager: Cleared all data for new project")
    }

    // MARK: - Sample Data
    private func initializeSampleData() {
        locations = [
            LocationItem(name: "Riverside Park", address: "123 River Rd", contact: "Parks Office", phone: "(313) 555-0142", email: "permits@city.org", permitStatus: "Pending"),
            LocationItem(name: "Old Mill", address: "45 Foundry Ln", contact: "Site Manager", phone: "(313) 555-0178", email: "mill@historic.org", permitStatus: "Approved"),
            LocationItem(name: "Downtown Alley", address: "218 3rd St", contact: "Business Assoc.", phone: "(313) 555-0111", email: "permits@downtown.org", permitStatus: "Needs Scout")
        ]
        saveLocations()
    }

    private func initializeDefaultFolders() {
        folders = [
            LocationFolder(name: "All Locations", colorHex: "#007AFF", iconName: "mappin.circle.fill", sortOrder: 0),
            LocationFolder(name: "Favorites", colorHex: "#FF9500", iconName: "star.fill", sortOrder: 1),
            LocationFolder(name: "Pending Approval", colorHex: "#FF3B30", iconName: "clock.fill", sortOrder: 2),
            LocationFolder(name: "Approved", colorHex: "#34C759", iconName: "checkmark.circle.fill", sortOrder: 3)
        ]
        saveFolders()
    }

    private func initializeDefaultPhotoTags() {
        photoTags = [
            PhotoTag(name: "Hero Shot", colorHex: "#FF9500"),
            PhotoTag(name: "Reference", colorHex: "#007AFF"),
            PhotoTag(name: "Problem Area", colorHex: "#FF3B30"),
            PhotoTag(name: "Power Source", colorHex: "#FFCC00"),
            PhotoTag(name: "Parking", colorHex: "#34C759"),
            PhotoTag(name: "Crew Area", colorHex: "#5856D6")
        ]
        savePhotoTags()
    }

    // MARK: - Location CRUD Operations

    func addLocation(_ location: LocationItem) {
        var newLocation = location
        newLocation = LocationItem(
            id: location.id,
            name: location.name,
            address: location.address,
            locationInFilm: location.locationInFilm,
            contact: location.contact,
            phone: location.phone,
            email: location.email,
            permitStatus: location.permitStatus,
            notes: location.notes,
            dateToScout: location.dateToScout,
            scouted: location.scouted,
            latitude: location.latitude,
            longitude: location.longitude,
            imageDatas: location.imageDatas,
            parkingMapImageData: location.parkingMapImageData,
            parkingMapAnnotations: location.parkingMapAnnotations,
            folderID: location.folderID,
            isFavorite: location.isFavorite,
            priority: location.priority,
            photos: location.photos,
            tagIDs: location.tagIDs,
            availabilityWindows: location.availabilityWindows,
            scoutWeather: location.scoutWeather,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: currentUserName,
            lastModifiedBy: currentUserName
        )
        locations.append(newLocation)
        saveLocations()
        logActivity(locationID: newLocation.id, type: .created, description: "Location '\(newLocation.name)' was created")
    }

    func updateLocation(_ location: LocationItem) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            var updatedLocation = location
            updatedLocation = LocationItem(
                id: location.id,
                name: location.name,
                address: location.address,
                locationInFilm: location.locationInFilm,
                contact: location.contact,
                phone: location.phone,
                email: location.email,
                permitStatus: location.permitStatus,
                notes: location.notes,
                dateToScout: location.dateToScout,
                scouted: location.scouted,
                latitude: location.latitude,
                longitude: location.longitude,
                imageDatas: location.imageDatas,
                parkingMapImageData: location.parkingMapImageData,
                parkingMapAnnotations: location.parkingMapAnnotations,
                folderID: location.folderID,
                isFavorite: location.isFavorite,
                priority: location.priority,
                photos: location.photos,
                tagIDs: location.tagIDs,
                availabilityWindows: location.availabilityWindows,
                scoutWeather: location.scoutWeather,
                createdAt: locations[index].createdAt,
                updatedAt: Date(),
                createdBy: locations[index].createdBy,
                lastModifiedBy: currentUserName
            )

            // Track status changes
            if locations[index].permitStatus != updatedLocation.permitStatus {
                logActivity(
                    locationID: location.id,
                    type: .statusChanged,
                    description: "Permit status changed from '\(locations[index].permitStatus)' to '\(updatedLocation.permitStatus)'",
                    previousValue: locations[index].permitStatus,
                    newValue: updatedLocation.permitStatus,
                    fieldName: "permitStatus"
                )
            }

            // Track scouted changes
            if locations[index].scouted != updatedLocation.scouted && updatedLocation.scouted {
                logActivity(locationID: location.id, type: .scouted, description: "Location was marked as scouted")
            }

            locations[index] = updatedLocation
            saveLocations()
        }
    }

    func deleteLocation(_ location: LocationItem) {
        logActivity(locationID: location.id, type: .updated, description: "Location '\(location.name)' was deleted")
        locations.removeAll { $0.id == location.id }
        // Also remove related data
        comments.removeAll { $0.locationID == location.id }
        documents.removeAll { $0.locationID == location.id }
        assignments.removeAll { $0.locationID == location.id }
        approvals.removeAll { $0.locationID == location.id }
        saveLocations()
        saveComments()
        saveDocuments()
        saveAssignments()
        saveApprovals()
    }

    func deleteLocations(at offsets: IndexSet) {
        let toDelete = offsets.map { locations[$0] }
        toDelete.forEach { deleteLocation($0) }
    }

    func getLocation(by id: UUID) -> LocationItem? {
        return locations.first { $0.id == id }
    }

    func getLocation(byName name: String) -> LocationItem? {
        return locations.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Folder Operations

    func addFolder(_ folder: LocationFolder) {
        folders.append(folder)
        saveFolders()
    }

    func updateFolder(_ folder: LocationFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
            saveFolders()
        }
    }

    func deleteFolder(_ folder: LocationFolder) {
        // Move locations to no folder
        for i in locations.indices where locations[i].folderID == folder.id {
            locations[i].folderID = nil
        }
        folders.removeAll { $0.id == folder.id }
        saveFolders()
        saveLocations()
    }

    func getLocationsInFolder(_ folderID: UUID?) -> [LocationItem] {
        if folderID == nil {
            return locations
        }
        return locations.filter { $0.folderID == folderID }
    }

    // MARK: - Comment Operations

    func addComment(_ comment: LocationComment) {
        comments.append(comment)
        saveComments()
        logActivity(locationID: comment.locationID, type: .commentAdded, description: "Comment added by \(comment.authorName)")
    }

    func updateComment(_ comment: LocationComment) {
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
            saveComments()
        }
    }

    func deleteComment(_ comment: LocationComment) {
        comments.removeAll { $0.id == comment.id }
        saveComments()
    }

    func getComments(for locationID: UUID) -> [LocationComment] {
        return comments.filter { $0.locationID == locationID }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Document Operations

    func addDocument(_ document: LocationDocument) {
        documents.append(document)
        saveDocuments()
        logActivity(locationID: document.locationID, type: .documentAdded, description: "Document '\(document.name)' was added")
    }

    func updateDocument(_ document: LocationDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
            saveDocuments()
        }
    }

    func deleteDocument(_ document: LocationDocument) {
        logActivity(locationID: document.locationID, type: .documentRemoved, description: "Document '\(document.name)' was removed")
        documents.removeAll { $0.id == document.id }
        saveDocuments()
    }

    func getDocuments(for locationID: UUID) -> [LocationDocument] {
        return documents.filter { $0.locationID == locationID }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Assignment Operations

    func addAssignment(_ assignment: LocationAssignment, context: NSManagedObjectContext? = nil) {
        var newAssignment = assignment

        // Sync to Tasks app if context is provided
        if let context = context,
           let location = getLocation(by: assignment.locationID) {
            let taskID = LocationTaskSyncService.shared.syncAssignment(assignment, locationName: location.name, in: context)
            newAssignment.linkedTaskID = taskID
        }

        assignments.append(newAssignment)
        saveAssignments()
        logActivity(locationID: assignment.locationID, type: .assignmentChanged, description: "\(assignment.assigneeName) was assigned as \(assignment.role.rawValue)")
    }

    func updateAssignment(_ assignment: LocationAssignment, context: NSManagedObjectContext? = nil) {
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            var updatedAssignment = assignment

            // Sync to Tasks app if context is provided
            if let context = context,
               let location = getLocation(by: assignment.locationID) {
                // Preserve existing linkedTaskID if not set
                if updatedAssignment.linkedTaskID == nil {
                    updatedAssignment.linkedTaskID = assignments[index].linkedTaskID
                }
                let taskID = LocationTaskSyncService.shared.syncAssignment(updatedAssignment, locationName: location.name, in: context)
                updatedAssignment.linkedTaskID = taskID
            }

            assignments[index] = updatedAssignment
            saveAssignments()
        }
    }

    func deleteAssignment(_ assignment: LocationAssignment, context: NSManagedObjectContext? = nil) {
        // Delete linked task if context is provided
        if let context = context, let taskID = assignment.linkedTaskID {
            LocationTaskSyncService.shared.deleteTask(taskID: taskID, in: context)
        }

        assignments.removeAll { $0.id == assignment.id }
        saveAssignments()
    }

    func getAssignments(for locationID: UUID) -> [LocationAssignment] {
        return assignments.filter { $0.locationID == locationID }
    }

    /// Sync all assignments for a location to the Tasks app
    func syncAssignmentsToTasks(for locationID: UUID, context: NSManagedObjectContext) {
        guard let location = getLocation(by: locationID) else { return }

        for (index, assignment) in assignments.enumerated() where assignment.locationID == locationID {
            let taskID = LocationTaskSyncService.shared.syncAssignment(assignment, locationName: location.name, in: context)
            assignments[index].linkedTaskID = taskID
        }

        saveAssignments()
    }

    /// Sync all assignments to the Tasks app
    func syncAllAssignmentsToTasks(context: NSManagedObjectContext) {
        for (index, assignment) in assignments.enumerated() {
            if let location = getLocation(by: assignment.locationID) {
                let taskID = LocationTaskSyncService.shared.syncAssignment(assignment, locationName: location.name, in: context)
                assignments[index].linkedTaskID = taskID
            }
        }

        saveAssignments()
    }

    // MARK: - Approval Operations

    func addApproval(_ approval: LocationApproval) {
        approvals.append(approval)
        saveApprovals()
    }

    func updateApproval(_ approval: LocationApproval) {
        if let index = approvals.firstIndex(where: { $0.id == approval.id }) {
            approvals[index] = approval
            saveApprovals()

            if approval.status == .approved {
                logActivity(locationID: approval.locationID, type: .approved, description: "Approved by \(approval.approverName)")
            } else if approval.status == .denied {
                logActivity(locationID: approval.locationID, type: .denied, description: "Denied by \(approval.approverName)")
            }
        }
    }

    func getApprovals(for locationID: UUID) -> [LocationApproval] {
        return approvals.filter { $0.locationID == locationID }.sorted { $0.order < $1.order }
    }

    // MARK: - Activity Log

    private func logActivity(locationID: UUID, type: ActivityLogEntry.ActivityType, description: String, previousValue: String? = nil, newValue: String? = nil, fieldName: String? = nil) {
        let entry = ActivityLogEntry(
            locationID: locationID,
            activityType: type,
            description: description,
            userName: currentUserName,
            previousValue: previousValue,
            newValue: newValue,
            fieldName: fieldName
        )
        activityLog.append(entry)
        saveActivityLog()
    }

    func getActivityLog(for locationID: UUID) -> [ActivityLogEntry] {
        return activityLog.filter { $0.locationID == locationID }.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Filtering

    func filteredLocations() -> [LocationItem] {
        var result = locations

        // Search text
        if !filterOptions.searchText.isEmpty {
            let search = filterOptions.searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(search) ||
                $0.address.lowercased().contains(search) ||
                $0.locationInFilm.lowercased().contains(search) ||
                $0.contact.lowercased().contains(search) ||
                $0.notes.lowercased().contains(search)
            }
        }

        // Permit status filter
        if !filterOptions.permitStatuses.isEmpty {
            result = result.filter { filterOptions.permitStatuses.contains($0.permitStatus) }
        }

        // Folder filter
        if !filterOptions.folderIDs.isEmpty {
            result = result.filter { filterOptions.folderIDs.contains($0.folderID ?? UUID()) }
        }

        // Favorites only
        if filterOptions.showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        // Scouted only
        if filterOptions.showScoutedOnly {
            result = result.filter { $0.scouted }
        }

        // Unscouted only
        if filterOptions.showUnscoutedOnly {
            result = result.filter { !$0.scouted }
        }

        // Date range
        if let dateRange = filterOptions.dateRange {
            result = result.filter {
                guard let scoutDate = $0.dateToScout else { return false }
                return scoutDate >= dateRange.start && scoutDate <= dateRange.end
            }
        }

        // Proximity filter
        if let center = filterOptions.proximityCenter, let radius = filterOptions.proximityRadiusMiles {
            result = result.filter {
                guard let lat = $0.latitude, let lon = $0.longitude else { return false }
                let distance = distanceInMiles(from: center, to: (lat, lon))
                return distance <= radius
            }
        }

        // Sorting
        switch filterOptions.sortBy {
        case .name:
            result.sort { filterOptions.sortAscending ? $0.name < $1.name : $0.name > $1.name }
        case .dateAdded:
            result.sort { filterOptions.sortAscending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
        case .dateModified:
            result.sort { filterOptions.sortAscending ? $0.updatedAt < $1.updatedAt : $0.updatedAt > $1.updatedAt }
        case .scoutDate:
            result.sort {
                let d1 = $0.dateToScout ?? Date.distantFuture
                let d2 = $1.dateToScout ?? Date.distantFuture
                return filterOptions.sortAscending ? d1 < d2 : d1 > d2
            }
        case .status:
            result.sort { filterOptions.sortAscending ? $0.permitStatus < $1.permitStatus : $0.permitStatus > $1.permitStatus }
        case .distance:
            if let center = filterOptions.proximityCenter {
                result.sort {
                    let d1 = distanceInMiles(from: center, to: ($0.latitude ?? 0, $0.longitude ?? 0))
                    let d2 = distanceInMiles(from: center, to: ($1.latitude ?? 0, $1.longitude ?? 0))
                    return filterOptions.sortAscending ? d1 < d2 : d1 > d2
                }
            }
        }

        return result
    }

    private func distanceInMiles(from coord1: CLLocationCoordinate2D, to coord2: (Double, Double)) -> Double {
        let lat1 = coord1.latitude * .pi / 180
        let lon1 = coord1.longitude * .pi / 180
        let lat2 = coord2.0 * .pi / 180
        let lon2 = coord2.1 * .pi / 180

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let radiusOfEarthMiles = 3959.0

        return radiusOfEarthMiles * c
    }

    // MARK: - Nearby Locations

    func getNearbyLocations(to location: LocationItem, withinMiles radius: Double = 5.0) -> [LocationItem] {
        guard let lat = location.latitude, let lon = location.longitude else { return [] }
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        return locations.filter { loc in
            guard loc.id != location.id, let locLat = loc.latitude, let locLon = loc.longitude else { return false }
            let distance = distanceInMiles(from: center, to: (locLat, locLon))
            return distance <= radius
        }.sorted {
            let d1 = distanceInMiles(from: center, to: ($0.latitude ?? 0, $0.longitude ?? 0))
            let d2 = distanceInMiles(from: center, to: ($1.latitude ?? 0, $1.longitude ?? 0))
            return d1 < d2
        }
    }

    // MARK: - Export Functionality

    func exportLocations(format: LocationExportFormat, locationIDs: [UUID]? = nil) -> Data? {
        let locationsToExport = locationIDs == nil ? locations : locations.filter { locationIDs!.contains($0.id) }

        switch format {
        case .json:
            return exportToJSON(locationsToExport)
        case .csv:
            return exportToCSV(locationsToExport)
        case .pdf:
            return exportToPDF(locationsToExport)
        }
    }

    private func exportToJSON(_ locations: [LocationItem]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(locations)
    }

    private func exportToCSV(_ locations: [LocationItem]) -> Data? {
        var csv = "ID,Name,Address,Location in Film,Contact,Phone,Email,Permit Status,Notes,Scout Date,Scouted,Latitude,Longitude,Favorite,Priority,Created At,Updated At\n"

        for loc in locations {
            let scoutDate = loc.dateToScout?.formatted(date: .abbreviated, time: .omitted) ?? ""
            let row = [
                loc.id.uuidString,
                escapeCSV(loc.name),
                escapeCSV(loc.address),
                escapeCSV(loc.locationInFilm),
                escapeCSV(loc.contact),
                escapeCSV(loc.phone),
                escapeCSV(loc.email),
                escapeCSV(loc.permitStatus),
                escapeCSV(loc.notes),
                scoutDate,
                loc.scouted ? "Yes" : "No",
                loc.latitude.map { String($0) } ?? "",
                loc.longitude.map { String($0) } ?? "",
                loc.isFavorite ? "Yes" : "No",
                String(loc.priority),
                loc.createdAt.formatted(date: .abbreviated, time: .shortened),
                loc.updatedAt.formatted(date: .abbreviated, time: .shortened)
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv.data(using: .utf8)
    }

    private func escapeCSV(_ string: String) -> String {
        var escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }

    private func exportToPDF(_ locations: [LocationItem]) -> Data? {
        #if os(macOS)
        let pageWidth: CGFloat = 612  // 8.5 inches at 72 DPI
        let pageHeight: CGFloat = 792 // 11 inches at 72 DPI
        let margin: CGFloat = 50

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        var yPosition = pageHeight - margin
        var isOnPage = false

        func startNewPage() {
            if isOnPage {
                context.endPDFPage()
            }
            context.beginPDFPage(nil)
            isOnPage = true
            yPosition = pageHeight - margin
        }

        startNewPage()

        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]
        let title = "Location Report"
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleLine = CTLineCreateWithAttributedString(titleString)
        context.textPosition = CGPoint(x: margin, y: yPosition)
        CTLineDraw(titleLine, context)
        yPosition -= 40

        // Date
        let dateFont = NSFont.systemFont(ofSize: 12)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: NSColor.gray
        ]
        let dateString = NSAttributedString(string: "Generated: \(Date().formatted())", attributes: dateAttributes)
        let dateLine = CTLineCreateWithAttributedString(dateString)
        context.textPosition = CGPoint(x: margin, y: yPosition)
        CTLineDraw(dateLine, context)
        yPosition -= 30

        // Locations
        let headerFont = NSFont.boldSystemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 11)

        for location in locations {
            if yPosition < 150 {
                startNewPage()
            }

            // Location name
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: NSColor.black]
            let nameString = NSAttributedString(string: location.name, attributes: nameAttrs)
            let nameLine = CTLineCreateWithAttributedString(nameString)
            context.textPosition = CGPoint(x: margin, y: yPosition)
            CTLineDraw(nameLine, context)
            yPosition -= 18

            // Details
            let details = [
                "Address: \(location.address)",
                "Location in Film: \(location.locationInFilm)",
                "Contact: \(location.contact) | Phone: \(location.phone) | Email: \(location.email)",
                "Status: \(location.permitStatus) | Scouted: \(location.scouted ? "Yes" : "No")",
                "Scout Date: \(location.dateToScout?.formatted(date: .abbreviated, time: .omitted) ?? "Not scheduled")"
            ]

            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor.darkGray]
            for detail in details {
                let detailString = NSAttributedString(string: detail, attributes: bodyAttrs)
                let detailLine = CTLineCreateWithAttributedString(detailString)
                context.textPosition = CGPoint(x: margin + 10, y: yPosition)
                CTLineDraw(detailLine, context)
                yPosition -= 14
            }

            // Notes
            if !location.notes.isEmpty {
                let notesString = NSAttributedString(string: "Notes: \(location.notes)", attributes: bodyAttrs)
                let notesLine = CTLineCreateWithAttributedString(notesString)
                context.textPosition = CGPoint(x: margin + 10, y: yPosition)
                CTLineDraw(notesLine, context)
                yPosition -= 14
            }

            yPosition -= 20 // Space between locations
        }

        context.endPDFPage()
        context.closePDF()

        return pdfData as Data
        #else
        return nil
        #endif
    }

    // MARK: - Import Functionality

    func importLocations(from data: Data, format: LocationExportFormat) -> Int {
        switch format {
        case .json:
            return importFromJSON(data)
        case .csv:
            return importFromCSV(data)
        case .pdf:
            return 0 // PDF import not supported
        }
    }

    private func importFromJSON(_ data: Data) -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let importedLocations = try? decoder.decode([LocationItem].self, from: data) else {
            return 0
        }

        var count = 0
        for location in importedLocations {
            // Check for duplicates by name and address
            if !locations.contains(where: { $0.name == location.name && $0.address == location.address }) {
                var newLocation = location
                // Generate new ID to avoid conflicts
                newLocation = LocationItem(
                    id: UUID(),
                    name: location.name,
                    address: location.address,
                    locationInFilm: location.locationInFilm,
                    contact: location.contact,
                    phone: location.phone,
                    email: location.email,
                    permitStatus: location.permitStatus,
                    notes: location.notes,
                    dateToScout: location.dateToScout,
                    scouted: location.scouted,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    imageDatas: location.imageDatas,
                    parkingMapImageData: location.parkingMapImageData,
                    parkingMapAnnotations: location.parkingMapAnnotations,
                    folderID: location.folderID,
                    isFavorite: location.isFavorite,
                    priority: location.priority,
                    photos: location.photos,
                    tagIDs: location.tagIDs,
                    availabilityWindows: location.availabilityWindows,
                    scoutWeather: location.scoutWeather,
                    createdAt: Date(),
                    updatedAt: Date(),
                    createdBy: currentUserName,
                    lastModifiedBy: currentUserName
                )
                addLocation(newLocation)
                count += 1
            }
        }

        return count
    }

    private func importFromCSV(_ data: Data) -> Int {
        guard let csvString = String(data: data, encoding: .utf8) else { return 0 }

        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return 0 } // Need header + at least one data row

        var count = 0
        for i in 1..<lines.count {
            let columns = parseCSVLine(lines[i])
            guard columns.count >= 5 else { continue }

            let name = columns[safe: 1] ?? ""
            let address = columns[safe: 2] ?? ""

            // Skip if duplicate
            if locations.contains(where: { $0.name == name && $0.address == address }) {
                continue
            }

            let location = LocationItem(
                name: name,
                address: address,
                locationInFilm: columns[safe: 3] ?? "",
                contact: columns[safe: 4] ?? "",
                phone: columns[safe: 5] ?? "",
                email: columns[safe: 6] ?? "",
                permitStatus: columns[safe: 7] ?? "Pending",
                notes: columns[safe: 8] ?? "",
                scouted: columns[safe: 10]?.lowercased() == "yes",
                isFavorite: columns[safe: 13]?.lowercased() == "yes"
            )
            addLocation(location)
            count += 1
        }

        return count
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)

        return result.map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"\"", with: "\"") }
    }

    // MARK: - iCloud Sync

    private func setupiCloudObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataDidChange),
            name: NSNotification.Name(rawValue: "NSUbiquityIdentityDidChangeNotification"),
            object: nil
        )
    }

    @objc private func iCloudDataDidChange() {
        syncFromiCloud()
    }

    func syncToiCloud() {
        guard let iCloudURL = iCloudContainerURL else { return }

        isSyncing = true

        DispatchQueue.global(qos: .background).async {
            try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)

            // Copy all data files to iCloud
            let files = [
                (self.locationsFileURL, "locations.json"),
                (self.foldersFileURL, "folders.json"),
                (self.commentsFileURL, "comments.json"),
                (self.documentsFileURL, "documents.json"),
                (self.assignmentsFileURL, "assignments.json"),
                (self.approvalsFileURL, "approvals.json"),
                (self.photoTagsFileURL, "photo_tags.json")
            ]

            for (localURL, filename) in files {
                let iCloudFileURL = iCloudURL.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: iCloudFileURL)
                try? FileManager.default.copyItem(at: localURL, to: iCloudFileURL)
            }

            DispatchQueue.main.async {
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
    }

    func syncFromiCloud() {
        guard let iCloudURL = iCloudContainerURL else { return }

        isSyncing = true

        DispatchQueue.global(qos: .background).async {
            let files = [
                ("locations.json", self.locationsFileURL),
                ("folders.json", self.foldersFileURL),
                ("comments.json", self.commentsFileURL),
                ("documents.json", self.documentsFileURL),
                ("assignments.json", self.assignmentsFileURL),
                ("approvals.json", self.approvalsFileURL),
                ("photo_tags.json", self.photoTagsFileURL)
            ]

            for (filename, localURL) in files {
                let iCloudFileURL = iCloudURL.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: iCloudFileURL.path) {
                    try? FileManager.default.removeItem(at: localURL)
                    try? FileManager.default.copyItem(at: iCloudFileURL, to: localURL)
                }
            }

            DispatchQueue.main.async {
                self.loadAllData()
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
    }

    // MARK: - Persistence

    private func loadAllData() {
        loadLocations()
        loadFolders()
        loadComments()
        loadDocuments()
        loadActivityLog()
        loadAssignments()
        loadApprovals()
        loadPhotoTags()
    }

    private func saveLocations() {
        save(locations, to: locationsFileURL)
    }

    private func loadLocations() {
        locations = load(from: locationsFileURL) ?? []
    }

    private func saveFolders() {
        save(folders, to: foldersFileURL)
    }

    private func loadFolders() {
        folders = load(from: foldersFileURL) ?? []
    }

    private func saveComments() {
        save(comments, to: commentsFileURL)
    }

    private func loadComments() {
        comments = load(from: commentsFileURL) ?? []
    }

    private func saveDocuments() {
        save(documents, to: documentsFileURL)
    }

    private func loadDocuments() {
        documents = load(from: documentsFileURL) ?? []
    }

    private func saveActivityLog() {
        save(activityLog, to: activityLogFileURL)
    }

    private func loadActivityLog() {
        activityLog = load(from: activityLogFileURL) ?? []
    }

    private func saveAssignments() {
        save(assignments, to: assignmentsFileURL)
    }

    private func loadAssignments() {
        assignments = load(from: assignmentsFileURL) ?? []
    }

    private func saveApprovals() {
        save(approvals, to: approvalsFileURL)
    }

    private func loadApprovals() {
        approvals = load(from: approvalsFileURL) ?? []
    }

    private func savePhotoTags() {
        save(photoTags, to: photoTagsFileURL)
    }

    private func loadPhotoTags() {
        photoTags = load(from: photoTagsFileURL) ?? []
    }

    private func save<T: Encodable>(_ data: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: url, options: [.atomic])
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to load data from \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func migrateFromUserDefaults() {
        let oldKey = "com.productionrunner.locations"

        guard let data = UserDefaults.standard.data(forKey: oldKey),
              let decoded = try? JSONDecoder().decode([LocationItem].self, from: data) else {
            return
        }

        locations = decoded
        saveLocations()
        UserDefaults.standard.removeObject(forKey: oldKey)
        print("Migrated \(locations.count) locations from UserDefaults to file storage")
    }
}

// MARK: - Array Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - CLLocationCoordinate2D Import
import MapKit
