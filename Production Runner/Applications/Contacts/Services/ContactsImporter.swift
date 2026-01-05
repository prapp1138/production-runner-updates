//
//  ContactsImporter.swift
//  Production Runner
//
//  Import contacts from CSV, TSV, XLSX, or ODS files
//

import SwiftUI
import UniformTypeIdentifiers
import CoreXLSX

// MARK: - Import Data Models
struct ImportColumn: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let header: String
    let sampleData: [String]
    var mappedField: ContactField?
    
    enum ContactField: String, CaseIterable, Hashable {
        case name = "Name"
        case role = "Role"
        case phone = "Phone"
        case email = "Email"
        case allergies = "Allergies"
        case category = "Category"
        case department = "Department"
        case ignore = "— Don't Import —"
        
        var icon: String {
            switch self {
            case .name: return "person.fill"
            case .role: return "briefcase.fill"
            case .phone: return "phone.fill"
            case .email: return "envelope.fill"
            case .allergies: return "exclamationmark.triangle.fill"
            case .category: return "tag.fill"
            case .department: return "building.2.fill"
            case .ignore: return "xmark.circle"
            }
        }
    }
}

struct ParsedContactData {
    let columns: [ImportColumn]
    let rows: [[String]]
}

// MARK: - CSV/TSV/XLSX/ODS Parser
struct ContactFileParser {
    static func parse(url: URL) throws -> ParsedContactData {
        guard url.startAccessingSecurityScopedResource() else {
            throw ParsingError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "csv":
            return try parseCSV(url: url, delimiter: ",")
        case "tsv":
            return try parseCSV(url: url, delimiter: "\t")
        case "xlsx":
            return try parseXLSX(url: url)
        case "ods":
            throw ParsingError.unsupportedFormat("Please export ODS to CSV format first")
        default:
            throw ParsingError.unsupportedFormat("Unsupported file format: .\(fileExtension)")
        }
    }
    
    // MARK: - CSV/TSV Parser
    private static func parseCSV(url: URL, delimiter: String) throws -> ParsedContactData {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw ParsingError.emptyFile
        }

        // Parse header row
        // Safe: already validated lines is not empty above
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine, delimiter: delimiter)
        
        // Parse data rows
        let dataLines = Array(lines.dropFirst())
        let rows = dataLines.map { parseCSVLine($0, delimiter: delimiter) }
        
        // Create columns with sample data
        let columns = headers.enumerated().map { index, header in
            let sampleData = rows.prefix(3).map { row in
                index < row.count ? row[index] : ""
            }
            
            // Auto-detect field based on header name
            let detectedField = autoDetectField(header: header)
            
            return ImportColumn(
                index: index,
                header: header.isEmpty ? "Column \(index + 1)" : header,
                sampleData: sampleData,
                mappedField: detectedField
            )
        }
        
        return ParsedContactData(columns: columns, rows: rows)
    }
    
    // CSV line parser that handles escaped quotes ("" -> ") and quoted fields
    private static func parseCSVLine(_ line: String, delimiter: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        // Fixed: Safe optional binding instead of force unwrap
        guard let delimiterChar = delimiter.first else {
            // If delimiter is empty, return the whole line as a single field
            return [line]
        }
        var previousWasQuote = false

        for char in line {
            if char == "\"" {
                if insideQuotes {
                    if previousWasQuote {
                        // This is an escaped quote ("") - add a single quote
                        currentField.append("\"")
                        previousWasQuote = false
                    } else {
                        // Could be end of quote or start of escaped quote
                        previousWasQuote = true
                    }
                } else {
                    // Start of quoted field
                    insideQuotes = true
                    previousWasQuote = false
                }
            } else {
                if previousWasQuote {
                    // Previous quote was the end of the quoted field
                    insideQuotes = false
                    previousWasQuote = false
                }

                if char == delimiterChar && !insideQuotes {
                    fields.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else {
                    currentField.append(char)
                }
            }
        }

        // Handle trailing quote
        if previousWasQuote {
            insideQuotes = false
        }

        // Add the last field, trimming any trailing newlines/whitespace
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))

        return fields
    }
    
    // MARK: - XLSX Parser
    private static func parseXLSX(url: URL) throws -> ParsedContactData {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ParsingError.unsupportedFormat("Could not read XLSX file")
        }
        
        let sharedStrings = try? file.parseSharedStrings()
        
        guard let worksheetPaths = try? file.parseWorksheetPaths() else {
            throw ParsingError.emptyFile
        }
        
        guard !worksheetPaths.isEmpty else {
            throw ParsingError.unsupportedFormat("No worksheets found in XLSX file")
        }
        
        // Try each worksheet until we find one with data
        for worksheetPath in worksheetPaths {
            do {
                let worksheet = try file.parseWorksheet(at: worksheetPath)
                
                guard let sheetData = worksheet.data, !sheetData.rows.isEmpty else {
                    continue // Try next sheet
                }
                
                // Find the maximum column index by converting letters to numbers
                var maxColumn: Int = 0
                for row in sheetData.rows {
                    for cell in row.cells {
                        let colLetter = cell.reference.column.value
                        let colIndex = columnLetterToNumber(colLetter)
                        maxColumn = max(maxColumn, colIndex)
                    }
                }
                
                guard maxColumn > 0 else {
                    continue // Try next sheet
                }
                
                // Parse all rows
                var allRows: [[String]] = []
                for row in sheetData.rows {
                    var rowData: [String] = Array(repeating: "", count: maxColumn)
                    
                    for cell in row.cells {
                        let colLetter = cell.reference.column.value
                        let colIndex = columnLetterToNumber(colLetter)
                        let index = colIndex - 1 // Convert to 0-based index
                        
                        if index >= 0 && index < rowData.count {
                            rowData[index] = cellValue(cell, sharedStrings: sharedStrings)
                        }
                    }
                    
                    // Only add rows that have at least one non-empty cell
                    if !rowData.allSatisfy({ $0.isEmpty }) {
                        allRows.append(rowData)
                    }
                }
                
                // If this sheet has data, use it
                if !allRows.isEmpty {
                    // First row is headers
                    // Safe: already validated allRows is not empty above
                    let headers = allRows[0]
                    let dataRows = Array(allRows.dropFirst())

                    // Make sure we have at least headers
                    guard !headers.allSatisfy({ $0.isEmpty }) else {
                        continue // Try next sheet
                    }
                    
                    let columns = headers.enumerated().map { index, header in
                        let sampleData = dataRows.prefix(3).map { row in
                            index < row.count ? row[index] : ""
                        }
                        let detectedField = autoDetectField(header: header)
                        return ImportColumn(
                            index: index,
                            header: header.isEmpty ? "Column \(index + 1)" : header,
                            sampleData: sampleData,
                            mappedField: detectedField
                        )
                    }
                    
                    return ParsedContactData(columns: columns, rows: dataRows)
                }
            } catch {
                // If this sheet fails, try the next one
                continue
            }
        }
        
        // If we get here, no worksheets had valid data
        throw ParsingError.unsupportedFormat("No data found in any worksheet. Make sure at least one sheet has headers in the first row and data below.")
    }
    
    // Convert Excel column letter (A, B, C, ..., Z, AA, AB, ...) to number (1, 2, 3, ...)
    private static func columnLetterToNumber(_ letters: String) -> Int {
        var result = 0
        for char in letters.uppercased() {
            guard let value = char.asciiValue, value >= 65, value <= 90 else {
                continue
            }
            result = result * 26 + Int(value - 64)
        }
        return result
    }
    
    private static func cellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let inlineString = cell.inlineString {
            return inlineString.text ?? ""
        }
        if let value = cell.value {
            return value
        }
        if cell.type == .sharedString, let stringValue = cell.value {
            if let index = Int(stringValue), let sharedStrings = sharedStrings {
                if index < sharedStrings.items.count {
                    return sharedStrings.items[index].text ?? ""
                }
            }
        }
        return ""
    }
    
    // Auto-detect field mapping based on header name
    private static func autoDetectField(header: String) -> ImportColumn.ContactField? {
        let lower = header.lowercased()
        
        if lower.contains("name") { return .name }
        if lower.contains("role") || lower.contains("title") || lower.contains("position") { return .role }
        if lower.contains("phone") || lower.contains("mobile") || lower.contains("cell") { return .phone }
        if lower.contains("email") || lower.contains("mail") { return .email }
        if lower.contains("allerg") { return .allergies }
        if lower.contains("category") || lower.contains("type") { return .category }
        if lower.contains("department") || lower.contains("dept") { return .department }
        
        return nil
    }
    
    enum ParsingError: LocalizedError {
        case accessDenied
        case emptyFile
        case unsupportedFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Could not access the file"
            case .emptyFile:
                return "The file is empty"
            case .unsupportedFormat(let message):
                return message
            }
        }
    }
}

// MARK: - Column Mapper Sheet
struct ContactColumnMapperSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let parsedData: ParsedContactData
    let onImport: ([Contact]) -> Void
    
    @State private var columns: [ImportColumn]
    @State private var showingPreview = false
    @State private var previewContacts: [Contact] = []
    
    init(parsedData: ParsedContactData, onImport: @escaping ([Contact]) -> Void) {
        self.parsedData = parsedData
        self.onImport = onImport
        self._columns = State(initialValue: parsedData.columns)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Column mapping list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($columns) { $column in
                        columnMapperRow(column: $column)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer with actions
            footer
        }
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showingPreview) {
            previewSheet
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Map Import Columns")
                    .font(.title2.bold())
                Spacer()
            }
            
            Text("Match each column from your file to a contact field")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                Label("\(parsedData.rows.count) rows", systemImage: "tablecells")
                Label("\(parsedData.columns.count) columns", systemImage: "square.grid.3x1.below.line.grid.1x2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
    }
    
    // MARK: - Column Mapper Row
    private func columnMapperRow(column: Binding<ImportColumn>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Column info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(column.wrappedValue.header)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    
                    Text("Col \(column.wrappedValue.index + 1)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                // Sample data
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(column.wrappedValue.sampleData, id: \.self) { sample in
                        if !sample.isEmpty {
                            Text(sample)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Field picker
            Menu {
                ForEach(ImportColumn.ContactField.allCases, id: \.self) { field in
                    Button {
                        column.wrappedValue.mappedField = field == .ignore ? nil : field
                    } label: {
                        Label(field.rawValue, systemImage: field.icon)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if let mapped = column.wrappedValue.mappedField {
                        Image(systemName: mapped.icon)
                            .foregroundStyle(.blue)
                        Text(mapped.rawValue)
                            .fontWeight(.medium)
                    } else {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                        Text("Select Field...")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(width: 200)
        }
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
            
            Spacer()
            
            Button("Preview Import") {
                generatePreview()
                showingPreview = true
            }
            .disabled(!hasNameMapping)
            
            Button("Import") {
                performImport()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!hasNameMapping)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
    
    // MARK: - Preview Sheet
    private var previewSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview Import (\(previewContacts.count) contacts)")
                    .font(.headline)
                Spacer()
                Button("Close") { showingPreview = false }
            }
            .padding()
            
            Divider()
            
            List(previewContacts) { contact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.headline)
                    HStack {
                        if !contact.role.isEmpty {
                            Text(contact.role)
                        }
                        if !contact.email.isEmpty {
                            Text("•")
                            Text(contact.email)
                        }
                        if !contact.phone.isEmpty {
                            Text("•")
                            Text(contact.phone)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - Helpers
    private var hasNameMapping: Bool {
        columns.contains { $0.mappedField == .name }
    }
    
    private func generatePreview() {
        previewContacts = parsedData.rows.prefix(10).compactMap { row in
            createContact(from: row)
        }
    }
    
    private func performImport() {
        let contacts = parsedData.rows.compactMap { row in
            createContact(from: row)
        }
        onImport(contacts)
        dismiss()
    }
    
    private func createContact(from row: [String]) -> Contact? {
        var name = ""
        var role = ""
        var phone = ""
        var email = ""
        var allergies = ""
        var category: Contact.Category = .crew
        var department: Contact.Department = .production
        
        for column in columns {
            guard column.index < row.count,
                  let field = column.mappedField else { continue }
            
            let value = row[column.index].trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch field {
            case .name:
                name = value
            case .role:
                role = value
            case .phone:
                phone = value
            case .email:
                email = value
            case .allergies:
                allergies = value
            case .category:
                // Parse category from value
                let lower = value.lowercased()
                if lower.contains("cast") { category = .cast }
                else if lower.contains("vendor") { category = .vendor }
                else { category = .crew }
            case .department:
                // Parse department from value
                if let dept = Contact.Department.allCases.first(where: {
                    value.lowercased().contains($0.rawValue.lowercased())
                }) {
                    department = dept
                }
            case .ignore:
                break
            }
        }
        
        // Must have a name to be valid
        guard !name.isEmpty else { return nil }
        
        return Contact(
            id: UUID(),
            name: name,
            role: role,
            phone: phone,
            email: email,
            allergies: allergies,
            paperworkStarted: false,
            paperworkComplete: false,
            category: category,
            department: department
        )
    }
}

// MARK: - File Importer Wrapper
struct ContactsFileImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onFileSelected: (URL) -> Void
    
    func body(content: Content) -> some View {
        let supportedTypes: [UTType] = [
            .commaSeparatedText,
            .tabSeparatedText
        ] + [
            UTType(filenameExtension: "xlsx"),
            UTType(filenameExtension: "ods")
        ].compactMap { $0 }
        
        return content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        onFileSelected(url)
                    }
                case .failure(let error):
                    print("File import error: \(error)")
                }
            }
    }
}

extension View {
    func contactsFileImporter(isPresented: Binding<Bool>, onFileSelected: @escaping (URL) -> Void) -> some View {
        modifier(ContactsFileImporterModifier(isPresented: isPresented, onFileSelected: onFileSelected))
    }
}
