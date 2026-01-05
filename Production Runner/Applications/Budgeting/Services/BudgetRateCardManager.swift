import Foundation
import CoreData

/// Manages rate card operations
/// Extracted from BudgetViewModel for single responsibility
final class BudgetRateCardManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var rateCards: [RateCardEntity] = []

    // MARK: - Private Properties

    private let context: NSManagedObjectContext
    private let auditTrail: BudgetAuditTrail

    // MARK: - Initialization

    init(context: NSManagedObjectContext, auditTrail: BudgetAuditTrail = BudgetAuditTrail()) {
        self.context = context
        self.auditTrail = auditTrail
        loadRateCards()
    }

    // MARK: - Rate Card Loading

    func loadRateCards() {
        rateCards = RateCardEntity.fetchAll(in: context)
        BudgetLogger.info("Loaded \(rateCards.count) rate cards", category: BudgetLogger.data)
    }

    // MARK: - Rate Card CRUD

    /// Create a new rate card
    @discardableResult
    func createRateCard(
        name: String,
        category: String,
        unit: String,
        rate: Double,
        notes: String = ""
    ) -> RateCardEntity {
        let rateCard = RateCardEntity.create(
            name: name,
            category: category,
            defaultUnit: unit,
            defaultRate: rate,
            notes: notes,
            in: context
        )

        loadRateCards()

        auditTrail.recordChange(
            action: .created,
            entityType: "RateCard",
            entityID: rateCard.id ?? UUID(),
            details: "Created rate card '\(name)' at \(rate.asCurrency())/\(unit)"
        )

        BudgetLogger.logDataOperation(.create, entity: "RateCard", success: true)
        return rateCard
    }

    /// Update an existing rate card
    func updateRateCard(
        _ rateCard: RateCardEntity,
        name: String? = nil,
        category: String? = nil,
        unit: String? = nil,
        rate: Double? = nil,
        notes: String? = nil
    ) {
        rateCard.update(
            name: name,
            category: category,
            defaultUnit: unit,
            defaultRate: rate,
            notes: notes
        )

        loadRateCards()

        auditTrail.recordChange(
            action: .updated,
            entityType: "RateCard",
            entityID: rateCard.id ?? UUID(),
            details: "Updated rate card '\(rateCard.displayName)'"
        )

        BudgetLogger.logDataOperation(.update, entity: "RateCard", success: true)
    }

    /// Delete a rate card
    func deleteRateCard(_ rateCard: RateCardEntity) {
        let cardName = rateCard.displayName
        let cardID = rateCard.id ?? UUID()

        rateCard.delete()
        loadRateCards()

        auditTrail.recordChange(
            action: .deleted,
            entityType: "RateCard",
            entityID: cardID,
            details: "Deleted rate card '\(cardName)'"
        )

        BudgetLogger.logDataOperation(.delete, entity: "RateCard", success: true)
    }

    // MARK: - Rate Card Linking

    /// Link a line item to a rate card
    func linkItemToRateCard(item: inout BudgetLineItem, rateCard: RateCardEntity) {
        item.isLinkedToRateCard = true
        item.rateCardID = rateCard.id
        item.unitCost = rateCard.defaultRate

        BudgetLogger.debug("Linked item '\(item.name)' to rate card '\(rateCard.displayName)'", category: BudgetLogger.data)
    }

    /// Unlink a line item from its rate card
    func unlinkItemFromRateCard(item: inout BudgetLineItem) {
        item.isLinkedToRateCard = false
        item.rateCardID = nil

        BudgetLogger.debug("Unlinked item '\(item.name)' from rate card", category: BudgetLogger.data)
    }

    // MARK: - Rate Card Lookup

    /// Find rate card by ID
    func rateCard(for id: UUID) -> RateCardEntity? {
        rateCards.first { $0.id == id }
    }

    /// Find rate cards by category
    func rateCards(for category: String) -> [RateCardEntity] {
        rateCards.filter { $0.category == category }
    }

    /// Get rate from linked rate card
    func getRate(for rateCardID: UUID?) -> Double? {
        guard let id = rateCardID,
              let rateCard = rateCard(for: id) else {
            return nil
        }
        return rateCard.defaultRate
    }

    // MARK: - Bulk Operations

    /// Update all items linked to a rate card when the rate changes
    func updateLinkedItems(for rateCardID: UUID, in items: inout [BudgetLineItem]) {
        guard let rateCard = rateCard(for: rateCardID) else { return }

        for index in items.indices {
            if items[index].rateCardID == rateCardID && items[index].isLinkedToRateCard {
                items[index].unitCost = rateCard.defaultRate
            }
        }

        BudgetLogger.info("Updated \(items.filter { $0.rateCardID == rateCardID }.count) items linked to rate card", category: BudgetLogger.data)
    }
}
