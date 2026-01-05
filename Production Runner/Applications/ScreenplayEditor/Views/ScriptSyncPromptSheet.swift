//
//  ScriptSyncPromptSheet.swift
//  Production Runner
//
//  Popup dialog that prompts the user to choose how their script
//  should sync to other apps in Production Runner.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Script Sync Prompt Sheet

struct ScriptSyncPromptSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The draft ID this preference applies to
    let draftId: UUID

    /// The script title for display
    let scriptTitle: String

    /// Whether this is an import (vs. new script)
    let isImport: Bool

    /// Callback when user makes a choice
    let onChoice: (ScriptSyncMode) -> Void

    @State private var selectedMode: ScriptSyncMode = .autoSync
    @State private var rememberChoice = false
    @ObservedObject private var prefManager = ScriptSyncPreferenceManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Explanation
                    explanationView

                    // Options
                    optionsView

                    // Remember choice checkbox
                    rememberChoiceView
                }
                .padding(24)
            }

            Divider()

            // Footer with buttons
            footerView
        }
        .frame(width: 520, height: 480)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #endif
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)

                Image(systemName: "arrow.triangle.2.circlepath.doc.on.clipboard")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Script Sync Options")
                    .font(.system(size: 18, weight: .semibold))

                Text(isImport ? "How should \"\(scriptTitle)\" sync?" : "How should your new script sync?")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Explanation

    private var explanationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text("About Script Syncing")
                    .font(.system(size: 13, weight: .semibold))
            }

            Text("Production Runner can automatically keep your script in sync across all apps " +
                 "(Breakdowns, Scheduler, Shot Lists, etc.), or you can manually load it when you're ready.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Options

    private var optionsView: some View {
        VStack(spacing: 12) {
            ForEach(ScriptSyncMode.allCases, id: \.self) { mode in
                syncOptionCard(mode: mode)
            }
        }
    }

    private func syncOptionCard(mode: ScriptSyncMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedMode = mode
            }
        }) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(selectedMode == mode ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if selectedMode == mode {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                    }
                }

                // Icon
                Image(systemName: mode.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(selectedMode == mode ? .accentColor : .secondary)
                    .frame(width: 32)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(mode.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Recommended badge for auto-sync
                if mode == .autoSync {
                    Text("Recommended")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedMode == mode ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        selectedMode == mode ? Color.accentColor : Color.secondary.opacity(0.15),
                        lineWidth: selectedMode == mode ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Remember Choice

    private var rememberChoiceView: some View {
        HStack(spacing: 10) {
            Button(action: {
                rememberChoice.toggle()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: rememberChoice ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundColor(rememberChoice ? .accentColor : .secondary)

                    Text("Don't ask me again, use this setting for all new scripts")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 12) {
            // What apps will sync indicator
            HStack(spacing: 6) {
                Image(systemName: "app.connected.to.app.below.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("Syncs to: Breakdowns, Scheduler, Shot List, Design")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Cancel button (optional - user can dismiss)
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            // Confirm button
            Button(action: confirmChoice) {
                HStack(spacing: 6) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    // MARK: - Actions

    private func confirmChoice() {
        // Save the preference for this draft
        prefManager.setSyncMode(selectedMode, for: draftId)

        // If remember choice is checked, set as default and disable future prompts
        if rememberChoice {
            prefManager.defaultSyncMode = selectedMode.rawValue
            prefManager.askOnNewScript = false
        }

        // Notify the caller
        onChoice(selectedMode)

        // Dismiss
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ScriptSyncPromptSheet(
        draftId: UUID(),
        scriptTitle: "The Dark Knight",
        isImport: true,
        onChoice: { mode in
            print("Selected mode: \(mode)")
        }
    )
}

#Preview("New Script") {
    ScriptSyncPromptSheet(
        draftId: UUID(),
        scriptTitle: "Untitled Screenplay",
        isImport: false,
        onChoice: { mode in
            print("Selected mode: \(mode)")
        }
    )
}
