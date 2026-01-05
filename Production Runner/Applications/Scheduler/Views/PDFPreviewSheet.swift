//
//  PDFPreviewSheet.swift
//  Production Runner
//
//  Advanced PDF preview with zoom, view modes, thumbnails, and enhanced export/print
//

import SwiftUI
import PDFKit

#if os(macOS)
struct PDFPreviewSheet: View {
    let pdfDocument: PDFDocument
    let title: String
    let defaultFilename: String
    var onOrientationChange: ((Orientation) -> PDFDocument?)? = nil

    @Environment(\.dismiss) private var dismiss

    // MARK: - State Variables

    // Original
    @State private var currentPage = 0
    @State private var orientation: Orientation = .landscape
    @State private var activePDFDocument: PDFDocument?

    // Zoom Controls
    @State private var zoomLevel: CGFloat = 1.0
    @State private var autoScale: Bool = true
    @State private var fitMode: FitMode = .page

    // View Modes
    @State private var viewMode: PDFViewMode = .single
    @State private var showThumbnails: Bool = false

    // Navigation
    @State private var showPageJumper: Bool = false
    @State private var showThumbnailGrid: Bool = false

    // Export Options
    @State private var showExportOptions: Bool = false
    @State private var exportPageRange: PageRangeOption = .all
    @State private var exportStartPage: Int = 1
    @State private var exportEndPage: Int = 1
    @State private var exportQuality: ExportQuality = .high

    // Print Options
    @State private var showPrintOptions: Bool = false
    @State private var printPageRange: PageRangeOption = .all
    @State private var printStartPage: Int = 1
    @State private var printEndPage: Int = 1
    @State private var printCopies: Int = 1
    @State private var printDuplex: DuplexMode = .none

    // Annotations
    @State private var showAnnotations: Bool = false
    @State private var annotationMode: AnnotationMode = .none
    @State private var annotationColor: Color = .yellow

    // MARK: - Enums

    enum Orientation: String, CaseIterable {
        case landscape = "Landscape"
        case portrait = "Portrait"
    }

    enum FitMode: String, CaseIterable {
        case page = "Fit Page"
        case width = "Fit Width"
        case actual = "Actual Size"
    }

    enum PDFViewMode: String, CaseIterable {
        case single = "Single"
        case continuous = "Continuous"
        case twoPage = "Two-Up"
        case twoPageContinuous = "Two-Up Continuous"

        var pdfDisplayMode: PDFDisplayMode {
            switch self {
            case .single: return .singlePage
            case .continuous: return .singlePageContinuous
            case .twoPage: return .twoUp
            case .twoPageContinuous: return .twoUpContinuous
            }
        }

        var icon: String {
            switch self {
            case .single: return "doc"
            case .continuous: return "scroll"
            case .twoPage: return "doc.on.doc"
            case .twoPageContinuous: return "doc.on.doc.fill"
            }
        }
    }

    enum PageRangeOption: String, CaseIterable {
        case all = "All Pages"
        case current = "Current Page"
        case range = "Page Range"
    }

    enum ExportQuality: String, CaseIterable {
        case low = "Low (Smaller File)"
        case medium = "Medium"
        case high = "High Quality"
        case maximum = "Maximum Quality"

        var compressionQuality: CGFloat {
            switch self {
            case .low: return 0.3
            case .medium: return 0.5
            case .high: return 0.8
            case .maximum: return 1.0
            }
        }
    }

    enum DuplexMode: String, CaseIterable {
        case none = "Single-Sided"
        case longEdge = "Double-Sided (Long Edge)"
        case shortEdge = "Double-Sided (Short Edge)"
    }

    enum AnnotationMode: String, CaseIterable {
        case none = "None"
        case note = "Note"
        case highlight = "Highlight"
        case draw = "Draw"

        var icon: String {
            switch self {
            case .none: return "hand.tap"
            case .note: return "note.text"
            case .highlight: return "highlighter"
            case .draw: return "pencil.tip"
            }
        }
    }

    // MARK: - Computed Properties

    private var activeDocument: PDFDocument {
        activePDFDocument ?? pdfDocument
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Thumbnail Sidebar (optional)
            ThumbnailSidebar(
                pdfDocument: activeDocument,
                currentPage: $currentPage,
                isVisible: $showThumbnails
            )

            // Main Content
            VStack(spacing: 0) {
                headerView
                mainToolbar
                pdfContentArea
                footerView
            }

            // Annotation Panel (optional)
            AnnotationPanel(
                annotationMode: $annotationMode,
                annotationColor: $annotationColor,
                isVisible: $showAnnotations,
                onClearAll: clearAllAnnotations
            )
        }
        .frame(minWidth: 900, minHeight: 600)
        .frame(idealWidth: 1200, idealHeight: 800)
        .sheet(isPresented: $showExportOptions) {
            ExportOptionsSheet(
                isPresented: $showExportOptions,
                pageRange: $exportPageRange,
                startPage: $exportStartPage,
                endPage: $exportEndPage,
                quality: $exportQuality,
                pageCount: activeDocument.pageCount,
                onExport: performExport
            )
        }
        .sheet(isPresented: $showPrintOptions) {
            PrintOptionsSheet(
                isPresented: $showPrintOptions,
                pageRange: $printPageRange,
                startPage: $printStartPage,
                endPage: $printEndPage,
                copies: $printCopies,
                duplex: $printDuplex,
                orientation: $orientation,
                pageCount: activeDocument.pageCount,
                onPrint: performPrint
            )
        }
        .sheet(isPresented: $showThumbnailGrid) {
            ThumbnailGridView(
                pdfDocument: activeDocument,
                currentPage: $currentPage,
                isPresented: $showThumbnailGrid
            )
        }
        .onAppear {
            activePDFDocument = pdfDocument
        }
        .onChange(of: orientation) { _ in
            if let callback = onOrientationChange,
               let newPDF = callback(orientation) {
                activePDFDocument = newPDF
                currentPage = 0 // Reset to first page
            }
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("\(activeDocument.pageCount) page\(activeDocument.pageCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var mainToolbar: some View {
        HStack(spacing: 16) {
            // Sidebar toggle
            Button {
                withAnimation {
                    showThumbnails.toggle()
                }
            } label: {
                Image(systemName: showThumbnails ? "sidebar.left.fill" : "sidebar.left")
            }
            .help("Toggle Thumbnail Sidebar")

            Divider().frame(height: 20)

            // Zoom controls
            zoomControls

            Divider().frame(height: 20)

            // View mode picker
            viewModePicker

            Divider().frame(height: 20)

            // Navigation
            navigationControls

            Spacer()

            // Annotation toggle
            annotationToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(zoomLevel <= 0.25)
            .help("Zoom Out")

            Text("\(Int(zoomLevel * 100))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 50)

            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(zoomLevel >= 4.0)
            .help("Zoom In")

            Divider().frame(height: 16)

            Menu {
                ForEach(FitMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        setFitMode(mode)
                    }
                }
                Divider()
                Button("25%") { setZoom(0.25) }
                Button("50%") { setZoom(0.5) }
                Button("100%") { setZoom(1.0) }
                Button("150%") { setZoom(1.5) }
                Button("200%") { setZoom(2.0) }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)
            .help("Zoom Options")
        }
    }

    private var viewModePicker: some View {
        HStack(spacing: 4) {
            ForEach(PDFViewMode.allCases, id: \.self) { mode in
                Button {
                    viewMode = mode
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12))
                        Text(mode.rawValue)
                            .font(.system(size: 9))
                    }
                    .frame(width: 60, height: 32)
                    .background(viewMode == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(mode.rawValue)
            }
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 4) {
            // First/Previous/Next/Last buttons
            Button {
                currentPage = 0
            } label: {
                Image(systemName: "chevron.left.to.line")
            }
            .disabled(currentPage == 0)
            .help("First Page")

            Button {
                if currentPage > 0 { currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage == 0)
            .help("Previous Page")

            Button {
                if currentPage < activeDocument.pageCount - 1 { currentPage += 1 }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPage >= activeDocument.pageCount - 1)
            .help("Next Page")

            Button {
                currentPage = activeDocument.pageCount - 1
            } label: {
                Image(systemName: "chevron.right.to.line")
            }
            .disabled(currentPage >= activeDocument.pageCount - 1)
            .help("Last Page")

            Divider().frame(height: 16)

            // Page indicator with jump capability
            Button {
                showPageJumper.toggle()
            } label: {
                Text("Page \(currentPage + 1) of \(activeDocument.pageCount)")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(minWidth: 100)
            }
            .buttonStyle(.plain)
            .help("Jump to Page")
            .popover(isPresented: $showPageJumper) {
                PageJumperView(
                    currentPage: $currentPage,
                    pageCount: activeDocument.pageCount,
                    showPopover: $showPageJumper
                )
            }

            // Thumbnail grid toggle
            Button {
                showThumbnailGrid.toggle()
            } label: {
                Image(systemName: "square.grid.3x3")
            }
            .help("Show Thumbnail Grid")

            // Orientation toggle
            HStack(spacing: 4) {
                ForEach(Orientation.allCases, id: \.self) { orient in
                    Button {
                        orientation = orient
                    } label: {
                        Image(systemName: orient == .landscape ? "rectangle" : "rectangle.portrait")
                            .font(.system(size: 14))
                            .foregroundStyle(orientation == orient ? Color.primary : Color.secondary)
                            .frame(width: 32, height: 24)
                    }
                    .buttonStyle(.plain)
                    .background(orientation == orient ? Color.primary.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                    .help(orient.rawValue)
                }
            }
        }
    }

    private var annotationToggle: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation {
                    showAnnotations.toggle()
                }
            } label: {
                Image(systemName: showAnnotations ? "sidebar.right.fill" : "sidebar.right")
            }
            .help("Toggle Annotations")

            if annotationMode != .none {
                Text(annotationMode.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    private var pdfContentArea: some View {
        SchedulerPDFPreview(
            document: activeDocument,
            currentPage: currentPage,
            zoomLevel: zoomLevel,
            autoScale: autoScale,
            displayMode: viewMode.pdfDisplayMode,
            annotationMode: annotationMode,
            annotationColor: annotationColor
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                showPrintOptions = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "printer")
                    Text("Print")
                }
            }
            .help("Print PDF")

            Button {
                showExportOptions = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                    Text("Export")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .help("Export PDF")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(0.95),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -2)
    }

    // MARK: - Helper Methods

    private func zoomIn() {
        autoScale = false
        zoomLevel = min(4.0, zoomLevel + 0.25)
    }

    private func zoomOut() {
        autoScale = false
        zoomLevel = max(0.25, zoomLevel - 0.25)
    }

    private func setZoom(_ level: CGFloat) {
        autoScale = false
        zoomLevel = level
    }

    private func setFitMode(_ mode: FitMode) {
        switch mode {
        case .page:
            autoScale = true
            zoomLevel = 1.0
        case .width:
            autoScale = false
            zoomLevel = 1.2
        case .actual:
            autoScale = false
            zoomLevel = 1.0
        }
    }

    private func clearAllAnnotations() {
        // TODO: Implement annotation clearing
        annotationMode = .none
    }

    private func performExport() {
        // Build new PDF with selected pages
        let exportDocument = PDFDocument()
        let pagesToExport: [Int]

        switch exportPageRange {
        case .all:
            pagesToExport = Array(0..<activeDocument.pageCount)
        case .current:
            pagesToExport = [currentPage]
        case .range:
            let start = max(0, min(exportStartPage - 1, activeDocument.pageCount - 1))
            let end = max(start, min(exportEndPage - 1, activeDocument.pageCount - 1))
            pagesToExport = Array(start...end)
        }

        for (index, pageIndex) in pagesToExport.enumerated() {
            if let page = activeDocument.page(at: pageIndex) {
                exportDocument.insert(page, at: index)
            }
        }

        // Show save panel and export
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = defaultFilename
        savePanel.message = "Export PDF"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            if exportDocument.write(to: url) {
                NSWorkspace.shared.open(url)
                dismiss()
            } else {
                print("Failed to write PDF to file")
            }
        }
    }

    private func performPrint() {
        // Build print document with selected pages
        let printDocument = PDFDocument()
        let pagesToPrint: [Int]

        switch printPageRange {
        case .all:
            pagesToPrint = Array(0..<activeDocument.pageCount)
        case .current:
            pagesToPrint = [currentPage]
        case .range:
            let start = max(0, min(printStartPage - 1, activeDocument.pageCount - 1))
            let end = max(start, min(printEndPage - 1, activeDocument.pageCount - 1))
            pagesToPrint = Array(start...end)
        }

        for (index, pageIndex) in pagesToPrint.enumerated() {
            if let page = activeDocument.page(at: pageIndex) {
                printDocument.insert(page, at: index)
            }
        }

        let printInfo = NSPrintInfo.shared
        printInfo.orientation = orientation == .landscape ? .landscape : .portrait
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit

        // Note: copies and duplex are set through the print panel by the user
        // We provide UI for these but they're applied via the system print dialog

        let printOperation = printDocument.printOperation(
            for: printInfo,
            scalingMode: .pageScaleToFit,
            autoRotate: true
        )
        printOperation?.showsPrintPanel = true
        printOperation?.showsProgressPanel = true
        printOperation?.run()
    }
}

// MARK: - Enhanced PDF Preview Wrapper

private struct SchedulerPDFPreview: NSViewRepresentable {
    let document: PDFDocument
    let currentPage: Int
    let zoomLevel: CGFloat
    let autoScale: Bool
    let displayMode: PDFDisplayMode
    let annotationMode: PDFPreviewSheet.AnnotationMode
    let annotationColor: Color

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = autoScale
        pdfView.scaleFactor = autoScale ? 1.0 : zoomLevel
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        pdfView.displayMode = displayMode
        pdfView.displayDirection = .horizontal
        pdfView.displaysPageBreaks = false

        // Add gesture recognizer for annotations
        let clickGesture = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePageClick(_:))
        )
        pdfView.addGestureRecognizer(clickGesture)

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update PDF document if it changed
        if pdfView.document != document {
            pdfView.document = document
        }

        pdfView.autoScales = autoScale
        pdfView.scaleFactor = autoScale ? 1.0 : zoomLevel
        pdfView.displayMode = displayMode

        if let page = document.page(at: currentPage) {
            NSAnimationContext.runAnimationGroup { animationContext in
                animationContext.duration = 0.3
                animationContext.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                pdfView.go(to: page)
            }
        }
    }

    class Coordinator: NSObject {
        var parent: SchedulerPDFPreview

        init(_ parent: SchedulerPDFPreview) {
            self.parent = parent
        }

        @objc func handlePageClick(_ gestureRecognizer: NSClickGestureRecognizer) {
            guard parent.annotationMode == .note else { return }

            let pdfView = gestureRecognizer.view as! PDFView
            let location = gestureRecognizer.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let pageLocation = pdfView.convert(location, to: page)

            let annotation = PDFAnnotation(
                bounds: CGRect(x: pageLocation.x, y: pageLocation.y, width: 20, height: 20),
                forType: .text,
                withProperties: nil
            )
            annotation.contents = "Note"
            annotation.color = NSColor(parent.annotationColor)
            page.addAnnotation(annotation)
        }
    }
}

// MARK: - Thumbnail Sidebar

private struct ThumbnailSidebar: View {
    let pdfDocument: PDFDocument
    @Binding var currentPage: Int
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(0..<pdfDocument.pageCount, id: \.self) { index in
                            ThumbnailPageView(
                                page: pdfDocument.page(at: index),
                                pageNumber: index + 1,
                                isSelected: index == currentPage
                            )
                            .onTapGesture {
                                currentPage = index
                            }
                            .id(index)
                        }
                    }
                    .padding(8)
                }
                .frame(width: 200)
                .background(Color(nsColor: .controlBackgroundColor))
                .onChange(of: currentPage) { newPage in
                    withAnimation {
                        proxy.scrollTo(newPage, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct ThumbnailPageView: View {
    let page: PDFPage?
    let pageNumber: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let page = page {
                Image(nsImage: page.thumbnail(of: CGSize(width: 150, height: 200), for: .mediaBox))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                                   lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                           radius: isSelected ? 6 : 2)
            }

            Text("Page \(pageNumber)")
                .font(.caption2)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .padding(4)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Page Jumper

private struct PageJumperView: View {
    @Binding var currentPage: Int
    let pageCount: Int
    @Binding var showPopover: Bool
    @State private var pageInput: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Jump to Page")
                .font(.headline)

            HStack {
                TextField("Page number", text: $pageInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onSubmit {
                        jumpToPage()
                    }

                Button("Go") {
                    jumpToPage()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("1 - \(pageCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 200)
    }

    private func jumpToPage() {
        if let page = Int(pageInput), page >= 1, page <= pageCount {
            currentPage = page - 1
            showPopover = false
            pageInput = ""
        }
    }
}

// MARK: - Thumbnail Grid

private struct ThumbnailGridView: View {
    let pdfDocument: PDFDocument
    @Binding var currentPage: Int
    @Binding var isPresented: Bool

    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<pdfDocument.pageCount, id: \.self) { index in
                        ThumbnailGridItem(
                            page: pdfDocument.page(at: index),
                            pageNumber: index + 1,
                            isSelected: index == currentPage
                        )
                        .onTapGesture {
                            currentPage = index
                            isPresented = false
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("All Pages")
            .toolbar {
                Button("Done") {
                    isPresented = false
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

private struct ThumbnailGridItem: View {
    let page: PDFPage?
    let pageNumber: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let page = page {
                Image(nsImage: page.thumbnail(of: CGSize(width: 180, height: 240), for: .mediaBox))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2),
                                   lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(radius: 4)
            }

            Text("Page \(pageNumber)")
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Export Options Sheet

private struct ExportOptionsSheet: View {
    @Binding var isPresented: Bool
    @Binding var pageRange: PDFPreviewSheet.PageRangeOption
    @Binding var startPage: Int
    @Binding var endPage: Int
    @Binding var quality: PDFPreviewSheet.ExportQuality
    let pageCount: Int
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Options")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Section("Page Range") {
                    Picker("Range", selection: $pageRange) {
                        ForEach(PDFPreviewSheet.PageRangeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    if pageRange == .range {
                        HStack {
                            Text("From:")
                            TextField("Start", value: $startPage, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)

                            Text("To:")
                            TextField("End", value: $endPage, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)

                            Text("(of \(pageCount))")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Section("Quality") {
                    Picker("Compression", selection: $quality) {
                        ForEach(PDFPreviewSheet.ExportQuality.allCases, id: \.self) { qual in
                            Text(qual.rawValue).tag(qual)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Higher quality = larger file size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export") {
                    onExport()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }
}

// MARK: - Print Options Sheet

private struct PrintOptionsSheet: View {
    @Binding var isPresented: Bool
    @Binding var pageRange: PDFPreviewSheet.PageRangeOption
    @Binding var startPage: Int
    @Binding var endPage: Int
    @Binding var copies: Int
    @Binding var duplex: PDFPreviewSheet.DuplexMode
    @Binding var orientation: PDFPreviewSheet.Orientation
    let pageCount: Int
    let onPrint: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Print Options")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Section("Pages") {
                    Picker("Range", selection: $pageRange) {
                        ForEach(PDFPreviewSheet.PageRangeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    if pageRange == .range {
                        HStack {
                            Text("From:")
                            TextField("Start", value: $startPage, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)

                            Text("To:")
                            TextField("End", value: $endPage, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)

                            Text("(of \(pageCount))")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Section("Copies") {
                    HStack {
                        Stepper("Number of copies:", value: $copies, in: 1...99)
                        Text("\(copies)")
                            .frame(width: 40, alignment: .trailing)
                            .fontWeight(.semibold)
                    }
                }

                Section("Printing") {
                    Picker("Duplex", selection: $duplex) {
                        ForEach(PDFPreviewSheet.DuplexMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Picker("Orientation", selection: $orientation) {
                        ForEach(PDFPreviewSheet.Orientation.allCases, id: \.self) { orient in
                            HStack {
                                Image(systemName: orient == .landscape ? "rectangle" : "rectangle.portrait")
                                Text(orient.rawValue)
                            }
                            .tag(orient)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Print") {
                    onPrint()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500, height: 500)
    }
}

// MARK: - Annotation Panel

private struct AnnotationPanel: View {
    @Binding var annotationMode: PDFPreviewSheet.AnnotationMode
    @Binding var annotationColor: Color
    @Binding var isVisible: Bool
    let onClearAll: () -> Void

    var body: some View {
        if isVisible {
            VStack(spacing: 16) {
                headerSection

                Divider()

                modeSelectionSection

                if annotationMode != .none {
                    Divider()
                    colorPickerSection
                }

                Spacer()

                clearAllButton
            }
            .padding()
            .frame(width: 250)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var headerSection: some View {
        Text("Annotations")
            .font(.headline)
    }

    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tool")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(PDFPreviewSheet.AnnotationMode.allCases, id: \.self) { mode in
                annotationModeButton(for: mode)
            }
        }
    }

    private func annotationModeButton(for mode: PDFPreviewSheet.AnnotationMode) -> some View {
        Button {
            annotationMode = mode
        } label: {
            HStack {
                Image(systemName: mode.icon)
                Text(mode.rawValue)
                Spacer()
                if annotationMode == mode {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(8)
            .background(annotationMode == mode ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption)
                .foregroundStyle(.secondary)

            ColorPicker("Annotation Color", selection: $annotationColor)
                .labelsHidden()
        }
    }

    private var clearAllButton: some View {
        Button(role: .destructive) {
            onClearAll()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Clear All")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

#else
// iOS placeholder - not used but needed for compilation
struct PDFPreviewSheet: View {
    let pdfDocument: PDFDocument
    let title: String
    let defaultFilename: String

    var body: some View {
        Text("PDF Preview not available on iOS")
    }
}
#endif
