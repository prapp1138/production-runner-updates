import SwiftUI
import CoreData

struct NewProjectPrompt: View {
    @Environment(\.managedObjectContext) private var moc
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    var onCreated: (NSManagedObject) -> Void = { _ in }

    @AppStorage("account_name") private var accountName: String = ""

    @State private var projectName: String = ""
    @State private var user: String = ""
    @State private var status: ProjectStatus = .development
    @State private var errorMessage: String?
    @State private var showSavedBanner = false
    @State private var showErrorAlert = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Start New Project").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name").font(.caption).foregroundColor(.secondary)
                TextField("Enter a project name…", text: $projectName).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("User").font(.caption).foregroundColor(.secondary)
                TextField("", text: $user).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Status").font(.caption).foregroundColor(.secondary)
                Picker("Project Status", selection: $status) {
                    ForEach(ProjectStatus.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
            }
            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red).font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Create") { createProject() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { if user.isEmpty { user = accountName } }
        .padding()
        .frame(width: 380)
        .alert("Save Failed", isPresented: $showErrorAlert) { Button("OK", role: .cancel) {} }
            message: { Text(errorMessage ?? "Unknown error") }
        .overlay(alignment: .top) {
            if showSavedBanner {
                Text("Saved")
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.green.opacity(0.9))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .transition(.opacity)
            }
        }
    }

    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let created = store.create(
            name: trimmedName,
            user: user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : user,
            statusRaw: status.rawValue
        )

        guard let obj = created else {
            errorMessage = "Failed to save project."
            showErrorAlert = true
            return
        }

        showSavedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showSavedBanner = false
            isPresented = false
            onCreated(obj)
        }
    }
}
