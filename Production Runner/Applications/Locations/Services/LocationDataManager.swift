//
//  LocationDataManager.swift
//  Production Runner
//
//  Location data manager - Core Data backed
//  Stores location data in project .runner files via Core Data
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData
import MapKit
#if canImport(AppKit)
import AppKit
#endif

/// Singleton manager for storing and accessing location data across the application
/// Uses Core Data for persistence within project files
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
    @Published var isConfigured: Bool = false

    // MARK: - Core Data Context
    private var context: NSManagedObjectContext?
    private var projectID: NSManagedObjectID?

    // Current user name (for activity tracking)
    private var currentUserName: String {
        #if os(macOS)
        return NSFullUserName()
        #else
        return "User"
        #endif
    }

    // MARK: - Legacy File URLs (for migration only)
    private var legacyAppSupportFolder: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("M42.Production-Central/Locations", isDirectory: true)
    }

    private var legacyLocationsFileURL: URL { legacyAppSupportFolder.appendingPathComponent("locations.json") }
    private var legacyFoldersFileURL: URL { legacyAppSupportFolder.appendingPathComponent("folders.json") }

    // MARK: - Initialization
    private init() {
        // Listen for project switch notifications
        setupProjectSwitchObserver()
    }

    // MARK: - Core Data Configuration

    /// Configure the manager with a Core Data context and project
    /// Call this when opening a project to enable Core Data persistence
    func configure(context: NSManagedObjectContext, projectID: NSManagedObjectID) {
        print("📍 LocationDataManager: Starting configuration...")

        self.context = context
        self.projectID = projectID
        self.isConfigured = true

        print("📍 LocationDataManager: Context and projectID set")

        // Check for legacy JSON data to migrate
        // Disabled temporarily for debugging
        // checkAndMigrateLegacyData()

        // Load all data from Core Data
        print("📍 LocationDataManager: Loading data from Core Data...")
        loadAllDataFromCoreData()

        print("📍 LocationDataManager: Configuration complete")
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
        context = nil
        projectID = nil
        isConfigured = false
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

        print("📍 LocationDataManager: Cleared all data for new project")
    }

    // MARK: - Load Data from Core Data

    private func loadAllDataFromCoreData() {
        loadLocationsFromCoreData()
        loadFoldersFromCoreData()
        loadCommentsFromCoreData()
        loadDocumentsFromCoreData()
        loadAssignmentsFromCoreData()
        loadApprovalsFromCoreData()
        // Activity log and photo tags are stored as JSON within entities
    }

    private func loadLocationsFromCoreData() {
        guard let context = context, let projectID = projectID else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationEntity")
        request.predicate = NSPredicate(format: "project == %@", projectID)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let entities = try context.fetch(request)
            locations = entities.compactMap { locationItemFromEntity($0) }
            print("📍 Loaded \(locations.count) locations from Core Data")
        } catch {
            print("❌ Failed to fetch locations: \(error)")
        }
    }

    private func loadFoldersFromCoreData() {
        guard let context = context, let projectID = projectID else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationFolderEntity")
        request.predicate = NSPredicate(format: "project == %@", projectID)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let entities = try context.fetch(request)
            folders = entities.compactMap { folderFromEntity($0) }
            print("📍 Loaded \(folders.count) folders from Core Data")
        } catch {
            print("❌ Failed to fetch folders: \(error)")
        }
    }

    private func loadCommentsFromCoreData() {
        guard let context = context, let projectID = projectID else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationCommentEntity")
        // Filter to only comments for locations in this project
        request.predicate = NSPredicate(format: "location.project == %@", projectID)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let entities = try context.fetch(request)
            comments = entities.compactMap { commentFromEntity($0) }
            print("📍 Loaded \(comments.count) comments from Core Data")
        } catch {
            print("❌ Failed to fetch comments: \(error)")
        }
    }

    private func loadDocumentsFromCoreData() {
        guard let context = context, let projectID = projectID else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationDocumentEntity")
        // Filter to only documents for locations in this project
        request.predicate = NSPredicate(format: "location.project == %@", projectID)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let entities = try context.fetch(request)
            documents = entities.compactMap { documentFromEntity($0) }
            print("📍 Loaded \(documents.count) documents from Core Data")
        } catch {
            print("❌ Failed to fetch documents: \(error)")
        }
    }

    private func loadAssignmentsFromCoreData() {
        guard let context = context, let projectID = projectID else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationAssignmentEntity")
        // Filter to only assignments for locations in this project
        request.predicate = NSPredicate(format: "location.project == %@", projectID)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let entities = try context.fetch(request)
            assignments = entities.compactMap { assignmentFromEntity($0) }
            print("📍 Loaded \(assignments.count) assignments from Core Data")
        } catch {
            print("❌ Failed to fetch assignments: \(error)")
        }
    }

    private func loadApprovalsFromCoreData() {
        guard let context = context, let projectID = projectID else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationApprovalEntity")
        // Filter to only approvals for locations in this project
        request.predicate = NSPredicate(format: "location.project == %@", projectID)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let entities = try context.fetch(request)
            approvals = entities.compactMap { approvalFromEntity($0) }
            print("📍 Loaded \(approvals.count) approvals from Core Data")
        } catch {
            print("❌ Failed to fetch approvals: \(error)")
        }
    }

    // MARK: - Entity to Struct Conversions

    private func locationItemFromEntity(_ entity: NSManagedObject) -> LocationItem? {
        // Skip deleted entities
        guard !entity.isDeleted else { return nil }

        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String else {
            return nil
        }

        // Decode photos from relationship - filter out deleted entities
        var photos: [LocationPhoto] = []
        if let photoSet = entity.value(forKey: "photos") as? Set<NSManagedObject> {
            photos = photoSet
                .filter { !$0.isDeleted }
                .compactMap { photoFromEntity($0) }
                .sorted { $0.addedAt < $1.addedAt }
        }

        // Decode availability windows from relationship - filter out deleted entities
        var availabilityWindows: [AvailabilityWindow] = []
        if let availSet = entity.value(forKey: "availabilityWindows") as? Set<NSManagedObject> {
            availabilityWindows = availSet
                .filter { !$0.isDeleted }
                .compactMap { availabilityFromEntity($0) }
        }

        // Decode parking annotations from JSON
        var parkingAnnotations: [ParkingMapAnnotation] = []
        if let annotationsJSON = entity.value(forKey: "parkingMapAnnotationsJSON") as? String,
           let data = annotationsJSON.data(using: .utf8) {
            parkingAnnotations = (try? JSONDecoder().decode([ParkingMapAnnotation].self, from: data)) ?? []
        }

        // Decode tag IDs from JSON
        var tagIDs: [UUID] = []
        if let tagIDsJSON = entity.value(forKey: "tagIDsJSON") as? String,
           let data = tagIDsJSON.data(using: .utf8) {
            tagIDs = (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }

        // Decode weather from JSON
        var scoutWeather: LocationWeather?
        if let weatherJSON = entity.value(forKey: "scoutWeatherJSON") as? String,
           let data = weatherJSON.data(using: .utf8) {
            scoutWeather = try? JSONDecoder().decode(LocationWeather.self, from: data)
        }

        let latitude = entity.value(forKey: "latitude") as? Double
        let longitude = entity.value(forKey: "longitude") as? Double

        return LocationItem(
            id: id,
            name: name,
            address: entity.value(forKey: "address") as? String ?? "",
            locationInFilm: entity.value(forKey: "locationInFilm") as? String ?? "",
            contact: entity.value(forKey: "contact") as? String ?? "",
            phone: entity.value(forKey: "phone") as? String ?? "",
            email: entity.value(forKey: "email") as? String ?? "",
            permitStatus: entity.value(forKey: "permitStatus") as? String ?? "Pending",
            notes: entity.value(forKey: "notes") as? String ?? "",
            dateToScout: entity.value(forKey: "dateToScout") as? Date,
            scouted: entity.value(forKey: "scouted") as? Bool ?? false,
            latitude: latitude != 0 ? latitude : nil,
            longitude: longitude != 0 ? longitude : nil,
            imageDatas: [],  // Legacy field, use photos instead
            parkingMapImageData: entity.value(forKey: "parkingMapImageData") as? Data,
            parkingMapAnnotations: parkingAnnotations,
            folderID: (entity.value(forKey: "folder") as? NSManagedObject)?.value(forKey: "id") as? UUID,
            isFavorite: entity.value(forKey: "isFavorite") as? Bool ?? false,
            priority: Int(entity.value(forKey: "priority") as? Int16 ?? 0),
            photos: photos,
            tagIDs: tagIDs,
            availabilityWindows: availabilityWindows,
            scoutWeather: scoutWeather,
            createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date(),
            createdBy: entity.value(forKey: "createdBy") as? String ?? "",
            lastModifiedBy: entity.value(forKey: "lastModifiedBy") as? String ?? "",
            sortOrder: entity.value(forKey: "sortOrder") as? Int32 ?? 0
        )
    }

    private func photoFromEntity(_ entity: NSManagedObject) -> LocationPhoto? {
        // Skip deleted entities
        guard !entity.isDeleted else { return nil }

        guard let id = entity.value(forKey: "id") as? UUID else {
            return nil
        }

        // Allow photos without image data (might be loading external storage)
        let imageData = entity.value(forKey: "imageData") as? Data ?? Data()

        let categoryString = entity.value(forKey: "category") as? String ?? "Other"
        let category = LocationPhoto.PhotoCategory(rawValue: categoryString) ?? .other

        // Decode annotations from JSON
        var annotations: [PhotoAnnotation] = []
        if let annotationsJSON = entity.value(forKey: "annotationsJSON") as? String,
           let data = annotationsJSON.data(using: .utf8) {
            annotations = (try? JSONDecoder().decode([PhotoAnnotation].self, from: data)) ?? []
        }

        return LocationPhoto(
            id: id,
            imageData: imageData,
            thumbnailData: entity.value(forKey: "thumbnailData") as? Data,
            category: category,
            tagIDs: [],
            caption: entity.value(forKey: "caption") as? String ?? "",
            takenAt: nil,
            addedAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
            annotations: annotations
        )
    }

    private func availabilityFromEntity(_ entity: NSManagedObject) -> AvailabilityWindow? {
        // Skip deleted entities
        guard !entity.isDeleted else { return nil }

        guard let id = entity.value(forKey: "id") as? UUID,
              let startDate = entity.value(forKey: "startDate") as? Date,
              let endDate = entity.value(forKey: "endDate") as? Date else {
            return nil
        }

        return AvailabilityWindow(
            id: id,
            startDate: startDate,
            endDate: endDate,
            isAvailable: !(entity.value(forKey: "isBlocked") as? Bool ?? false),
            notes: entity.value(forKey: "notes") as? String ?? "",
            recurring: .none
        )
    }

    private func folderFromEntity(_ entity: NSManagedObject) -> LocationFolder? {
        // Skip deleted entities
        guard !entity.isDeleted else { return nil }

        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String else {
            return nil
        }

        return LocationFolder(
            id: id,
            name: name,
            colorHex: entity.value(forKey: "colorHex") as? String ?? "#007AFF",
            iconName: "folder.fill",  // Not in Core Data model, use default
            parentFolderID: entity.value(forKey: "parentFolderID") as? UUID,
            sortOrder: Int(entity.value(forKey: "sortOrder") as? Int32 ?? 0),
            createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private func commentFromEntity(_ entity: NSManagedObject) -> LocationComment? {
        guard let id = entity.value(forKey: "id") as? UUID else {
            return nil
        }

        // Safely get location relationship - may be nil for orphaned records
        guard let locationEntity = entity.value(forKey: "location") as? NSManagedObject,
              !locationEntity.isDeleted,
              let locationID = locationEntity.value(forKey: "id") as? UUID else {
            print("⚠️ Comment \(id) has no valid location - skipping")
            return nil
        }

        return LocationComment(
            id: id,
            locationID: locationID,
            authorName: entity.value(forKey: "authorName") as? String ?? "",
            authorEmail: "",
            content: entity.value(forKey: "content") as? String ?? "",
            createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date(),
            parentCommentID: entity.value(forKey: "parentCommentID") as? UUID,
            isResolved: entity.value(forKey: "isResolved") as? Bool ?? false,
            attachmentData: nil,
            attachmentName: nil
        )
    }

    private func documentFromEntity(_ entity: NSManagedObject) -> LocationDocument? {
        guard let id = entity.value(forKey: "id") as? UUID else {
            return nil
        }

        // Safely get location relationship
        guard let locationEntity = entity.value(forKey: "location") as? NSManagedObject,
              !locationEntity.isDeleted,
              let locationID = locationEntity.value(forKey: "id") as? UUID else {
            print("⚠️ Document \(id) has no valid location - skipping")
            return nil
        }

        // File data may be nil for empty documents
        let fileData = entity.value(forKey: "fileData") as? Data ?? Data()

        let docTypeString = entity.value(forKey: "documentType") as? String ?? "Other"
        let docType = LocationDocument.DocumentType(rawValue: docTypeString) ?? .other

        return LocationDocument(
            id: id,
            locationID: locationID,
            name: entity.value(forKey: "name") as? String ?? "",
            documentType: docType,
            fileData: fileData,
            fileExtension: (entity.value(forKey: "fileName") as? String)?.components(separatedBy: ".").last ?? "",
            createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date(),
            notes: "",
            expirationDate: nil
        )
    }

    private func assignmentFromEntity(_ entity: NSManagedObject) -> LocationAssignment? {
        guard let id = entity.value(forKey: "id") as? UUID else {
            return nil
        }

        // Safely get location relationship
        guard let locationEntity = entity.value(forKey: "location") as? NSManagedObject,
              !locationEntity.isDeleted,
              let locationID = locationEntity.value(forKey: "id") as? UUID else {
            print("⚠️ Assignment \(id) has no valid location - skipping")
            return nil
        }

        let roleString = entity.value(forKey: "role") as? String ?? "Other"
        let role = LocationAssignment.AssignmentRole(rawValue: roleString) ?? .other

        return LocationAssignment(
            id: id,
            locationID: locationID,
            assigneeName: entity.value(forKey: "assigneeName") as? String ?? "",
            assigneeEmail: "",  // Not in Core Data model
            assigneePhone: "",  // Not in Core Data model
            role: role,
            taskDescription: entity.value(forKey: "notes") as? String ?? "",  // Use notes field
            dueDate: entity.value(forKey: "dueDate") as? Date,
            isCompleted: entity.value(forKey: "isCompleted") as? Bool ?? false,
            completedAt: nil,  // Not in Core Data model
            notes: entity.value(forKey: "notes") as? String ?? "",
            createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
            linkedTaskID: nil  // Not in Core Data model
        )
    }

    private func approvalFromEntity(_ entity: NSManagedObject) -> LocationApproval? {
        guard let id = entity.value(forKey: "id") as? UUID else {
            return nil
        }

        // Safely get location relationship
        guard let locationEntity = entity.value(forKey: "location") as? NSManagedObject,
              !locationEntity.isDeleted,
              let locationID = locationEntity.value(forKey: "id") as? UUID else {
            print("⚠️ Approval \(id) has no valid location - skipping")
            return nil
        }

        let statusString = entity.value(forKey: "status") as? String ?? "pending"
        let status = LocationApproval.ApprovalStatus(rawValue: statusString) ?? .pending

        return LocationApproval(
            id: id,
            locationID: locationID,
            approverName: entity.value(forKey: "approverName") as? String ?? "",
            approverRole: entity.value(forKey: "step") as? String ?? "",  // Use step field
            status: status,
            comments: entity.value(forKey: "notes") as? String ?? "",  // Use notes field
            requestedAt: entity.value(forKey: "createdAt") as? Date ?? Date(),  // Use createdAt
            respondedAt: entity.value(forKey: "approvedAt") as? Date,  // Use approvedAt
            order: Int(entity.value(forKey: "sortOrder") as? Int32 ?? 0)  // Use sortOrder
        )
    }

    // MARK: - Find Entity Helpers

    private func findLocationEntity(by id: UUID) -> NSManagedObject? {
        guard let context = context else { return nil }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    private func findFolderEntity(by id: UUID) -> NSManagedObject? {
        guard let context = context else { return nil }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationFolderEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    // MARK: - Location CRUD Operations

    func addLocation(_ location: LocationItem) {
        guard let context = context, let projectID = projectID else {
            print("❌ Cannot add location: Core Data not configured")
            return
        }

        guard let project = try? context.existingObject(with: projectID) else {
            print("❌ Cannot find project for location")
            return
        }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "LocationEntity", into: context)

        entity.setValue(location.id, forKey: "id")
        entity.setValue(location.name, forKey: "name")
        entity.setValue(location.address, forKey: "address")
        entity.setValue(location.locationInFilm, forKey: "locationInFilm")
        entity.setValue(location.contact, forKey: "contact")
        entity.setValue(location.phone, forKey: "phone")
        entity.setValue(location.email, forKey: "email")
        entity.setValue(location.permitStatus, forKey: "permitStatus")
        entity.setValue(location.notes, forKey: "notes")
        entity.setValue(location.dateToScout, forKey: "dateToScout")
        entity.setValue(location.scouted, forKey: "scouted")
        entity.setValue(location.latitude ?? 0, forKey: "latitude")
        entity.setValue(location.longitude ?? 0, forKey: "longitude")
        entity.setValue(location.isFavorite, forKey: "isFavorite")
        entity.setValue(Int16(location.priority), forKey: "priority")
        entity.setValue(Int32(locations.count), forKey: "sortOrder")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(currentUserName, forKey: "createdBy")
        entity.setValue(currentUserName, forKey: "lastModifiedBy")
        entity.setValue(location.parkingMapImageData, forKey: "parkingMapImageData")
        entity.setValue(project, forKey: "project")

        // Link to folder if specified
        if let folderID = location.folderID, let folderEntity = findFolderEntity(by: folderID) {
            entity.setValue(folderEntity, forKey: "folder")
        }

        // Encode parking annotations as JSON
        if !location.parkingMapAnnotations.isEmpty {
            if let data = try? JSONEncoder().encode(location.parkingMapAnnotations),
               let json = String(data: data, encoding: .utf8) {
                entity.setValue(json, forKey: "parkingMapAnnotationsJSON")
            }
        }

        // Encode tag IDs as JSON
        if !location.tagIDs.isEmpty {
            if let data = try? JSONEncoder().encode(location.tagIDs),
               let json = String(data: data, encoding: .utf8) {
                entity.setValue(json, forKey: "tagIDsJSON")
            }
        }

        // Add photos
        for photo in location.photos {
            addPhotoEntity(photo, to: entity)
        }

        // Add availability windows
        for window in location.availabilityWindows {
            addAvailabilityEntity(window, to: entity)
        }

        saveContext()
        loadLocationsFromCoreData()

        logActivity(locationID: location.id, type: .created, description: "Location '\(location.name)' was created")
    }

    private func addPhotoEntity(_ photo: LocationPhoto, to locationEntity: NSManagedObject) {
        guard let context = context else { return }

        let photoEntity = NSEntityDescription.insertNewObject(forEntityName: "LocationPhotoEntity", into: context)
        photoEntity.setValue(photo.id, forKey: "id")
        photoEntity.setValue(photo.imageData, forKey: "imageData")
        photoEntity.setValue(photo.thumbnailData, forKey: "thumbnailData")
        photoEntity.setValue(photo.caption, forKey: "caption")
        photoEntity.setValue(photo.category.rawValue, forKey: "category")
        photoEntity.setValue(Int32(0), forKey: "sortOrder")
        photoEntity.setValue(photo.addedAt, forKey: "createdAt")
        photoEntity.setValue(locationEntity, forKey: "location")

        if !photo.annotations.isEmpty {
            if let data = try? JSONEncoder().encode(photo.annotations),
               let json = String(data: data, encoding: .utf8) {
                photoEntity.setValue(json, forKey: "annotationsJSON")
            }
        }
    }

    private func addAvailabilityEntity(_ window: AvailabilityWindow, to locationEntity: NSManagedObject) {
        guard let context = context else { return }

        let availEntity = NSEntityDescription.insertNewObject(forEntityName: "LocationAvailabilityEntity", into: context)
        availEntity.setValue(window.id, forKey: "id")
        availEntity.setValue(window.startDate, forKey: "startDate")
        availEntity.setValue(window.endDate, forKey: "endDate")
        availEntity.setValue(!window.isAvailable, forKey: "isBlocked")
        availEntity.setValue(window.notes, forKey: "notes")
        availEntity.setValue(Date(), forKey: "createdAt")
        availEntity.setValue(locationEntity, forKey: "location")
    }

    func updateLocation(_ location: LocationItem) {
        guard let entity = findLocationEntity(by: location.id) else {
            print("❌ Cannot find location entity to update")
            return
        }

        // Track status changes for activity log
        let oldStatus = entity.value(forKey: "permitStatus") as? String
        let oldScouted = entity.value(forKey: "scouted") as? Bool ?? false

        entity.setValue(location.name, forKey: "name")
        entity.setValue(location.address, forKey: "address")
        entity.setValue(location.locationInFilm, forKey: "locationInFilm")
        entity.setValue(location.contact, forKey: "contact")
        entity.setValue(location.phone, forKey: "phone")
        entity.setValue(location.email, forKey: "email")
        entity.setValue(location.permitStatus, forKey: "permitStatus")
        entity.setValue(location.notes, forKey: "notes")
        entity.setValue(location.dateToScout, forKey: "dateToScout")
        entity.setValue(location.scouted, forKey: "scouted")
        entity.setValue(location.latitude ?? 0, forKey: "latitude")
        entity.setValue(location.longitude ?? 0, forKey: "longitude")
        entity.setValue(location.isFavorite, forKey: "isFavorite")
        entity.setValue(Int16(location.priority), forKey: "priority")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(currentUserName, forKey: "lastModifiedBy")
        entity.setValue(location.parkingMapImageData, forKey: "parkingMapImageData")

        // Update folder link
        if let folderID = location.folderID, let folderEntity = findFolderEntity(by: folderID) {
            entity.setValue(folderEntity, forKey: "folder")
        } else {
            entity.setValue(nil, forKey: "folder")
        }

        // Update JSON fields
        if let data = try? JSONEncoder().encode(location.parkingMapAnnotations),
           let json = String(data: data, encoding: .utf8) {
            entity.setValue(json, forKey: "parkingMapAnnotationsJSON")
        }

        if let data = try? JSONEncoder().encode(location.tagIDs),
           let json = String(data: data, encoding: .utf8) {
            entity.setValue(json, forKey: "tagIDsJSON")
        }

        if let weather = location.scoutWeather,
           let data = try? JSONEncoder().encode(weather),
           let json = String(data: data, encoding: .utf8) {
            entity.setValue(json, forKey: "scoutWeatherJSON")
        }

        saveContext()
        loadLocationsFromCoreData()

        // Log status changes
        if oldStatus != location.permitStatus {
            logActivity(
                locationID: location.id,
                type: .statusChanged,
                description: "Permit status changed from '\(oldStatus ?? "Unknown")' to '\(location.permitStatus)'",
                previousValue: oldStatus,
                newValue: location.permitStatus,
                fieldName: "permitStatus"
            )
        }

        if !oldScouted && location.scouted {
            logActivity(locationID: location.id, type: .scouted, description: "Location was marked as scouted")
        }
    }

    func deleteLocation(_ location: LocationItem) {
        guard let context = context, let entity = findLocationEntity(by: location.id) else {
            return
        }

        logActivity(locationID: location.id, type: .updated, description: "Location '\(location.name)' was deleted")

        context.delete(entity)
        saveContext()
        loadAllDataFromCoreData()
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
        guard let context = context, let projectID = projectID else { return }

        guard let project = try? context.existingObject(with: projectID) else { return }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "LocationFolderEntity", into: context)
        entity.setValue(folder.id, forKey: "id")
        entity.setValue(folder.name, forKey: "name")
        entity.setValue(folder.colorHex, forKey: "colorHex")
        // iconName not in Core Data model
        entity.setValue(folder.parentFolderID, forKey: "parentFolderID")
        entity.setValue(Int32(folders.count), forKey: "sortOrder")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(project, forKey: "project")

        saveContext()
        loadFoldersFromCoreData()
    }

    func updateFolder(_ folder: LocationFolder) {
        guard let entity = findFolderEntity(by: folder.id) else { return }

        entity.setValue(folder.name, forKey: "name")
        entity.setValue(folder.colorHex, forKey: "colorHex")
        // iconName not in Core Data model
        entity.setValue(folder.parentFolderID, forKey: "parentFolderID")
        entity.setValue(Date(), forKey: "updatedAt")

        saveContext()
        loadFoldersFromCoreData()
    }

    func deleteFolder(_ folder: LocationFolder) {
        guard let context = context, let entity = findFolderEntity(by: folder.id) else { return }

        // Unlink locations from this folder
        for location in locations where location.folderID == folder.id {
            if let locEntity = findLocationEntity(by: location.id) {
                locEntity.setValue(nil, forKey: "folder")
            }
        }

        context.delete(entity)
        saveContext()
        loadFoldersFromCoreData()
        loadLocationsFromCoreData()
    }

    func getLocationsInFolder(_ folderID: UUID?) -> [LocationItem] {
        if folderID == nil {
            return locations
        }
        return locations.filter { $0.folderID == folderID }
    }

    // MARK: - Comment Operations

    func addComment(_ comment: LocationComment) {
        guard let context = context,
              let locationEntity = findLocationEntity(by: comment.locationID) else { return }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "LocationCommentEntity", into: context)
        entity.setValue(comment.id, forKey: "id")
        entity.setValue(comment.content, forKey: "content")
        entity.setValue(comment.authorName, forKey: "authorName")
        entity.setValue(comment.isResolved, forKey: "isResolved")
        entity.setValue(comment.parentCommentID, forKey: "parentCommentID")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(locationEntity, forKey: "location")

        saveContext()
        loadCommentsFromCoreData()

        logActivity(locationID: comment.locationID, type: .commentAdded, description: "Comment added by \(comment.authorName)")
    }

    func updateComment(_ comment: LocationComment) {
        guard let context = context else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationCommentEntity")
        request.predicate = NSPredicate(format: "id == %@", comment.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return }

        entity.setValue(comment.content, forKey: "content")
        entity.setValue(comment.isResolved, forKey: "isResolved")
        entity.setValue(Date(), forKey: "updatedAt")

        saveContext()
        loadCommentsFromCoreData()
    }

    func deleteComment(_ comment: LocationComment) {
        guard let context = context else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationCommentEntity")
        request.predicate = NSPredicate(format: "id == %@", comment.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return }

        context.delete(entity)
        saveContext()
        loadCommentsFromCoreData()
    }

    func getComments(for locationID: UUID) -> [LocationComment] {
        return comments.filter { $0.locationID == locationID }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Document Operations

    func addDocument(_ document: LocationDocument) {
        guard let context = context,
              let locationEntity = findLocationEntity(by: document.locationID) else { return }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "LocationDocumentEntity", into: context)
        entity.setValue(document.id, forKey: "id")
        entity.setValue(document.name, forKey: "name")
        entity.setValue(document.documentType.rawValue, forKey: "documentType")
        entity.setValue(document.fileData, forKey: "fileData")
        entity.setValue("\(document.name).\(document.fileExtension)", forKey: "fileName")
        entity.setValue(Int64(document.fileData.count), forKey: "fileSize")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(locationEntity, forKey: "location")

        saveContext()
        loadDocumentsFromCoreData()

        logActivity(locationID: document.locationID, type: .documentAdded, description: "Document '\(document.name)' was added")
    }

    func updateDocument(_ document: LocationDocument) {
        guard let context = context else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationDocumentEntity")
        request.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return }

        entity.setValue(document.name, forKey: "name")
        entity.setValue(document.documentType.rawValue, forKey: "documentType")
        entity.setValue(Date(), forKey: "updatedAt")

        saveContext()
        loadDocumentsFromCoreData()
    }

    func deleteDocument(_ document: LocationDocument) {
        guard let context = context else { return }

        logActivity(locationID: document.locationID, type: .documentRemoved, description: "Document '\(document.name)' was removed")

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationDocumentEntity")
        request.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return }

        context.delete(entity)
        saveContext()
        loadDocumentsFromCoreData()
    }

    func getDocuments(for locationID: UUID) -> [LocationDocument] {
        return documents.filter { $0.locationID == locationID }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Assignment Operations

    func addAssignment(_ assignment: LocationAssignment, context taskContext: NSManagedObjectContext? = nil) {
        guard let context = context,
              let locationEntity = findLocationEntity(by: assignment.locationID) else { return }

        var newAssignment = assignment

        // Sync to Tasks app if context is provided
        if let taskContext = taskContext,
           let location = getLocation(by: assignment.locationID) {
            let taskID = LocationTaskSyncService.shared.syncAssignment(assignment, locationName: location.name, in: taskContext)
            newAssignment.linkedTaskID = taskID
        }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "LocationAssignmentEntity", into: context)
        entity.setValue(newAssignment.id, forKey: "id")
        entity.setValue(newAssignment.assigneeName, forKey: "assigneeName")
        // assigneeEmail, assigneePhone not in Core Data model
        entity.setValue(newAssignment.role.rawValue, forKey: "role")
        // Store taskDescription in notes field
        entity.setValue(newAssignment.notes.isEmpty ? newAssignment.taskDescription : newAssignment.notes, forKey: "notes")
        entity.setValue(newAssignment.dueDate, forKey: "dueDate")
        entity.setValue(newAssignment.isCompleted, forKey: "isCompleted")
        // completedAt, linkedTaskID not in Core Data model
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        entity.setValue(locationEntity, forKey: "location")

        saveContext()
        loadAssignmentsFromCoreData()

        logActivity(locationID: assignment.locationID, type: .assignmentChanged, description: "\(assignment.assigneeName) was assigned as \(assignment.role.rawValue)")
    }

    func updateAssignment(_ assignment: LocationAssignment, context taskContext: NSManagedObjectContext? = nil) {
        guard let context = context else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationAssignmentEntity")
        request.predicate = NSPredicate(format: "id == %@", assignment.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return }

        var updatedAssignment = assignment

        // Sync to Tasks app if context is provided
        // Note: linkedTaskID not in Core Data model, so task sync is in-memory only
        if let taskContext = taskContext,
           let location = getLocation(by: assignment.locationID) {
            let taskID = LocationTaskSyncService.shared.syncAssignment(updatedAssignment, locationName: location.name, in: taskContext)
            updatedAssignment.linkedTaskID = taskID
        }

        entity.setValue(updatedAssignment.assigneeName, forKey: "assigneeName")
        // assigneeEmail, assigneePhone not in Core Data model
        entity.setValue(updatedAssignment.role.rawValue, forKey: "role")
        // Store taskDescription in notes field
        entity.setValue(updatedAssignment.notes.isEmpty ? updatedAssignment.taskDescription : updatedAssignment.notes, forKey: "notes")
        entity.setValue(updatedAssignment.dueDate, forKey: "dueDate")
        entity.setValue(updatedAssignment.isCompleted, forKey: "isCompleted")
        // completedAt, linkedTaskID not in Core Data model
        entity.setValue(Date(), forKey: "updatedAt")

        saveContext()
        loadAssignmentsFromCoreData()
    }

    func deleteAssignment(_ assignment: LocationAssignment, context taskContext: NSManagedObjectContext? = nil) {
        guard let context = context else { return }

        // Delete linked task if context is provided
        if let taskContext = taskContext, let taskID = assignment.linkedTaskID {
            LocationTaskSyncService.shared.deleteTask(taskID: taskID, in: taskContext)
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationAssignmentEntity")
        request.predicate = NSPredicate(format: "id == %@", assignment.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return }

        context.delete(entity)
        saveContext()
        loadAssignmentsFromCoreData()
    }

    func getAssignments(for locationID: UUID) -> [LocationAssignment] {
        return assignments.filter { $0.locationID == locationID }
    }

    func syncAssignmentsToTasks(for locationID: UUID, context: NSManagedObjectContext) {
        guard let location = getLocation(by: locationID) else { return }

        for assignment in assignments where assignment.locationID == locationID {
            // Sync to Tasks app - linkedTaskID not persisted in Core Data model
            _ = LocationTaskSyncService.shared.syncAssignment(assignment, locationName: location.name, in: context)
        }
    }

    func syncAllAssignmentsToTasks(context: NSManagedObjectContext) {
        for assignment in assignments {
            if let location = getLocation(by: assignment.locationID) {
                // Sync to Tasks app - linkedTaskID not persisted in Core Data model
                _ = LocationTaskSyncService.shared.syncAssignment(assignment, locationName: location.name, in: context)
            }
        }
    }

    private func findAssignmentEntity(by id: UUID) -> NSManagedObject? {
        guard let context = context else { return nil }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationAssignmentEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    // MARK: - Approval Operations

    func addApproval(_ approval: LocationApproval) {
        guard let context = context,
              let locationEntity = findLocationEntity(by: approval.locationID) else { return }

        let entity = NSEntityDescription.insertNewObject(forEntityName: "LocationApprovalEntity", into: context)
        entity.setValue(approval.id, forKey: "id")
        entity.setValue(approval.approverName, forKey: "approverName")
        entity.setValue(approval.approverRole, forKey: "step")  // Model uses step
        entity.setValue(approval.status.rawValue, forKey: "status")
        entity.setValue(approval.comments, forKey: "notes")  // Model uses notes
        // requestedAt maps to createdAt
        entity.setValue(approval.respondedAt, forKey: "approvedAt")  // Model uses approvedAt
        entity.setValue(Int32(approval.order), forKey: "sortOrder")  // Model uses sortOrder
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(locationEntity, forKey: "location")

        saveContext()
        loadApprovalsFromCoreData()
    }

    func updateApproval(_ approval: LocationApproval) {
        guard let context = context else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LocationApprovalEntity")
        request.predicate = NSPredicate(format: "id == %@", approval.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return }

        entity.setValue(approval.status.rawValue, forKey: "status")
        entity.setValue(approval.comments, forKey: "notes")  // Model uses notes
        entity.setValue(approval.respondedAt, forKey: "approvedAt")  // Model uses approvedAt

        saveContext()
        loadApprovalsFromCoreData()

        if approval.status == .approved {
            logActivity(locationID: approval.locationID, type: .approved, description: "Approved by \(approval.approverName)")
        } else if approval.status == .denied {
            logActivity(locationID: approval.locationID, type: .denied, description: "Denied by \(approval.approverName)")
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
        // Activity log is kept in memory for this session
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
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
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

        let headerFont = NSFont.boldSystemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 11)

        for location in locations {
            if yPosition < 150 {
                startNewPage()
            }

            let nameAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: NSColor.black]
            let nameString = NSAttributedString(string: location.name, attributes: nameAttrs)
            let nameLine = CTLineCreateWithAttributedString(nameString)
            context.textPosition = CGPoint(x: margin, y: yPosition)
            CTLineDraw(nameLine, context)
            yPosition -= 18

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

            if !location.notes.isEmpty {
                let notesString = NSAttributedString(string: "Notes: \(location.notes)", attributes: bodyAttrs)
                let notesLine = CTLineCreateWithAttributedString(notesString)
                context.textPosition = CGPoint(x: margin + 10, y: yPosition)
                CTLineDraw(notesLine, context)
                yPosition -= 14
            }

            yPosition -= 20
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
            return 0
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
            if !locations.contains(where: { $0.name == location.name && $0.address == location.address }) {
                var newLocation = location
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
                    lastModifiedBy: currentUserName,
                    sortOrder: Int32(locations.count)
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
        guard lines.count > 1 else { return 0 }

        var count = 0
        for i in 1..<lines.count {
            let columns = parseCSVLine(lines[i])
            guard columns.count >= 5 else { continue }

            let name = columns[safe: 1] ?? ""
            let address = columns[safe: 2] ?? ""

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

    // MARK: - Core Data Save

    private func saveContext() {
        guard let context = context, context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("❌ Failed to save location context: \(error)")
        }
    }

    // MARK: - Legacy JSON Migration

    private func checkAndMigrateLegacyData() {
        let locationsFile = legacyLocationsFileURL

        // Check if legacy JSON files exist
        guard FileManager.default.fileExists(atPath: locationsFile.path) else {
            print("📍 No legacy JSON data to migrate")

            // Initialize defaults for empty project
            if locations.isEmpty {
                initializeDefaultFolders()
            }
            return
        }

        print("📍 Found legacy JSON data, starting migration...")

        // Load legacy locations
        if let data = try? Data(contentsOf: locationsFile) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let legacyLocations = try? decoder.decode([LocationItem].self, from: data) {
                print("📍 Migrating \(legacyLocations.count) locations from JSON...")

                for location in legacyLocations {
                    addLocation(location)
                }

                print("✅ Migration complete")

                // Archive the old files (don't delete in case user needs them)
                let archiveFolder = legacyAppSupportFolder.appendingPathComponent("migrated_\(Date().timeIntervalSince1970)")
                try? FileManager.default.createDirectory(at: archiveFolder, withIntermediateDirectories: true)

                let filesToArchive = [
                    "locations.json", "folders.json", "comments.json",
                    "documents.json", "assignments.json", "approvals.json", "photo_tags.json"
                ]

                for file in filesToArchive {
                    let source = legacyAppSupportFolder.appendingPathComponent(file)
                    let dest = archiveFolder.appendingPathComponent(file)
                    try? FileManager.default.moveItem(at: source, to: dest)
                }

                print("📍 Archived legacy files to: \(archiveFolder.path)")
            }
        }

        // Load legacy folders
        let foldersFile = legacyFoldersFileURL
        if let data = try? Data(contentsOf: foldersFile) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let legacyFolders = try? decoder.decode([LocationFolder].self, from: data) {
                for folder in legacyFolders {
                    addFolder(folder)
                }
            }
        }
    }

    private func initializeDefaultFolders() {
        let defaultFolders = [
            LocationFolder(name: "All Locations", colorHex: "#007AFF", iconName: "mappin.circle.fill", sortOrder: 0),
            LocationFolder(name: "Favorites", colorHex: "#FF9500", iconName: "star.fill", sortOrder: 1),
            LocationFolder(name: "Pending Approval", colorHex: "#FF3B30", iconName: "clock.fill", sortOrder: 2),
            LocationFolder(name: "Approved", colorHex: "#34C759", iconName: "checkmark.circle.fill", sortOrder: 3)
        ]

        for folder in defaultFolders {
            addFolder(folder)
        }

        print("📍 Created default folders")
    }
}

// MARK: - Array Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
