import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import CoreData

// MARK: - Models (shared across platforms)
struct PDFAnnotationItem: Identifiable, Hashable {
    let id: UUID
    var type: AnnotationType
    var position: CGPoint
    var size: CGSize
    var content: String
    var page: Int
    var color: Color
    var signatureImage: Data?

    init(
        id: UUID = UUID(),
        type: AnnotationType,
        position: CGPoint,
        size: CGSize,
        content: String,
        page: Int,
        color: Color,
        signatureImage: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.content = content
        self.page = page
        self.color = color
        self.signatureImage = signatureImage
    }

    enum AnnotationType: String, CaseIterable {
        case text = "Text"
        case checkbox = "Checkbox"
        case signature = "Signature"
        case initials = "Initials"
        case checkmark = "Checkmark"
        case date = "Date"

        var icon: String {
            switch self {
            case .text: return "textformat"
            case .checkbox: return "checkmark.square"
            case .signature: return "signature"
            case .initials: return "person.crop.circle"
            case .checkmark: return "checkmark.circle.fill"
            case .date: return "calendar"
            }
        }
    }
}

#if os(macOS)
// MARK: - Annotation Storage Helper
struct StoredAnnotation: Codable {
    let id: String
    let type: String
    let positionX: Double
    let positionY: Double
    let sizeWidth: Double
    let sizeHeight: Double
    let content: String
    let page: Int
    let signatureImageData: Data?
}

// MARK: - Annotation Helpers for PaperworkEntity
extension PaperworkEntity {
    var annotations: [PDFAnnotationItem] {
        get {
            guard let data = annotationsData else { return [] }
            guard let stored = try? JSONDecoder().decode([StoredAnnotation].self, from: data) else { return [] }
            return stored.compactMap { s -> PDFAnnotationItem? in
                guard let uuid = UUID(uuidString: s.id) else { return nil }
                return PDFAnnotationItem(
                    id: uuid,
                    type: PDFAnnotationItem.AnnotationType(rawValue: s.type) ?? .text,
                    position: CGPoint(x: s.positionX, y: s.positionY),
                    size: CGSize(width: s.sizeWidth, height: s.sizeHeight),
                    content: s.content,
                    page: s.page,
                    color: .black,
                    signatureImage: s.signatureImageData
                )
            }
        }
        set {
            let stored = newValue.map { a in
                StoredAnnotation(
                    id: a.id.uuidString,
                    type: a.type.rawValue,
                    positionX: a.position.x,
                    positionY: a.position.y,
                    sizeWidth: a.size.width,
                    sizeHeight: a.size.height,
                    content: a.content,
                    page: a.page,
                    signatureImageData: a.signatureImage
                )
            }
            annotationsData = try? JSONEncoder().encode(stored)
            dateModified = Date()
        }
    }

    func addAnnotation(_ annotation: PDFAnnotationItem) {
        guard managedObjectContext != nil else { return }
        var current = annotations
        current.append(annotation)
        annotations = current
        try? managedObjectContext?.save()
    }

    func updateAnnotation(_ annotation: PDFAnnotationItem) {
        guard managedObjectContext != nil else { return }
        var current = annotations
        if let index = current.firstIndex(where: { $0.id == annotation.id }) {
            current[index] = annotation
            annotations = current
            try? managedObjectContext?.save()
        }
    }

    func deleteAnnotation(_ annotation: PDFAnnotationItem) {
        guard managedObjectContext != nil else { return }
        var current = annotations
        current.removeAll { $0.id == annotation.id }
        annotations = current
        try? managedObjectContext?.save()
    }

    func clearAnnotations() {
        guard managedObjectContext != nil else { return }
        annotations = []
        try? managedObjectContext?.save()
    }
}

// MARK: - Main Paperwork View
struct PaperworkView: View {
    @State private var selectedDocumentId: UUID?
    @State private var currentPage: Int = 0
    @State private var zoom: CGFloat = 1.0
    @State private var showToolbar = true
    @State private var selectedTool: PDFAnnotationItem.AnnotationType?
    @State private var isAddingAnnotation = false
    @State private var pendingAnnotation: PDFAnnotationItem?
    @State private var signatureText: String = ""
    @State private var showSignaturePad = false
    @State private var searchText: String = ""
    @State private var showLeftPane = true
    @State private var showRightPane = true
    @State private var selectedContactId: UUID?
    @State private var selectedCategory: String = "All"

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var moc

    @FetchRequest(
        entity: ContactEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ContactEntity.name, ascending: true)],
        animation: .default
    ) private var contacts: FetchedResults<ContactEntity>

    @FetchRequest(
        entity: PaperworkEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PaperworkEntity.dateAdded, ascending: false)],
        animation: .default
    ) private var paperworkEntities: FetchedResults<PaperworkEntity>

    private var selectedDocument: PaperworkEntity? {
        guard let id = selectedDocumentId else { return nil }
        return paperworkEntities.first { $0.id == id }
    }

    private var selectedContact: ContactEntity? {
        guard let id = selectedContactId else { return nil }
        return contacts.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            topToolbar

            Divider()

            // Main content
            HSplitView {
                // Left: Document sidebar
                if showLeftPane {
                    documentSidebar
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                }

                // Center: PDF editor
                if let doc = selectedDocument {
                    pdfEditorView(for: doc)
                        .frame(minWidth: 400)
                } else {
                    emptyStateView
                        .frame(minWidth: 400)
                }

                // Right: Contacts inspector
                if showRightPane {
                    contactsInspectorPane
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                }
            }
        }
        .sheet(isPresented: $showSignaturePad) {
            DrawableSignaturePadView(signatureText: $signatureText) { signatureData, signatureString in
                if let annotation = pendingAnnotation {
                    var updated = annotation
                    updated.content = signatureString
                    updated.signatureImage = signatureData
                    addAnnotation(updated)
                }
                showSignaturePad = false
                pendingAnnotation = nil
            }
        }
        .onAppear {
            print("🔵 PaperworkView appeared - Documents: \(paperworkEntities.count), Contacts: \(contacts.count)")
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 16) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                TextField("Search documents and contacts", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .frame(width: 350)

            Spacer()

            // Toggle buttons
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showLeftPane.toggle()
                    }
                } label: {
                    Image(systemName: showLeftPane ? "sidebar.leading" : "sidebar.leading")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(showLeftPane ? Color.indigo.opacity(0.1) : Color.primary.opacity(0.04))
                        )
                        .foregroundStyle(showLeftPane ? Color.indigo : .secondary)
                }
                .buttonStyle(.plain)
                .customTooltip("Toggle Documents Sidebar")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showRightPane.toggle()
                    }
                } label: {
                    Image(systemName: showRightPane ? "sidebar.trailing" : "sidebar.trailing")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(showRightPane ? Color.indigo.opacity(0.1) : Color.primary.opacity(0.04))
                        )
                        .foregroundStyle(showRightPane ? Color.indigo : .secondary)
                }
                .buttonStyle(.plain)
                .customTooltip("Toggle Contacts Inspector")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Document Sidebar
    private var documentSidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paperwork")
                            .font(.system(size: 18, weight: .bold))
                        Text("\(paperworkEntities.count) document\(paperworkEntities.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        print("🔵 Import button clicked")
                        openPDFImportPanel()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.indigo)
                                    .shadow(color: Color.indigo.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Import PDF")
                }
            }
            .padding(16)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.08),
                            Color.indigo.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .background(.ultraThinMaterial)
                }
            )

            Divider()

            // Documents list
            if paperworkEntities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.ellipsis")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.indigo.opacity(0.5))

                    VStack(spacing: 6) {
                        Text("No Documents")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Import a PDF to get started")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        print("🔵 Empty state Import button clicked")
                        openPDFImportPanel()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Import PDF")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.indigo)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDocuments) { doc in
                            PaperworkEntityRow(
                                document: doc,
                                isSelected: selectedDocumentId == doc.id
                            ) {
                                selectedDocumentId = doc.id
                                currentPage = Int(doc.currentPage)
                            } onDelete: {
                                deleteDocument(doc)
                            }
                            .contextMenu {
                                // Assign to contact menu
                                Menu("Assign to Contact") {
                                    Button("No Contact") {
                                        assignDocumentToContact(doc, contact: nil)
                                    }
                                    Divider()
                                    ForEach(contacts) { contact in
                                        Button(contact.name ?? "Unknown") {
                                            assignDocumentToContact(doc, contact: contact)
                                        }
                                    }
                                }

                                Divider()

                                Button(doc.isSigned ? "Signed" : "Mark as Signed") {
                                    markDocumentAsSigned(doc)
                                }
                                .disabled(doc.isSigned)

                                Divider()

                                Button("Delete", role: .destructive) {
                                    deleteDocument(doc)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }

            Spacer()
        }
    }

    // MARK: - PDF Editor View
    private func pdfEditorView(for document: PaperworkEntity) -> some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack(spacing: 16) {
                // Document name
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.indigo)

                    Text(document.name ?? "Untitled")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                }

                Spacer()

                // Zoom controls
                HStack(spacing: 8) {
                    Button {
                        zoom = max(0.5, zoom - 0.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(zoom * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .frame(minWidth: 50)
                        .monospacedDigit()

                    Button {
                        zoom = min(3.0, zoom + 0.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )

                // Mark as Signed button
                Button {
                    markDocumentAsSigned(document)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: document.isSigned ? "checkmark.seal.fill" : "checkmark.seal")
                            .font(.system(size: 13))
                        Text(document.isSigned ? "Signed" : "Mark Signed")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(document.isSigned ? Color.green : Color.orange)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(document.isSigned)

                // Export button
                Button {
                    exportPDF(document)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                        Text("Export")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.indigo)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Annotation toolbar
            annotationToolbar(for: document)

            Divider()

            // PDF view
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    if let pdfDoc = document.pdfDocument,
                       let page = pdfDoc.page(at: currentPage) {
                        PDFPageView(
                            page: page,
                            zoom: zoom,
                            annotations: document.annotations.filter { $0.page == currentPage },
                            selectedTool: selectedTool,
                            onAddAnnotation: { annotation in
                                var newAnnotation = annotation
                                newAnnotation.page = currentPage

                                if newAnnotation.type == .signature || newAnnotation.type == .initials {
                                    pendingAnnotation = newAnnotation
                                    showSignaturePad = true
                                } else if newAnnotation.type == .date {
                                    newAnnotation.content = DateFormatter.localizedString(
                                        from: Date(),
                                        dateStyle: .medium,
                                        timeStyle: .none
                                    )
                                    addAnnotation(newAnnotation)
                                } else {
                                    addAnnotation(newAnnotation)
                                }

                                selectedTool = nil
                            },
                            onUpdateAnnotation: { annotation in
                                updateAnnotation(annotation)
                            },
                            onDeleteAnnotation: { annotation in
                                deleteAnnotation(annotation)
                            }
                        )
                        .frame(
                            width: page.bounds(for: .mediaBox).width * zoom,
                            height: page.bounds(for: .mediaBox).height * zoom
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Page navigation
            if let pdfDoc = document.pdfDocument {
                pageNavigation(pageCount: pdfDoc.pageCount, document: document)
            }
        }
    }

    // MARK: - Annotation Toolbar
    private func annotationToolbar(for document: PaperworkEntity) -> some View {
        HStack(spacing: 8) {
            Text("Tools:")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            ForEach(PDFAnnotationItem.AnnotationType.allCases, id: \.self) { tool in
                Button {
                    selectedTool = selectedTool == tool ? nil : tool
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 13, weight: .medium))
                        Text(tool.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedTool == tool ? Color.indigo : Color.primary.opacity(0.04))
                    )
                    .foregroundStyle(selectedTool == tool ? .white : .primary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !document.annotations.isEmpty {
                Button {
                    clearAnnotations(for: document)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                        Text("Clear All")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                    )
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Page Navigation
    private func pageNavigation(pageCount: Int, document: PaperworkEntity) -> some View {
        HStack(spacing: 12) {
            Button {
                if currentPage > 0 {
                    currentPage -= 1
                    document.currentPage = Int16(currentPage)
                    try? moc.save()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)

            Text("Page \(currentPage + 1) of \(pageCount)")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()

            Button {
                if currentPage < pageCount - 1 {
                    currentPage += 1
                    document.currentPage = Int16(currentPage)
                    try? moc.save()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= pageCount - 1)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "doc.badge.ellipsis")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.indigo)
            }

            VStack(spacing: 8) {
                Text("PDF Paperwork Manager")
                    .font(.system(size: 22, weight: .bold))
                Text("Import, edit, and sign PDF documents")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Button {
                openPDFImportPanel()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Import PDF Document")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.indigo)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 12) {
                Text("Features:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                FeatureRow(icon: "textformat", title: "Add text fields", color: .blue)
                FeatureRow(icon: "checkmark.square", title: "Add checkboxes", color: .green)
                FeatureRow(icon: "signature", title: "Add signatures", color: .purple)
                FeatureRow(icon: "person.crop.circle", title: "Add initials", color: .orange)
                FeatureRow(icon: "calendar", title: "Insert dates", color: .teal)
                FeatureRow(icon: "square.and.arrow.up", title: "Export completed PDFs", color: .indigo)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Functions

    /// Opens NSOpenPanel directly to import PDF documents
    private func openPDFImportPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        panel.message = "Select PDF documents to import"
        panel.prompt = "Import"

        panel.begin { response in
            if response == .OK {
                let urls = panel.urls
                print("🔵 NSOpenPanel selected \(urls.count) files")
                self.importPDFFiles(urls: urls)
            } else {
                print("🔵 NSOpenPanel cancelled")
            }
        }
    }

    /// Import PDF files from URLs
    private func importPDFFiles(urls: [URL]) {
        for url in urls {
            print("🔵 Processing URL: \(url.lastPathComponent)")

            // Access security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Read file data first (while we have access)
            guard let fileData = try? Data(contentsOf: url) else {
                print("🔴 Failed to read file data from: \(url.lastPathComponent)")
                continue
            }
            print("🔵 File data read - \(fileData.count) bytes")

            // Create PDF document from data to get page count
            guard let pdfDoc = PDFDocument(data: fileData) else {
                print("🔴 Failed to create PDF from data: \(url.lastPathComponent)")
                continue
            }
            print("🔵 PDF loaded - \(pdfDoc.pageCount) pages")

            // Create PaperworkEntity in Core Data
            let paperworkEntity = PaperworkEntity.create(
                in: moc,
                name: url.deletingPathExtension().lastPathComponent,
                fileName: url.lastPathComponent,
                fileData: fileData,
                pageCount: Int16(pdfDoc.pageCount),
                contact: selectedContact
            )
            print("🔵 Created PaperworkEntity with ID: \(paperworkEntity.id?.uuidString ?? "nil")")

            // Update contact's paperwork status if a contact is selected
            if let contact = selectedContact {
                contact.paperworkStarted = true
                contact.modifiedAt = Date()
                print("🔵 Updated contact '\(contact.name ?? "Unknown")' paperworkStarted = true")
            }

            // Save context
            do {
                try moc.save()
                print("🔵 Context saved successfully")
            } catch {
                print("🔴 Failed to save context: \(error)")
                moc.rollback()
                continue
            }

            // Select the newly imported document
            selectedDocumentId = paperworkEntity.id
            currentPage = 0
            print("🔵 Selected document: \(paperworkEntity.id?.uuidString ?? "nil")")
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        print("🔵 handleImport called")
        switch result {
        case .success(let urls):
            print("🔵 Import success - \(urls.count) URLs")
            for url in urls {
                print("🔵 Processing URL: \(url.lastPathComponent)")

                // Access security-scoped resource
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // Read file data first (while we have access)
                guard let fileData = try? Data(contentsOf: url) else {
                    print("🔴 Failed to read file data from: \(url.lastPathComponent)")
                    continue
                }
                print("🔵 File data read - \(fileData.count) bytes")

                // Create PDF document from data to get page count
                guard let pdfDoc = PDFDocument(data: fileData) else {
                    print("🔴 Failed to create PDF from data: \(url.lastPathComponent)")
                    continue
                }
                print("🔵 PDF loaded - \(pdfDoc.pageCount) pages")

                // Create PaperworkEntity in Core Data
                let paperworkEntity = PaperworkEntity.create(
                    in: moc,
                    name: url.deletingPathExtension().lastPathComponent,
                    fileName: url.lastPathComponent,
                    fileData: fileData,
                    pageCount: Int16(pdfDoc.pageCount),
                    contact: selectedContact
                )
                print("🔵 Created PaperworkEntity with ID: \(paperworkEntity.id?.uuidString ?? "nil")")

                // Update contact's paperwork status if a contact is selected
                if let contact = selectedContact {
                    contact.paperworkStarted = true
                    contact.modifiedAt = Date()
                    print("🔵 Updated contact '\(contact.name ?? "Unknown")' paperworkStarted = true")
                }

                // Save context
                do {
                    try moc.save()
                    print("🔵 Context saved successfully")
                } catch {
                    print("🔴 Failed to save context: \(error)")
                    // Rollback on failure
                    moc.rollback()
                    continue
                }

                // Select the newly imported document
                selectedDocumentId = paperworkEntity.id
                currentPage = 0
                print("🔵 Selected document: \(paperworkEntity.id?.uuidString ?? "nil")")
            }
        case .failure(let error):
            print("🔴 Import failed: \(error.localizedDescription)")
        }
    }

    private func addAnnotation(_ annotation: PDFAnnotationItem) {
        guard let document = selectedDocument else { return }
        document.addAnnotation(annotation)
    }

    private func updateAnnotation(_ annotation: PDFAnnotationItem) {
        guard let document = selectedDocument else { return }
        document.updateAnnotation(annotation)
    }

    private func deleteAnnotation(_ annotation: PDFAnnotationItem) {
        guard let document = selectedDocument else { return }
        document.deleteAnnotation(annotation)
    }

    private func clearAnnotations(for document: PaperworkEntity) {
        document.clearAnnotations()
    }

    private func deleteDocument(_ entity: PaperworkEntity) {
        // Store contact reference before deletion
        let contact = entity.contact

        if selectedDocumentId == entity.id {
            selectedDocumentId = nil
        }
        moc.delete(entity)

        // Update contact's paperwork status after deletion
        if let contact = contact {
            updateContactPaperworkStatus(contact)
        }

        try? moc.save()
    }

    private func markDocumentAsSigned(_ document: PaperworkEntity) {
        document.isSigned = true
        document.dateModified = Date()

        // Update the contact's paperwork status
        if let contact = document.contact {
            updateContactPaperworkStatus(contact)
        }

        try? moc.save()
        print("🔵 Document '\(document.name ?? "Unknown")' marked as signed")
    }

    private func updateContactPaperworkStatus(_ contact: ContactEntity) {
        guard let paperworkSet = contact.paperwork as? Set<PaperworkEntity> else {
            contact.paperworkStarted = false
            contact.paperworkComplete = false
            return
        }

        if paperworkSet.isEmpty {
            contact.paperworkStarted = false
            contact.paperworkComplete = false
        } else {
            contact.paperworkStarted = true
            contact.paperworkComplete = paperworkSet.allSatisfy { $0.isSigned }
        }
        contact.modifiedAt = Date()
    }

    private func assignDocumentToContact(_ document: PaperworkEntity, contact: ContactEntity?) {
        // Store the old contact to update its status
        let oldContact = document.contact

        // Assign to new contact (or nil)
        document.contact = contact
        document.dateModified = Date()

        // Update the old contact's paperwork status
        if let oldContact = oldContact {
            updateContactPaperworkStatus(oldContact)
        }

        // Update the new contact's paperwork status
        if let newContact = contact {
            newContact.paperworkStarted = true
            updateContactPaperworkStatus(newContact)
        }

        // Save context
        do {
            try moc.save()
            print("🔵 Document '\(document.name ?? "Unknown")' assigned to '\(contact?.name ?? "No Contact")'")
        } catch {
            print("🔴 Failed to assign document: \(error)")
            moc.rollback()
        }
    }

    // MARK: - Contacts Inspector Pane
    private var contactsInspectorPane: some View {
        VStack(spacing: 0) {
            // Header with category filter
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.indigo)
                        Text("Signature Status")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Spacer()
                }

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableCategories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedCategory == category ? Color.indigo : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Contacts list grouped by category
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(groupedContacts.keys.sorted(), id: \.self) { category in
                        if let categoryContacts = groupedContacts[category], !categoryContacts.isEmpty {
                            // Category header
                            HStack {
                                Text(category)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Text("\(categoryContacts.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.primary.opacity(0.08))
                                    )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.02))

                            // Category contacts
                            ForEach(Array(categoryContacts.enumerated()), id: \.element.id) { index, contact in
                                ContactSignatureRow(
                                    contact: contact,
                                    isSelected: selectedContactId == contact.id,
                                    onSelect: {
                                        selectedContactId = contact.id
                                    },
                                    onAddDocument: {
                                        selectedContactId = contact.id
                                        openPDFImportPanel()
                                    }
                                )
                                if index < categoryContacts.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }

                            if category != groupedContacts.keys.sorted().last {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var availableCategories: [String] {
        var categories = Set<String>()
        categories.insert("All")
        for contact in contacts {
            let category = getContactCategory(contact)
            categories.insert(category)
        }
        return Array(categories).sorted()
    }

    private var groupedContacts: [String: [ContactEntity]] {
        let filtered = filteredContacts
        var grouped: [String: [ContactEntity]] = [:]

        for contact in filtered {
            let category = getContactCategory(contact)
            if grouped[category] != nil {
                grouped[category]?.append(contact)
            } else {
                grouped[category] = [contact]
            }
        }

        return grouped
    }

    private var filteredDocuments: [PaperworkEntity] {
        if searchText.isEmpty {
            return Array(paperworkEntities)
        } else {
            return paperworkEntities.filter { doc in
                (doc.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var filteredContacts: [ContactEntity] {
        var filtered = Array(contacts)

        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { contact in
                getContactCategory(contact) == selectedCategory
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { contact in
                let name = contact.name ?? ""
                let role = contact.role ?? ""
                let category = contact.category ?? ""

                return name.localizedCaseInsensitiveContains(searchText) ||
                       role.localizedCaseInsensitiveContains(searchText) ||
                       category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    private func getContactCategory(_ contact: ContactEntity) -> String {
        if let category = contact.category, !category.isEmpty {
            return category
        }
        // Try to infer from role if category is missing
        if let role = contact.role, !role.isEmpty {
            let roleLower = role.lowercased()
            if roleLower.contains("cast") || roleLower.contains("actor") {
                return "Cast"
            } else if roleLower.contains("crew") || roleLower.contains("director") || roleLower.contains("producer") {
                return "Crew"
            } else if roleLower.contains("vendor") || roleLower.contains("supplier") {
                return "Vendor"
            }
        }
        return "Other"
    }

    private func exportPDF(_ document: PaperworkEntity) {
        guard let pdfDoc = document.pdfDocument else { return }

        // Create a new PDF document with annotations burned in
        let exportDoc = PDFDocument()

        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }

            // Get the page bounds
            let pageBounds = page.bounds(for: .mediaBox)

            // Create an image context to render the page with annotations
            let renderer = ImageRenderer(content:
                ZStack {
                    // Render the PDF page
                    PDFPageImage(page: page, size: pageBounds.size)

                    // Overlay annotations
                    ForEach(document.annotations.filter { $0.page == pageIndex }) { annotation in
                        AnnotationRenderView(annotation: annotation)
                            .position(annotation.position)
                    }
                }
                .frame(width: pageBounds.width, height: pageBounds.height)
            )

            renderer.scale = 2.0 // Higher quality

            if let nsImage = renderer.nsImage {
                // Convert NSImage to PDFPage
                if let imageData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: imageData),
                   let pngData = bitmap.representation(using: .png, properties: [:]),
                   let pngImage = NSImage(data: pngData) {

                    let newPage = PDFPage(image: pngImage)
                    if let newPage = newPage {
                        exportDoc.insert(newPage, at: exportDoc.pageCount)
                    }
                }
            }
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(document.name ?? "document")_signed.pdf"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                exportDoc.write(to: url)
            }
        }
    }
}

// MARK: - Paperwork Entity Row
private struct PaperworkEntityRow: View {
    let document: PaperworkEntity
    let isSelected: Bool
    let action: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Thumbnail or icon with signed badge
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(document.isSigned ? Color.green.opacity(0.1) : Color.indigo.opacity(0.1))
                        .frame(width: 50, height: 60)

                    Image(systemName: document.isSigned ? "doc.badge.ellipsis" : "doc.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(document.isSigned ? Color.green : Color.indigo)

                    if document.isSigned {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.green).frame(width: 18, height: 18))
                            .offset(x: 4, y: 4)
                    }
                }

                // Document info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(document.name ?? "Untitled")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? Color.indigo : .primary)

                        if document.isSigned {
                            Text("Signed")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.green)
                                )
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(document.pageCount) page\(document.pageCount == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if !document.annotations.isEmpty {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("\(document.annotations.count) annotation\(document.annotations.count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let contact = document.contact {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                            Text(contact.name ?? "Unknown")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isHovered {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.indigo)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.indigo.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.indigo.opacity(0.3) : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - PDF Page View with Annotations
private struct PDFPageView: View {
    let page: PDFPage
    let zoom: CGFloat
    let annotations: [PDFAnnotationItem]
    let selectedTool: PDFAnnotationItem.AnnotationType?
    let onAddAnnotation: (PDFAnnotationItem) -> Void
    let onUpdateAnnotation: (PDFAnnotationItem) -> Void
    let onDeleteAnnotation: (PDFAnnotationItem) -> Void

    @State private var dragLocation: CGPoint?

    var body: some View {
        ZStack(alignment: .topLeading) {
            // PDF Page
            PDFPageContentView(page: page, zoom: zoom)

            // Annotations overlay
            ForEach(annotations) { annotation in
                PDFDraggableAnnotationView(
                    annotation: annotation,
                    zoom: zoom,
                    onUpdate: onUpdateAnnotation,
                    onDelete: onDeleteAnnotation
                )
                .position(
                    x: annotation.position.x * zoom,
                    y: annotation.position.y * zoom
                )
            }

            // Drag overlay for adding annotations
            if selectedTool != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragLocation = value.location
                            }
                            .onEnded { value in
                                if let tool = selectedTool {
                                    let annotation = PDFAnnotationItem(
                                        type: tool,
                                        position: CGPoint(
                                            x: value.location.x / zoom,
                                            y: value.location.y / zoom
                                        ),
                                        size: defaultSize(for: tool),
                                        content: defaultContent(for: tool),
                                        page: 0,
                                        color: .black
                                    )
                                    onAddAnnotation(annotation)
                                }
                                dragLocation = nil
                            }
                    )
            }
        }
    }

    private func defaultSize(for type: PDFAnnotationItem.AnnotationType) -> CGSize {
        switch type {
        case .text:
            return CGSize(width: 200, height: 30)
        case .checkbox, .checkmark:
            return CGSize(width: 20, height: 20)
        case .signature:
            return CGSize(width: 150, height: 50)
        case .initials:
            return CGSize(width: 80, height: 40)
        case .date:
            return CGSize(width: 100, height: 25)
        }
    }

    private func defaultContent(for type: PDFAnnotationItem.AnnotationType) -> String {
        switch type {
        case .text:
            return "Type here..."
        case .checkbox:
            return ""
        case .signature:
            return "Signature"
        case .initials:
            return "Initials"
        case .checkmark:
            return "✓"
        case .date:
            return DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
        }
    }
}

// MARK: - PDF Page Content View
private struct PDFPageContentView: View {
    let page: PDFPage
    let zoom: CGFloat

    var body: some View {
        PDFPageViewRepresentable(page: page, zoom: zoom)
    }
}

private struct PDFPageViewRepresentable: NSViewRepresentable {
    let page: PDFPage
    let zoom: CGFloat

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = false
        pdfView.displaysPageBreaks = false
        pdfView.displayDirection = .horizontal
        pdfView.displayMode = .singlePage
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument()
        nsView.document?.insert(page, at: 0)
        nsView.scaleFactor = zoom
    }
}

// MARK: - PDF Draggable Annotation View
private struct PDFDraggableAnnotationView: View {
    let annotation: PDFAnnotationItem
    let zoom: CGFloat
    let onUpdate: (PDFAnnotationItem) -> Void
    let onDelete: (PDFAnnotationItem) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var dragOffset: CGSize = .zero
    @State private var isHovered = false

    var body: some View {
        ZStack {
            annotationContent
                .scaleEffect(zoom)
        }
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    var updated = annotation
                    updated.position = CGPoint(
                        x: annotation.position.x + value.translation.width / zoom,
                        y: annotation.position.y + value.translation.height / zoom
                    )
                    onUpdate(updated)
                    dragOffset = .zero
                }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .overlay(alignment: .topTrailing) {
            if isHovered {
                Button {
                    onDelete(annotation)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
            }
        }
    }

    @ViewBuilder
    private var annotationContent: some View {
        switch annotation.type {
        case .text:
            if isEditing {
                TextField("", text: $editText, onCommit: {
                    var updated = annotation
                    updated.content = editText
                    onUpdate(updated)
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(4)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.indigo, lineWidth: 2)
                )
            } else {
                Text(annotation.content)
                    .font(.system(size: 12))
                    .padding(4)
                    .background(Color.yellow.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange, lineWidth: 1)
                    )
                    .onTapGesture(count: 2) {
                        editText = annotation.content
                        isEditing = true
                    }
            }

        case .checkbox:
            Image(systemName: "square")
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .onTapGesture(count: 2) {
                    var updated = annotation
                    updated.type = .checkmark
                    onUpdate(updated)
                }

        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
                .onTapGesture(count: 2) {
                    var updated = annotation
                    updated.type = .checkbox
                    onUpdate(updated)
                }

        case .signature, .initials:
            if let imageData = annotation.signatureImage,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: annotation.size.width, height: annotation.size.height)
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue, lineWidth: 1)
                    )
            } else {
                Text(annotation.content)
                    .font(.custom("Snell Roundhand", size: annotation.type == .initials ? 14 : 16))
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue, lineWidth: 1)
                    )
            }

        case .date:
            Text(annotation.content)
                .font(.system(size: 11, weight: .medium))
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
}

// MARK: - Drawable Signature Pad View
private struct DrawableSignaturePadView: View {
    @Binding var signatureText: String
    let onComplete: (Data?, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isDrawMode = true
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Signature")
                .font(.system(size: 20, weight: .bold))

            // Mode toggle
            Picker("Mode", selection: $isDrawMode) {
                Text("Draw").tag(true)
                Text("Type").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if isDrawMode {
                // Drawing canvas
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        // Signature line
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .offset(y: 30)

                        // Drawing
                        Canvas { context, size in
                            for line in lines {
                                var path = Path()
                                if let first = line.first {
                                    path.move(to: first)
                                    for point in line.dropFirst() {
                                        path.addLine(to: point)
                                    }
                                }
                                context.stroke(path, with: .color(.black), lineWidth: 2)
                            }

                            // Current line
                            var currentPath = Path()
                            if let first = currentLine.first {
                                currentPath.move(to: first)
                                for point in currentLine.dropFirst() {
                                    currentPath.addLine(to: point)
                                }
                            }
                            context.stroke(currentPath, with: .color(.black), lineWidth: 2)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    currentLine.append(value.location)
                                }
                                .onEnded { _ in
                                    lines.append(currentLine)
                                    currentLine = []
                                }
                        )
                    }
                    .frame(height: 120)

                    Button("Clear") {
                        lines = []
                        currentLine = []
                    }
                    .font(.system(size: 12))
                }
            } else {
                // Type signature
                TextField("Type your signature", text: $signatureText)
                    .textFieldStyle(.plain)
                    .font(.custom("Snell Roundhand", size: 24))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    if isDrawMode {
                        // Render the drawing to an image
                        let renderer = ImageRenderer(content:
                            Canvas { context, size in
                                for line in lines {
                                    var path = Path()
                                    if let first = line.first {
                                        path.move(to: first)
                                        for point in line.dropFirst() {
                                            path.addLine(to: point)
                                        }
                                    }
                                    context.stroke(path, with: .color(.black), lineWidth: 2)
                                }
                            }
                            .frame(width: 300, height: 100)
                            .background(Color.clear)
                        )
                        renderer.scale = 2.0

                        if let nsImage = renderer.nsImage,
                           let tiffData = nsImage.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmap.representation(using: .png, properties: [:]) {
                            onComplete(pngData, "Drawn Signature")
                        } else {
                            onComplete(nil, "Signature")
                        }
                    } else {
                        onComplete(nil, signatureText)
                    }
                } label: {
                    Text("Add Signature")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(isDrawMode ? lines.isEmpty : signatureText.isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 400, minHeight: 280)
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Contact Signature Row
private struct ContactSignatureRow: View {
    let contact: ContactEntity
    let isSelected: Bool
    let onSelect: () -> Void
    let onAddDocument: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            // Contact info
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name ?? "Unknown Contact")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let role = contact.role, !role.isEmpty {
                        Text(role)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    } else if let category = contact.category, !category.isEmpty {
                        Text(category)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    if documentCount > 0 {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Text("\(documentCount) doc\(documentCount == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Add document button (always visible when selected or hovered)
            if isSelected || isHovered {
                Button {
                    onAddDocument()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.indigo.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }

            // Status badge
            Text(statusText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(statusColor.opacity(0.12))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.indigo.opacity(0.08) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }

    private var documentCount: Int {
        if let paperworkSet = contact.paperwork as? Set<PaperworkEntity> {
            return paperworkSet.count
        }
        return 0
    }

    private var signedCount: Int {
        if let paperworkSet = contact.paperwork as? Set<PaperworkEntity> {
            return paperworkSet.filter { $0.isSigned }.count
        }
        return 0
    }

    private var hasSigned: Bool {
        // Check if the contact has paperwork that is all signed
        if let paperworkSet = contact.paperwork as? Set<PaperworkEntity>, !paperworkSet.isEmpty {
            return paperworkSet.allSatisfy { $0.isSigned }
        }
        // If no paperwork assigned, check the paperworkComplete flag
        return contact.paperworkComplete
    }

    private var hasPartialSigned: Bool {
        // Has some signed but not all
        if let paperworkSet = contact.paperwork as? Set<PaperworkEntity>, !paperworkSet.isEmpty {
            let signedCount = paperworkSet.filter { $0.isSigned }.count
            return signedCount > 0 && signedCount < paperworkSet.count
        }
        return false
    }

    private var statusColor: Color {
        if hasSigned {
            return .green
        } else if hasPartialSigned {
            return .orange
        } else if documentCount > 0 {
            return .orange
        }
        return .secondary
    }

    private var statusIcon: String {
        if hasSigned {
            return "checkmark.circle.fill"
        } else if hasPartialSigned {
            return "clock.fill"
        } else if documentCount > 0 {
            return "doc.badge.clock"
        }
        return "doc.badge.plus"
    }

    private var statusText: String {
        if hasSigned {
            return "Complete"
        } else if hasPartialSigned {
            return "\(signedCount)/\(documentCount)"
        } else if documentCount > 0 {
            return "Pending"
        }
        return "No Docs"
    }
}

// MARK: - PDF Page Image for Export
private struct PDFPageImage: View {
    let page: PDFPage
    let size: CGSize

    var body: some View {
        if let image = renderPageToImage() {
            Image(nsImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)
        }
    }

    private func renderPageToImage() -> NSImage? {
        let bounds = page.bounds(for: .mediaBox)
        let image = NSImage(size: bounds.size)
        image.lockFocus()

        if let context = NSGraphicsContext.current?.cgContext {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(bounds)
            page.draw(with: .mediaBox, to: context)
        }

        image.unlockFocus()
        return image
    }
}

// MARK: - Annotation Render View for Export
private struct AnnotationRenderView: View {
    let annotation: PDFAnnotationItem

    var body: some View {
        switch annotation.type {
        case .text:
            Text(annotation.content)
                .font(.system(size: 12))

        case .checkbox:
            Image(systemName: "square")
                .font(.system(size: 16))

        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)

        case .signature, .initials:
            if let imageData = annotation.signatureImage,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: annotation.size.width, height: annotation.size.height)
            } else {
                Text(annotation.content)
                    .font(.custom("Snell Roundhand", size: annotation.type == .initials ? 14 : 16))
            }

        case .date:
            Text(annotation.content)
                .font(.system(size: 11, weight: .medium))
        }
    }
}
#else
// MARK: - iOS Placeholder View
struct PaperworkView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Paperwork")
                .font(.title2.bold())

            Text("PDF annotation features are available on Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
#endif
