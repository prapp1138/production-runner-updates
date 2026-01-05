//
//  LoginView.swift
//  Production Runner
//
//  Email/password login screen with options for account creation and password reset.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showPasswordReset = false
    @State private var showError = false
    @State private var localErrorMessage = ""

    var body: some View {
        ZStack {
            // Background
            backgroundView

            VStack(spacing: 0) {
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)

                        // Branding Section
                        brandingSection

                        // Login Form
                        loginFormSection

                        // Footer Links
                        footerLinksSection

                        Spacer()
                            .frame(height: 40)
                    }
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 520)
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView()
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(localErrorMessage)
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        Color.black
    }

    // MARK: - Branding Section

    private var brandingSection: some View {
        VStack(spacing: 16) {
            // App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 16, x: 0, y: 8)

                Image(systemName: "film.stack")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Title
            Text("Production Runner")
                .font(.system(size: 24, weight: .bold))

            // Subtitle
            Text("Sign in to access your projects and team")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Login Form Section

    private var loginFormSection: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("your@email.com", text: $email)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                    .disableAutocorrection(true)
                    .help(Tooltips.Auth.emailField)
            }

            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField("Enter your password", text: $password)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    #if os(iOS)
                    .textContentType(.password)
                    #endif
                    .help(Tooltips.Auth.passwordField)
            }

            // Forgot Password - Centered
            Button("Forgot Password?") {
                showPasswordReset = true
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .buttonStyle(.plain)
            .help(Tooltips.Auth.forgotPasswordButton)
            .frame(maxWidth: .infinity)

            // Sign In Button
            Button(action: signIn) {
                HStack(spacing: 6) {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                    }
                    Text(authService.isLoading ? "Signing In..." : "Sign In")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(signInButtonBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(signInButtonBorder, lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.06),
                    radius: 4,
                    x: 0,
                    y: 1
                )
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid || authService.isLoading)
            .opacity((!isFormValid || authService.isLoading) ? 0.5 : 1.0)
            .help(Tooltips.Auth.signInButton)
        }
        .padding(24)
        .background(formBackground)
        .cornerRadius(16)
    }

    private var signInButtonBackground: Color {
        Color.accentColor
    }

    private var signInButtonBorder: Color {
        Color.accentColor
    }

    private var formBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.primary.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    // MARK: - Footer Links Section

    private var footerLinksSection: some View {
        VStack(spacing: 16) {
            // Divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 1)
                Text("New to Production Runner?")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 1)
            }

            // Create Account Button
            Button(action: { showSignUp = true }) {
                Text("Create an Account")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(light: Color(white: 0.1), dark: Color(white: 0.95)))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(light: .white, dark: Color(white: 0.15)))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(light: Color(white: 0.88), dark: Color(white: 0.25)), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.06),
                        radius: 4,
                        x: 0,
                        y: 1
                    )
            }
            .buttonStyle(.plain)
            .help(Tooltips.Auth.createAccountButton)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    // MARK: - Actions

    private func signIn() {
        Task {
            do {
                try await authService.signInWithEmail(email: email, password: password)
            } catch {
                localErrorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .frame(width: 420, height: 560)
    }
}
#endif
