//
//  PasswordResetView.swift
//  Production Runner
//
//  Password reset form that sends a reset email to the user.
//

import SwiftUI

struct PasswordResetView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var showError = false
    @State private var localErrorMessage = ""
    @State private var emailSent = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)

                if emailSent {
                    successContent
                } else {
                    formContent
                }

                Spacer()
            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .frame(width: 380, height: 380)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(localErrorMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(Tooltips.Auth.closeButton)

            Spacer()

            Text("Reset Password")
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            // Spacer for symmetry
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "key.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }

            // Description
            VStack(spacing: 8) {
                Text("Forgot your password?")
                    .font(.system(size: 16, weight: .semibold))

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("your@email.com", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                    .disableAutocorrection(true)
                    .help(Tooltips.Auth.resetEmailField)
            }

            // Send Button
            Button(action: sendResetEmail) {
                HStack(spacing: 8) {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                    }
                    Text(authService.isLoading ? "Sending..." : "Send Reset Email")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(buttonBackground)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid || authService.isLoading)
            .help(Tooltips.Auth.sendResetButton)
        }
    }

    private var buttonBackground: some View {
        Group {
            if isFormValid && !authService.isLoading {
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.secondary.opacity(0.3)
            }
        }
    }

    // MARK: - Success Content

    private var successContent: some View {
        VStack(spacing: 24) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
            }

            // Success Message
            VStack(spacing: 8) {
                Text("Email Sent")
                    .font(.system(size: 16, weight: .semibold))

                Text("Check your inbox for a password reset link. It may take a few minutes to arrive.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Email Display
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(email)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(12)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            // Back to Login Button
            Button(action: { dismiss() }) {
                Text("Back to Sign In")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .help(Tooltips.Auth.backToSignInButton)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@")
    }

    // MARK: - Actions

    private func sendResetEmail() {
        Task {
            do {
                try await authService.sendPasswordReset(email: email)
                withAnimation {
                    emailSent = true
                }
            } catch {
                localErrorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PasswordResetView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordResetView()
    }
}
#endif
