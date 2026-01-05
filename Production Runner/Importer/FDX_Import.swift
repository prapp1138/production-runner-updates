//
//  FDX_Import.swift
//  Production Runner
//
//  Standalone UI for importing Final Draft (.fdx) files.
//  Add this file to your target. It does not modify other UIs.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Classic macOS Import Progress View
struct ClassicImportProgressView: View {
    let title: String
    let statusMessage: String
    let progress: Double // 0.0 to 1.0
    let detailMessage: String

    @Environment(\.colorScheme) private var colorScheme

    private var barBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    private var barFillColor: Color {
        Color.accentColor
    }

    private var windowBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.94)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar area
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark
                    ? Color(white: 0.25)
                    : Color(white: 0.88)
            )

            Divider()

            // Content area
            VStack(spacing: 16) {
                // Icon and status
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text(detailMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.top, 4)

                // Classic progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barBackgroundColor)
                            .frame(height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                            )

                        // Fill bar with classic striped animation
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        barFillColor,
                                        barFillColor.opacity(0.8),
                                        barFillColor
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: max(0, geometry.size.width * progress - 4), height: 12)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                            .animation(.easeInOut(duration: 0.2), value: progress)
                    }
                }
                .frame(height: 16)

                // Percentage text
                HStack {
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 380)
        .background(windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Import Progress State
@MainActor
final class ImportProgressState: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var title: String = "Importing Script"
    @Published var statusMessage: String = "Preparing..."
    @Published var detailMessage: String = ""
    @Published var progress: Double = 0.0

    func reset() {
        isShowing = false
        title = "Importing Script"
        statusMessage = "Preparing..."
        detailMessage = ""
        progress = 0.0
    }

    func show(title: String = "Importing Script") {
        self.title = title
        self.isShowing = true
    }

    func update(status: String, detail: String = "", progress: Double) {
        self.statusMessage = status
        self.detailMessage = detail
        self.progress = min(1.0, max(0.0, progress))
    }

    func hide() {
        self.isShowing = false
    }
}

struct FDX_Import: View {
    @Environment(\.managedObjectContext) private var moc
    @State private var isImporterPresented = false
    @State private var importLog: [String] = []
    @State private var isBusy = false
    @StateObject private var progressState = ImportProgressState()
    @Environment(\.dismiss) private var dismiss

    /// Optional breakdown version ID to tag imported scenes with
    var breakdownVersionId: UUID? = nil
    /// Callback when import completes with the new version ID and scene count
    var onImportComplete: ((UUID, Int) -> Void)? = nil

    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 12) {
                Text("FDX Importer")
                    .font(.largeTitle).bold()

                Text("Import Final Draft (.fdx) files into Scenes without using Breakdowns UI.")
                    .font(.subheadline)

                HStack {
                    Button(action: { isImporterPresented = true }) {
                        Label("Choose .fdx File", systemImage: "doc.badge.plus")
                    }
                    .disabled(isBusy)
                    Spacer()
                }

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(importLog.indices, id: \.self) { i in
                            Text(importLog[i]).font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.vertical, 4)
                }
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 0)
            }
            .padding()
            .blur(radius: progressState.isShowing ? 3 : 0)
            .allowsHitTesting(!progressState.isShowing)

            // Progress overlay
            if progressState.isShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ClassicImportProgressView(
                    title: progressState.title,
                    statusMessage: progressState.statusMessage,
                    progress: progressState.progress,
                    detailMessage: progressState.detailMessage
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: progressState.isShowing)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType(filenameExtension: "fdx") ?? .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await performImport(url: url) }
            case .failure(let err):
                appendLog("Importer error: \(err.localizedDescription)")
            }
        }
    }

    private func performImport(url: URL) async {
        // Fetch a project from the current context
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        fetch.fetchLimit = 1
        guard let project = try? moc.fetch(fetch).first else {
            appendLog("No ProjectEntity found. Create a project first.")
            return
        }

        isBusy = true
        progressState.show(title: "Importing \(url.lastPathComponent)")

        defer {
            isBusy = false
            progressState.hide()
        }

        do {
            // Step 1: Cleanup (10%)
            progressState.update(
                status: "Removing existing scenes...",
                detail: "Cleaning up old data",
                progress: 0.05
            )
            appendLog("[FDX] Removing existing scenes, shots, and scheduler data...")

            try await Task.sleep(nanoseconds: 100_000_000) // Brief pause for UI
            try FDXImportService.shared.deleteAllScenes(for: project, in: moc)

            progressState.update(
                status: "Cleanup complete",
                detail: "Old scenes removed",
                progress: 0.15
            )
            appendLog("[FDX] Cleanup complete.")

            // Step 2: Reading file (25%)
            progressState.update(
                status: "Reading script file...",
                detail: url.lastPathComponent,
                progress: 0.20
            )
            appendLog("[FDX] Starting parse: \(url.lastPathComponent)")

            try await Task.sleep(nanoseconds: 100_000_000)

            // Step 3: Parsing XML (50%)
            progressState.update(
                status: "Parsing Final Draft XML...",
                detail: "Extracting scene data",
                progress: 0.35
            )

            try await Task.sleep(nanoseconds: 100_000_000)

            // Step 4: Import scenes with progress callback
            progressState.update(
                status: "Importing scenes...",
                detail: "Processing scene data",
                progress: 0.50
            )

            // Generate a new version ID if none provided
            let versionId = breakdownVersionId ?? UUID()
            let drafts = try FDXImportService.shared.importFDX(from: url, into: moc, for: project, breakdownVersionId: versionId)
            let totalScenes = drafts.count

            appendLog("[FDX] Parsed scenes: \(totalScenes) (version: \(versionId.uuidString.prefix(8))...)")

            // Simulate scene-by-scene progress for visual feedback
            for (index, draft) in drafts.prefix(min(10, totalScenes)).enumerated() {
                let sceneProgress = 0.50 + (Double(index + 1) / Double(min(10, totalScenes))) * 0.35
                progressState.update(
                    status: "Processing scenes...",
                    detail: "Scene \(draft.numberString.isEmpty ? "\(index + 1)" : draft.numberString): \(draft.headingText.prefix(30))...",
                    progress: sceneProgress
                )
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms per scene visual update
            }

            // Show samples in log
            for i in drafts.prefix(3).indices {
                let d = drafts[i]
                appendLog(String(format: "[FDX] Sample[%d] #%@ :: %@ (len=%@)", i, d.numberString, d.headingText, d.pageLength ?? "—"))
            }

            // Step 5: Finalizing (100%)
            progressState.update(
                status: "Finalizing import...",
                detail: "\(totalScenes) scenes imported successfully",
                progress: 0.95
            )

            try await Task.sleep(nanoseconds: 200_000_000)

            progressState.update(
                status: "Import complete!",
                detail: "\(totalScenes) scenes ready",
                progress: 1.0
            )

            appendLog("[FDX] Import complete and saved.")

            try await Task.sleep(nanoseconds: 500_000_000) // Show completion briefly

            // Notify parent with version ID and scene count for version management
            onImportComplete?(versionId, totalScenes)

            NotificationCenter.default.post(name: Notification.Name("breakdownsImportCompleted"), object: nil)
            await MainActor.run {
                dismiss()
            }
        } catch {
            progressState.update(
                status: "Import failed",
                detail: error.localizedDescription,
                progress: progressState.progress
            )
            appendLog("[FDX] ERROR: \(error.localizedDescription)")

            try? await Task.sleep(nanoseconds: 2_000_000_000) // Show error for 2 seconds
        }
    }

    private func appendLog(_ line: String) {
        withAnimation { importLog.append(line) }
    }
}

#Preview {
    FDX_Import()
        .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
}

#Preview("Progress View") {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        ClassicImportProgressView(
            title: "Importing Script.fdx",
            statusMessage: "Processing scenes...",
            progress: 0.65,
            detailMessage: "Scene 12: INT. KITCHEN - DAY"
        )
    }
}
