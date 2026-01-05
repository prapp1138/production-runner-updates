import SwiftUI
import CoreData

// Lightweight in-file model so this view works immediately.
// You can move this to its own file or Core Data later.
struct Contact: Identifiable, Hashable {
    enum Category: String, CaseIterable, Hashable, Codable {
        case cast, crew, vendor
        var displayName: String { rawValue.capitalized }
    }

    // Cast-specific type (used instead of Department for Cast category)
    enum CastType: String, CaseIterable, Hashable, Codable {
        case leadCast = "🎭 Lead Cast"
        case supportingCast = "🎭 Supporting Cast"
        case dayPlay = "🎭 Day Play"
        case backgroundExtra = "🎭 Background/Extra"
        var displayName: String { rawValue }
    }

    enum Department: String, CaseIterable, Hashable, Codable {
        // Cast types (for when category is Cast)
        case castLead = "🎭 Lead Cast"
        case castSupporting = "🎭 Supporting Cast"
        case castDayPlay = "🎭 Day Play"
        case castBackground = "🎭 Background/Extra"
        // Crew departments
        case production = "📋 Production"
        case art = "📚 Art Department"
        case camera = "🎥 Camera"
        case gripElectric = "💡 Grip & Electric"
        case sound = "🔈 Sound"
        case costumeHairMakeup = "👗 Costume, Hair & Makeup"
        case specialEffects = "🎞 Special Effects"
        case stunts = "🎬 Stunts"
        case locations = "📍 Locations"
        case transportation = "🚚 Transportation"
        case craftServices = "🎨 Craft Services"
        case postProduction = "📡 Post-Production"
        case miscellaneous = "🧰 Miscellaneous"
        var displayName: String { rawValue }

        // Filter departments by category
        static var castDepartments: [Department] {
            [.castLead, .castSupporting, .castDayPlay, .castBackground]
        }

        static var crewDepartments: [Department] {
            allCases.filter { !castDepartments.contains($0) }
        }

        var isCastDepartment: Bool {
            Self.castDepartments.contains(self)
        }
    }

    // Contract status for tracking deal memos
    enum ContractStatus: String, CaseIterable, Hashable, Codable {
        case none = "None"
        case pending = "Pending"
        case sent = "Sent"
        case signed = "Signed"
        case expired = "Expired"

        var displayName: String { rawValue }

        var color: Color {
            switch self {
            case .none: return .secondary
            case .pending: return .orange
            case .sent: return .blue
            case .signed: return .green
            case .expired: return .red
            }
        }
    }

    var id: UUID = .init()
    var name: String
    var role: String
    var phone: String
    var email: String
    var allergies: String
    var paperworkStarted: Bool
    var paperworkComplete: Bool
    var category: Category
    var department: Department
    var sortOrder: Int32 = 0

    // New fields for enhanced features
    var isFavorite: Bool = false
    var photoData: Data? = nil
    var thumbnailData: Data? = nil
    var lastViewedAt: Date? = nil
    var lastContactedAt: Date? = nil
    var tags: [String] = []
    var contractStatus: ContractStatus = .none
    var availabilityStart: Date? = nil
    var availabilityEnd: Date? = nil
    var modifiedAt: Date? = nil
}

#if os(macOS)
import AppKit
import PDFKit

// MARK: - TextField with Full Keyboard Support for Table Cells
// This custom NSTextField ensures proper keyboard handling when embedded in SwiftUI Table views

class ContactsTextField: NSTextField {
    // Track if we're actively editing to properly handle keyboard events
    private var isEditing: Bool = false

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            isEditing = true
            // Select all text when becoming first responder for easy replacement
            if let editor = currentEditor() {
                editor.selectAll(nil)
            }
        }
        return result
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        isEditing = true
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        isEditing = false
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Only handle events if we're actively editing
        guard isEditing, let editor = currentEditor() else {
            return super.performKeyEquivalent(with: event)
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""

        // Handle CMD+A for select all
        if modifiers == .command && chars == "a" {
            editor.selectAll(nil)
            return true
        }

        // Handle CMD+C for copy
        if modifiers == .command && chars == "c" {
            editor.copy(nil)
            return true
        }

        // Handle CMD+V for paste
        if modifiers == .command && chars == "v" {
            editor.paste(nil)
            return true
        }

        // Handle CMD+X for cut
        if modifiers == .command && chars == "x" {
            editor.cut(nil)
            return true
        }

        // Handle CMD+Z for undo
        if modifiers == .command && chars == "z" {
            editor.undoManager?.undo()
            return true
        }

        // Handle CMD+Shift+Z for redo
        if modifiers == [.command, .shift] && chars == "z" {
            editor.undoManager?.redo()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    // Override keyDown to intercept ALL key presses when editing
    // This prevents the Table view from intercepting characters
    override func keyDown(with event: NSEvent) {
        guard isEditing, let editor = currentEditor() else {
            super.keyDown(with: event)
            return
        }

        let chars = event.characters ?? ""
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Handle Tab key - move to next field
        if event.keyCode == 48 { // Tab key
            window?.selectNextKeyView(nil)
            return
        }

        // Handle Shift+Tab - move to previous field
        if event.keyCode == 48 && modifiers.contains(.shift) {
            window?.selectPreviousKeyView(nil)
            return
        }

        // Handle Return/Enter - end editing
        if event.keyCode == 36 || event.keyCode == 76 { // Return or Enter
            window?.makeFirstResponder(nil)
            return
        }

        // Handle Escape - cancel editing
        if event.keyCode == 53 { // Escape
            abortEditing()
            window?.makeFirstResponder(nil)
            return
        }

        // Handle arrow keys - let the editor handle them for cursor movement
        if [123, 124, 125, 126].contains(Int(event.keyCode)) { // Left, Right, Down, Up arrows
            editor.keyDown(with: event)
            return
        }

        // Handle Delete/Backspace
        if event.keyCode == 51 || event.keyCode == 117 { // Delete or Forward Delete
            editor.keyDown(with: event)
            return
        }

        // For all other characters (including space), insert them directly
        if !chars.isEmpty && modifiers.isEmpty || modifiers == .shift {
            editor.insertText(chars)
            return
        }

        // Let super handle anything else
        super.keyDown(with: event)
    }
}

struct SelectableTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onCommit: (() -> Void)?
    var onFocus: (() -> Void)?

    func makeNSView(context: Context) -> ContactsTextField {
        let textField = ContactsTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.delegate = context.coordinator
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        textField.lineBreakMode = .byTruncatingTail
        textField.allowsEditingTextAttributes = false
        textField.isEditable = true
        textField.isSelectable = true
        return textField
    }

    func updateNSView(_ nsView: ContactsTextField, context: Context) {
        // Only update if the text has actually changed to avoid cursor jumping
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SelectableTextField
        private var lastKnownText: String = ""

        init(_ parent: SelectableTextField) {
            self.parent = parent
            self.lastKnownText = parent.text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let newText = textField.stringValue
            // Only update if text actually changed
            if newText != lastKnownText {
                lastKnownText = newText
                DispatchQueue.main.async {
                    self.parent.text = newText
                }
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit?()
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocus?()
        }

        // Handle control:textView:doCommandBy: to intercept commands
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Return/Enter to end editing
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                return true
            }
            // Handle Tab to move to next field
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                control.window?.selectNextKeyView(nil)
                return true
            }
            // Handle Shift+Tab to move to previous field
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                control.window?.selectPreviousKeyView(nil)
                return true
            }
            // Handle Escape to cancel editing
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}
#endif

// MARK: - iOS SelectableTextField
#if os(iOS)
import UIKit

/// UIViewRepresentable wrapper for UITextField that supports text selection on iOS
struct SelectableTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onCommit: (() -> Void)?
    var onFocus: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.delegate = context.coordinator
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no

        // Add action for text changes
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if the text has actually changed to avoid cursor jumping
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectableTextField
        private var lastKnownText: String = ""

        init(_ parent: SelectableTextField) {
            self.parent = parent
            self.lastKnownText = parent.text
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            let newText = textField.text ?? ""
            // Only update if text actually changed
            if newText != lastKnownText {
                lastKnownText = newText
                DispatchQueue.main.async {
                    self.parent.text = newText
                }
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onCommit?()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocus?()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
#endif

#if os(macOS)
struct ContactsView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme

    // Contacts app purple color (matching sidebar)
    private let contactsPurple = Color.purple

    // Core Data entity/keys used for persistence
    private let contactEntityName = "ContactEntity"
    private enum CK {
        static let id = "id"
        static let name = "name"
        static let email = "email"
        static let phone = "phone"
        static let note = "note"
        static let createdAt = "createdAt"
    }

    // MARK: - Core Data attribute helpers & category/department persistence
    private func entityAttributes() -> [String: NSAttributeDescription] {
        guard
            let psc = ctx.persistentStoreCoordinator,
            let entity = psc.managedObjectModel.entitiesByName[contactEntityName]
        else { return [:] }
        return entity.attributesByName
    }

    private func entityHas(_ key: String) -> Bool {
        entityAttributes()[key] != nil
    }

    // Normalize note by removing any prior [cast]/[crew]/[vendor] tags at the start
    private func stripCategoryTag(from note: String) -> String {
        let pattern = #"^\s*\[(cast|crew|vendor)\]\s*"#
        return note.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    // Read category either from a `category` attribute (String/Int) or from a leading `[cast]`/`[crew]`/`[vendor]` tag in `note`.
    private func readCategory(from mo: NSManagedObject) -> Contact.Category {
        let attrs = entityAttributes()
        if let attr = attrs["category"] {
            switch attr.attributeType {
            case .stringAttributeType:
                if let raw = (mo.value(forKey: "category") as? String)?.lowercased(),
                   let cat = Contact.Category(rawValue: raw) { return cat }
            case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                if let n = mo.value(forKey: "category") as? NSNumber {
                    switch n.intValue { case 0: return .cast; case 1: return .crew; case 2: return .vendor; default: break }
                }
            default: break
            }
        }
        // Fall back to note tag
        if let note = (mo.value(forKey: CK.note) as? String)?.lowercased() {
            if note.contains("[cast]")   { return .cast }
            if note.contains("[vendor]") { return .vendor }
            if note.contains("[crew]")   { return .crew }
        }
        return .crew
    }

    // Persist category into the best available place (attribute if present, otherwise a tag in `note`).
    private func writeCategory(_ cat: Contact.Category, into mo: NSManagedObject) {
        let attrs = entityAttributes()
        if let attr = attrs["category"] {
            switch attr.attributeType {
            case .stringAttributeType:
                mo.setValue(cat.rawValue, forKey: "category"); return
            case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                let mapped: Int = (cat == .cast ? 0 : cat == .crew ? 1 : 2)
                mo.setValue(mapped as NSNumber, forKey: "category"); return
            default: break
            }
        }
        // No `category` attribute — encode into `note` as a leading tag
        guard entityHas(CK.note) else { return }
        let existing = (mo.value(forKey: CK.note) as? String) ?? ""
        let cleaned = stripCategoryTag(from: existing)
        mo.setValue("[\(cat.rawValue)] " + cleaned, forKey: CK.note)
    }

    // Department read/write if attribute exists; otherwise keep in-memory default
    private func readDepartment(from mo: NSManagedObject) -> Contact.Department {
        guard entityHas("department"),
              let raw = mo.value(forKey: "department") as? String,
              let dep = Contact.Department(rawValue: raw) else { return .production }
        return dep
    }

    private func writeDepartment(_ dept: Contact.Department, into mo: NSManagedObject) {
        guard entityHas("department") else { return }
        mo.setValue(dept.rawValue, forKey: "department")
    }
    // Search and in-memory data for now
    @State private var searchText = ""
    @State private var contacts: [Contact] = []

    // Undo/Redo state
    @StateObject private var undoRedoManager = UndoRedoManager<[Contact]>(maxHistorySize: 10)
    private enum SidebarFilter: String, CaseIterable { case all = "All", favorites = "Favorites", recent = "Recent", cast = "Cast", crew = "Crew", vendor = "Vendors" }
    @State private var selectedFilter: SidebarFilter = .all
    @State private var selectedDepartment: Contact.Department? = nil
    @State private var selection: Set<UUID> = []
    @State private var clipboard: [Contact] = []
    @State private var showFavoritesOnly: Bool = false

    // Multi-select filtering (AND logic)
    @State private var selectedCategories: Set<Contact.Category> = []
    @State private var selectedTags: Set<String> = []
    @State private var showingMultiFilterPopover: Bool = false

    // Import/Export state
    @State private var showingFileImporter = false
    @State private var showingColumnMapper = false
    @State private var parsedImportData: ParsedContactData? = nil
    @State private var exportPDFURL: URL? = nil

    // Department Management
    @State private var showingDepartmentManager = false
    @AppStorage("production_departments") private var departmentsData: Data = Data()
    @State private var departments: [ProductionDepartment] = []

    // Unit Management
    @State private var showingUnitManager = false

    // Tag Management
    @State private var showingTagManager = false

    // Template Management
    @State private var showingTemplateManager = false

    // Error alert state
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    // Roles from Core Data
    @State private var availableRoles: [String] = []

    // Debounce timer for text editors (allergies field)
    @State private var allergiesSaveWorkItem: DispatchWorkItem?

    // MARK: - Core Data helpers (persist all contact fields)
    private func fetchStoreContacts() -> [Contact] {
        let req = NSFetchRequest<NSManagedObject>(entityName: contactEntityName)
        // Sort by sortOrder first, then by createdAt as fallback
        req.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: CK.createdAt, ascending: false),
            NSSortDescriptor(key: CK.name, ascending: true)
        ]
        do {
            let rows = try ctx.fetch(req)
            return rows.map { mo in
                let id = (mo.value(forKey: CK.id) as? UUID) ?? UUID()
                let name = (mo.value(forKey: CK.name) as? String) ?? "Untitled"
                let email = (mo.value(forKey: CK.email) as? String) ?? ""
                let phone = (mo.value(forKey: CK.phone) as? String) ?? ""
                let role = (mo.value(forKey: "role") as? String) ?? ""
                let allergies = (mo.value(forKey: "allergies") as? String) ?? ""
                let paperworkStarted = (mo.value(forKey: "paperworkStarted") as? Bool) ?? false
                let paperworkComplete = (mo.value(forKey: "paperworkComplete") as? Bool) ?? false
                let sortOrder = (mo.value(forKey: "sortOrder") as? Int32) ?? 0

                // New fields
                let isFavorite = (mo.value(forKey: "isFavorite") as? Bool) ?? false
                let photoData = mo.value(forKey: "photoData") as? Data
                let thumbnailData = mo.value(forKey: "thumbnailData") as? Data
                let lastViewedAt = mo.value(forKey: "lastViewedAt") as? Date
                let lastContactedAt = mo.value(forKey: "lastContactedAt") as? Date
                let tagsString = (mo.value(forKey: "tags") as? String) ?? ""
                let tags = tagsString.isEmpty ? [] : tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let contractStatusRaw = (mo.value(forKey: "contractStatus") as? String) ?? "None"
                let contractStatus = Contact.ContractStatus(rawValue: contractStatusRaw) ?? .none
                let availabilityStart = mo.value(forKey: "availabilityStart") as? Date
                let availabilityEnd = mo.value(forKey: "availabilityEnd") as? Date
                let modifiedAt = mo.value(forKey: "modifiedAt") as? Date

                // Map into in-memory UI model using persisted category/department if available
                let cat = readCategory(from: mo)
                let dept = readDepartment(from: mo)
                return Contact(
                    id: id,
                    name: name,
                    role: role,
                    phone: phone,
                    email: email,
                    allergies: allergies,
                    paperworkStarted: paperworkStarted,
                    paperworkComplete: paperworkComplete,
                    category: cat,
                    department: dept,
                    sortOrder: sortOrder,
                    isFavorite: isFavorite,
                    photoData: photoData,
                    thumbnailData: thumbnailData,
                    lastViewedAt: lastViewedAt,
                    lastContactedAt: lastContactedAt,
                    tags: tags,
                    contractStatus: contractStatus,
                    availabilityStart: availabilityStart,
                    availabilityEnd: availabilityEnd,
                    modifiedAt: modifiedAt
                )
            }
        } catch {
            #if DEBUG
            print("Fetch ContactEntity failed:", error)
            #endif
            return []
        }
    }

    @discardableResult
    private func upsertStore(for contact: Contact) -> NSManagedObject? {
        print("📇 [Contacts] upsertStore() called for contact ID: \(contact.id), name: '\(contact.name)'")
        // Try to fetch by id; if not found, insert
        let req = NSFetchRequest<NSManagedObject>(entityName: contactEntityName)
        req.predicate = NSPredicate(format: "%K == %@", CK.id, contact.id as CVarArg)
        req.fetchLimit = 1
        do {
            let found = try ctx.fetch(req).first
            let mo: NSManagedObject
            if let f = found {
                print("📇 [Contacts] Found existing entity, updating...")
                mo = f

                // Track changes for history (only for existing contacts)
                trackChanges(for: contact, existingMO: f)
            } else {
                print("📇 [Contacts] No existing entity found, creating new...")
                guard let entity = NSEntityDescription.entity(forEntityName: contactEntityName, in: ctx) else {
                    print("📇 [Contacts] ❌ Failed to get entity description for '\(contactEntityName)'")
                    return nil
                }
                mo = NSManagedObject(entity: entity, insertInto: ctx)
                mo.setValue(contact.id, forKey: CK.id)
                mo.setValue(Date(), forKey: CK.createdAt)
                print("📇 [Contacts] New managed object created with ID: \(contact.id)")
            }
            // Don't trim whitespace during editing - allow spaces between first/last name
            mo.setValue(contact.name, forKey: CK.name)
            mo.setValue(contact.email, forKey: CK.email)
            mo.setValue(contact.phone, forKey: CK.phone)
            mo.setValue(contact.role, forKey: "role")
            mo.setValue(contact.allergies, forKey: "allergies")
            mo.setValue(contact.paperworkStarted, forKey: "paperworkStarted")
            mo.setValue(contact.paperworkComplete, forKey: "paperworkComplete")
            mo.setValue(contact.sortOrder, forKey: "sortOrder")

            // New fields
            mo.setValue(contact.isFavorite, forKey: "isFavorite")
            mo.setValue(contact.photoData, forKey: "photoData")
            mo.setValue(contact.thumbnailData, forKey: "thumbnailData")
            mo.setValue(contact.lastViewedAt, forKey: "lastViewedAt")
            mo.setValue(contact.lastContactedAt, forKey: "lastContactedAt")
            mo.setValue(contact.tags.joined(separator: ","), forKey: "tags")
            mo.setValue(contact.contractStatus.rawValue, forKey: "contractStatus")
            mo.setValue(contact.availabilityStart, forKey: "availabilityStart")
            mo.setValue(contact.availabilityEnd, forKey: "availabilityEnd")
            mo.setValue(Date(), forKey: "modifiedAt") // Always update modifiedAt on save

            // Persist category & department (attribute if present, else note tag)
            writeCategory(contact.category, into: mo)
            writeDepartment(contact.department, into: mo)
            print("📇 [Contacts] upsertStore() completed successfully")
            return mo
        } catch {
            print("📇 [Contacts] ❌ upsertStore() failed with error: \(error)")
            #if DEBUG
            print("Upsert ContactEntity failed:", error)
            #endif
            return nil
        }
    }

    /// Track changes between the new contact values and existing Core Data values
    private func trackChanges(for contact: Contact, existingMO: NSManagedObject) {
        let oldName = existingMO.value(forKey: CK.name) as? String
        let oldEmail = existingMO.value(forKey: CK.email) as? String
        let oldPhone = existingMO.value(forKey: CK.phone) as? String
        let oldRole = existingMO.value(forKey: "role") as? String
        let oldCategory = existingMO.value(forKey: "category") as? String
        let oldDepartment = existingMO.value(forKey: "department") as? String
        let oldContractStatus = existingMO.value(forKey: "contractStatus") as? String
        let oldTags = existingMO.value(forKey: "tags") as? String
        let oldAllergies = existingMO.value(forKey: "allergies") as? String

        var changes: [(field: String, previous: String?, new: String?)] = []

        if oldName != contact.name { changes.append(("name", oldName, contact.name)) }
        if oldEmail != contact.email { changes.append(("email", oldEmail, contact.email)) }
        if oldPhone != contact.phone { changes.append(("phone", oldPhone, contact.phone)) }
        if oldRole != contact.role { changes.append(("role", oldRole, contact.role)) }
        if oldCategory != contact.category.rawValue { changes.append(("category", oldCategory, contact.category.rawValue)) }
        if oldDepartment != contact.department.rawValue { changes.append(("department", oldDepartment, contact.department.rawValue)) }
        if oldContractStatus != contact.contractStatus.rawValue { changes.append(("contractStatus", oldContractStatus, contact.contractStatus.rawValue)) }
        if oldAllergies != contact.allergies { changes.append(("allergies", oldAllergies, contact.allergies)) }

        let newTagsString = contact.tags.joined(separator: ",")
        if oldTags != newTagsString { changes.append(("tags", oldTags, newTagsString)) }

        if !changes.isEmpty {
            ContactHistoryService.shared.recordChanges(
                contactID: contact.id,
                changes: changes,
                context: ctx
            )
        }
    }

    private func saveContext() {
        print("📇 [Contacts] saveContext() called")
        guard ctx.hasChanges else {
            print("📇 [Contacts] No changes to save, skipping")
            return
        }
        do {
            print("📇 [Contacts] Saving context...")
            try ctx.save()
            print("📇 [Contacts] ✅ Context saved successfully")
            // NOTE: Do NOT call refreshContacts() here - it causes race conditions
            // during editing by replacing the contacts array mid-edit.
            // The in-memory contacts array is already up-to-date.
        }
        catch {
            print("📇 [Contacts] ❌ Save failed with error: \(error)")
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    private func refreshContacts() {
        let stored = fetchStoreContacts()
        // Preserve selection while refreshing
        let selectedID = selectedContact?.id
        contacts = stored
        if let id = selectedID {
            selectedContact = stored.first(where: { $0.id == id })
        }
    }

    private func deleteFromStore(ids: Set<UUID>) {
        let idsArray = Array(ids)
        let req = NSFetchRequest<NSManagedObject>(entityName: contactEntityName)
        req.predicate = NSPredicate(format: "%K IN %@", CK.id, idsArray)
        do {
            let rows = try ctx.fetch(req)
            for mo in rows { ctx.delete(mo) }
            saveContext()
        } catch {
            #if DEBUG
            print("Delete ContactEntity failed:", error)
            #endif
        }
    }

    private func matches(_ c: Contact) -> Bool {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return c.name.lowercased().contains(q)
        || c.role.lowercased().contains(q)
        || c.phone.lowercased().contains(q)
        || c.email.lowercased().contains(q)
        || c.category.rawValue.lowercased().contains(q)
    }

    private var filtered: [Contact] {
        var result = contacts.filter { c in
            let match = matches(c)
            let depOK = (selectedDepartment == nil) || (c.department == selectedDepartment!)

            // Check multi-select category filter (AND logic - contact must match ALL selected categories)
            // Note: For categories, "AND" means if multiple are selected, show contacts that are in ANY of them
            // since a contact can only have one category
            let categoryOK = selectedCategories.isEmpty || selectedCategories.contains(c.category)

            // Check multi-select tag filter (AND logic - contact must have ALL selected tags)
            let tagsOK = selectedTags.isEmpty || selectedTags.allSatisfy { c.tags.contains($0) }

            // If multi-select filters are active, use them
            if !selectedCategories.isEmpty || !selectedTags.isEmpty {
                return match && depOK && categoryOK && tagsOK
            }

            // If a department is selected, ignore category filters entirely
            if selectedDepartment != nil {
                return match && depOK
            }

            switch selectedFilter {
            case .all: return match && depOK
            case .favorites: return match && depOK && c.isFavorite
            case .recent: return match && depOK && c.lastViewedAt != nil
            case .cast: return match && depOK && c.category == .cast
            case .crew: return match && depOK && c.category == .crew
            case .vendor: return match && depOK && c.category == .vendor
            }
        }

        // For recent filter, sort by lastViewedAt descending and limit to 10
        if selectedFilter == .recent {
            result = result.sorted { ($0.lastViewedAt ?? .distantPast) > ($1.lastViewedAt ?? .distantPast) }
            if result.count > 10 {
                result = Array(result.prefix(10))
            }
        }

        return result
    }

    // Favorites count
    private var favoritesCount: Int {
        contacts.filter { $0.isFavorite }.count
    }

    // Recent contacts count (those with lastViewedAt set)
    private var recentCount: Int {
        min(contacts.filter { $0.lastViewedAt != nil }.count, 10)
    }
    
    // Cached category counts (computed once per render)
    private var categoryCounts: (cast: Int, crew: Int, vendor: Int) {
        var cast = 0, crew = 0, vendor = 0
        for c in contacts {
            switch c.category {
            case .cast: cast += 1
            case .crew: crew += 1
            case .vendor: vendor += 1
            }
        }
        return (cast, crew, vendor)
    }

    private var castTotal: Int { categoryCounts.cast }
    private var crewTotal: Int { categoryCounts.crew }
    private var vendorTotal: Int { categoryCounts.vendor }

    // Pre-computed index lookup for O(1) access in table columns
    private var contactIndexById: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: contacts.enumerated().map { ($1.id, $0) })
    }

    // MARK: - Bottom Bar with Totals (Screenplay-style)
    private var bottomBar: some View {
        HStack(spacing: 0) {
            // Left: Contact counts (matching Screenplay's bottomToolbar style)
            HStack(spacing: 20) {
                // Total count
                HStack(spacing: 6) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(castTotal + crewTotal + vendorTotal)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Total")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Cast count
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(castTotal)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Cast")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Crew count
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(crewTotal)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Crew")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Vendors count
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(vendorTotal)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(vendorTotal == 1 ? "Vendor" : "Vendors")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 16)

            Spacer()
        }
        .frame(height: 32)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - REDESIGNED: Premium metric pill with icon and modern styling
    private func totalPill(title: String, value: Int, color: Color, icon: String) -> some View {
        let pillContent = HStack(spacing: 6) {
            pillIcon(color: color, icon: icon)
            pillText(title: title, value: value)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

        return pillContent
            .background(pillBackground(color: color))
            .overlay(pillBorder(color: color))
            .shadow(color: color.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func pillIcon(color: Color, icon: String) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 24, height: 24)

            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func pillText(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.2)
            Text("\(value)")
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private func pillBackground(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
            
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.08),
                            color.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func pillBorder(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        color.opacity(0.3),
                        color.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
    // MARK: - REDESIGNED: Compact horizontal filter button
    private func filterButton(_ filter: SidebarFilter, label: String, icon: String) -> some View {
        let isActive = (selectedDepartment == nil && selectedFilter == filter)
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = filter
                if filter == .all { selectedDepartment = nil }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? contactsPurple : secondaryTextColor)

                Text(label)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? primaryTextColor : secondaryTextColor)
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(contactsPurple.opacity(0.12))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        contactsPurple.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? contactsPurple.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - REDESIGNED: Compact horizontal department button
    private func departmentButton(_ dept: Contact.Department, icon: String) -> some View {
        let isActive = (selectedDepartment == dept)
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDepartment = (isActive ? nil : dept)
                selectedFilter = .all
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? contactsPurple : secondaryTextColor)

                Text(dept.displayName)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? primaryTextColor : secondaryTextColor)
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(contactsPurple.opacity(0.12))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        contactsPurple.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? contactsPurple.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category color helper - updated with more vibrant colors
    private func categoryColor(_ cat: Contact.Category) -> Color {
        switch cat {
        case .cast:   return Color(red: 1.0, green: 0.23, blue: 0.19)  // Vibrant red
        case .crew:   return Color(red: 0.0, green: 0.48, blue: 1.0)   // Bright blue
        case .vendor: return Color(red: 0.2, green: 0.78, blue: 0.35)  // Fresh green
        }
    }

    // MARK: - Tag color helper
    @State private var tagColorCache: [String: Color] = [:]

    private func tagColor(for tagName: String) -> Color {
        // Check cache first
        if let cached = tagColorCache[tagName] {
            return cached
        }

        // Look up tag in Core Data
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactTagEntity")
        request.predicate = NSPredicate(format: "name == %@", tagName)
        request.fetchLimit = 1

        do {
            if let mo = try ctx.fetch(request).first,
               let colorHex = mo.value(forKey: "colorHex") as? String,
               let color = Color(hex: colorHex) {
                tagColorCache[tagName] = color
                return color
            }
        } catch {
            print("Failed to fetch tag color: \(error)")
        }

        // Default color if not found
        return .purple
    }

    // MARK: - Input Validation Helpers
    private func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return true } // Empty is valid (not required)
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func isValidPhone(_ phone: String) -> Bool {
        guard !phone.isEmpty else { return true } // Empty is valid (not required)
        // Allow digits, spaces, dashes, parentheses, plus sign - at least 7 digits
        let digitsOnly = phone.filter { $0.isNumber }
        return digitsOnly.count >= 7
    }

    // MARK: - Adaptive Colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .primary.opacity(0.7)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .primary.opacity(0.5)
    }

    private var backgroundPrimaryColor: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.95)
    }

    private var backgroundSecondaryColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    private var backgroundTertiaryColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)
    }

    private var hoverColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left: Table or Empty State (70% of width)
                    if contacts.isEmpty {
                        emptyContactsState
                            .frame(width: geometry.size.width * 0.70)
                    } else {
                        tableView
                            .frame(width: geometry.size.width * 0.70)
                    }

                    Divider()

                    // Right: Inspector (30% of width - fixed)
                    if let selectedContact = selectedContact {
                        inspectorPane(for: selectedContact)
                            .frame(width: geometry.size.width * 0.30)
                    } else {
                        emptyInspectorPane
                            .frame(width: geometry.size.width * 0.30)
                    }
                }
            }

            bottomBar
        }
        .toolbar { contactsToolbar }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Bootstrap from store if available
            let stored = fetchStoreContacts()
            if !stored.isEmpty { contacts = stored }
            // Load departments
            loadDepartments()
            // Load roles
            loadRoles()
            // Load tags for filtering
            loadAvailableTags()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prNewContact)) { _ in
            addBlankRow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidChange)) { _ in
            // Refresh contacts when added from other apps (e.g., Plan)
            refreshContacts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tagsDidChange)) { _ in
            // Refresh available tags when they change
            loadAvailableTags()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prImportContacts)) { _ in
            showingFileImporter = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .prDeleteSelectedContacts)) { _ in
            deleteSelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prExportContacts)) { _ in
            handleExportPDF()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
            handleCut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
            handleCopy()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
            handlePaste()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
            handleSelectAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
            deleteSelected()
        }
        .undoRedoSupport(
            canUndo: undoRedoManager.canUndo,
            canRedo: undoRedoManager.canRedo,
            onUndo: performUndo,
            onRedo: performRedo
        )
        .contactsFileImporter(isPresented: $showingFileImporter) { url in
            handleFileImport(url: url)
        }
        .sheet(isPresented: $showingColumnMapper) {
            if let data = parsedImportData {
                ContactColumnMapperSheet(parsedData: data) { importedContacts in
                    handleContactsImport(importedContacts)
                }
            }
        }
        .sheet(isPresented: $showingDepartmentManager) {
            DepartmentManagerSheet()
        }
        .sheet(isPresented: $showingUnitManager) {
            UnitManagerSheet(contacts: contacts)
        }
        .sheet(isPresented: $showingTagManager) {
            TagManagerSheet()
        }
        .sheet(isPresented: $showingTemplateManager) {
            TemplateManagerSheet()
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: departmentsData) { _ in
            loadDepartments()
        }
        .onChange(of: selection) { newSelection in
            if let firstID = newSelection.first,
               let contact = contacts.first(where: { $0.id == firstID }),
               let index = contacts.firstIndex(where: { $0.id == firstID }) {
                selectedContact = contact
                // Update lastViewedAt for recent contacts tracking
                contacts[index].lastViewedAt = Date()
                _ = upsertStore(for: contacts[index])
                saveContext()
            } else {
                selectedContact = nil
            }
        }
    }

    @State private var selectedContact: Contact?

    // Helper function to select a contact row when interacting with its cells
    private func selectRow(for contactID: UUID) {
        if !selection.contains(contactID) {
            selection = [contactID]
        }
    }

    private var tableView: some View {
        Table(filtered, selection: $selection) {
                TableColumn("") { c in
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tertiaryTextColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .draggable(c.id.uuidString) {
                            // Drag preview
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                Text(c.name)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.2))
                            )
                        }
                }
                .width(24)

                // Favorites column
                TableColumn("★") { c in
                    if let i = contactIndexById[c.id] {
                        Button {
                            contacts[i].isFavorite.toggle()
                            _ = upsertStore(for: contacts[i])
                            saveContext()
                        } label: {
                            Image(systemName: contacts[i].isFavorite ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundStyle(contacts[i].isFavorite ? .yellow : tertiaryTextColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .width(30)

                // Photo column
                TableColumn("") { c in
                    if let i = contactIndexById[c.id] {
                        ContactPhotoView(
                            photoData: contacts[i].photoData,
                            thumbnailData: contacts[i].thumbnailData,
                            name: c.name,
                            size: 28,
                            categoryColor: contactsPurple
                        )
                    }
                }
                .width(36)

                    TableColumn("Name") { c in
                        if let i = contactIndexById[c.id] {
                            SelectableTextField(placeholder: "Name", text: $contacts[i].name, onCommit: {
                                _ = upsertStore(for: contacts[i]); saveContext()
                            }, onFocus: {
                                saveToUndoStack()
                                selectRow(for: c.id)
                            })
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1).truncationMode(.tail)
                        } else {
                            Text(c.name)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("Category") { c in
                        if let i = contactIndexById[c.id] {
                            let current = contacts[i].category
                            Menu {
                                ForEach(Contact.Category.allCases, id: \.self) { cat in
                                    Button(cat.displayName) {
                                        contacts[i].category = cat
                                        // Auto-switch department when changing between cast and crew/vendor
                                        if cat == .cast && !contacts[i].department.isCastDepartment {
                                            contacts[i].department = .castLead
                                            contacts[i].role = "" // Clear role for cast (they type character name)
                                        } else if cat != .cast && contacts[i].department.isCastDepartment {
                                            contacts[i].department = .production
                                        }
                                        _ = upsertStore(for: contacts[i])
                                        saveContext()
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(categoryColor(current))
                                        .frame(width: 6, height: 6)
                                    Text(current.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(categoryColor(current).opacity(0.15))
                                        Capsule()
                                            .strokeBorder(categoryColor(current).opacity(0.3), lineWidth: 1)
                                    }
                                )
                                .foregroundStyle(categoryColor(current))
                                .lineLimit(1).truncationMode(.tail)
                            }
                            .menuStyle(.borderlessButton)
                            .onTapGesture { selectRow(for: c.id) }
                        } else {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(categoryColor(c.category))
                                    .frame(width: 6, height: 6)
                                Text(c.category.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(categoryColor(c.category).opacity(0.15))
                                    Capsule()
                                        .strokeBorder(categoryColor(c.category).opacity(0.3), lineWidth: 1)
                                }
                            )
                            .foregroundStyle(categoryColor(c.category))
                            .lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("Department") { c in
                        if let i = contactIndexById[c.id] {
                            // Show different options based on category
                            let departmentOptions = contacts[i].category == .cast
                                ? Contact.Department.castDepartments
                                : Contact.Department.crewDepartments
                            Menu {
                                ForEach(departmentOptions, id: \.self) { d in
                                    Button(d.displayName) {
                                        contacts[i].department = d
                                        _ = upsertStore(for: contacts[i])
                                        saveContext()
                                    }
                                }
                            } label: {
                                Text(contacts[i].department.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                                    .lineLimit(1).truncationMode(.tail)
                            }
                            .menuStyle(.borderlessButton)
                            .onTapGesture { selectRow(for: c.id) }
                        } else {
                            Text(c.department.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .width(min: 120, ideal: 140)

                    TableColumn("Role") { c in
                        if let i = contactIndexById[c.id] {
                            // Cast members get a text field for character/role name
                            // Crew members get a dropdown of available roles
                            if contacts[i].category == .cast {
                                SelectableTextField(placeholder: "Character Name", text: $contacts[i].role, onCommit: {
                                    _ = upsertStore(for: contacts[i]); saveContext()
                                }, onFocus: {
                                    saveToUndoStack()
                                    selectRow(for: c.id)
                                })
                                .font(.system(size: 13))
                                .lineLimit(1).truncationMode(.tail)
                            } else {
                                Menu {
                                    ForEach(availableRoles, id: \.self) { role in
                                        Button(role) {
                                            contacts[i].role = role
                                            _ = upsertStore(for: contacts[i])
                                            saveContext()
                                        }
                                    }
                                    Divider()
                                    Button("Clear") {
                                        contacts[i].role = ""
                                        _ = upsertStore(for: contacts[i])
                                        saveContext()
                                    }
                                } label: {
                                    HStack {
                                        Text(contacts[i].role.isEmpty ? "Select Role..." : contacts[i].role)
                                            .font(.system(size: 13))
                                            .foregroundColor(contacts[i].role.isEmpty ? .secondary : .primary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onTapGesture { selectRow(for: c.id) }
                            }
                        } else {
                            Text(c.role)
                                .font(.system(size: 13))
                                .lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("Tags") { c in
                        if !c.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(c.tags.prefix(2), id: \.self) { tagName in
                                    Text(tagName)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tagColor(for: tagName))
                                        .clipShape(Capsule())
                                }
                                if c.tags.count > 2 {
                                    Text("+\(c.tags.count - 2)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("-")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .width(min: 80, ideal: 120)

                    TableColumn("Phone") { c in
                        if let i = contactIndexById[c.id] {
                            HStack(spacing: 4) {
                                SelectableTextField(placeholder: "Phone", text: $contacts[i].phone, onCommit: {
                                    _ = upsertStore(for: contacts[i]); saveContext()
                                }, onFocus: {
                                    saveToUndoStack()
                                    selectRow(for: c.id)
                                })
                                .font(.system(size: 13))
                                .monospacedDigit().lineLimit(1).truncationMode(.tail)

                                if !contacts[i].phone.isEmpty && !isValidPhone(contacts[i].phone) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.system(size: 11))
                                        .customTooltip("Phone number should have at least 7 digits")
                                }
                            }
                        } else {
                            Text(c.phone)
                                .font(.system(size: 13))
                                .monospacedDigit().lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .width(min: 100)

                    TableColumn("Email") { c in
                        if let i = contactIndexById[c.id] {
                            HStack(spacing: 4) {
                                SelectableTextField(placeholder: "Email", text: $contacts[i].email, onCommit: {
                                    _ = upsertStore(for: contacts[i]); saveContext()
                                }, onFocus: {
                                    saveToUndoStack()
                                    selectRow(for: c.id)
                                })
                                .font(.system(size: 13))
                                .lineLimit(1).truncationMode(.middle)

                                if !contacts[i].email.isEmpty && !isValidEmail(contacts[i].email) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.system(size: 11))
                                        .customTooltip("Invalid email format")
                                }
                            }
                        } else {
                            Text(c.email)
                                .font(.system(size: 13))
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .width(min: 160, ideal: 200)

                    // Details column - iOS only (macOS has inspector pane on the right)
                    #if os(iOS)
                    TableColumn("Details") { c in
                        ContactDetailsPopover(contact: c, onUpdate: {
                            if let i = contactIndexById[c.id] {
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }
                        })
                    }
                    .width(min: 80, ideal: 90)
                    #endif
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .dropDestination(for: String.self) { items, location in
                    // Handle drop for reordering
                    guard let droppedIDString = items.first,
                          let droppedID = UUID(uuidString: droppedIDString),
                          let fromIndex = contacts.firstIndex(where: { $0.id == droppedID }) else {
                        return false
                    }

                    // Calculate target index based on drop location
                    // For simplicity, if we drop on a row, insert before it
                    // This is a basic implementation - drop target calculation may need refinement
                    let rowHeight: CGFloat = 32
                    let targetIndex = min(max(0, Int(location.y / rowHeight)), contacts.count - 1)

                    if fromIndex != targetIndex {
                        moveContact(from: fromIndex, to: targetIndex)
                    }
                    return true
                }
                .onCommand(#selector(NSStandardKeyBindingResponding.selectAll(_:))) {
                    // Select all rows when CMD+A is pressed and no text field is focused
                    selection = Set(filtered.map { $0.id })
                }
    }

    private func moveContact(from sourceIndex: Int, to destinationIndex: Int) {
        // Move the contact in the array
        var updated = contacts
        let moving = updated.remove(at: sourceIndex)
        let insertAt = destinationIndex > sourceIndex ? destinationIndex : destinationIndex
        updated.insert(moving, at: min(insertAt, updated.count))

        // Update sortOrder for all contacts
        for (index, var contact) in updated.enumerated() {
            contact.sortOrder = Int32(index)
            updated[index] = contact
            _ = upsertStore(for: contact)
        }

        contacts = updated
        saveContext()
    }

    // MARK: - Inspector Pane
    private func inspectorPane(for contact: Contact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                inspectorHeader(for: contact)
                Divider()
                inspectorClassification(for: contact)
                Divider()
                inspectorContactInfo(for: contact)
                Divider()
                inspectorAdditionalInfo(for: contact)
                Divider()
                inspectorPaperworkStatus(for: contact)
                Divider()
                inspectorContractStatus(for: contact)
                Divider()
                inspectorAvailability(for: contact)
                Divider()
                inspectorTags(for: contact)
                Divider()
                ContactNotesView(contactID: contact.id)
                Divider()
                ContactHistoryView(contactID: contact.id)
            }
            .padding(20)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private func inspectorHeader(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Photo with click-to-change
                if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                    Button {
                        ContactPhotoManager.pickImage { imageData in
                            guard let data = imageData else { return }
                            contacts[i].photoData = data
                            contacts[i].thumbnailData = ContactPhotoManager.generateThumbnail(from: data)
                            _ = upsertStore(for: contacts[i])
                            saveContext()
                        }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            ContactPhotoView(
                                photoData: contacts[i].photoData,
                                thumbnailData: contacts[i].thumbnailData,
                                name: contact.name,
                                size: 60,
                                categoryColor: contactsPurple
                            )

                            // Camera overlay icon
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                )
                                .offset(x: 2, y: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .customTooltip("Click to change photo")
                } else {
                    ContactPhotoView(
                        photoData: contact.photoData,
                        thumbnailData: contact.thumbnailData,
                        name: contact.name,
                        size: 60,
                        categoryColor: contactsPurple
                    )
                }

                Spacer()

                // Favorite toggle button
                if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                    Button {
                        contacts[i].isFavorite.toggle()
                        _ = upsertStore(for: contacts[i])
                        saveContext()
                    } label: {
                        Image(systemName: contacts[i].isFavorite ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundStyle(contacts[i].isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip(contacts[i].isFavorite ? "Remove from Favorites" : "Add to Favorites")
                }
            }

            if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                SelectableTextField(
                    placeholder: "Name",
                    text: $contacts[i].name,
                    onCommit: {
                        _ = upsertStore(for: contacts[i])
                        saveContext()
                    },
                    onFocus: {
                        saveToUndoStack()
                    }
                )
                .font(.system(size: 20, weight: .bold))

                // Cast members get a text field for character/role name
                // Crew members get a dropdown of available roles
                if contacts[i].category == .cast {
                    SelectableTextField(
                        placeholder: "Character Name",
                        text: $contacts[i].role,
                        onCommit: {
                            _ = upsertStore(for: contacts[i])
                            saveContext()
                        },
                        onFocus: {
                            saveToUndoStack()
                        }
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                } else {
                    Menu {
                        ForEach(availableRoles, id: \.self) { role in
                            Button(role) {
                                contacts[i].role = role
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }
                        }
                        Divider()
                        Button("Clear") {
                            contacts[i].role = ""
                            _ = upsertStore(for: contacts[i])
                            saveContext()
                        }
                    } label: {
                        HStack {
                            Text(contacts[i].role.isEmpty ? "Select Role..." : contacts[i].role)
                                .font(.system(size: 14))
                                .foregroundColor(contacts[i].role.isEmpty ? .secondary : .secondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(contact.name)
                    .font(.system(size: 20, weight: .bold))
                Text(contact.role)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func inspectorClassification(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classification")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 10) {
                if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                    HStack {
                        Text("Category")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        categoryPicker(for: i)
                        Spacer()
                    }

                    HStack {
                        Text("Department")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        departmentPicker(for: i)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categoryPicker(for index: Int) -> some View {
        Menu {
            ForEach(Contact.Category.allCases, id: \.self) { cat in
                Button(cat.displayName) {
                    _ = contacts[index].category
                    contacts[index].category = cat
                    // Auto-switch department when changing between cast and crew/vendor
                    if cat == .cast && !contacts[index].department.isCastDepartment {
                        contacts[index].department = .castLead
                        contacts[index].role = "" // Clear role for cast (they type character name)
                    } else if cat != .cast && contacts[index].department.isCastDepartment {
                        contacts[index].department = .production
                    }
                    _ = upsertStore(for: contacts[index])
                    saveContext()
                    selectedContact = contacts[index]
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(categoryColor(contacts[index].category))
                    .frame(width: 6, height: 6)
                Text(contacts[index].category.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(categoryColor(contacts[index].category).opacity(0.15)))
            .overlay(Capsule().strokeBorder(categoryColor(contacts[index].category).opacity(0.3), lineWidth: 1))
            .foregroundStyle(categoryColor(contacts[index].category))
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func departmentPicker(for index: Int) -> some View {
        // Show different options based on category
        let departmentOptions = contacts[index].category == .cast
            ? Contact.Department.castDepartments
            : Contact.Department.crewDepartments
        Menu {
            ForEach(departmentOptions, id: \.self) { d in
                Button(d.displayName) {
                    contacts[index].department = d
                    _ = upsertStore(for: contacts[index])
                    saveContext()
                    selectedContact = contacts[index]
                }
            }
        } label: {
            Text(contacts[index].department.displayName)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func inspectorContactInfo(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        SelectableTextField(
                            placeholder: "Email",
                            text: $contacts[i].email,
                            onCommit: {
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            },
                            onFocus: {
                                saveToUndoStack()
                            }
                        )
                        .font(.system(size: 13))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))

                    HStack {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        SelectableTextField(
                            placeholder: "Phone",
                            text: $contacts[i].phone,
                            onCommit: {
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            },
                            onFocus: {
                                saveToUndoStack()
                            }
                        )
                        .font(.system(size: 13))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
                }
            }
        }
    }

    @ViewBuilder
    private func inspectorAdditionalInfo(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Information")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                Text("Allergies")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                    TextEditor(text: $contacts[i].allergies)
                        .font(.system(size: 13))
                        .frame(height: 80)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
                        .onChange(of: contacts[i].allergies) { _ in
                            // Debounce saves - wait 0.5s after typing stops
                            allergiesSaveWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }
                            allergiesSaveWorkItem = workItem
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                        }
                        .onAppear {
                            // Save undo state when starting to edit
                            saveToUndoStack()
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func inspectorPaperworkStatus(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paperwork Status")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                VStack(spacing: 10) {
                    Toggle(isOn: $contacts[i].paperworkStarted) {
                        HStack(spacing: 8) {
                            Image(systemName: contacts[i].paperworkStarted ? "doc.text.fill" : "doc.text")
                                .font(.system(size: 16))
                                .foregroundStyle(contacts[i].paperworkStarted ? .blue : .secondary)
                            Text("Started Paperwork")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: contacts[i].paperworkStarted) { _ in
                        _ = upsertStore(for: contacts[i])
                        saveContext()
                    }

                    Toggle(isOn: $contacts[i].paperworkComplete) {
                        HStack(spacing: 8) {
                            Image(systemName: contacts[i].paperworkComplete ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(contacts[i].paperworkComplete ? .green : .secondary)
                            Text("Completed Paperwork")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: contacts[i].paperworkComplete) { _ in
                        _ = upsertStore(for: contacts[i])
                        saveContext()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inspectorContractStatus(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contract Status")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                HStack(spacing: 12) {
                    Image(systemName: contractStatusIcon(for: contacts[i].contractStatus))
                        .font(.system(size: 20))
                        .foregroundStyle(contractStatusColor(for: contacts[i].contractStatus))
                        .frame(width: 24)

                    Picker("Status", selection: $contacts[i].contractStatus) {
                        ForEach(Contact.ContractStatus.allCases, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(contractStatusColor(for: status))
                                    .frame(width: 8, height: 8)
                                Text(status.rawValue)
                            }
                            .tag(status)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: contacts[i].contractStatus) { _ in
                        _ = upsertStore(for: contacts[i])
                        saveContext()
                    }
                }

                // Status description
                Text(contractStatusDescription(for: contacts[i].contractStatus))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 36)
            }
        }
    }

    private func contractStatusIcon(for status: Contact.ContractStatus) -> String {
        switch status {
        case .none: return "doc"
        case .pending: return "doc.badge.clock"
        case .sent: return "paperplane.fill"
        case .signed: return "checkmark.seal.fill"
        case .expired: return "exclamationmark.triangle.fill"
        }
    }

    private func contractStatusColor(for status: Contact.ContractStatus) -> Color {
        switch status {
        case .none: return .secondary
        case .pending: return .orange
        case .sent: return .blue
        case .signed: return .green
        case .expired: return .red
        }
    }

    private func contractStatusDescription(for status: Contact.ContractStatus) -> String {
        switch status {
        case .none: return "No contract initiated"
        case .pending: return "Contract is being prepared"
        case .sent: return "Contract sent, awaiting signature"
        case .signed: return "Contract signed and complete"
        case .expired: return "Contract has expired"
        }
    }

    @ViewBuilder
    private func inspectorAvailability(for contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Availability")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
                VStack(alignment: .leading, spacing: 10) {
                    // Start date
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Text("From:")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)

                        if contacts[i].availabilityStart != nil {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { contacts[i].availabilityStart ?? Date() },
                                    set: { contacts[i].availabilityStart = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .onChange(of: contacts[i].availabilityStart) { _ in
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }

                            Button(action: {
                                contacts[i].availabilityStart = nil
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button("Set date") {
                                contacts[i].availabilityStart = Date()
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                            .buttonStyle(.plain)
                        }
                    }

                    // End date
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Text("To:")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)

                        if contacts[i].availabilityEnd != nil {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { contacts[i].availabilityEnd ?? Date() },
                                    set: { contacts[i].availabilityEnd = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .onChange(of: contacts[i].availabilityEnd) { _ in
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }

                            Button(action: {
                                contacts[i].availabilityEnd = nil
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button("Set date") {
                                contacts[i].availabilityEnd = Date()
                                _ = upsertStore(for: contacts[i])
                                saveContext()
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                            .buttonStyle(.plain)
                        }
                    }

                    // Availability indicator
                    if let start = contacts[i].availabilityStart, let end = contacts[i].availabilityEnd {
                        let now = Date()
                        let isAvailable = now >= start && now <= end

                        HStack(spacing: 6) {
                            Circle()
                                .fill(isAvailable ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(isAvailable ? "Currently available" : "Not currently available")
                                .font(.system(size: 11))
                                .foregroundStyle(isAvailable ? .green : .orange)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inspectorTags(for contact: Contact) -> some View {
        if let i = contacts.firstIndex(where: { $0.id == contact.id }) {
            TagAssignmentView(selectedTags: $contacts[i].tags)
                .onChange(of: contacts[i].tags) { _ in
                    _ = upsertStore(for: contacts[i])
                    saveContext()
                }
        }
    }

    // MARK: - Multi-Filter Popover
    private var multiFilterPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Advanced Filters")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !selectedCategories.isEmpty || !selectedTags.isEmpty {
                    Button("Clear All") {
                        selectedCategories.removeAll()
                        selectedTags.removeAll()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                }
            }

            Divider()

            // Categories section
            VStack(alignment: .leading, spacing: 8) {
                Text("Categories")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    ForEach(Contact.Category.allCases, id: \.self) { category in
                        Button(action: {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        }) {
                            HStack(spacing: 4) {
                                if selectedCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(category.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategories.contains(category) ? categoryColor(category).opacity(0.2) : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(selectedCategories.contains(category) ? categoryColor(category) : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Tags section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags (AND logic)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if availableTagsForFilter.isEmpty {
                    Text("No tags created yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(availableTagsForFilter, id: \.name) { tag in
                            Button(action: {
                                if selectedTags.contains(tag.name) {
                                    selectedTags.remove(tag.name)
                                } else {
                                    selectedTags.insert(tag.name)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if selectedTags.contains(tag.name) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 8, height: 8)
                                    Text(tag.name)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(selectedTags.contains(tag.name) ? tag.color.opacity(0.2) : Color.primary.opacity(0.05))
                                )
                                .foregroundStyle(selectedTags.contains(tag.name) ? tag.color : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Info text
            Text("Contacts must match ALL selected tags")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 320)
    }

    @State private var availableTagsForFilter: [ContactTag] = []

    private func loadAvailableTags() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ContactTagEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let results = try ctx.fetch(request)
            availableTagsForFilter = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else { return nil }
                let colorHex = (mo.value(forKey: "colorHex") as? String) ?? ContactTag.defaultColors[0]
                let sortOrder = (mo.value(forKey: "sortOrder") as? Int16) ?? 0
                return ContactTag(id: id, name: name, colorHex: colorHex, sortOrder: sortOrder)
            }
        } catch {
            print("Failed to load tags for filter: \(error)")
        }
    }

    private var emptyContactsState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Contacts")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Add your cast, crew, and vendors to get started")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 16) {
                Button(action: addBlankRow) {
                    Label("Add Contact", systemImage: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { showingFileImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundPrimaryColor)
    }

    private var emptyInspectorPane: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Contact Selected")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Select a contact from the list to view and edit their details")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    // MARK: - REDESIGNED: Modern macOS header with premium styling
    private var header: some View {
        HStack(spacing: 16) {
            // Premium action buttons group (left side) - Icon-only colored buttons like Breakdowns
            HStack(spacing: 8) {
                // New contact button (green)
                Button(action: addBlankRow) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("New Contact")

                // Delete button (red)
                Button(action: deleteSelected) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selection.isEmpty ? .red.opacity(0.5) : .red)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(Tooltips.Contacts.deleteContact)
                .disabled(selection.isEmpty)

                // Import button (orange)
                Button(action: { showingFileImporter = true }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(Tooltips.Contacts.importContacts)

                // Export button (purple)
                Button(action: { handleExportPDF() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(Tooltips.Contacts.exportContacts)

                // Print button (blue)
                Button(action: { handlePrint() }) {
                    Image(systemName: "printer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(Tooltips.Common.print)

                // Manage Tags button (teal)
                Button(action: { showingTagManager = true }) {
                    Image(systemName: "tag")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.teal)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Manage Tags")

                // Templates button (indigo)
                Button(action: { showingTemplateManager = true }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.indigo)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Contact Templates")
            }

            Divider()
                .frame(height: 24)

            // Categories section
            HStack(spacing: 8) {
                filterButton(.all, label: "All", icon: "square.grid.2x2")
                filterButton(.cast, label: "Cast", icon: "person.2.fill")
                filterButton(.crew, label: "Crew", icon: "person.3.fill")
                filterButton(.vendor, label: "Vendors", icon: "building.2.fill")
            }

            // Multi-filter button (with popover)
            Button(action: { showingMultiFilterPopover.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 12, weight: .medium))
                    if !selectedCategories.isEmpty || !selectedTags.isEmpty {
                        Text("\(selectedCategories.count + selectedTags.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.blue))
                    }
                }
                .foregroundStyle(selectedCategories.isEmpty && selectedTags.isEmpty ? secondaryTextColor : .blue)
                .frame(height: 28)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selectedCategories.isEmpty && selectedTags.isEmpty ? Color.primary.opacity(0.04) : Color.blue.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selectedCategories.isEmpty && selectedTags.isEmpty ? Color.primary.opacity(0.1) : Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .customTooltip("Advanced Filters")
            .popover(isPresented: $showingMultiFilterPopover, arrowEdge: .bottom) {
                multiFilterPopover
            }

            Divider()
                .frame(height: 24)

            // Departments section
            HStack(spacing: 8) {
                Menu {
                    Button("All Departments") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDepartment = nil
                        }
                    }
                    Divider()
                    ForEach(Contact.Department.allCases, id: \.self) { dept in
                        Button(dept.displayName) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDepartment = dept
                                selectedFilter = .all
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedDepartment == nil ? "building.2" : "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedDepartment == nil ? secondaryTextColor : contactsPurple)

                        Text(selectedDepartment?.displayName ?? "All Departments")
                            .font(.system(size: 13, weight: selectedDepartment == nil ? .regular : .semibold))
                            .foregroundStyle(selectedDepartment == nil ? secondaryTextColor : primaryTextColor)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(tertiaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedDepartment == nil ? Color.clear : contactsPurple.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(selectedDepartment == nil ? dividerColor : contactsPurple.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Manage Departments button (icon-only, teal)
                Button(action: { showingDepartmentManager = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.teal)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(Tooltips.Contacts.manageDepartments)

                // Manage Units button (icon-only, orange)
                Button(action: { showingUnitManager = true }) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip(Tooltips.Contacts.manageUnits)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            ZStack {
                backgroundTertiaryColor
            }
        )
        .overlay(
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var contactsToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Search field in toolbar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13, weight: .medium))

                TextField("Search contacts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(width: 180)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Undo/Redo Functions
    private func saveToUndoStack() {
        undoRedoManager.saveState(contacts)
    }

    private func performUndo() {
        guard let previousState = undoRedoManager.undo(currentState: contacts) else { return }
        restoreContacts(previousState)
    }

    private func performRedo() {
        guard let nextState = undoRedoManager.redo(currentState: contacts) else { return }
        restoreContacts(nextState)
    }

    private func restoreContacts(_ newContacts: [Contact]) {
        // First, delete ALL existing contacts from Core Data
        let req = NSFetchRequest<NSManagedObject>(entityName: contactEntityName)
        do {
            let allRows = try ctx.fetch(req)
            for mo in allRows {
                ctx.delete(mo)
            }
        } catch {
            #if DEBUG
            print("Clear contacts failed:", error)
            #endif
        }

        // Update in-memory state
        contacts = newContacts

        // Re-insert all contacts from the restored state
        for contact in newContacts {
            guard let entity = NSEntityDescription.entity(forEntityName: contactEntityName, in: ctx) else { continue }
            let mo = NSManagedObject(entity: entity, insertInto: ctx)
            mo.setValue(contact.id, forKey: CK.id)
            mo.setValue(Date(), forKey: CK.createdAt)
            mo.setValue(contact.name, forKey: CK.name)
            mo.setValue(contact.email, forKey: CK.email)
            mo.setValue(contact.phone, forKey: CK.phone)
            mo.setValue(contact.role, forKey: "role")
            mo.setValue(contact.allergies, forKey: "allergies")
            mo.setValue(contact.paperworkStarted, forKey: "paperworkStarted")
            mo.setValue(contact.paperworkComplete, forKey: "paperworkComplete")
            mo.setValue(contact.sortOrder, forKey: "sortOrder")
            writeCategory(contact.category, into: mo)
            writeDepartment(contact.department, into: mo)
        }

        // Single save for all changes
        do {
            if ctx.hasChanges {
                try ctx.save()
            }
        } catch {
            #if DEBUG
            print("Restore save failed:", error)
            #endif
        }

        selection.removeAll()
    }

    // MARK: - Actions
    private func addBlankRow() {
        print("📇 [Contacts] addBlankRow() called")
        saveToUndoStack()
        let newID = UUID()
        print("📇 [Contacts] Creating new contact with ID: \(newID)")
        let new = Contact(
            id: newID,
            name: "New Contact",
            role: "",
            phone: "",
            email: "",
            allergies: "",
            paperworkStarted: false,
            paperworkComplete: false,
            category: .crew,
            department: .production
        )
        print("📇 [Contacts] New contact created: name='\(new.name)', category=\(new.category), department=\(new.department)")
        contacts.insert(new, at: 0)
        print("📇 [Contacts] Contact inserted at index 0. Total contacts: \(contacts.count)")
        let result = upsertStore(for: new)
        print("📇 [Contacts] upsertStore result: \(result != nil ? "success" : "failed")")
        saveContext()
        print("📇 [Contacts] addBlankRow() completed")
    }

    private func deleteSelected() {
        guard !selection.isEmpty else { return }
        saveToUndoStack()
        contacts.removeAll { selection.contains($0.id) }
        deleteFromStore(ids: selection)
        selection.removeAll()
    }

    private func handleCut() {
        guard !selection.isEmpty else { return }
        // Copy selected contacts to clipboard
        clipboard = contacts.filter { selection.contains($0.id) }
        // Delete selected contacts (this already saves undo state)
        deleteSelected()
    }

    private func handleCopy() {
        guard !selection.isEmpty else { return }
        // Copy selected contacts to clipboard
        clipboard = contacts.filter { selection.contains($0.id) }
    }

    private func handlePaste() {
        guard !clipboard.isEmpty else { return }
        saveToUndoStack()
        // Create new contacts from clipboard with new UUIDs
        let pastedContacts = clipboard.map { contact in
            Contact(
                id: UUID(), // New ID for the pasted contact
                name: contact.name,
                role: contact.role,
                phone: contact.phone,
                email: contact.email,
                allergies: contact.allergies,
                paperworkStarted: contact.paperworkStarted,
                paperworkComplete: contact.paperworkComplete,
                category: contact.category,
                department: contact.department
            )
        }

        // Find insertion point: after the last selected item, or at the beginning if nothing selected
        var insertionIndex = 0
        if !selection.isEmpty {
            // Find the index of the last selected contact in the contacts array
            let selectedIndices = contacts.enumerated()
                .filter { selection.contains($0.element.id) }
                .map { $0.offset }
            if let lastIndex = selectedIndices.max() {
                insertionIndex = lastIndex + 1
            }
        }

        // Insert pasted contacts at the determined position
        contacts.insert(contentsOf: pastedContacts, at: insertionIndex)
        // Save to Core Data
        for contact in pastedContacts {
            _ = upsertStore(for: contact)
        }
        saveContext()
        // Select the newly pasted contacts
        selection = Set(pastedContacts.map { $0.id })
    }
    
    private func handleSelectAll() {
        selection = Set(filtered.map { $0.id })
    }
    
    // MARK: - Import Handlers
    private func handleFileImport(url: URL) {
        do {
            let parsed = try ContactFileParser.parse(url: url)
            parsedImportData = parsed
            showingColumnMapper = true
        } catch {
            errorMessage = "Failed to import file: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func handleContactsImport(_ importedContacts: [Contact]) {
        // Add imported contacts to the beginning of the list
        contacts.insert(contentsOf: importedContacts, at: 0)
        
        // Save to Core Data
        for contact in importedContacts {
            _ = upsertStore(for: contact)
        }
        saveContext()
    }
    
    // MARK: - Project Name Helper
    private func getProjectName() -> String {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
        req.fetchLimit = 1
        do {
            if let project = try ctx.fetch(req).first,
               let name = project.value(forKey: "name") as? String {
                return name.isEmpty ? "Production" : name
            }
        } catch {
            #if DEBUG
            print("Failed to fetch project name:", error)
            #endif
        }
        return "Production"
    }
    
    // MARK: - Export Handlers
    private func handleExportPDF() {
        let filterTitle = selectedFilter.rawValue
        let exportContacts = selectedFilter == .all ? contacts : filtered
        let projectName = getProjectName()

        guard let pdfURL = ContactsExport.generatePDF(
            contacts: exportContacts,
            filterTitle: filterTitle,
            projectName: projectName
        ) else {
            errorMessage = "Failed to generate PDF. Please try again."
            showingErrorAlert = true
            return
        }

        exportPDFURL = pdfURL
        presentSavePanel(for: pdfURL)
    }
    
    private func presentSavePanel(for url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Contacts"
        savePanel.message = "Choose a location to save your contacts PDF"
        savePanel.nameFieldStringValue = "Contacts_Export.pdf"
        
        savePanel.begin { [self] response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to save PDF: \(error.localizedDescription)"
                        self.showingErrorAlert = true
                    }
                }
            }
        }
    }
    
    private func handlePrint() {
        let filterTitle = selectedFilter.rawValue
        let printContacts = selectedFilter == .all ? contacts : filtered
        let projectName = getProjectName()
        
        guard let pdfURL = ContactsExport.generatePDF(
            contacts: printContacts,
            filterTitle: filterTitle,
            projectName: projectName
        ) else {
            print("Failed to generate PDF for printing")
            return
        }
        
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            print("Failed to load PDF document")
            return
        }
        
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        
        let printOperation = pdfDocument.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true)
        printOperation?.showsPrintPanel = true
        printOperation?.showsProgressPanel = true
        
        printOperation?.run()
    }

    // MARK: - Department Management
    private func loadDepartments() {
        guard !departmentsData.isEmpty else {
            departments = ProductionDepartment.defaults
            return
        }
        if let decoded = try? JSONDecoder().decode([ProductionDepartment].self, from: departmentsData) {
            departments = decoded
        }
    }

    private func loadRoles() {
        // Ensure default roles are loaded
        RolesDataManager.loadDefaultRoles(context: ctx)

        // Fetch all role names
        let roles = RolesDataManager.fetchAllRoles(context: ctx)
        availableRoles = roles.compactMap { $0.value(forKey: "name") as? String }.sorted()
    }
}

// MARK: - Contact Details Popover
struct ContactDetailsPopover: View {
    let contact: Contact
    let onUpdate: () -> Void

    @State private var showingPopover = false

    var body: some View {
        Button(action: { showingPopover = true }) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .medium))
                Text("View")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.purple)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.purple.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover) {
            ContactDetailView(contact: contact, onUpdate: onUpdate)
        }
    }
}

// MARK: - Contact Detail View
struct ContactDetailView: View {
    let contact: Contact
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let contactsPurple = Color(red: 0.51, green: 0.38, blue: 0.92)

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with avatar
                    popoverHeader

                    Divider()

                    // Classification
                    detailSection(title: "Classification") {
                        classificationContent
                    }

                    Divider()

                    // Contact Information
                    detailSection(title: "Contact Information") {
                        contactInfoContent
                    }

                    Divider()

                    // Additional Information
                    detailSection(title: "Additional Information") {
                        allergiesContent
                    }

                    Divider()

                    // Paperwork Status
                    detailSection(title: "Paperwork Status") {
                        paperworkContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 560)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var popoverHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    contactsPurple.opacity(0.6),
                                    contactsPurple.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Text(initials(from: contact.name))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            Text(contact.name)
                .font(.system(size: 20, weight: .bold))

            Text(contact.role.isEmpty ? "No role specified" : contact.role)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var classificationContent: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Category")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)

                HStack(spacing: 6) {
                    Circle()
                        .fill(categoryColor(contact.category))
                        .frame(width: 6, height: 6)
                    Text(contact.category.displayName)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(categoryColor(contact.category).opacity(0.15)))
                .overlay(Capsule().strokeBorder(categoryColor(contact.category).opacity(0.3), lineWidth: 1))
                .foregroundStyle(categoryColor(contact.category))

                Spacer()
            }

            HStack {
                Text("Department")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)

                Text(contact.department.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()
            }
        }
    }

    private var contactInfoContent: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(contact.email.isEmpty ? "Not provided" : contact.email)
                    .font(.system(size: 13))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))

            HStack {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(contact.phone.isEmpty ? "Not provided" : contact.phone)
                    .font(.system(size: 13))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
        }
    }

    private var allergiesContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allergies")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(contact.allergies.isEmpty ? "None listed" : contact.allergies)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 80, alignment: .topLeading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
        }
    }

    private var paperworkContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: contact.paperworkStarted ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 16))
                    .foregroundStyle(contact.paperworkStarted ? .blue : .secondary)

                Text("Started Paperwork")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Text(contact.paperworkStarted ? "Yes" : "No")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(contact.paperworkStarted ? .blue : .secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(contact.paperworkStarted ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(contact.paperworkStarted ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )

            HStack(spacing: 8) {
                Image(systemName: contact.paperworkComplete ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(contact.paperworkComplete ? .green : .secondary)

                Text("Completed Paperwork")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Text(contact.paperworkComplete ? "Yes" : "No")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(contact.paperworkComplete ? .green : .secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(contact.paperworkComplete ? Color.green.opacity(0.1) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(contact.paperworkComplete ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    private func categoryColor(_ cat: Contact.Category) -> Color {
        switch cat {
        case .cast:   return Color(red: 1.0, green: 0.23, blue: 0.19)
        case .crew:   return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .vendor: return Color(red: 0.2, green: 0.78, blue: 0.35)
        }
    }
}

#endif
