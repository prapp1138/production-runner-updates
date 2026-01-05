//
//  PDF_Import.swift
//  Production Runner
//
//  SwiftUI view for importing screenplay PDFs.
//  Mirrors the FDX_Import UI for consistency.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import PDFKit

// MARK: - PDF Import View

struct PDF_Import: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss

    @State private var isImporterPresented = false
    @State private var importLog: [String] = []
    @State private var isBusy = false
    @StateObject private var progressState = PDFImportProgressState()

    // Preview state
    @State private var previewDocument: PDFDocument? = nil
    @State private var previewSceneCount: Int = 0

    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PDF Importer")
                            .font(.largeTitle).bold()
                        Text("Import screenplay PDFs into your project scenes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Import button
                    Button(action: { isImporterPresented = true }) {
                        Label("Choose PDF", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                }

                Divider()

                // Info card
                infoCard

                Divider()

                // Log area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Log")
                        .font(.headline)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(importLog.indices, id: \.self) { i in
                                Text(importLog[i])
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(logColor(for: importLog[i]))
                            }
                        }
                        .padding(8)
                    }
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer(minLength: 0)
            }
            .padding()
            .blur(radius: progressState.isShowing ? 3 : 0)
            .allowsHitTesting(!progressState.isShowing)

            // Progress overlay
            if progressState.isShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                PDFImportProgressView(
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
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await performImport(url: url) }
            case .failure(let err):
                appendLog("❌ Importer error: \(err.localizedDescription)")
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF Import Notes")
                        .font(.headline)
                    Text("PDF parsing uses position-based analysis to identify screenplay elements. Results may vary depending on the PDF source.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Best: PDFs exported from Final Draft, Fade In, or Highland")
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Okay: Scanned PDFs may need OCR preprocessing")
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("For best results, import FDX files when available")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Import Logic

    private func performImport(url: URL) async {
        // Fetch project
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        fetch.fetchLimit = 1
        guard let project = try? moc.fetch(fetch).first else {
            appendLog("❌ No ProjectEntity found. Create a project first.")
            return
        }

        isBusy = true
        progressState.show(title: "Importing \(url.lastPathComponent)")

        defer {
            isBusy = false
            progressState.hide()
        }

        do {
            // Step 1: Cleanup
            progressState.update(
                status: "Removing existing scenes...",
                detail: "Cleaning up old data",
                progress: 0.05
            )
            appendLog("[PDF] Removing existing scenes, shots, and scheduler data...")

            try await Task.sleep(nanoseconds: 100_000_000)
            try PDFImportService.shared.deleteAllScenes(for: project, in: moc)

            progressState.update(
                status: "Cleanup complete",
                detail: "Old scenes removed",
                progress: 0.10
            )
            appendLog("[PDF] Cleanup complete.")

            // Step 2: Import with progress callback
            appendLog("[PDF] Starting import: \(url.lastPathComponent)")

            let drafts = try PDFImportService.shared.importPDF(
                from: url,
                into: moc,
                for: project,
                progressCallback: { progress in
                    Task { @MainActor in
                        progressState.update(
                            status: progress.message,
                            detail: progress.detail,
                            progress: progress.progress
                        )
                    }
                }
            )

            let totalScenes = drafts.count
            appendLog("[PDF] Parsed scenes: \(totalScenes)")

            // Log samples
            for i in drafts.prefix(3).indices {
                let d = drafts[i]
                appendLog(String(format: "[PDF] Sample[%d] #%@ :: %@ (pg=%@)",
                                i, d.numberString, String(d.headingText.prefix(40)), d.pageNumber ?? "—"))
            }

            // Final status
            progressState.update(
                status: "Import complete!",
                detail: "\(totalScenes) scenes ready",
                progress: 1.0
            )

            appendLog("✅ [PDF] Import complete and saved.")

            try await Task.sleep(nanoseconds: 500_000_000)

            // Notify completion
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
            appendLog("❌ [PDF] ERROR: \(error.localizedDescription)")

            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    // MARK: - Helpers

    private func appendLog(_ line: String) {
        withAnimation { importLog.append(line) }
    }

    private func logColor(for line: String) -> Color {
        if line.contains("❌") || line.contains("ERROR") {
            return .red
        } else if line.contains("⚠️") || line.contains("WARNING") {
            return .orange
        } else if line.contains("✅") {
            return .green
        }
        return .primary
    }
}

// MARK: - Progress State

@MainActor
final class PDFImportProgressState: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var title: String = "Importing PDF"
    @Published var statusMessage: String = "Preparing..."
    @Published var detailMessage: String = ""
    @Published var progress: Double = 0.0

    func reset() {
        isShowing = false
        title = "Importing PDF"
        statusMessage = "Preparing..."
        detailMessage = ""
        progress = 0.0
    }

    func show(title: String = "Importing PDF") {
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

// MARK: - Progress View

struct PDFImportProgressView: View {
    let title: String
    let statusMessage: String
    let progress: Double
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
            // Title bar
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

            // Content
            VStack(spacing: 16) {
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

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barBackgroundColor)
                            .frame(height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                            )

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [barFillColor, barFillColor.opacity(0.8), barFillColor],
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

// MARK: - Previews

#Preview {
    PDF_Import()
        .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
}

#Preview("Progress View") {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        PDFImportProgressView(
            title: "Importing Screenplay.pdf",
            statusMessage: "Processing scenes...",
            progress: 0.65,
            detailMessage: "Scene 12: INT. KITCHEN - DAY"
        )
    }
}
