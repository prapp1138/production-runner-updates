//
//  FirstLaunchTutorial.swift
//  Production Runner
//
//  Tutorial shown at first launch to guide users through app basics
//

import SwiftUI

// MARK: - Tutorial Step Model
struct TutorialStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let actionText: String?

    init(icon: String, title: String, description: String, actionText: String? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionText = actionText
    }
}

// MARK: - Tutorial Steps Data
struct TutorialData {
    static let steps: [TutorialStep] = [
        TutorialStep(
            icon: "star.fill",
            title: "Welcome to Production Runner",
            description: "Production Runner is your complete film and video production management solution. From script to screen, manage every aspect of your production in one integrated platform.",
            actionText: nil
        ),
        TutorialStep(
            icon: "doc.text.magnifyingglass",
            title: "Step 1: Import or Write Your Script",
            description: "Start by navigating to the Screenplay app. You can either import a Final Draft (FDX) file to preserve professional formatting, or write directly in Production Runner's built-in screenplay editor. Your script is the foundation - all scenes, breakdowns, and schedules flow from here.",
            actionText: "Screenplay app → Import FDX or start writing"
        ),
        TutorialStep(
            icon: "list.clipboard.fill",
            title: "Step 2: Break Down Your Scenes",
            description: "Once your script is ready, go to the Breakdowns app. Each scene heading automatically becomes a scene to break down. Add cast members, props, wardrobe, special effects, and all production elements needed for each scene. Thorough breakdowns ensure nothing is missed on shoot days.",
            actionText: "Breakdowns app → Add elements to each scene"
        ),
        TutorialStep(
            icon: "person.2.fill",
            title: "Step 3: Build Your Contacts",
            description: "Head to the Contacts app to add your cast and crew. Organize contacts by category (Cast, Crew, Vendors) and assign departments. Add phone numbers, emails, and role information. These contacts integrate with breakdowns, schedules, and call sheets automatically.",
            actionText: "Contacts app → Add cast and crew members"
        ),
        TutorialStep(
            icon: "mappin.circle.fill",
            title: "Step 4: Scout and Add Locations",
            description: "Use the Locations app to manage shooting locations. Add addresses, GPS coordinates, contact information, permit status, and location photos. Each location you create can be assigned to scenes in your breakdown and schedule.",
            actionText: "Locations app → Add shooting locations"
        ),
        TutorialStep(
            icon: "calendar.circle.fill",
            title: "Step 5: Build Your Shooting Schedule",
            description: "In the Scheduler app, create your stripboard shooting schedule. Drag and drop scene strips to organize by location, cast availability, and production efficiency. Insert Day Breaks between shooting days. The scheduler automatically pulls all breakdown data - cast, locations, and page counts.",
            actionText: "Scheduler app → Drag scenes into shooting order"
        ),
        TutorialStep(
            icon: "doc.text.fill",
            title: "Step 6: Generate Call Sheets",
            description: "Use the Call Sheets app to create professional daily production documents. Select a shoot day, and Production Runner auto-populates scenes, cast, and locations from your schedule. Add crew call times, meals, weather, and production notes. Export as PDF for distribution.",
            actionText: "Call Sheets app → Create and export call sheets"
        ),
        TutorialStep(
            icon: "dollarsign.circle.fill",
            title: "Track Your Budget",
            description: "The Budgeting app helps you manage production finances. Create budget line items with categories, rates, and quantities. Track actual spending against budgeted amounts. Use templates for standardized budgets across multiple projects.",
            actionText: "Budgeting app → Build your production budget"
        ),
        TutorialStep(
            icon: "checkmark.circle.fill",
            title: "You're Ready to Go!",
            description: "You now know the core Production Runner workflow: Script → Breakdowns → Schedule → Call Sheets. Explore other apps like Shot List, Calendar, Plan, and Tasks as your production evolves. Check the Help menu anytime for detailed guidance on each feature.",
            actionText: "Press Done to start your production"
        )
    ]
}

// MARK: - First Launch Tutorial View
struct FirstLaunchTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @AppStorage("hasSeenFirstLaunchTutorial") private var hasSeenTutorial = false

    private var isLastStep: Bool {
        currentStep == TutorialData.steps.count - 1
    }

    private var currentTutorialStep: TutorialStep {
        TutorialData.steps[currentStep]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress indicator
            VStack(spacing: 16) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<TutorialData.steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 24)

                // Step counter
                Text("Step \(currentStep + 1) of \(TutorialData.steps.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 32) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: currentTutorialStep.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 32)

                    // Title
                    Text(currentTutorialStep.title)
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)

                    // Description
                    Text(currentTutorialStep.description)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)

                    // Action text (if available)
                    if let actionText = currentTutorialStep.actionText {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.accentColor)
                            Text(actionText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.bottom, 40)
            }

            Divider()

            // Navigation buttons
            HStack(spacing: 16) {
                // Skip button (first steps only)
                if !isLastStep {
                    Button(action: {
                        hasSeenTutorial = true
                        dismiss()
                    }) {
                        Text("Skip Tutorial")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Previous button
                if currentStep > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            currentStep -= 1
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Previous")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }

                // Next/Done button
                Button(action: {
                    if isLastStep {
                        hasSeenTutorial = true
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            currentStep += 1
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(isLastStep ? "Done" : "Next")
                            .font(.system(size: 14, weight: .semibold))
                        if !isLastStep {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(width: 700, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Compact Tutorial Sheet (Alternative simpler version)
struct QuickStartGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenQuickStart") private var hasSeenQuickStart = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Start Guide")
                        .font(.system(size: 24, weight: .bold))
                    Text("Get started with Production Runner in 6 easy steps")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") {
                    hasSeenQuickStart = true
                    dismiss()
                }
                .buttonStyle(.borderless)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    QuickStartStep(number: 1, icon: "doc.text.magnifyingglass", title: "Import or Write Your Script", description: "Go to Screenplay → Import FDX file or write directly in the editor")

                    QuickStartStep(number: 2, icon: "list.clipboard.fill", title: "Break Down Your Scenes", description: "Go to Breakdowns → Add cast, props, and elements to each scene")

                    QuickStartStep(number: 3, icon: "person.2.fill", title: "Add Cast & Crew", description: "Go to Contacts → Add your cast and crew with contact info")

                    QuickStartStep(number: 4, icon: "mappin.circle.fill", title: "Add Locations", description: "Go to Locations → Add shooting locations with addresses and permits")

                    QuickStartStep(number: 5, icon: "calendar.circle.fill", title: "Build Your Schedule", description: "Go to Scheduler → Drag scene strips to create shooting order")

                    QuickStartStep(number: 6, icon: "doc.text.fill", title: "Generate Call Sheets", description: "Go to Call Sheets → Create daily production documents")

                    // Help reference
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Need More Help?")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Access the complete Help guide from the menu bar: Help → Production Runner Help")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Toggle("Don't show this again", isOn: $hasSeenQuickStart)
                    .font(.system(size: 13))

                Spacer()

                Button("Get Started") {
                    hasSeenQuickStart = true
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 600, height: 550)
    }
}

struct QuickStartStep: View {
    let number: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Get Started Window View (for Help menu)
struct GetStartedWindowView: View {
    @State private var currentStep = 0

    private var isLastStep: Bool {
        currentStep == TutorialData.steps.count - 1
    }

    private var currentTutorialStep: TutorialStep {
        TutorialData.steps[currentStep]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress indicator
            VStack(spacing: 16) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<TutorialData.steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 24)

                // Step counter
                Text("Step \(currentStep + 1) of \(TutorialData.steps.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 32) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: currentTutorialStep.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 32)

                    // Title
                    Text(currentTutorialStep.title)
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)

                    // Description
                    Text(currentTutorialStep.description)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)

                    // Action text (if available)
                    if let actionText = currentTutorialStep.actionText {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.accentColor)
                            Text(actionText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.bottom, 40)
            }

            Divider()

            // Navigation buttons
            HStack(spacing: 16) {
                // Close button
                Button(action: {
                    #if os(macOS)
                    NSApp.keyWindow?.close()
                    #endif
                }) {
                    Text("Close")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Previous button
                if currentStep > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            currentStep -= 1
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Previous")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }

                // Next/Done button
                Button(action: {
                    if isLastStep {
                        #if os(macOS)
                        NSApp.keyWindow?.close()
                        #endif
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            currentStep += 1
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(isLastStep ? "Done" : "Next")
                            .font(.system(size: 14, weight: .semibold))
                        if !isLastStep {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }
}

// MARK: - Preview
#if DEBUG
struct FirstLaunchTutorial_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FirstLaunchTutorialView()
            QuickStartGuideView()
            GetStartedWindowView()
        }
    }
}
#endif
