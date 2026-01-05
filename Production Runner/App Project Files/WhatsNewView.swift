//
//  WhatsNewView.swift
//  Production Runner
//
//  What's New in Production Runner view
//  Shows version-specific updates and features
//

import SwiftUI

// MARK: - Version Release Model
struct VersionRelease: Identifiable, Hashable {
    let id = UUID()
    let version: String
    let date: String
    let features: [WhatsNewFeature]
    let isCurrentVersion: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(version)
    }

    static func == (lhs: VersionRelease, rhs: VersionRelease) -> Bool {
        lhs.version == rhs.version
    }
}

struct WhatsNewFeature: Hashable {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String? // "NEW", "IMPROVED", "FIXED"
}

// MARK: - Version History Data
struct VersionHistory {
    // Current version
    static let currentVersion = "1.0.0"

    // All version releases (newest first)
    static let releases: [VersionRelease] = [
        // Version 1.0.0 - Initial Release
        VersionRelease(
            version: "1.0.0",
            date: "January 2025",
            features: [
                WhatsNewFeature(
                    icon: "doc.text.magnifyingglass",
                    iconColor: .indigo,
                    title: "Screenplay Editor & FDX Import",
                    description: "Import Final Draft (FDX) files with full formatting preservation or write directly in the built-in screenplay editor. Track revisions with 9 industry-standard colors from White to Cherry.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "list.clipboard.fill",
                    iconColor: .orange,
                    title: "Script Breakdowns",
                    description: "Comprehensive scene breakdown system with color-coded elements: cast, props, wardrobe, vehicles, special effects, and more. Export breakdown sheets for department distribution.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "calendar.circle.fill",
                    iconColor: .cyan,
                    title: "Digital Stripboard Scheduler",
                    description: "Professional stripboard scheduling with drag-and-drop scene reordering, day breaks, page count tracking, and advanced filtering. Export one-liner schedules and production strips.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "doc.text.fill",
                    iconColor: .yellow,
                    title: "Professional Call Sheets",
                    description: "Generate industry-standard call sheets with comprehensive sections: cast calls, crew call, locations, weather, meals, and next-day preview. Export to PDF for distribution.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "dollarsign.circle.fill",
                    iconColor: .mint,
                    title: "Budget Management",
                    description: "Multi-version budgeting with line items, rate cards, variance tracking, and audit trails. Use standard templates or create custom budgets.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "person.2.fill",
                    iconColor: .purple,
                    title: "Contacts Database",
                    description: "Organize cast, crew, and vendors with department assignments and role tracking. Import from CSV, export to PDF. Contacts integrate seamlessly with breakdowns and call sheets.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "mappin.circle.fill",
                    iconColor: .teal,
                    title: "Location Management",
                    description: "Scout and manage shooting locations with Apple Maps integration, GPS coordinates, photo galleries, permit status tracking, and location contact information.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "video.fill",
                    iconColor: .red,
                    title: "Shot List & Storyboarding",
                    description: "Plan coverage with detailed shot lists organized by scene. Add storyboard frames and use the Top Down Shot Planner for blocking camera positions and actor movement.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "calendar",
                    iconColor: .green,
                    title: "Production Calendar",
                    description: "Visualize your production timeline with Month, Week, and Timeline views. Color-coded events for shoot days, prep, rehearsals, location scouts, and milestones.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "list.bullet.clipboard",
                    iconColor: .purple,
                    title: "Pre-Production Planning",
                    description: "Organize pre-production with four dedicated tabs: Ideas (concepts and notes), Casting (actor planning), Crew (department organization), and Visuals (mood boards and references).",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "checklist.checked",
                    iconColor: .pink,
                    title: "Task Management",
                    description: "Track production tasks with priorities, due dates, and reminders. Color-coded urgency indicators keep you on schedule. Tasks appear on the Dashboard for quick reference.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "paintpalette.fill",
                    iconColor: .blue,
                    title: "5 Visual Themes",
                    description: "Personalize your workspace with 5 distinct visual themes: Standard (minimal clean), Aqua (brushed metal), Retro (80s terminal), Neon (cyberpunk), and Cinema (Letterboxd-inspired).",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "doc.on.doc.fill",
                    iconColor: .indigo,
                    title: "Auto-Save & Project Packages",
                    description: "All changes auto-save every 10 seconds. Projects save as .runner package files containing all your production data in one portable file.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "questionmark.circle.fill",
                    iconColor: .blue,
                    title: "Comprehensive Help Documentation",
                    description: "In-depth help guide covering every feature with step-by-step instructions, workflow guidance, and pro tips. Access from Help menu (⌘?) anytime.",
                    badge: "NEW"
                )
            ],
            isCurrentVersion: true
        )

        // Future versions will be added above as releases occur
        // Example for next version:
        /*
        VersionRelease(
            version: "1.1.0",
            date: "February 2025",
            isCurrentVersion: false,
            features: [
                WhatsNewFeature(
                    icon: "waveform",
                    iconColor: .blue,
                    title: "Audio Import",
                    description: "Import and sync audio files with your script.",
                    badge: "NEW"
                ),
                WhatsNewFeature(
                    icon: "calendar.circle.fill",
                    iconColor: .cyan,
                    title: "Scheduler Performance",
                    description: "Faster drag-and-drop with improved rendering.",
                    badge: "IMPROVED"
                )
            ]
        ),
        */
    ]

    // Get features for current version
    static var currentVersionFeatures: [WhatsNewFeature] {
        releases.first(where: { $0.isCurrentVersion })?.features ?? []
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVersion: VersionRelease?
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    private var showVersionHistory: Bool {
        VersionHistory.releases.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("What's New in Production Runner")
                    .font(.system(size: 28, weight: .bold))

                Text("Version \(appVersion)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                // Version selector (if multiple versions exist)
                if showVersionHistory {
                    HStack(spacing: 8) {
                        Text("Show updates for:")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Picker("", selection: $selectedVersion) {
                            ForEach(VersionHistory.releases) { release in
                                Text("Version \(release.version)").tag(release as VersionRelease?)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.top, 48)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)

            // Features Grid - macOS style 2-column layout
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 24),
                    GridItem(.flexible(), spacing: 24)
                ], spacing: 28) {
                    ForEach(displayedFeatures.indices, id: \.self) { index in
                        let feature = displayedFeatures[index]
                        WhatsNewFeatureRow(
                            icon: feature.icon,
                            iconColor: feature.iconColor,
                            title: feature.title,
                            description: feature.description,
                            badge: feature.badge
                        )
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 32)
            }

            // Footer
            HStack {
                if showVersionHistory {
                    Button("View All Versions") {
                        // Show all versions in expanded view
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button("Continue") {
                    // Mark this version as seen
                    lastSeenVersion = VersionHistory.currentVersion
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Spacer()
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 24)
            .background(Color.primary.opacity(0.03))
        }
        .frame(minWidth: 700, idealWidth: 780, maxWidth: 900)
        .frame(minHeight: 580, idealHeight: 680, maxHeight: 800)
        .onAppear {
            // Default to current version
            if selectedVersion == nil {
                selectedVersion = VersionHistory.releases.first(where: { $0.isCurrentVersion })
            }
        }
    }

    // Features to display based on selected version
    private var displayedFeatures: [WhatsNewFeature] {
        selectedVersion?.features ?? VersionHistory.currentVersionFeatures
    }
}

struct WhatsNewFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var badge: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor(for: badge))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func badgeColor(for badge: String) -> Color {
        switch badge {
        case "NEW": return .green
        case "IMPROVED": return .blue
        case "FIXED": return .orange
        default: return .gray
        }
    }
}

#if DEBUG
struct WhatsNewView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewView()
    }
}
#endif
