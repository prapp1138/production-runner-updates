//
//  CallSheetDeliveryService.swift
//  Production Runner
//
//  Service for delivering call sheets via Email and SMS.
//  Coordinates between TwilioService for SMS and NSSharingService for Email.
//

import Foundation
import CoreData
import Combine

#if os(macOS)
import AppKit
#endif

// MARK: - Delivery Service

/// Service for sending call sheets to cast and crew
@MainActor
final class CallSheetDeliveryService: ObservableObject {

    // MARK: - Singleton

    static let shared = CallSheetDeliveryService()

    // MARK: - Published State

    @Published var currentDelivery: CallSheetDelivery?
    @Published var isSending: Bool = false
    @Published var sendingProgress: Double = 0.0
    @Published var currentRecipientName: String?
    @Published var lastError: String?

    // MARK: - Private Properties

    private let twilioService = TwilioService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {}

    // MARK: - Delivery Operations

    /// Send a call sheet to all recipients
    /// - Parameters:
    ///   - callSheet: The call sheet to send
    ///   - recipients: List of recipients with their delivery preferences
    ///   - pdfData: The generated PDF data
    ///   - pdfURL: Optional file URL for the PDF (for email attachments)
    /// - Returns: Updated delivery tracking object
    func sendCallSheet(
        _ callSheet: CallSheet,
        to recipients: [DeliveryRecipient],
        pdfData: Data,
        pdfURL: URL? = nil
    ) async throws -> CallSheetDelivery {
        guard !recipients.isEmpty else {
            throw DeliveryError.noRecipients
        }

        isSending = true
        sendingProgress = 0.0
        lastError = nil

        defer {
            isSending = false
            currentRecipientName = nil
        }

        // Create delivery tracking object
        var delivery = CallSheetDelivery(
            id: UUID(),
            callSheetID: callSheet.id,
            recipients: recipients.map { recipient in
                var updated = recipient
                updated.status = .pending
                updated.sentAt = nil
                updated.deliveredAt = nil
                updated.viewedAt = nil
                updated.confirmedAt = nil
                return updated
            },
            sentAt: Date()
        )

        currentDelivery = delivery

        // Process each recipient
        let totalRecipients = Double(delivery.recipients.count)

        for (index, recipient) in delivery.recipients.enumerated() {
            currentRecipientName = recipient.name

            do {
                var updatedRecipient = recipient
                updatedRecipient.status = .sending
                delivery.recipients[index] = updatedRecipient
                currentDelivery = delivery

                switch recipient.method {
                case .sms:
                    let sid = try await sendSMS(
                        to: recipient,
                        callSheet: callSheet,
                        pdfURL: pdfURL
                    )
                    updatedRecipient.twilioMessageSid = sid
                    updatedRecipient.status = .sent
                    updatedRecipient.sentAt = Date()

                case .email:
                    try await sendEmail(
                        to: recipient,
                        callSheet: callSheet,
                        pdfData: pdfData,
                        pdfURL: pdfURL
                    )
                    updatedRecipient.status = .sent
                    updatedRecipient.sentAt = Date()
                }

                delivery.recipients[index] = updatedRecipient

            } catch {
                var updatedRecipient = recipient
                updatedRecipient.status = .failed
                delivery.recipients[index] = updatedRecipient

                #if DEBUG
                print("CallSheetDeliveryService: Failed to send to \(recipient.name): \(error.localizedDescription)")
                #endif
            }

            sendingProgress = Double(index + 1) / totalRecipients
            currentDelivery = delivery
        }

        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .callSheetDeliveryStatusChanged,
            object: nil,
            userInfo: ["delivery": delivery]
        )

        return delivery
    }

    /// Resend to failed recipients
    func resendFailed(
        delivery: CallSheetDelivery,
        callSheet: CallSheet,
        pdfData: Data,
        pdfURL: URL? = nil
    ) async throws -> CallSheetDelivery {
        let failedRecipients = delivery.recipients.filter { $0.status == .failed }
        guard !failedRecipients.isEmpty else {
            throw DeliveryError.noFailedRecipients
        }

        // Create new delivery with only failed recipients
        var retryDelivery = delivery

        isSending = true
        sendingProgress = 0.0

        defer {
            isSending = false
            currentRecipientName = nil
        }

        let totalRecipients = Double(failedRecipients.count)
        var processedCount = 0

        for (index, recipient) in retryDelivery.recipients.enumerated() {
            guard recipient.status == .failed else { continue }

            currentRecipientName = recipient.name

            do {
                var updatedRecipient = recipient
                updatedRecipient.status = .sending
                retryDelivery.recipients[index] = updatedRecipient
                currentDelivery = retryDelivery

                switch recipient.method {
                case .sms:
                    let sid = try await sendSMS(
                        to: recipient,
                        callSheet: callSheet,
                        pdfURL: pdfURL
                    )
                    updatedRecipient.twilioMessageSid = sid
                    updatedRecipient.status = .sent
                    updatedRecipient.sentAt = Date()

                case .email:
                    try await sendEmail(
                        to: recipient,
                        callSheet: callSheet,
                        pdfData: pdfData,
                        pdfURL: pdfURL
                    )
                    updatedRecipient.status = .sent
                    updatedRecipient.sentAt = Date()
                }

                retryDelivery.recipients[index] = updatedRecipient

            } catch {
                // Keep as failed
                #if DEBUG
                print("CallSheetDeliveryService: Retry failed for \(recipient.name): \(error.localizedDescription)")
                #endif
            }

            processedCount += 1
            sendingProgress = Double(processedCount) / totalRecipients
            currentDelivery = retryDelivery
        }

        return retryDelivery
    }

    /// Check delivery status for SMS messages
    func refreshDeliveryStatus(_ delivery: CallSheetDelivery) async -> CallSheetDelivery {
        var updatedDelivery = delivery

        for (index, recipient) in delivery.recipients.enumerated() {
            // Only check SMS with a message SID that hasn't been delivered/viewed yet
            guard recipient.method == .sms,
                  let sid = recipient.twilioMessageSid,
                  recipient.status == .sent || recipient.status == .sending else {
                continue
            }

            do {
                let status = try await twilioService.checkStatus(messageSid: sid)
                var updatedRecipient = recipient
                updatedRecipient.status = status

                // Update timestamps based on status
                if status == .delivered && recipient.deliveredAt == nil {
                    updatedRecipient.deliveredAt = Date()
                } else if status == .viewed && recipient.viewedAt == nil {
                    updatedRecipient.viewedAt = Date()
                }

                updatedDelivery.recipients[index] = updatedRecipient

            } catch {
                #if DEBUG
                print("CallSheetDeliveryService: Failed to check status for \(recipient.name): \(error.localizedDescription)")
                #endif
            }
        }

        currentDelivery = updatedDelivery
        return updatedDelivery
    }

    // MARK: - Private Helpers

    /// Send SMS to a recipient
    private func sendSMS(
        to recipient: DeliveryRecipient,
        callSheet: CallSheet,
        pdfURL: URL?
    ) async throws -> String {
        guard let phone = recipient.phone, !phone.isEmpty else {
            throw DeliveryError.missingPhoneNumber
        }

        // Build message body
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var message = "📋 CALL SHEET - \(callSheet.title)\n"
        message += "📅 \(dateFormatter.string(from: callSheet.shootDate))\n"
        message += "Day \(callSheet.dayNumber) of \(callSheet.totalDays)\n\n"

        if let crewCall = callSheet.crewCall {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            message += "⏰ Crew Call: \(timeFormatter.string(from: crewCall))\n"
        }

        if !callSheet.shootingLocation.isEmpty {
            message += "📍 \(callSheet.shootingLocation)\n"
        }

        message += "\n- Production Runner"

        // Send via Twilio
        let sid = try await twilioService.sendSMS(
            to: phone,
            body: message,
            mediaUrl: pdfURL
        )

        return sid
    }

    /// Send email to a recipient
    private func sendEmail(
        to recipient: DeliveryRecipient,
        callSheet: CallSheet,
        pdfData: Data,
        pdfURL: URL?
    ) async throws {
        guard let email = recipient.email, !email.isEmpty else {
            throw DeliveryError.missingEmailAddress
        }

        #if os(macOS)
        // Use NSSharingService for email
        let sharingService = NSSharingService(named: .composeEmail)

        guard let service = sharingService else {
            throw DeliveryError.emailServiceUnavailable
        }

        // Build subject
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let subject = "Call Sheet - \(callSheet.title) - \(dateFormatter.string(from: callSheet.shootDate))"

        // Build body
        var body = "Please find attached the call sheet for \(callSheet.title).\n\n"
        body += "Shoot Date: \(dateFormatter.string(from: callSheet.shootDate))\n"
        body += "Day \(callSheet.dayNumber) of \(callSheet.totalDays)\n\n"

        if let crewCall = callSheet.crewCall {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            body += "Crew Call: \(timeFormatter.string(from: crewCall))\n"
        }

        if !callSheet.shootingLocation.isEmpty {
            body += "Location: \(callSheet.shootingLocation)\n"
        }

        body += "\n---\nSent via Production Runner"

        // Prepare items to share
        var items: [Any] = [body]

        // Add PDF as attachment
        if let url = pdfURL {
            items.append(url)
        } else {
            // Create temporary file for the PDF
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("CallSheet_\(callSheet.id.uuidString).pdf")
            try pdfData.write(to: tempURL)
            items.append(tempURL)
        }

        // Configure and perform
        service.recipients = [email]
        service.subject = subject

        // Perform on main thread
        await MainActor.run {
            if service.canPerform(withItems: items) {
                service.perform(withItems: items)
            }
        }
        #endif
    }

    // MARK: - Persistence

    /// Save delivery history to Core Data
    func saveDeliveryHistory(
        _ delivery: CallSheetDelivery,
        for callSheetID: UUID,
        in context: NSManagedObjectContext
    ) {
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "CallSheetEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", callSheetID as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                #if DEBUG
                print("CallSheetDeliveryService: Call sheet not found for saving delivery history")
                #endif
                return
            }

            // Encode delivery to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            if let deliveryData = try? encoder.encode(delivery),
               let jsonString = String(data: deliveryData, encoding: .utf8) {
                entity.setValue(jsonString, forKey: "deliveryHistoryJSON")
                entity.setValue(Date(), forKey: "lastSentDate")

                try context.save()

                #if DEBUG
                print("CallSheetDeliveryService: Saved delivery history for call sheet \(callSheetID)")
                #endif
            }
        } catch {
            #if DEBUG
            print("CallSheetDeliveryService: Failed to save delivery history: \(error)")
            #endif
        }
    }

    /// Load delivery history from Core Data
    func loadDeliveryHistory(
        for callSheetID: UUID,
        from context: NSManagedObjectContext
    ) -> CallSheetDelivery? {
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "CallSheetEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", callSheetID as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first,
                  let jsonString = entity.value(forKey: "deliveryHistoryJSON") as? String,
                  let data = jsonString.data(using: .utf8) else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            return try decoder.decode(CallSheetDelivery.self, from: data)

        } catch {
            #if DEBUG
            print("CallSheetDeliveryService: Failed to load delivery history: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Recipient Helpers

    /// Build recipients list from cast members and crew contacts
    func buildRecipientsList(
        castMembers: [CastMember],
        crewContacts: [CrewContact]? = nil,
        defaultMethod: DeliveryMethod = .email
    ) -> [DeliveryRecipient] {
        var recipients: [DeliveryRecipient] = []

        // Add cast members
        for cast in castMembers {
            let recipient = DeliveryRecipient(
                id: UUID(),
                name: cast.actorName,
                email: cast.email,
                phone: cast.phone,
                method: defaultMethod,
                status: .pending
            )
            recipients.append(recipient)
        }

        // Add crew contacts if provided
        if let crew = crewContacts {
            for contact in crew {
                let recipient = DeliveryRecipient(
                    id: UUID(),
                    name: contact.name,
                    email: contact.email,
                    phone: contact.phone,
                    method: defaultMethod,
                    status: .pending
                )
                recipients.append(recipient)
            }
        }

        return recipients
    }
}

// MARK: - Errors

enum DeliveryError: LocalizedError {
    case noRecipients
    case noFailedRecipients
    case missingPhoneNumber
    case missingEmailAddress
    case emailServiceUnavailable
    case pdfGenerationFailed

    var errorDescription: String? {
        switch self {
        case .noRecipients:
            return "No recipients selected for delivery."
        case .noFailedRecipients:
            return "No failed deliveries to retry."
        case .missingPhoneNumber:
            return "Recipient has no phone number for SMS delivery."
        case .missingEmailAddress:
            return "Recipient has no email address for email delivery."
        case .emailServiceUnavailable:
            return "Email service is not available on this device."
        case .pdfGenerationFailed:
            return "Failed to generate call sheet PDF."
        }
    }
}

// MARK: - Crew Contact (Simple struct for crew info)

struct CrewContact: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: String
    var email: String?
    var phone: String?

    init(id: UUID = UUID(), name: String, role: String, email: String? = nil, phone: String? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let callSheetDeliveryStatusChanged = Notification.Name("callSheetDeliveryStatusChanged")
}
