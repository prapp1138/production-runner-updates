import SwiftUI
import CoreData
import Combine

// MARK: - Live Mode Store
class LiveModeStore: ObservableObject {
    // MARK: - Published Properties

    // Current time (updates every second)
    @Published var currentTimeString: String = ""

    // Current shoot day number
    @Published var currentShootDay: Int?

    // Current shoot date
    @Published var currentShootDate: Date?

    // Current shoot day entity
    @Published var currentShootDayEntity: ShootDayEntity?

    // Current project
    @Published var currentProject: ProjectEntity?

    // Is currently recording/tracking
    @Published var isRecording: Bool = false

    // Time entries for today
    @Published var todayTimeEntries: [TimeEntry] = []

    // Active timer (for time tracking)
    @Published var activeTimerCategory: TimeEntryCategory?
    @Published var activeTimerStart: Date?

    // MARK: - Private Properties

    private var timerCancellable: AnyCancellable?
    private var context: NSManagedObjectContext?
    private var storeObserver: NSObjectProtocol?

    // MARK: - Initialization

    init() {
        startClockTimer()
        setupStoreObserver()
    }

    deinit {
        timerCancellable?.cancel()
        if let observer = storeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupStoreObserver() {
        storeObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload if time entries changed externally
            if let date = self?.currentShootDate {
                self?.loadTimeEntries(for: date)
            }
        }
    }

    // MARK: - Setup

    func setup(with context: NSManagedObjectContext, project: ProjectEntity? = nil) {
        self.context = context
        self.currentProject = project
        loadCurrentShootDay()
    }

    // MARK: - Clock Timer

    private func startClockTimer() {
        updateTimeString()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimeString()
            }
    }

    private func updateTimeString() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        currentTimeString = formatter.string(from: Date())
    }

    // MARK: - Shoot Day Management

    private func loadCurrentShootDay() {
        guard let context = context, let project = currentProject else {
            currentShootDay = 1
            currentShootDate = Date()
            return
        }

        let today = Calendar.current.startOfDay(for: Date())

        // Find shoot day for today
        let request: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
        request.predicate = NSPredicate(format: "project == %@ AND date >= %@ AND date < %@",
                                         project,
                                         today as NSDate,
                                         Calendar.current.date(byAdding: .day, value: 1, to: today)! as NSDate)
        request.fetchLimit = 1

        do {
            if let shootDay = try context.fetch(request).first {
                currentShootDayEntity = shootDay
                currentShootDay = Int(shootDay.dayNumber)
                currentShootDate = shootDay.date
                loadTimeEntries(for: shootDay.date ?? today)
            } else {
                // No shoot day for today, find the most recent one
                let recentRequest: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
                recentRequest.predicate = NSPredicate(format: "project == %@", project)
                recentRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                recentRequest.fetchLimit = 1

                if let recent = try context.fetch(recentRequest).first {
                    currentShootDayEntity = recent
                    currentShootDay = Int(recent.dayNumber)
                    currentShootDate = recent.date ?? today
                    loadTimeEntries(for: recent.date ?? today)
                } else {
                    currentShootDay = 1
                    currentShootDate = today
                }
            }
        } catch {
            print("[LiveModeStore] Error loading shoot day: \(error)")
            currentShootDay = 1
            currentShootDate = Date()
        }
    }

    func setShootDay(_ dayNumber: Int, date: Date) {
        currentShootDay = dayNumber
        currentShootDate = date

        // Find the corresponding ShootDayEntity
        if let context = context, let project = currentProject {
            let request: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
            request.predicate = NSPredicate(format: "project == %@ AND dayNumber == %d", project, dayNumber)
            request.fetchLimit = 1

            if let shootDay = try? context.fetch(request).first {
                currentShootDayEntity = shootDay
            }
        }

        loadTimeEntries(for: date)
    }

    // MARK: - Time Entry Management

    func loadTimeEntries(for date: Date) {
        guard let context = context, let project = currentProject else {
            todayTimeEntries = []
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<TimeEntryEntity> = TimeEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "project == %@ AND startTime >= %@ AND startTime < %@",
                                         project,
                                         startOfDay as NSDate,
                                         endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]

        do {
            let entities = try context.fetch(request)
            todayTimeEntries = entities.compactMap { entity in
                TimeEntry(from: entity)
            }
            print("[LiveModeStore] Loaded \(todayTimeEntries.count) time entries for \(date)")
        } catch {
            print("[LiveModeStore] Error loading time entries: \(error)")
            todayTimeEntries = []
        }
    }

    func startTimer(for category: TimeEntryCategory) {
        activeTimerCategory = category
        activeTimerStart = Date()
        isRecording = true
    }

    func stopTimer() -> TimeEntry? {
        guard let category = activeTimerCategory,
              let startTime = activeTimerStart else { return nil }

        let endTime = Date()
        let entry = TimeEntry(
            id: UUID(),
            category: category,
            startTime: startTime,
            endTime: endTime,
            notes: nil
        )

        addTimeEntry(entry)

        activeTimerCategory = nil
        activeTimerStart = nil
        isRecording = false

        return entry
    }

    func addTimeEntry(_ entry: TimeEntry) {
        // Add to local array
        todayTimeEntries.append(entry)

        // Save to Core Data
        guard let context = context, let project = currentProject else {
            print("[LiveModeStore] Warning: No context or project, time entry not persisted")
            return
        }

        let entity = TimeEntryEntity(context: context)
        entity.id = entry.id
        entity.category = entry.category.rawValue
        entity.startTime = entry.startTime
        entity.endTime = entry.endTime
        entity.notes = entry.notes
        entity.sceneNumber = entry.sceneNumber
        entity.createdBy = entry.createdBy
        entity.createdAt = entry.createdAt
        entity.updatedAt = Date()
        entity.project = project

        // Link to shoot day if available
        if let shootDayEntity = currentShootDayEntity {
            entity.shootDayID = shootDayEntity.id
        }

        // Calculate duration if we have both times
        if let endTime = entry.endTime {
            entity.duration = endTime.timeIntervalSince(entry.startTime)
        }

        do {
            try context.save()
            print("[LiveModeStore] Saved time entry: \(entry.category.rawValue) at \(entry.formattedStartTime)")
        } catch {
            print("[LiveModeStore] Error saving time entry: \(error)")
        }
    }

    func removeTimeEntry(_ entry: TimeEntry) {
        // Remove from local array
        todayTimeEntries.removeAll { $0.id == entry.id }

        // Delete from Core Data
        guard let context = context else { return }

        let request: NSFetchRequest<TimeEntryEntity> = TimeEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
                print("[LiveModeStore] Deleted time entry: \(entry.category.rawValue)")
            }
        } catch {
            print("[LiveModeStore] Error deleting time entry: \(error)")
        }
    }

    func updateTimeEntry(_ entry: TimeEntry) {
        // Update local array
        if let index = todayTimeEntries.firstIndex(where: { $0.id == entry.id }) {
            todayTimeEntries[index] = entry
        }

        // Update in Core Data
        guard let context = context else { return }

        let request: NSFetchRequest<TimeEntryEntity> = TimeEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                entity.category = entry.category.rawValue
                entity.startTime = entry.startTime
                entity.endTime = entry.endTime
                entity.notes = entry.notes
                entity.sceneNumber = entry.sceneNumber
                entity.updatedAt = Date()

                if let endTime = entry.endTime {
                    entity.duration = endTime.timeIntervalSince(entry.startTime)
                }

                try context.save()
                print("[LiveModeStore] Updated time entry: \(entry.category.rawValue)")
            }
        } catch {
            print("[LiveModeStore] Error updating time entry: \(error)")
        }
    }

    // MARK: - Computed Properties

    var elapsedTimerString: String? {
        guard let startTime = activeTimerStart else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return formatDuration(elapsed)
    }

    var totalWorkingHours: Double {
        guard let crewCall = todayTimeEntries.first(where: { $0.category == .crewCall })?.startTime,
              let wrap = todayTimeEntries.first(where: { $0.category == .wrap })?.startTime else {
            return 0
        }
        return wrap.timeIntervalSince(crewCall) / 3600.0
    }

    var totalMealBreakTime: Double {
        let mealEntries = todayTimeEntries.filter { $0.category == .lunch || $0.category == .secondMeal }
        return mealEntries.reduce(0) { $0 + ($1.duration ?? 0) } / 60.0 // in minutes
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Time Entry Category
enum TimeEntryCategory: String, CaseIterable, Identifiable, Codable {
    case crewCall = "Crew Call"
    case onSet = "On Set"
    case firstShot = "First Shot"
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case secondMeal = "Second Meal"
    case lastShot = "Last Shot"
    case cameraWrap = "Camera Wrap"
    case wrap = "Wrap"
    case lastManOut = "Last Man Out"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .crewCall: return "person.3.fill"
        case .onSet: return "location.fill"
        case .firstShot: return "camera.fill"
        case .breakfast: return "cup.and.saucer.fill"
        case .lunch: return "fork.knife"
        case .secondMeal: return "fork.knife.circle.fill"
        case .lastShot: return "camera.badge.clock.fill"
        case .cameraWrap: return "camera.badge.ellipsis"
        case .wrap: return "checkmark.circle.fill"
        case .lastManOut: return "door.left.hand.open"
        case .custom: return "clock.fill"
        }
    }

    var color: Color {
        switch self {
        case .crewCall: return .blue
        case .onSet: return .cyan
        case .firstShot: return .green
        case .breakfast: return .orange
        case .lunch: return .orange
        case .secondMeal: return .orange
        case .lastShot: return .purple
        case .cameraWrap: return .pink
        case .wrap: return .red
        case .lastManOut: return .gray
        case .custom: return .secondary
        }
    }

    var sortOrder: Int {
        switch self {
        case .crewCall: return 0
        case .onSet: return 1
        case .firstShot: return 2
        case .breakfast: return 3
        case .lunch: return 4
        case .secondMeal: return 5
        case .lastShot: return 6
        case .cameraWrap: return 7
        case .wrap: return 8
        case .lastManOut: return 9
        case .custom: return 10
        }
    }
}

// MARK: - Time Entry Model
struct TimeEntry: Identifiable, Codable {
    let id: UUID
    var category: TimeEntryCategory
    var startTime: Date
    var endTime: Date?
    var notes: String?
    var sceneNumber: String?
    var createdBy: String?
    var createdAt: Date = Date()

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }

    var formattedEndTime: String? {
        guard let end = endTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: end)
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Initialize from Core Data entity
    init(from entity: TimeEntryEntity) {
        self.id = entity.id ?? UUID()
        self.category = TimeEntryCategory(rawValue: entity.category ?? "") ?? .custom
        self.startTime = entity.startTime ?? Date()
        self.endTime = entity.endTime
        self.notes = entity.notes
        self.sceneNumber = entity.sceneNumber
        self.createdBy = entity.createdBy
        self.createdAt = entity.createdAt ?? Date()
    }

    /// Standard initializer
    init(id: UUID, category: TimeEntryCategory, startTime: Date, endTime: Date?, notes: String?, sceneNumber: String? = nil, createdBy: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.sceneNumber = sceneNumber
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

// MARK: - Teleprompter Settings
struct TeleprompterSettings: Codable {
    var scrollSpeed: Double = 50.0        // Words per minute
    var fontSize: CGFloat = 48.0
    var textColor: String = "white"
    var backgroundColor: String = "black"
    var mirrorMode: Bool = false
    var showTimecode: Bool = true
    var autoScroll: Bool = false
    var selectedSceneNumbers: [String] = []
    var countdownSeconds: Int = 5
    var lineSpacing: CGFloat = 1.5
    var textAlignment: String = "center"  // leading, center, trailing
    var showSceneHeaders: Bool = true
    var highlightCurrentLine: Bool = true

    static var `default`: TeleprompterSettings {
        TeleprompterSettings()
    }
}

// MARK: - Wrap Report Model
struct WrapReportData: Identifiable, Codable {
    let id: UUID
    var shootDate: Date
    var dayNumber: Int

    // Times
    var callTime: Date?
    var firstShotTime: Date?
    var lunchStart: Date?
    var lunchEnd: Date?
    var wrapTime: Date?

    // Calculations
    var totalHours: Double {
        guard let call = callTime, let wrap = wrapTime else { return 0 }
        return wrap.timeIntervalSince(call) / 3600.0
    }

    var mealPenaltyMinutes: Int {
        guard let firstShot = firstShotTime, let lunch = lunchStart else { return 0 }
        let hoursToLunch = lunch.timeIntervalSince(firstShot) / 3600.0
        if hoursToLunch > 6 {
            return Int((hoursToLunch - 6) * 60)
        }
        return 0
    }

    // Scenes
    var scheduledScenes: [String] = []
    var completedScenes: [String] = []
    var partialScenes: [String] = []

    var completionPercentage: Double {
        guard !scheduledScenes.isEmpty else { return 0 }
        return Double(completedScenes.count) / Double(scheduledScenes.count) * 100
    }

    // Notes
    var notes: String = ""
    var weatherConditions: String = ""
    var accidents: String = ""
    var delayNotes: String = ""

    // Status
    var status: WrapReportStatus = .draft
    var signatures: [SignatureData] = []

    var createdAt: Date = Date()
    var submittedAt: Date?

    /// Initialize from Core Data entity
    init(from entity: WrapReportEntity) {
        self.id = entity.id ?? UUID()
        self.shootDate = entity.shootDate ?? Date()
        self.dayNumber = Int(entity.dayNumber)
        self.callTime = entity.callTime
        self.firstShotTime = entity.firstShotTime
        self.lunchStart = entity.lunchStart
        self.lunchEnd = entity.lunchEnd
        self.wrapTime = entity.wrapTime
        self.notes = entity.notes ?? ""
        self.weatherConditions = entity.weatherConditions ?? ""
        self.accidents = entity.accidents ?? ""
        self.delayNotes = entity.delayNotes ?? ""
        self.status = WrapReportStatus(rawValue: entity.status ?? "draft") ?? .draft
        self.createdAt = entity.createdAt ?? Date()
        self.submittedAt = entity.submittedAt

        // Decode scenes from JSON
        if let scheduledJSON = entity.scheduledScenesJSON,
           let data = scheduledJSON.data(using: .utf8),
           let scenes = try? JSONDecoder().decode([String].self, from: data) {
            self.scheduledScenes = scenes
        }
        if let completedJSON = entity.completedScenesJSON,
           let data = completedJSON.data(using: .utf8),
           let scenes = try? JSONDecoder().decode([String].self, from: data) {
            self.completedScenes = scenes
        }
        if let partialJSON = entity.partialScenesJSON,
           let data = partialJSON.data(using: .utf8),
           let scenes = try? JSONDecoder().decode([String].self, from: data) {
            self.partialScenes = scenes
        }

        // Decode signatures from JSON
        if let signatureJSON = entity.signatureDataJSON,
           let data = signatureJSON.data(using: .utf8),
           let sigs = try? JSONDecoder().decode([SignatureData].self, from: data) {
            self.signatures = sigs
        }
    }

    /// Standard initializer
    init(id: UUID, shootDate: Date, dayNumber: Int) {
        self.id = id
        self.shootDate = shootDate
        self.dayNumber = dayNumber
    }
}

enum WrapReportStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case pendingSignatures = "Pending Signatures"
    case submitted = "Submitted"
    case approved = "Approved"

    var color: Color {
        switch self {
        case .draft: return .gray
        case .pendingSignatures: return .orange
        case .submitted: return .blue
        case .approved: return .green
        }
    }
}

// MARK: - Production Report Model
struct ProductionReportData: Identifiable, Codable {
    let id: UUID
    var shootDate: Date
    var dayNumber: Int
    var reportNumber: Int

    // Project Info
    var projectName: String = ""
    var director: String = ""
    var producer: String = ""
    var firstAD: String = ""
    var unitProductionManager: String = ""

    // Call Times
    var crewCall: Date?
    var shootingCall: Date?
    var firstShotTime: Date?
    var lunchCall: Date?
    var firstShotAfterLunch: Date?
    var cameraWrap: Date?
    var lastManOut: Date?

    // Scene Progress
    var scenesScheduled: [String] = []
    var scenesCompleted: [String] = []
    var scenesPartial: [String] = []
    var pagesScheduled: Double = 0
    var pagesCompleted: Double = 0

    // Script Info
    var scriptDated: Date?
    var scriptColor: String = ""

    // Cast
    var castEntries: [CastReportEntry] = []

    // Extras
    var standInsCount: Int = 0
    var atmosphereCount: Int = 0
    var specialAbilityCount: Int = 0

    // Notes
    var productionNotes: String = ""
    var accidentReport: String = ""
    var equipmentIssues: String = ""

    // Status
    var status: ProductionReportStatus = .draft
    var signatures: [SignatureData] = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct CastReportEntry: Identifiable, Codable {
    let id: UUID
    var castNumber: Int
    var name: String
    var role: String
    var callTime: Date?
    var onSet: Date?
    var firstShot: Date?
    var lastShot: Date?
    var wrap: Date?
    var mealIn: Date?
    var mealOut: Date?
    var travelTime: Double?
    var notes: String?
}

enum ProductionReportStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case review = "Under Review"
    case submitted = "Submitted"
    case approved = "Approved"

    var color: Color {
        switch self {
        case .draft: return .gray
        case .review: return .orange
        case .submitted: return .blue
        case .approved: return .green
        }
    }
}

// MARK: - Signature Model
struct SignatureData: Identifiable, Codable, Hashable {
    let id: UUID
    var signerName: String
    var signerRole: String
    var signatureImageData: Data?
    var signatureText: String?  // Fallback text signature
    var signedAt: Date
    var ipAddress: String?

    var hasSignature: Bool {
        signatureImageData != nil || (signatureText != nil && !signatureText!.isEmpty)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SignatureData, rhs: SignatureData) -> Bool {
        lhs.id == rhs.id
    }
}
