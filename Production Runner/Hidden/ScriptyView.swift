import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// ScriptyView is currently macOS-only
#if os(macOS)
struct ScriptyView: View {
    private enum ScriptyMode: String, CaseIterable, Identifiable {
        case script = "Script View"
        case set = "Set View"
        var id: String { rawValue }
    }

    @State private var mode: ScriptyMode = .script

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Scripty").font(.largeTitle).bold()
                Text("Script notes and continuity tracking.")
                    .foregroundColor(.secondary)
            }
            .padding([.top, .horizontal])
            .padding(.bottom, 8)

            // Toolbar (below header)
            VStack(spacing: 8) {
                Picker("Mode", selection: $mode) {
                    ForEach(ScriptyMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(toolbarBackground)
            .overlay(Divider(), alignment: .bottom)

            // Content area switching with mode
            Group {
                switch mode {
                case .script:
                    ScriptModeView()
                case .set:
                    SetModeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(appBackground)
    }

    // MARK: - Background helpers
    private var appBackground: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }

    private var toolbarBackground: some View {
        #if os(macOS)
        return Color(NSColor.underPageBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

// MARK: - Mode placeholder views
private struct ScriptModeView: View {
    // Split + data state
    @State private var leftRatio: CGFloat = 0.6
    @State private var isImportingPDF = false
    @State private var pdfURL: URL? = nil
    @State private var breakdown = BreakdownData()

    var body: some View {
        VStack(spacing: 0) {
            // Local toolbar for Script View actions
            HStack(spacing: 12) {
                Button {
                    isImportingPDF = true
                } label: {
                    Label("Import PDF", systemImage: "doc.fill.badge.plus")
                }
                .help("Choose a script PDF to display on the left pane")

                if pdfURL != nil {
                    Button { NotificationCenter.default.post(name: .pdfZoomIn, object: nil) } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    Button { NotificationCenter.default.post(name: .pdfZoomOut, object: nil) } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            #if os(macOS)
            .background(Color(NSColor.underPageBackgroundColor))
            #else
            .background(Color(UIColor.secondarySystemBackground))
            #endif
            .overlay(Divider(), alignment: .bottom)

            // Two-pane layout
            GeometryReader { proxy in
                let totalW = max(proxy.size.width, 200)
                let dividerW: CGFloat = 1
                let leftW = max(240, min(totalW * leftRatio - dividerW/2, totalW - 280))
                let rightW = totalW - leftW - dividerW

                HStack(spacing: 0) {
                    // Left: PDF script pane
                    VStack(alignment: .leading, spacing: 0) {
                        if let url = pdfURL {
                            ScriptyPDFKitView(url: url)
                                .overlay(alignment: .topLeading) { Color.clear.frame(height: 0) }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.richtext")
                                    .font(.system(size: 42))
                                    .padding(.bottom, 4)
                                Text("No PDF Loaded").font(.headline)
                                Text("Click ‘Import PDF’ to select your script.")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: leftW, height: proxy.size.height)

                    // Draggable divider
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: dividerW)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newRatio = (leftW + value.translation.width) / totalW
                                leftRatio = min(max(newRatio, 0.3), 0.7)
                            })
                        .background(
                            Rectangle().fill(Color.clear)
                                .contentShape(Rectangle())
                        )

                    // Right: Breakdown sheet pane
                    BreakdownSheetView(data: $breakdown)
                        .frame(width: rightW, height: proxy.size.height)
                }
            }
        }
        .fileImporter(isPresented: $isImportingPDF, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                pdfURL = url
            }
        }
    }
}

// MARK: - PDFKit bridge
#if os(macOS)
private struct ScriptyPDFKitView: NSViewRepresentable {
    var url: URL
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }
    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(url: url)
    }
}
#else
private struct PDFKitView: UIViewRepresentable {
    var url: URL
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
#endif

extension Notification.Name {
    static let pdfZoomIn = Notification.Name("Scripty_PDFZoomIn")
    static let pdfZoomOut = Notification.Name("Scripty_PDFZoomOut")
}

// MARK: - Breakdown Sheet
private struct BreakdownData {
    var scene: String = ""
    var slug: String = "" // e.g., INT/EXT – LOCATION – DAY/NIGHT
    var location: String = ""
    var timeOfDay: String = ""
    var cast: String = ""
    var extras: String = ""
    var props: String = ""
    var wardrobe: String = ""
    var makeupHair: String = ""
    var sfxVfx: String = ""
    var vehicles: String = ""
    var animals: String = ""
    var stunts: String = ""
    var notes: String = ""
}

private struct BreakdownSheetView: View {
    @Binding var data: BreakdownData

    var body: some View {
        #if os(macOS)
        let bg = Color(NSColor.textBackgroundColor)
        #else
        let bg = Color(UIColor.systemBackground)
        #endif

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Breakdown Sheet").font(.title3).bold()
                    Spacer()
                }
                .padding(.bottom, 4)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        field("Scene", text: $data.scene)
                        field("Slug Line", text: $data.slug)
                    }
                    GridRow {
                        field("Location", text: $data.location)
                        field("Time of Day", text: $data.timeOfDay)
                    }
                }

                GroupBox("Cast (Principals)") { multi($data.cast) }
                GroupBox("Extras / Background") { multi($data.extras) }
                GroupBox("Props / Set Dressing") { multi($data.props) }
                GroupBox("Wardrobe") { multi($data.wardrobe) }
                GroupBox("Makeup & Hair") { multi($data.makeupHair) }
                GroupBox("SFX / VFX") { multi($data.sfxVfx) }
                GroupBox("Vehicles") { multi($data.vehicles) }
                GroupBox("Animals") { multi($data.animals) }
                GroupBox("Stunts") { multi($data.stunts) }
                GroupBox("Notes") { multi($data.notes, minHeight: 140) }

                Spacer(minLength: 8)
            }
            .padding(16)
        }
        .background(bg)
    }

    // helpers
    @ViewBuilder private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder private func multi(_ text: Binding<String>, minHeight: CGFloat = 90) -> some View {
        TextEditor(text: text)
            .frame(minHeight: minHeight)
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}

private struct SetModeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set View").font(.title2).bold()
            Text("Placeholder — show continuity, takes, and set-specific notes here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}
#endif
