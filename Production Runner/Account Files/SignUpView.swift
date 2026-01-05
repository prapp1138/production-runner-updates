//
//  SignUpView.swift
//  Production Runner
//
//  Account creation form with email, password, and display name fields.
//

import SwiftUI

struct SignUpView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var localErrorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Info Banner
                    infoBanner

                    // Form Fields
                    formSection

                    // Create Account Button
                    createAccountButton

                    // Validation Messages
                    validationMessages
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .frame(width: 400, height: 560)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(localErrorMessage)
        }
        .alert("Account Created", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your account has been created. Please check your email to verify your address, then sign in.")
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

            Text("Create Account")
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

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Email Verification Required")
                    .font(.system(size: 13, weight: .semibold))
                Text("A verification email will be sent to confirm your address.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 20) {
            // Display Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Your name", text: $displayName)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    #endif
                    .help(Tooltips.Auth.displayNameField)
            }

            // Email
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
                    .help(Tooltips.Auth.emailField)
            }

            // Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField("Minimum 8 characters", text: $password)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textContentType(.newPassword)
                    #endif
                    .help(Tooltips.Auth.passwordField)

                // Password strength indicator
                if !password.isEmpty {
                    passwordStrengthView
                }
            }

            // Confirm Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField("Re-enter password", text: $confirmPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textContentType(.newPassword)
                    #endif
                    .help(Tooltips.Auth.confirmPasswordField)
            }
        }
    }

    // MARK: - Password Strength View

    private var passwordStrengthView: some View {
        HStack(spacing: 8) {
            // Strength bars
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(strengthColor(for: index))
                    .frame(height: 4)
            }

            Text(strengthText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(strengthTextColor)
        }
    }

    private var passwordStrength: Int {
        var strength = 0
        if password.count >= 8 { strength += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { strength += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { strength += 1 }
        if password.rangeOfCharacter(from: .punctuationCharacters) != nil ||
           password.rangeOfCharacter(from: .symbols) != nil { strength += 1 }
        return strength
    }

    private func strengthColor(for index: Int) -> Color {
        if index < passwordStrength {
            switch passwordStrength {
            case 1: return .red
            case 2: return .orange
            case 3: return .yellow
            case 4: return .green
            default: return .clear
            }
        }
        return Color.primary.opacity(0.1)
    }

    private var strengthText: String {
        switch passwordStrength {
        case 0: return ""
        case 1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Strong"
        default: return ""
        }
    }

    private var strengthTextColor: Color {
        switch passwordStrength {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .secondary
        }
    }

    // MARK: - Create Account Button

    private var createAccountButton: some View {
        Button(action: createAccount) {
            HStack(spacing: 8) {
                if authService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                }
                Text(authService.isLoading ? "Creating Account..." : "Create Account")
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
        .help(Tooltips.Auth.createAccountSubmit)
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

    // MARK: - Validation Messages

    private var validationMessages: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !password.isEmpty && password.count < 8 {
                validationRow(icon: "xmark.circle.fill", color: .red, text: "Password must be at least 8 characters")
            }

            if !confirmPassword.isEmpty && password != confirmPassword {
                validationRow(icon: "xmark.circle.fill", color: .red, text: "Passwords do not match")
            }

            if !email.isEmpty && !email.contains("@") {
                validationRow(icon: "xmark.circle.fill", color: .red, text: "Please enter a valid email address")
            }
        }
    }

    private func validationRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
    }

    // MARK: - Actions

    private func createAccount() {
        Task {
            do {
                try await authService.createAccount(
                    email: email,
                    password: password,
                    displayName: displayName
                )
                showSuccess = true
            } catch {
                localErrorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}
#endif
