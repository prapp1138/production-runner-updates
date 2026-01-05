//
//  AppSettings.swift
//  Production Runner
//
//  Created by Editing on 11/24/25.
//

import SwiftUI

/// App-level settings window (not project-specific)
struct AppSettingsView: View {
    @AppStorage("app_auto_update") private var autoUpdate: Bool = true
    @AppStorage("app_appearance") private var appAppearance: String = "system"
    @AppStorage("app_theme") private var appTheme: String = "Standard"
    @AppStorage("app_custom_accent_enabled") private var customAccentEnabled: Bool = false
    @AppStorage("app_custom_accent_color") private var customAccentHex: String = ""
    @AppStorage("app_ai_integration") private var aiIntegration: Bool = false
    @AppStorage("app_ai_provider") private var aiProvider: String = "openai"
    @AppStorage("app_telemetry") private var telemetryEnabled: Bool = true

    @State private var showNotificationSettings = false

    @Environment(\.dismiss) private var dismiss
    @State private var customAccentColor: Color = .accentColor

    private let themes = ["System", "Light", "Dark"]
    private let aiProviders = ["OpenAI", "Anthropic", "Local"]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private func loadCustomColor() {
        if !customAccentHex.isEmpty, let color = Color(hex: customAccentHex) {
            customAccentColor = color
        } else {
            // Default to current theme's accent color
            customAccentColor = AppAppearance.Theme(rawValue: appTheme)?.accentColor ?? .accentColor
        }
    }

    private func saveCustomColor(_ color: Color) {
        customAccentHex = color.toHex() ?? ""
        NotificationCenter.default.post(name: Notification.Name("AppAccentColorDidChange"), object: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // General Settings
                    SettingsSection(title: "General", icon: "gearshape") {
                        SettingRow(
                            title: "Auto Update App",
                            description: "Automatically download and install app updates",
                            icon: "arrow.triangle.2.circlepath.circle.fill"
                        ) {
                            Toggle("", isOn: $autoUpdate)
                                .labelsHidden()
                        }

                        SettingRow(
                            title: "Send Telemetry Data",
                            description: "Help improve Production Runner by sharing anonymous usage data",
                            icon: "chart.line.uptrend.xyaxis.circle.fill"
                        ) {
                            Toggle("", isOn: $telemetryEnabled)
                                .labelsHidden()
                        }

                        SettingRow(
                            title: "Notification Settings",
                            description: "Configure which notifications you want to receive",
                            icon: "bell.circle.fill"
                        ) {
                            Button("Configure") {
                                showNotificationSettings = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    // Appearance
                    SettingsSection(title: "Appearance", icon: "paintbrush") {
                        SettingRow(
                            title: "Appearance",
                            description: "Choose your preferred color scheme",
                            icon: "moon.circle.fill"
                        ) {
                            Picker("", selection: $appAppearance) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                            .onChange(of: appAppearance) { newValue in
                                AppAppearance.apply(newValue)
                            }
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        // Custom Accent Color
                        SettingRow(
                            title: "Custom Accent Color",
                            description: "Override theme with your own accent color",
                            icon: "eyedropper.halffull"
                        ) {
                            HStack(spacing: 12) {
                                if customAccentEnabled {
                                    ColorPicker("", selection: $customAccentColor, supportsOpacity: false)
                                        .labelsHidden()
                                        .onChange(of: customAccentColor) { newColor in
                                            saveCustomColor(newColor)
                                        }
                                }
                                Toggle("", isOn: $customAccentEnabled)
                                    .labelsHidden()
                                    .onChange(of: customAccentEnabled) { enabled in
                                        if enabled {
                                            loadCustomColor()
                                            saveCustomColor(customAccentColor)
                                        } else {
                                            // Revert to theme color
                                            AppAppearance.applyTheme(appTheme)
                                        }
                                        NotificationCenter.default.post(name: Notification.Name("AppAccentColorDidChange"), object: nil)
                                    }
                            }
                        }

                        // Custom color preview when enabled
                        if customAccentEnabled {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(customAccentColor)
                                    .frame(width: 60, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary, lineWidth: 2)
                                    )
                                    .shadow(color: customAccentColor.opacity(0.4), radius: 4, y: 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Custom Color")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(customAccentHex.isEmpty ? "Select a color" : customAccentHex.uppercased())
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Reset to Theme") {
                                    let themeColor = AppAppearance.Theme(rawValue: appTheme)?.accentColor ?? .accentColor
                                    customAccentColor = themeColor
                                    saveCustomColor(themeColor)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }

                    // AI Integration
                    SettingsSection(title: "AI Integration", icon: "brain") {
                        SettingRow(
                            title: "Enable AI Features",
                            description: "Use AI to help with script breakdowns, scheduling, and more",
                            icon: "sparkles.rectangle.stack.fill"
                        ) {
                            Toggle("", isOn: $aiIntegration)
                                .labelsHidden()
                        }

                        if aiIntegration {
                            SettingRow(
                                title: "AI Provider",
                                description: "Choose your preferred AI service provider",
                                icon: "server.rack"
                            ) {
                                Picker("", selection: $aiProvider) {
                                    Text("OpenAI").tag("openai")
                                    Text("Anthropic").tag("anthropic")
                                    Text("Local Model").tag("local")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 150)
                            }
                        }
                    }

                    // About
                    SettingsSection(title: "About", icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Version")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(appVersion)
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("Build")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(appBuild)
                                    .fontWeight(.medium)
                            }

                            Divider()

                            Button {
                                #if os(macOS)
                                NSWorkspace.shared.open(URL(string: "https://productionrunner.app")!)
                                #endif
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Visit Website")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ModernSecondaryButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 600)
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 56, height: 56)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("App Settings")
                    .font(.title.bold())
                Text("Preferences and configuration for Production Runner")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.primary.opacity(0.03))
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.blue.gradient)
                Text(title)
                    .font(.title3.bold())
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Setting Row
struct SettingRow<Control: View>: View {
    let title: String
    let description: String
    let icon: String
    let control: Control

    init(
        title: String,
        description: String,
        icon: String,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// Note: Color hex extensions (init?(hex:) and toHex()) are defined in LocationsView.swift
