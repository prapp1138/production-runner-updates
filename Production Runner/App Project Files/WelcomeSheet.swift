//
//  WelcomeSheet.swift
//  Production Runner
//
//  Welcome popup shown when a user first launches a project.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-platform color helper
private var welcomeWindowBackgroundColor: Color {
    #if os(macOS)
    Color(NSColor.windowBackgroundColor)
    #else
    Color(UIColor.systemBackground)
    #endif
}

struct WelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Store the project ID to track which projects have seen the welcome
    let projectID: String

    // State for the "Don't show again" checkbox
    @State private var dontShowAgain: Bool = false

    // Key for tracking welcome shown per project
    private var welcomeShownKey: String {
        "welcome_shown_\(projectID)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            headerSection

            // Content
            VStack(spacing: 12) {
                // App sections overview
                appSectionsOverview

                // Quick tips
                quickTipsSection

                // Keyboard shortcuts hint
                keyboardShortcutsHint
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Spacer(minLength: 0)

            // Footer with Get Started button
            footerSection
        }
        .frame(width: 600, height: 600)
        .background(welcomeWindowBackgroundColor)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)

                Image(systemName: "film.stack")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.top, 32)

            VStack(spacing: 8) {
                Text("Welcome to Production Runner")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Your all-in-one filmmaking companion")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - App Sections Overview

    private var appSectionsOverview: some View {
        EmptyView()
    }

    // MARK: - Quick Tips Section

    private var quickTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tips")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                TipRow(
                    icon: "sidebar.left",
                    text: "Use the sidebar to navigate between apps"
                )
                TipRow(
                    icon: "gearshape",
                    text: "Click the gear icon to customize project settings"
                )
                TipRow(
                    icon: "questionmark.circle",
                    text: "Hover over buttons to see helpful tooltips"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Keyboard Shortcuts Hint

    private var keyboardShortcutsHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text("Press ⌘? to view all available shortcuts")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                // Don't show again checkbox
                Button(action: {
                    dontShowAgain.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundStyle(dontShowAgain ? Color.accentColor : .secondary)

                        Text("Don't show again")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Get Started button
                Button(action: {
                    // Save preference if checkbox is checked
                    if dontShowAgain {
                        UserDefaults.standard.set(true, forKey: welcomeShownKey)
                    }
                    dismiss()
                }) {
                    Text("Get Started")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Tip Row

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Welcome Sheet Helper

extension View {
    /// Shows the welcome sheet if it hasn't been shown for this project yet
    func welcomeSheet(projectID: String, isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            WelcomeSheet(projectID: projectID)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WelcomeSheet_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeSheet(projectID: "preview-project")
    }
}
#endif
