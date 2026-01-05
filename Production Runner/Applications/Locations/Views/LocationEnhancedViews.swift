import SwiftUI
import MapKit
import UniformTypeIdentifiers
import CoreData

// MARK: - All Locations Map View
struct AllLocationsMapView: View {
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458), // Detroit default
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var selectedLocationID: UUID?
    @Binding var isPresented: Bool
    var onSelectLocation: ((LocationItem) -> Void)?

    var locationsWithCoordinates: [LocationItem] {
        locationManager.locations.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)
                Text("All Locations")
                    .font(.title2.bold())

                Spacer()

                Text("\(locationsWithCoordinates.count) locations on map")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(ModernActionButtonStyle(color: .blue))
            }
            .padding()
            .background(.ultraThinMaterial)

            // Map
            Map(coordinateRegion: $region, annotationItems: locationsWithCoordinates) { location in
                MapAnnotation(coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude ?? 0,
                    longitude: location.longitude ?? 0
                )) {
                    LocationMapPin(
                        location: location,
                        isSelected: selectedLocationID == location.id,
                        onTap: {
                            selectedLocationID = location.id
                        }
                    )
                }
            }

            // Selected location info bar
            if let selectedID = selectedLocationID,
               let location = locationManager.getLocation(by: selectedID) {
                selectedLocationBar(location)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            fitMapToLocations()
        }
    }

    private func selectedLocationBar(_ location: LocationItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                Text(location.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            PermitStatusBadge(status: location.permitStatus)

            if location.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }

            Button("View") {
                onSelectLocation?(location)
                isPresented = false
            }
            .buttonStyle(ModernActionButtonStyle(color: .blue))
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func fitMapToLocations() {
        guard !locationsWithCoordinates.isEmpty else { return }

        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for location in locationsWithCoordinates {
            if let lat = location.latitude, let lon = location.longitude {
                minLat = min(minLat, lat)
                maxLat = max(maxLat, lat)
                minLon = min(minLon, lon)
                maxLon = max(maxLon, lon)
            }
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)
        )
        region = MKCoordinateRegion(center: center, span: span)
    }
}

struct LocationMapPin: View {
    let location: LocationItem
    let isSelected: Bool
    let onTap: () -> Void

    var pinColor: Color {
        switch location.permitStatus {
        case "Approved": return .green
        case "Denied": return .red
        case "Needs Scout": return .orange
        default: return .blue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
                    .shadow(color: pinColor.opacity(0.4), radius: isSelected ? 8 : 4)

                Image(systemName: location.isFavorite ? "star.fill" : "mappin")
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundColor(.white)
            }

            if isSelected {
                Text(location.name)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .offset(y: 4)
            }
        }
        .onTapGesture(perform: onTap)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Route Planning View
struct RoutePlanningView: View {
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var selectedLocations: [LocationItem] = []
    @State private var routeInfo: RouteInfo?
    @State private var isCalculating = false
    @Binding var isPresented: Bool

    struct RouteInfo {
        var totalDistance: Double // in miles
        var totalTime: TimeInterval // in seconds
        var segments: [(from: LocationItem, to: LocationItem, distance: Double, time: TimeInterval)]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)
                Text("Route Planning")
                    .font(.title2.bold())

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(ModernActionButtonStyle(color: .blue))
            }
            .padding()
            .background(.ultraThinMaterial)

            HStack(spacing: 0) {
                // Left: Location selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Locations")
                        .font(.headline)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(locationManager.locations.filter { $0.latitude != nil }) { location in
                                RouteLocationRow(
                                    location: location,
                                    isSelected: selectedLocations.contains(where: { $0.id == location.id }),
                                    order: selectedLocations.firstIndex(where: { $0.id == location.id }).map { $0 + 1 },
                                    onToggle: {
                                        toggleLocation(location)
                                    }
                                )
                            }
                        }
                    }

                    if selectedLocations.count >= 2 {
                        Button {
                            calculateRoute()
                        } label: {
                            HStack {
                                if isCalculating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.swap")
                                }
                                Text("Calculate Route")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ModernActionButtonStyle(color: .blue))
                        .disabled(isCalculating)
                    }
                }
                .padding()
                .frame(width: 280)
                .background(Color.primary.opacity(0.02))

                Divider()

                // Right: Route info and map
                VStack(spacing: 0) {
                    if let route = routeInfo {
                        // Route summary
                        HStack(spacing: 24) {
                            VStack {
                                Text(String(format: "%.1f mi", route.totalDistance))
                                    .font(.title.bold())
                                Text("Total Distance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider().frame(height: 40)

                            VStack {
                                Text(formatDuration(route.totalTime))
                                    .font(.title.bold())
                                Text("Est. Drive Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider().frame(height: 40)

                            VStack {
                                Text("\(selectedLocations.count)")
                                    .font(.title.bold())
                                Text("Stops")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))

                        // Segments list
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(route.segments.enumerated()), id: \.offset) { index, segment in
                                    RouteSegmentRow(
                                        index: index + 1,
                                        from: segment.from,
                                        to: segment.to,
                                        distance: segment.distance,
                                        time: segment.time
                                    )
                                }
                            }
                            .padding()
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Select at least 2 locations to calculate a route")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func toggleLocation(_ location: LocationItem) {
        if let index = selectedLocations.firstIndex(where: { $0.id == location.id }) {
            selectedLocations.remove(at: index)
        } else {
            selectedLocations.append(location)
        }
        routeInfo = nil
    }

    private func calculateRoute() {
        guard selectedLocations.count >= 2 else { return }

        isCalculating = true
        var segments: [(from: LocationItem, to: LocationItem, distance: Double, time: TimeInterval)] = []

        // Calculate distances between consecutive locations
        for i in 0..<(selectedLocations.count - 1) {
            let from = selectedLocations[i]
            let to = selectedLocations[i + 1]

            if let lat1 = from.latitude, let lon1 = from.longitude,
               let lat2 = to.latitude, let lon2 = to.longitude {
                let distance = haversineDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
                let time = distance / 30.0 * 3600 // Assume 30 mph average
                segments.append((from: from, to: to, distance: distance, time: time))
            }
        }

        let totalDistance = segments.reduce(0) { $0 + $1.distance }
        let totalTime = segments.reduce(0) { $0 + $1.time }

        routeInfo = RouteInfo(totalDistance: totalDistance, totalTime: totalTime, segments: segments)
        isCalculating = false
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 3959.0 // Earth radius in miles
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

struct RouteLocationRow: View {
    let location: LocationItem
    let isSelected: Bool
    let order: Int?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                    if let order = order {
                        Text("\(order)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.subheadline.weight(.medium))
                    Text(location.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct RouteSegmentRow: View {
    let index: Int
    let from: LocationItem
    let to: LocationItem
    let distance: Double
    let time: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 2, height: 30)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(from.name)
                    .font(.subheadline.weight(.medium))
                HStack {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                    Text(String(format: "%.1f mi", distance))
                        .font(.caption)
                    Text("•")
                        .font(.caption)
                    Text(formatTime(time))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                Text(to.name)
                    .font(.subheadline.weight(.medium))
            }

            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes) min"
    }
}

// MARK: - Folder Management View
struct FolderManagementView: View {
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var showAddFolder = false
    @State private var editingFolder: LocationFolder?
    @State private var newFolderName = ""
    @State private var newFolderColor = Color.blue
    @State private var newFolderIcon = "folder.fill"
    @Binding var isPresented: Bool

    let iconOptions = ["folder.fill", "star.fill", "flag.fill", "bookmark.fill", "tag.fill", "heart.fill", "mappin.circle.fill", "building.2.fill", "house.fill"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)
                Text("Manage Folders")
                    .font(.title2.bold())

                Spacer()

                Button {
                    showAddFolder = true
                } label: {
                    Label("Add Folder", systemImage: "plus")
                }
                .buttonStyle(ModernActionButtonStyle(color: .blue))

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(ModernSecondaryButtonStyle())
            }
            .padding()
            .background(.ultraThinMaterial)

            // Folders list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(locationManager.folders.sorted { $0.sortOrder < $1.sortOrder }) { folder in
                        FolderRow(
                            folder: folder,
                            locationCount: locationManager.getLocationsInFolder(folder.id).count,
                            onEdit: {
                                editingFolder = folder
                                newFolderName = folder.name
                                newFolderColor = Color(hex: folder.colorHex) ?? .blue
                                newFolderIcon = folder.iconName
                            },
                            onDelete: {
                                locationManager.deleteFolder(folder)
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showAddFolder) {
            folderEditorSheet(isNew: true)
        }
        .sheet(item: $editingFolder) { folder in
            folderEditorSheet(isNew: false)
        }
    }

    private func folderEditorSheet(isNew: Bool) -> some View {
        VStack(spacing: 20) {
            Text(isNew ? "New Folder" : "Edit Folder")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                TextField("Folder name", text: $newFolderName)
                    .textFieldStyle(ModernTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $newFolderColor)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button {
                            newFolderIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(newFolderIcon == icon ? .white : .primary)
                                .frame(width: 44, height: 44)
                                .background(newFolderIcon == icon ? newFolderColor : Color.primary.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showAddFolder = false
                    editingFolder = nil
                    resetForm()
                }
                .buttonStyle(ModernSecondaryButtonStyle())

                Button(isNew ? "Create" : "Save") {
                    if isNew {
                        let folder = LocationFolder(
                            name: newFolderName,
                            colorHex: newFolderColor.toHex() ?? "#007AFF",
                            iconName: newFolderIcon,
                            sortOrder: locationManager.folders.count
                        )
                        locationManager.addFolder(folder)
                    } else if var folder = editingFolder {
                        folder = LocationFolder(
                            id: folder.id,
                            name: newFolderName,
                            colorHex: newFolderColor.toHex() ?? folder.colorHex,
                            iconName: newFolderIcon,
                            parentFolderID: folder.parentFolderID,
                            sortOrder: folder.sortOrder,
                            createdAt: folder.createdAt,
                            updatedAt: Date()
                        )
                        locationManager.updateFolder(folder)
                    }
                    showAddFolder = false
                    editingFolder = nil
                    resetForm()
                }
                .buttonStyle(ModernActionButtonStyle(color: .blue))
                .disabled(newFolderName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func resetForm() {
        newFolderName = ""
        newFolderColor = .blue
        newFolderIcon = "folder.fill"
    }
}

struct FolderRow: View {
    let folder: LocationFolder
    let locationCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.iconName)
                .font(.title2)
                .foregroundColor(Color(hex: folder.colorHex) ?? .blue)
                .frame(width: 44, height: 44)
                .background((Color(hex: folder.colorHex) ?? .blue).opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.headline)
                Text("\(locationCount) locations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
    }
}

// MARK: - Advanced Filter View
struct AdvancedFilterView: View {
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var localFilter: LocationFilterOptions
    @Binding var isPresented: Bool

    let permitStatuses = ["Pending", "Needs Scout", "Approved", "Denied"]

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._localFilter = State(initialValue: LocationDataManager.shared.filterOptions)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)
                Text("Filters")
                    .font(.title2.bold())

                Spacer()

                Button("Reset") {
                    localFilter = LocationFilterOptions()
                }
                .buttonStyle(ModernSecondaryButtonStyle())

                Button("Apply") {
                    locationManager.filterOptions = localFilter
                    isPresented = false
                }
                .buttonStyle(ModernActionButtonStyle(color: .blue))
            }
            .padding()
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Permit Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permit Status")
                            .font(.headline)

                        HStack(spacing: 8) {
                            ForEach(permitStatuses, id: \.self) { status in
                                FilterChip(
                                    label: status,
                                    isSelected: localFilter.permitStatuses.contains(status),
                                    color: statusColor(for: status)
                                ) {
                                    if localFilter.permitStatuses.contains(status) {
                                        localFilter.permitStatuses.removeAll { $0 == status }
                                    } else {
                                        localFilter.permitStatuses.append(status)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Quick Filters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Filters")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Toggle("Favorites Only", isOn: $localFilter.showFavoritesOnly)
                            Toggle("Scouted Only", isOn: $localFilter.showScoutedOnly)
                            Toggle("Unscouted Only", isOn: $localFilter.showUnscoutedOnly)
                        }
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                    }

                    Divider()

                    // Sort Options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sort By")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Picker("Sort by", selection: $localFilter.sortBy) {
                                ForEach(LocationFilterOptions.SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .labelsHidden()

                            Toggle("Ascending", isOn: $localFilter.sortAscending)
                                #if os(macOS)
                                .toggleStyle(.checkbox)
                                #endif
                        }
                    }

                    Divider()

                    // Folders
                    if !locationManager.folders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Folders")
                                .font(.headline)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                                ForEach(locationManager.folders) { folder in
                                    FilterChip(
                                        label: folder.name,
                                        isSelected: localFilter.folderIDs.contains(folder.id),
                                        color: Color(hex: folder.colorHex) ?? .blue
                                    ) {
                                        if localFilter.folderIDs.contains(folder.id) {
                                            localFilter.folderIDs.removeAll { $0 == folder.id }
                                        } else {
                                            localFilter.folderIDs.append(folder.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            // Active filters summary
            if hasActiveFilters {
                HStack {
                    Text("\(activeFilterCount) filters active")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(locationManager.filteredLocations().count) locations match")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Approved": return .green
        case "Denied": return .red
        case "Needs Scout": return .orange
        default: return .blue
        }
    }

    private var hasActiveFilters: Bool {
        !localFilter.permitStatuses.isEmpty ||
        !localFilter.folderIDs.isEmpty ||
        localFilter.showFavoritesOnly ||
        localFilter.showScoutedOnly ||
        localFilter.showUnscoutedOnly
    }

    private var activeFilterCount: Int {
        var count = 0
        count += localFilter.permitStatuses.count
        count += localFilter.folderIDs.count
        if localFilter.showFavoritesOnly { count += 1 }
        if localFilter.showScoutedOnly { count += 1 }
        if localFilter.showUnscoutedOnly { count += 1 }
        return count
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color.primary.opacity(0.05))
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Comments View
struct LocationCommentsView: View {
    let locationID: UUID
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var newCommentText = ""
    @State private var authorName = ""

    var comments: [LocationComment] {
        locationManager.getComments(for: locationID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(.blue.gradient)
                Text("Comments")
                    .font(.headline)
                Spacer()
                Text("\(comments.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))

            if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(comments) { comment in
                            CommentBubble(comment: comment) {
                                locationManager.deleteComment(comment)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Add comment
            VStack(spacing: 8) {
                if authorName.isEmpty {
                    TextField("Your name", text: $authorName)
                        .textFieldStyle(ModernTextFieldStyle())
                }

                HStack(spacing: 8) {
                    TextField("Add a comment...", text: $newCommentText)
                        .textFieldStyle(ModernTextFieldStyle())

                    Button {
                        addComment()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(ModernIconButtonStyle())
                    .disabled(newCommentText.isEmpty || authorName.isEmpty)
                }
            }
            .padding(12)
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
        .onAppear {
            #if os(macOS)
            authorName = NSFullUserName()
            #endif
        }
    }

    private func addComment() {
        let comment = LocationComment(
            locationID: locationID,
            authorName: authorName,
            content: newCommentText
        )
        locationManager.addComment(comment)
        newCommentText = ""
    }
}

struct CommentBubble: View {
    let comment: LocationComment
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.authorName)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(comment.content)
                .font(.subheadline)

            if comment.isResolved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Resolved")
                        .font(.caption)
                }
                .foregroundColor(.green)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Activity Log View
struct ActivityLogView: View {
    let locationID: UUID
    @StateObject private var locationManager = LocationDataManager.shared

    var activities: [ActivityLogEntry] {
        locationManager.getActivityLog(for: locationID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.blue.gradient)
                Text("Activity")
                    .font(.headline)
                Spacer()
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))

            if activities.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(activities) { activity in
                            ActivityRow(activity: activity)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }
}

struct ActivityRow: View {
    let activity: ActivityLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activity.activityType.icon)
                .font(.body)
                .foregroundColor(activity.activityType.color)
                .frame(width: 24, height: 24)
                .background(activity.activityType.color.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.description)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    Text(activity.userName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(activity.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
    }
}

// MARK: - Documents View
struct LocationDocumentsView: View {
    let locationID: UUID
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var showAddDocument = false
    @State private var isImporting = false

    var documents: [LocationDocument] {
        locationManager.getDocuments(for: locationID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.blue.gradient)
                Text("Documents")
                    .font(.headline)
                Spacer()
                Button {
                    isImporting = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(ModernSecondaryButtonStyle())
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))

            if documents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No documents yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Add permits, contracts, or other files")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(documents) { doc in
                            DocumentRow(document: doc) {
                                locationManager.deleteDocument(doc)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 300)
            }
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf, .image, .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if let data = try? Data(contentsOf: url) {
                        let doc = LocationDocument(
                            locationID: locationID,
                            name: url.lastPathComponent,
                            documentType: .other,
                            fileData: data,
                            fileExtension: url.pathExtension
                        )
                        locationManager.addDocument(doc)
                    }
                }
            case .failure:
                break
            }
        }
    }
}

struct DocumentRow: View {
    let document: LocationDocument
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.documentType.icon)
                .font(.title2)
                .foregroundColor(document.documentType.color)
                .frame(width: 40, height: 40)
                .background(document.documentType.color.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(document.documentType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let expiration = document.expirationDate {
                        Text("• Expires \(expiration.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(expiration < Date() ? .red : .secondary)
                    }
                }
            }

            Spacer()

            Text(document.fileExtension.uppercased())
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Export View
struct ExportLocationsView: View {
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var selectedFormat: LocationExportFormat = .json
    @State private var selectedLocationIDs: Set<UUID> = []
    @State private var selectAll = true
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)
                Text("Export Locations")
                    .font(.title2.bold())

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(ModernSecondaryButtonStyle())
            }
            .padding()
            .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                // Format selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Format")
                        .font(.headline)

                    HStack(spacing: 12) {
                        ForEach(LocationExportFormat.allCases, id: \.self) { format in
                            Button {
                                selectedFormat = format
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: format.icon)
                                        .font(.title)
                                    Text(format.rawValue)
                                        .font(.caption.weight(.medium))
                                }
                                .frame(width: 80, height: 80)
                                .background(selectedFormat == format ? Color.blue.opacity(0.1) : Color.primary.opacity(0.03))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedFormat == format ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // Location selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Select Locations")
                            .font(.headline)
                        Spacer()
                        Toggle("Select All", isOn: $selectAll)
                            #if os(macOS)
                            .toggleStyle(.checkbox)
                            #endif
                            .onChange(of: selectAll) { newValue in
                                if newValue {
                                    selectedLocationIDs = Set(locationManager.locations.map { $0.id })
                                } else {
                                    selectedLocationIDs.removeAll()
                                }
                            }
                    }

                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(locationManager.locations) { location in
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { selectedLocationIDs.contains(location.id) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedLocationIDs.insert(location.id)
                                            } else {
                                                selectedLocationIDs.remove(location.id)
                                            }
                                        }
                                    ))
                                    #if os(macOS)
                                    .toggleStyle(.checkbox)
                                    #endif

                                    Text(location.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(location.permitStatus)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)
                }

                // Export button
                Button {
                    exportLocations()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export \(selectedLocationIDs.count) Locations")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernActionButtonStyle(color: .blue))
                .disabled(selectedLocationIDs.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 550)
        .onAppear {
            selectedLocationIDs = Set(locationManager.locations.map { $0.id })
        }
    }

    private func exportLocations() {
        guard let data = locationManager.exportLocations(format: selectedFormat, locationIDs: Array(selectedLocationIDs)) else { return }

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [selectedFormat == .pdf ? .pdf : selectedFormat == .csv ? .commaSeparatedText : .json]
        panel.nameFieldStringValue = "locations.\(selectedFormat.fileExtension)"

        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
        #endif

        isPresented = false
    }
}

// MARK: - Import View
struct ImportLocationsView: View {
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var isImporting = false
    @State private var importResult: Int?
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue.gradient)

            Text("Import Locations")
                .font(.title2.bold())

            Text("Import locations from a JSON or CSV file")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let result = importResult {
                HStack {
                    Image(systemName: result > 0 ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(result > 0 ? .green : .orange)
                    Text(result > 0 ? "\(result) locations imported successfully" : "No new locations to import")
                }
                .padding()
                .background(result > 0 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(ModernSecondaryButtonStyle())

                Button {
                    isImporting = true
                } label: {
                    Label("Choose File", systemImage: "doc.badge.plus")
                }
                .buttonStyle(ModernActionButtonStyle(color: .blue))
            }
        }
        .padding(30)
        .frame(width: 400)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                if let data = try? Data(contentsOf: url) {
                    let format: LocationExportFormat = url.pathExtension.lowercased() == "csv" ? .csv : .json
                    importResult = locationManager.importLocations(from: data, format: format)
                }
            case .failure:
                break
            }
        }
    }
}

// MARK: - Nearby Locations View
struct NearbyLocationsView: View {
    let location: LocationItem
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var radius: Double = 5.0
    var onSelectLocation: ((LocationItem) -> Void)?

    var nearbyLocations: [LocationItem] {
        locationManager.getNearbyLocations(to: location, withinMiles: radius)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundStyle(.blue.gradient)
                Text("Nearby Locations")
                    .font(.headline)
                Spacer()
                Picker("Radius", selection: $radius) {
                    Text("1 mi").tag(1.0)
                    Text("5 mi").tag(5.0)
                    Text("10 mi").tag(10.0)
                    Text("25 mi").tag(25.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))

            if nearbyLocations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No nearby locations within \(Int(radius)) miles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(nearbyLocations) { nearby in
                            NearbyLocationCard(
                                location: nearby,
                                distanceFrom: location
                            ) {
                                onSelectLocation?(nearby)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }
}

struct NearbyLocationCard: View {
    let location: LocationItem
    let distanceFrom: LocationItem
    let onTap: () -> Void

    var distance: Double {
        guard let lat1 = distanceFrom.latitude, let lon1 = distanceFrom.longitude,
              let lat2 = location.latitude, let lon2 = location.longitude else { return 0 }

        let R = 3959.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(location.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    if location.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Text(location.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    PermitStatusBadge(status: location.permitStatus)
                    Spacer()
                    Text(String(format: "%.1f mi", distance))
                        .font(.caption.weight(.medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .frame(width: 200)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weather View
struct LocationWeatherView: View {
    let scoutDate: Date?
    let weather: LocationWeather?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundStyle(.blue.gradient)
                Text("Weather Forecast")
                    .font(.headline)
                Spacer()
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))

            if let weather = weather {
                HStack(spacing: 20) {
                    // Main weather
                    VStack(spacing: 4) {
                        Image(systemName: weather.condition.icon)
                            .font(.system(size: 36))
                            .foregroundColor(weather.condition.color)
                        if let temp = weather.temperature {
                            Text("\(Int(temp))\(weather.temperatureUnit)")
                                .font(.title2.bold())
                        }
                        Text(weather.condition.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider().frame(height: 60)

                    // Details
                    VStack(alignment: .leading, spacing: 6) {
                        if let humidity = weather.humidity {
                            HStack(spacing: 4) {
                                Image(systemName: "humidity")
                                    .font(.caption)
                                Text("\(Int(humidity))% humidity")
                                    .font(.caption)
                            }
                        }
                        if let wind = weather.windSpeed {
                            HStack(spacing: 4) {
                                Image(systemName: "wind")
                                    .font(.caption)
                                Text("\(Int(wind)) mph \(weather.windDirection ?? "")")
                                    .font(.caption)
                            }
                        }
                        if let precip = weather.precipitation, precip > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                Text("\(Int(precip))% chance of rain")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                }
                .padding(16)
            } else if let date = scoutDate {
                VStack(spacing: 8) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Weather forecast for \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Forecast will be available closer to the date")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(16)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Set a scout date to see weather forecast")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }
}

// MARK: - Location Assignments View
/// Displays and manages assignments for a location, synced with the Tasks app
struct LocationAssignmentsView: View {
    let locationID: UUID
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationDataManager.shared

    // Form state
    @State private var showAddForm = false
    @State private var assigneeName = ""
    @State private var assigneeEmail = ""
    @State private var assigneePhone = ""
    @State private var role: LocationAssignment.AssignmentRole = .scout
    @State private var taskDescription = ""
    @State private var dueDate: Date? = nil
    @State private var notes = ""

    var assignments: [LocationAssignment] {
        locationManager.getAssignments(for: locationID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange.gradient)
                Text("Assigned Tasks")
                    .font(.headline)
                Spacer()
                Text("\(assignments.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)

                Button {
                    showAddForm.toggle()
                } label: {
                    Image(systemName: showAddForm ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))

            if assignments.isEmpty && !showAddForm {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No assignments yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Tap + to assign tasks to team members")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(height: 120)
            } else if !assignments.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(assignments) { assignment in
                            AssignmentRow(
                                assignment: assignment,
                                onToggleComplete: {
                                    toggleCompletion(assignment)
                                },
                                onDelete: {
                                    deleteAssignment(assignment)
                                }
                            )
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 300)
            }

            // Add assignment form
            if showAddForm {
                Divider()

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Assignee name", text: $assigneeName)
                            .textFieldStyle(.roundedBorder)

                        Picker("Role", selection: $role) {
                            ForEach(LocationAssignment.AssignmentRole.allCases, id: \.self) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .frame(width: 160)
                    }

                    TextField("Task description", text: $taskDescription)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        TextField("Email (optional)", text: $assigneeEmail)
                            .textFieldStyle(.roundedBorder)
                        TextField("Phone (optional)", text: $assigneePhone)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 8) {
                        DatePicker(
                            "Due date",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                        .labelsHidden()

                        Button {
                            dueDate = nil
                        } label: {
                            Text("Clear")
                                .font(.caption)
                        }
                        .disabled(dueDate == nil)

                        Spacer()

                        Button {
                            addAssignment()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(assigneeName.isEmpty || taskDescription.isEmpty)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.02))
            }
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
        .onAppear {
            #if os(macOS)
            if assigneeName.isEmpty {
                assigneeName = NSFullUserName()
            }
            #endif
        }
    }

    private func addAssignment() {
        let assignment = LocationAssignment(
            locationID: locationID,
            assigneeName: assigneeName,
            assigneeEmail: assigneeEmail,
            assigneePhone: assigneePhone,
            role: role,
            taskDescription: taskDescription,
            dueDate: dueDate,
            notes: notes
        )

        locationManager.addAssignment(assignment, context: viewContext)

        // Reset form
        assigneeName = ""
        assigneeEmail = ""
        assigneePhone = ""
        taskDescription = ""
        dueDate = nil
        notes = ""
        role = .scout
        showAddForm = false

        #if os(macOS)
        assigneeName = NSFullUserName()
        #endif
    }

    private func toggleCompletion(_ assignment: LocationAssignment) {
        var updated = assignment
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil
        locationManager.updateAssignment(updated, context: viewContext)
    }

    private func deleteAssignment(_ assignment: LocationAssignment) {
        locationManager.deleteAssignment(assignment, context: viewContext)
    }
}

// MARK: - Assignment Row
struct AssignmentRow: View {
    let assignment: LocationAssignment
    let onToggleComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Completion checkbox
            Button {
                onToggleComplete()
            } label: {
                Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(assignment.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.taskDescription.isEmpty ? "\(assignment.role.rawValue) task" : assignment.taskDescription)
                    .font(.system(size: 13))
                    .strikethrough(assignment.isCompleted)
                    .foregroundColor(assignment.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: assignment.role.icon)
                            .font(.system(size: 10))
                        Text(assignment.assigneeName)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)

                    if let dueDate = assignment.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(dueDate < Date() && !assignment.isCompleted ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Role badge
            Text(assignment.role.rawValue)
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
