//
//  TwilioService.swift
//  Production Runner
//
//  Service for sending SMS messages via Twilio API.
//  Handles message sending and status tracking.
//

import Foundation
import Security

#if os(macOS)
import AppKit
#endif

// MARK: - Twilio Configuration

/// Configuration for Twilio API
struct TwilioConfig: Codable {
    var accountSid: String
    var authToken: String
    var fromNumber: String

    var isConfigured: Bool {
        !accountSid.isEmpty && !authToken.isEmpty && !fromNumber.isEmpty
    }
}

// MARK: - Twilio Service

/// Service for sending SMS via Twilio
@MainActor
final class TwilioService: ObservableObject {

    // MARK: - Singleton

    static let shared = TwilioService()

    // MARK: - Published State

    @Published var isConfigured: Bool = false
    @Published var isSending: Bool = false
    @Published var lastError: String?

    // MARK: - Private Properties

    private let keychainServiceName = "com.productionrunner.twilio"

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration

    /// Load configuration from Keychain
    private func loadConfiguration() {
        if let config = loadConfigFromKeychain() {
            isConfigured = config.isConfigured
        } else {
            isConfigured = false
        }
    }

    /// Get the current configuration
    func getConfig() -> TwilioConfig? {
        return loadConfigFromKeychain()
    }

    /// Save configuration to Keychain
    func saveConfig(_ config: TwilioConfig) throws {
        try saveConfigToKeychain(config)
        isConfigured = config.isConfigured
    }

    /// Clear configuration from Keychain
    func clearConfig() {
        deleteConfigFromKeychain()
        isConfigured = false
    }

    // MARK: - SMS Sending

    /// Send an SMS message
    /// - Parameters:
    ///   - to: Phone number to send to (E.164 format: +1XXXXXXXXXX)
    ///   - body: Message body text
    ///   - mediaUrl: Optional URL to media (e.g., PDF link)
    /// - Returns: Twilio message SID for tracking
    func sendSMS(to: String, body: String, mediaUrl: URL? = nil) async throws -> String {
        guard let config = loadConfigFromKeychain(), config.isConfigured else {
            throw TwilioError.notConfigured
        }

        isSending = true
        defer { isSending = false }

        // Twilio API endpoint
        let urlString = "https://api.twilio.com/2010-04-01/Accounts/\(config.accountSid)/Messages.json"
        guard let url = URL(string: urlString) else {
            throw TwilioError.invalidURL
        }

        // Build request body
        var bodyParams = [
            "To": formatPhoneNumber(to),
            "From": config.fromNumber,
            "Body": body
        ]

        if let mediaUrl = mediaUrl {
            bodyParams["MediaUrl"] = mediaUrl.absoluteString
        }

        let bodyString = bodyParams
            .map { "\($0.key)=\(percentEncode($0.value))" }
            .joined(separator: "&")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Basic auth
        let authString = "\(config.accountSid):\(config.authToken)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = bodyString.data(using: .utf8)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwilioError.invalidResponse
        }

        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            // Success - parse response for message SID
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = json["sid"] as? String {
                lastError = nil
                return sid
            }
            throw TwilioError.parseError
        } else {
            // Error - parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                lastError = message
                throw TwilioError.apiError(message)
            }
            lastError = "HTTP \(httpResponse.statusCode)"
            throw TwilioError.httpError(httpResponse.statusCode)
        }
    }

    /// Check the status of a message
    /// - Parameter messageSid: The Twilio message SID
    /// - Returns: The delivery status
    func checkStatus(messageSid: String) async throws -> DeliveryStatus {
        guard let config = loadConfigFromKeychain(), config.isConfigured else {
            throw TwilioError.notConfigured
        }

        let urlString = "https://api.twilio.com/2010-04-01/Accounts/\(config.accountSid)/Messages/\(messageSid).json"
        guard let url = URL(string: urlString) else {
            throw TwilioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Basic auth
        let authString = "\(config.accountSid):\(config.authToken)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw TwilioError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String else {
            throw TwilioError.parseError
        }

        return mapTwilioStatus(status)
    }

    /// Send a test SMS
    public func sendTestSMS(to: String) async throws -> Bool {
        let testMessage = "Test message from Production Runner. Your call sheet delivery is configured correctly!"
        let _ = try await sendSMS(to: to, body: testMessage)
        return true
    }

    // MARK: - Private Helpers

    private func formatPhoneNumber(_ phone: String) -> String {
        // Remove all non-numeric characters
        let digits = phone.filter { $0.isNumber }

        // If already in E.164 format with +, return as-is
        if phone.hasPrefix("+") {
            return phone
        }

        // Add +1 for US numbers if needed
        if digits.count == 10 {
            return "+1\(digits)"
        } else if digits.count == 11 && digits.hasPrefix("1") {
            return "+\(digits)"
        }

        // Return with + prefix
        return "+\(digits)"
    }

    private func percentEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    private func mapTwilioStatus(_ status: String) -> DeliveryStatus {
        switch status.lowercased() {
        case "queued", "accepted":
            return .sending
        case "sending":
            return .sending
        case "sent":
            return .sent
        case "delivered":
            return .delivered
        case "read":
            return .viewed
        case "failed", "undelivered":
            return .failed
        default:
            return .sent
        }
    }

    // MARK: - Keychain Storage

    private func saveConfigToKeychain(_ config: TwilioConfig) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        // Delete existing item first
        deleteConfigFromKeychain()

        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: "twilio_config",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TwilioError.keychainError(status)
        }
    }

    private func loadConfigFromKeychain() -> TwilioConfig? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: "twilio_config",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(TwilioConfig.self, from: data)
    }

    private func deleteConfigFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: "twilio_config"
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum TwilioError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case parseError
    case httpError(Int)
    case apiError(String)
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Twilio is not configured. Please add your API credentials in Settings."
        case .invalidURL:
            return "Invalid Twilio API URL."
        case .invalidResponse:
            return "Invalid response from Twilio API."
        case .parseError:
            return "Failed to parse Twilio API response."
        case .httpError(let code):
            return "HTTP error \(code) from Twilio API."
        case .apiError(let message):
            return "Twilio API error: \(message)"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}
