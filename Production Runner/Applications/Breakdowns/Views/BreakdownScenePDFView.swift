import SwiftUI
import PDFKit

/// SwiftUI view for previewing and exporting scene breakdown PDFs
struct BreakdownScenePDFView: View {
    let scene: SceneEntity
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pdfDocument: PDFDocument?
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scene \(scene.number ?? "—") Breakdown")
                    .font(.headline)

                Spacer()

                Button("Export PDF") {
                    showShareSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // PDF Preview
            if let pdfDocument = pdfDocument {
                BreakdownPDFKitView(document: pdfDocument)
            } else {
                ProgressView("Generating PDF...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 800)
        .onAppear {
            generatePDF()
        }
        #if os(macOS)
        .sheet(isPresented: $showShareSheet) {
            if let pdfDocument = pdfDocument,
               let data = pdfDocument.dataRepresentation() {
                BreakdownShareSheet(items: [data])
            }
        }
        #endif
    }

    private func generatePDF() {
        DispatchQueue.global(qos: .userInitiated).async {
            let pdf = BreakdownScenePDF.generatePDF(for: scene, context: context)
            DispatchQueue.main.async {
                self.pdfDocument = pdf
            }
        }
    }
}

// MARK: - PDFKit View Wrapper
struct BreakdownPDFKitView: View {
    let document: PDFDocument

    var body: some View {
        #if os(macOS)
        BreakdownPDFKitViewRepresentable(document: document)
        #else
        BreakdownPDFKitViewControllerRepresentable(document: document)
        #endif
    }
}

#if os(macOS)
struct BreakdownPDFKitViewRepresentable: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
#else
struct BreakdownPDFKitViewControllerRepresentable: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#endif

// MARK: - Share Sheet
#if os(macOS)
struct BreakdownShareSheet: NSViewRepresentable {
    let items: [Any]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let data = items.first as? Data else { return }

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.pdf]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.title = "Save Scene Breakdown PDF"
            savePanel.message = "Choose a location to save the breakdown PDF"
            savePanel.nameFieldStringValue = "Scene_Breakdown.pdf"

            savePanel.begin { result in
                if result == .OK, let url = savePanel.url {
                    do {
                        try data.write(to: url)
                    } catch {
                        print("Error saving PDF: \(error)")
                    }
                }
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#else
struct BreakdownShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
