import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import MapKit
import Contacts
import WebKit
import CoreData

struct ParkingMapAnnotation: Codable, Hashable, Identifiable {
    let id: UUID
    var text: String
    var x: Double  // Position as percentage (0-1)
    var y: Double  // Position as percentage (0-1)
    var textColorHex: String  // Hex color like "#FF0000"
    var fontName: String
    var fontSize: Double
    var backgroundColorHex: String  // Hex color for background

    init(id: UUID = UUID(), text: String = "", x: Double = 0.5, y: Double = 0.5, textColorHex: String = "#000000", fontName: String = "Helvetica", fontSize: Double = 24, backgroundColorHex: String = "#FFFFFF") {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.textColorHex = textColorHex
        self.fontName = fontName
        self.fontSize = fontSize
        self.backgroundColorHex = backgroundColorHex
    }
}

struct LocationItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var address: String
    var locationInFilm: String
    var contact: String
    var phone: String
    var email: String
    var permitStatus: String
    var notes: String
    var dateToScout: Date?
    var scouted: Bool
    var latitude: Double?
    var longitude: Double?
    var imageDatas: [Data]
    var parkingMapImageData: Data?
    var parkingMapAnnotations: [ParkingMapAnnotation]

    // New fields for enhanced functionality
    var folderID: UUID?
    var isFavorite: Bool
    var priority: Int  // 1-5, where 1 is highest
    var photos: [LocationPhoto]  // Enhanced photo storage with categories
    var tagIDs: [UUID]
    var availabilityWindows: [AvailabilityWindow]
    var scoutWeather: LocationWeather?
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    var lastModifiedBy: String
    var sortOrder: Int32

    init(
        id: UUID = UUID(),
        name: String,
        address: String = "",
        locationInFilm: String = "",
        contact: String = "",
        phone: String = "",
        email: String = "",
        permitStatus: String = "Pending",
        notes: String = "",
        dateToScout: Date? = nil,
        scouted: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil,
        imageDatas: [Data] = [],
        parkingMapImageData: Data? = nil,
        parkingMapAnnotations: [ParkingMapAnnotation] = [],
        folderID: UUID? = nil,
        isFavorite: Bool = false,
        priority: Int = 3,
        photos: [LocationPhoto] = [],
        tagIDs: [UUID] = [],
        availabilityWindows: [AvailabilityWindow] = [],
        scoutWeather: LocationWeather? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String = "",
        lastModifiedBy: String = "",
        sortOrder: Int32 = 0
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.locationInFilm = locationInFilm
        self.contact = contact
        self.phone = phone
        self.email = email
        self.permitStatus = permitStatus
        self.notes = notes
        self.dateToScout = dateToScout
        self.scouted = scouted
        self.latitude = latitude
        self.longitude = longitude
        self.imageDatas = imageDatas
        self.parkingMapImageData = parkingMapImageData
        self.parkingMapAnnotations = parkingMapAnnotations
        self.folderID = folderID
        self.isFavorite = isFavorite
        self.priority = priority
        self.photos = photos
        self.tagIDs = tagIDs
        self.availabilityWindows = availabilityWindows
        self.scoutWeather = scoutWeather
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.sortOrder = sortOrder
    }
}

// Lightweight MapKit autocomplete for address/place suggestions
final class AddressAutocomplete: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" { didSet { completer.queryFragment = query } }
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter = {
        let c = MKLocalSearchCompleter()
        c.resultTypes = [.address, .pointOfInterest]
        return c
    }()
    override init() {
        super.init()
        completer.delegate = self
    }
    func completer(_ completer: MKLocalSearchCompleter, didUpdateResults results: [MKLocalSearchCompletion]) {
        self.results = results
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.results = []
    }
}

struct LocationsView: View {
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - State
    enum MapProvider: String {
        case apple
        case google
    }

    enum LocationViewMode: String, CaseIterable {
        case details = "Details"
        case mapEditor = "Map Editor"

        var icon: String {
            switch self {
            case .details: return "info.circle"
            case .mapEditor: return "map"
            }
        }
    }

    @StateObject private var ac = AddressAutocomplete()
    @StateObject private var locationManager = LocationDataManager.shared
    @State private var selectedProvider: MapProvider = .apple
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchText: String = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var lastSelectedID: UUID? = nil  // Track last selected for shift-click range
    @State private var selectedDate: Date = Date()
    @State private var isImportingImages: Bool = false
    @State private var importTargetID: UUID? = nil
    @State private var showGoogleEarthPopup: Bool = false
    @State private var googleEarthURL: String = "https://earth.google.com"
    @State private var googleEarthWebView: WKWebView?
    @State private var showMapEditor: Bool = false
    @State private var currentViewMode: LocationViewMode = .details

    // Photo viewer state
    @State private var selectedPhotoIndex: Int? = nil
    @State private var photoZoomLevel: CGFloat = 1.0
    private let minPhotoZoom: CGFloat = 0.5
    private let maxPhotoZoom: CGFloat = 3.0

    // Undo/Redo state
    @StateObject private var undoRedoManager = UndoRedoManager<[LocationItem]>(maxHistorySize: 10)

    // Clipboard for copy/paste operations
    @State private var locationClipboard: LocationItem? = nil

    // New feature states
    @State private var showAllLocationsMap: Bool = false
    @State private var showRoutePlanning: Bool = false
    @State private var showFolderManagement: Bool = false
    @State private var showAdvancedFilter: Bool = false
    @State private var showExportView: Bool = false
    @State private var showImportView: Bool = false
    @State private var showNearbyLocations: Bool = true
    @State private var showComments: Bool = true
    @State private var showActivityLog: Bool = false
    @State private var showDocuments: Bool = true
    @State private var showWeather: Bool = true
    @State private var selectedFolderID: UUID? = nil

    // MARK: - Derived
    private var filteredLocations: [LocationItem] {
        var locations = locationManager.locations

        // Filter by folder if one is selected
        if let folderID = selectedFolderID {
            locations = locations.filter { $0.folderID == folderID }
        }

        // Filter by search text
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            locations = locations.filter { $0.name.localizedCaseInsensitiveContains(trimmed) || $0.address.localizedCaseInsensitiveContains(trimmed) }
        }

        return locations
    }

    // Get the first selected ID for single-selection compatibility
    private var selectedID: UUID? {
        selectedIDs.first
    }

    private var selectedIndex: Int? {
        guard let id = selectedID else { return nil }
        return locationManager.locations.firstIndex(where: { $0.id == id })
    }

    private var selectedLocationBinding: Binding<LocationItem?> {
        Binding<LocationItem?>(
            get: {
                guard let idx = selectedIndex,
                      idx < locationManager.locations.count else { return nil }
                return locationManager.locations[idx]
            },
            set: { newValue in
                guard let newValue else { return }
                locationManager.updateLocation(newValue)
            }
        )
    }

    // MARK: - Layout
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                leftPane
                    .frame(width: geometry.size.width * 0.30)

                Divider()

                rightPane
                    .frame(width: geometry.size.width * 0.70)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(modernBackgroundColor)
        .fileImporter(isPresented: $isImportingImages, allowedContentTypes: [UTType.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                guard let targetID = importTargetID, var location = locationManager.getLocation(by: targetID) else { return }
                for url in urls {
                    if let data = try? Data(contentsOf: url) {
                        location.imageDatas.append(data)
                    }
                }
                locationManager.updateLocation(location)
            case .failure:
                break
            }
        }
        .sheet(isPresented: $showMapEditor) {
            if let binding = selectedLocationBindingIfAvailable {
                MapEditorView(location: binding, isPresented: $showMapEditor)
            }
        }
        .sheet(isPresented: $showAllLocationsMap) {
            AllLocationsMapView(isPresented: $showAllLocationsMap) { location in
                selectedIDs = [location.id]
                lastSelectedID = location.id
            }
        }
        .sheet(isPresented: $showRoutePlanning) {
            RoutePlanningView(isPresented: $showRoutePlanning)
        }
        .sheet(isPresented: $showFolderManagement) {
            FolderManagementView(isPresented: $showFolderManagement)
        }
        .sheet(isPresented: $showAdvancedFilter) {
            AdvancedFilterView(isPresented: $showAdvancedFilter)
        }
        .sheet(isPresented: $showExportView) {
            ExportLocationsView(isPresented: $showExportView)
        }
        .sheet(isPresented: $showImportView) {
            ImportLocationsView(isPresented: $showImportView)
        }
        #if os(macOS)
        .undoRedoSupport(
            canUndo: undoRedoManager.canUndo,
            canRedo: undoRedoManager.canRedo,
            onUndo: performUndo,
            onRedo: performRedo
        )
        .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
            deleteSelectedWithUndo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
            // Single selection view
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
            performCutCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
            performCopyCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
            performPasteCommand()
        }
        #endif
        .onAppear {
            configureLocationManager()
        }
    }

    // MARK: - Core Data Configuration

    /// Configure the LocationDataManager with the current Core Data context
    private func configureLocationManager() {
        // Get the project from the context
        guard !locationManager.isConfigured else { return }

        // Make sure the persistent store coordinator has stores loaded
        guard let coordinator = viewContext.persistentStoreCoordinator,
              !coordinator.persistentStores.isEmpty else {
            print("📍 Locations: Waiting for Core Data store to load...")
            return
        }

        // Fetch the current project
        let request = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        request.fetchLimit = 1

        do {
            if let project = try viewContext.fetch(request).first {
                locationManager.configure(context: viewContext, projectID: project.objectID)
                print("📍 Locations: Configured with project \(project.objectID)")
            } else {
                print("📍 Locations: No project found in store")
            }
        } catch {
            print("❌ Failed to fetch project for Locations: \(error)")
        }
    }

    // MARK: - Undo/Redo Functions
    #if os(macOS)
    private func saveToUndoStack() {
        undoRedoManager.saveState(locationManager.locations)
    }

    private func performUndo() {
        guard let previousState = undoRedoManager.undo(currentState: locationManager.locations) else { return }
        locationManager.locations = previousState
    }

    private func performRedo() {
        guard let nextState = undoRedoManager.redo(currentState: locationManager.locations) else { return }
        locationManager.locations = nextState
    }

    private func deleteSelectedWithUndo() {
        guard selectedID != nil else { return }
        saveToUndoStack()
        deleteSelected()
    }

    // MARK: - Clipboard Operations (Cut, Copy, Paste)

    private func performCutCommand() {
        // Check if text field has focus - let system handle cut
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text cut
            }
        }
        // Copy then delete
        performCopyCommand()
        deleteSelectedWithUndo()
    }

    private func performCopyCommand() {
        // Check if text field has focus - let system handle copy
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text copy
            }
        }
        // Copy selected location to clipboard
        guard let id = selectedID,
              let location = locationManager.locations.first(where: { $0.id == id }) else { return }
        locationClipboard = location
    }

    private func performPasteCommand() {
        // Check if text field has focus - let system handle paste
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text paste
            }
        }
        // Paste location from clipboard
        guard let copied = locationClipboard else { return }
        saveToUndoStack()

        // Create a duplicate with new ID
        let newLocation = LocationItem(
            id: UUID(),
            name: copied.name + " (copy)",
            address: copied.address,
            locationInFilm: copied.locationInFilm,
            contact: copied.contact,
            phone: copied.phone,
            email: copied.email,
            permitStatus: copied.permitStatus,
            notes: copied.notes,
            dateToScout: copied.dateToScout,
            scouted: copied.scouted,
            latitude: copied.latitude,
            longitude: copied.longitude,
            imageDatas: copied.imageDatas,
            parkingMapImageData: copied.parkingMapImageData,
            parkingMapAnnotations: copied.parkingMapAnnotations
        )
        locationManager.locations.append(newLocation)
        selectedIDs = [newLocation.id]
        lastSelectedID = newLocation.id
    }
    #endif

    // MARK: - Subviews
    private var leftPane: some View {
        VStack(spacing: 0) {
            leftPaneHeader
            Divider().opacity(0.5)
            leftPaneLocationCount
            leftPaneLocationList
        }
        .background(cardBackgroundColor)
    }

    private var leftPaneHeader: some View {
        VStack(spacing: 10) {
            leftPaneSearchRow
            leftPaneToolbarRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
    }

    private var leftPaneSearchRow: some View {
        HStack(spacing: 10) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
                TextField("Search locations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            // Add button
            Button(action: addLocation) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(CompactToolbarButtonStyle(color: .accentColor))
            .customTooltip("Add Location")

            // Delete button
            Button(action: deleteSelected) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(CompactToolbarButtonStyle(color: .red))
            .disabled(selectedIDs.isEmpty)
            .opacity(selectedIDs.isEmpty ? 0.4 : 1.0)
            .customTooltip(selectedIDs.count > 1 ? "Delete \(selectedIDs.count) Selected" : "Delete Selected")
        }
    }

    private var leftPaneToolbarRow: some View {
        HStack(spacing: 4) {
            Button { showAllLocationsMap = true } label: {
                Label("Map", systemImage: "map")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(CompactFeatureButtonStyle())
            .customTooltip("View All Locations on Map")

            Button { showRoutePlanning = true } label: {
                Label("Route", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(CompactFeatureButtonStyle())
            .customTooltip("Plan Route Between Locations")

            leftPaneFolderMenu

            Button { showAdvancedFilter = true } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(CompactFeatureButtonStyle())
            .customTooltip("Advanced Filters")

            Spacer()

            leftPaneMoreMenu
        }
    }

    private var leftPaneFolderMenu: some View {
        Menu {
            Button {
                selectedFolderID = nil
            } label: {
                HStack {
                    Label("All Locations", systemImage: "square.grid.2x2")
                    if selectedFolderID == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(locationManager.folders) { folder in
                Button {
                    selectedFolderID = folder.id
                } label: {
                    HStack {
                        Label(folder.name, systemImage: folder.iconName)
                        if selectedFolderID == folder.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                showFolderManagement = true
            } label: {
                Label("Manage Folders...", systemImage: "folder.badge.gearshape")
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: selectedFolderID == nil ? "folder" : "folder.fill")
                    .font(.system(size: 10))
                Text(folderMenuLabel)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
        }
        .buttonStyle(CompactFeatureButtonStyle())
        .customTooltip("Filter by Folder")
    }

    private var folderMenuLabel: String {
        if selectedFolderID == nil {
            return "All"
        }
        return locationManager.folders.first(where: { $0.id == selectedFolderID })?.name ?? "Folder"
    }

    private var leftPaneMoreMenu: some View {
        Menu {
            Button { showExportView = true } label: {
                Label("Export Locations...", systemImage: "square.and.arrow.up")
            }
            Button { showImportView = true } label: {
                Label("Import Locations...", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24)
    }

    @ViewBuilder
    private var leftPaneLocationCount: some View {
        if !filteredLocations.isEmpty {
            HStack {
                Text("\(filteredLocations.count) location\(filteredLocations.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.015))
        }
    }

    private var leftPaneLocationList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(filteredLocations) { loc in
                    LocationCard(
                        location: loc,
                        isSelected: selectedIDs.contains(loc.id),
                        action: { handleLocationSelection(loc.id) }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var rightPane: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let binding = selectedLocationBindingIfAvailable {
                    detailsForm(binding)
                } else {
                    emptyStateView
                }
            }
            .background(modernBackgroundColor)

            // Google Earth popup at bottom
            if showGoogleEarthPopup {
                googleEarthPopupPane
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "mappin.circle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.accentColor.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("No Location Selected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.8))

                Text("Select a location from the list\nto view and edit details")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if locationManager.locations.isEmpty {
                Button(action: addLocation) {
                    Label("Add Your First Location", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(ModernActionButtonStyle(color: .accentColor))
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var googleEarthPopupPane: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack(spacing: 12) {
                Image(systemName: "globe.americas.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)

                TextField("Search location in Google Earth...", text: $googleEarthURL)
                    .textFieldStyle(ModernTextFieldStyle())
                    .onSubmit {
                        // Trigger WebView reload
                    }

                Button(action: {
                    guard let id = selectedID,
                          let location = locationManager.getLocation(by: id) else { return }
                    captureGoogleEarthScreenshot(for: location)
                }) {
                    Label("Screenshot", systemImage: "camera.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(ModernIconButtonStyle())

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showGoogleEarthPopup = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.primary.opacity(0.1)),
                alignment: .bottom
            )

            // WebView
            GoogleEarthWebView(url: $googleEarthURL, webView: $googleEarthWebView)
                .frame(height: 500)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func detailsForm(_ loc: Binding<LocationItem>) -> some View {
        VStack(spacing: 0) {
            // Toolbar with view switcher
            HStack(spacing: 10) {
                // View mode picker
                HStack(spacing: 1) {
                    ForEach(LocationViewMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                currentViewMode = mode
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 10, weight: .medium))
                                Text(mode.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(currentViewMode == mode ? Color.primary.opacity(0.08) : Color.clear)
                            )
                            .foregroundStyle(currentViewMode == mode ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )

                Spacer()

                // Search Address Button
                Button {
                    isSearching.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isSearching) {
                    addressSearchPopover(loc)
                }

                PermitStatusBadge(status: loc.wrappedValue.permitStatus)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.015))

            Divider()
                .opacity(0.5)

            // Content based on view mode
            if currentViewMode == .details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Header with location name and controls
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.accentColor.gradient)

                            Text(loc.wrappedValue.name)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(1)

                            Spacer()

                            // Priority picker (compact)
                            Menu {
                                ForEach(1...5, id: \.self) { priority in
                                    Button {
                                        loc.priority.wrappedValue = priority
                                    } label: {
                                        HStack {
                                            Text("Priority \(priority)")
                                            if loc.wrappedValue.priority == priority {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    ForEach(0..<(6 - loc.wrappedValue.priority), id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                    }
                                }
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.orange.opacity(0.1))
                                )
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 60)

                            // Favorite toggle
                            Button {
                                loc.isFavorite.wrappedValue.toggle()
                            } label: {
                                Image(systemName: loc.wrappedValue.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundColor(loc.wrappedValue.isFavorite ? .yellow : .secondary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(loc.wrappedValue.isFavorite ? Color.yellow.opacity(0.15) : Color.primary.opacity(0.04))
                                    )
                            }
                            .buttonStyle(.plain)
                            .customTooltip(loc.wrappedValue.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                            // Folder picker
                            Menu {
                                Button {
                                    loc.folderID.wrappedValue = nil
                                } label: {
                                    Label("No Folder", systemImage: "folder")
                                }
                                Divider()
                                ForEach(locationManager.folders) { folder in
                                    Button {
                                        loc.folderID.wrappedValue = folder.id
                                    } label: {
                                        Label(folder.name, systemImage: folder.iconName)
                                    }
                                }
                            } label: {
                                Image(systemName: loc.wrappedValue.folderID != nil ? "folder.fill" : "folder")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(Color.primary.opacity(0.04))
                                    )
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 28)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                        // Location Photos Section (storyboard-style inline viewer)
                        locationPhotosSection(loc)

                // Basic Information Card (with address field)
                ModernCard(title: "Basic Information", icon: "info.circle.fill") {
                    VStack(spacing: 12) {
                        // Row 1: Name, Location in Film, Address, Contact, Phone, Email - inline style
                        HStack(spacing: 6) {
                            CompactField(label: "Name", text: loc.name)
                            CompactField(label: "In Film", text: loc.locationInFilm)
                            HStack(spacing: 2) {
                                CompactField(label: "Address", text: loc.address)
                                if loc.wrappedValue.latitude != nil && loc.wrappedValue.longitude != nil {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.green)
                                }
                            }
                            CompactField(label: "Contact", text: loc.contact)
                            CompactField(label: "Phone", text: loc.phone)
                            CompactField(label: "Email", text: loc.email)
                        }

                        // Row 2: Permit Status, Scout Date, Scouted checkbox, Notes
                        HStack(spacing: 8) {
                            // Permit Status - compact
                            Picker("", selection: loc.permitStatus) {
                                Text("Pending").tag("Pending")
                                Text("Scout").tag("Needs Scout")
                                Text("Approved").tag("Approved")
                                Text("Denied").tag("Denied")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .fixedSize()

                            Divider().frame(height: 20)

                            // Scout Date
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                let dateBinding = Binding<Date>(
                                    get: { loc.wrappedValue.dateToScout ?? Date() },
                                    set: {
                                        loc.wrappedValue.dateToScout = $0
                                        syncScoutDateToCalendar(location: loc.wrappedValue)
                                    }
                                )
                                DatePicker("", selection: dateBinding, displayedComponents: [.date])
                                    .labelsHidden()
                                    .fixedSize()
                            }

                            // Scouted checkbox
                            HStack(spacing: 4) {
                                Toggle("", isOn: loc.scouted)
                                    .labelsHidden()
                                    #if os(macOS)
                                    .toggleStyle(.checkbox)
                                    #endif
                                Text("Scouted")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Divider().frame(height: 20)

                            // Notes field (takes remaining space)
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                TextField("Notes...", text: loc.notes)
                                    .font(.system(size: 12))
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(4)
                        }
                    }
                }

                // Assigned Tasks Card - synced with Tasks app
                LocationAssignmentsView(locationID: loc.wrappedValue.id)

                // Location Scouting Questionnaire Card
                LocationScoutingQuestionnaireView(location: loc)

                // Parking Map Card
                ModernCard(title: "Parking Map", icon: "car.fill") {
                    VStack(spacing: 12) {
                        if loc.wrappedValue.parkingMapImageData != nil {
                            // Display map with annotations
                            renderParkingMapWithAnnotations(loc.wrappedValue)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                .contextMenu {
                                    Button {
                                        showMapEditor = true
                                    } label: {
                                        Label("Edit Map", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        loc.parkingMapImageData.wrappedValue = nil
                                        loc.parkingMapAnnotations.wrappedValue = []
                                    } label: {
                                        Label("Remove Parking Map", systemImage: "trash")
                                    }
                                }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("No parking map yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(12)
                        }

                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showGoogleEarthPopup.toggle()
                                }
                            } label: {
                                Label(showGoogleEarthPopup ? "Close Google Earth" : "Search Google Earth", systemImage: showGoogleEarthPopup ? "xmark.circle.fill" : "globe.americas.fill")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ModernSecondaryButtonStyle())

                            if loc.wrappedValue.parkingMapImageData != nil {
                                Button {
                                    showMapEditor = true
                                } label: {
                                    Label("Edit Map", systemImage: "pencil.and.outline")
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ModernActionButtonStyle(color: .blue))
                            }
                        }

                        if loc.wrappedValue.parkingMapImageData != nil {
                            Text("Click on map to add text • Double-click to edit • Drag to move")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                // MARK: - Enhanced Features Section

                // Nearby Locations
                if loc.wrappedValue.latitude != nil && loc.wrappedValue.longitude != nil {
                    NearbyLocationsView(location: loc.wrappedValue) { nearby in
                        selectedIDs = [nearby.id]
                        lastSelectedID = nearby.id
                    }
                    .padding(.horizontal, 16)
                }

                // Weather Forecast for Scout Date
                LocationWeatherView(
                    scoutDate: loc.wrappedValue.dateToScout,
                    weather: loc.wrappedValue.scoutWeather
                )
                .padding(.horizontal, 16)

                // Documents Section
                LocationDocumentsView(locationID: loc.wrappedValue.id)
                    .padding(.horizontal, 16)

                // Comments Section
                LocationCommentsView(locationID: loc.wrappedValue.id)
                    .padding(.horizontal, 16)

                // Activity Log (collapsible)
                DisclosureGroup(isExpanded: $showActivityLog) {
                    ActivityLogView(locationID: loc.wrappedValue.id)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.blue.gradient)
                        Text("Activity History")
                            .font(.headline)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 20)
                }
            } else {
                // Map Editor View
                MapEditorView(location: loc, onDismiss: {
                    currentViewMode = .details
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectedLocationBindingIfAvailable: Binding<LocationItem>? {
        guard let id = selectedID,
              let location = locationManager.getLocation(by: id) else { return nil }
        return Binding<LocationItem>(
            get: {
                // Re-fetch by ID to ensure we have the current location
                locationManager.getLocation(by: id) ?? location
            },
            set: { locationManager.updateLocation($0) }
        )
    }

    // MARK: - Address Search Popover
    private func addressSearchPopover(_ loc: Binding<LocationItem>) -> some View {
        VStack(spacing: 12) {
            // Provider picker
            Picker("", selection: $selectedProvider) {
                Label("Apple Maps", systemImage: "map.fill").tag(MapProvider.apple)
                Label("Google", systemImage: "globe").tag(MapProvider.google)
            }
            .pickerStyle(.segmented)

            // Search field
            HStack(spacing: 8) {
                TextField("Search for a place or address...", text: $ac.query)
                    .textFieldStyle(ModernTextFieldStyle())
                    .onSubmit { performSearch(into: loc) }

                Button {
                    performSearch(into: loc)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(ModernIconButtonStyle())
                .disabled(ac.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Autocomplete results
            if !ac.results.isEmpty && !ac.query.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(ac.results, id: \.self) { suggestion in
                            Button {
                                resolve(completion: suggestion, into: loc)
                                isSearching = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.body.weight(.medium))
                                            .foregroundColor(.primary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(16)
        .frame(width: 350)
    }

    // MARK: - Location Photos Section (Storyboard-style)
    private func locationPhotosSection(_ loc: Binding<LocationItem>) -> some View {
        VStack(spacing: 0) {
            // Photos toolbar header
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Location Photos")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))

                if !loc.imageDatas.wrappedValue.isEmpty {
                    Text("\(loc.imageDatas.wrappedValue.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }

                Spacer()

                // Zoom controls (only when photos exist)
                if !loc.imageDatas.wrappedValue.isEmpty {
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                photoZoomLevel = max(minPhotoZoom, photoZoomLevel - 0.25)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(photoZoomLevel > minPhotoZoom ? Color.secondary : Color.secondary.opacity(0.4))
                        .disabled(photoZoomLevel <= minPhotoZoom)

                        Text("\(Int(photoZoomLevel * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 36)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                photoZoomLevel = min(maxPhotoZoom, photoZoomLevel + 0.25)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(photoZoomLevel < maxPhotoZoom ? Color.secondary : Color.secondary.opacity(0.4))
                        .disabled(photoZoomLevel >= maxPhotoZoom)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }

                Button {
                    importTargetID = loc.wrappedValue.id
                    isImportingImages = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(CompactFeatureButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Photos content area
            if loc.imageDatas.wrappedValue.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No photos yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Click \"Add Photos\" to import location images")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.primary.opacity(0.02))
            } else {
                // Two-panel view: thumbnails on left, selected photo on right
                let baseHeight: CGFloat = 280
                let scaledHeight = baseHeight * photoZoomLevel

                HStack(spacing: 0) {
                    // Left: Thumbnail strip
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(loc.imageDatas.wrappedValue.enumerated()), id: \.offset) { index, data in
                                photoThumbnail(data: data, index: index, isSelected: selectedPhotoIndex == index)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedPhotoIndex = index
                                        }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                var datas = loc.imageDatas.wrappedValue
                                                datas.remove(at: index)
                                                loc.imageDatas.wrappedValue = datas
                                                if selectedPhotoIndex == index {
                                                    selectedPhotoIndex = datas.isEmpty ? nil : max(0, index - 1)
                                                } else if let selected = selectedPhotoIndex, selected > index {
                                                    selectedPhotoIndex = selected - 1
                                                }
                                            }
                                        } label: {
                                            Label("Remove Photo", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 120)
                    .background(Color.primary.opacity(0.02))

                    Divider()

                    // Right: Selected photo viewer (height scales with zoom)
                    ZStack {
                        Color.black.opacity(0.85)

                        if let index = selectedPhotoIndex, index < loc.imageDatas.wrappedValue.count {
                            let data = loc.imageDatas.wrappedValue[index]
                            #if os(macOS)
                            if let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: scaledHeight - 40)
                                    .padding(20)
                            }
                            #else
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: scaledHeight - 40)
                                    .padding(20)
                            }
                            #endif
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Select a photo")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        // Navigation arrows
                        if let index = selectedPhotoIndex {
                            HStack {
                                if index > 0 {
                                    Button {
                                        withAnimation { selectedPhotoIndex = index - 1 }
                                    } label: {
                                        Image(systemName: "chevron.left.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                                if index < loc.imageDatas.wrappedValue.count - 1 {
                                    Button {
                                        withAnimation { selectedPhotoIndex = index + 1 }
                                    } label: {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: scaledHeight)
                .animation(.easeInOut(duration: 0.2), value: photoZoomLevel)
            }
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .onAppear {
            // Auto-select first photo if available
            if selectedPhotoIndex == nil && !loc.imageDatas.wrappedValue.isEmpty {
                selectedPhotoIndex = 0
            }
        }
    }

    private func photoThumbnail(data: Data, index: Int, isSelected: Bool) -> some View {
        Group {
            #if os(macOS)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 70)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.blue : Color.primary.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1), radius: isSelected ? 4 : 2, y: 1)
            }
            #else
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 70)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.blue : Color.primary.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1), radius: isSelected ? 4 : 2, y: 1)
            }
            #endif
        }
    }

    // MARK: - Actions
    private func handleLocationSelection(_ id: UUID) {
        #if os(macOS)
        let shiftPressed = NSEvent.modifierFlags.contains(.shift)
        let commandPressed = NSEvent.modifierFlags.contains(.command)

        if commandPressed {
            // Command+Click: Toggle selection
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
                lastSelectedID = id
            }
        } else if shiftPressed, let lastID = lastSelectedID {
            // Shift+Click: Range selection
            guard let lastIndex = filteredLocations.firstIndex(where: { $0.id == lastID }),
                  let currentIndex = filteredLocations.firstIndex(where: { $0.id == id }) else {
                selectedIDs = [id]
                lastSelectedID = id
                return
            }

            let range = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
            let rangeIDs = filteredLocations[range].map { $0.id }
            selectedIDs.formUnion(rangeIDs)
        } else {
            // Normal click: Single selection
            selectedIDs = [id]
            lastSelectedID = id
        }
        #else
        // iOS: Simple single selection
        selectedIDs = [id]
        lastSelectedID = id
        #endif
    }

    private func addLocation() {
        let new = LocationItem(name: "New Location")
        locationManager.addLocation(new)
        selectedIDs = [new.id]
        lastSelectedID = new.id
    }

    private func deleteSelected() {
        guard !selectedIDs.isEmpty else { return }
        for id in selectedIDs {
            if let location = locationManager.getLocation(by: id) {
                locationManager.deleteLocation(location)
            }
        }
        selectedIDs = []
        lastSelectedID = nil
    }

    private func syncScoutDateToCalendar(location: LocationItem) {
        guard let scoutDate = location.dateToScout else { return }

        // Create a calendar event for the scout date
        #if os(macOS)
        NotificationCenter.default.post(
            name: Notification.Name("createCalendarEvent"),
            object: nil,
            userInfo: [
                "title": "Scout Location: \(location.name)",
                "startDate": scoutDate,
                "endDate": Calendar.current.date(byAdding: .hour, value: 2, to: scoutDate) ?? scoutDate,
                "location": location.address,
                "notes": "Location scouting for \(location.name)\nContact: \(location.contact)\nPhone: \(location.phone)",
                "isAllDay": false
            ]
        )
        #endif
    }

    private func captureGoogleEarthScreenshot(for location: LocationItem) {
        #if os(macOS)
        guard let webView = googleEarthWebView else { return }

        // Use WKWebView's snapshot API to capture the WebView content
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds

        webView.takeSnapshot(with: config) { image, error in
            guard let image = image else { return }

            // Crop to remove black bars
            let croppedImage = self.cropToVisibleContent(image)

            // Resize to fit 8.5x11 horizontal (1122x792 points at 72 DPI)
            let targetSize = NSSize(width: 1122, height: 792)
            let resizedImage = self.resizeImage(croppedImage, to: targetSize)

            // Convert to PNG data
            guard let tiffData = resizedImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

            // Update the location with the parking map data
            var updatedLocation = location
            updatedLocation.parkingMapImageData = pngData
            self.locationManager.updateLocation(updatedLocation)

            // Close the popup
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.showGoogleEarthPopup = false
                }
            }
        }
        #endif
    }

    #if os(macOS)
    private func cropToVisibleContent(_ image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let width = cgImage.width
        let height = cgImage.height
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return image
        }

        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow

        // Find non-black boundaries
        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = bytes[offset]
                let g = bytes[offset + 1]
                let b = bytes[offset + 2]

                // Check if pixel is not black (with small tolerance)
                if r > 10 || g > 10 || b > 10 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        // Add small padding
        let padding = 5
        minX = max(0, minX - padding)
        maxX = min(width - 1, maxX + padding)
        minY = max(0, minY - padding)
        maxY = min(height - 1, maxY + padding)

        // Crop to found boundaries
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
        return croppedImage
    }

    private func resizeImage(_ image: NSImage, to targetSize: NSSize) -> NSImage {
        let sourceSize = image.size
        let widthRatio = targetSize.width / sourceSize.width
        let heightRatio = targetSize.height / sourceSize.height
        let scaleFactor = min(widthRatio, heightRatio)

        let scaledWidth = sourceSize.width * scaleFactor
        let scaledHeight = sourceSize.height * scaleFactor

        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()

        NSColor.white.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        let x = (targetSize.width - scaledWidth) / 2
        let y = (targetSize.height - scaledHeight) / 2
        let destRect = NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight)

        image.draw(in: destRect, from: NSRect(origin: .zero, size: sourceSize), operation: .sourceOver, fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }
    #endif

    // MARK: - Maps
    private func resolve(completion: MKLocalSearchCompletion, into loc: Binding<LocationItem>) {
        isSearching = true
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            guard error == nil, let item = response?.mapItems.first else { return }

            let resolvedName = item.name ?? completion.title
            loc.name.wrappedValue = resolvedName

            var formattedAddress = ""
            if let postal = item.placemark.postalAddress {
                let formatter = CNPostalAddressFormatter()
                formatter.style = .mailingAddress
                formattedAddress = formatter.string(from: postal)
                    .replacingOccurrences(of: "\n", with: ", ")
            } else {
                let pieces = [
                    item.placemark.subThoroughfare,
                    item.placemark.thoroughfare,
                    item.placemark.locality,
                    item.placemark.administrativeArea,
                    item.placemark.postalCode,
                    item.placemark.country
                ].compactMap { $0 }.joined(separator: ", ")
                formattedAddress = pieces.isEmpty ? completion.title : pieces
            }
            loc.address.wrappedValue = formattedAddress
            loc.contact.wrappedValue = item.placemark.name ?? resolvedName
            if let phone = item.phoneNumber, !phone.isEmpty { loc.phone.wrappedValue = phone }
            let coord = item.placemark.coordinate
            loc.latitude.wrappedValue = coord.latitude
            loc.longitude.wrappedValue = coord.longitude
            if let url = item.url?.absoluteString, !url.isEmpty {
                let trimmed = loc.notes.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { loc.notes.wrappedValue = url }
                else if !trimmed.contains(url) { loc.notes.wrappedValue += "\n" + url }
            }

            // Collapse suggestions after selection
            ac.results = []
            ac.query = ""
        }
    }

    private func performSearch(into loc: Binding<LocationItem>) {
        let raw = ac.query.isEmpty ? searchQuery : ac.query
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        let search = MKLocalSearch(request: req)
        search.start { response, error in
            isSearching = false
            guard error == nil, let item = response?.mapItems.first else { return }

            let resolvedName = item.name ?? query
            loc.name.wrappedValue = resolvedName

            var formattedAddress = ""
            if let postal = item.placemark.postalAddress {
                let formatter = CNPostalAddressFormatter()
                formatter.style = .mailingAddress
                formattedAddress = formatter.string(from: postal)
                    .replacingOccurrences(of: "\n", with: ", ")
            } else {
                let pieces = [
                    item.placemark.subThoroughfare,
                    item.placemark.thoroughfare,
                    item.placemark.locality,
                    item.placemark.administrativeArea,
                    item.placemark.postalCode,
                    item.placemark.country
                ].compactMap { $0 }.joined(separator: ", ")
                formattedAddress = pieces.isEmpty ? resolvedName : pieces
            }
            loc.address.wrappedValue = formattedAddress
            loc.contact.wrappedValue = item.placemark.name ?? resolvedName

            if let phone = item.phoneNumber, !phone.isEmpty {
                loc.phone.wrappedValue = phone
            }

            let coord = item.placemark.coordinate
            loc.latitude.wrappedValue = coord.latitude
            loc.longitude.wrappedValue = coord.longitude

            if let url = item.url?.absoluteString, !url.isEmpty {
                let trimmed = loc.notes.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    loc.notes.wrappedValue = url
                } else if !trimmed.contains(url) {
                    loc.notes.wrappedValue += "\n" + url
                }
            }
        }
    }

    // MARK: - Styling
    private var modernBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor).opacity(0.5)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private func photoThumb(from data: Data) -> Image {
        #if os(macOS)
        if let ns = NSImage(data: data) { return Image(nsImage: ns) }
        return Image(systemName: "photo")
        #else
        if let ui = UIImage(data: data) { return Image(uiImage: ui) }
        return Image(systemName: "photo")
        #endif
    }

    private func parkingImageFromData(_ data: Data) -> Image? {
        #if os(macOS)
        if let ns = NSImage(data: data) {
            return Image(nsImage: ns)
        }
        return nil
        #else
        if let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }
        return nil
        #endif
    }

    private func renderParkingMapWithAnnotations(_ location: LocationItem) -> some View {
        #if os(macOS)
        if let binding = selectedLocationBindingIfAvailable {
            return AnyView(InteractiveParkingMapView(location: binding))
        } else {
            return AnyView(EmptyView())
        }
        #else
        return AnyView(EmptyView())
        #endif
    }

    // MARK: - PDF Support
    #if os(macOS)
    struct PDFKitView: NSViewRepresentable {
        let document: PDFDocument?
        func makeNSView(context: Context) -> PDFView {
            let view = PDFView()
            view.autoScales = true
            view.displayMode = .singlePageContinuous
            view.displayDirection = .vertical
            view.document = document
            return view
        }
        func updateNSView(_ view: PDFView, context: Context) {
            view.document = document
        }
    }
    #else
    struct PDFKitView: UIViewRepresentable {
        let document: PDFDocument?
        func makeUIView(context: Context) -> PDFView {
            let view = PDFView()
            view.autoScales = true
            view.displayMode = .singlePageContinuous
            view.displayDirection = .vertical
            view.document = document
            return view
        }
        func updateUIView(_ view: PDFView, context: Context) {
            view.document = document
        }
    }
    #endif

    struct PDFContainer: View {
        let resourceName: String
        let fileExtension: String
        var body: some View {
            if let doc = loadDocument() {
                PDFKitView(document: doc)
            } else {
                ZStack {
                    Color.primary.opacity(0.03)
                    VStack(spacing: 12) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        VStack(spacing: 4) {
                            Text("PDF Not Found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Add \"\(resourceName).\(fileExtension)\" to Copy Bundle Resources")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(24)
                }
                .frame(minHeight: 200)
            }
        }
        private func loadDocument() -> PDFDocument? {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else { return nil }
            return PDFDocument(url: url)
        }
    }
}

// MARK: - Modern UI Components

struct LocationCard: View {
    let location: LocationItem
    let isSelected: Bool
    let action: () -> Void

    var statusColor: Color {
        switch location.permitStatus {
        case "Approved": return .green
        case "Denied": return .red
        case "Needs Scout": return .orange
        default: return .blue
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Status indicator circle with icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor.gradient : statusColor.opacity(0.15).gradient)
                        .frame(width: 42, height: 42)

                    Image(systemName: location.isFavorite ? "star.circle.fill" : "mappin.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : (location.isFavorite ? .yellow : statusColor))
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Name row
                    HStack(spacing: 5) {
                        Text(location.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if location.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.yellow)
                        }
                    }

                    // Address row
                    if !location.address.isEmpty {
                        Text(location.address)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Status metadata row
                    HStack(spacing: 8) {
                        // Status pill
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 5, height: 5)
                            Text(location.permitStatus)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(statusColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(4)

                        if location.scouted {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 9))
                                Text("Scouted")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.green)
                        }

                        if let scoutDate = location.dateToScout {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 9))
                                Text(scoutDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer(minLength: 8)

                // Right side indicators
                VStack(alignment: .trailing, spacing: 6) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                    }

                    // Priority stars (only show for high priority)
                    if location.priority <= 2 {
                        HStack(spacing: 2) {
                            ForEach(0..<(4 - location.priority), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct ModernCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))
            }

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

struct ModernFormField: View {
    let label: String
    @Binding var text: String
    let icon: String
    var autocapitalize: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            TextField(label, text: $text)
                .textFieldStyle(ModernTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(autocapitalize ? .words : .never)
                .autocorrectionDisabled(!autocapitalize)
                #endif
        }
    }
}

// Compact inline field for dense layouts
struct CompactField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.8))
                .textCase(.uppercase)
                .tracking(0.3)
            TextField(label, text: $text)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

struct ModernActionButtonStyle: ButtonStyle {
    let color: Color
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.18 : 0.12))
            )
            .foregroundColor(isDestructive ? .red : color)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.18 : 0.1))
            )
            .foregroundColor(.accentColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.15 : 0.1))
            )
            .foregroundColor(.accentColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct FeatureToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.05))
            .foregroundColor(.secondary)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompactToolbarButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
            .foregroundColor(color)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompactFeatureButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
            .foregroundColor(.secondary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct PermitStatusBadge: View {
    let status: String

    var statusColor: Color {
        switch status {
        case "Approved": return .green
        case "Denied": return .red
        case "Needs Scout": return .orange
        default: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(status)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(statusColor.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Google Earth WebView with Screenshot Capability
#if os(macOS)
struct GoogleEarthWebView: NSViewRepresentable {
    @Binding var url: String
    @Binding var webView: WKWebView?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsMagnification = true

        // Store reference to webView
        DispatchQueue.main.async {
            self.webView = webView
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let targetURL = URL(string: url) else { return }

        // Only load if no page loaded yet or host changed - prevents reloading during form submissions
        if nsView.url == nil {
            let request = URLRequest(url: targetURL)
            nsView.load(request)
        } else if let currentURL = nsView.url,
                  currentURL.host != targetURL.host {
            let request = URLRequest(url: targetURL)
            nsView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: GoogleEarthWebView

        init(_ parent: GoogleEarthWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == false {
                if let url = navigationAction.request.url {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
#else
struct GoogleEarthWebView: UIViewRepresentable {
    @Binding var url: String
    @Binding var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        DispatchQueue.main.async {
            self.webView = webView
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let targetURL = URL(string: url) else { return }

        // Only load if no page loaded yet or host changed
        if uiView.url == nil {
            let request = URLRequest(url: targetURL)
            uiView.load(request)
        } else if let currentURL = uiView.url,
                  currentURL.host != targetURL.host {
            let request = URLRequest(url: targetURL)
            uiView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: GoogleEarthWebView

        init(_ parent: GoogleEarthWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == false {
                if let url = navigationAction.request.url {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
#endif

// MARK: - Interactive Parking Map View
struct InteractiveParkingMapView: View {
    @Binding var location: LocationItem
    @State private var selectedAnnotationID: UUID?
    @State private var showTextEditor: Bool = false
    @State private var showFormatting: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    // Base map image
                    if let parkingData = location.parkingMapImageData {
                        #if os(macOS)
                        if let nsImage = NSImage(data: parkingData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .onTapGesture { location in
                                    addAnnotationAt(point: location, in: geometry.size)
                                }
                        }
                        #else
                        if let uiImage = UIImage(data: parkingData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .onTapGesture { location in
                                    addAnnotationAt(point: location, in: geometry.size)
                                }
                        }
                        #endif
                    }

                    // Draggable annotations
                    ForEach(location.parkingMapAnnotations.indices, id: \.self) { index in
                        DraggableAnnotationView(
                            annotation: $location.parkingMapAnnotations[index],
                            isSelected: location.parkingMapAnnotations[index].id == selectedAnnotationID,
                            geometrySize: geometry.size,
                            onSelect: {
                                selectedAnnotationID = location.parkingMapAnnotations[index].id
                            },
                            onDelete: {
                                location.parkingMapAnnotations.remove(at: index)
                                selectedAnnotationID = nil
                            }
                        )
                    }
                }
            }
            .frame(height: 400)

            // Formatting toolbar for selected annotation
            if let selectedID = selectedAnnotationID,
               let index = location.parkingMapAnnotations.firstIndex(where: { $0.id == selectedID }) {
                FormattingToolbar(annotation: $location.parkingMapAnnotations[index])
            }
        }
    }

    private func addAnnotationAt(point: CGPoint, in size: CGSize) {
        let newAnnotation = ParkingMapAnnotation(
            text: "Double-click to edit",
            x: Double(point.x / size.width),
            y: Double(point.y / size.height)
        )
        location.parkingMapAnnotations.append(newAnnotation)
        selectedAnnotationID = newAnnotation.id
    }
}

// MARK: - Draggable Annotation View
struct DraggableAnnotationView: View {
    @Binding var annotation: ParkingMapAnnotation
    let isSelected: Bool
    let geometrySize: CGSize
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isDragging = false
    @State private var isEditing = false
    @State private var editText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                TextField("Text", text: $editText, onCommit: {
                    annotation.text = editText
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.custom(annotation.fontName, size: CGFloat(annotation.fontSize)))
                .foregroundColor(Color(hex: annotation.textColorHex) ?? .black)
                .padding(8)
                .background(Color(hex: annotation.backgroundColorHex) ?? .white)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: 2)
                )
            } else {
                Text(annotation.text)
                    .font(.custom(annotation.fontName, size: CGFloat(annotation.fontSize)))
                    .foregroundColor(Color(hex: annotation.textColorHex) ?? .black)
                    .padding(8)
                    .background(Color(hex: annotation.backgroundColorHex) ?? .white)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? 2 : 0)
                    )
                    .onTapGesture {
                        onSelect()
                    }
                    .onTapGesture(count: 2) {
                        editText = annotation.text
                        isEditing = true
                    }
                    .contextMenu {
                        Button("Edit") {
                            editText = annotation.text
                            isEditing = true
                        }
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    }
            }
        }
        .position(
            x: geometrySize.width * CGFloat(annotation.x),
            y: geometrySize.height * CGFloat(annotation.y)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let newX = value.location.x / geometrySize.width
                    let newY = value.location.y / geometrySize.height
                    annotation.x = Double(max(0, min(1, newX)))
                    annotation.y = Double(max(0, min(1, newY)))
                    onSelect()
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

// MARK: - Formatting Toolbar
struct FormattingToolbar: View {
    @Binding var annotation: ParkingMapAnnotation

    var body: some View {
        HStack(spacing: 12) {
            // Text color
            ColorPicker("", selection: Binding(
                get: { Color(hex: annotation.textColorHex) ?? .black },
                set: { annotation.textColorHex = $0.toHex() ?? "#000000" }
            ))
            .labelsHidden()
            .frame(width: 40)

            Text("BG:")
                .font(.caption)
                .foregroundColor(.secondary)

            // Background color
            ColorPicker("", selection: Binding(
                get: { Color(hex: annotation.backgroundColorHex) ?? .white },
                set: { annotation.backgroundColorHex = $0.toHex() ?? "#FFFFFF" }
            ))
            .labelsHidden()
            .frame(width: 40)

            Divider()
                .frame(height: 20)

            // Font picker
            Picker("", selection: $annotation.fontName) {
                Text("Helvetica").tag("Helvetica")
                Text("Helvetica Bold").tag("Helvetica-Bold")
                Text("Arial").tag("Arial")
                Text("Arial Bold").tag("Arial-Bold")
            }
            .frame(width: 120)

            // Font size
            Stepper("\(Int(annotation.fontSize))pt", value: $annotation.fontSize, in: 12...72, step: 2)
                .frame(width: 100)

            Spacer()
        }
        .padding(8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Annotation Editor View
struct AnnotationEditorView: View {
    @Binding var annotation: ParkingMapAnnotation?
    @Binding var location: LocationItem
    @Binding var isPresented: Bool

    @State private var text: String = ""
    @State private var textColor: Color = .black
    @State private var backgroundColor: Color = .white
    @State private var fontSize: Double = 24
    @State private var fontName: String = "Helvetica"
    @State private var xPosition: Double = 0.5
    @State private var yPosition: Double = 0.5

    let availableFonts = ["Helvetica", "Helvetica-Bold", "Arial", "Arial-Bold", "Courier", "Courier-Bold", "Times New Roman", "Times-Bold"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Text Annotation")
                .font(.title2.bold())
                .padding(.top, 20)

            Form {
                Section("Text Content") {
                    TextField("Enter text", text: $text)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Text Color") {
                    ColorPicker("Text Color", selection: $textColor)
                }

                Section("Background Color") {
                    ColorPicker("Background Color", selection: $backgroundColor)
                }

                Section("Font") {
                    Picker("Font Family", selection: $fontName) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Size: \(Int(fontSize))")
                            .font(.caption)
                        Slider(value: $fontSize, in: 12...72, step: 1)
                    }
                }

                Section("Position") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("X Position: \(Int(xPosition * 100))%")
                            .font(.caption)
                        Slider(value: $xPosition, in: 0...1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Y Position: \(Int(yPosition * 100))%")
                            .font(.caption)
                        Slider(value: $yPosition, in: 0...1)
                    }
                }

                Section("Preview") {
                    HStack {
                        Spacer()
                        Text(text.isEmpty ? "Preview" : text)
                            .font(.custom(fontName, size: CGFloat(fontSize)))
                            .foregroundColor(textColor)
                            .padding(8)
                            .background(backgroundColor)
                            .cornerRadius(4)
                        Spacer()
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveAnnotation()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let ann = annotation {
                text = ann.text
                textColor = Color(hex: ann.textColorHex) ?? .black
                backgroundColor = Color(hex: ann.backgroundColorHex) ?? .white
                fontSize = ann.fontSize
                fontName = ann.fontName
                xPosition = ann.x
                yPosition = ann.y
            }
        }
    }

    private func saveAnnotation() {
        let newAnnotation = ParkingMapAnnotation(
            id: annotation?.id ?? UUID(),
            text: text,
            x: xPosition,
            y: yPosition,
            textColorHex: textColor.toHex() ?? "#000000",
            fontName: fontName,
            fontSize: fontSize,
            backgroundColorHex: backgroundColor.toHex() ?? "#FFFFFF"
        )

        // Update or add annotation
        if let existingIndex = location.parkingMapAnnotations.firstIndex(where: { $0.id == newAnnotation.id }) {
            location.parkingMapAnnotations[existingIndex] = newAnnotation
        } else {
            location.parkingMapAnnotations.append(newAnnotation)
        }

        isPresented = false
    }
}

// MARK: - Map Editor View
struct MapEditorView: View {
    @Binding var location: LocationItem
    var isPresented: Binding<Bool>?
    var onDismiss: (() -> Void)?

    @State private var selectedAnnotationID: UUID?
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedTool: MapEditorTool = .select
    @State private var showColorPicker: Bool = false
    @State private var newAnnotationText: String = ""
    @State private var currentTextColor: Color = .black
    @State private var currentBackgroundColor: Color = .white
    @State private var currentFontSize: Double = 24
    @State private var currentFontName: String = "Helvetica-Bold"

    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 4.0

    enum MapEditorTool: String, CaseIterable {
        case select = "Select"
        case addText = "Add Text"
        case addArrow = "Arrow"
        case addCircle = "Circle"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Main content
            HStack(spacing: 0) {
                // Left sidebar - Tools
                toolsSidebar

                Divider()

                // Main canvas
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.9)

                        // Map canvas with zoom and pan
                        mapCanvas(in: geometry)
                    }
                }

                Divider()

                // Right sidebar - Properties
                if selectedAnnotationID != nil {
                    propertiesSidebar
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundStyle(.blue.gradient)

            Text("Map Editor")
                .font(.title2.bold())

            Text("– \(location.name)")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    withAnimation { zoomScale = max(minZoom, zoomScale - 0.25) }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(ModernIconButtonStyle())

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 50)

                Button {
                    withAnimation { zoomScale = min(maxZoom, zoomScale + 0.25) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(ModernIconButtonStyle())

                Button {
                    withAnimation {
                        zoomScale = 1.0
                        offset = .zero
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(ModernIconButtonStyle())
                .customTooltip("Reset View")
            }

            Divider()
                .frame(height: 24)

            Button {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    isPresented?.wrappedValue = false
                }
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(ModernActionButtonStyle(color: .blue))
        }
        .padding(16)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Tools Sidebar
    private var toolsSidebar: some View {
        VStack(spacing: 16) {
            Text("Tools")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(MapEditorTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: iconForTool(tool))
                                .font(.body)
                                .frame(width: 24)
                            Text(tool.rawValue)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTool == tool ? Color.blue.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedTool == tool ? .blue : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Quick actions
            VStack(spacing: 8) {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    // Clear all annotations
                    location.parkingMapAnnotations.removeAll()
                    selectedAnnotationID = nil
                } label: {
                    Label("Clear All", systemImage: "trash")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernSecondaryButtonStyle())
            }

            Spacer()

            // Annotation count
            VStack(spacing: 4) {
                Text("\(location.parkingMapAnnotations.count)")
                    .font(.title.bold())
                    .foregroundColor(.blue)
                Text("Annotations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
        }
        .padding(16)
        .frame(width: 180)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Properties Sidebar
    private var propertiesSidebar: some View {
        VStack(spacing: 16) {
            Text("Properties")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let selectedID = selectedAnnotationID,
               let index = location.parkingMapAnnotations.firstIndex(where: { $0.id == selectedID }) {
                VStack(alignment: .leading, spacing: 12) {
                    // Text content
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter text", text: $location.parkingMapAnnotations[index].text)
                            .textFieldStyle(ModernTextFieldStyle())
                    }

                    Divider()

                    // Colors
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Text Color")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: location.parkingMapAnnotations[index].textColorHex) ?? .black },
                                set: { location.parkingMapAnnotations[index].textColorHex = $0.toHex() ?? "#000000" }
                            ))
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Background")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: location.parkingMapAnnotations[index].backgroundColorHex) ?? .white },
                                set: { location.parkingMapAnnotations[index].backgroundColorHex = $0.toHex() ?? "#FFFFFF" }
                            ))
                            .labelsHidden()
                        }
                    }

                    Divider()

                    // Font
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Font")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $location.parkingMapAnnotations[index].fontName) {
                            Text("Helvetica").tag("Helvetica")
                            Text("Helvetica Bold").tag("Helvetica-Bold")
                            Text("Arial").tag("Arial")
                            Text("Arial Bold").tag("Arial-Bold")
                            Text("Courier").tag("Courier")
                            Text("Marker Felt").tag("Marker Felt")
                        }
                        .labelsHidden()
                    }

                    // Font size
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Size: \(Int(location.parkingMapAnnotations[index].fontSize))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $location.parkingMapAnnotations[index].fontSize, in: 12...72, step: 2)
                    }

                    Divider()

                    // Delete button
                    Button(role: .destructive) {
                        location.parkingMapAnnotations.remove(at: index)
                        selectedAnnotationID = nil
                    } label: {
                        Label("Delete Annotation", systemImage: "trash")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ModernActionButtonStyle(color: .red, isDestructive: true))
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 220)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Map Canvas
    private func mapCanvas(in geometry: GeometryProxy) -> some View {
        ZStack {
            if let parkingData = location.parkingMapImageData {
                #if os(macOS)
                if let nsImage = NSImage(data: parkingData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoomScale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if selectedTool == .select {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastZoomScale * value
                                    zoomScale = min(max(newScale, minZoom), maxZoom)
                                }
                                .onEnded { _ in
                                    lastZoomScale = zoomScale
                                }
                        )
                        .onTapGesture { location in
                            if selectedTool == .addText {
                                addTextAnnotation(at: location, in: geometry.size)
                            } else {
                                selectedAnnotationID = nil
                            }
                        }
                }
                #endif
            }

            // Annotations overlay
            ForEach(location.parkingMapAnnotations.indices, id: \.self) { index in
                MapEditorAnnotationView(
                    annotation: $location.parkingMapAnnotations[index],
                    isSelected: location.parkingMapAnnotations[index].id == selectedAnnotationID,
                    zoomScale: zoomScale,
                    offset: offset,
                    containerSize: geometry.size,
                    onSelect: {
                        selectedAnnotationID = location.parkingMapAnnotations[index].id
                        selectedTool = .select
                    },
                    onDelete: {
                        location.parkingMapAnnotations.remove(at: index)
                        selectedAnnotationID = nil
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Helper Functions
    private func iconForTool(_ tool: MapEditorTool) -> String {
        switch tool {
        case .select: return "cursorarrow"
        case .addText: return "textformat"
        case .addArrow: return "arrow.right"
        case .addCircle: return "circle"
        }
    }

    private func addTextAnnotation(at point: CGPoint, in size: CGSize) {
        // Calculate position relative to the image considering zoom and offset
        let centerX = size.width / 2 + offset.width
        let centerY = size.height / 2 + offset.height

        let relativeX = (point.x - centerX) / zoomScale + size.width / 2
        let relativeY = (point.y - centerY) / zoomScale + size.height / 2

        let newAnnotation = ParkingMapAnnotation(
            text: "New Label",
            x: Double(relativeX / size.width),
            y: Double(relativeY / size.height),
            textColorHex: currentTextColor.toHex() ?? "#000000",
            fontName: currentFontName,
            fontSize: currentFontSize,
            backgroundColorHex: currentBackgroundColor.toHex() ?? "#FFFFFF"
        )
        location.parkingMapAnnotations.append(newAnnotation)
        selectedAnnotationID = newAnnotation.id
        selectedTool = .select
    }
}

// MARK: - Map Editor Annotation View
struct MapEditorAnnotationView: View {
    @Binding var annotation: ParkingMapAnnotation
    let isSelected: Bool
    let zoomScale: CGFloat
    let offset: CGSize
    let containerSize: CGSize
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isEditing: Bool = false
    @State private var editText: String = ""

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $editText, onCommit: {
                    annotation.text = editText
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.custom(annotation.fontName, size: CGFloat(annotation.fontSize) * zoomScale))
                .foregroundColor(Color(hex: annotation.textColorHex) ?? .black)
                .padding(8 * zoomScale)
                .background(Color(hex: annotation.backgroundColorHex) ?? .white)
                .cornerRadius(4 * zoomScale)
                .overlay(
                    RoundedRectangle(cornerRadius: 4 * zoomScale)
                        .stroke(Color.blue, lineWidth: 2)
                )
            } else {
                Text(annotation.text)
                    .font(.custom(annotation.fontName, size: CGFloat(annotation.fontSize) * zoomScale))
                    .foregroundColor(Color(hex: annotation.textColorHex) ?? .black)
                    .padding(8 * zoomScale)
                    .background(Color(hex: annotation.backgroundColorHex) ?? .white)
                    .cornerRadius(4 * zoomScale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4 * zoomScale)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? 2 : 0)
                    )
                    .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 8)
                    .onTapGesture {
                        onSelect()
                    }
                    .onTapGesture(count: 2) {
                        editText = annotation.text
                        isEditing = true
                    }
            }
        }
        .position(
            x: containerSize.width / 2 + offset.width + (containerSize.width * CGFloat(annotation.x) - containerSize.width / 2) * zoomScale,
            y: containerSize.height / 2 + offset.height + (containerSize.height * CGFloat(annotation.y) - containerSize.height / 2) * zoomScale
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Update annotation position
                    let centerX = containerSize.width / 2 + offset.width
                    let centerY = containerSize.height / 2 + offset.height

                    let newX = (value.location.x - centerX) / zoomScale + containerSize.width / 2
                    let newY = (value.location.y - centerY) / zoomScale + containerSize.height / 2

                    annotation.x = Double(max(0, min(1, newX / containerSize.width)))
                    annotation.y = Double(max(0, min(1, newY / containerSize.height)))
                    onSelect()
                }
        )
    }
}

// MARK: - Photo Collage View
struct PhotoCollageView: View {
    @Binding var imageDatas: [Data]
    @State private var selectedPhotoIndex: Int?
    @State private var showFullScreen: Bool = false

    private let spacing: CGFloat = 8
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            gridView
        }
        .sheet(isPresented: $showFullScreen) {
            photoDetailSheet
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(imageDatas.enumerated()), id: \.offset) { index, data in
                    photoThumbnailView(index: index, data: data)
                }
            }
            .padding(spacing)
        }
        .frame(maxHeight: 400)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }

    private func photoThumbnailView(index: Int, data: Data) -> some View {
        PhotoThumbnail(
            imageData: data,
            index: index,
            height: randomHeight(for: index)
        )
        .onTapGesture {
            selectedPhotoIndex = index
            showFullScreen = true
        }
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    var array = imageDatas
                    array.remove(at: index)
                    imageDatas = array
                }
            } label: {
                Label("Remove Photo", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var photoDetailSheet: some View {
        if let index = selectedPhotoIndex {
            PhotoDetailView(
                imageDatas: $imageDatas,
                currentIndex: index,
                isPresented: $showFullScreen
            )
        }
    }

    // Create varying heights for masonry effect
    private func randomHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [140, 180, 160, 200, 150, 170]
        return heights[index % heights.count]
    }
}

// MARK: - Photo Thumbnail
struct PhotoThumbnail: View {
    let imageData: Data
    let index: Int
    let height: CGFloat

    var body: some View {
        Group {
            #if os(macOS)
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            } else {
                placeholderView
            }
            #else
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            } else {
                placeholderView
            }
            #endif
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .frame(height: height)
            .overlay(
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.secondary)
            )
    }
}

// MARK: - Photo Detail View
struct PhotoDetailView: View {
    @Binding var imageDatas: [Data]
    @State var currentIndex: Int
    @Binding var isPresented: Bool

    // Zoom state
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 5.0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Photo \(currentIndex + 1) of \(imageDatas.count)")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Zoom controls
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomScale = max(minZoom, zoomScale - 0.25)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.body)
                    }
                    .buttonStyle(ModernIconButtonStyle())
                    .disabled(zoomScale <= minZoom)

                    Text("\(Int(zoomScale * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 50)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomScale = min(maxZoom, zoomScale + 0.25)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.body)
                    }
                    .buttonStyle(ModernIconButtonStyle())
                    .disabled(zoomScale >= maxZoom)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomScale = 1.0
                            offset = .zero
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                    }
                    .buttonStyle(ModernIconButtonStyle())
                    .customTooltip("Reset Zoom")
                }
                .padding(.horizontal, 12)

                Divider()
                    .frame(height: 24)

                Button(role: .destructive) {
                    withAnimation {
                        imageDatas.remove(at: currentIndex)
                        if imageDatas.isEmpty {
                            isPresented = false
                        } else if currentIndex >= imageDatas.count {
                            currentIndex = imageDatas.count - 1
                        }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(ModernActionButtonStyle(color: .red, isDestructive: true))

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Photo viewer with navigation
            ZStack {
                Color.black.opacity(0.85)

                HStack(spacing: 0) {
                    // Previous button
                    if currentIndex > 0 {
                        Button {
                            withAnimation {
                                currentIndex -= 1
                                resetZoom()
                            }
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    } else {
                        Spacer()
                            .frame(width: 84)
                    }

                    // Current photo with zoom
                    Spacer()

                    GeometryReader { geometry in
                        ZStack {
                            Group {
                                #if os(macOS)
                                if let nsImage = NSImage(data: imageDatas[currentIndex]) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                }
                                #else
                                if let uiImage = UIImage(data: imageDatas[currentIndex]) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                }
                                #endif
                            }
                            .scaleEffect(zoomScale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastZoomScale * value
                                        zoomScale = min(max(newScale, minZoom), maxZoom)
                                    }
                                    .onEnded { _ in
                                        lastZoomScale = zoomScale
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if zoomScale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if zoomScale > 1.0 {
                                        resetZoom()
                                    } else {
                                        zoomScale = 2.0
                                        lastZoomScale = 2.0
                                    }
                                }
                            }
                            #if os(macOS)
                            .onContinuousHover { _ in }
                            .background(
                                ScrollWheelZoomView(
                                    zoomScale: $zoomScale,
                                    minZoom: minZoom,
                                    maxZoom: maxZoom,
                                    onZoomEnd: { lastZoomScale = zoomScale }
                                )
                            )
                            #endif
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }
                    .padding(40)

                    Spacer()

                    // Next button
                    if currentIndex < imageDatas.count - 1 {
                        Button {
                            withAnimation {
                                currentIndex += 1
                                resetZoom()
                            }
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    } else {
                        Spacer()
                            .frame(width: 84)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func resetZoom() {
        zoomScale = 1.0
        lastZoomScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Scroll Wheel Zoom (macOS)
#if os(macOS)
struct ScrollWheelZoomView: NSViewRepresentable {
    @Binding var zoomScale: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onZoomEnd: () -> Void

    func makeNSView(context: Context) -> ScrollWheelZoomNSView {
        let view = ScrollWheelZoomNSView()
        view.onScroll = { delta in
            let newScale = zoomScale + delta * 0.01
            zoomScale = min(max(newScale, minZoom), maxZoom)
            onZoomEnd()
        }
        return view
    }

    func updateNSView(_ nsView: ScrollWheelZoomNSView, context: Context) {}
}

class ScrollWheelZoomNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        // Use deltaY for vertical scroll (zooming)
        let delta = event.deltaY
        if abs(delta) > 0.1 {
            onScroll?(delta)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
#endif

// MARK: - Color Extensions
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        #if os(macOS)
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        #else
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        #endif
    }
}

// MARK: - Location Scouting Questionnaire
struct LocationScoutingQuestionnaireView: View {
    @Binding var location: LocationItem

    @State private var expandedSections: Set<String> = ["general"]

    // Questionnaire responses (stored in location.notes as JSON or structured format)
    @State private var responses: [String: String] = [:]

    var body: some View {
        ModernCard(title: "Location Scouting Report", icon: "doc.text.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Complete this questionnaire during your location scout")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                    // General Information
                    QuestionnaireSection(title: "General Information", icon: "info.circle.fill", isExpanded: expandedSections.contains("general")) {
                        expandedSections.toggle("general")
                    } content: {
                        QuestionField(question: "Location Name", response: $responses["location_name"], placeholder: location.name)
                        QuestionField(question: "Address", response: $responses["address"], placeholder: location.address)
                        QuestionField(question: "GPS Coordinates", response: $responses["gps"], placeholder: "Latitude, Longitude")
                        QuestionField(question: "Property Owner/Contact", response: $responses["owner"], placeholder: location.contact)
                        QuestionField(question: "Owner Phone/Email", response: $responses["owner_contact"], placeholder: location.phone)
                        YesNoField(question: "Permission to film obtained?", response: $responses["permission"])
                        QuestionField(question: "Filming Hours Allowed", response: $responses["filming_hours"], placeholder: "e.g., 7 AM - 10 PM")
                    }

                    // Accessibility & Parking
                    QuestionnaireSection(title: "Accessibility & Parking", icon: "car.fill", isExpanded: expandedSections.contains("parking")) {
                        expandedSections.toggle("parking")
                    } content: {
                        YesNoField(question: "Accessible by vehicles?", response: $responses["vehicle_access"])
                        QuestionField(question: "Road conditions to location", response: $responses["road_conditions"], placeholder: "Paved, gravel, dirt, etc.")
                        YesNoField(question: "Parking available for crew?", response: $responses["crew_parking"])
                        QuestionField(question: "Estimated parking spaces", response: $responses["parking_spaces"], placeholder: "Number of spaces")
                        YesNoField(question: "Parking for equipment trucks?", response: $responses["truck_parking"])
                        QuestionField(question: "Distance from parking to set", response: $responses["parking_distance"], placeholder: "e.g., 50 feet")
                        YesNoField(question: "Loading/unloading zone available?", response: $responses["loading_zone"])
                    }

                    // Power & Utilities
                    QuestionnaireSection(title: "Power & Utilities", icon: "bolt.fill", isExpanded: expandedSections.contains("power")) {
                        expandedSections.toggle("power")
                    } content: {
                        YesNoField(question: "Power available on location?", response: $responses["power_available"])
                        QuestionField(question: "Power source details", response: $responses["power_details"], placeholder: "Type, voltage, amperage")
                        QuestionField(question: "Number of outlets available", response: $responses["outlets"], placeholder: "Count")
                        YesNoField(question: "Generator needed?", response: $responses["generator_needed"])
                        YesNoField(question: "Water access available?", response: $responses["water_access"])
                        YesNoField(question: "Restroom facilities available?", response: $responses["restrooms"])
                        QuestionField(question: "Nearest restrooms", response: $responses["restroom_location"], placeholder: "On-site or distance away")
                    }

                    // Sound & Noise
                    QuestionnaireSection(title: "Sound & Noise", icon: "speaker.wave.2.fill", isExpanded: expandedSections.contains("sound")) {
                        expandedSections.toggle("sound")
                    } content: {
                        QuestionField(question: "Ambient noise level (1-10)", response: $responses["noise_level"], placeholder: "1 = quiet, 10 = very loud")
                        QuestionField(question: "Noise sources", response: $responses["noise_sources"], placeholder: "Traffic, construction, planes, etc.")
                        YesNoField(question: "Flight path overhead?", response: $responses["flight_path"])
                        YesNoField(question: "Nearby traffic/highway?", response: $responses["nearby_traffic"])
                        QuestionField(question: "Quietest time of day", response: $responses["quiet_times"], placeholder: "e.g., Early morning")
                        YesNoField(question: "Sound blankets/dampening needed?", response: $responses["sound_dampening"])
                    }

                    // Lighting & Natural Light
                    QuestionnaireSection(title: "Lighting & Natural Light", icon: "sun.max.fill", isExpanded: expandedSections.contains("lighting")) {
                        expandedSections.toggle("lighting")
                    } content: {
                        QuestionField(question: "Direction property faces", response: $responses["facing_direction"], placeholder: "North, South, East, West")
                        QuestionField(question: "Sunrise time observed", response: $responses["sunrise"], placeholder: "Time")
                        QuestionField(question: "Sunset time observed", response: $responses["sunset"], placeholder: "Time")
                        QuestionField(question: "Natural light quality", response: $responses["natural_light"], placeholder: "Harsh, soft, filtered, etc.")
                        YesNoField(question: "Windows with good light?", response: $responses["good_windows"])
                        YesNoField(question: "Existing practical lights?", response: $responses["practical_lights"])
                        QuestionField(question: "Additional lighting needs", response: $responses["lighting_needs"], placeholder: "Describe requirements")
                    }

                    // Space & Layout
                    QuestionnaireSection(title: "Space & Layout", icon: "square.grid.2x2.fill", isExpanded: expandedSections.contains("space")) {
                        expandedSections.toggle("space")
                    } content: {
                        QuestionField(question: "Room dimensions (if applicable)", response: $responses["dimensions"], placeholder: "Length x Width x Height")
                        QuestionField(question: "Ceiling height", response: $responses["ceiling_height"], placeholder: "Feet")
                        YesNoField(question: "Sufficient space for equipment?", response: $responses["equipment_space"])
                        YesNoField(question: "Space for video village?", response: $responses["video_village_space"])
                        YesNoField(question: "Blocking/movement space adequate?", response: $responses["blocking_space"])
                        QuestionField(question: "Furniture/set dressing present", response: $responses["furniture"], placeholder: "Describe what's there")
                    }

                    // Weather & Environmental
                    QuestionnaireSection(title: "Weather & Environmental", icon: "cloud.sun.fill", isExpanded: expandedSections.contains("weather")) {
                        expandedSections.toggle("weather")
                    } content: {
                        QuestionField(question: "Current weather conditions", response: $responses["weather_current"], placeholder: "Sunny, cloudy, rainy, etc.")
                        QuestionField(question: "Temperature", response: $responses["temperature"], placeholder: "Degrees")
                        YesNoField(question: "Cover available if raining?", response: $responses["rain_cover"])
                        YesNoField(question: "Shade available for crew?", response: $responses["shade"])
                        QuestionField(question: "Wind conditions", response: $responses["wind"], placeholder: "Calm, breezy, windy")
                        YesNoField(question: "Weather contingency needed?", response: $responses["weather_contingency"])
                    }

                    // Permits & Restrictions
                    QuestionnaireSection(title: "Permits & Restrictions", icon: "doc.badge.gearshape.fill", isExpanded: expandedSections.contains("permits")) {
                        expandedSections.toggle("permits")
                    } content: {
                        YesNoField(question: "Filming permit required?", response: $responses["permit_required"])
                        QuestionField(question: "Permit contact/department", response: $responses["permit_contact"], placeholder: "Who to contact")
                        QuestionField(question: "Permit cost", response: $responses["permit_cost"], placeholder: "Dollar amount")
                        QuestionField(question: "Insurance requirements", response: $responses["insurance"], placeholder: "Amount and type")
                        YesNoField(question: "Restrictions on crew size?", response: $responses["crew_restrictions"])
                        YesNoField(question: "Restrictions on equipment?", response: $responses["equipment_restrictions"])
                        QuestionField(question: "Filming hours restrictions", response: $responses["hours_restrictions"], placeholder: "Any time limits")
                        YesNoField(question: "Neighbors need notification?", response: $responses["neighbor_notice"])
                    }

                    // Safety & Security
                    QuestionnaireSection(title: "Safety & Security", icon: "shield.fill", isExpanded: expandedSections.contains("safety")) {
                        expandedSections.toggle("safety")
                    } content: {
                        YesNoField(question: "Location safe for cast/crew?", response: $responses["safe_location"])
                        QuestionField(question: "Safety concerns", response: $responses["safety_concerns"], placeholder: "Hazards, risks, etc.")
                        YesNoField(question: "First aid accessible?", response: $responses["first_aid"])
                        QuestionField(question: "Nearest hospital/medical", response: $responses["nearest_hospital"], placeholder: "Name and distance")
                        YesNoField(question: "Security personnel needed?", response: $responses["security_needed"])
                        YesNoField(question: "Fire safety equipment present?", response: $responses["fire_safety"])
                        QuestionField(question: "Emergency exits marked?", response: $responses["emergency_exits"], placeholder: "Yes/No/How many")
                    }

                    // Cost & Fees
                    QuestionnaireSection(title: "Cost & Fees", icon: "dollarsign.circle.fill", isExpanded: expandedSections.contains("costs")) {
                        expandedSections.toggle("costs")
                    } content: {
                        QuestionField(question: "Location fee", response: $responses["location_fee"], placeholder: "Amount per day")
                        QuestionField(question: "Prep/strike days cost", response: $responses["prep_cost"], placeholder: "Amount")
                        QuestionField(question: "Overtime rates", response: $responses["overtime"], placeholder: "Rate after hours")
                        QuestionField(question: "Damage deposit required", response: $responses["deposit"], placeholder: "Amount")
                        QuestionField(question: "Additional fees", response: $responses["additional_fees"], placeholder: "Cleaning, security, etc.")
                        QuestionField(question: "Payment terms", response: $responses["payment_terms"], placeholder: "When payment is due")
                    }

                    // Additional Notes
                    QuestionnaireSection(title: "Additional Notes & Observations", icon: "note.text", isExpanded: expandedSections.contains("notes")) {
                        expandedSections.toggle("notes")
                    } content: {
                        LongFormField(question: "Overall impressions", response: $responses["impressions"])
                        LongFormField(question: "Challenges/concerns", response: $responses["challenges"])
                        LongFormField(question: "Advantages/benefits", response: $responses["advantages"])
                        LongFormField(question: "Additional notes", response: $responses["additional_notes"])
                    }
                }
                .padding()
            }
            .frame(maxHeight: 500)
        }
        .onAppear {
            loadResponses()
        }
        .onChange(of: responses) { _ in
            saveResponses()
        }
    }

    private func loadResponses() {
        // Load responses from location.notes (could be JSON encoded)
        // For now, initialize empty
    }

    private func saveResponses() {
        // Save responses to location.notes
        // Could encode as JSON
    }
}

// MARK: - Questionnaire Section
struct QuestionnaireSection<Content: View>: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(.leading, 24)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
}

// MARK: - Question Field
struct QuestionField: View {
    let question: String
    @Binding var response: String?
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.subheadline)
                .foregroundColor(.primary)
            TextField(placeholder, text: Binding(
                get: { response ?? "" },
                set: { response = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
        }
    }
}

// MARK: - Yes/No Field
struct YesNoField: View {
    let question: String
    @Binding var response: String?

    var body: some View {
        HStack {
            Text(question)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    response = "Yes"
                } label: {
                    Text("Yes")
                        .font(.subheadline)
                        .foregroundColor(response == "Yes" ? .white : .green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(response == "Yes" ? Color.green : Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button {
                    response = "No"
                } label: {
                    Text("No")
                        .font(.subheadline)
                        .foregroundColor(response == "No" ? .white : .red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(response == "No" ? Color.red : Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Long Form Field
struct LongFormField: View {
    let question: String
    @Binding var response: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.subheadline)
                .foregroundColor(.primary)
            TextEditor(text: Binding(
                get: { response ?? "" },
                set: { response = $0.isEmpty ? nil : $0 }
            ))
            .frame(minHeight: 80)
            .padding(4)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
        }
    }
}

// Helper for Set toggle
extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

