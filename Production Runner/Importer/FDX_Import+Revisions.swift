//
//  FDX_Import+Revisions.swift
//  Production Runner
//
//  Enhanced FDX import with revision tracking
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct EnhancedFDXImport: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    
    @State private var isImporterPresented = false
    @State private var importLog: [String] = []
    @State private var isBusy = false
    
    // Revision metadata
    @State private var revisionName: String = ""
    @State private var selectedColor: ScriptRevisionEntity.RevisionColor = .white
    @State private var importedBy: String = NSFullUserName()
    @State private var createRevisionRecord: Bool = true
    
    // Suggestion state
    @State private var suggestedNextColor: ScriptRevisionEntity.RevisionColor?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Import Script")
                    .font(.largeTitle).bold()
                
                Text("Import a Final Draft (.fdx) file and track it as a script revision")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Revision Details Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Revision Details")
                    .font(.headline)
                
                // Revision name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Revision Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., Pink Revisions, Production Draft", text: $revisionName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Color picker
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Revision Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let suggested = suggestedNextColor {
                            Spacer()
                            Text("Suggested: \(suggested.rawValue)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Picker("Color", selection: $selectedColor) {
                        ForEach(ScriptRevisionEntity.RevisionColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(colorForRevision(color.rawValue))
                                    .frame(width: 12, height: 12)
                                Text(color.rawValue)
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Imported by
                VStack(alignment: .leading, spacing: 6) {
                    Text("Imported By")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Your name", text: $importedBy)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Create revision record toggle
                Toggle("Track as revision (recommended)", isOn: $createRevisionRecord)
                    .font(.caption)
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Import button
            Button(action: { isImporterPresented = true }) {
                HStack {
                    if isBusy {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "doc.badge.plus")
                    }
                    Text(isBusy ? "Importing..." : "Choose FDX File")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
            
            // Import log
            if !importLog.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Log")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(importLog.indices, id: \.self) { i in
                                Text(importLog[i])
                                    .font(.caption.monospaced())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(height: 120)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 600)
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
                appendLog("❌ Import error: \(err.localizedDescription)")
            }
        }
        .onAppear {
            loadSuggestedColor()
        }
    }
    
    // MARK: - Import Logic
    
    private func performImport(url: URL) async {
        // Fetch current project
        let fetch = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        fetch.fetchLimit = 1
        
        guard let project = try? moc.fetch(fetch).first else {
            appendLog("❌ No project found. Create a project first.")
            return
        }
        
        await MainActor.run { isBusy = true }
        defer { Task { @MainActor in isBusy = false } }
        
        do {
            appendLog("📄 Starting import: \(url.lastPathComponent)")
            
            let options = FDXImportService.RevisionImportOptions(
                revisionName: revisionName.isEmpty ? nil : revisionName,
                colorName: selectedColor.rawValue,
                importedBy: importedBy.isEmpty ? nil : importedBy,
                createRevisionRecord: createRevisionRecord
            )
            
            let revision = try FDXImportService.shared.importFDXWithRevisionTracking(
                from: url,
                into: moc,
                for: project,
                options: options
            )
            
            if let revision = revision {
                appendLog("✅ Created revision: \(revision.displayName)")
                appendLog("📊 Scenes: \(revision.sceneCount), Pages: \(revision.pageCount)")
                appendLog("📝 Changes: \(revision.changeSummary)")
            } else {
                appendLog("✅ Imported without revision record")
            }
            
            // Notify other views
            NotificationCenter.default.post(name: Notification.Name("breakdownsSceneOrderChanged"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("scriptRevisionImported"), object: revision)
            
            appendLog("✅ Import complete!")
            
            // Auto-dismiss after a delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await MainActor.run {
                dismiss()
            }
            
        } catch let error as FDXImportError {
            switch error {
            case .invalidData:
                appendLog("❌ Invalid FDX file")
            case .xmlParseFailed(let reason):
                appendLog("❌ Parse failed: \(reason)")
            case .missingProject:
                appendLog("❌ No project found")
            case .contextSaveFailed(let err):
                appendLog("❌ Save failed: \(err.localizedDescription)")
            }
        } catch {
            appendLog("❌ Unexpected error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func appendLog(_ line: String) {
        Task { @MainActor in
            withAnimation {
                importLog.append(line)
            }
        }
    }
    
    private func loadSuggestedColor() {
        Task {
            let fetch = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
            fetch.fetchLimit = 1
            
            guard let project = try? moc.fetch(fetch).first else { return }
            
            do {
                if let latest = try ScriptRevisionEntity.mostRecent(for: project, in: moc),
                   let currentColor = latest.revisionColor {
                    await MainActor.run {
                        suggestedNextColor = currentColor.next()
                        selectedColor = currentColor.next()
                    }
                }
            } catch {
                print("Failed to load suggested color: \(error)")
            }
        }
    }
    
    private func colorForRevision(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "white": return .white
        case "blue": return .blue
        case "pink": return .pink
        case "yellow": return .yellow
        case "green": return .green
        case "goldenrod": return .orange
        case "buff": return .brown
        case "salmon": return Color(red: 1.0, green: 0.5, blue: 0.4)
        case "cherry": return .red
        case "tan": return Color(red: 0.8, green: 0.7, blue: 0.6)
        case "gray": return .gray
        case "ivory": return Color(red: 1.0, green: 1.0, blue: 0.9)
        default: return .accentColor
        }
    }
}

#Preview {
    EnhancedFDXImport()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
