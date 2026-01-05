import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-platform helpers for StoryboardViewer
private func storyboardImage(from data: Data) -> Image? {
    #if os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
    #else
    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
    #endif
}

private var storyboardControlBackgroundColor: Color {
    #if os(macOS)
    Color(NSColor.controlBackgroundColor)
    #else
    Color(UIColor.secondarySystemBackground)
    #endif
}

private var storyboardTextBackgroundColor: Color {
    #if os(macOS)
    Color(NSColor.textBackgroundColor)
    #else
    Color(UIColor.systemBackground)
    #endif
}

struct StoryboardViewer: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SceneEntity.sortIndex, ascending: true)],
        animation: .default
    )
    private var scenes: FetchedResults<SceneEntity>

    @State private var selectedSceneNumber: String?
    @State private var viewMode: StoryboardViewMode = .grid
    @State private var searchText: String = ""

    enum StoryboardViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
        case filmstrip = "Filmstrip"

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            case .filmstrip: return "film"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content
            if scenesWithStoryboards.isEmpty {
                EmptyStateView(
                    "No Reference Shots",
                    systemImage: "rectangle.3.group.fill",
                    description: "Add reference shot images to shots in the Shot List app"
                )
            } else {
                switch viewMode {
                case .grid:
                    gridView
                case .list:
                    listView
                case .filmstrip:
                    filmstripView
                }
            }
        }
        .background(storyboardTextBackgroundColor)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(storyboardControlBackgroundColor)
            )
            .frame(maxWidth: 250)

            Spacer()

            // Stats
            Text("\(totalShotCount) shots • \(storyboardCount) with frames")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // View mode picker
            Picker("View", selection: $viewMode) {
                ForEach(StoryboardViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
        .padding(12)
        .background(storyboardControlBackgroundColor)
    }

    // MARK: - Grid View

    @ViewBuilder
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredScenes) { scene in
                    ForEach(shotsWithStoryboards(for: scene)) { shot in
                        StoryboardCard(shot: shot, sceneNumber: scene.number ?? "")
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - List View

    @ViewBuilder
    private var listView: some View {
        List {
            ForEach(filteredScenes) { scene in
                Section {
                    ForEach(shotsWithStoryboards(for: scene)) { shot in
                        StoryboardListRow(shot: shot, sceneNumber: scene.number ?? "")
                    }
                } header: {
                    Text("Scene \(scene.number ?? "") - \((scene.sceneSlug ?? "").uppercased())")
                        .font(.headline)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Filmstrip View

    @ViewBuilder
    private var filmstripView: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(filteredScenes) { scene in
                    VStack(alignment: .leading, spacing: 8) {
                        // Scene header
                        HStack {
                            Text("Scene \(scene.number ?? "")")
                                .font(.headline)
                            Text((scene.sceneSlug ?? "").uppercased())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        // Horizontal scroll of shots
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(shotsWithStoryboards(for: scene)) { shot in
                                    FilmstripFrame(shot: shot)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Helpers

    private var filteredScenes: [SceneEntity] {
        let scenesArray = scenesWithStoryboards
        if searchText.isEmpty {
            return scenesArray
        }
        return scenesArray.filter { scene in
            (scene.number ?? "").localizedCaseInsensitiveContains(searchText) ||
            (scene.sceneSlug ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var scenesWithStoryboards: [SceneEntity] {
        scenes.filter { scene in
            let shots = (scene.shots as? Set<ShotEntity>) ?? []
            return shots.contains { $0.storyboardImageData != nil }
        }
    }

    private func shotsWithStoryboards(for scene: SceneEntity) -> [ShotEntity] {
        let shots = (scene.shots as? Set<ShotEntity>) ?? []
        return shots
            .filter { $0.storyboardImageData != nil }
            .sorted { ($0.index) < ($1.index) }
    }

    private var totalShotCount: Int {
        scenes.reduce(0) { $0 + ((($1.shots as? Set<ShotEntity>)?.count) ?? 0) }
    }

    private var storyboardCount: Int {
        scenes.reduce(0) { total, scene in
            let shots = (scene.shots as? Set<ShotEntity>) ?? []
            return total + shots.filter { $0.storyboardImageData != nil }.count
        }
    }
}

// MARK: - Storyboard Card

struct StoryboardCard: View {
    let shot: ShotEntity
    let sceneNumber: String

    var body: some View {
        VStack(spacing: 0) {
            // Image
            if let imageData = shot.storyboardImageData,
               let img = storyboardImage(from: imageData) {
                img
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    )
            }

            // Info bar
            HStack {
                // Shot code
                Text("\(sceneNumber)-\(shot.code ?? "")")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)

                if let type = shot.type {
                    Text(type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let cam = shot.cam, !cam.isEmpty {
                    Text(cam)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(storyboardControlBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Storyboard List Row

struct StoryboardListRow: View {
    let shot: ShotEntity
    let sceneNumber: String

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            if let imageData = shot.storyboardImageData,
               let img = storyboardImage(from: imageData) {
                img
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120, height: 68)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 68)
                    .cornerRadius(6)
            }

            // Shot info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(sceneNumber)-\(shot.code ?? "")")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)

                    if let type = shot.type {
                        Text(type)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                            )
                            .foregroundStyle(.blue)
                    }
                }

                if let description = shot.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }

                // Technical info
                HStack(spacing: 12) {
                    if let cam = shot.cam, !cam.isEmpty {
                        Label(cam, systemImage: "camera.fill")
                    }
                    if let lens = shot.lens, !lens.isEmpty {
                        Label(lens, systemImage: "circle.circle")
                    }
                    if let rig = shot.rig, !rig.isEmpty {
                        Label(rig, systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filmstrip Frame

struct FilmstripFrame: View {
    let shot: ShotEntity

    var body: some View {
        VStack(spacing: 4) {
            // Image with film perforations style
            ZStack {
                if let imageData = shot.storyboardImageData,
                   let img = storyboardImage(from: imageData) {
                    img
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 180, height: 100)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 180, height: 100)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.black, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Shot label
            Text(shot.code ?? "—")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StoryboardViewer()
}
