import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-platform helpers for SignaturesView
private func signatureImage(from data: Data) -> Image? {
    #if os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
    #else
    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
    #endif
}

private var signatureControlBackgroundColor: Color {
    #if os(macOS)
    Color(NSColor.controlBackgroundColor)
    #else
    Color(UIColor.secondarySystemBackground)
    #endif
}

private var signatureTextBackgroundColor: Color {
    #if os(macOS)
    Color(NSColor.textBackgroundColor)
    #else
    Color(UIColor.systemBackground)
    #endif
}

struct SignaturesView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var store: LiveModeStore

    @State private var signatures: [SignatureData] = []
    @State private var showingAddSignature: Bool = false
    @State private var selectedSignatureID: UUID?

    private var selectedSignature: SignatureData? {
        guard let id = selectedSignatureID else { return nil }
        return signatures.first { $0.id == id }
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Left: Signature list
            signatureListPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)

            // Right: Signature capture/preview
            signatureDetailPanel
                .frame(minWidth: 400)
        }
        #else
        NavigationSplitView {
            signatureListPanel
        } detail: {
            signatureDetailPanel
        }
        #endif
    }

    // MARK: - Signature List Panel

    @ViewBuilder
    private var signatureListPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Signatures")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddSignature = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(signatureControlBackgroundColor)

            Divider()

            // Signature list
            if signatures.isEmpty {
                EmptyStateView(
                    "No Signatures",
                    systemImage: "signature",
                    description: "Capture signatures for production paperwork"
                )
            } else {
                List(selection: $selectedSignatureID) {
                    ForEach(signatures) { signature in
                        SignatureListRow(signature: signature)
                            .tag(signature.id)
                    }
                    .onDelete(perform: deleteSignatures)
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            HStack {
                Text("\(signatures.count) signatures")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !signatures.isEmpty {
                    Button("Export All") {
                        exportSignatures()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(signatureControlBackgroundColor)
        }
        .background(signatureTextBackgroundColor)
        .sheet(isPresented: $showingAddSignature) {
            AddSignatureSheet(isPresented: $showingAddSignature) { signature in
                signatures.append(signature)
            }
        }
    }

    // MARK: - Signature Detail Panel

    @ViewBuilder
    private var signatureDetailPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Signature Details")
                    .font(.headline)
                Spacer()
            }
            .padding(16)
            .background(signatureControlBackgroundColor)

            Divider()

            // Content
            if let signature = selectedSignature {
                signatureDetailContent(signature)
            } else {
                EmptyStateView(
                    "Select a Signature",
                    systemImage: "hand.tap",
                    description: "Choose a signature to view details"
                )
            }
        }
        .background(signatureTextBackgroundColor)
    }

    @ViewBuilder
    private func signatureDetailContent(_ signature: SignatureData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Signature image
                VStack(spacing: 12) {
                    if let imageData = signature.signatureImageData,
                       let signatureImage = signatureImage(from: imageData) {
                        signatureImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    } else if let textSignature = signature.signatureText {
                        Text(textSignature)
                            .font(.custom("Snell Roundhand", size: 48))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }

                // Signature info
                VStack(alignment: .leading, spacing: 16) {
                    SignatureDetailRow(label: "Name", value: signature.signerName)
                    SignatureDetailRow(label: "Role", value: signature.signerRole)
                    SignatureDetailRow(label: "Signed At", value: signature.signedAt.formatted(date: .long, time: .shortened))
                    if let ip = signature.ipAddress {
                        SignatureDetailRow(label: "IP Address", value: ip)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(signatureControlBackgroundColor)
                )

                // Actions
                HStack(spacing: 16) {
                    Button {
                        // Export this signature
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        signatures.removeAll { $0.id == signature.id }
                        selectedSignatureID = nil
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Helpers

    private func deleteSignatures(at offsets: IndexSet) {
        signatures.remove(atOffsets: offsets)
    }

    private func exportSignatures() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Signatures_\(Date().formatted(date: .numeric, time: .omitted)).pdf"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                generateSignaturesPDF(to: url)
            }
        }
        #endif
    }

    #if os(macOS)
    private func generateSignaturesPDF(to url: URL) {
        let pdfMetaData = [
            kCGPDFContextCreator: "Production Runner",
            kCGPDFContextTitle: "Signatures Report"
        ]

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let pdfContext = CGContext(url as CFURL, mediaBox: &pageRect, pdfMetaData as CFDictionary) else {
            print("[SignaturesView] Failed to create PDF context")
            return
        }

        pdfContext.beginPDFPage(nil)

        // Draw title
        let titleFont = NSFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]

        let title = NSAttributedString(string: "SIGNATURES REPORT", attributes: titleAttributes)
        let titleLine = CTLineCreateWithAttributedString(title)
        pdfContext.textPosition = CGPoint(x: 50, y: pageHeight - 50)
        CTLineDraw(titleLine, pdfContext)

        var yOffset: CGFloat = pageHeight - 100

        // Draw each signature
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]

        for signature in signatures {
            // Draw name and role
            let nameText = NSAttributedString(string: "\(signature.signerName) - \(signature.signerRole)", attributes: bodyAttributes)
            let nameLine = CTLineCreateWithAttributedString(nameText)
            pdfContext.textPosition = CGPoint(x: 50, y: yOffset)
            CTLineDraw(nameLine, pdfContext)

            // Draw date
            let dateText = NSAttributedString(string: "Signed: \(signature.signedAt.formatted())", attributes: bodyAttributes)
            let dateLine = CTLineCreateWithAttributedString(dateText)
            pdfContext.textPosition = CGPoint(x: 50, y: yOffset - 20)
            CTLineDraw(dateLine, pdfContext)

            // Draw signature image if available
            if let imageData = signature.signatureImageData,
               let nsImage = NSImage(data: imageData),
               let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let imageRect = CGRect(x: 50, y: yOffset - 100, width: 200, height: 60)
                pdfContext.draw(cgImage, in: imageRect)
                yOffset -= 140
            } else if let textSig = signature.signatureText {
                let sigFont = NSFont(name: "Snell Roundhand", size: 24) ?? NSFont.systemFont(ofSize: 24)
                let sigAttributes: [NSAttributedString.Key: Any] = [
                    .font: sigFont,
                    .foregroundColor: NSColor.black
                ]
                let sigText = NSAttributedString(string: textSig, attributes: sigAttributes)
                let sigLine = CTLineCreateWithAttributedString(sigText)
                pdfContext.textPosition = CGPoint(x: 50, y: yOffset - 60)
                CTLineDraw(sigLine, pdfContext)
                yOffset -= 100
            } else {
                yOffset -= 60
            }

            // Add separator
            yOffset -= 20

            // Check if we need a new page
            if yOffset < 100 {
                pdfContext.endPDFPage()
                pdfContext.beginPDFPage(nil)
                yOffset = pageHeight - 50
            }
        }

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        print("[SignaturesView] PDF exported to \(url.path)")
    }
    #endif
}

// MARK: - Signature List Row

struct SignatureListRow: View {
    let signature: SignatureData

    var body: some View {
        HStack(spacing: 12) {
            // Signature preview
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .frame(width: 60, height: 40)

                if let imageData = signature.signatureImageData,
                   let signatureImage = signatureImage(from: imageData) {
                    signatureImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 54, height: 34)
                } else if let textSignature = signature.signatureText {
                    Text(textSignature)
                        .font(.custom("Snell Roundhand", size: 14))
                        .lineLimit(1)
                } else {
                    Image(systemName: "signature")
                        .foregroundStyle(.tertiary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(signature.signerName)
                    .font(.subheadline.weight(.medium))
                Text(signature.signerRole)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(signature.signedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Signature Detail Row

struct SignatureDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Add Signature Sheet

struct AddSignatureSheet: View {
    @Binding var isPresented: Bool
    let onSave: (SignatureData) -> Void

    @State private var signerName: String = ""
    @State private var signerRole: String = ""
    @State private var signatureMode: SignatureMode = .text
    @State private var textSignature: String = ""
    @State private var canvasLines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []

    enum SignatureMode: String, CaseIterable {
        case text = "Type"
        case draw = "Draw"

        var icon: String {
            switch self {
            case .text: return "keyboard"
            case .draw: return "pencil.tip"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Signature")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(spacing: 20) {
                    // Signer info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Signer Information")
                            .font(.headline)

                        TextField("Full Name", text: $signerName)
                            .textFieldStyle(.roundedBorder)

                        TextField("Role/Title", text: $signerRole)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Signature mode picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Signature")
                            .font(.headline)

                        Picker("Mode", selection: $signatureMode) {
                            ForEach(SignatureMode.allCases, id: \.self) { mode in
                                Label(mode.rawValue, systemImage: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        // Signature input
                        switch signatureMode {
                        case .text:
                            textSignatureInput
                        case .draw:
                            drawSignatureInput
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Clear") {
                    textSignature = ""
                    canvasLines = []
                    currentLine = []
                }
                .buttonStyle(.bordered)
                .disabled(textSignature.isEmpty && canvasLines.isEmpty)

                Button("Save Signature") {
                    saveSignature()
                }
                .buttonStyle(.borderedProminent)
                .disabled(signerName.isEmpty || signerRole.isEmpty || !hasSignature)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
    }

    @ViewBuilder
    private var textSignatureInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Type your signature", text: $textSignature)
                .textFieldStyle(.plain)
                .font(.custom("Snell Roundhand", size: 32))
                .padding()
                .frame(height: 100)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text("Your typed signature will be styled in a handwriting font")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var drawSignatureInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Canvas placeholder - in a real implementation this would be a drawing canvas
            ZStack {
                Color.white

                if canvasLines.isEmpty && currentLine.isEmpty {
                    Text("Draw your signature here")
                        .foregroundStyle(.tertiary)
                }

                // Drawing canvas would go here
                Canvas { context, size in
                    for line in canvasLines {
                        var path = Path()
                        if let first = line.first {
                            path.move(to: first)
                            for point in line.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        context.stroke(path, with: .color(.black), lineWidth: 2)
                    }

                    if !currentLine.isEmpty {
                        var path = Path()
                        if let first = currentLine.first {
                            path.move(to: first)
                            for point in currentLine.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        context.stroke(path, with: .color(.black), lineWidth: 2)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentLine.append(value.location)
                        }
                        .onEnded { _ in
                            canvasLines.append(currentLine)
                            currentLine = []
                        }
                )
            }
            .frame(height: 150)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            Text("Use your mouse or trackpad to draw your signature")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hasSignature: Bool {
        switch signatureMode {
        case .text:
            return !textSignature.isEmpty
        case .draw:
            return !canvasLines.isEmpty
        }
    }

    private func saveSignature() {
        let signature = SignatureData(
            id: UUID(),
            signerName: signerName,
            signerRole: signerRole,
            signatureImageData: signatureMode == .draw ? captureCanvasImage() : nil,
            signatureText: signatureMode == .text ? textSignature : nil,
            signedAt: Date(),
            ipAddress: nil
        )
        onSave(signature)
        isPresented = false
    }

    private func captureCanvasImage() -> Data? {
        // Create a view that renders the signature strokes
        let signatureView = SignatureCanvasRenderer(lines: canvasLines)

        #if os(macOS)
        // Use ImageRenderer to capture the view
        let renderer = ImageRenderer(content: signatureView.frame(width: 400, height: 150))
        renderer.scale = 2.0 // Retina quality

        guard let nsImage = renderer.nsImage else { return nil }
        guard let tiffData = nsImage.tiffRepresentation else { return nil }
        guard let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmapRep.representation(using: .png, properties: [:])
        #else
        let renderer = ImageRenderer(content: signatureView.frame(width: 400, height: 150))
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.pngData()
        #endif
    }
}

// MARK: - Signature Canvas Renderer
/// A view that renders signature strokes for image capture
private struct SignatureCanvasRenderer: View {
    let lines: [[CGPoint]]

    var body: some View {
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
        .background(Color.white)
    }
}

#Preview {
    SignaturesView()
        .environmentObject(LiveModeStore())
}
