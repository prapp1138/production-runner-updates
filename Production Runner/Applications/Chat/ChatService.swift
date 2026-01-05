import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Firestore Models

struct FirestoreUser: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var displayName: String
    var email: String?
    var photoURL: String?
    var createdAt: Date
    var lastSeen: Date
    var isOnline: Bool

    var initials: String {
        String(displayName.split(separator: " ").compactMap { $0.first }.prefix(2))
    }

    init(id: String? = nil, displayName: String, email: String? = nil, photoURL: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.createdAt = Date()
        self.lastSeen = Date()
        self.isOnline = true
    }
}

struct FirestoreChannel: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var isPrivate: Bool
    var memberIDs: [String]
    var createdAt: Date
    var createdBy: String
    var lastMessageAt: Date?
    var lastMessagePreview: String?

    init(id: String? = nil, name: String, isPrivate: Bool = false, memberIDs: [String], createdBy: String) {
        self.id = id
        self.name = name
        self.isPrivate = isPrivate
        self.memberIDs = memberIDs
        self.createdBy = createdBy
        self.createdAt = Date()
    }
}

struct FirestoreMessage: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var channelID: String
    var authorID: String
    var authorName: String
    var text: String
    var timestamp: Date
    var isEdited: Bool
    var editedAt: Date?

    init(id: String? = nil, channelID: String, authorID: String, authorName: String, text: String) {
        self.id = id
        self.channelID = channelID
        self.authorID = authorID
        self.authorName = authorName
        self.text = text
        self.timestamp = Date()
        self.isEdited = false
    }
}

// MARK: - Chat Service

@MainActor
class ChatService: ObservableObject {
    static let shared = ChatService()

    // Lazy initialization to avoid accessing Firestore before Firebase.configure()
    private lazy var db: Firestore = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var channelsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?

    // Published state - Chat specific
    @Published var channels: [FirestoreChannel] = []
    @Published var messages: [FirestoreMessage] = []
    @Published var users: [String: FirestoreUser] = [:] // Cache of users by ID
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Computed properties bridging to AuthService
    var currentUser: FirestoreUserProfile? {
        AuthService.shared.currentUser
    }

    var isAuthenticated: Bool {
        AuthService.shared.isAuthenticated
    }

    var userID: String? {
        AuthService.shared.userID
    }

    private init() {
        setupAuthSubscription()
    }

    deinit {
        channelsListener?.remove()
        messagesListener?.remove()
    }

    // MARK: - Auth Subscription

    private func setupAuthSubscription() {
        // Subscribe to AuthService state changes
        AuthService.shared.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .authenticated:
                    self?.onUserAuthenticated()
                case .unauthenticated, .unknown:
                    self?.onUserSignedOut()
                }
            }
            .store(in: &cancellables)
    }

    private func onUserAuthenticated() {
        guard let userID = userID else { return }
        print("🔥 Chat: User authenticated, setting up channels for \(userID)")

        // Join or create general channel
        Task {
            await joinOrCreateGeneralChannel()
            listenToChannels()
        }
    }

    private func onUserSignedOut() {
        print("🔥 Chat: User signed out, clearing data")
        channelsListener?.remove()
        messagesListener?.remove()
        channels = []
        messages = []
        users = [:]
    }

    // MARK: - Display Name Update

    func updateDisplayName(_ name: String) async {
        guard var profile = AuthService.shared.currentUser else { return }
        profile.displayName = name

        do {
            try await AuthService.shared.updateUserProfile(profile)
            print("🔥 Updated display name to: \(name)")
        } catch {
            errorMessage = "Failed to update name: \(error.localizedDescription)"
        }
    }

    // MARK: - User Fetching

    func fetchUser(id: String) async -> FirestoreUser? {
        if let cached = users[id] {
            return cached
        }

        do {
            let document = try await db.collection("users").document(id).getDocument()
            if let user = try? document.data(as: FirestoreUser.self) {
                users[id] = user
                return user
            }
        } catch {
            print("🔥 Failed to fetch user \(id): \(error)")
        }

        return nil
    }

    // MARK: - Channels

    private func joinOrCreateGeneralChannel() async {
        guard let userID = userID else { return }

        // Check if general channel exists
        do {
            let snapshot = try await db.collection("channels")
                .whereField("name", isEqualTo: "general")
                .limit(to: 1)
                .getDocuments()

            if let existingChannel = snapshot.documents.first {
                // Join existing channel
                var channel = try existingChannel.data(as: FirestoreChannel.self)
                if !channel.memberIDs.contains(userID) {
                    channel.memberIDs.append(userID)
                    try db.collection("channels").document(existingChannel.documentID).setData(from: channel, merge: true)
                }
                print("🔥 Joined existing general channel")
            } else {
                // Create general channel
                let general = FirestoreChannel(
                    name: "general",
                    isPrivate: false,
                    memberIDs: [userID],
                    createdBy: userID
                )
                _ = try db.collection("channels").addDocument(from: general)
                print("🔥 Created general channel")
            }
        } catch {
            print("🔥 Failed to setup general channel: \(error)")
        }
    }

    private func listenToChannels() {
        guard let userID = userID else { return }

        channelsListener?.remove()

        channelsListener = db.collection("channels")
            .whereField("memberIDs", arrayContains: userID)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("🔥 Channels listener error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                Task { @MainActor in
                    self?.channels = documents.compactMap { doc in
                        try? doc.data(as: FirestoreChannel.self)
                    }
                    print("🔥 Channels updated: \(self?.channels.count ?? 0)")
                }
            }
    }

    func createChannel(name: String, isPrivate: Bool) async -> FirestoreChannel? {
        guard let userID = userID else { return nil }

        let channel = FirestoreChannel(
            name: name,
            isPrivate: isPrivate,
            memberIDs: [userID],
            createdBy: userID
        )

        do {
            let ref = try db.collection("channels").addDocument(from: channel)
            var newChannel = channel
            newChannel.id = ref.documentID
            print("🔥 Created channel: \(name)")
            return newChannel
        } catch {
            errorMessage = "Failed to create channel: \(error.localizedDescription)"
            return nil
        }
    }

    func deleteChannel(_ channel: FirestoreChannel) async {
        guard let channelID = channel.id else { return }

        do {
            // Delete all messages in channel first
            let messages = try await db.collection("messages")
                .whereField("channelID", isEqualTo: channelID)
                .getDocuments()

            for doc in messages.documents {
                try await doc.reference.delete()
            }

            // Delete channel
            try await db.collection("channels").document(channelID).delete()
            print("🔥 Deleted channel: \(channel.name)")
        } catch {
            errorMessage = "Failed to delete channel: \(error.localizedDescription)"
        }
    }

    // MARK: - Messages

    func listenToMessages(in channel: FirestoreChannel) {
        guard let channelID = channel.id else { return }

        messagesListener?.remove()

        messagesListener = db.collection("messages")
            .whereField("channelID", isEqualTo: channelID)
            .order(by: "timestamp", descending: false)
            .limit(toLast: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("🔥 Messages listener error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                Task { @MainActor in
                    self?.messages = documents.compactMap { doc in
                        try? doc.data(as: FirestoreMessage.self)
                    }
                    print("🔥 Messages updated: \(self?.messages.count ?? 0)")
                }
            }
    }

    func sendMessage(text: String, in channel: FirestoreChannel) async {
        guard let channelID = channel.id,
              let user = currentUser,
              let userID = user.id else { return }

        let message = FirestoreMessage(
            channelID: channelID,
            authorID: userID,
            authorName: user.displayName,
            text: text
        )

        do {
            _ = try db.collection("messages").addDocument(from: message)

            // Update channel's last message info
            try await db.collection("channels").document(channelID).setData([
                "lastMessageAt": FieldValue.serverTimestamp(),
                "lastMessagePreview": String(text.prefix(50))
            ], merge: true)

            print("🔥 Sent message in \(channel.name)")
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    func editMessage(_ message: FirestoreMessage, newText: String) async {
        guard let messageID = message.id else { return }

        do {
            try await db.collection("messages").document(messageID).setData([
                "text": newText,
                "isEdited": true,
                "editedAt": FieldValue.serverTimestamp()
            ], merge: true)
            print("🔥 Edited message")
        } catch {
            errorMessage = "Failed to edit message: \(error.localizedDescription)"
        }
    }

    func deleteMessage(_ message: FirestoreMessage) async {
        guard let messageID = message.id else { return }

        do {
            try await db.collection("messages").document(messageID).delete()
            print("🔥 Deleted message")
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
        }
    }

    // MARK: - Presence

    func setOnlineStatus(_ isOnline: Bool) {
        guard let userID = userID else { return }

        db.collection("users").document(userID).setData([
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
