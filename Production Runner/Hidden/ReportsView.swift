import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ReportItem: Identifiable {
    let id = UUID()
    let name: String
    let user: String
    let date: Date
}

struct ReportsView: View {
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("account_name") private var accountName: String = ""
    let project: NSManagedObject
    let projectFileURL: URL?

    @State private var showingImporter = false
    @State private var submitted: [ReportItem] = []
    @State private var showingDownloadAlert = false
    @State private var showingDigitalReports = false
    @State private var downloadAlertMessage = ""

    init(project: NSManagedObject, projectFileURL: URL? = nil) {
        self.project = project
        self.projectFileURL = projectFileURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 12) {
                Button {
                    downloadReportTemplates()
                } label: {
                    Label("Download Templates", systemImage: "arrow.down.circle")
                }
                Button {
                    showingDigitalReports = true
                } label: {
                    Label("Digital Reports", systemImage: "doc.badge.ellipsis")
                }
                Button { showingImporter = true } label: { Label("Submit Report", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) {
                    if !submitted.isEmpty { submitted.removeLast() }
                } label: { Label("Remove Report", systemImage: "trash") }
            }

            Text("Submitted Reports").font(.headline).padding(.top, 4)

            List(submitted) { item in
                HStack {
                    Text(item.name).bold()
                    Spacer()
                    Text(item.user).foregroundColor(.secondary)
                    Text(formatted(item.date)).foregroundColor(.secondary)
                }
            }
            .frame(minHeight: 160)

            Spacer()
        }
        .padding()
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                // Add to Assets on submit
                do {
                    try AssetStore.addFile(at: url, to: project, projectFileURL: projectFileURL, in: moc)
                    submitted.insert(ReportItem(name: url.lastPathComponent, user: accountName.isEmpty ? "User" : accountName, date: Date()), at: 0)
                } catch {
                    // swallow for demo
                }
            }
        }
        .alert("Download Templates", isPresented: $showingDownloadAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadAlertMessage)
        }
        .sheet(isPresented: $showingDigitalReports) {
            DigitalReportsView()
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    // MARK: - Template Download

    private func downloadReportTemplates() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.zip]
        savePanel.nameFieldStringValue = "Production_Report_Templates.zip"
        savePanel.message = "Choose where to save the report templates"
        savePanel.prompt = "Download"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                Task {
                    await downloadTemplatesFile(to: url)
                }
            }
        }
        #else
        // iOS: Download to temp and share
        Task {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Production_Report_Templates.zip")
            await downloadTemplatesFile(to: tempURL)

            if FileManager.default.fileExists(atPath: tempURL.path) {
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(activityVC, animated: true)
                }
            }
        }
        #endif
    }

    private func downloadTemplatesFile(to destinationURL: URL) async {
        // Production report templates URL (could be hosted on Firebase Storage or GitHub)
        let templatesURL = "https://raw.githubusercontent.com/production-runner/templates/main/report-templates.zip"

        guard let url = URL(string: templatesURL) else {
            await MainActor.run {
                downloadAlertMessage = "Invalid template URL"
                showingDownloadAlert = true
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                await MainActor.run {
                    downloadAlertMessage = "Failed to download templates (server error)"
                    showingDownloadAlert = true
                }
                return
            }

            try data.write(to: destinationURL)

            await MainActor.run {
                downloadAlertMessage = "Templates downloaded successfully to:\n\(destinationURL.path)"
                showingDownloadAlert = true
                print("[Reports] Templates downloaded to: \(destinationURL.path)")
            }

        } catch {
            await MainActor.run {
                downloadAlertMessage = "Failed to download templates:\n\(error.localizedDescription)"
                showingDownloadAlert = true
                print("[Reports] Download error: \(error)")
            }
        }
    }
}

// MARK: - Digital Reports View

struct DigitalReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reports: [DigitalReport] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading reports...")
                } else if reports.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Digital Reports")
                            .font(.headline)
                        Text("Submit reports to see them here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(reports) { report in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.name)
                                .font(.headline)
                            HStack {
                                Text(report.type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatted(report.submittedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Digital Reports")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            #endif
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadDigitalReports()
        }
    }

    private func loadDigitalReports() {
        isLoading = true

        // In a real implementation, this would fetch from Firestore or backend
        // For now, simulate with placeholder data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Placeholder - in production, fetch from Firestore
            reports = []
            isLoading = false
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Digital Report Model

struct DigitalReport: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let submittedAt: Date
    let submittedBy: String
}
