//
//  CallSheetDeliveryView.swift
//  Production Runner
//
//  View for sending call sheets to cast and crew via Email/SMS.
//  Displays recipient selection, delivery method options, and status tracking.
//

import SwiftUI
import CoreData

#if os(macOS)

// MARK: - Call Sheet Delivery View

struct CallSheetDeliveryView: View {
    let callSheet: CallSheet
    let pdfData: Data
    let onDismiss: () -> Void

    @StateObject private var deliveryService = CallSheetDeliveryService.shared
    @StateObject private var twilioService = TwilioService.shared

    @State private var recipients: [DeliveryRecipient] = []
    @State private var selectAll = true
    @State private var defaultMethod: DeliveryMethod = .email
    @State private var showTwilioSettings = false
    @State private var showConfirmation = false
    @State private var deliveryComplete = false
    @State private var currentDelivery: CallSheetDelivery?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            if deliveryService.isSending {
                // Sending Progress View
                sendingProgressView
            } else if deliveryComplete, let delivery = currentDelivery {
                // Delivery Results View
                deliveryResultsView(delivery: delivery)
            } else {
                // Recipient Selection View
                recipientSelectionView
            }
        }
        .frame(width: 600, height: 500)
        .background(CallSheetDesign.background)
        .onAppear {
            loadRecipients()
        }
        .sheet(isPresented: $showTwilioSettings) {
            TwilioSettingsView()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Send Call Sheet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CallSheetDesign.textPrimary)

                Text(callSheet.title)
                    .font(.system(size: 13))
                    .foregroundColor(CallSheetDesign.textSecondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(CallSheetDesign.cardBackground)
    }

    // MARK: - Recipient Selection

    private var recipientSelectionView: some View {
        VStack(spacing: 0) {
            // Options Bar
            HStack(spacing: 16) {
                // Select All Toggle
                Toggle(isOn: $selectAll) {
                    Text("Select All")
                        .font(.system(size: 13))
                }
                .toggleStyle(.checkbox)
                .onChange(of: selectAll) { newValue in
                    for index in recipients.indices {
                        recipients[index].isSelected = newValue
                    }
                }

                Spacer()

                // Default Method Picker
                HStack(spacing: 8) {
                    Text("Default:")
                        .font(.system(size: 12))
                        .foregroundColor(CallSheetDesign.textSecondary)

                    Picker("", selection: $defaultMethod) {
                        ForEach(DeliveryMethod.allCases) { method in
                            HStack(spacing: 4) {
                                Image(systemName: method.displayIcon)
                                Text(method.rawValue)
                            }
                            .tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .onChange(of: defaultMethod) { newMethod in
                        for index in recipients.indices {
                            recipients[index].method = newMethod
                        }
                    }
                }

                // Twilio Settings
                if !twilioService.isConfigured {
                    Button(action: { showTwilioSettings = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Setup SMS")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { showTwilioSettings = true }) {
                        Image(systemName: "gear")
                            .font(.system(size: 12))
                            .foregroundColor(CallSheetDesign.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("SMS Settings")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(CallSheetDesign.cardBackground.opacity(0.5))

            Divider()

            // Recipients List
            if recipients.isEmpty {
                emptyRecipientsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach($recipients) { $recipient in
                            RecipientRow(
                                recipient: $recipient,
                                twilioConfigured: twilioService.isConfigured
                            )
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // Footer with Send Button
            HStack {
                // Summary
                let selectedCount = recipients.filter(\.isSelected).count
                Text("\(selectedCount) of \(recipients.count) selected")
                    .font(.system(size: 12))
                    .foregroundColor(CallSheetDesign.textSecondary)

                Spacer()

                // Cancel Button
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundColor(CallSheetDesign.textSecondary)

                // Send Button
                Button(action: sendCallSheet) {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(selectedCount > 0 ? CallSheetDesign.accent : Color.gray)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(CallSheetDesign.cardBackground)
        }
    }

    private var emptyRecipientsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(CallSheetDesign.textTertiary)

            Text("No Recipients")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(CallSheetDesign.textSecondary)

            Text("Add cast members with contact info to send call sheets.")
                .font(.system(size: 13))
                .foregroundColor(CallSheetDesign.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Sending Progress

    private var sendingProgressView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Sending Call Sheet...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CallSheetDesign.textPrimary)

                if let name = deliveryService.currentRecipientName {
                    Text("Sending to \(name)")
                        .font(.system(size: 13))
                        .foregroundColor(CallSheetDesign.textSecondary)
                }
            }

            ProgressView(value: deliveryService.sendingProgress)
                .frame(width: 200)

            Text("\(Int(deliveryService.sendingProgress * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(CallSheetDesign.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Delivery Results

    private func deliveryResultsView(delivery: CallSheetDelivery) -> some View {
        VStack(spacing: 0) {
            // Summary Header
            HStack(spacing: 16) {
                let successCount = delivery.recipients.filter { $0.status == .sent || $0.status == .delivered }.count
                let failedCount = delivery.recipients.filter { $0.status == .failed }.count

                if failedCount == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                } else if successCount == 0 {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Delivery Complete")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(CallSheetDesign.textPrimary)

                    Text("\(successCount) sent, \(failedCount) failed")
                        .font(.system(size: 13))
                        .foregroundColor(CallSheetDesign.textSecondary)
                }

                Spacer()

                if failedCount > 0 {
                    Button(action: retryFailed) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Failed")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CallSheetDesign.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(CallSheetDesign.cardBackground)

            Divider()

            // Results List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(delivery.recipients) { recipient in
                        DeliveryResultRow(recipient: recipient)
                        Divider()
                            .padding(.leading, 60)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Done", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(CallSheetDesign.accent)
                    .cornerRadius(6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(CallSheetDesign.cardBackground)
        }
    }

    // MARK: - Actions

    private func loadRecipients() {
        // Build recipients from cast members
        recipients = callSheet.castMembers.compactMap { cast in
            // Only include if they have contact info
            guard !cast.email.isEmpty || !cast.phone.isEmpty else {
                return nil
            }

            return DeliveryRecipient(
                id: UUID(),
                name: cast.actorName,
                email: cast.email,
                phone: cast.phone,
                method: defaultMethod,
                status: .pending
            )
        }
    }

    private func sendCallSheet() {
        let selectedRecipients = recipients.filter(\.isSelected)
        guard !selectedRecipients.isEmpty else { return }

        Task {
            do {
                let delivery = try await deliveryService.sendCallSheet(
                    callSheet,
                    to: selectedRecipients,
                    pdfData: pdfData
                )
                currentDelivery = delivery
                deliveryComplete = true
            } catch {
                // Handle error
                #if DEBUG
                print("Delivery failed: \(error)")
                #endif
            }
        }
    }

    private func retryFailed() {
        guard let delivery = currentDelivery else { return }

        deliveryComplete = false

        Task {
            do {
                let updatedDelivery = try await deliveryService.resendFailed(
                    delivery: delivery,
                    callSheet: callSheet,
                    pdfData: pdfData
                )
                currentDelivery = updatedDelivery
                deliveryComplete = true
            } catch {
                deliveryComplete = true
            }
        }
    }
}

// MARK: - Recipient Row

struct RecipientRow: View {
    @Binding var recipient: DeliveryRecipient
    let twilioConfigured: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: $recipient.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            // Avatar
            Circle()
                .fill(CallSheetDesign.accent.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(recipient.name.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CallSheetDesign.accent)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(recipient.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CallSheetDesign.textPrimary)

                HStack(spacing: 8) {
                    if let email = recipient.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                            .font(.system(size: 11))
                            .foregroundColor(CallSheetDesign.textSecondary)
                    }
                    if let phone = recipient.phone, !phone.isEmpty {
                        Label(phone, systemImage: "phone")
                            .font(.system(size: 11))
                            .foregroundColor(CallSheetDesign.textSecondary)
                    }
                }
            }

            Spacer()

            // Method Picker
            Picker("", selection: $recipient.method) {
                ForEach(DeliveryMethod.allCases) { method in
                    HStack(spacing: 4) {
                        Image(systemName: method.displayIcon)
                        Text(method.rawValue)
                    }
                    .tag(method)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .disabled(recipient.method == .sms && !twilioConfigured)

            // Warning if SMS selected but no phone
            if recipient.method == .sms && (recipient.phone == nil || recipient.phone!.isEmpty) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .help("No phone number available")
            }

            // Warning if Email selected but no email
            if recipient.method == .email && (recipient.email == nil || recipient.email!.isEmpty) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .help("No email address available")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Delivery Result Row

struct DeliveryResultRow: View {
    let recipient: DeliveryRecipient

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            statusIcon
                .frame(width: 24)

            // Avatar
            Circle()
                .fill(CallSheetDesign.accent.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(recipient.name.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CallSheetDesign.accent)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(recipient.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CallSheetDesign.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: recipient.method.displayIcon)
                    Text(recipient.method.rawValue)
                    Text("•")
                    Text(recipient.status.displayName)
                }
                .font(.system(size: 11))
                .foregroundColor(statusColor)
            }

            Spacer()

            // Timestamp
            if let sentAt = recipient.sentAt {
                Text(sentAt, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(CallSheetDesign.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch recipient.status {
        case .sent, .delivered:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .viewed, .confirmed:
            Image(systemName: "eye.circle.fill")
                .foregroundColor(.blue)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .sending:
            ProgressView()
                .scaleEffect(0.6)
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.gray)
        }
    }

    private var statusColor: Color {
        switch recipient.status {
        case .sent, .delivered:
            return .green
        case .viewed, .confirmed:
            return .blue
        case .failed:
            return .red
        case .sending, .pending:
            return CallSheetDesign.textSecondary
        }
    }
}

// MARK: - Twilio Settings View

struct TwilioSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var twilioService = TwilioService.shared

    @State private var accountSid: String = ""
    @State private var authToken: String = ""
    @State private var fromNumber: String = ""
    @State private var testPhone: String = ""
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var showTestResult = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Twilio SMS Settings")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            Form {
                Section {
                    TextField("Account SID", text: $accountSid)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Auth Token", text: $authToken)
                        .textFieldStyle(.roundedBorder)

                    TextField("From Phone Number (+1...)", text: $fromNumber)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("API Credentials")
                } footer: {
                    Text("Get these from your Twilio Console at twilio.com/console")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Test") {
                    HStack {
                        TextField("Test Phone Number", text: $testPhone)
                            .textFieldStyle(.roundedBorder)

                        Button(action: sendTestSMS) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Send Test")
                            }
                        }
                        .disabled(testPhone.isEmpty || isTesting)
                    }

                    if showTestResult, let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 20)

            Divider()

            // Footer
            HStack {
                if twilioService.isConfigured {
                    Button("Clear Credentials", role: .destructive) {
                        twilioService.clearConfig()
                        accountSid = ""
                        authToken = ""
                        fromNumber = ""
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)

                Button("Save") {
                    saveConfig()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(accountSid.isEmpty || authToken.isEmpty || fromNumber.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 450, height: 450)
        .onAppear {
            loadConfig()
        }
    }

    private func loadConfig() {
        if let config = twilioService.getConfig() {
            accountSid = config.accountSid
            authToken = config.authToken
            fromNumber = config.fromNumber
        }
    }

    private func saveConfig() {
        let config = TwilioConfig(
            accountSid: accountSid,
            authToken: authToken,
            fromNumber: fromNumber
        )
        try? twilioService.saveConfig(config)
    }

    private func sendTestSMS() {
        isTesting = true
        testResult = nil
        showTestResult = false

        Task {
            do {
                // Save config first
                saveConfig()

                let _ = try await twilioService.sendTestSMS(to: testPhone)
                testResult = "Success! Test message sent."
            } catch {
                testResult = "Failed: \(error.localizedDescription)"
            }
            isTesting = false
            showTestResult = true
        }
    }
}

// MARK: - Extensions

extension DeliveryMethod {
    var displayIcon: String {
        switch self {
        case .email: return "envelope"
        case .sms: return "message"
        }
    }
}

extension DeliveryStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .sending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .viewed: return "Viewed"
        case .confirmed: return "Confirmed"
        case .failed: return "Failed"
        }
    }
}

#endif
