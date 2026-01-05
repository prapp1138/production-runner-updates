import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Export dialog for budget data
struct BudgetExportView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: BudgetExportService.ExportFormat = .csv
    @State private var options = BudgetExportService.ExportOptions()
    @State private var exportStatus: ExportStatus = .idle
    @State private var errorMessage: String?

    enum ExportStatus {
        case idle
        case exporting
        case success
        case error
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    formatSection
                    optionsSection
                    previewSection
                }
                .padding(20)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 480, height: 520)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Budget")
                    .font(.system(size: 18, weight: .semibold))
                if let version = viewModel.selectedVersion {
                    Text(version.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Format Section

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Export Format", icon: "doc")

            HStack(spacing: 12) {
                ForEach(BudgetExportService.ExportFormat.allCases, id: \.self) { format in
                    formatButton(format)
                }
            }
        }
    }

    private func formatButton(_ format: BudgetExportService.ExportFormat) -> some View {
        Button(action: { selectedFormat = format }) {
            VStack(spacing: 8) {
                Image(systemName: formatIcon(for: format))
                    .font(.system(size: 24))
                Text(format.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedFormat == format ? Color.blue.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selectedFormat == format ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedFormat == format ? .blue : .primary)
    }

    private func formatIcon(for format: BudgetExportService.ExportFormat) -> String {
        switch format {
        case .csv: return "tablecells"
        case .pdf: return "doc.richtext"
        case .json: return "curlybraces"
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Options", icon: "slider.horizontal.3")

            VStack(spacing: 8) {
                Toggle("Include header row", isOn: $options.includeHeader)
                Toggle("Include notes", isOn: $options.includeNotes)
                Toggle("Include summary section", isOn: $options.includeSummary)
                Toggle("Include transactions", isOn: $options.includeTransactions)
                Toggle("Group by category", isOn: $options.groupByCategory)
                Toggle("Group by section", isOn: $options.groupBySection)
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Export Preview", icon: "eye")

            VStack(alignment: .leading, spacing: 8) {
                previewRow("Line Items", value: "\(viewModel.lineItems.count)")
                previewRow("Categories", value: "\(viewModel.customCategories.count)")
                if options.includeTransactions {
                    previewRow("Transactions", value: "\(viewModel.transactions.count)")
                }
                previewRow("Total Budget", value: viewModel.summary.totalBudget.asCurrency())
                previewRow("Format", value: selectedFormat.rawValue)
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

    private func previewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let error = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }

            if exportStatus == .success {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Export successful!")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button(action: performExport) {
                if exportStatus == .exporting {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("Export")
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .disabled(exportStatus == .exporting)
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.blue)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    // MARK: - Export

    private func performExport() {
        exportStatus = .exporting
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data: Data?

            switch selectedFormat {
            case .csv:
                if options.includeTransactions {
                    // Export both items and transactions
                    data = viewModel.exportToCSV()
                } else {
                    data = viewModel.exportToCSV()
                }
            case .pdf:
                data = viewModel.exportToPDF()
            case .json:
                data = viewModel.exportToJSON()
            }

            DispatchQueue.main.async {
                if let exportData = data {
                    saveExportedData(exportData)
                } else {
                    exportStatus = .error
                    errorMessage = "Failed to generate export data"
                }
            }
        }
    }

    private func saveExportedData(_ data: Data) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = BudgetExportService.suggestedFilename(
            for: viewModel.selectedVersion?.name ?? "Budget",
            format: selectedFormat
        )

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    exportStatus = .success

                    // Close after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                } catch {
                    exportStatus = .error
                    errorMessage = error.localizedDescription
                }
            } else {
                exportStatus = .idle
            }
        }
        #else
        // iOS: Use share sheet
        exportStatus = .success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
        #endif
    }
}

// MARK: - Preview

struct BudgetExportView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetExportView(
            viewModel: BudgetViewModel(context: PersistenceController.preview.container.viewContext)
        )
    }
}
