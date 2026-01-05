// MARK: - Call Sheet Editor View
// Production Runner - Call Sheet Module
// Main editor interface with Celtx-style minimal white design

import SwiftUI
import UniformTypeIdentifiers
import CoreData

#if os(macOS)
import AppKit

// MARK: - Call Sheet Editor View

struct CallSheetEditorView: View {
    @Binding var callSheet: CallSheet
    let onClose: () -> Void
    let onSave: (CallSheet) -> Void

    @State private var editingSheet: CallSheet
    @State private var showBottomPanel = true
    @State private var showPreview = true
    @State private var bottomPanelHeight: CGFloat = 200
    @State private var previewZoom: CGFloat = 1.0
    @State private var selectedSection: CallSheetSectionType?
    @State private var collapsedSections: Set<CallSheetSectionType> = []
    @State private var isDragging = false
    @State private var draggedSection: CallSheetSectionType?
    @State private var showDeliverySheet = false
    @State private var deliveryPDFData: Data?

    init(callSheet: Binding<CallSheet>, onClose: @escaping () -> Void, onSave: @escaping (CallSheet) -> Void) {
        self._callSheet = callSheet
        self.onClose = onClose
        self.onSave = onSave
        self._editingSheet = State(initialValue: callSheet.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            EditorToolbar(
                title: editingSheet.title,
                status: editingSheet.status,
                onClose: onClose,
                onSave: { onSave(editingSheet) },
                onExport: exportPDF,
                onSend: showDeliveryView,
                showBottomPanel: $showBottomPanel,
                showPreview: $showPreview
            )

            Divider()

            // Main Content Area
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Left: Main Editor
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: CallSheetDesign.sectionSpacing) {
                                ForEach(editingSheet.visibleSections, id: \.self) { section in
                                    sectionView(for: section)
                                        .id(section)
                                }
                            }
                            .padding(CallSheetDesign.cardPadding)
                        }
                        .onChange(of: selectedSection) { newSection in
                            if let section = newSection {
                                withAnimation {
                                    proxy.scrollTo(section, anchor: .top)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .callSheetBackground()

                    // Right: PDF Preview
                    if showPreview {
                        Divider()

                        PDFPreviewPanel(
                            callSheet: editingSheet,
                            zoom: $previewZoom
                        )
                        .frame(minWidth: 320, idealWidth: 400)
                    }
                }

                // Bottom: Section Navigator
                if showBottomPanel {
                    Divider()

                    SectionNavigatorHorizontal(
                        callSheet: $editingSheet,
                        selectedSection: $selectedSection,
                        collapsedSections: $collapsedSections
                    )
                    .frame(height: bottomPanelHeight)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .sheet(isPresented: $showDeliverySheet) {
            if let pdfData = deliveryPDFData {
                CallSheetDeliveryView(
                    callSheet: editingSheet,
                    pdfData: pdfData,
                    onDismiss: { showDeliverySheet = false }
                )
            }
        }
    }

    // MARK: - Section View Builder

    @ViewBuilder
    private func sectionView(for section: CallSheetSectionType) -> some View {
        switch section {
        case .header:
            HeaderSectionView(callSheet: $editingSheet)
        case .productionInfo:
            ProductionInfoSectionView(callSheet: $editingSheet)
        case .callTimes:
            CallTimesSectionView(callSheet: $editingSheet)
        case .location:
            CallSheetLocationSectionView(callSheet: $editingSheet)
        case .weather:
            WeatherSectionView(callSheet: $editingSheet)
        case .schedule:
            ScheduleSectionView(callSheet: $editingSheet)
        case .cast:
            CastSectionView(callSheet: $editingSheet)
        case .crew:
            CrewSectionView(callSheet: $editingSheet)
        case .background:
            BackgroundActorsSectionView(callSheet: $editingSheet)
        case .productionNotes:
            ProductionNotesSectionView(callSheet: $editingSheet)
        case .advanceSchedule:
            AdvanceScheduleSectionView(callSheet: $editingSheet)
        case .safetyInfo:
            SafetyInfoSectionView(callSheet: $editingSheet)
        }
    }

    // MARK: - Export PDF

    private func exportPDF() {
        let pageSize = CGSize(width: 612, height: 792)
        let printLayout = CallSheetPrintLayout(callSheet: editingSheet)

        let hosting = NSHostingView(rootView: printLayout.frame(width: pageSize.width, height: pageSize.height))
        hosting.frame = CGRect(origin: .zero, size: pageSize)
        let data = hosting.dataWithPDF(inside: hosting.bounds)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = sanitizedFileName(from: editingSheet.title) + ".pdf"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                print("PDF export failed: \(error)")
            }
        }
    }

    private func sanitizedFileName(from string: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return string.components(separatedBy: invalid).joined().replacingOccurrences(of: "\n", with: " ")
    }

    // MARK: - Send Call Sheet

    private func showDeliveryView() {
        // Generate PDF data for delivery
        let pageSize = CGSize(width: 612, height: 792)
        let printLayout = CallSheetPrintLayout(callSheet: editingSheet)

        let hosting = NSHostingView(rootView: printLayout.frame(width: pageSize.width, height: pageSize.height))
        hosting.frame = CGRect(origin: .zero, size: pageSize)
        let data = hosting.dataWithPDF(inside: hosting.bounds)

        deliveryPDFData = data
        showDeliverySheet = true
    }
}

// MARK: - Editor Toolbar

struct EditorToolbar: View {
    let title: String
    let status: CallSheetStatus
    let onClose: () -> Void
    let onSave: () -> Void
    let onExport: () -> Void
    let onSend: () -> Void
    @Binding var showBottomPanel: Bool
    @Binding var showPreview: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Back Button
            Button(action: onClose) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(CallSheetDesign.accent)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 24)

            // Title & Status
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(CallSheetDesign.textPrimary)

                CallSheetStatusBadge(status: status)
            }

            Spacer()

            // View Toggles
            HStack(spacing: 4) {
                ToolbarToggleButton(
                    icon: "rectangle.bottomthird.inset.filled",
                    isActive: showBottomPanel,
                    action: { showBottomPanel.toggle() },
                    tooltip: "Toggle Sections Panel"
                )

                ToolbarToggleButton(
                    icon: "sidebar.right",
                    isActive: showPreview,
                    action: { showPreview.toggle() },
                    tooltip: "Toggle PDF Preview"
                )
            }

            Divider()
                .frame(height: 24)

            // Export Button
            Button(action: onExport) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 12, weight: .medium))
                    Text("Export PDF")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(CallSheetDesign.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CallSheetDesign.accent.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("e", modifiers: [.command])

            // Send Button
            Button(action: onSend) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("Send")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Save Button
            Button(action: onSave) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(CallSheetDesign.accent)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: [.command])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(CallSheetDesign.cardBackground)
    }
}

struct ToolbarToggleButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    let tooltip: String

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isActive ? CallSheetDesign.accent : CallSheetDesign.textTertiary)
                .frame(width: 32, height: 32)
                .background(isActive ? CallSheetDesign.accent.opacity(0.1) : CallSheetDesign.textTertiary.opacity(0.08))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Section Navigator

struct SectionNavigator: View {
    @Binding var callSheet: CallSheet
    @Binding var selectedSection: CallSheetSectionType?
    @Binding var collapsedSections: Set<CallSheetSectionType>

    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SECTIONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .tracking(0.5)

                Spacer()

                Button(action: { isEditing.toggle() }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundColor(isEditing ? .green : CallSheetDesign.textTertiary)
                }
                .buttonStyle(.plain)
                .help(isEditing ? "Done Editing" : "Edit Sections")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CallSheetDesign.sectionHeader)

            Divider()

            // Section List
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(callSheet.sectionOrder, id: \.self) { section in
                        SectionNavigatorRow(
                            section: section,
                            isSelected: selectedSection == section,
                            isVisible: callSheet.sectionConfigs.first { $0.sectionType == section }?.isVisible ?? true,
                            isEditing: isEditing,
                            onSelect: { selectedSection = section },
                            onToggleVisibility: { callSheet.toggleSection(section) }
                        )
                    }
                    .onMove { source, destination in
                        callSheet.sectionOrder.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .padding(8)
            }

            Divider()

            // Template Info
            HStack {
                Image(systemName: callSheet.templateType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(CallSheetDesign.accent)

                Text(callSheet.templateType.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(CallSheetDesign.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(CallSheetDesign.sectionHeader)
        }
        .background(CallSheetDesign.cardBackground)
    }
}

struct SectionNavigatorRow: View {
    let section: CallSheetSectionType
    let isSelected: Bool
    let isVisible: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                // Drag Handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(CallSheetDesign.textTertiary)
                    .frame(width: 16)

                // Visibility Toggle
                Button(action: onToggleVisibility) {
                    Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundColor(isVisible ? CallSheetDesign.accent : CallSheetDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Icon
            Image(systemName: section.icon)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? CallSheetDesign.accent : CallSheetDesign.textSecondary)
                .frame(width: 18)

            // Title
            Text(section.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isVisible ? CallSheetDesign.textPrimary : CallSheetDesign.textTertiary)

            Spacer()

            if !isEditing && isSelected {
                Circle()
                    .fill(CallSheetDesign.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? CallSheetDesign.accent.opacity(0.08) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .opacity(isVisible || isEditing ? 1.0 : 0.5)
    }
}

// MARK: - Section Navigator Horizontal (Bottom Panel)

struct SectionNavigatorHorizontal: View {
    @Binding var callSheet: CallSheet
    @Binding var selectedSection: CallSheetSectionType?
    @Binding var collapsedSections: Set<CallSheetSectionType>

    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text("SECTIONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .tracking(0.5)

                Spacer()

                // Template Info
                HStack(spacing: 6) {
                    Image(systemName: callSheet.templateType.icon)
                        .font(.system(size: 11))
                        .foregroundColor(CallSheetDesign.accent)

                    Text(callSheet.templateType.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CallSheetDesign.textSecondary)
                }

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 8)

                Button(action: { isEditing.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text(isEditing ? "Done" : "Edit")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isEditing ? .green : CallSheetDesign.textTertiary)
                }
                .buttonStyle(.plain)
                .help(isEditing ? "Done Editing" : "Edit Sections")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CallSheetDesign.sectionHeader)

            Divider()

            // Horizontal Section List
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(callSheet.sectionOrder, id: \.self) { section in
                        SectionNavigatorChip(
                            section: section,
                            isSelected: selectedSection == section,
                            isVisible: callSheet.sectionConfigs.first { $0.sectionType == section }?.isVisible ?? true,
                            isEditing: isEditing,
                            onSelect: { selectedSection = section },
                            onToggleVisibility: { callSheet.toggleSection(section) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(CallSheetDesign.cardBackground)
    }
}

struct SectionNavigatorChip: View {
    let section: CallSheetSectionType
    let isSelected: Bool
    let isVisible: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isEditing {
                // Visibility Toggle
                Button(action: onToggleVisibility) {
                    Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 10))
                        .foregroundColor(isVisible ? CallSheetDesign.accent : CallSheetDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Icon
            Image(systemName: section.icon)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white : CallSheetDesign.textSecondary)

            // Title
            Text(section.rawValue)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : (isVisible ? CallSheetDesign.textPrimary : CallSheetDesign.textTertiary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? CallSheetDesign.accent : CallSheetDesign.sectionHeader)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? CallSheetDesign.accent : CallSheetDesign.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .opacity(isVisible || isEditing ? 1.0 : 0.5)
    }
}

// MARK: - PDF Preview Panel

struct PDFPreviewPanel: View {
    let callSheet: CallSheet
    @Binding var zoom: CGFloat

    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792

    init(callSheet: CallSheet, zoom: Binding<CGFloat>) {
        self.callSheet = callSheet
        self._zoom = zoom
        print("📄 PDFPreviewPanel: Initialized with '\(callSheet.title)'")
        print("📄 PDFPreviewPanel: scheduleItems.count = \(callSheet.scheduleItems.count)")
        if callSheet.scheduleItems.count > 0 {
            print("📄 PDFPreviewPanel: First item = '\(callSheet.scheduleItems[0].intExt.rawValue). \(callSheet.scheduleItems[0].setDescription)'")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 12))
                    .foregroundColor(CallSheetDesign.accent)

                Text("PDF PREVIEW")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .tracking(0.5)

                Spacer()

                // Zoom Controls
                HStack(spacing: 4) {
                    Button(action: { zoom = max(zoom - 0.1, 0.3) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CallSheetDesign.textSecondary)
                            .frame(width: 20, height: 20)
                            .background(CallSheetDesign.sectionHeader)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(zoom * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(CallSheetDesign.textSecondary)
                        .frame(width: 36)

                    Button(action: { zoom = min(zoom + 0.1, 1.2) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CallSheetDesign.textSecondary)
                            .frame(width: 20, height: 20)
                            .background(CallSheetDesign.sectionHeader)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(CallSheetDesign.sectionHeader)

            Divider()

            // Preview Content
            ScrollView([.horizontal, .vertical]) {
                VStack {
                    CallSheetPrintLayout(callSheet: callSheet)
                        .frame(width: pageWidth, height: pageHeight)
                        .background(Color.white) // PDF preview always white (paper simulation)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        .scaleEffect(zoom)
                        .frame(width: pageWidth * zoom, height: pageHeight * zoom)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(CallSheetDesign.background)
        }
    }
}

// MARK: - Template Selection Sheet

struct TemplateSelectionSheet: View {
    @Binding var selectedTemplate: CallSheetTemplateType
    let onSelect: (CallSheetTemplateType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose a Template")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            .background(CallSheetDesign.sectionHeader)

            Divider()

            // Templates Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(CallSheetTemplateType.allCases) { template in
                        TemplatePickerCard(
                            template: template,
                            isSelected: selectedTemplate == template,
                            action: {
                                selectedTemplate = template
                            }
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                CallSheetButton(title: "Cancel", style: .secondary) { dismiss() }
                CallSheetButton(title: "Use Template", icon: "checkmark", style: .primary) {
                    onSelect(selectedTemplate)
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - New Call Sheet Sheet

struct NewCallSheetSheet: View {
    @Binding var isPresented: Bool
    let onCreate: (CallSheet) -> Void

    @Environment(\.managedObjectContext) private var moc

    @State private var title = "Untitled Call Sheet"
    @State private var selectedTemplate: CallSheetTemplateType = .featureFilm
    @State private var shootDate = Date()
    @State private var selectedShootDay: ShootDayEntity?
    @State private var shootDays: [ShootDayEntity] = []

    // Import from Breakdowns
    @State private var importSource: ImportSource = .none
    @State private var availableScenes: [SceneEntity] = []
    @State private var selectedSceneIDs: Set<UUID> = []
    @State private var showScenePicker = false

    enum ImportSource: Equatable {
        case none
        case schedule
        case breakdowns
    }

    /// Computed property: only shoot days that have scenes assigned
    private var shootDaysWithScenes: [ShootDayEntity] {
        shootDays.filter { day in
            guard let scenes = day.scenes as? Set<SceneEntity> else { return false }
            return !scenes.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Call Sheet")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CallSheetDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(CallSheetDesign.sectionHeader)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        TextField("Call Sheet Title", text: $title)
                            .font(.system(size: 16))
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(CallSheetDesign.sectionHeader)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(CallSheetDesign.border, lineWidth: 1)
                            )
                    }

                    // Import Scenes Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IMPORT SCENES")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        // Import source picker
                        HStack(spacing: 8) {
                            ImportSourceButton(
                                title: "None",
                                icon: "xmark.circle",
                                isSelected: importSource == .none,
                                action: {
                                    importSource = .none
                                    selectedShootDay = nil
                                    selectedSceneIDs.removeAll()
                                }
                            )

                            // Show "From Schedule" if there are shoot days with scenes
                            if !shootDaysWithScenes.isEmpty {
                                ImportSourceButton(
                                    title: "From Schedule",
                                    icon: "calendar",
                                    isSelected: importSource == .schedule,
                                    action: { importSource = .schedule }
                                )
                            }

                            if !availableScenes.isEmpty {
                                ImportSourceButton(
                                    title: "From Breakdowns",
                                    icon: "list.bullet.rectangle",
                                    isSelected: importSource == .breakdowns,
                                    action: { importSource = .breakdowns }
                                )
                            }
                        }

                        // Info message when shoot days exist but have no scenes
                        if !shootDays.isEmpty && shootDaysWithScenes.isEmpty && importSource == .none {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(CallSheetDesign.textTertiary)
                                Text("Shoot days exist but have no scenes assigned. Use Scheduler to assign scenes to days.")
                                    .font(.system(size: 11))
                                    .foregroundColor(CallSheetDesign.textTertiary)
                            }
                            .padding(8)
                            .background(CallSheetDesign.sectionHeader.opacity(0.5))
                            .cornerRadius(6)
                        }

                        // Import from Schedule picker
                        if importSource == .schedule && !shootDaysWithScenes.isEmpty {
                            HStack(spacing: 12) {
                                Picker("", selection: $selectedShootDay) {
                                    Text("Select a shoot day...").tag(nil as ShootDayEntity?)
                                    ForEach(shootDaysWithScenes, id: \.objectID) { day in
                                        Text(shootDayLabel(day)).tag(day as ShootDayEntity?)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity)

                                if selectedShootDay != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(12)
                            .background(CallSheetDesign.sectionHeader)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedShootDay != nil ? Color.green.opacity(0.5) : CallSheetDesign.border, lineWidth: 1)
                            )

                            if let day = selectedShootDay, let scenes = day.scenes as? Set<SceneEntity> {
                                Text("\(scenes.count) scene\(scenes.count == 1 ? "" : "s") will be imported")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }

                        // Import from Breakdowns picker
                        if importSource == .breakdowns && !availableScenes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button(action: { showScenePicker = true }) {
                                        HStack {
                                            Image(systemName: "list.bullet.rectangle")
                                                .font(.system(size: 14))
                                            Text(selectedSceneIDs.isEmpty ? "Select Scenes..." : "\(selectedSceneIDs.count) scene\(selectedSceneIDs.count == 1 ? "" : "s") selected")
                                                .font(.system(size: 14))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(CallSheetDesign.textTertiary)
                                        }
                                        .foregroundColor(CallSheetDesign.textPrimary)
                                    }
                                    .buttonStyle(.plain)

                                    if !selectedSceneIDs.isEmpty {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(12)
                                .background(CallSheetDesign.sectionHeader)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(!selectedSceneIDs.isEmpty ? Color.green.opacity(0.5) : CallSheetDesign.border, lineWidth: 1)
                                )

                                // Quick actions
                                HStack(spacing: 8) {
                                    Button("Select All") {
                                        selectedSceneIDs = Set(availableScenes.compactMap { $0.id })
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(CallSheetDesign.accent)
                                    .buttonStyle(.plain)

                                    Text("·")
                                        .foregroundColor(CallSheetDesign.textTertiary)

                                    Button("Clear") {
                                        selectedSceneIDs.removeAll()
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(CallSheetDesign.textTertiary)
                                    .buttonStyle(.plain)
                                }

                                if !selectedSceneIDs.isEmpty {
                                    Text("\(selectedSceneIDs.count) scene\(selectedSceneIDs.count == 1 ? "" : "s") will be imported")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }

                    // Shoot Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SHOOT DATE")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        DatePicker("", selection: $shootDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                            .frame(maxWidth: 300)
                    }

                    // Template Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEMPLATE")
                            .font(CallSheetDesign.labelFont)
                            .foregroundColor(CallSheetDesign.textTertiary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(CallSheetTemplateType.allCases) { template in
                                TemplatePickerCard(
                                    template: template,
                                    isSelected: selectedTemplate == template,
                                    action: { selectedTemplate = template }
                                )
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                CallSheetButton(title: "Cancel", style: .secondary) {
                    isPresented = false
                }
                CallSheetButton(title: "Create Call Sheet", icon: "plus", style: .primary) {
                    var newSheet = CallSheet.empty(template: selectedTemplate)
                    newSheet.title = title
                    newSheet.shootDate = shootDate

                    print("📄 NewCallSheetSheet: Creating call sheet with importSource = \(importSource)")

                    // Import scenes based on selected source
                    switch importSource {
                    case .schedule:
                        // Import scenes from selected shoot day
                        if let shootDay = selectedShootDay, let shootDayID = shootDay.id {
                            if let project = shootDay.project {
                                print("📄 NewCallSheetSheet: Importing from schedule - shootDay \(shootDay.dayNumber)")
                                let scheduleItems = CallSheetDataService.shared.importScenesFromScheduler(
                                    shootDayID: shootDayID,
                                    projectID: project.objectID,
                                    in: moc
                                )
                                newSheet.scheduleItems = scheduleItems
                                newSheet.dayNumber = Int(shootDay.dayNumber)
                                print("📄 NewCallSheetSheet: Imported \(scheduleItems.count) items from schedule")

                                // Use shoot day date if available
                                if let dayDate = shootDay.date {
                                    newSheet.shootDate = dayDate
                                }
                            }
                        }

                    case .breakdowns:
                        // Import scenes directly from breakdowns
                        print("📄 NewCallSheetSheet: Importing from breakdowns - \(selectedSceneIDs.count) selected")
                        if !selectedSceneIDs.isEmpty {
                            let selectedScenes = availableScenes.filter { scene in
                                guard let id = scene.id else { return false }
                                return selectedSceneIDs.contains(id)
                            }
                            print("📄 NewCallSheetSheet: Found \(selectedScenes.count) matching scenes")
                            let scheduleItems = CallSheetDataService.shared.importScenesFromBreakdowns(
                                scenes: selectedScenes,
                                in: moc
                            )
                            newSheet.scheduleItems = scheduleItems
                            print("📄 NewCallSheetSheet: Imported \(scheduleItems.count) items from breakdowns")
                        }

                    case .none:
                        print("📄 NewCallSheetSheet: No import source selected")
                        break
                    }

                    print("📄 NewCallSheetSheet: Final call sheet has \(newSheet.scheduleItems.count) schedule items")
                    if newSheet.scheduleItems.count > 0 {
                        let first = newSheet.scheduleItems[0]
                        print("📄 NewCallSheetSheet: First item - scene '\(first.sceneNumber)' - '\(first.intExt.rawValue). \(first.setDescription)'")
                    }

                    onCreate(newSheet)
                    isPresented = false
                }
            }
            .padding()
        }
        .frame(width: 600, height: 750)
        .onAppear {
            loadShootDays()
            loadAvailableScenes()
        }
        .onChange(of: selectedShootDay) { newDay in
            // Auto-update title and date when shoot day is selected
            if let day = newDay {
                title = "Day \(day.dayNumber) Call Sheet"
                if let date = day.date {
                    shootDate = date
                }
            }
        }
        .sheet(isPresented: $showScenePicker) {
            ScenePickerSheet(
                scenes: availableScenes,
                selectedSceneIDs: $selectedSceneIDs,
                isPresented: $showScenePicker
            )
        }
    }

    private func loadShootDays() {
        let fetch: NSFetchRequest<ShootDayEntity> = ShootDayEntity.fetchRequest()
        fetch.sortDescriptors = [NSSortDescriptor(keyPath: \ShootDayEntity.dayNumber, ascending: true)]

        do {
            shootDays = try moc.fetch(fetch)
            print("NewCallSheetSheet: Loaded \(shootDays.count) shoot days")
            // Debug: Log scene counts for each shoot day
            for day in shootDays {
                let scenes = day.scenes as? Set<SceneEntity> ?? []
                print("  Day \(day.dayNumber): \(scenes.count) scenes")
                if scenes.count > 0 {
                    if let first = scenes.first {
                        print("    First scene: number='\(first.number ?? "nil")' slug='\(first.sceneSlug ?? "nil")'")
                    }
                }
            }
        } catch {
            print("NewCallSheetSheet: Failed to load shoot days - \(error)")
        }
    }

    private func loadAvailableScenes() {
        let fetch: NSFetchRequest<SceneEntity> = SceneEntity.fetchRequest()
        fetch.sortDescriptors = [
            NSSortDescriptor(keyPath: \SceneEntity.displayOrder, ascending: true),
            NSSortDescriptor(keyPath: \SceneEntity.createdAt, ascending: true)
        ]

        do {
            availableScenes = try moc.fetch(fetch)
            print("NewCallSheetSheet: Loaded \(availableScenes.count) available scenes for import")
        } catch {
            print("NewCallSheetSheet: Failed to load scenes - \(error)")
        }
    }

    private func shootDayLabel(_ day: ShootDayEntity) -> String {
        var label = "Day \(day.dayNumber)"
        if let scenes = day.scenes as? Set<SceneEntity>, !scenes.isEmpty {
            label += " (\(scenes.count) scene\(scenes.count == 1 ? "" : "s"))"
        }
        if let date = day.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            label += " - \(formatter.string(from: date))"
        }
        return label
    }
}

// MARK: - Import Source Button

struct ImportSourceButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : CallSheetDesign.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? CallSheetDesign.accent : CallSheetDesign.sectionHeader)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? CallSheetDesign.accent : CallSheetDesign.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scene Picker Sheet

struct ScenePickerSheet: View {
    let scenes: [SceneEntity]
    @Binding var selectedSceneIDs: Set<UUID>
    @Binding var isPresented: Bool

    @State private var searchText = ""

    private var filteredScenes: [SceneEntity] {
        if searchText.isEmpty {
            return scenes
        }
        return scenes.filter { scene in
            let number = scene.number ?? ""
            let slug = scene.sceneSlug ?? ""
            let location = scene.scriptLocation ?? ""
            let searchLower = searchText.lowercased()
            return number.lowercased().contains(searchLower) ||
                   slug.lowercased().contains(searchLower) ||
                   location.lowercased().contains(searchLower)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Scenes")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CallSheetDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(CallSheetDesign.sectionHeader)

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(CallSheetDesign.textTertiary)
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CallSheetDesign.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(CallSheetDesign.sectionHeader)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Quick actions
            HStack {
                Text("\(selectedSceneIDs.count) of \(scenes.count) selected")
                    .font(.system(size: 12))
                    .foregroundColor(CallSheetDesign.textSecondary)

                Spacer()

                Button("Select All") {
                    selectedSceneIDs = Set(scenes.compactMap { $0.id })
                }
                .font(.system(size: 12))
                .foregroundColor(CallSheetDesign.accent)
                .buttonStyle(.plain)

                Text("·")
                    .foregroundColor(CallSheetDesign.textTertiary)

                Button("Clear All") {
                    selectedSceneIDs.removeAll()
                }
                .font(.system(size: 12))
                .foregroundColor(CallSheetDesign.textTertiary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Scene list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredScenes, id: \.objectID) { scene in
                        ScenePickerRow(
                            scene: scene,
                            isSelected: scene.id != nil && selectedSceneIDs.contains(scene.id!),
                            onToggle: {
                                guard let id = scene.id else { return }
                                if selectedSceneIDs.contains(id) {
                                    selectedSceneIDs.remove(id)
                                } else {
                                    selectedSceneIDs.insert(id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                CallSheetButton(title: "Cancel", style: .secondary) {
                    isPresented = false
                }
                CallSheetButton(title: "Done", icon: "checkmark", style: .primary) {
                    isPresented = false
                }
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Scene Picker Row

struct ScenePickerRow: View {
    let scene: SceneEntity
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? CallSheetDesign.accent : CallSheetDesign.textTertiary)

                // Scene number
                Text(scene.number ?? "?")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(CallSheetDesign.textPrimary)
                    .frame(width: 40, alignment: .leading)

                // INT/EXT badge
                if let locationType = scene.locationType, !locationType.isEmpty {
                    Text(locationType.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(locationType.uppercased().contains("EXT") ? Color.yellow.opacity(0.8) : Color.blue.opacity(0.8))
                        .cornerRadius(3)
                }

                // Scene slug/location
                Text(scene.sceneSlug ?? scene.scriptLocation ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(CallSheetDesign.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Page count
                if scene.pageEighths > 0 {
                    Text(formatPageEighths(scene.pageEighths))
                        .font(.system(size: 11))
                        .foregroundColor(CallSheetDesign.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? CallSheetDesign.accent.opacity(0.08) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func formatPageEighths(_ eighths: Int16) -> String {
        let pages = eighths / 8
        let remainder = eighths % 8
        if pages > 0 && remainder > 0 {
            return "\(pages) \(remainder)/8 pg"
        } else if pages > 0 {
            return "\(pages) pg"
        } else {
            return "\(remainder)/8 pg"
        }
    }
}

#endif
