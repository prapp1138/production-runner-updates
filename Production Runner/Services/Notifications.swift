//
//  Notifications.swift
//  Production Runner
//
//  Created by Brandon on 11/2/25.
//

import SwiftUI
import Combine
import UserNotifications

// MARK: - Notification Model
struct PRNotification: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let category: NotificationCategory
    let timestamp: Date
    var isRead: Bool
    var actionURL: String?

    enum NotificationCategory: String, Codable, CaseIterable {
        case general = "General"
        case task = "Task"
        case schedule = "Schedule"
        case callSheet = "Call Sheet"
        case location = "Location"
        case budget = "Budget"
        case team = "Team"
        case scriptRevision = "Script Revision"
        case chat = "Chat"
        case calendar = "Calendar"
        case paperwork = "Paperwork"
        case shots = "Shots"

        var icon: String {
            switch self {
            case .general: return "bell.fill"
            case .task: return "checklist"
            case .schedule: return "calendar.badge.clock"
            case .callSheet: return "doc.text.fill"
            case .location: return "mappin.circle.fill"
            case .budget: return "dollarsign.circle.fill"
            case .team: return "person.2.fill"
            case .scriptRevision: return "doc.badge.arrow.up"
            case .chat: return "message.fill"
            case .calendar: return "calendar"
            case .paperwork: return "doc.on.clipboard.fill"
            case .shots: return "film.fill"
            }
        }

        var color: Color {
            switch self {
            case .general: return .blue
            case .task: return .orange
            case .schedule: return .green
            case .callSheet: return .purple
            case .location: return .pink
            case .budget: return .yellow
            case .team: return .teal
            case .scriptRevision: return Color(red: 1.0, green: 0.6, blue: 0.2)
            case .chat: return .indigo
            case .calendar: return .cyan
            case .paperwork: return .brown
            case .shots: return .mint
            }
        }

        var displayName: String {
            return self.rawValue
        }

        var description: String {
            switch self {
            case .general: return "General app notifications"
            case .task: return "Task assignments and updates"
            case .schedule: return "Schedule changes and updates"
            case .callSheet: return "Call sheet drafts and updates"
            case .location: return "Location updates and changes"
            case .budget: return "Budget updates and changes"
            case .team: return "Team member updates"
            case .scriptRevision: return "New screenplay revisions"
            case .chat: return "New chat messages"
            case .calendar: return "Calendar invites and events"
            case .paperwork: return "New paperwork and documents"
            case .shots: return "Shot list updates"
            }
        }
    }

    init(id: UUID = UUID(), title: String, message: String, category: NotificationCategory, timestamp: Date = Date(), isRead: Bool = false, actionURL: String? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.category = category
        self.timestamp = timestamp
        self.isRead = isRead
        self.actionURL = actionURL
    }
}

// MARK: - Notification Settings Manager
class NotificationSettingsManager: ObservableObject {
    static let shared = NotificationSettingsManager()

    // Global notification toggle
    @AppStorage("app_notifications") var notificationsEnabled: Bool = true

    // First launch tracking
    @AppStorage("app_notifications_prompted") var hasPromptedForNotifications: Bool = false

    // System notification authorization status
    @Published var systemNotificationsAuthorized: Bool = false

    // Per-category toggles
    @AppStorage("notify_general") var generalEnabled: Bool = true
    @AppStorage("notify_task") var taskEnabled: Bool = true
    @AppStorage("notify_schedule") var scheduleEnabled: Bool = true
    @AppStorage("notify_callSheet") var callSheetEnabled: Bool = true
    @AppStorage("notify_location") var locationEnabled: Bool = true
    @AppStorage("notify_budget") var budgetEnabled: Bool = true
    @AppStorage("notify_team") var teamEnabled: Bool = true
    @AppStorage("notify_scriptRevision") var scriptRevisionEnabled: Bool = true
    @AppStorage("notify_chat") var chatEnabled: Bool = true
    @AppStorage("notify_calendar") var calendarEnabled: Bool = true
    @AppStorage("notify_paperwork") var paperworkEnabled: Bool = true
    @AppStorage("notify_shots") var shotsEnabled: Bool = true

    private init() {
        checkSystemNotificationStatus()
    }

    func isEnabled(for category: PRNotification.NotificationCategory) -> Bool {
        guard notificationsEnabled else { return false }

        switch category {
        case .general: return generalEnabled
        case .task: return taskEnabled
        case .schedule: return scheduleEnabled
        case .callSheet: return callSheetEnabled
        case .location: return locationEnabled
        case .budget: return budgetEnabled
        case .team: return teamEnabled
        case .scriptRevision: return scriptRevisionEnabled
        case .chat: return chatEnabled
        case .calendar: return calendarEnabled
        case .paperwork: return paperworkEnabled
        case .shots: return shotsEnabled
        }
    }

    func setEnabled(_ enabled: Bool, for category: PRNotification.NotificationCategory) {
        switch category {
        case .general: generalEnabled = enabled
        case .task: taskEnabled = enabled
        case .schedule: scheduleEnabled = enabled
        case .callSheet: callSheetEnabled = enabled
        case .location: locationEnabled = enabled
        case .budget: budgetEnabled = enabled
        case .team: teamEnabled = enabled
        case .scriptRevision: scriptRevisionEnabled = enabled
        case .chat: chatEnabled = enabled
        case .calendar: calendarEnabled = enabled
        case .paperwork: paperworkEnabled = enabled
        case .shots: shotsEnabled = enabled
        }
    }

    func checkSystemNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.systemNotificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestSystemNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.systemNotificationsAuthorized = granted
                self?.hasPromptedForNotifications = true
                completion(granted)
            }
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func openSystemSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - System Notification Service
class SystemNotificationService {
    static let shared = SystemNotificationService()

    private init() {
        setupNotificationCategories()
    }

    private func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        // Create notification categories for actionable notifications
        var categories: Set<UNNotificationCategory> = []

        for category in PRNotification.NotificationCategory.allCases {
            let viewAction = UNNotificationAction(
                identifier: "VIEW_ACTION",
                title: "View",
                options: [.foreground]
            )

            let dismissAction = UNNotificationAction(
                identifier: "DISMISS_ACTION",
                title: "Dismiss",
                options: [.destructive]
            )

            let notificationCategory = UNNotificationCategory(
                identifier: category.rawValue,
                actions: [viewAction, dismissAction],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )

            categories.insert(notificationCategory)
        }

        center.setNotificationCategories(categories)
    }

    func sendSystemNotification(title: String, message: String, category: PRNotification.NotificationCategory, identifier: String? = nil) {
        guard NotificationSettingsManager.shared.isEnabled(for: category),
              NotificationSettingsManager.shared.systemNotificationsAuthorized else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = category.rawValue

        // Add category-specific user info
        content.userInfo = [
            "category": category.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        let notificationID = identifier ?? UUID().uuidString
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send system notification: \(error.localizedDescription)")
            }
        }
    }

    func clearPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - Notification Manager (Global State)
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var notifications: [PRNotification] = []
    @AppStorage("pr_notifications") private var notificationsData: Data = Data()

    private let settings = NotificationSettingsManager.shared
    private let systemNotifications = SystemNotificationService.shared

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private init() {
        loadNotifications()
    }

    /// Add a notification (both in-app and system notification)
    func addNotification(title: String, message: String, category: PRNotification.NotificationCategory, actionURL: String? = nil, sendSystemNotification: Bool = true) {
        // Always add to in-app notifications
        let notification = PRNotification(
            title: title,
            message: message,
            category: category,
            actionURL: actionURL
        )
        notifications.insert(notification, at: 0)
        saveNotifications()

        // Send system notification if enabled
        if sendSystemNotification && settings.isEnabled(for: category) {
            systemNotifications.sendSystemNotification(
                title: title,
                message: message,
                category: category,
                identifier: notification.id.uuidString
            )
        }
    }

    /// Add notification for screenplay revision
    func notifyScriptRevision(revisionName: String, projectName: String) {
        addNotification(
            title: "New Script Revision",
            message: "\(revisionName) is now available for \(projectName)",
            category: .scriptRevision
        )
    }

    /// Add notification for calendar invite
    func notifyCalendarInvite(eventName: String, from sender: String) {
        addNotification(
            title: "Calendar Invite",
            message: "\(sender) invited you to \(eventName)",
            category: .calendar
        )
    }

    /// Add notification for task assignment
    func notifyTaskAssigned(taskName: String, assignedBy: String) {
        addNotification(
            title: "Task Assigned",
            message: "\(assignedBy) assigned you: \(taskName)",
            category: .task
        )
    }

    /// Add notification for budget update
    func notifyBudgetUpdate(budgetName: String, changeDescription: String) {
        addNotification(
            title: "Budget Updated",
            message: "\(budgetName): \(changeDescription)",
            category: .budget
        )
    }

    /// Add notification for shot list update
    func notifyShotUpdate(shotName: String, updateType: String) {
        addNotification(
            title: "Shot Updated",
            message: "\(shotName) - \(updateType)",
            category: .shots
        )
    }

    /// Add notification for schedule update
    func notifyScheduleUpdate(scheduleName: String, changeDescription: String) {
        addNotification(
            title: "Schedule Updated",
            message: "\(scheduleName): \(changeDescription)",
            category: .schedule
        )
    }

    /// Add notification for call sheet draft
    func notifyCallSheetDrafted(callSheetName: String, shootDate: String) {
        addNotification(
            title: "Call Sheet Drafted",
            message: "\(callSheetName) for \(shootDate) is ready for review",
            category: .callSheet
        )
    }

    /// Add notification for new chat message
    func notifyChatMessage(from sender: String, channelName: String, preview: String) {
        addNotification(
            title: "\(sender) in #\(channelName)",
            message: preview,
            category: .chat
        )
    }

    /// Add notification for new paperwork
    func notifyNewPaperwork(documentName: String, from sender: String) {
        addNotification(
            title: "New Paperwork",
            message: "\(sender) sent you: \(documentName)",
            category: .paperwork
        )
    }

    func markAsRead(_ notification: PRNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            saveNotifications()
        }
    }

    func markAllAsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        saveNotifications()
    }

    func deleteNotification(_ notification: PRNotification) {
        notifications.removeAll { $0.id == notification.id }
        saveNotifications()
    }

    func clearAll() {
        notifications.removeAll()
        saveNotifications()
    }

    private func saveNotifications() {
        if let encoded = try? JSONEncoder().encode(notifications) {
            notificationsData = encoded
        }
    }

    private func loadNotifications() {
        if let decoded = try? JSONDecoder().decode([PRNotification].self, from: notificationsData) {
            notifications = decoded
        }
    }
}

// MARK: - Notifications View (macOS)
struct NotificationsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedCategory: PRNotification.NotificationCategory? = nil
    @State private var searchText = ""
    
    private var filteredNotifications: [PRNotification] {
        var result = notificationManager.notifications
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("Notifications")
                        .font(.system(size: 28, weight: .bold))
                    
                    Spacer()
                    
                    if notificationManager.unreadCount > 0 {
                        Text("\(notificationManager.unreadCount) unread")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                            )
                    }
                    
                    Menu {
                        Button("Mark All as Read") {
                            notificationManager.markAllAsRead()
                        }
                        Button("Clear All", role: .destructive) {
                            notificationManager.clearAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                }
                
                // Search and filter
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("Search notifications...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    
                    Menu {
                        Button("All Categories") {
                            selectedCategory = nil
                        }
                        Divider()
                        ForEach(PRNotification.NotificationCategory.allCases, id: \.self) { category in
                            Button(category.rawValue) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 14, weight: .medium))
                            Text(selectedCategory?.rawValue ?? "All")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(20)
            
            Divider()
            
            // Notifications list
            if filteredNotifications.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredNotifications) { notification in
                            NotificationRow(notification: notification)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("No Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("You're all caught up!")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: PRNotification
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Category icon
            ZStack {
                Circle()
                    .fill(notification.category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: notification.category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(notification.category.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(timeAgo(from: notification.timestamp))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                
                Text(notification.message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if !notification.isRead {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text("Unread")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Text(notification.category.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(notification.category.color.opacity(0.12))
                        )
                }
                .padding(.top, 4)
            }
            
            // Actions
            HStack(spacing: 8) {
                if !notification.isRead {
                    Button {
                        notificationManager.markAsRead(notification)
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Mark as read")
                }
                
                Button {
                    notificationManager.deleteNotification(notification)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(notification.isRead ? Color.primary.opacity(0.02) : Color.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    notification.isRead ? Color.primary.opacity(0.06) : Color.blue.opacity(0.15),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - iOS Notifications View
struct NotificationsViewiOS: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedCategory: PRNotification.NotificationCategory? = nil
    @State private var searchText = ""
    
    private var filteredNotifications: [PRNotification] {
        var result = notificationManager.notifications
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("Search notifications...", text: $searchText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(PRNotification.NotificationCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                isSelected: selectedCategory == category,
                                color: category.color
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                // Notifications list
                if filteredNotifications.isEmpty {
                    emptyStateIOS
                } else {
                    List {
                        ForEach(filteredNotifications) { notification in
                            NotificationRowIOS(notification: notification)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All as Read") {
                            notificationManager.markAllAsRead()
                        }
                        Button("Clear All", role: .destructive) {
                            notificationManager.clearAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Mark All as Read") {
                            notificationManager.markAllAsRead()
                        }
                        Button("Clear All", role: .destructive) {
                            notificationManager.clearAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                #endif
            }
            .overlay(alignment: .topTrailing) {
                if notificationManager.unreadCount > 0 {
                    Text("\(notificationManager.unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                        .padding(.top, 8)
                        .padding(.trailing, 60)
                }
            }
        }
    }
    
    private var emptyStateIOS: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("No Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("You're all caught up!")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Category Chip (iOS)
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color : Color.primary.opacity(0.08))
                )
        }
    }
}

// MARK: - iOS Notification Row
struct NotificationRowIOS: View {
    let notification: PRNotification
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(notification.category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: notification.category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(notification.category.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(timeAgo(from: notification.timestamp))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(notification.category.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(notification.category.color)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(notification.isRead ? Color.primary.opacity(0.02) : Color.blue.opacity(0.05))
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                notificationManager.deleteNotification(notification)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            if !notification.isRead {
                Button {
                    notificationManager.markAsRead(notification)
                } label: {
                    Label("Read", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - First Launch Notification Prompt
struct NotificationPermissionPromptView: View {
    @ObservedObject var settings = NotificationSettingsManager.shared
    @Binding var isPresented: Bool
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            // Header with icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)

            Text("Stay Updated")
                .font(.system(size: 24, weight: .bold))

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    isRequesting = true
                    settings.requestSystemNotificationPermission { granted in
                        isRequesting = false
                        isPresented = false
                    }
                } label: {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Enable Notifications")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)

                Button {
                    settings.hasPromptedForNotifications = true
                    isPresented = false
                } label: {
                    Text("Not Now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
    }
}

struct NotificationTypeRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @ObservedObject var settings = NotificationSettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification Settings")
                        .font(.title.bold())
                    Text("Choose which notifications you want to receive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(24)
            .background(Color.primary.opacity(0.03))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // System notification status
                    systemNotificationStatus

                    // Master toggle
                    masterToggleSection

                    // Per-category toggles
                    if settings.notificationsEnabled {
                        categoryTogglesSection
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 550, height: 650)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            settings.checkSystemNotificationStatus()
        }
    }

    private var systemNotificationStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: settings.systemNotificationsAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(settings.systemNotificationsAuthorized ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("System Notifications")
                        .font(.headline)

                    Text(settings.systemNotificationsAuthorized
                        ? "Production Runner can send you notifications"
                        : "System notifications are disabled. Enable them in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !settings.systemNotificationsAuthorized {
                    Button("Open Settings") {
                        settings.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(settings.systemNotificationsAuthorized ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(settings.systemNotificationsAuthorized ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var masterToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.blue.gradient)
                Text("All Notifications")
                    .font(.title3.bold())
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Notifications")
                        .font(.body.weight(.semibold))
                    Text("Master toggle for all in-app and system notifications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $settings.notificationsEnabled)
                    .labelsHidden()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var categoryTogglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.purple.gradient)
                Text("Notification Categories")
                    .font(.title3.bold())
            }

            VStack(spacing: 0) {
                ForEach(PRNotification.NotificationCategory.allCases, id: \.self) { category in
                    CategoryToggleRow(category: category)

                    if category != PRNotification.NotificationCategory.allCases.last {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct CategoryToggleRow: View {
    let category: PRNotification.NotificationCategory
    @ObservedObject var settings = NotificationSettingsManager.shared

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { settings.isEnabled(for: category) },
            set: { settings.setEnabled($0, for: category) }
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: category.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))

                Text(category.description)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isEnabled)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Notification Permission Check Modifier
struct NotificationPermissionModifier: ViewModifier {
    @ObservedObject var settings = NotificationSettingsManager.shared
    @State private var showPrompt = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !settings.hasPromptedForNotifications {
                    // Delay to let the welcome sheet appear and be dismissed first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        showPrompt = true
                    }
                }
            }
            .sheet(isPresented: $showPrompt) {
                NotificationPermissionPromptView(isPresented: $showPrompt)
            }
    }
}

extension View {
    func checkNotificationPermission() -> some View {
        modifier(NotificationPermissionModifier())
    }
}
