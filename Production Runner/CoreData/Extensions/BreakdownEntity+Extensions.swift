
import Foundation
import CoreData

extension BreakdownEntity {
    /// Get or create a breakdown entity for a given scene
    static func getOrCreate(for scene: SceneEntity, in context: NSManagedObjectContext) -> BreakdownEntity {
        if let existing = scene.breakdown {
            return existing
        }

        let breakdown = BreakdownEntity(context: context)
        breakdown.id = UUID()
        breakdown.createdAt = Date()
        breakdown.updatedAt = Date()
        breakdown.scene = scene

        return breakdown
    }

    /// Update the updatedAt timestamp
    func touch() {
        self.updatedAt = Date()
    }

    // MARK: - Cast Members

    func getCastIDs() -> [String] {
        guard let castIDs = castIDs, !castIDs.isEmpty else { return [] }
        return castIDs.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setCastIDs(_ ids: [String]) {
        castIDs = ids.joined(separator: ", ")
        touch()
    }

    // MARK: - Extras

    func getExtras() -> [String] {
        guard let extras = extras, !extras.isEmpty else { return [] }
        return extras.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setExtras(_ items: [String]) {
        extras = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Props

    func getProps() -> [String] {
        guard let props = props, !props.isEmpty else { return [] }
        return props.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setProps(_ items: [String]) {
        props = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Wardrobe

    func getWardrobe() -> [String] {
        guard let wardrobe = wardrobe, !wardrobe.isEmpty else { return [] }
        return wardrobe.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setWardrobe(_ items: [String]) {
        wardrobe = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Vehicles

    func getVehicles() -> [String] {
        guard let vehicles = vehicles, !vehicles.isEmpty else { return [] }
        return vehicles.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setVehicles(_ items: [String]) {
        vehicles = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Makeup

    func getMakeup() -> [String] {
        guard let makeup = makeup, !makeup.isEmpty else { return [] }
        return makeup.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setMakeup(_ items: [String]) {
        makeup = items.joined(separator: ", ")
        touch()
    }

    // MARK: - SPFX

    func getSPFX() -> [String] {
        guard let spfx = spfx, !spfx.isEmpty else { return [] }
        return spfx.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setSPFX(_ items: [String]) {
        spfx = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Art

    func getArt() -> [String] {
        guard let art = art, !art.isEmpty else { return [] }
        return art.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setArt(_ items: [String]) {
        art = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Sound FX

    func getSoundFX() -> [String] {
        guard let soundfx = soundfx, !soundfx.isEmpty else { return [] }
        return soundfx.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setSoundFX(_ items: [String]) {
        soundfx = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Visual Effects

    func getVisualEffects() -> [String] {
        guard let visualEffects = visualEffects, !visualEffects.isEmpty else { return [] }
        return visualEffects.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setVisualEffects(_ items: [String]) {
        visualEffects = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Animals

    func getAnimals() -> [String] {
        guard let animals = animals, !animals.isEmpty else { return [] }
        return animals.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setAnimals(_ items: [String]) {
        animals = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Stunts

    func getStunts() -> [String] {
        guard let stunts = stunts, !stunts.isEmpty else { return [] }
        return stunts.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setStunts(_ items: [String]) {
        stunts = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Special Equipment

    func getSpecialEquipment() -> [String] {
        guard let specialEquipment = specialEquipment, !specialEquipment.isEmpty else { return [] }
        return specialEquipment.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func setSpecialEquipment(_ items: [String]) {
        specialEquipment = items.joined(separator: ", ")
        touch()
    }

    // MARK: - Custom Categories

    /// Custom categories are stored as JSON: [{"name": "Category Name", "items": "item1, item2"}]
    func getCustomCategories() -> [(name: String, items: [String])] {
        guard let customCategories = customCategories,
              !customCategories.isEmpty,
              let data = customCategories.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }

        return json.compactMap { dict in
            guard let name = dict["name"] else { return nil }
            let itemsString = dict["items"] ?? ""
            let items = itemsString.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return (name: name, items: items)
        }
    }

    func setCustomCategories(_ categories: [(name: String, items: [String])]) {
        let json = categories.map { category in
            [
                "name": category.name,
                "items": category.items.joined(separator: ", ")
            ]
        }

        if let data = try? JSONSerialization.data(withJSONObject: json, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            customCategories = jsonString
            touch()
        }
    }

    func addCustomCategory(name: String) {
        var categories = getCustomCategories()
        guard !categories.contains(where: { $0.name == name }) else { return }
        categories.append((name: name, items: []))
        setCustomCategories(categories)
    }

    func removeCustomCategory(name: String) {
        var categories = getCustomCategories()
        categories.removeAll { $0.name == name }
        setCustomCategories(categories)
    }

    func updateCustomCategory(name: String, items: [String]) {
        var categories = getCustomCategories()
        if let index = categories.firstIndex(where: { $0.name == name }) {
            categories[index] = (name: name, items: items)
            setCustomCategories(categories)
        }
    }
}
