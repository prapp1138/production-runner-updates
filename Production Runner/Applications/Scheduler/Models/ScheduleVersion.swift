import Foundation

// MARK: - Schedule Version Model

struct ScheduleVersion: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdDate: Date
    var sceneOrder: [UUID] // Store UUIDs of scenes in this version's order
    var productionStartDate: Date
    var notes: String

    // Script revision tracking
    var scriptRevisionId: UUID?     // Reference to loaded script revision
    var scriptColorName: String?    // Color name for display (e.g., "Blue", "Pink")
    var scriptLoadedDate: Date?     // When the script was loaded into this version

    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        sceneOrder: [UUID] = [],
        productionStartDate: Date = Date(),
        notes: String = "",
        scriptRevisionId: UUID? = nil,
        scriptColorName: String? = nil,
        scriptLoadedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.sceneOrder = sceneOrder
        self.productionStartDate = productionStartDate
        self.notes = notes
        self.scriptRevisionId = scriptRevisionId
        self.scriptColorName = scriptColorName
        self.scriptLoadedDate = scriptLoadedDate
    }

    /// Display name for the loaded script revision
    var scriptDisplayName: String? {
        guard let colorName = scriptColorName else { return nil }
        if colorName.lowercased() == "white" {
            return "Original Draft"
        }
        return "\(colorName) Revision"
    }

    /// Duplicate this version with a new ID and modified name
    func duplicate() -> ScheduleVersion {
        return ScheduleVersion(
            id: UUID(),
            name: name + " (Copy)",
            createdDate: Date(),
            sceneOrder: sceneOrder,
            productionStartDate: productionStartDate,
            notes: notes,
            scriptRevisionId: scriptRevisionId,
            scriptColorName: scriptColorName,
            scriptLoadedDate: scriptLoadedDate
        )
    }
}
