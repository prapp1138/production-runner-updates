//
//  ScreenplayDraftPickerSheet.swift
//  Production Runner
//
//  Sheet for selecting a screenplay draft to load into Breakdowns.
//

import SwiftUI

/// Sheet that displays available screenplay drafts for selection
struct ScreenplayDraftPickerSheet: View {
    @ObservedObject private var dataManager = ScreenplayDataManager.shared
    @ObservedObject private var syncPrefManager = ScriptSyncPreferenceManager.shared
    let isLoading: Bool
    let onSelect: (ScreenplayDraftInfo) -> Void
    let onCancel: () -> Void

    @State private var selectedDraftId: UUID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Load Script from Screenplay")
                        .font(.headline)
                    Text("Select a draft to import into Breakdowns")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))

            Divider()

            // Content
            if dataManager.isLoading {
                Spacer()
                ProgressView("Loading drafts...")
                Spacer()
            } else if dataManager.drafts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Screenplays Found")
                        .font(.headline)
                    Text("Import a script in the Screenplay app first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(dataManager.drafts, selection: $selectedDraftId) { draft in
                    DraftRow(
                        draft: draft,
                        isSelected: selectedDraftId == draft.id,
                        syncMode: syncPrefManager.syncMode(for: draft.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDraftId = draft.id
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Load Script") {
                    if let id = selectedDraftId,
                       let draft = dataManager.drafts.first(where: { $0.id == id }) {
                        onSelect(draft)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedDraftId == nil || isLoading)
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        }
        .frame(width: 500, height: 400)
        .onAppear {
            // Auto-select the first draft if available
            if selectedDraftId == nil, let first = dataManager.drafts.first {
                selectedDraftId = first.id
            }
        }
    }
}

// MARK: - Draft Row

private struct DraftRow: View {
    let draft: ScreenplayDraftInfo
    let isSelected: Bool
    let syncMode: ScriptSyncMode

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(draft.title)
                        .font(.headline)
                        .lineLimit(1)

                    // Sync mode badge
                    syncModeBadge
                }

                HStack(spacing: 12) {
                    if let author = draft.author, !author.isEmpty {
                        Label(author, systemImage: "person")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Label("\(draft.sceneCount) scenes", systemImage: "film")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(draft.pageCount) pages", systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(draft.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(draft.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var syncModeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: syncMode.icon)
                .font(.system(size: 8, weight: .semibold))
            Text(syncMode == .autoSync ? "Auto" : "Manual")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(syncMode == .autoSync ? .green : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(syncMode == .autoSync ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
        )
    }
}

#Preview {
    ScreenplayDraftPickerSheet(
        isLoading: false,
        onSelect: { _ in },
        onCancel: {}
    )
}
