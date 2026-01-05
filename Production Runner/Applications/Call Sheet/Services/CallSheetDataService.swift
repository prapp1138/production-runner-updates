// MARK: - Call Sheet Data Service
// Production Runner - Call Sheet Module
// Handles data synchronization between Call Sheets and other Production Runner apps

import SwiftUI
import CoreData
import Combine

// MARK: - Call Sheet Data Service

@MainActor
final class CallSheetDataService: ObservableObject {
    static let shared = CallSheetDataService()

    // MARK: Published State
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    // MARK: Private Properties
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotificationObservers()
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Listen for scheduler changes
        NotificationCenter.default.publisher(for: Notification.Name("schedulerSceneOrderChanged"))
            .sink { [weak self] _ in
                self?.handleSchedulerUpdate()
            }
            .store(in: &cancellables)

        // Listen for breakdown changes
        NotificationCenter.default.publisher(for: Notification.Name("breakdownsSceneSynced"))
            .sink { [weak self] _ in
                self?.handleBreakdownUpdate()
            }
            .store(in: &cancellables)

        // Listen for contact changes
        NotificationCenter.default.publisher(for: Notification.Name("contactsDidChange"))
            .sink { [weak self] _ in
                self?.handleContactsUpdate()
            }
            .store(in: &cancellables)
    }

    private func handleSchedulerUpdate() {
        // Notify UI that scheduler data has changed
        NotificationCenter.default.post(name: .callSheetDataDidChange, object: nil)
    }

    private func handleBreakdownUpdate() {
        NotificationCenter.default.post(name: .callSheetDataDidChange, object: nil)
    }

    private func handleContactsUpdate() {
        NotificationCenter.default.post(name: .callSheetDataDidChange, object: nil)
    }

    // MARK: - Core Data Operations

    /// Save a call sheet to Core Data
    func saveCallSheet(_ callSheet: CallSheet, projectID: NSManagedObjectID, in context: NSManagedObjectContext) {
        guard let project = try? context.existingObject(with: projectID) else {
            #if DEBUG
            print("CallSheetDataService: Failed to load project for saving")
            #endif
            return
        }

        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "CallSheetEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", callSheet.id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            let entity: NSManagedObject

            if let existingEntity = results.first {
                entity = existingEntity
            } else {
                entity = NSEntityDescription.insertNewObject(forEntityName: "CallSheetEntity", into: context)
                entity.setValue(callSheet.id, forKey: "id")
                entity.setValue(project, forKey: "project")
            }

            // Basic Info
            entity.setValue(callSheet.title, forKey: "title")
            entity.setValue(callSheet.productionCompany, forKey: "productionCompany")
            entity.setValue(callSheet.productionCompanyImageData, forKey: "productionCompanyImageData")
            entity.setValue(callSheet.shootDate, forKey: "shootDate")
            entity.setValue(callSheet.dayNumber, forKey: "dayNumber")
            entity.setValue(callSheet.totalDays, forKey: "totalDays")
            entity.setValue(callSheet.status.rawValue, forKey: "status")

            // Section configuration as JSON
            if let sectionOrderJSON = try? JSONEncoder().encode(callSheet.sectionOrder.map { $0.rawValue }) {
                entity.setValue(String(data: sectionOrderJSON, encoding: .utf8), forKey: "sectionOrder")
            }

            // Key Personnel
            entity.setValue(callSheet.director, forKey: "director")
            entity.setValue(callSheet.firstAD, forKey: "assistantDirector")
            entity.setValue(callSheet.producer, forKey: "producer")
            entity.setValue(callSheet.dop, forKey: "dop")
            entity.setValue(callSheet.productionManager, forKey: "productionManager")

            // Call Times - ISO8601 format
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]

            entity.setValue(callSheet.crewCall.map { formatter.string(from: $0) }, forKey: "crewCall")
            entity.setValue(callSheet.shootingCall.map { formatter.string(from: $0) }, forKey: "shootingCall")
            entity.setValue(callSheet.breakfast.map { formatter.string(from: $0) }, forKey: "breakfast")
            entity.setValue(callSheet.lunch.map { formatter.string(from: $0) }, forKey: "lunch")
            entity.setValue(callSheet.estimatedWrap.map { formatter.string(from: $0) }, forKey: "estimatedWrap")
            entity.setValue(callSheet.gracePeriod, forKey: "walkaway")

            // Location Info
            entity.setValue(callSheet.shootingLocation, forKey: "shootingLocation")
            entity.setValue(callSheet.locationAddress, forKey: "locationAddress")
            entity.setValue(callSheet.parkingInstructions, forKey: "locationParking")
            entity.setValue(callSheet.basecamp, forKey: "basecamp")
            entity.setValue(callSheet.crewParking, forKey: "crewParking")
            entity.setValue(callSheet.nearestHospital, forKey: "nearestHospital")

            // Weather
            entity.setValue(callSheet.weatherHigh, forKey: "weatherHigh")
            entity.setValue(callSheet.weatherLow, forKey: "weatherLow")
            entity.setValue(callSheet.weatherConditions, forKey: "weatherConditions")
            entity.setValue(callSheet.sunrise, forKey: "sunrise")
            entity.setValue(callSheet.sunset, forKey: "sunset")

            // JSON-encoded arrays
            if let scheduleJSON = try? JSONEncoder().encode(callSheet.scheduleItems) {
                let jsonString = String(data: scheduleJSON, encoding: .utf8)
                entity.setValue(jsonString, forKey: "scheduleItemsJSON")
                print("📄 CallSheetDataService: Saved \(callSheet.scheduleItems.count) schedule items to JSON")
                if callSheet.scheduleItems.count > 0 {
                    print("📄   First item: '\(callSheet.scheduleItems[0].intExt.rawValue). \(callSheet.scheduleItems[0].setDescription)'")
                }
            }
            if let castJSON = try? JSONEncoder().encode(callSheet.castMembers) {
                entity.setValue(String(data: castJSON, encoding: .utf8), forKey: "castMembersJSON")
            }
            if let crewJSON = try? JSONEncoder().encode(callSheet.crewMembers) {
                entity.setValue(String(data: crewJSON, encoding: .utf8), forKey: "crewMembersJSON")
            }

            // Notes
            entity.setValue(callSheet.productionNotes, forKey: "productionNotes")
            entity.setValue(callSheet.safetyNotes, forKey: "safetyNotes")
            entity.setValue(callSheet.advanceSchedule, forKey: "advanceSchedule")

            // Metadata
            entity.setValue(callSheet.createdDate, forKey: "createdDate")
            entity.setValue(Date(), forKey: "lastModified")

            try context.save()
            lastSyncDate = Date()

            #if DEBUG
            print("CallSheetDataService: Saved call sheet '\(callSheet.title)'")
            #endif
        } catch {
            syncError = error.localizedDescription
            #if DEBUG
            print("CallSheetDataService: Failed to save - \(error)")
            #endif
        }
    }

    /// Load all call sheets for a project
    func loadCallSheets(projectID: NSManagedObjectID, in context: NSManagedObjectContext) -> [CallSheet] {
        guard let project = try? context.existingObject(with: projectID) else {
            #if DEBUG
            print("CallSheetDataService: Failed to load project")
            #endif
            return []
        }

        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "CallSheetEntity")
        fetchRequest.predicate = NSPredicate(format: "project == %@", project)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "shootDate", ascending: true)]

        do {
            let entities = try context.fetch(fetchRequest)
            let sheets = entities.compactMap { convertEntityToCallSheet($0) }
            #if DEBUG
            print("CallSheetDataService: Loaded \(sheets.count) call sheets")
            #endif
            return sheets
        } catch {
            #if DEBUG
            print("CallSheetDataService: Failed to load - \(error)")
            #endif
            return []
        }
    }

    /// Delete a call sheet
    func deleteCallSheet(_ callSheet: CallSheet, in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "CallSheetEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", callSheet.id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            if let entity = try context.fetch(fetchRequest).first {
                context.delete(entity)
                try context.save()
                #if DEBUG
                print("CallSheetDataService: Deleted call sheet '\(callSheet.title)'")
                #endif
            }
        } catch {
            #if DEBUG
            print("CallSheetDataService: Failed to delete - \(error)")
            #endif
        }
    }

    // MARK: - Entity Conversion

    private func convertEntityToCallSheet(_ entity: NSManagedObject) -> CallSheet? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let title = entity.value(forKey: "title") as? String,
              let shootDate = entity.value(forKey: "shootDate") as? Date,
              let statusRaw = entity.value(forKey: "status") as? String,
              let status = CallSheetStatus(rawValue: statusRaw),
              let createdDate = entity.value(forKey: "createdDate") as? Date,
              let lastModified = entity.value(forKey: "lastModified") as? Date else {
            return nil
        }

        // Decode section order
        var sectionOrder: [CallSheetSectionType] = CallSheetSectionType.allCases
        if let sectionOrderString = entity.value(forKey: "sectionOrder") as? String,
           let data = sectionOrderString.data(using: .utf8),
           let rawValues = try? JSONDecoder().decode([String].self, from: data) {
            sectionOrder = rawValues.compactMap { CallSheetSectionType(rawValue: $0) }
        }

        // Decode arrays
        var scheduleItems: [ScheduleItem] = []
        if let scheduleJSON = entity.value(forKey: "scheduleItemsJSON") as? String,
           let data = scheduleJSON.data(using: .utf8) {
            do {
                scheduleItems = try JSONDecoder().decode([ScheduleItem].self, from: data)
                print("📄 CallSheetDataService: Successfully decoded \(scheduleItems.count) schedule items from JSON")
                if scheduleItems.count > 0 {
                    print("📄   First item: '\(scheduleItems[0].intExt.rawValue). \(scheduleItems[0].setDescription)'")
                }
            } catch {
                print("📄 CallSheetDataService: ❌ JSON decoding failed: \(error)")
                print("📄   JSON string length: \(scheduleJSON.count) characters")
                if scheduleJSON.count < 1000 {
                    print("📄   JSON content: \(scheduleJSON)")
                }
                scheduleItems = []
            }
        } else {
            print("📄 CallSheetDataService: No scheduleItemsJSON found in entity")
        }

        var castMembers: [CastMember] = []
        if let castJSON = entity.value(forKey: "castMembersJSON") as? String,
           let data = castJSON.data(using: .utf8) {
            castMembers = (try? JSONDecoder().decode([CastMember].self, from: data)) ?? []
        }

        var crewMembers: [CrewMember] = []
        if let crewJSON = entity.value(forKey: "crewMembersJSON") as? String,
           let data = crewJSON.data(using: .utf8) {
            crewMembers = (try? JSONDecoder().decode([CrewMember].self, from: data)) ?? []
        }

        let sectionConfigs = sectionOrder.map { CallSheetSectionConfig(sectionType: $0) }

        return CallSheet(
            id: id,
            title: title,
            projectName: (entity.value(forKey: "project") as? NSManagedObject)?.value(forKey: "name") as? String ?? "",
            productionCompany: entity.value(forKey: "productionCompany") as? String ?? "",
            productionCompanyImageData: entity.value(forKey: "productionCompanyImageData") as? Data,
            shootDate: shootDate,
            dayNumber: entity.value(forKey: "dayNumber") as? Int ?? 1,
            totalDays: entity.value(forKey: "totalDays") as? Int ?? 1,
            status: status,
            templateType: .featureFilm,
            sectionOrder: sectionOrder,
            sectionConfigs: sectionConfigs,
            director: entity.value(forKey: "director") as? String ?? "",
            firstAD: entity.value(forKey: "assistantDirector") as? String ?? "",
            secondAD: "",
            producer: entity.value(forKey: "producer") as? String ?? "",
            lineProducer: "",
            upm: "",
            dop: entity.value(forKey: "dop") as? String ?? "",
            productionManager: entity.value(forKey: "productionManager") as? String ?? "",
            productionCoordinator: "",
            crewCall: parseTimeString(entity.value(forKey: "crewCall") as? String),
            onSetCall: nil,
            shootingCall: parseTimeString(entity.value(forKey: "shootingCall") as? String),
            firstShotCall: nil,
            breakfast: parseTimeString(entity.value(forKey: "breakfast") as? String),
            lunch: parseTimeString(entity.value(forKey: "lunch") as? String),
            secondMeal: nil,
            estimatedWrap: parseTimeString(entity.value(forKey: "estimatedWrap") as? String),
            hardOut: nil,
            gracePeriod: entity.value(forKey: "walkaway") as? String ?? "",
            shootingLocation: entity.value(forKey: "shootingLocation") as? String ?? "",
            locationAddress: entity.value(forKey: "locationAddress") as? String ?? "",
            locationContact: "",
            locationPhone: "",
            parkingInstructions: entity.value(forKey: "locationParking") as? String ?? "",
            basecamp: entity.value(forKey: "basecamp") as? String ?? "",
            basecampAddress: "",
            crewParking: entity.value(forKey: "crewParking") as? String ?? "",
            talentParking: "",
            nearestHospital: entity.value(forKey: "nearestHospital") as? String ?? "",
            hospitalAddress: "",
            hospitalPhone: "",
            weatherHigh: entity.value(forKey: "weatherHigh") as? String ?? "",
            weatherLow: entity.value(forKey: "weatherLow") as? String ?? "",
            weatherConditions: entity.value(forKey: "weatherConditions") as? String ?? "",
            sunrise: entity.value(forKey: "sunrise") as? String ?? "",
            sunset: entity.value(forKey: "sunset") as? String ?? "",
            humidity: "",
            windSpeed: "",
            precipitation: "",
            scheduleItems: scheduleItems,
            castMembers: castMembers,
            crewMembers: crewMembers,
            backgroundActors: [],
            productionNotes: entity.value(forKey: "productionNotes") as? String ?? "",
            safetyNotes: entity.value(forKey: "safetyNotes") as? String ?? "",
            advanceSchedule: entity.value(forKey: "advanceSchedule") as? String ?? "",
            specialEquipment: "",
            walkie: "",
            createdDate: createdDate,
            lastModified: lastModified,
            revisionNumber: 0,
            revisionColor: .white
        )
    }

    private func parseTimeString(_ timeString: String?) -> Date? {
        guard let timeString = timeString, !timeString.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
        if let date = formatter.date(from: timeString) {
            return date
        }

        // Fallback to time-only format
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        if let time = timeFormatter.date(from: timeString) {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: Date())
        }

        return nil
    }

    // MARK: - Import from Other Apps

    /// Import scenes directly from Breakdowns (SceneEntity)
    /// This allows creating call sheets without needing shoot days set up
    func importScenesFromBreakdowns(
        scenes: [SceneEntity],
        in context: NSManagedObjectContext
    ) -> [ScheduleItem] {
        print("📄 CallSheetDataService: importScenesFromBreakdowns called with \(scenes.count) scenes")

        // Sort scenes by displayOrder
        let sortedScenes = scenes.sorted { s1, s2 in
            s1.displayOrder < s2.displayOrder
        }

        // Convert SceneEntity to ScheduleItem
        var scheduleItems: [ScheduleItem] = []

        for (index, scene) in sortedScenes.enumerated() {
            // Debug: Log raw scene data
            if index < 5 {
                print("📄 --- Scene[\(index)] Raw Data ---")
                print("📄   number: '\(scene.number ?? "nil")'")
                print("📄   sceneSlug: '\(scene.sceneSlug ?? "nil")'")
                print("📄   scriptLocation: '\(scene.scriptLocation ?? "nil")'")
                print("📄   locationType: '\(scene.locationType ?? "nil")'")
                print("📄   timeOfDay: '\(scene.timeOfDay ?? "nil")'")
            }

            // Parse the scene heading to extract INT/EXT, location, and time of day
            let heading = scene.sceneSlug ?? ""
            let parsed = parseSceneHeading(heading)

            if index < 5 {
                print("📄   parsed.intExt: '\(parsed.intExt)'")
                print("📄   parsed.location: '\(parsed.location)'")
                print("📄   parsed.timeOfDay: '\(parsed.timeOfDay)'")
            }

            // Use parsed values, falling back to stored values if parsing fails
            let intExt: ScheduleItem.IntExt
            if !parsed.intExt.isEmpty {
                let intExtRaw = parsed.intExt.uppercased()
                if intExtRaw.contains("EXT") && intExtRaw.contains("INT") {
                    intExt = .intExt
                } else if intExtRaw.contains("EXT") {
                    intExt = .ext
                } else {
                    intExt = .int
                }
            } else {
                // Fall back to locationType field
                let locationTypeRaw = (scene.locationType ?? "").uppercased()
                if locationTypeRaw.contains("EXT") && locationTypeRaw.contains("INT") {
                    intExt = .intExt
                } else if locationTypeRaw.contains("EXT") {
                    intExt = .ext
                } else {
                    intExt = .int
                }
            }

            // Parse DAY/NIGHT from parsed heading or timeOfDay field
            let dayNight: ScheduleItem.DayNight
            let timeOfDayRaw = (!parsed.timeOfDay.isEmpty ? parsed.timeOfDay : (scene.timeOfDay ?? "DAY")).uppercased()
            switch timeOfDayRaw {
            case "NIGHT": dayNight = .night
            case "DAWN": dayNight = .dawn
            case "DUSK": dayNight = .dusk
            case "MORNING": dayNight = .morning
            case "AFTERNOON": dayNight = .afternoon
            case "EVENING": dayNight = .evening
            case "CONTINUOUS": dayNight = .continuous
            case "LATER": dayNight = .later
            case "MOMENTS LATER": dayNight = .momentsLater
            case "SAME TIME": dayNight = .sameTime
            default: dayNight = .day
            }

            // Calculate pages from eighths (8 eighths = 1 page)
            let pages = Double(scene.pageEighths) / 8.0

            // Parse cast IDs from CSV string
            let castIds: [String]
            if let castCSV = scene.castIDs, !castCSV.isEmpty {
                castIds = castCSV.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else {
                castIds = []
            }

            // Get set description - use parsed location (without INT/EXT and time of day)
            let setDescription = !parsed.location.isEmpty ? parsed.location : (scene.scriptLocation ?? "")

            // Get location - could be from breakdown or use the same as set description
            let location = scene.scriptLocation ?? setDescription

            let item = ScheduleItem(
                sceneNumber: scene.number ?? "",
                setDescription: setDescription,
                intExt: intExt,
                dayNight: dayNight,
                pages: pages,
                estimatedTime: "",
                castIds: castIds,
                location: location,
                notes: scene.descriptionText ?? "",
                specialRequirements: "",
                sortOrder: index
            )

            // Debug: Log final ScheduleItem
            if index < 5 {
                print("📄 --- Final ScheduleItem[\(index)] ---")
                print("📄   sceneNumber: '\(item.sceneNumber)'")
                print("📄   setDescription: '\(item.setDescription)'")
                print("📄   intExt: '\(item.intExt.rawValue)'")
                print("📄   dayNight: '\(item.dayNight.rawValue)'")
                print("📄   PDF will show: '\(item.intExt.rawValue). \(item.setDescription)'")
            }

            scheduleItems.append(item)
        }

        print("📄 CallSheetDataService: Converted \(scheduleItems.count) scenes to ScheduleItems")
        return scheduleItems
    }

    /// Import scenes from Scheduler for a specific shoot day
    func importScenesFromScheduler(
        shootDayID: UUID,
        projectID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) -> [ScheduleItem] {
        print("CallSheetDataService: importScenesFromScheduler called for day \(shootDayID)")

        // Fetch the ShootDayEntity
        let shootDayFetch: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
        shootDayFetch.predicate = NSPredicate(format: "id == %@", shootDayID as CVarArg)
        shootDayFetch.fetchLimit = 1

        guard let shootDay = try? context.fetch(shootDayFetch).first else {
            print("CallSheetDataService: ShootDay not found for ID \(shootDayID)")
            return []
        }

        // Get scenes assigned to this shoot day
        guard let scenes = shootDay.scenes as? Set<SceneEntity> else {
            print("CallSheetDataService: No scenes found for shoot day")
            return []
        }

        // Sort scenes by scheduleOrder, then displayOrder
        let sortedScenes = scenes.sorted { s1, s2 in
            if s1.scheduleOrder != s2.scheduleOrder {
                return s1.scheduleOrder < s2.scheduleOrder
            }
            return s1.displayOrder < s2.displayOrder
        }

        print("CallSheetDataService: Found \(sortedScenes.count) scenes for shoot day")

        // Convert SceneEntity to ScheduleItem
        var scheduleItems: [ScheduleItem] = []

        for (index, scene) in sortedScenes.enumerated() {
            // Debug: Log all raw scene data fields
            print("CallSheetDataService: --- Scene[\(index)] Raw Data ---")
            print("  number: '\(scene.number ?? "nil")'")
            print("  sceneSlug: '\(scene.sceneSlug ?? "nil")'")
            print("  scriptLocation: '\(scene.scriptLocation ?? "nil")'")
            print("  locationType: '\(scene.locationType ?? "nil")'")
            print("  timeOfDay: '\(scene.timeOfDay ?? "nil")'")

            // Parse the scene heading to extract INT/EXT, location, and time of day
            let heading = scene.sceneSlug ?? ""
            let parsed = parseSceneHeading(heading)
            print("  parsed.intExt: '\(parsed.intExt)'")
            print("  parsed.location: '\(parsed.location)'")
            print("  parsed.timeOfDay: '\(parsed.timeOfDay)'")

            // Use parsed values, falling back to stored values if parsing fails
            let intExt: ScheduleItem.IntExt
            if !parsed.intExt.isEmpty {
                let intExtRaw = parsed.intExt.uppercased()
                if intExtRaw.contains("EXT") && intExtRaw.contains("INT") {
                    intExt = .intExt
                } else if intExtRaw.contains("EXT") {
                    intExt = .ext
                } else {
                    intExt = .int
                }
            } else {
                // Fall back to locationType field
                let locationTypeRaw = (scene.locationType ?? "").uppercased()
                if locationTypeRaw.contains("EXT") && locationTypeRaw.contains("INT") {
                    intExt = .intExt
                } else if locationTypeRaw.contains("EXT") {
                    intExt = .ext
                } else {
                    intExt = .int
                }
            }

            // Parse DAY/NIGHT from parsed heading or timeOfDay field
            let dayNight: ScheduleItem.DayNight
            let timeOfDayRaw = (!parsed.timeOfDay.isEmpty ? parsed.timeOfDay : (scene.timeOfDay ?? "DAY")).uppercased()
            switch timeOfDayRaw {
            case "NIGHT": dayNight = .night
            case "DAWN": dayNight = .dawn
            case "DUSK": dayNight = .dusk
            case "MORNING": dayNight = .morning
            case "AFTERNOON": dayNight = .afternoon
            case "EVENING": dayNight = .evening
            case "CONTINUOUS": dayNight = .continuous
            case "LATER": dayNight = .later
            case "MOMENTS LATER": dayNight = .momentsLater
            case "SAME TIME": dayNight = .sameTime
            default: dayNight = .day
            }

            // Calculate pages from eighths (8 eighths = 1 page)
            let pages = Double(scene.pageEighths) / 8.0

            // Parse cast IDs from CSV string
            let castIds: [String]
            if let castCSV = scene.castIDs, !castCSV.isEmpty {
                castIds = castCSV.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else {
                castIds = []
            }

            // Get set description - use parsed location (without INT/EXT and time of day)
            // This is what appears in the "SET DESCRIPTION" column
            let setDescription = !parsed.location.isEmpty ? parsed.location : (scene.scriptLocation ?? "")

            // Get location - could be from breakdown or use the same as set description
            let location = scene.scriptLocation ?? setDescription

            let item = ScheduleItem(
                sceneNumber: scene.number ?? "",
                setDescription: setDescription,
                intExt: intExt,
                dayNight: dayNight,
                pages: pages,
                estimatedTime: "",
                castIds: castIds,
                location: location,
                notes: scene.descriptionText ?? "",
                specialRequirements: "",
                sortOrder: index
            )

            // Debug: Final ScheduleItem values
            print("CallSheetDataService: --- Final ScheduleItem[\(index)] ---")
            print("  sceneNumber: '\(item.sceneNumber)'")
            print("  intExt: '\(item.intExt.rawValue)'")
            print("  setDescription: '\(item.setDescription)'")
            print("  dayNight: '\(item.dayNight.rawValue)'")
            print("  location: '\(item.location)'")
            print("  -> PDF will show: '\(item.intExt.rawValue). \(item.setDescription)'")

            scheduleItems.append(item)
        }

        print("CallSheetDataService: Converted \(scheduleItems.count) scenes to ScheduleItems")
        return scheduleItems
    }

    /// Parse a scene heading like "INT. KITCHEN - DAY" into components
    private func parseSceneHeading(_ heading: String) -> (intExt: String, location: String, timeOfDay: String) {
        let raw = heading.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Common INT/EXT patterns
        var intExt = ""
        var remainder = raw

        // Check for INT./EXT. patterns
        let intExtPatterns = ["INT./EXT.", "INT/EXT.", "INT./EXT", "INT/EXT", "I/E.", "I/E",
                              "EXT./INT.", "EXT/INT.", "EXT./INT", "EXT/INT",
                              "INT.", "INT ", "EXT.", "EXT "]
        for pattern in intExtPatterns {
            if raw.hasPrefix(pattern) {
                intExt = pattern.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                remainder = String(raw.dropFirst(pattern.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Now parse location and time of day from remainder
        // Format is typically: "LOCATION - TIME OF DAY" or "LOCATION -- TIME OF DAY"
        var location = remainder
        var timeOfDay = ""

        // Look for " - " or " -- " separator
        if let dashRange = remainder.range(of: " - ", options: .backwards) {
            location = String(remainder[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            timeOfDay = String(remainder[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let dashRange = remainder.range(of: " -- ", options: .backwards) {
            location = String(remainder[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            timeOfDay = String(remainder[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        return (intExt, location, timeOfDay)
    }

    /// Import cast from Contacts app
    func importCastFromContacts(
        projectID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) -> [CastMember] {
        // This would integrate with the Contacts app
        #if DEBUG
        print("CallSheetDataService: importCastFromContacts called")
        #endif
        return []
    }

    /// Import crew from Contacts app by department
    func importCrewFromContacts(
        departments: [CrewDepartment],
        projectID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) -> [CrewMember] {
        #if DEBUG
        print("CallSheetDataService: importCrewFromContacts called for \(departments.count) departments")
        #endif
        return []
    }

    /// Import location from Locations app
    func importLocationFromLocations(
        locationID: UUID,
        projectID: NSManagedObjectID,
        in context: NSManagedObjectContext
    ) -> (name: String, address: String, parking: String, contact: String, phone: String)? {
        #if DEBUG
        print("CallSheetDataService: importLocationFromLocations called for \(locationID)")
        #endif
        return nil
    }

    // MARK: - Weather Integration

    /// Fetch weather data for a location and date
    /// Uses OpenWeatherMap API - requires API key in environment variable OPENWEATHER_API_KEY
    func fetchWeather(for location: String, date: Date) async -> WeatherData? {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"], !apiKey.isEmpty else {
            #if DEBUG
            print("CallSheetDataService: No OpenWeatherMap API key found. Set OPENWEATHER_API_KEY environment variable.")
            #endif
            return nil
        }

        // First, geocode the location to get coordinates
        guard let coordinates = await geocodeLocation(location, apiKey: apiKey) else {
            #if DEBUG
            print("CallSheetDataService: Failed to geocode location '\(location)'")
            #endif
            return nil
        }

        // Check if date is within 5 days (forecast limit)
        let daysDifference = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0

        if daysDifference < 0 {
            // Historical data - use current weather as fallback
            return await fetchCurrentWeather(lat: coordinates.lat, lon: coordinates.lon, apiKey: apiKey, location: location)
        } else if daysDifference <= 5 {
            // Use forecast API
            return await fetchForecastWeather(lat: coordinates.lat, lon: coordinates.lon, date: date, apiKey: apiKey)
        } else {
            // Beyond forecast range - return nil
            #if DEBUG
            print("CallSheetDataService: Date is beyond 5-day forecast range")
            #endif
            return nil
        }
    }

    private func geocodeLocation(_ location: String, apiKey: String) async -> (lat: Double, lon: Double)? {
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        let urlString = "https://api.openweathermap.org/geo/1.0/direct?q=\(encodedLocation)&limit=1&appid=\(apiKey)"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let locations = try JSONDecoder().decode([GeocodingResult].self, from: data)
            guard let first = locations.first else { return nil }

            return (lat: first.lat, lon: first.lon)
        } catch {
            #if DEBUG
            print("CallSheetDataService: Geocoding error: \(error)")
            #endif
            return nil
        }
    }

    private func fetchCurrentWeather(lat: Double, lon: Double, apiKey: String, location: String) async -> WeatherData? {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let weatherResponse = try JSONDecoder().decode(CurrentWeatherResponse.self, from: data)

            return WeatherData(
                high: "\(Int(weatherResponse.main.temp_max))°F",
                low: "\(Int(weatherResponse.main.temp_min))°F",
                conditions: weatherResponse.weather.first?.description.capitalized ?? "Unknown",
                humidity: "\(weatherResponse.main.humidity)%",
                windSpeed: "\(Int(weatherResponse.wind.speed)) mph",
                precipitation: weatherResponse.rain?.oneHour != nil ? "\(weatherResponse.rain?.oneHour ?? 0) mm" : "0 mm",
                sunrise: formatTime(from: weatherResponse.sys.sunrise),
                sunset: formatTime(from: weatherResponse.sys.sunset)
            )
        } catch {
            #if DEBUG
            print("CallSheetDataService: Current weather error: \(error)")
            #endif
            return nil
        }
    }

    private func fetchForecastWeather(lat: Double, lon: Double, date: Date, apiKey: String) async -> WeatherData? {
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let forecastResponse = try JSONDecoder().decode(ForecastWeatherResponse.self, from: data)

            // Find forecasts for the target date
            let calendar = Calendar.current
            let targetDay = calendar.startOfDay(for: date)

            let matchingForecasts = forecastResponse.list.filter { forecast in
                let forecastDate = Date(timeIntervalSince1970: TimeInterval(forecast.dt))
                return calendar.isDate(forecastDate, inSameDayAs: targetDay)
            }

            guard !matchingForecasts.isEmpty else { return nil }

            // Calculate daily aggregates
            let temps = matchingForecasts.map { $0.main.temp }
            let high = temps.max() ?? 0
            let low = temps.min() ?? 0

            // Use the midday forecast for conditions (around 12pm)
            let middayForecast = matchingForecasts.min { abs($0.dt % 86400 - 43200) < abs($1.dt % 86400 - 43200) } ?? matchingForecasts.first!

            let avgHumidity = matchingForecasts.map { $0.main.humidity }.reduce(0, +) / matchingForecasts.count
            let avgWindSpeed = matchingForecasts.map { $0.wind.speed }.reduce(0, +) / Double(matchingForecasts.count)

            let totalPrecip = matchingForecasts.compactMap { $0.rain?.threeHour }.reduce(0, +)

            // Calculate sunrise/sunset for target date (use first forecast time as reference)
            let sunriseTime = formatTime(from: forecastResponse.city.sunrise)
            let sunsetTime = formatTime(from: forecastResponse.city.sunset)

            return WeatherData(
                high: "\(Int(high))°F",
                low: "\(Int(low))°F",
                conditions: middayForecast.weather.first?.description.capitalized ?? "Unknown",
                humidity: "\(avgHumidity)%",
                windSpeed: "\(Int(avgWindSpeed)) mph",
                precipitation: totalPrecip > 0 ? "\(String(format: "%.1f", totalPrecip)) mm" : "0 mm",
                sunrise: sunriseTime,
                sunset: sunsetTime
            )
        } catch {
            #if DEBUG
            print("CallSheetDataService: Forecast weather error: \(error)")
            #endif
            return nil
        }
    }

    private func formatTime(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Weather Data Model

struct WeatherData {
    let high: String
    let low: String
    let conditions: String
    let humidity: String
    let windSpeed: String
    let precipitation: String
    let sunrise: String
    let sunset: String
}

// MARK: - OpenWeatherMap API Response Models

private struct GeocodingResult: Codable {
    let lat: Double
    let lon: Double
    let name: String
}

private struct CurrentWeatherResponse: Codable {
    let main: MainWeather
    let weather: [Weather]
    let wind: Wind
    let rain: Rain?
    let sys: Sys

    struct MainWeather: Codable {
        let temp: Double
        let temp_min: Double
        let temp_max: Double
        let humidity: Int
    }

    struct Weather: Codable {
        let description: String
    }

    struct Wind: Codable {
        let speed: Double
    }

    struct Rain: Codable {
        let oneHour: Double?

        enum CodingKeys: String, CodingKey {
            case oneHour = "1h"
        }
    }

    struct Sys: Codable {
        let sunrise: Int
        let sunset: Int
    }
}

private struct ForecastWeatherResponse: Codable {
    let list: [ForecastItem]
    let city: City

    struct ForecastItem: Codable {
        let dt: Int
        let main: MainWeather
        let weather: [Weather]
        let wind: Wind
        let rain: Rain?

        struct MainWeather: Codable {
            let temp: Double
            let humidity: Int
        }

        struct Weather: Codable {
            let description: String
        }

        struct Wind: Codable {
            let speed: Double
        }

        struct Rain: Codable {
            let threeHour: Double?

            enum CodingKeys: String, CodingKey {
                case threeHour = "3h"
            }
        }
    }

    struct City: Codable {
        let sunrise: Int
        let sunset: Int
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let callSheetDataDidChange = Notification.Name("callSheetDataDidChange")
    static let callSheetDidSave = Notification.Name("callSheetDidSave")
}
