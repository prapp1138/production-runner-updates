// WelcomeView.swift
// A lightweight entry screen to Create/Open project files and switch stores.

import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#endif

struct WelcomeView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var colorScheme

    /// Called after a project is created or opened, so you can present main content.
    var onProjectReady: (() -> Void)? = nil

    @State private var status: String = ""
    @State private var isHoveringNew = false
    @State private var isHoveringOpen = false

    // Gradient colors - warm orange to cool blue
    private let gradientColors: [Color] = [
        Color(red: 1.0, green: 0.45, blue: 0.2),    // Warm orange
        Color(red: 0.95, green: 0.35, blue: 0.45),  // Coral/salmon
        Color(red: 0.7, green: 0.3, blue: 0.7),     // Purple transition
        Color(red: 0.3, green: 0.4, blue: 0.9),     // Blue
        Color(red: 0.2, green: 0.5, blue: 0.95)     // Bright blue
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            gradientBackground

            // Content overlay
            VStack(spacing: 0) {
                Spacer()

                // Main content card
                VStack(spacing: 32) {
                    // Logo and title
                    VStack(spacing: 16) {
                        // App icon or logo placeholder
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.orange.opacity(0.4), radius: 20, x: 0, y: 10)

                            Image(systemName: "film.stack")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 8) {
                            Text("Production Runner")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Professional Film Production Management")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    // Action buttons
                    HStack(spacing: 16) {
                        // New Project button
                        Button {
                            createNewProject()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("New Project")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Start fresh")
                                        .font(.system(size: 11))
                                        .opacity(0.7)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(isHoveringNew ? 0.25 : 0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .scaleEffect(isHoveringNew ? 1.02 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringNew)
                        .onHover { hovering in
                            isHoveringNew = hovering
                        }

                        // Open Project button
                        Button {
                            openExistingProject()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Open Project")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Continue working")
                                        .font(.system(size: 11))
                                        .opacity(0.7)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(isHoveringOpen ? 0.25 : 0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .scaleEffect(isHoveringOpen ? 1.02 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringOpen)
                        .onHover { hovering in
                            isHoveringOpen = hovering
                        }
                    }
                    .frame(maxWidth: 460)

                    // Status message
                    if !status.isEmpty {
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.2))
                            )
                    }
                }
                .padding(40)

                Spacer()

                // Footer
                VStack(spacing: 8) {
                    Text("Version 1.0")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Gradient Background

    private var gradientBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Overlay mesh gradient effect
            GeometryReader { geometry in
                ZStack {
                    // Top-left glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.6), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                        .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.2)

                    // Bottom-right glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.5), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.6
                            )
                        )
                        .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.3)

                    // Center accent
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.4
                            )
                        )
                        .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.4)
                        .offset(x: 0, y: geometry.size.height * 0.1)
                }
            }

            // Noise texture overlay for depth
            Rectangle()
                .fill(Color.white.opacity(0.02))
        }
        .ignoresSafeArea()
    }

    private func createNewProject() {
        #if os(macOS)
        guard let folderURL = promptForNewProjectFolder() else { return }
        do {
            let pkg = try ProjectFileManager.createProject(named: folderURL.deletingPathExtension().lastPathComponent, in: folderURL)
            status = "Created project at: \(pkg.path)"
            onProjectReady?()
        } catch {
            status = "Error creating project: \(error.localizedDescription)"
        }
        #else
        status = "Create project is only wired on macOS in this sample."
        #endif
    }

    private func openExistingProject() {
        #if os(macOS)
        guard let url = promptToOpenProject() else { return }
        do {
            let pkg = try ProjectFileManager.normalizePackageURL(url)
            status = "Opened project at: \(pkg.path)"
            onProjectReady?()
        } catch {
            status = "Error opening project: \(error.localizedDescription)"
        }
        #else
        status = "Open project is only wired on macOS in this sample."
        #endif
    }
}

private struct StoreInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Store")
                .font(.headline)
            Text(activeStorePath())
                .font(.footnote)
                .textSelection(.enabled)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func activeStorePath() -> String {
        // Try to discover current store URL for display/debug
        for store in PersistenceController.shared.container.persistentStoreCoordinator.persistentStores {
            if let url = store.url { return url.path }
        }
        return "Unknown"
    }
}

#if os(macOS)
@discardableResult
private func promptForNewProjectFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.title = "Choose a folder for your new project"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose"
    return panel.runModal() == .OK ? panel.urls.first : nil
}

@discardableResult
private func promptToOpenProject() -> URL? {
    let panel = NSOpenPanel()
    panel.title = "Open Production Runner Project"
    panel.canChooseFiles = true
    panel.canChooseDirectories = true // allow packages/folders if project is a package
    panel.allowsMultipleSelection = false
    panel.prompt = "Open"
    // If you have a custom UTType for projects, you can restrict here via allowedContentTypes
    return panel.runModal() == .OK ? panel.urls.first : nil
}
#endif

// MARK: - Preview

#if DEBUG
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
#endif
