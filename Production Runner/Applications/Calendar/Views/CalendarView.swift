import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#endif

// MARK: - Gantt Drag State (Simple Global)
/// Simple global drag state that doesn't trigger SwiftUI re-renders.
/// Uses absolute screen position to calculate offsets, avoiding coordinate space issues.
final class GanttDragState {
    static let shared = GanttDragState()

    private(set) var activeEventID: UUID?
    private(set) var dragType: DragType = .none
    private(set) var startX: CGFloat = 0
    private(set) var currentOffset: CGFloat = 0

    // Y-axis tracking for vertical drag
    private(set) var startY: CGFloat = 0
    private(set) var currentY: CGFloat = 0
    private(set) var hoveredSubcategoryID: String?

    enum DragType {
        case none
        case move
        case resizeStart
        case resizeEnd
    }

    var currentYOffset: CGFloat {
        currentY - startY
    }

    private init() {}

    func beginDrag(eventID: UUID, type: DragType, startX: CGFloat, startY: CGFloat = 0) {
        self.activeEventID = eventID
        self.dragType = type
        self.startX = startX
        self.startY = startY
        self.currentOffset = 0
        self.currentY = startY
    }

    func updateDrag(currentX: CGFloat, currentY: CGFloat = 0) {
        self.currentOffset = currentX - startX
        self.currentY = currentY
    }

    func updateHoveredSubcategory(_ subcategoryID: String?) {
        self.hoveredSubcategoryID = subcategoryID
    }

    func endDrag() -> (xOffset: CGFloat, yOffset: CGFloat) {
        let finalXOffset = currentOffset
        let finalYOffset = currentYOffset
        activeEventID = nil
        dragType = .none
        startX = 0
        currentOffset = 0
        startY = 0
        currentY = 0
        hoveredSubcategoryID = nil
        return (finalXOffset, finalYOffset)
    }

    func isDragging(eventID: UUID) -> Bool {
        activeEventID == eventID && dragType == .move
    }

    func isResizingStart(eventID: UUID) -> Bool {
        activeEventID == eventID && dragType == .resizeStart
    }

    func isResizingEnd(eventID: UUID) -> Bool {
        activeEventID == eventID && dragType == .resizeEnd
    }

    func offset(for eventID: UUID, type: DragType) -> CGFloat {
        guard activeEventID == eventID, dragType == type else { return 0 }
        return currentOffset
    }
}

// MARK: - Production Calendar Event Types
enum ProductionEventType: String, CaseIterable, Codable {
    case shootDay = "Shoot Day"
    case prepDay = "Prep Day"
    case rehearsal = "Rehearsal"
    case locationScout = "Location Scout"
    case meeting = "Meeting"
    case milestone = "Milestone"
    case wrapDay = "Wrap Day"
    case preProduction = "Pre-Production"
    case postProduction = "Post-Production"
    
    var icon: String {
        switch self {
        case .shootDay: return "camera.fill"
        case .prepDay: return "wrench.and.screwdriver.fill"
        case .rehearsal: return "person.2.fill"
        case .locationScout: return "mappin.circle.fill"
        case .meeting: return "person.3.fill"
        case .milestone: return "flag.fill"
        case .wrapDay: return "checkmark.circle.fill"
        case .preProduction: return "calendar.badge.clock"
        case .postProduction: return "film.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .shootDay: return Color(red: 1.0, green: 0.23, blue: 0.19)
        case .prepDay: return Color(red: 1.0, green: 0.6, blue: 0.0)
        case .rehearsal: return Color(red: 0.75, green: 0.22, blue: 0.87)
        case .locationScout: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .meeting: return Color(red: 0.2, green: 0.78, blue: 0.78)
        case .milestone: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .wrapDay: return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .preProduction: return Color(red: 0.36, green: 0.36, blue: 0.95)
        case .postProduction: return Color(red: 1.0, green: 0.18, blue: 0.55)
        }
    }
}

// MARK: - Production Phase
enum ProductionPhase: String, CaseIterable, Codable {
    case development = "Development"
    case preProduction = "Pre-Production"
    case production = "Production"
    case postProduction = "Post-Production"

    var icon: String {
        switch self {
        case .development: return "lightbulb.fill"
        case .preProduction: return "calendar.badge.clock"
        case .production: return "camera.fill"
        case .postProduction: return "film.fill"
        }
    }

    var color: Color {
        switch self {
        case .development: return Color(red: 0.8, green: 0.4, blue: 0.2)
        case .preProduction: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .production: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .postProduction: return Color(red: 0.6, green: 0.3, blue: 0.8)
        }
    }

    // Map to category ID for timeline
    var categoryID: String {
        switch self {
        case .development: return "development"
        case .preProduction: return "pre-production"
        case .production: return "production"
        case .postProduction: return "post-production"
        }
    }
}

// MARK: - Production Event Model
struct ProductionEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var type: ProductionEventType
    var productionPhase: ProductionPhase = .development
    var date: Date
    var endDate: Date?
    var notes: String = ""
    var location: String = ""
    var scenes: [String] = []
    var crew: [String] = []
    var callTime: Date?
    var wrapTime: Date?
    var customColor: String? = nil // Hex color string for custom colors
    var linkedLocationID: UUID? = nil // Link to LocationItem
    var linkedTaskIDs: [UUID] = [] // Link to TaskEntity IDs

    var isMultiDay: Bool {
        guard let end = endDate else { return false }
        return Calendar.current.dateComponents([.day], from: date, to: end).day ?? 0 > 0
    }

    var duration: Int {
        guard let end = endDate else { return 1 }
        return max(1, Calendar.current.dateComponents([.day], from: date, to: end).day ?? 0 + 1)
    }

    var displayColor: Color {
        if let hexColor = customColor, let color = Color(hex: hexColor) {
            return color
        }
        return type.color
    }

    // Category assignment for timeline gantt view - auto-map from production phase
    var categoryID: String? {
        productionPhase.categoryID
    }
    var subcategoryID: String? = nil
}

// MARK: - Production Timeline Categories
struct ProductionCategory: Identifiable, Equatable {
    var id: String
    var name: String
    var color: Color
    var subcategories: [ProductionSubcategory]
    var isExpanded: Bool = true

    init(id: String, name: String, color: Color, subcategories: [ProductionSubcategory], isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.color = color
        self.subcategories = subcategories
        self.isExpanded = isExpanded
    }

    static func == (lhs: ProductionCategory, rhs: ProductionCategory) -> Bool {
        lhs.id == rhs.id && lhs.isExpanded == rhs.isExpanded
    }
}

struct ProductionSubcategory: Identifiable, Codable {
    var id: String
    var name: String
    var categoryID: String
}

// Default production categories for gantt chart
extension ProductionCategory {
    static let defaultCategories: [ProductionCategory] = [
        ProductionCategory(
            id: "development",
            name: "DEVELOPMENT",
            color: Color(red: 0.8, green: 0.4, blue: 0.2),
            subcategories: [
                ProductionSubcategory(id: "dev-concept", name: "Concept Development", categoryID: "development"),
                ProductionSubcategory(id: "dev-script", name: "Script Writing", categoryID: "development"),
                ProductionSubcategory(id: "dev-review", name: "Review & Approval", categoryID: "development")
            ]
        ),
        ProductionCategory(
            id: "pre-production",
            name: "PRE-PRODUCTION",
            color: Color(red: 0.2, green: 0.6, blue: 0.9),
            subcategories: [
                ProductionSubcategory(id: "pre-script", name: "Shooting Script", categoryID: "pre-production"),
                ProductionSubcategory(id: "pre-breakdown", name: "Script Breakdown", categoryID: "pre-production"),
                ProductionSubcategory(id: "pre-budget", name: "Budgeting", categoryID: "pre-production"),
                ProductionSubcategory(id: "pre-schedule", name: "Scheduling", categoryID: "pre-production"),
                ProductionSubcategory(id: "pre-casting", name: "Casting", categoryID: "pre-production"),
                ProductionSubcategory(id: "pre-location", name: "Location Scouting", categoryID: "pre-production")
            ]
        ),
        ProductionCategory(
            id: "production",
            name: "PRODUCTION",
            color: Color(red: 0.9, green: 0.3, blue: 0.3),
            subcategories: [
                ProductionSubcategory(id: "prod-principal", name: "Principal Photography", categoryID: "production"),
                ProductionSubcategory(id: "prod-pickups", name: "Pick-up Shots", categoryID: "production"),
                ProductionSubcategory(id: "prod-broll", name: "B-Roll", categoryID: "production")
            ]
        ),
        ProductionCategory(
            id: "post-production",
            name: "POST-PRODUCTION",
            color: Color(red: 0.6, green: 0.3, blue: 0.8),
            subcategories: [
                ProductionSubcategory(id: "post-edit", name: "Editing", categoryID: "post-production"),
                ProductionSubcategory(id: "post-color", name: "Color Grading", categoryID: "post-production"),
                ProductionSubcategory(id: "post-sound", name: "Sound Design", categoryID: "post-production"),
                ProductionSubcategory(id: "post-vfx", name: "Visual Effects", categoryID: "post-production"),
                ProductionSubcategory(id: "post-music", name: "Music & Scoring", categoryID: "post-production"),
                ProductionSubcategory(id: "post-final", name: "Final Mix & Mastering", categoryID: "post-production")
            ]
        )
    ]
}

// MARK: - Calendar View Mode
enum CalendarViewMode: String, CaseIterable {
    case month = "Month"
    case week = "Week"
    case timeline = "Timeline"
    
    var icon: String {
        switch self {
        case .month: return "calendar"
        case .week: return "calendar.day.timeline.left"
        case .timeline: return "chart.bar.xaxis"
        }
    }
}

// MARK: - Main Calendar View
#if os(macOS)
struct CalendarView: View {
    let project: NSManagedObject
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("app_theme") private var appTheme: String = "Standard"

    private var currentTheme: AppAppearance.Theme {
        AppAppearance.Theme(rawValue: appTheme) ?? .standard
    }

    // View State
    @State private var viewMode: CalendarViewMode = .month
    @State private var currentDate: Date = Date()
    @State private var events: [ProductionEvent] = []
    @State private var selectedDate: Date?
    @State private var selectedEvent: ProductionEvent?
    @State private var showAddEvent = false
    @State private var showEventDetail = false
    @State private var showFilterPanel = false
    @State private var showEventItems = false
    @State private var eventItems: [EventItemEntity] = []

    // Timeline add event state
    @State private var selectedSubcategoryForAdd: ProductionSubcategory?

    // Drag and Drop State
    @State private var draggedEvent: ProductionEvent?

    // Clipboard State
    @State private var copiedEvent: ProductionEvent?
    @FocusState private var isFocused: Bool

    // Undo/Redo State
    @State private var undoStack: [[ProductionEvent]] = []
    @State private var redoStack: [[ProductionEvent]] = []

    // Notification observer for Core Data changes
    @State private var notificationObserver: NSObjectProtocol?

    // Filters
    @State private var eventTypeFilters: Set<ProductionEventType> = Set(ProductionEventType.allCases)

    private var cal: Calendar { Calendar.current }

    // Theme-aware colors
    private var primaryTextColor: Color {
        switch currentTheme {
        case .retro:
            return Color(red: 0.2, green: 1.0, blue: 0.3) // Terminal green
        case .neon:
            return Color(red: 1.0, green: 0.2, blue: 0.6) // Neon pink
        case .aqua:
            return colorScheme == .dark ? Color(red: 0.85, green: 0.88, blue: 0.92) : .primary
        case .cinema:
            return .white
        default:
            return colorScheme == .dark ? .white : .primary
        }
    }

    private var secondaryTextColor: Color {
        switch currentTheme {
        case .retro:
            return Color(red: 0.1, green: 0.5, blue: 0.15) // Dim green
        case .neon:
            return Color(red: 0.5, green: 0.3, blue: 0.6)
        case .aqua:
            return Color(red: 0.6, green: 0.65, blue: 0.72)
        case .cinema:
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        default:
            return colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.6)
        }
    }

    private var tertiaryTextColor: Color {
        switch currentTheme {
        case .retro:
            return Color(red: 0.05, green: 0.3, blue: 0.1) // Very dim green
        case .neon:
            return Color(red: 0.3, green: 0.2, blue: 0.4)
        case .aqua:
            return Color(red: 0.4, green: 0.45, blue: 0.52)
        case .cinema:
            return Color(red: 0.4, green: 0.4, blue: 0.4)
        default:
            return colorScheme == .dark ? Color.white.opacity(0.5) : Color.primary.opacity(0.4)
        }
    }

    private var backgroundPrimaryColor: Color {
        switch currentTheme {
        case .retro:
            return Color.black // Terminal black
        case .neon:
            return Color(red: 0.05, green: 0.02, blue: 0.08)
        case .aqua:
            return colorScheme == .dark ? Color(red: 0.08, green: 0.12, blue: 0.16) : Color(white: 0.95)
        case .cinema:
            return Color(red: 0.086, green: 0.102, blue: 0.122) // Letterboxd dark bg #161a1f
        default:
            return colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.95)
        }
    }

    private var backgroundSecondaryColor: Color {
        switch currentTheme {
        case .retro:
            return Color(red: 0.0, green: 0.15, blue: 0.05).opacity(0.5) // Dark green tint
        case .neon:
            return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.08)
        case .aqua:
            return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.08)
        case .cinema:
            return Color(red: 0.110, green: 0.133, blue: 0.157) // Letterboxd card bg
        default:
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
        }
    }

    private var backgroundTertiaryColor: Color {
        switch currentTheme {
        case .retro:
            return Color(red: 0.0, green: 0.1, blue: 0.03)
        case .neon:
            return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.04)
        case .aqua:
            return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.04)
        case .cinema:
            return Color(red: 0.086, green: 0.102, blue: 0.122)
        default:
            return colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03)
        }
    }

    private var dividerColor: Color {
        switch currentTheme {
        case .retro:
            return Color(red: 0.1, green: 0.5, blue: 0.15).opacity(0.5) // Green divider
        case .neon:
            return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.3)
        case .aqua:
            return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.3)
        case .cinema:
            return Color(red: 0.0, green: 0.878, blue: 0.329).opacity(0.2) // Letterboxd green
        default:
            return colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        calendarMainView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showAddEvent, onDismiss: {
                selectedSubcategoryForAdd = nil  // Clear selection when sheet dismisses
            }) {
                AddEventSheet(
                    project: project,
                    initialDate: selectedDate ?? currentDate,
                    initialPhase: phaseForSubcategory(selectedSubcategoryForAdd),
                    initialSubcategoryID: selectedSubcategoryForAdd?.id,
                    onSave: { event in
                        saveToUndoStack()
                        events.append(event)
                        saveEvents()
                    }
                )
            }
            .sheet(isPresented: $showEventDetail) {
                if let event = selectedEvent {
                    EventDetailSheet(
                        event: event,
                        project: project,
                        onUpdate: { updated in
                            if let idx = events.firstIndex(where: { $0.id == updated.id }) {
                                saveToUndoStack()
                                events[idx] = updated
                                saveEvents()
                            }
                        },
                        onDelete: {
                            saveToUndoStack()
                            events.removeAll { $0.id == event.id }
                            saveEvents()
                            showEventDetail = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showEventItems) {
                EventItemsManagerSheet(
                    project: project,
                    eventItems: $eventItems,
                    onDismiss: { showEventItems = false }
                )
            }
            .onAppear {
                loadEvents()
                loadShootDaysFromScheduler()
                loadEventItems()
                setupNotificationObserver()
            }
            .onDisappear {
                if let observer = notificationObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
            .onDeleteCommand {
                deleteSelectedEvent()
            }
            .onCopyCommand {
                guard selectedEvent != nil else { return [] }
                copySelectedEvent()
                return [NSItemProvider(object: selectedEvent!.id.uuidString as NSString)]
            }
            .onCutCommand {
                guard selectedEvent != nil else { return [] }
                cutSelectedEvent()
                return [NSItemProvider(object: selectedEvent!.id.uuidString as NSString)]
            }
            .onPasteCommand(of: [.text]) { providers in
                guard copiedEvent != nil, selectedDate != nil else { return }
                pasteEvent()
            }
            .undoRedoSupport(
                canUndo: !undoStack.isEmpty,
                canRedo: !redoStack.isEmpty,
                onUndo: performUndo,
                onRedo: performRedo
            )
            .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
                // Calendar doesn't have multi-select, but we can expand the view
            }
            .onReceive(NotificationCenter.default.publisher(for: .prNewCalendarEvent)) { _ in
                showAddEvent = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .prEditCalendarEvent)) { _ in
                if selectedEvent != nil {
                    showEventDetail = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prDeleteCalendarEvent)) { _ in
                deleteSelectedEvent()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prRefreshCalendar)) { _ in
                refreshShootDays()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
                if selectedEvent != nil {
                    cutSelectedEvent()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
                if selectedEvent != nil {
                    copySelectedEvent()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
                if copiedEvent != nil && selectedDate != nil {
                    pasteEvent()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
                deleteSelectedEvent()
            }
    }

    @ViewBuilder
    private var calendarMainView: some View {
        if #available(macOS 14.0, *) {
            HStack(spacing: 0) {
                mainCalendarArea
                sidePanelArea
            }
        } else {
            fallbackCalendarView
        }
    }

    @ViewBuilder
    private var mainCalendarArea: some View {
        VStack(spacing: 0) {
            calendarToolbar
            Divider()
            calendarViewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundPrimaryColor)
        }
    }

    private var calendarToolbar: some View {
        CalendarToolbar(
            viewMode: $viewMode,
            currentDate: $currentDate,
            showAddEvent: $showAddEvent,
            showFilterPanel: $showFilterPanel,
            showEventItems: $showEventItems,
            onToday: { currentDate = Date() },
            onPrevious: movePrevious,
            onNext: moveNext,
            onRefresh: { refreshShootDays() },
            currentTheme: currentTheme
        )
    }

    @ViewBuilder
    private var calendarViewContent: some View {
        Group {
            switch viewMode {
            case .month:
                monthViewContent
            case .week:
                weekViewContent
            case .timeline:
                timelineViewContent
            }
        }
    }

    private var monthViewContent: some View {
        MonthView(
            currentDate: $currentDate,
            events: filteredEvents,
            selectedDate: $selectedDate,
            selectedEventID: selectedEvent?.id,
            draggedEvent: $draggedEvent,
            onEventSelect: { event in selectedEvent = event },
            onEventTap: { event in
                selectedEvent = event
                showEventDetail = true
            },
            onDateTap: { date in selectedDate = date },
            onDateDoubleClick: { date in
                selectedDate = date
                showAddEvent = true
            },
            onEventMoved: { event, newDate in moveEvent(event, to: newDate, subcategory: nil) },
            currentTheme: currentTheme
        )
    }

    private var weekViewContent: some View {
        WeekView(
            currentDate: $currentDate,
            events: filteredEvents,
            selectedDate: $selectedDate,
            onEventTap: { event in
                selectedEvent = event
                showEventDetail = true
            }
        )
    }

    private var timelineViewContent: some View {
        TimelineView(
            currentDate: $currentDate,
            events: filteredEvents,
            eventItems: eventItems,
            onEventTap: { event in
                selectedEvent = event
                showEventDetail = true
            },
            onEventMoved: { event, newDate, subcategoryID in moveEvent(event, to: newDate, subcategory: subcategoryID) },
            onEventResized: { event, newStart, newEnd in resizeEvent(event, newStartDate: newStart, newEndDate: newEnd) },
            onAddEvent: { subcategory in
                selectedSubcategoryForAdd = subcategory
                showAddEvent = true
            }
        )
    }

    @ViewBuilder
    private var sidePanelArea: some View {
        if showFilterPanel || selectedDate != nil {
            Divider()
                .background(dividerColor)

            if showFilterPanel {
                FilterPanel(
                    eventTypeFilters: $eventTypeFilters,
                    onClose: { showFilterPanel = false }
                )
                .frame(width: 280)
            } else if let date = selectedDate {
                DayDetailPanel(
                    date: date,
                    events: eventsForDate(date),
                    onClose: { selectedDate = nil },
                    onAddEvent: {
                        selectedDate = date
                        showAddEvent = true
                    },
                    onEventTap: { event in
                        selectedEvent = event
                        showEventDetail = true
                    },
                    onRefresh: {
                        refreshShootDays()
                    }
                )
                .frame(width: 320)
            }
        }
    }

    @ViewBuilder
    private var fallbackCalendarView: some View {
        VStack(spacing: 0) {
            calendarToolbar
            Divider()
            calendarViewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundPrimaryColor)
        }
    }

    var body: some View {
        calendarContent
    }

    // MARK: - Computed Properties
    private var filteredEvents: [ProductionEvent] {
        events.filter { eventTypeFilters.contains($0.type) }
    }
    
    private func eventsForDate(_ date: Date) -> [ProductionEvent] {
        let startOfDay = cal.startOfDay(for: date)
        return filteredEvents.filter { event in
            let eventStart = cal.startOfDay(for: event.date)
            if let eventEnd = event.endDate {
                let eventEndDay = cal.startOfDay(for: eventEnd)
                return startOfDay >= eventStart && startOfDay <= eventEndDay
            }
            return eventStart == startOfDay
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Navigation
    private func movePrevious() {
        switch viewMode {
        case .month:
            currentDate = cal.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        case .week:
            currentDate = cal.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
        case .timeline:
            currentDate = cal.date(byAdding: .month, value: -3, to: currentDate) ?? currentDate
        }
    }
    
    private func moveNext() {
        switch viewMode {
        case .month:
            currentDate = cal.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        case .week:
            currentDate = cal.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        case .timeline:
            currentDate = cal.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate
        }
    }
    
    // MARK: - Refresh
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
            object: moc,
            queue: .main
        ) { [self] notification in
            // Check if ShootDayEntity was modified
            if let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
               updated.contains(where: { $0.entity.name == "ShootDayEntity" }) {
                refreshShootDays()
            }
            if let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>,
               inserted.contains(where: { $0.entity.name == "ShootDayEntity" }) {
                refreshShootDays()
            }
        }
    }
    
    private func refreshShootDays() {
        // Remove all existing shoot day events
        events.removeAll { $0.type == .shootDay }
        
        // Reload from scheduler
        loadShootDaysFromScheduler()
    }
    
    // MARK: - Clipboard Operations
    private func copySelectedEvent() {
        guard let event = selectedEvent else { return }
        copiedEvent = event
    }

    private func cutSelectedEvent() {
        guard let event = selectedEvent else { return }
        copiedEvent = event
        deleteSelectedEvent()
    }

    private func pasteEvent() {
        guard let event = copiedEvent,
              let targetDate = selectedDate else { return }

        var newEvent = event
        newEvent.id = UUID() // Generate new ID for the pasted event

        // Set the new date
        let calendar = Calendar.current
        let targetStartOfDay = calendar.startOfDay(for: targetDate)

        // Preserve time components from original event
        let timeComponents = calendar.dateComponents([.hour, .minute], from: event.date)

        if let newDateTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                           minute: timeComponents.minute ?? 0,
                                           second: 0,
                                           of: targetStartOfDay) {
            newEvent.date = newDateTime
        } else {
            newEvent.date = targetStartOfDay
        }

        // Adjust end date if it exists (maintain duration)
        if let oldEndDate = event.endDate {
            let oldStartOfDay = calendar.startOfDay(for: event.date)
            let daysDifference = calendar.dateComponents([.day], from: oldStartOfDay, to: calendar.startOfDay(for: oldEndDate)).day ?? 0
            if let newEndDate = calendar.date(byAdding: .day, value: daysDifference, to: targetStartOfDay) {
                newEvent.endDate = newEndDate
            }
        }

        // Update call time and wrap time dates if they exist
        if let oldCallTime = event.callTime {
            let callTimeComponents = calendar.dateComponents([.hour, .minute], from: oldCallTime)
            if let newCallTime = calendar.date(bySettingHour: callTimeComponents.hour ?? 0,
                                               minute: callTimeComponents.minute ?? 0,
                                               second: 0,
                                               of: targetStartOfDay) {
                newEvent.callTime = newCallTime
            }
        }

        if let oldWrapTime = event.wrapTime {
            let wrapTimeComponents = calendar.dateComponents([.hour, .minute], from: oldWrapTime)
            if let newWrapTime = calendar.date(bySettingHour: wrapTimeComponents.hour ?? 0,
                                               minute: wrapTimeComponents.minute ?? 0,
                                               second: 0,
                                               of: targetStartOfDay) {
                newEvent.wrapTime = newWrapTime
            }
        }

        saveToUndoStack()
        events.append(newEvent)
        saveEvents()
        selectedEvent = newEvent
    }

    private func deleteSelectedEvent() {
        guard let event = selectedEvent else { return }
        saveToUndoStack()
        events.removeAll { $0.id == event.id }
        saveEvents()
        selectedEvent = nil
    }

    // MARK: - Undo/Redo Operations
    private func saveToUndoStack() {
        // Save current state to undo stack
        undoStack.append(events)
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        // Limit undo stack to 20 items
        if undoStack.count > 20 {
            undoStack.removeFirst()
        }
    }

    private func performUndo() {
        guard !undoStack.isEmpty else { return }

        // Save current state to redo stack
        redoStack.append(events)

        // Restore previous state
        events = undoStack.removeLast()
        saveEvents()
        selectedEvent = nil
    }

    private func performRedo() {
        guard !redoStack.isEmpty else { return }

        // Save current state to undo stack
        undoStack.append(events)

        // Restore next state
        events = redoStack.removeLast()
        saveEvents()
        selectedEvent = nil
    }

    // MARK: - Event Management
    private func moveEvent(_ event: ProductionEvent, to newDate: Date, subcategory subcategoryID: String?) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }

        saveToUndoStack()
        var updatedEvent = event

        // Calculate the time difference and adjust dates
        let calendar = Calendar.current
        let oldStartOfDay = calendar.startOfDay(for: event.date)
        let newStartOfDay = calendar.startOfDay(for: newDate)

        // Get time components from original date
        let timeComponents = calendar.dateComponents([.hour, .minute], from: event.date)

        // Set new date with same time
        if let newDateTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                           minute: timeComponents.minute ?? 0,
                                           second: 0,
                                           of: newStartOfDay) {
            updatedEvent.date = newDateTime
        } else {
            updatedEvent.date = newStartOfDay
        }

        // Adjust end date if it exists (maintain duration)
        if let oldEndDate = event.endDate {
            let daysDifference = calendar.dateComponents([.day], from: oldStartOfDay, to: calendar.startOfDay(for: oldEndDate)).day ?? 0
            if let newEndDate = calendar.date(byAdding: .day, value: daysDifference, to: newStartOfDay) {
                updatedEvent.endDate = newEndDate
            }
        }

        // Update call time and wrap time dates if they exist
        if let oldCallTime = event.callTime {
            let callTimeComponents = calendar.dateComponents([.hour, .minute], from: oldCallTime)
            if let newCallTime = calendar.date(bySettingHour: callTimeComponents.hour ?? 0,
                                               minute: callTimeComponents.minute ?? 0,
                                               second: 0,
                                               of: newStartOfDay) {
                updatedEvent.callTime = newCallTime
            }
        }

        if let oldWrapTime = event.wrapTime {
            let wrapTimeComponents = calendar.dateComponents([.hour, .minute], from: oldWrapTime)
            if let newWrapTime = calendar.date(bySettingHour: wrapTimeComponents.hour ?? 0,
                                               minute: wrapTimeComponents.minute ?? 0,
                                               second: 0,
                                               of: newStartOfDay) {
                updatedEvent.wrapTime = newWrapTime
            }
        }

        // Update subcategoryID if provided and different
        if let newSubcategoryID = subcategoryID, newSubcategoryID != event.subcategoryID {
            updatedEvent.subcategoryID = newSubcategoryID

            // Find which category this subcategory belongs to and update productionPhase
            for category in ProductionCategory.defaultCategories {
                if let subcategory = category.subcategories.first(where: { $0.id == newSubcategoryID }) {
                    // Update productionPhase to match new category (maintains data integrity)
                    switch subcategory.categoryID {
                    case "development":
                        updatedEvent.productionPhase = .development
                    case "pre-production":
                        updatedEvent.productionPhase = .preProduction
                    case "production":
                        updatedEvent.productionPhase = .production
                    case "post-production":
                        updatedEvent.productionPhase = .postProduction
                    default:
                        break
                    }
                    print("[CalendarView] Event '\(event.title)' moved to subcategory: \(subcategory.name) in category: \(category.name)")
                    break
                }
            }
        }

        events[index] = updatedEvent
        saveEvents()
    }

    private func resizeEvent(_ event: ProductionEvent, newStartDate: Date?, newEndDate: Date?) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }

        saveToUndoStack()
        var updatedEvent = event
        let calendar = Calendar.current

        // Handle start date change
        if let newStart = newStartDate {
            let newStartOfDay = calendar.startOfDay(for: newStart)

            // Get time components from original date
            let timeComponents = calendar.dateComponents([.hour, .minute], from: event.date)

            // Set new date with same time
            if let newDateTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                               minute: timeComponents.minute ?? 0,
                                               second: 0,
                                               of: newStartOfDay) {
                updatedEvent.date = newDateTime
            } else {
                updatedEvent.date = newStartOfDay
            }

            // Ensure start date doesn't go past end date
            if let endDate = updatedEvent.endDate, updatedEvent.date > endDate {
                updatedEvent.date = endDate
            }
        }

        // Handle end date change
        if let newEnd = newEndDate {
            let newEndOfDay = calendar.startOfDay(for: newEnd)

            // Ensure end date doesn't go before start date
            if newEndOfDay >= calendar.startOfDay(for: updatedEvent.date) {
                updatedEvent.endDate = newEndOfDay
            } else {
                // If dragged before start, set to same as start (1 day event)
                updatedEvent.endDate = nil
            }
        }

        events[index] = updatedEvent
        saveEvents()
    }

    // MARK: - Data Persistence
    private func loadEvents() {
        // Use UserDefaults keyed by project ID to avoid Core Data schema changes
        let projectID = project.objectID.uriRepresentation().absoluteString
        let key = "calendarEvents_\(projectID)"
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            events = []
            return
        }
        events = (try? JSONDecoder().decode([ProductionEvent].self, from: data)) ?? []
    }
    
    private func saveEvents() {
        let projectID = project.objectID.uriRepresentation().absoluteString
        let key = "calendarEvents_\(projectID)"
        let data = try? JSONEncoder().encode(events)
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Convert a subcategory's category ID to a ProductionPhase
    private func phaseForSubcategory(_ subcategory: ProductionSubcategory?) -> ProductionPhase? {
        guard let categoryID = subcategory?.categoryID else { return nil }
        return ProductionPhase.allCases.first { $0.categoryID == categoryID }
    }

    private func loadEventItems() {
        let req = NSFetchRequest<NSManagedObject>(entityName: "EventItemEntity")
        req.predicate = NSPredicate(format: "project == %@", project)
        req.sortDescriptors = [
            NSSortDescriptor(key: "productionPhase", ascending: true),
            NSSortDescriptor(key: "sortOrder", ascending: true)
        ]

        guard let results = try? moc.fetch(req) else {
            eventItems = []
            return
        }
        eventItems = results.compactMap { $0 as? EventItemEntity }
    }

    private func loadShootDaysFromScheduler() {
        // Fetch shoot days from ShootDayEntity
        let req = NSFetchRequest<NSManagedObject>(entityName: "ShootDayEntity")
        req.predicate = NSPredicate(format: "project == %@", project)
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        guard let shootDays = try? moc.fetch(req) else { return }
        
        for day in shootDays {
            guard let date = day.value(forKey: "date") as? Date else { continue }
            
            // Check if we already have an event for this shoot day
            let existingEvent = events.first { event in
                event.type == .shootDay &&
                cal.isDate(event.date, inSameDayAs: date)
            }
            
            if existingEvent == nil {
                let dayNumber = day.value(forKey: "dayNumber") as? Int ?? 0
                
                // Get scenes
                let scenes: [String]
                if let sceneSet = day.value(forKey: "scenes") as? Set<NSManagedObject> {
                    scenes = sceneSet.compactMap { scene in
                        if let sceneNumber = scene.value(forKey: "sceneNumber") as? String {
                            return sceneNumber
                        } else if let sceneNumber = scene.value(forKey: "number") as? String {
                            return sceneNumber
                        }
                        return nil
                    }.sorted()
                } else {
                    scenes = []
                }
                
                // Get location if available
                var location = ""
                if let locationName = day.value(forKey: "location") as? String {
                    location = locationName
                }
                
                // Get call time if available
                var callTime: Date? = nil
                if let call = day.value(forKey: "callTime") as? Date {
                    callTime = call
                }
                
                // Get notes if available
                var notes = ""
                if let dayNotes = day.value(forKey: "notes") as? String {
                    notes = dayNotes
                }
                
                let title = dayNumber > 0 ? "Shoot Day \(dayNumber)" : "Shoot Day"
                
                let event = ProductionEvent(
                    title: title,
                    type: .shootDay,
                    date: date,
                    notes: notes,
                    location: location,
                    scenes: scenes,
                    callTime: callTime
                )
                events.append(event)
            }
        }
        
        saveEvents()
    }
}

// MARK: - Modern Calendar Toolbar
private struct CalendarToolbar: View {
    @Binding var viewMode: CalendarViewMode
    @Binding var currentDate: Date
    @Binding var showAddEvent: Bool
    @Binding var showFilterPanel: Bool
    @Binding var showEventItems: Bool
    var onToday: () -> Void
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onRefresh: () -> Void
    var currentTheme: AppAppearance.Theme = .standard

    @Environment(\.colorScheme) private var colorScheme

    // Terminal green for retro theme
    private var retroGreen: Color { Color(red: 0.2, green: 1.0, blue: 0.3) }
    private var retroDimGreen: Color { Color(red: 0.1, green: 0.5, blue: 0.15) }

    private var toolbarBackgroundColor: Color {
        switch currentTheme {
        case .retro:
            return Color(red: 0.0, green: 0.06, blue: 0.02)
        case .neon:
            return Color(red: 0.04, green: 0.02, blue: 0.06)
        case .aqua:
            return colorScheme == .dark ? Color(red: 0.06, green: 0.1, blue: 0.14) : Color.black.opacity(0.03)
        case .cinema:
            return Color(red: 0.086, green: 0.102, blue: 0.122)
        default:
            return colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03)
        }
    }

    private var buttonBackgroundColor: Color {
        switch currentTheme {
        case .retro:
            return retroDimGreen.opacity(0.3)
        case .neon:
            return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.15)
        case .aqua:
            return Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.15)
        case .cinema:
            return Color(red: 0.0, green: 0.878, blue: 0.329).opacity(0.12)
        default:
            return Color.primary.opacity(0.08)
        }
    }

    private var textColor: Color {
        switch currentTheme {
        case .retro:
            return retroGreen
        case .neon:
            return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .aqua:
            return colorScheme == .dark ? Color(red: 0.85, green: 0.88, blue: 0.92) : .primary
        case .cinema:
            return .white
        default:
            return .primary
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Date Navigation Group (arrows + Today)
            HStack(spacing: 8) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(textColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(buttonBackgroundColor)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Previous")

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(textColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(buttonBackgroundColor)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Next")

                Button(action: onToday) {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(buttonBackgroundColor)
                        )
                }
                .buttonStyle(.plain)
            }

            // Actions Group (Filter, Add Event)
            HStack(spacing: 8) {
                Button(action: { showFilterPanel.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Filter")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(buttonBackgroundColor)
                    )
                    .foregroundStyle(textColor)
                }
                .buttonStyle(.plain)

                Button(action: { showEventItems = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Event Items")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(buttonBackgroundColor)
                    )
                    .foregroundStyle(textColor)
                }
                .buttonStyle(.plain)

                Button(action: { showAddEvent = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add Event")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(buttonBackgroundColor)
                    )
                    .foregroundStyle(textColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Custom View Mode Buttons (replacing segmented picker)
            HStack(spacing: 4) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = mode
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: viewMode == mode ? .bold : .medium))

                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: viewMode == mode ? .semibold : .regular))
                        }
                        .foregroundStyle(viewMode == mode ? textColor : textColor.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if viewMode == mode {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(buttonBackgroundColor)

                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(textColor.opacity(0.3), lineWidth: 1)
                                } else {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(buttonBackgroundColor.opacity(0.3))
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(buttonBackgroundColor.opacity(0.5))
            )

            Text(formattedDateRange)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(minWidth: 200)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(toolbarBackgroundColor)
    }
    
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }
}

// MARK: - Month View (ENHANCED READABILITY)
private struct MonthView: View {
    @Binding var currentDate: Date
    let events: [ProductionEvent]
    @Binding var selectedDate: Date?
    let selectedEventID: UUID?
    @Binding var draggedEvent: ProductionEvent?
    var onEventSelect: (ProductionEvent) -> Void
    var onEventTap: (ProductionEvent) -> Void
    var onDateTap: (Date) -> Void
    var onDateDoubleClick: (Date) -> Void = { _ in }
    var onEventMoved: (ProductionEvent, Date) -> Void
    var currentTheme: AppAppearance.Theme = .standard
    @Environment(\.colorScheme) private var colorScheme

    private var cal: Calendar { Calendar.current }

    // Minimalist color palette
    private var headerTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color.primary.opacity(0.5)
    }

    private var headerBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    private var gridBackgroundColor: Color {
        colorScheme == .dark ? Color.clear : Color.clear
    }

    private var weekNumberBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.015)
    }

    private var weekNumberTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.25)
    }

    private var otherMonthTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)
    }

    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: currentDate))!
    }

    private var daysInMonth: [Date] {
        guard let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        return range.compactMap { day in
            cal.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    private var leadingBlanks: Int {
        let weekday = cal.component(.weekday, from: monthStart)
        return (weekday + 5) % 7 // Monday as first day
    }

    // Get all dates to display including previous and next month dates
    private var allDisplayDates: [Date] {
        var dates: [Date] = []

        // Previous month dates (leading)
        if leadingBlanks > 0 {
            for i in (1...leadingBlanks).reversed() {
                if let date = cal.date(byAdding: .day, value: -i, to: monthStart) {
                    dates.append(date)
                }
            }
        }

        // Current month dates
        dates.append(contentsOf: daysInMonth)

        // Next month dates (trailing) - fill remaining cells to complete the grid
        let totalCells = dates.count
        let remainder = totalCells % 7
        if remainder > 0 {
            let trailingCount = 7 - remainder
            if let lastDay = daysInMonth.last {
                for i in 1...trailingCount {
                    if let date = cal.date(byAdding: .day, value: i, to: lastDay) {
                        dates.append(date)
                    }
                }
            }
        }

        return dates
    }

    // Get week numbers for each row
    private var weekNumbers: [Int] {
        var weeks: [Int] = []
        let dates = allDisplayDates
        var index = 0
        while index < dates.count {
            let weekOfYear = cal.component(.weekOfYear, from: dates[index])
            weeks.append(weekOfYear)
            index += 7
        }
        return weeks
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        cal.component(.month, from: date) == cal.component(.month, from: currentDate) &&
        cal.component(.year, from: date) == cal.component(.year, from: currentDate)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Week number column on the left
                VStack(spacing: 0) {
                    // Header spacer for "Wk" label
                    Text("WK")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(weekNumberTextColor)
                        .frame(width: 40)
                        .frame(height: 36)
                        .background(headerBackgroundColor)

                    Divider()
                        .background(dividerColor)

                    // Week numbers
                    let headerHeight: CGFloat = 36
                    let availableHeight = geometry.size.height - headerHeight
                    let totalRows = CGFloat(weekNumbers.count)
                    let cellHeight = (availableHeight - (totalRows - 1) * 1) / totalRows

                    VStack(spacing: 1) {
                        ForEach(weekNumbers, id: \.self) { weekNum in
                            Text("\(weekNum)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(weekNumberTextColor)
                                .frame(width: 40, height: cellHeight)
                                .background(weekNumberBackgroundColor)
                        }
                    }
                }
                .frame(width: 40)

                Divider()
                    .background(dividerColor)

                // Main calendar grid
                VStack(spacing: 0) {
                    // Weekday Headers - More minimalist
                    HStack(spacing: 0) {
                        ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(headerTextColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                        }
                    }
                    .background(headerBackgroundColor)

                    Divider()
                        .background(dividerColor)

                    // Calendar Grid - Cleaner spacing
                    let headerHeight: CGFloat = 36
                    let availableHeight = geometry.size.height - headerHeight
                    let totalRows = CGFloat(weekNumbers.count)
                    let cellHeight = (availableHeight - (totalRows - 1) * 1) / totalRows

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                        ForEach(allDisplayDates, id: \.self) { date in
                            let inCurrentMonth = isCurrentMonth(date)
                            DayCell(
                                date: date,
                                events: inCurrentMonth ? eventsForDate(date) : [],
                                isSelected: selectedDate != nil && cal.isDate(date, inSameDayAs: selectedDate!),
                                isToday: cal.isDateInToday(date),
                                isOtherMonth: !inCurrentMonth,
                                selectedEventID: selectedEventID,
                                draggedEvent: $draggedEvent,
                                onTap: { onDateTap(date) },
                                onDoubleTap: { onDateDoubleClick(date) },
                                onEventSelect: onEventSelect,
                                onEventTap: onEventTap,
                                onEventDropped: { event in
                                    onEventMoved(event, date)
                                },
                                currentTheme: currentTheme
                            )
                            .frame(height: cellHeight)
                        }
                    }
                    .background(gridBackgroundColor)
                }
            }
        }
    }

    private func eventsForDate(_ date: Date) -> [ProductionEvent] {
        let startOfDay = cal.startOfDay(for: date)
        return events.filter { event in
            let eventStart = cal.startOfDay(for: event.date)
            if let eventEnd = event.endDate {
                let eventEndDay = cal.startOfDay(for: eventEnd)
                return startOfDay >= eventStart && startOfDay <= eventEndDay
            }
            return eventStart == startOfDay
        }
    }
}

// MARK: - Day Cell (ENHANCED READABILITY)
private struct DayCell: View {
    let date: Date
    let events: [ProductionEvent]
    let isSelected: Bool
    let isToday: Bool
    var isOtherMonth: Bool = false
    let selectedEventID: UUID?
    @Binding var draggedEvent: ProductionEvent?
    var onTap: () -> Void
    var onDoubleTap: () -> Void = {}
    var onEventSelect: (ProductionEvent) -> Void
    var onEventTap: (ProductionEvent) -> Void
    var onEventDropped: (ProductionEvent) -> Void
    var currentTheme: AppAppearance.Theme = .standard

    @State private var isTargeted = false
    @Environment(\.colorScheme) private var colorScheme

    private var cal: Calendar { Calendar.current }

    // Terminal green for retro theme
    private var retroGreen: Color { Color(red: 0.2, green: 1.0, blue: 0.3) }
    private var retroDimGreen: Color { Color(red: 0.1, green: 0.5, blue: 0.15) }
    private var retroVeryDimGreen: Color { Color(red: 0.05, green: 0.25, blue: 0.08) }

    // Minimalist color palette
    private var dateTextColor: Color {
        if isOtherMonth {
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
        }
        if isToday {
            return .white
        }
        return colorScheme == .dark ? Color.white.opacity(0.9) : .primary
    }

    private var moreEventsTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.4) : Color.primary.opacity(0.4)
    }

    private var cellBackgroundColor: Color {
        if isOtherMonth {
            return Color.clear
        }
        if isTargeted {
            return Color.accentColor.opacity(0.15)
        } else if isSelected {
            return Color.accentColor.opacity(0.08)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.015)
        }
    }

    private var cellBorderColor: Color {
        if isOtherMonth {
            return Color.clear
        }
        if isTargeted {
            return Color.accentColor.opacity(0.6)
        } else if isSelected {
            return Color.accentColor.opacity(0.4)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
        }
    }

    private var todayCircleColor: Color {
        Color.accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Date number - Clean and minimal
            HStack {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 13, weight: isToday && !isOtherMonth ? .bold : (isOtherMonth ? .light : .medium)))
                    .foregroundStyle(dateTextColor)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(isToday && !isOtherMonth ? todayCircleColor : Color.clear)
                    )

                Spacer()
            }

            // Events - Clean design (only show for current month)
            if !isOtherMonth {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(events.prefix(3)) { event in
                        EventChip(
                            event: event,
                            isSelected: selectedEventID == event.id,
                            onSelect: { onEventSelect(event) },
                            onOpen: { onEventTap(event) },
                            onDragStarted: { draggedEvent = event },
                            onDragEnded: { draggedEvent = nil }
                        )
                    }

                    if events.count > 3 {
                        Text("+\(events.count - 3)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(moreEventsTextColor)
                            .padding(.horizontal, 6)
                            .padding(.top, 1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(6)
        .background(cellBackgroundColor)
        .overlay(
            Rectangle()
                .strokeBorder(
                    cellBorderColor,
                    lineWidth: isTargeted ? 2 : (isSelected ? 1.5 : 0.5)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !isOtherMonth {
                onDoubleTap()
            }
        }
        .onTapGesture(count: 1, perform: onTap)
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let event = draggedEvent else { return false }

            // Don't drop on the same day
            let eventStartOfDay = cal.startOfDay(for: event.date)
            let dropStartOfDay = cal.startOfDay(for: date)
            guard eventStartOfDay != dropStartOfDay else { return false }

            onEventDropped(event)
            return true
        }
    }
}

// MARK: - Event Chip (Draggable) - Minimalist Design
private struct EventChip: View {
    let event: ProductionEvent
    let isSelected: Bool
    var onSelect: () -> Void
    var onOpen: () -> Void
    var onDragStarted: () -> Void
    var onDragEnded: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : .primary
    }

    var body: some View {
        HStack(spacing: 4) {
            // Subtle color indicator
            RoundedRectangle(cornerRadius: 1)
                .fill(event.displayColor)
                .frame(width: 2, height: 10)

            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(primaryTextColor)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? event.displayColor.opacity(0.2) : event.displayColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    isSelected ? event.displayColor.opacity(0.6) : event.displayColor.opacity(0.3),
                    lineWidth: isSelected ? 1 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpen()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .onDrag {
            onDragStarted()
            return NSItemProvider(object: event.id.uuidString as NSString)
        }
    }
}

// MARK: - Week View (ENHANCED READABILITY)
private struct WeekView: View {
    @Binding var currentDate: Date
    let events: [ProductionEvent]
    @Binding var selectedDate: Date?
    var onEventTap: (ProductionEvent) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var cal: Calendar { Calendar.current }

    private var weekStart: Date {
        var comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)
        comp.weekday = 2 // Monday
        return cal.date(from: comp) ?? currentDate
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var dayHeaderTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : .primary.opacity(0.7)
    }

    private var dayNumberTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var dayHeaderBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
    }

    private var gridBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.95)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day Headers - More visible
            HStack(spacing: 2) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(dayOfWeek(date))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(dayHeaderTextColor)

                        Text("\(cal.component(.day, from: date))")
                            .font(.system(size: 17, weight: cal.isDateInToday(date) ? .bold : .semibold))
                            .foregroundStyle(cal.isDateInToday(date) ? (colorScheme == .dark ? .black : .white) : dayNumberTextColor)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(cal.isDateInToday(date) ? Color.accentColor : Color.clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(dayHeaderBackgroundColor)
                }
            }

            Divider()
                .background(dividerColor)

            // Time Grid
            ScrollView {
                HStack(alignment: .top, spacing: 2) {
                    ForEach(weekDays, id: \.self) { date in
                        WeekDayColumn(
                            date: date,
                            events: eventsForDate(date),
                            onEventTap: onEventTap,
                            colorScheme: colorScheme
                        )
                    }
                }
                .background(gridBackgroundColor)
            }
        }
    }
    
    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func eventsForDate(_ date: Date) -> [ProductionEvent] {
        let startOfDay = cal.startOfDay(for: date)
        return events.filter { event in
            let eventStart = cal.startOfDay(for: event.date)
            if let eventEnd = event.endDate {
                let eventEndDay = cal.startOfDay(for: eventEnd)
                return startOfDay >= eventStart && startOfDay <= eventEndDay
            }
            return eventStart == startOfDay
        }
    }
}

// MARK: - Week Day Column (ENHANCED)
private struct WeekDayColumn: View {
    let date: Date
    let events: [ProductionEvent]
    var onEventTap: (ProductionEvent) -> Void
    let colorScheme: ColorScheme

    private var eventTitleColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var eventBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.9)
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(events) { event in
                Button(action: { onEventTap(event) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: event.type.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(event.displayColor)

                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(eventTitleColor)
                        }

                        if let callTime = event.callTime {
                            Text(formatTime(callTime))
                                .font(.system(size: 11))
                                .foregroundStyle(eventTitleColor.opacity(0.7))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(event.displayColor.opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(event.displayColor.opacity(0.7), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer(minLength: 100)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Subcategory Row Info (for vertical drag detection)
/// Helper struct to track subcategory row positions for drag-and-drop detection
private struct SubcategoryRowInfo {
    let subcategory: ProductionSubcategory
    let categoryID: String
    let yOffset: CGFloat        // Distance from top of timeline grid
    let rowHeight: CGFloat
}

// MARK: - Timeline View (GANTT CHART)
private struct TimelineView: View {
    @Binding var currentDate: Date
    let events: [ProductionEvent]
    let eventItems: [EventItemEntity]
    var onEventTap: (ProductionEvent) -> Void
    var onEventMoved: (ProductionEvent, Date, String?) -> Void
    var onEventResized: (ProductionEvent, Date?, Date?) -> Void
    var onAddEvent: ((ProductionSubcategory) -> Void)?

    @State private var categories: [ProductionCategory] = []
    @State private var dayWidth: CGFloat = 60
    @State private var scrollOffset: CGFloat = 0
    @State private var cachedDateRange: [Date] = []
    @State private var shouldScrollToToday = true

    /// Triggers view refresh when drag state changes
    @State private var dragRefreshTrigger = false

    // Subcategory detection for vertical drag
    @State private var subcategoryRowMap: [SubcategoryRowInfo] = []
    @State private var timelineGridTopY: CGFloat = 0

    private let rowHeight: CGFloat = 44
    private let categoryHeaderHeight: CGFloat = 36
    private let sidebarWidth: CGFloat = 260

    @Environment(\.colorScheme) private var colorScheme

    private var cal: Calendar { Calendar.current }

    // Theme colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .primary.opacity(0.7)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)
    }

    private var dividerLightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    private var categoryHeaderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    private var subcategoryRowColor: Color {
        colorScheme == .dark ? Color.clear : Color.white.opacity(0.4)
    }

    private var timelineBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.95)
    }

    private var sidebarBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03)
    }

    private var timelineStart: Date {
        cal.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
    }

    private var timelineEnd: Date {
        cal.date(byAdding: .month, value: 5, to: currentDate) ?? currentDate
    }

    private var monthSpans: [(start: Date, days: Int)] {
        var spans: [(Date, Int)] = []
        var current = cal.startOfDay(for: timelineStart)
        let end = cal.startOfDay(for: timelineEnd)

        while current <= end {
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: current))!
            let days = cal.range(of: .day, in: .month, for: monthStart)!.count
            spans.append((monthStart, days))
            current = cal.date(byAdding: .month, value: 1, to: current)!
        }

        return spans
    }

    private var dateRange: [Date] {
        cachedDateRange.isEmpty ? buildDateRange() : cachedDateRange
    }

    private func buildDateRange() -> [Date] {
        var dates: [Date] = []
        var current = cal.startOfDay(for: timelineStart)
        let end = cal.startOfDay(for: timelineEnd)

        while current <= end {
            dates.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }

    private var todayIndex: Int {
        let today = cal.startOfDay(for: Date())
        return dateRange.firstIndex(where: { cal.isDate($0, inSameDayAs: today) }) ?? 0
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollViewReader { mainProxy in
            VStack(spacing: 0) {
                // Main content area - combined header and grid for synchronized scrolling
                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // Left sidebar with categories
                        VStack(spacing: 0) {
                            // Sidebar header (aligned with date row)
                            HStack {
                                Text("CATEGORY")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(secondaryTextColor)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(width: sidebarWidth, height: 36)
                            .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98))

                            // Category rows
                            ForEach($categories) { $category in
                                CategorySidebarRow(
                                    category: $category,
                                    rowHeight: rowHeight,
                                    colorScheme: colorScheme,
                                    onAddEvent: handleAddEvent
                                )
                            }
                        }
                        .frame(width: sidebarWidth)
                        .background(colorScheme == .dark ? Color(white: 0.08) : Color.white)

                        // Timeline grid with ScrollViewReader for programmatic scrolling
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Date header row (inside horizontal scroll)
                                    HStack(spacing: 0) {
                                        ForEach(Array(dateRange.enumerated()), id: \.offset) { index, date in
                                            VStack(spacing: 2) {
                                                Text(dayOfWeek(date))
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(isToday(date) ? Color.accentColor : secondaryTextColor)
                                                Text("\(dayNumber(date))")
                                                    .font(.system(size: 11, weight: isToday(date) ? .bold : .regular))
                                                    .foregroundStyle(isToday(date) ? Color.accentColor : primaryTextColor)
                                            }
                                            .frame(width: dayWidth, height: 36)
                                            .background(
                                                isToday(date) ? Color.accentColor.opacity(0.15) :
                                                (isWeekend(date) ? (colorScheme == .dark ? Color(white: 0.10) : Color(white: 0.96)) : Color.clear)
                                            )
                                            .id("day-\(index)")
                                        }
                                    }
                                    .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98))

                                    // Grid content
                                    ZStack(alignment: .topLeading) {
                                        // Grid background columns
                                        HStack(spacing: 0) {
                                            ForEach(Array(dateRange.enumerated()), id: \.offset) { index, date in
                                                Rectangle()
                                                    .fill(
                                                        isToday(date) ? Color.accentColor.opacity(0.08) :
                                                        (isWeekend(date) ? (colorScheme == .dark ? Color(white: 0.06) : Color(white: 0.97)) : Color.clear)
                                                    )
                                                    .frame(width: dayWidth)
                                            }
                                        }

                                        // Event bars overlay
                                        VStack(spacing: 0) {
                                            ForEach(categories.indices, id: \.self) { index in
                                                CategoryTimelineRow(
                                                    category: $categories[index],
                                                    events: eventsForCategory(categories[index]),
                                                    dateRange: dateRange,
                                                    timelineStart: timelineStart,
                                                    dayWidth: dayWidth,
                                                    rowHeight: rowHeight,
                                                    colorScheme: colorScheme,
                                                    dragRefreshTrigger: $dragRefreshTrigger,
                                                    subcategoryRowMap: subcategoryRowMap,
                                                    gridTopY: timelineGridTopY,
                                                    onEventTap: onEventTap,
                                                    onEventMoved: onEventMoved,
                                                    onEventResized: onEventResized
                                                )
                                            }
                                        }

                                        // Today indicator line (on top of everything)
                                        if todayIndex >= 0 && todayIndex < dateRange.count {
                                            GeometryReader { geometry in
                                                Rectangle()
                                                    .fill(Color.accentColor)
                                                    .frame(width: 2, height: geometry.size.height)
                                                    .offset(x: CGFloat(todayIndex) * dayWidth + dayWidth / 2 - 1)
                                            }
                                            .allowsHitTesting(false)
                                        }
                                    }
                                }
                                .frame(width: CGFloat(dateRange.count) * dayWidth)
                            }
                            .onAppear {
                                if shouldScrollToToday {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            proxy.scrollTo("day-\(todayIndex)", anchor: .center)
                                        }
                                        shouldScrollToToday = false
                                    }
                                }
                            }
                            .onChange(of: currentDate) { _ in
                                // Rebuild date range when current date changes
                                cachedDateRange = buildDateRange()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("day-\(todayIndex)", anchor: .center)
                                    }
                                }
                            }
                        }
                        .background(colorScheme == .dark ? Color(white: 0.08) : Color.white)
                    }
                }
            }
        }
        .background(
            // Capture global Y position of the timeline grid
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        timelineGridTopY = geo.frame(in: .global).minY
                    }
                    .onChange(of: geo.frame(in: .global).minY) { newY in
                        timelineGridTopY = newY
                    }
            }
        )
        .onAppear {
            cachedDateRange = buildDateRange()
            buildCategoriesFromEventItems()
            subcategoryRowMap = buildSubcategoryRowInfo()
        }
        .onChange(of: eventItems.count) { _ in
            buildCategoriesFromEventItems()
            subcategoryRowMap = buildSubcategoryRowInfo()
        }
        .onChange(of: categories) { _ in
            subcategoryRowMap = buildSubcategoryRowInfo()
        }
    }

    private func navigateMonth(_ delta: Int) {
        if let newDate = cal.date(byAdding: .month, value: delta, to: currentDate) {
            currentDate = newDate
        }
    }

    private func scrollToToday() {
        currentDate = Date()
    }

    private func buildCategoriesFromEventItems() {
        // Build categories with subcategories from EventItemEntity data
        // Fall back to default categories if no event items exist
        var builtCategories: [ProductionCategory] = []

        for phase in ProductionPhase.allCases {
            let phaseItems = eventItems.filter { $0.productionPhase == phase.categoryID }
                .sorted { $0.sortOrder < $1.sortOrder }

            let subcategories: [ProductionSubcategory]

            if phaseItems.isEmpty {
                // Use default subcategories for this phase
                if let defaultCategory = ProductionCategory.defaultCategories.first(where: { $0.id == phase.categoryID }) {
                    subcategories = defaultCategory.subcategories
                } else {
                    subcategories = []
                }
            } else {
                subcategories = phaseItems.compactMap { item in
                    guard let itemID = item.id, let name = item.name else { return nil }
                    return ProductionSubcategory(
                        id: itemID.uuidString,
                        name: name,
                        categoryID: phase.categoryID
                    )
                }
            }

            builtCategories.append(ProductionCategory(
                id: phase.categoryID,
                name: phase.rawValue.uppercased(),
                color: phase.color,
                subcategories: subcategories,
                isExpanded: true
            ))
        }

        categories = builtCategories
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func eventsForCategory(_ category: ProductionCategory) -> [ProductionEvent] {
        events.filter { event in
            guard let catID = event.categoryID else { return false }
            return catID == category.id
        }
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> Int {
        return cal.component(.day, from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        cal.isDateInToday(date)
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = cal.component(.weekday, from: date)
        return weekday == 1 || weekday == 7  // Sunday = 1, Saturday = 7
    }

    private func monthBoundaryOffsets() -> [CGFloat] {
        var offsets: [CGFloat] = []
        var currentMonth: Int? = nil

        for (index, date) in dateRange.enumerated() {
            let month = cal.component(.month, from: date)

            if let prevMonth = currentMonth, month != prevMonth {
                // New month boundary - draw line at the start of the new month day
                offsets.append(CGFloat(index) * dayWidth - 1)
            }

            currentMonth = month
        }

        return offsets
    }

    private func handleAddEvent(for subcategory: ProductionSubcategory) {
        onAddEvent?(subcategory)
    }

    // MARK: - Subcategory Detection for Vertical Drag

    /// Builds array of visible subcategory rows with their Y positions
    private func buildSubcategoryRowInfo() -> [SubcategoryRowInfo] {
        var rows: [SubcategoryRowInfo] = []
        var currentY: CGFloat = categoryHeaderHeight + 1  // Start after date header row

        for category in categories {
            // Skip category header
            currentY += rowHeight + 1  // header + divider

            // Only include rows from expanded categories
            if category.isExpanded {
                for subcategory in category.subcategories {
                    rows.append(SubcategoryRowInfo(
                        subcategory: subcategory,
                        categoryID: category.id,
                        yOffset: currentY,
                        rowHeight: rowHeight
                    ))
                    currentY += rowHeight + 1  // row + divider
                }
            }
        }

        return rows
    }

    /// Detects which subcategory row the cursor is over based on global Y position
    private func subcategoryForYPosition(_ globalY: CGFloat) -> ProductionSubcategory? {
        let relativeY = globalY - timelineGridTopY

        for rowInfo in subcategoryRowMap {
            if relativeY >= rowInfo.yOffset && relativeY < rowInfo.yOffset + rowInfo.rowHeight {
                return rowInfo.subcategory
            }
        }

        return nil
    }
}

// MARK: - Category Sidebar Row (Simplified)
private struct CategorySidebarRow: View {
    @Binding var category: ProductionCategory
    let rowHeight: CGFloat
    let colorScheme: ColorScheme
    var onAddEvent: ((ProductionSubcategory) -> Void)?

    @State private var hoveredSubcategoryID: String?

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .primary.opacity(0.6)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header
            Button(action: { category.isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 14)

                    Text(category.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: rowHeight)
                .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.96))
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            // Subcategory rows
            if category.isExpanded {
                ForEach(category.subcategories) { subcategory in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 6, height: 6)

                        Text(subcategory.name)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(secondaryTextColor)

                        Spacer()

                        // Add button (appears on hover)
                        Button(action: {
                            onAddEvent?(subcategory)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Add Event")
                        .opacity(hoveredSubcategoryID == subcategory.id ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.15), value: hoveredSubcategoryID == subcategory.id)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: rowHeight)
                    .background(colorScheme == .dark ? Color(white: 0.08) : Color.white)
                    .onHover { hovering in
                        hoveredSubcategoryID = hovering ? subcategory.id : nil
                    }

                    Rectangle()
                        .fill(dividerColor.opacity(0.5))
                        .frame(height: 1)
                }
                .animation(.easeInOut(duration: 0.2), value: category.isExpanded)
            }
        }
    }
}

// MARK: - Category Timeline Column (for lazy loading)
private struct CategoryTimelineColumn: View {
    let category: ProductionCategory
    let date: Date
    let dateIndex: Int
    let events: [ProductionEvent]
    let timelineStart: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    let colorScheme: ColorScheme
    var onEventTap: (ProductionEvent) -> Void

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header cell
            Color.clear
                .frame(width: dayWidth, height: rowHeight)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            // Subcategory cells
            if category.isExpanded {
                ForEach(category.subcategories) { _ in
                    Color.clear
                        .frame(width: dayWidth, height: rowHeight)

                    Rectangle()
                        .fill(dividerColor.opacity(0.5))
                        .frame(height: 1)
                }
            }
        }
    }
}

// MARK: - Category Timeline Row (Simplified)
private struct CategoryTimelineRow: View {
    @Binding var category: ProductionCategory
    let events: [ProductionEvent]
    let dateRange: [Date]
    let timelineStart: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    let colorScheme: ColorScheme
    @Binding var dragRefreshTrigger: Bool
    let subcategoryRowMap: [SubcategoryRowInfo]
    let gridTopY: CGFloat
    var onEventTap: (ProductionEvent) -> Void
    var onEventMoved: (ProductionEvent, Date, String?) -> Void
    var onEventResized: (ProductionEvent, Date?, Date?) -> Void

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            // Category header row (empty grid)
            HStack(spacing: 0) {
                ForEach(dateRange, id: \.self) { _ in
                    Color.clear
                        .frame(width: dayWidth, height: rowHeight)
                }
            }
            .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.96))

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            // Subcategory rows with events
            if category.isExpanded {
                ForEach(category.subcategories) { subcategory in
                    ZStack(alignment: .leading) {
                        // Grid cells
                        HStack(spacing: 0) {
                            ForEach(dateRange, id: \.self) { _ in
                                Color.clear
                                    .frame(width: dayWidth, height: rowHeight)
                            }
                        }

                        // Event bars
                        ForEach(eventsForSubcategory(subcategory)) { event in
                            GanttBar(
                                event: event,
                                startDate: timelineStart,
                                dayWidth: dayWidth,
                                rowHeight: rowHeight,
                                dragRefreshTrigger: $dragRefreshTrigger,
                                subcategoryRowMap: subcategoryRowMap,
                                gridTopY: gridTopY,
                                onTap: { onEventTap(event) },
                                onMoved: { newDate, newSubcategoryID in onEventMoved(event, newDate, newSubcategoryID) },
                                onResized: { newStart, newEnd in onEventResized(event, newStart, newEnd) }
                            )
                        }
                    }
                    .background(
                        // Highlight row when being dragged over
                        GanttDragState.shared.hoveredSubcategoryID == subcategory.id
                            ? Color.accentColor.opacity(0.15)
                            : (colorScheme == .dark ? Color(white: 0.08) : Color.white)
                    )

                    Rectangle()
                        .fill(dividerColor.opacity(0.5))
                        .frame(height: 1)
                }
                .animation(.easeInOut(duration: 0.2), value: category.isExpanded)
            }
        }
    }

    private func eventsForSubcategory(_ subcategory: ProductionSubcategory) -> [ProductionEvent] {
        events.filter { event in
            // Filter by subcategoryID if set, otherwise fall back to categoryID matching
            if let subID = event.subcategoryID {
                return subID == subcategory.id
            }
            // Legacy: show in first subcategory of matching category if no subcategoryID
            guard let catID = event.categoryID else { return false }
            return catID == subcategory.categoryID && subcategory.id == category.subcategories.first?.id
        }
    }
}

// MARK: - Gantt Bar (Event Display)
/// Displays a single event bar in the Gantt timeline with drag-to-move and resize handles.
/// Uses global screen position tracking to avoid coordinate space issues from view recreation.
private struct GanttBar: View {
    let event: ProductionEvent
    let startDate: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    @Binding var dragRefreshTrigger: Bool
    let subcategoryRowMap: [SubcategoryRowInfo]
    let gridTopY: CGFloat
    var onTap: () -> Void
    var onMoved: (Date, String?) -> Void
    var onResized: (Date?, Date?) -> Void

    @State private var isHovered = false

    private var cal: Calendar { Calendar.current }
    private var dragState: GanttDragState { GanttDragState.shared }

    // MARK: - Computed Properties

    private var offsetDays: Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: event.date)).day ?? 0
    }

    private var durationDays: Int {
        guard let endDate = event.endDate else { return 1 }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: event.date), to: cal.startOfDay(for: endDate)).day ?? 0
        return max(1, days + 1)
    }

    private var barWidth: CGFloat {
        max(CGFloat(durationDays) * dayWidth - 4, dayWidth - 4)
    }

    // Get drag state from global singleton
    private var isDragging: Bool {
        dragState.isDragging(eventID: event.id)
    }

    private var isResizingStart: Bool {
        dragState.isResizingStart(eventID: event.id)
    }

    private var isResizingEnd: Bool {
        dragState.isResizingEnd(eventID: event.id)
    }

    private var dragOffset: CGFloat {
        dragState.offset(for: event.id, type: .move)
    }

    private var resizeStartOffset: CGFloat {
        dragState.offset(for: event.id, type: .resizeStart)
    }

    private var resizeEndOffset: CGFloat {
        dragState.offset(for: event.id, type: .resizeEnd)
    }

    // Calculate adjusted values during drag/resize
    private var adjustedOffsetDays: CGFloat {
        CGFloat(offsetDays) + (dragOffset + resizeStartOffset) / dayWidth
    }

    private var adjustedBarWidth: CGFloat {
        barWidth - resizeStartOffset + resizeEndOffset
    }

    /// Duration days adjusted for current resize operation (updates in real-time)
    private var adjustedDurationDays: Int {
        // If not resizing, return the static duration
        guard isResizingStart || isResizingEnd else { return durationDays }

        // Calculate how many days the resize has changed
        let startDaysDelta = isResizingStart ? Int(round(resizeStartOffset / dayWidth)) : 0
        let endDaysDelta = isResizingEnd ? Int(round(resizeEndOffset / dayWidth)) : 0

        // Adjust duration: shrinking start adds days, extending end adds days
        let adjusted = durationDays - startDaysDelta + endDaysDelta
        return max(1, adjusted)
    }

    // MARK: - Body

    var body: some View {
        // Use ID to force re-render when dragRefreshTrigger changes
        let _ = dragRefreshTrigger

        HStack(spacing: 0) {
            Color.clear
                .frame(width: max(0, adjustedOffsetDays * dayWidth))

            ZStack {
                // Main bar content
                HStack(spacing: 0) {
                    // Left resize handle
                    leftResizeHandle

                    // Main draggable area
                    mainDragArea

                    // Right resize handle
                    rightResizeHandle
                }
                .frame(width: max(dayWidth - 4, adjustedBarWidth), height: rowHeight - 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(event.displayColor)
                        .brightness(isHovered || isDragging ? 0.15 : 0)
                        .shadow(
                            color: .black.opacity(isDragging || isResizingStart || isResizingEnd ? 0.3 : (isHovered ? 0.2 : 0)),
                            radius: isDragging ? 8 : 4,
                            y: isDragging ? 4 : 0
                        )
                )
                .opacity(isDragging || isResizingStart || isResizingEnd ? 0.9 : 1.0)
                .scaleEffect(isDragging ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isDragging)
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .customTooltip(event.title)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Subviews

    private var leftResizeHandle: some View {
        Rectangle()
            .fill(Color.white.opacity(isHovered ? 0.3 : 0.001))
            .frame(width: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if dragState.activeEventID != event.id || dragState.dragType != .resizeStart {
                            print("[GanttBar DEBUG] Left resize started for event: '\(event.title)'")
                            dragState.beginDrag(eventID: event.id, type: .resizeStart, startX: value.startLocation.x)
                        }
                        dragState.updateDrag(currentX: value.location.x)

                        // Constrain offset
                        let maxOffset = barWidth - dayWidth
                        let raw = dragState.currentOffset
                        let constrained = min(maxOffset, max(-CGFloat(offsetDays) * dayWidth, raw))
                        if constrained != raw {
                            dragState.updateDrag(currentX: dragState.startX + constrained)
                        }

                        print("[GanttBar DEBUG] Left resizing - offset: \(Int(dragState.currentOffset))")
                        dragRefreshTrigger.toggle()
                    }
                    .onEnded { _ in
                        let (xOffset, _) = dragState.endDrag()
                        let daysDelta = Int(round(xOffset / dayWidth))
                        print("[GanttBar DEBUG] Left resize ended - daysDelta: \(daysDelta)")

                        dragRefreshTrigger.toggle()

                        if daysDelta != 0 {
                            if let newStartDate = cal.date(byAdding: .day, value: daysDelta, to: event.date) {
                                onResized(newStartDate, nil)
                            }
                        }
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    private var mainDragArea: some View {
        HStack(spacing: 4) {
            Text(event.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            if barWidth > 80 {
                Text("\(adjustedDurationDays)d")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragState.activeEventID != event.id || dragState.dragType != .move {
                        print("[GanttBar DEBUG] Main drag started for event: '\(event.title)'")
                        print("[GanttBar DEBUG]   - startLocation: (\(Int(value.startLocation.x)), \(Int(value.startLocation.y)))")
                        dragState.beginDrag(eventID: event.id, type: .move, startX: value.startLocation.x, startY: value.startLocation.y)
                    }
                    dragState.updateDrag(currentX: value.location.x, currentY: value.location.y)

                    // Detect hovered subcategory for visual feedback
                    let targetSubcategory = subcategoryForYPosition(value.location.y)
                    if dragState.hoveredSubcategoryID != targetSubcategory?.id {
                        dragState.updateHoveredSubcategory(targetSubcategory?.id)
                    }

                    print("[GanttBar DEBUG] Main dragging - offset: (\(Int(dragState.currentOffset)), \(Int(dragState.currentYOffset)))")
                    dragRefreshTrigger.toggle()
                }
                .onEnded { value in
                    let (xOffset, yOffset) = dragState.endDrag()
                    let daysDelta = Int(round(xOffset / dayWidth))
                    print("[GanttBar DEBUG] Main drag ended - xOffset: \(Int(xOffset)), yOffset: \(Int(yOffset))")
                    print("[GanttBar DEBUG]   - daysDelta: \(daysDelta)")

                    dragRefreshTrigger.toggle()

                    // Calculate new date (horizontal movement)
                    var newDate = event.date
                    if daysDelta != 0 {
                        if let calculatedDate = cal.date(byAdding: .day, value: daysDelta, to: event.date) {
                            newDate = calculatedDate
                            print("[GanttBar DEBUG]   - Moving to newDate: \(newDate)")
                        }
                    }

                    // Detect target subcategory (vertical movement)
                    let targetSubcategory = subcategoryForYPosition(value.location.y)
                    let newSubcategoryID = targetSubcategory?.id ?? event.subcategoryID

                    if let target = targetSubcategory {
                        print("[GanttBar DEBUG]   - Target subcategory: \(target.name) (ID: \(target.id))")
                        if target.id != event.subcategoryID {
                            print("[GanttBar DEBUG]   - Subcategory will change: \(event.subcategoryID ?? "nil") -> \(target.id)")
                        }
                    } else {
                        print("[GanttBar DEBUG]   - No valid target subcategory (keeping current)")
                    }

                    // Call onMoved with both date and subcategory
                    onMoved(newDate, newSubcategoryID)
                }
        )
        .onTapGesture {
            onTap()
        }
    }

    private var rightResizeHandle: some View {
        Rectangle()
            .fill(Color.white.opacity(isHovered ? 0.3 : 0.001))
            .frame(width: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if dragState.activeEventID != event.id || dragState.dragType != .resizeEnd {
                            print("[GanttBar DEBUG] Right resize started for event: '\(event.title)'")
                            dragState.beginDrag(eventID: event.id, type: .resizeEnd, startX: value.startLocation.x)
                        }
                        dragState.updateDrag(currentX: value.location.x)

                        // Constrain offset
                        let minOffset = -(barWidth - dayWidth)
                        let raw = dragState.currentOffset
                        let constrained = max(minOffset, raw)
                        if constrained != raw {
                            dragState.updateDrag(currentX: dragState.startX + constrained)
                        }

                        print("[GanttBar DEBUG] Right resizing - offset: \(Int(dragState.currentOffset))")
                        dragRefreshTrigger.toggle()
                    }
                    .onEnded { _ in
                        let (xOffset, _) = dragState.endDrag()
                        let daysDelta = Int(round(xOffset / dayWidth))
                        print("[GanttBar DEBUG] Right resize ended - daysDelta: \(daysDelta)")

                        dragRefreshTrigger.toggle()

                        if daysDelta != 0 {
                            let currentEndDate = event.endDate ?? event.date
                            if let newEndDate = cal.date(byAdding: .day, value: daysDelta, to: currentEndDate) {
                                onResized(nil, newEndDate)
                            }
                        }
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Helper Functions

    /// Detects which subcategory row the cursor is over based on global Y position
    private func subcategoryForYPosition(_ globalY: CGFloat) -> ProductionSubcategory? {
        let relativeY = globalY - gridTopY

        for rowInfo in subcategoryRowMap {
            if relativeY >= rowInfo.yOffset && relativeY < rowInfo.yOffset + rowInfo.rowHeight {
                return rowInfo.subcategory
            }
        }

        return nil
    }
}

// MARK: - Category Sidebar Section
private struct CategorySidebarSection: View {
    @Binding var category: ProductionCategory
    let rowHeight: CGFloat
    let categoryHeaderHeight: CGFloat
    let colorScheme: ColorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .primary.opacity(0.6)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header - Compact for 10% width
            Button(action: { category.isExpanded.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 12)

                    Text(category.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: categoryHeaderHeight)
                .background(category.color.opacity(0.2))
            }
            .buttonStyle(.plain)

            Divider().background(dividerColor)

            // Subcategory rows - Compact for 10% width
            if category.isExpanded {
                ForEach(category.subcategories) { subcategory in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subcategory.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(height: rowHeight, alignment: .leading)
                    .background(
                        Color.clear
                            .overlay(Divider().background(dividerColor), alignment: .bottom)
                    )
                }
            }
        }
    }
}

// MARK: - Category Timeline Section
private struct CategoryTimelineSection: View {
    let category: ProductionCategory
    let events: [ProductionEvent]
    let dateRange: [Date]
    let timelineStart: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    let categoryHeaderHeight: CGFloat
    let colorScheme: ColorScheme
    var onEventTap: (ProductionEvent) -> Void
    var onEventMoved: (ProductionEvent, Date) -> Void

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    private var dividerLightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header row
            HStack(spacing: 0) {
                ForEach(dateRange, id: \.self) { _ in
                    Color.clear
                        .frame(width: dayWidth, height: categoryHeaderHeight)
                }
            }
            .background(category.color.opacity(0.15))
            .overlay(Divider().background(dividerColor), alignment: .bottom)

            // Subcategory rows
            if category.isExpanded {
                ForEach(category.subcategories) { subcategory in
                    SubcategoryTimelineRow(
                        category: category,
                        subcategory: subcategory,
                        events: eventsForSubcategory(subcategory),
                        dateRange: dateRange,
                        timelineStart: timelineStart,
                        dayWidth: dayWidth,
                        rowHeight: rowHeight,
                        colorScheme: colorScheme,
                        onEventTap: onEventTap,
                        onEventMoved: onEventMoved
                    )
                }
            }
        }
    }

    private func eventsForSubcategory(_ subcategory: ProductionSubcategory) -> [ProductionEvent] {
        events.filter { event in
            event.subcategoryID == subcategory.id
        }
    }
}

// MARK: - Subcategory Timeline Row
private struct SubcategoryTimelineRow: View {
    let category: ProductionCategory
    let subcategory: ProductionSubcategory
    let events: [ProductionEvent]
    let dateRange: [Date]
    let timelineStart: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    let colorScheme: ColorScheme
    var onEventTap: (ProductionEvent) -> Void
    var onEventMoved: (ProductionEvent, Date) -> Void

    @State private var draggedEvent: ProductionEvent?

    private var cal: Calendar { Calendar.current }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background row
            HStack(spacing: 0) {
                ForEach(dateRange, id: \.self) { _ in
                    Color.clear
                        .frame(width: dayWidth, height: rowHeight)
                }
            }
            .overlay(Divider().background(dividerColor), alignment: .bottom)

            // Events
            ForEach(events) { event in
                GanttEventBar(
                    event: event,
                    category: category,
                    timelineStart: timelineStart,
                    dayWidth: dayWidth,
                    rowHeight: rowHeight,
                    colorScheme: colorScheme,
                    onTap: { onEventTap(event) },
                    onMoved: { newDate in onEventMoved(event, newDate) }
                )
            }
        }
        .frame(height: rowHeight)
    }
}

// MARK: - Gantt Event Bar
private struct GanttEventBar: View {
    let event: ProductionEvent
    let category: ProductionCategory
    let timelineStart: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    let colorScheme: ColorScheme
    var onTap: () -> Void
    var onMoved: (Date) -> Void

    // Use @GestureState for drag offsets to prevent gesture conflicts during view re-renders
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var resizeDelta: Int = 0
    @State private var isResizing = false

    private var cal: Calendar { Calendar.current }

    private var eventTextColor: Color {
        .white
    }

    private var offsetDays: Int {
        let start = cal.startOfDay(for: timelineStart)
        let eventStart = cal.startOfDay(for: event.date)
        return max(0, cal.dateComponents([.day], from: start, to: eventStart).day ?? 0)
    }

    private var totalOffset: CGFloat {
        CGFloat(offsetDays) * dayWidth + dragOffset
    }

    private var effectiveDuration: Int {
        event.duration + resizeDelta
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: totalOffset, height: rowHeight)

            // Event bar
            HStack(spacing: 6) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(eventTextColor)
                    .lineLimit(1)

                Spacer()

                Text("\(effectiveDuration) DAYS TOTAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(eventTextColor.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .frame(width: max(CGFloat(effectiveDuration) * dayWidth - 2, dayWidth), height: rowHeight - 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(category.color)
                    .shadow(color: category.color.opacity(0.4), radius: 3, y: 2)
            )
            .opacity(isDragging || isResizing ? 0.8 : 1.0)
            .overlay(
                // Resize handles
                HStack {
                    Spacer()
                    GanttResizeHandle(isResizing: $isResizing, resizeDelta: $resizeDelta, dayWidth: dayWidth)
                }
            )
            .onTapGesture(count: 2) {
                onTap()
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .updating($dragOffset) { value, state, _ in
                        if !isDragging {
                            print("[GanttEventBar DEBUG] Drag started for event: '\(event.title)'")
                            print("[GanttEventBar DEBUG]   - Event date: \(event.date)")
                            print("[GanttEventBar DEBUG]   - dayWidth: \(Int(dayWidth))")
                            print("[GanttEventBar DEBUG]   - offsetDays: \(offsetDays)")
                            DispatchQueue.main.async { self.isDragging = true }
                        }
                        state = value.translation.width
                        print("[GanttEventBar DEBUG] Dragging - translation: \(Int(value.translation.width)), dragOffset: \(Int(state))")
                    }
                    .onEnded { value in
                        let daysMoved = Int(round(value.translation.width / dayWidth))
                        print("[GanttEventBar DEBUG] Drag ended for event: '\(event.title)'")
                        print("[GanttEventBar DEBUG]   - Final translation: \(Int(value.translation.width))")
                        print("[GanttEventBar DEBUG]   - dayWidth: \(Int(dayWidth))")
                        print("[GanttEventBar DEBUG]   - daysMoved (calculated): \(daysMoved)")
                        print("[GanttEventBar DEBUG]   - Original event.date: \(event.date)")

                        isDragging = false
                        if daysMoved != 0, let newDate = cal.date(byAdding: .day, value: daysMoved, to: event.date) {
                            print("[GanttEventBar DEBUG]   - Moving to newDate: \(newDate)")
                            onMoved(newDate)
                        } else {
                            print("[GanttEventBar DEBUG]   - NOT moving (daysMoved == 0 or newDate failed)")
                        }
                    }
            )

            Spacer(minLength: 0)
        }
        .frame(height: rowHeight)
    }
}

// MARK: - Gantt Resize Handle
private struct GanttResizeHandle: View {
    @Binding var isResizing: Bool
    @Binding var resizeDelta: Int
    let dayWidth: CGFloat

    // Use @GestureState for drag amount to prevent gesture conflicts
    @GestureState private var dragAmount: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 8, height: 24)
            .cornerRadius(2)
            .padding(.trailing, 4)
            .gesture(
                DragGesture()
                    .updating($dragAmount) { value, state, _ in
                        if !isResizing {
                            print("[GanttResizeHandle DEBUG] Resize started")
                            print("[GanttResizeHandle DEBUG]   - dayWidth: \(Int(dayWidth))")
                            DispatchQueue.main.async { self.isResizing = true }
                        }
                        state = value.translation.width
                        let newResizeDelta = Int(round(state / dayWidth))
                        if newResizeDelta != resizeDelta {
                            DispatchQueue.main.async { self.resizeDelta = newResizeDelta }
                        }
                        print("[GanttResizeHandle DEBUG] Resizing - dragAmount: \(Int(state)), resizeDelta: \(newResizeDelta)")
                    }
                    .onEnded { value in
                        let finalResizeDelta = Int(round(value.translation.width / dayWidth))
                        print("[GanttResizeHandle DEBUG] Resize ended - final resizeDelta: \(finalResizeDelta)")
                        isResizing = false
                        resizeDelta = finalResizeDelta
                    }
            )
    }
}

// MARK: - Event Type Row
private struct EventTypeRow: View {
    let type: ProductionEventType
    let count: Int
    let isSelected: Bool
    let colorScheme: ColorScheme
    var onTap: () -> Void

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : .primary.opacity(0.8)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .primary.opacity(0.5)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : type.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? primaryTextColor : secondaryTextColor)

                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(tertiaryTextColor)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeline Event Row
private struct TimelineEventRow: View {
    let event: ProductionEvent
    let timelineStart: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    let colorScheme: ColorScheme
    var onTap: () -> Void
    var onMoved: (Date) -> Void

    // Use @GestureState for drag offset to prevent gesture conflicts during view re-renders
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private var cal: Calendar { Calendar.current }

    private var eventTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var eventDurationTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .primary.opacity(0.9)
    }

    private var offsetDays: Int {
        let start = cal.startOfDay(for: timelineStart)
        let eventStart = cal.startOfDay(for: event.date)
        return max(0, cal.dateComponents([.day], from: start, to: eventStart).day ?? 0)
    }

    private var totalOffset: CGFloat {
        CGFloat(offsetDays) * dayWidth + dragOffset
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: totalOffset, height: rowHeight)

            HStack(spacing: 8) {
                Image(systemName: event.type.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(eventTextColor)

                Text(event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(eventTextColor)
                    .lineLimit(1)

                Spacer()

                Text("\(event.duration)d")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(eventDurationTextColor)
            }
            .padding(.horizontal, 14)
            .frame(width: CGFloat(event.duration) * dayWidth - 4, height: rowHeight - 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(event.displayColor)
                    .shadow(color: event.displayColor.opacity(0.4), radius: 4, y: 2)
            )
            .opacity(isDragging ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isDragging)
            .onTapGesture(count: 2) {
                onTap()
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .updating($dragOffset) { value, state, _ in
                        if !isDragging {
                            print("[TimelineEventRow DEBUG] Drag started for event: '\(event.title)'")
                            print("[TimelineEventRow DEBUG]   - Event date: \(event.date)")
                            print("[TimelineEventRow DEBUG]   - dayWidth: \(Int(dayWidth))")
                            print("[TimelineEventRow DEBUG]   - offsetDays: \(offsetDays)")
                            print("[TimelineEventRow DEBUG]   - timelineStart: \(timelineStart)")
                            DispatchQueue.main.async { self.isDragging = true }
                        }
                        state = value.translation.width
                        print("[TimelineEventRow DEBUG] Dragging - translation: \(Int(value.translation.width)), dragOffset: \(Int(state))")
                    }
                    .onEnded { value in
                        let daysMoved = Int(round(value.translation.width / dayWidth))
                        print("[TimelineEventRow DEBUG] Drag ended for event: '\(event.title)'")
                        print("[TimelineEventRow DEBUG]   - Final translation: \(Int(value.translation.width))")
                        print("[TimelineEventRow DEBUG]   - dayWidth: \(Int(dayWidth))")
                        print("[TimelineEventRow DEBUG]   - daysMoved (calculated): \(daysMoved)")
                        print("[TimelineEventRow DEBUG]   - Original event.date: \(event.date)")

                        isDragging = false
                        if daysMoved != 0, let newDate = cal.date(byAdding: .day, value: daysMoved, to: event.date) {
                            print("[TimelineEventRow DEBUG]   - Moving to newDate: \(newDate)")
                            onMoved(newDate)
                        } else {
                            print("[TimelineEventRow DEBUG]   - NOT moving (daysMoved == 0 or newDate failed)")
                        }
                    }
            )

            Spacer(minLength: 0)
        }
        .frame(height: rowHeight)
    }
}

// MARK: - Day Detail Panel (ENHANCED)
private struct DayDetailPanel: View {
    let date: Date
    let events: [ProductionEvent]
    var onClose: () -> Void
    var onAddEvent: () -> Void
    var onEventTap: (ProductionEvent) -> Void
    var onRefresh: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .primary.opacity(0.7)
    }

    private var emptyStateIconColor: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .primary.opacity(0.4)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
    }

    private var panelBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                    Text("\(events.count) event(s)")
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(secondaryTextColor)
                }
                .buttonStyle(.plain)
                .customTooltip("Sync with Scheduler")

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(secondaryTextColor)
                }
                .buttonStyle(.plain)
                .customTooltip("Close")
            }

            Divider()
                .background(dividerColor)

            // Events List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(events) { event in
                        EventCard(event: event, onTap: { onEventTap(event) })
                    }
                    
                    if events.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(emptyStateIconColor)

                            Text("No events scheduled")
                                .font(.system(size: 14))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }

            Spacer()

            // Add Event Button
            Button(action: onAddEvent) {
                Label("Add Event", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(panelBackgroundColor)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Event Card (ENHANCED)
private struct EventCard: View {
    let event: ProductionEvent
    var onTap: () -> Void

    @State private var showLocationDetails = false
    @State private var showTaskDetails = false
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var colorScheme

    private var isShootDay: Bool {
        event.type == .shootDay
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .primary.opacity(0.7)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .primary.opacity(0.5)
    }

    private var iconColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .primary.opacity(0.6)
    }

    private var secondaryIconColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : .primary.opacity(0.8)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }

    private var linkedLocation: LocationItem? {
        // First try to get by linkedLocationID
        if let locationID = event.linkedLocationID {
            if let location = LocationDataManager.shared.getLocation(by: locationID) {
                return location
            }
        }

        // Fallback: try to match by location name in the event's location field
        if !event.location.isEmpty {
            if let location = LocationDataManager.shared.getLocation(byName: event.location) {
                return location
            }
        }

        return nil
    }

    private var linkedTasks: [TaskEntity] {
        guard !event.linkedTaskIDs.isEmpty else { return [] }
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", event.linkedTaskIDs)
        return (try? moc.fetch(fetchRequest)) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card button
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: event.type.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(event.displayColor)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(event.displayColor.opacity(0.25))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(primaryTextColor)

                            HStack(spacing: 4) {
                                Text(event.type.rawValue)
                                    .font(.system(size: 12))
                                    .foregroundStyle(secondaryTextColor)

                                if isShootDay {
                                    Text("•")
                                        .font(.system(size: 12))
                                        .foregroundStyle(secondaryTextColor)
                                    Text("From Scheduler")
                                        .font(.system(size: 11))
                                        .foregroundStyle(secondaryTextColor)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tertiaryTextColor)
                    }

                    if let callTime = event.callTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(secondaryTextColor)

                            Text("Call: \(formatTime(callTime))")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }

                    if !event.location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                                .foregroundStyle(secondaryTextColor)

                            Text(event.location)
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                    }

                    if !event.scenes.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(.system(size: 11))
                                .foregroundStyle(secondaryTextColor)

                            Text("Scenes: \(event.scenes.joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Linked Location Dropdown
            if let location = linkedLocation {
                VStack(spacing: 0) {
                    Divider()
                        .background(dividerColor)

                    Button(action: { withAnimation { showLocationDetails.toggle() } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)

                            Text("Synced Location")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(primaryTextColor)

                            Spacer()

                            Image(systemName: showLocationDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tertiaryTextColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                    }
                    .buttonStyle(.plain)

                    if showLocationDetails {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(location.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(primaryTextColor)

                            if !location.address.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 10))
                                        .foregroundStyle(iconColor)
                                    Text(location.address)
                                        .font(.system(size: 11))
                                        .foregroundStyle(secondaryIconColor)
                                }
                            }

                            if !location.contact.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "person")
                                        .font(.system(size: 10))
                                        .foregroundStyle(iconColor)
                                    Text(location.contact)
                                        .font(.system(size: 11))
                                        .foregroundStyle(secondaryIconColor)
                                }
                            }

                            if !location.phone.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "phone")
                                        .font(.system(size: 10))
                                        .foregroundStyle(iconColor)
                                    Text(location.phone)
                                        .font(.system(size: 11))
                                        .foregroundStyle(secondaryIconColor)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.blue.opacity(0.05))
                    }
                }
            }

            // Linked Tasks Dropdown
            if !linkedTasks.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    Button(action: { withAnimation { showTaskDetails.toggle() } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checklist")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)

                            Text("Synced Tasks (\(linkedTasks.count))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(primaryTextColor)

                            Spacer()

                            Image(systemName: showTaskDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tertiaryTextColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.1))
                    }
                    .buttonStyle(.plain)

                    if showTaskDetails {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(linkedTasks, id: \.id) { task in
                                HStack(spacing: 8) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(task.isCompleted ? .green : tertiaryTextColor)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title ?? "Untitled Task")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(primaryTextColor)

                                        if let notes = task.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.system(size: 10))
                                                .foregroundStyle(secondaryTextColor)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.green.opacity(0.05))
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(event.displayColor.opacity(0.4), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Filter Panel (ENHANCED)
private struct FilterPanel: View {
    @Binding var eventTypeFilters: Set<ProductionEventType>
    var onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.6)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
    }

    private var backgroundSecondaryColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filters")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(secondaryTextColor)
                }
                .buttonStyle(.plain)
                .customTooltip("Close")
            }

            Divider()
                .background(dividerColor)

            Text("Event Types")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ProductionEventType.allCases, id: \.self) { type in
                    HStack(spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { eventTypeFilters.contains(type) },
                            set: { isOn in
                                if isOn {
                                    eventTypeFilters.insert(type)
                                } else {
                                    eventTypeFilters.remove(type)
                                }
                            }
                        )) {
                            EmptyView()
                        }
                        .toggleStyle(.switch)
                        .labelsHidden()

                        Image(systemName: type.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(type.color)
                            .frame(width: 24)

                        Text(type.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(primaryTextColor)

                        Spacer()
                    }
                }
            }

            Spacer()

            Button("Reset Filters") {
                eventTypeFilters = Set(ProductionEventType.allCases)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(backgroundSecondaryColor)
    }
}

#else
// iOS stub - this view is disabled on iOS, shown via placeholder in MainDashboardViewiOS
struct CalendarView: View {
    let project: NSManagedObject
    var body: some View {
        Text("Calendar - Coming Soon on iOS")
    }
}
#endif
