import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif

struct DigitalCallSheetShotListView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: LiveModeStore

    @State private var selectedTab: CallSheetTab = .callSheet
    @State private var selectedCallSheet: CallSheetEntity?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CallSheetEntity.shootDate, ascending: false)],
        animation: .default
    )
    private var callSheets: FetchedResults<CallSheetEntity>

    enum CallSheetTab: String, CaseIterable {
        case callSheet = "Call Sheet"
        case shotList = "Shot List"

        var icon: String {
            switch self {
            case .callSheet: return "doc.text.fill"
            case .shotList: return "video.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            tabSelector

            Divider()

            // Content
            if let callSheet = todaysCallSheet {
                switch selectedTab {
                case .callSheet:
                    callSheetContent(callSheet)
                case .shotList:
                    shotListContent(callSheet)
                }
            } else {
                noCallSheetView
            }
        }
        .onAppear {
            selectedCallSheet = todaysCallSheet
        }
    }

    // MARK: - Today's Call Sheet

    private var todaysCallSheet: CallSheetEntity? {
        let today = Calendar.current.startOfDay(for: Date())
        return callSheets.first { callSheet in
            guard let shootDate = callSheet.shootDate else { return false }
            return Calendar.current.isDate(shootDate, inSameDayAs: today)
        }
    }

    // MARK: - Tab Selector

    @ViewBuilder
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CallSheetTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab
                            ? Color.blue.opacity(0.1)
                            : Color.clear
                    )
                    .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

    // MARK: - Call Sheet Content

    @ViewBuilder
    private func callSheetContent(_ callSheet: CallSheetEntity) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                callSheetHeader(callSheet)

                Divider()

                // Key Times
                keyTimesSection(callSheet)

                Divider()

                // Location
                locationSection(callSheet)

                Divider()

                // Schedule
                scheduleSection(callSheet)

                Divider()

                // Cast
                castSection(callSheet)

                Divider()

                // Notes
                notesSection(callSheet)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func callSheetHeader(_ callSheet: CallSheetEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(callSheet.title ?? "Untitled")
                        .font(.title.bold())

                    if let company = callSheet.productionCompany, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Day badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Day \(callSheet.dayNumber)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                    Text("of \(callSheet.totalDays)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let date = callSheet.shootDate {
                Text(date, style: .date)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func keyTimesSection(_ callSheet: CallSheetEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Times", systemImage: "clock.fill")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                TimeCard(title: "Crew Call", time: callSheet.crewCall, color: .blue)
                TimeCard(title: "Shooting Call", time: callSheet.shootingCall, color: .green)
                TimeCard(title: "Breakfast", time: callSheet.breakfast, color: .orange)
                TimeCard(title: "Lunch", time: callSheet.lunch, color: .orange)
                TimeCard(title: "Est. Wrap", time: callSheet.estimatedWrap, color: .red)
                TimeCard(title: "Walkaway", time: callSheet.walkaway, color: .purple)
            }
        }
    }

    @ViewBuilder
    private func locationSection(_ callSheet: CallSheetEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location", systemImage: "mappin.circle.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let location = callSheet.shootingLocation, !location.isEmpty {
                    HStack(alignment: .top) {
                        Text("Location:")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(location)
                    }
                }

                if let address = callSheet.locationAddress, !address.isEmpty {
                    HStack(alignment: .top) {
                        Text("Address:")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(address)
                    }
                }

                if let parking = callSheet.crewParking, !parking.isEmpty {
                    HStack(alignment: .top) {
                        Text("Parking:")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(parking)
                    }
                }

                if let hospital = callSheet.nearestHospital, !hospital.isEmpty {
                    HStack(alignment: .top) {
                        Text("Hospital:")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(hospital)
                    }
                    .foregroundStyle(.red)
                }
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func scheduleSection(_ callSheet: CallSheetEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schedule", systemImage: "list.bullet.rectangle.fill")
                .font(.headline)

            if let scheduleJSON = callSheet.scheduleItemsJSON,
               let data = scheduleJSON.data(using: .utf8),
               let items = try? JSONDecoder().decode([ScheduleDisplayItem].self, from: data) {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        LiveScheduleItemRow(item: item)
                    }
                }
            } else {
                Text("No schedule items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func castSection(_ callSheet: CallSheetEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cast", systemImage: "person.2.fill")
                .font(.headline)

            if let castJSON = callSheet.castMembersJSON,
               let data = castJSON.data(using: .utf8),
               let members = try? JSONDecoder().decode([CastDisplayMember].self, from: data) {
                VStack(spacing: 8) {
                    ForEach(members) { member in
                        LiveCastMemberRow(member: member)
                    }
                }
            } else {
                Text("No cast members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ callSheet: CallSheetEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let productionNotes = callSheet.productionNotes, !productionNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Production Notes", systemImage: "note.text")
                        .font(.headline)
                    Text(productionNotes)
                        .font(.subheadline)
                }
            }

            if let safetyNotes = callSheet.safetyNotes, !safetyNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Safety Notes", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text(safetyNotes)
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Shot List Content

    @ViewBuilder
    private func shotListContent(_ callSheet: CallSheetEntity) -> some View {
        // Get scenes for today from the schedule
        if let scheduleJSON = callSheet.scheduleItemsJSON,
           let data = scheduleJSON.data(using: .utf8),
           let items = try? JSONDecoder().decode([ScheduleDisplayItem].self, from: data) {

            let sceneNumbers = items.compactMap { $0.sceneNumber }

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sceneNumbers, id: \.self) { sceneNumber in
                        SceneShotListCard(sceneNumber: sceneNumber, context: context)
                    }
                }
                .padding(20)
            }
        } else {
            EmptyStateView(
                "No Shots Scheduled",
                systemImage: "video.slash",
                description: "No scenes are scheduled for today"
            )
        }
    }

    // MARK: - No Call Sheet View

    @ViewBuilder
    private var noCallSheetView: some View {
        EmptyStateView(
            "No Call Sheet for Today",
            systemImage: "doc.text.fill",
            description: "Create a call sheet for today in the Call Sheets app"
        )
    }
}

// MARK: - Supporting Views

struct TimeCard: View {
    let title: String
    let time: String?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(time ?? "—")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(time != nil ? color : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

struct LiveScheduleItemRow: View {
    let item: ScheduleDisplayItem

    var body: some View {
        HStack(spacing: 12) {
            if let sceneNumber = item.sceneNumber {
                Text(sceneNumber)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.blue)
                    .frame(width: 50, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.description ?? "")
                    .font(.subheadline)
                    .lineLimit(2)

                if let cast = item.cast, !cast.isEmpty {
                    Text(cast)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let time = item.estimatedTime {
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }
}

struct LiveCastMemberRow: View {
    let member: CastDisplayMember

    var body: some View {
        HStack(spacing: 12) {
            // Cast number
            Text("#\(member.castNumber)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.purple)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.weight(.medium))
                if let role = member.role, !role.isEmpty {
                    Text(role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let callTime = member.callTime {
                Text(callTime)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SceneShotListCard: View {
    let sceneNumber: String
    let context: NSManagedObjectContext

    @FetchRequest var shots: FetchedResults<ShotEntity>

    init(sceneNumber: String, context: NSManagedObjectContext) {
        self.sceneNumber = sceneNumber
        self.context = context

        // Fetch shots for this scene
        _shots = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ShotEntity.index, ascending: true)],
            predicate: NSPredicate(format: "scene.number == %@", sceneNumber)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scene header
            HStack {
                Text("Scene \(sceneNumber)")
                    .font(.headline)
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(shots.count) shots")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if shots.isEmpty {
                Text("No shots defined")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(shots) { shot in
                        ShotRow(shot: shot)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }
}

struct ShotRow: View {
    let shot: ShotEntity

    var body: some View {
        HStack(spacing: 12) {
            // Shot code
            Text(shot.code ?? "—")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
                .frame(width: 40, alignment: .leading)

            // Shot type
            if let type = shot.type {
                Text(type)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
                    .foregroundStyle(.blue)
            }

            // Description
            Text(shot.descriptionText ?? "")
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // Camera & Lens info
            HStack(spacing: 8) {
                if let cam = shot.cam, !cam.isEmpty {
                    Text(cam)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let lens = shot.lens, !lens.isEmpty {
                    Text(lens)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Display Models

struct ScheduleDisplayItem: Identifiable, Codable {
    var id: UUID = UUID()
    var sceneNumber: String?
    var description: String?
    var cast: String?
    var estimatedTime: String?
    var location: String?

    enum CodingKeys: String, CodingKey {
        case id, sceneNumber, description, cast, estimatedTime, location
    }
}

struct CastDisplayMember: Identifiable, Codable {
    var id: UUID = UUID()
    var castNumber: Int
    var name: String
    var role: String?
    var callTime: String?
    var scenes: String?

    enum CodingKeys: String, CodingKey {
        case id, castNumber, name, role, callTime, scenes
    }
}
