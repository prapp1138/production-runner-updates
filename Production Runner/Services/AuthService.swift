//
//  AuthService.swift
//  Production Runner
//
//  Core authentication service for Firebase Auth integration.
//  Handles email/password authentication, account creation, and profile management.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Combine
import Network

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown          // Initial state, checking auth
    case unauthenticated  // No user signed in
    case authenticated    // User signed in with full account
}

// MARK: - Connection State

enum ConnectionState: Equatable {
    case unknown
    case connected
    case disconnected
}

// MARK: - Firestore User Profile

struct FirestoreUserProfile: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var displayName: String
    var email: String?
    var photoURL: String?
    var phone: String?
    var role: String?
    var userType: String
    var avatarColorHex: String
    var createdAt: Date
    var lastSeen: Date
    var isOnline: Bool
    var isEmailVerified: Bool

    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    init(
        id: String? = nil,
        displayName: String,
        email: String? = nil,
        photoURL: String? = nil,
        phone: String? = nil,
        role: String? = nil,
        userType: String = "Admin",
        avatarColorHex: String = "#007AFF",
        createdAt: Date = Date(),
        lastSeen: Date = Date(),
        isOnline: Bool = true,
        isEmailVerified: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.phone = phone
        self.role = role
        self.userType = userType
        self.avatarColorHex = avatarColorHex
        self.createdAt = createdAt
        self.lastSeen = lastSeen
        self.isOnline = isOnline
        self.isEmailVerified = isEmailVerified
    }
}

// MARK: - Auth Error

enum AuthServiceError: LocalizedError {
    case noInternet
    case invalidCredential
    case notAuthenticated
    case noEmail
    case weakPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No internet connection. Please check your connection and try again."
        case .invalidCredential:
            return "Invalid credentials provided."
        case .notAuthenticated:
            return "You are not signed in."
        case .noEmail:
            return "No email associated with this account."
        case .weakPassword:
            return "Password must be at least 8 characters."
        case .emailAlreadyInUse:
            return "An account with this email already exists. Try signing in."
        case .userNotFound:
            return "No account found with this email."
        case .wrongPassword:
            return "Incorrect email or password. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unknown(let message):
            return message
        }
    }

    static func from(_ error: Error) -> AuthServiceError {
        let nsError = error as NSError

        if let authError = AuthErrorCode(rawValue: nsError.code) {
            switch authError {
            case .invalidEmail, .invalidCredential:
                return .invalidCredential
            case .weakPassword:
                return .weakPassword
            case .emailAlreadyInUse:
                return .emailAlreadyInUse
            case .userNotFound:
                return .userNotFound
            case .wrongPassword:
                return .wrongPassword
            case .networkError:
                return .networkError
            default:
                return .unknown(error.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }
}

// MARK: - Auth Service

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    // Lazy initialization to avoid accessing Firestore before Firebase.configure()
    private lazy var db: Firestore = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    // Published State
    @Published var authState: AuthState = .unknown
    @Published var connectionState: ConnectionState = .unknown
    @Published var currentUser: FirestoreUserProfile?
    @Published var firebaseUser: User?
    @Published var isLoading = false
    @Published var statusMessage: String = "Initializing..."
    @Published var errorMessage: String?

    // Computed Properties
    var isAuthenticated: Bool {
        authState == .authenticated
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    var userID: String? {
        firebaseUser?.uid
    }

    // MARK: - Initialization

    private init() {
        startNetworkMonitoring()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status == .satisfied {
                    self?.connectionState = .connected
                } else {
                    self?.connectionState = .disconnected
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Initialize Auth (call after Firebase.configure())

    func initializeAuth() async {
        statusMessage = "Connecting..."

        // Wait for network connection (with timeout)
        let startTime = Date()
        while connectionState == .unknown {
            if Date().timeIntervalSince(startTime) > 10 {
                connectionState = .disconnected
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        guard connectionState == .connected else {
            errorMessage = AuthServiceError.noInternet.errorDescription
            return
        }

        statusMessage = "Checking authentication..."

        // Setup auth state listener
        setupAuthStateListener()

        // Wait for auth state to be determined
        let authStartTime = Date()
        while authState == .unknown {
            if Date().timeIntervalSince(authStartTime) > 10 {
                authState = .unauthenticated
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.handleAuthStateChange(user: user)
            }
        }
    }

    private func handleAuthStateChange(user: User?) async {
        self.firebaseUser = user

        if let user = user {
            statusMessage = "Signing in..."
            self.authState = .authenticated
            await fetchOrCreateUserProfile(firebaseUser: user)
        } else {
            self.authState = .unauthenticated
            self.currentUser = nil
        }
    }

    // MARK: - Sign In with Email/Password

    func signInWithEmail(email: String, password: String) async throws {
        guard connectionState == .connected else {
            throw AuthServiceError.noInternet
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("Signed in with email: \(result.user.uid)")
        } catch {
            let authError = AuthServiceError.from(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }

    // MARK: - Create Account

    func createAccount(email: String, password: String, displayName: String) async throws {
        guard connectionState == .connected else {
            throw AuthServiceError.noInternet
        }

        guard password.count >= 8 else {
            throw AuthServiceError.weakPassword
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Update display name on Firebase Auth profile
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            // Send email verification
            try await result.user.sendEmailVerification()

            print("Created account: \(result.user.uid)")
        } catch {
            let authError = AuthServiceError.from(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        guard connectionState == .connected else {
            throw AuthServiceError.noInternet
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("Password reset email sent to: \(email)")
        } catch {
            let authError = AuthServiceError.from(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        // Update online status before signing out
        if let userID = currentUser?.id {
            db.collection("users").document(userID).setData([
                "isOnline": false,
                "lastSeen": FieldValue.serverTimestamp()
            ], merge: true)
        }

        do {
            try Auth.auth().signOut()
            print("Signed out")
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Profile Management

    private func fetchOrCreateUserProfile(firebaseUser: User) async {
        let userRef = db.collection("users").document(firebaseUser.uid)

        do {
            let document = try await userRef.getDocument()

            if document.exists, let profile = try? document.data(as: FirestoreUserProfile.self) {
                // Update last seen and online status
                var updatedProfile = profile
                updatedProfile.lastSeen = Date()
                updatedProfile.isOnline = true
                updatedProfile.isEmailVerified = firebaseUser.isEmailVerified
                try userRef.setData(from: updatedProfile, merge: true)
                currentUser = updatedProfile
                print("Loaded existing user: \(profile.displayName)")
            } else {
                // Create new profile
                let newProfile = FirestoreUserProfile(
                    id: firebaseUser.uid,
                    displayName: firebaseUser.displayName ?? "User",
                    email: firebaseUser.email,
                    photoURL: firebaseUser.photoURL?.absoluteString,
                    userType: "Admin",
                    avatarColorHex: "#007AFF",
                    createdAt: Date(),
                    lastSeen: Date(),
                    isOnline: true,
                    isEmailVerified: firebaseUser.isEmailVerified
                )
                try userRef.setData(from: newProfile)
                currentUser = newProfile
                print("Created new user profile: \(newProfile.displayName)")
            }
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            print("Profile fetch error: \(error)")
        }
    }

    func updateUserProfile(_ profile: FirestoreUserProfile) async throws {
        guard let userID = profile.id else { return }

        try db.collection("users").document(userID).setData(from: profile, merge: true)
        currentUser = profile
    }

    // MARK: - Local Storage Sync

    func syncFromLocalStorage(
        name: String,
        email: String,
        phone: String,
        role: String,
        userType: String,
        avatarColorHex: String
    ) async throws {
        guard var profile = currentUser else { return }

        profile.displayName = name.isEmpty ? profile.displayName : name
        profile.phone = phone.isEmpty ? nil : phone
        profile.role = role.isEmpty ? nil : role
        profile.userType = userType
        profile.avatarColorHex = avatarColorHex

        try await updateUserProfile(profile)
    }

    func syncToLocalStorage() -> (name: String, email: String, phone: String, role: String, userType: String, avatarColorHex: String)? {
        guard let profile = currentUser else { return nil }

        return (
            name: profile.displayName,
            email: profile.email ?? "",
            phone: profile.phone ?? "",
            role: profile.role ?? "",
            userType: profile.userType,
            avatarColorHex: profile.avatarColorHex
        )
    }

    // MARK: - Retry Connection

    func retryConnection() async {
        errorMessage = nil
        await initializeAuth()
    }
}
