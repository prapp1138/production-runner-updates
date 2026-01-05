//
//  ScreenplayDataManager.swift
//  Production Runner
//
//  Manages screenplay draft persistence with CoreData.
//  Optimized for large scripts (500+ pages) with external storage.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Screenplay Data Manager

@MainActor
class ScreenplayDataManager: ObservableObject {
    static let shared = ScreenplayDataManager()

    @Published var drafts: [ScreenplayDraftInfo] = []
    @Published var isLoading = false
    @Published var currentDocument: ScreenplayDocument?
    @Published var currentDraftId: UUID?

    private var context: NSManagedObjectContext?
    private var autoSaveTimer: Timer?

    /// Guards against concurrent loadDrafts operations
    private var isLoadingDrafts = false

    /// Unique identifier for each load operation to handle race conditions
    private var currentLoadId: UUID?

    private init() {}

    func configure(with context: NSManagedObjectContext) {
        print("[Screenplay DEBUG] configure called with context")
        self.context = context
        loadDrafts()
    }

    var hasDrafts: Bool {
        !drafts.isEmpty
    }

    func loadDrafts() {
        print("[Screenplay DEBUG] loadDrafts called, context: \(context != nil ? "valid" : "nil")")
        guard let context = context else {
            print("[Screenplay DEBUG] loadDrafts - no context!")
            return
        }

        // Prevent concurrent load operations
        guard !isLoadingDrafts else {
            print("[Screenplay DEBUG] loadDrafts - already loading, skipping")
            return
        }

        isLoadingDrafts = true
        let loadId = UUID()
        currentLoadId = loadId

        print("[Screenplay DEBUG] loadDrafts - Setting isLoading = TRUE (loadId: \(loadId))")
        isLoading = true

        context.perform { [weak self] in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScreenplayDraftEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

            do {
                let entities = try context.fetch(request)
                print("[Screenplay DEBUG] loadDrafts - fetched \(entities.count) entities")
                let drafts = entities.map { entity -> ScreenplayDraftInfo in
                    ScreenplayDraftInfo(
                        id: entity.value(forKey: "id") as? UUID ?? UUID(),
                        title: entity.value(forKey: "projectTitle") as? String ?? "Untitled",
                        author: entity.value(forKey: "author") as? String,
                        pageCount: entity.value(forKey: "pageCount") as? Int ?? 0,
                        sceneCount: entity.value(forKey: "sceneCount") as? Int ?? 0,
                        wordCount: entity.value(forKey: "wordCount") as? Int ?? 0,
                        updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date(),
                        importedFrom: entity.value(forKey: "importedFrom") as? String
                    )
                }

                DispatchQueue.main.async {
                    // Only update if this is still the current load operation
                    guard self?.currentLoadId == loadId else {
                        print("[Screenplay DEBUG] loadDrafts - stale load operation, discarding results")
                        return
                    }

                    print("[Screenplay DEBUG] loadDrafts - setting \(drafts.count) drafts: \(drafts.map { $0.title })")
                    self?.drafts = drafts
                    print("[Screenplay DEBUG] loadDrafts - Setting isLoading = FALSE (success)")
                    self?.isLoading = false
                    self?.isLoadingDrafts = false
                }
            } catch {
                print("[Screenplay DEBUG] loadDrafts - error: \(error)")
                DispatchQueue.main.async {
                    guard self?.currentLoadId == loadId else { return }
                    print("[Screenplay DEBUG] loadDrafts - Setting isLoading = FALSE (error)")
                    self?.isLoading = false
                    self?.isLoadingDrafts = false
                }
            }
        }
    }

    /// Create a new draft with optional elements (for imports)
    func createDraft(
        title: String = "Untitled Screenplay",
        author: String? = nil,
        elements: [ScriptElement]? = nil,
        importedFrom: String? = nil
    ) -> UUID? {
        guard let context = context else { return nil }

        let id = UUID()
        var document: ScreenplayDocument

        if let elements = elements, !elements.isEmpty {
            document = ScreenplayDocument(
                id: id,
                title: title,
                author: author ?? "",
                elements: elements
            )
        } else {
            document = ScreenplayDocument.newScreenplay(title: title)
            if let author = author {
                document.author = author
            }
        }

        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "ScreenplayDraftEntity", into: context)
            entity.setValue(id, forKey: "id")
            entity.setValue(title, forKey: "projectTitle")
            entity.setValue(author, forKey: "author")

            do {
                let encodedContent = try document.encode()
                entity.setValue(encodedContent, forKey: "content")
            } catch {
                print("[ScreenplayDataManager] ERROR: Failed to encode document: \(error)")
            }

            entity.setValue(document.estimatedPageCount, forKey: "pageCount")
            entity.setValue(document.scenes.count, forKey: "sceneCount")
            entity.setValue(calculateWordCount(document), forKey: "wordCount")
            entity.setValue(0, forKey: "sortOrder")
            entity.setValue(importedFrom, forKey: "importedFrom")
            entity.setValue(Date(), forKey: "createdAt")
            entity.setValue(Date(), forKey: "updatedAt")

            do {
                try context.save()
            } catch {
                print("[ScreenplayDataManager] ERROR: Failed to save new draft: \(error)")
            }
        }

        loadDrafts()
        return id
    }

    private func calculateWordCount(_ document: ScreenplayDocument) -> Int {
        document.elements.reduce(0) { count, element in
            count + element.text.split(separator: " ").count
        }
    }

    func loadDocument(id: UUID) -> ScreenplayDocument? {
        print("[Screenplay DEBUG] loadDocument - starting for id: \(id)")
        guard let context = context else {
            print("[Screenplay DEBUG] loadDocument - no context!")
            return nil
        }

        var result: ScreenplayDocument?

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScreenplayDraftEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                let entities = try context.fetch(request)
                print("[Screenplay DEBUG] loadDocument - found \(entities.count) entities")

                if let entity = entities.first {
                    let title = entity.value(forKey: "projectTitle") as? String ?? "unknown"
                    print("[Screenplay DEBUG] loadDocument - found entity: '\(title)'")

                    if let data = entity.value(forKey: "content") as? Data {
                        print("[Screenplay DEBUG] loadDocument - content data size: \(data.count) bytes")
                        do {
                            result = try ScreenplayDocument.decode(from: data)
                            print("[Screenplay DEBUG] loadDocument - decoded successfully, \(result?.elements.count ?? 0) elements")
                        } catch {
                            print("[Screenplay DEBUG] loadDocument - decode error: \(error)")
                        }
                    } else {
                        print("[Screenplay DEBUG] loadDocument - content is nil or not Data")
                    }
                } else {
                    print("[Screenplay DEBUG] loadDocument - no entity found for id")
                }
            } catch {
                print("[Screenplay DEBUG] loadDocument - fetch error: \(error)")
            }
        }

        if result != nil {
            currentDraftId = id
            currentDocument = result
        }

        return result
    }

    func saveDocument(_ document: ScreenplayDocument) {
        guard let context = context else { return }

        context.perform { [weak self] in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScreenplayDraftEntity")
            request.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            request.fetchLimit = 1

            do {
                let entity: NSManagedObject
                if let existing = try context.fetch(request).first {
                    entity = existing
                } else {
                    entity = NSEntityDescription.insertNewObject(forEntityName: "ScreenplayDraftEntity", into: context)
                    entity.setValue(document.id, forKey: "id")
                    entity.setValue(Date(), forKey: "createdAt")
                }

                entity.setValue(document.title, forKey: "projectTitle")
                entity.setValue(document.author, forKey: "author")
                entity.setValue(try document.encode(), forKey: "content")
                entity.setValue(document.estimatedPageCount, forKey: "pageCount")
                entity.setValue(document.scenes.count, forKey: "sceneCount")

                let wordCount = document.elements.reduce(0) { count, element in
                    count + element.text.split(separator: " ").count
                }
                entity.setValue(wordCount, forKey: "wordCount")
                entity.setValue(Date(), forKey: "updatedAt")

                try context.save()

                // Only update the draft info in the local list without triggering a full reload
                // This avoids the "Loading script..." flicker during typing
                DispatchQueue.main.async {
                    if let index = self?.drafts.firstIndex(where: { $0.id == document.id }) {
                        self?.drafts[index] = ScreenplayDraftInfo(
                            id: document.id,
                            title: document.title,
                            author: document.author,
                            pageCount: document.estimatedPageCount,
                            sceneCount: document.scenes.count,
                            wordCount: document.elements.reduce(0) { $0 + $1.text.split(separator: " ").count },
                            updatedAt: Date(),
                            importedFrom: self?.drafts[index].importedFrom
                        )
                    }
                }
            } catch {
                print("[ScreenplayDataManager] Save error: \(error)")
            }
        }
    }

    /// Save document in the background with debouncing for large scripts
    func saveDocumentAsync(_ document: ScreenplayDocument) {
        currentDocument = document

        // Cancel existing timer
        autoSaveTimer?.invalidate()

        // Debounce saves for large documents
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.saveDocument(document)
            }
        }
    }

    func deleteDraft(id: UUID) {
        guard let context = context else { return }

        print("[Screenplay DEBUG] deleteDraft called for id: \(id)")

        // Update local state first to provide immediate UI feedback
        if currentDraftId == id {
            currentDraftId = nil
            currentDocument = nil
        }

        // Remove from local array immediately for instant UI update
        drafts.removeAll { $0.id == id }

        // Clear all revisions when a script is deleted - start fresh
        Task { @MainActor in
            FDXRevisionImporter.shared.clearAllRevisions()
        }

        // Then perform the actual delete in Core Data
        context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScreenplayDraftEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            do {
                if let entity = try context.fetch(request).first {
                    context.delete(entity)
                    try context.save()
                    print("[Screenplay DEBUG] deleteDraft - saved successfully")

                    // Also clean up Breakdowns, Shots, and Scheduler data
                    self.cleanupBreakdownData(in: context)
                } else {
                    print("[Screenplay DEBUG] deleteDraft - entity not found")
                }
            } catch {
                print("[ScreenplayDataManager] ERROR: Failed to delete draft: \(error)")
            }
        }
    }

    /// Clean up all scenes, shots, and scheduler data when a script is deleted
    private func cleanupBreakdownData(in context: NSManagedObjectContext) {
        do {
            // Get the project (if any)
            let projectFetch = NSFetchRequest<NSManagedObject>(entityName: "ProjectEntity")
            projectFetch.fetchLimit = 1

            if let project = try context.fetch(projectFetch).first {
                // Use FDXImportService to clean up all related data (scenes, shots, scheduler)
                try FDXImportService.shared.deleteAllScenes(for: project, in: context)
                print("[Screenplay DEBUG] cleanupBreakdownData - cleaned up scenes, shots, and scheduler data")
            }
        } catch {
            print("[Screenplay DEBUG] cleanupBreakdownData - error: \(error)")
        }
    }

    func renameDraft(id: UUID, newTitle: String) {
        guard let context = context else { return }

        context.perform { [weak self] in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ScreenplayDraftEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                if let entity = try context.fetch(request).first {
                    entity.setValue(newTitle, forKey: "projectTitle")
                    entity.setValue(Date(), forKey: "updatedAt")
                    try context.save()
                }
            } catch {
                print("[ScreenplayDataManager] ERROR: Failed to rename draft: \(error)")
            }

            DispatchQueue.main.async {
                self?.loadDrafts()
            }
        }
    }

    /// Get document info without loading full content
    func getDraftInfo(id: UUID) -> ScreenplayDraftInfo? {
        return drafts.first { $0.id == id }
    }
}

// MARK: - Draft Info

struct ScreenplayDraftInfo: Identifiable, Equatable {
    let id: UUID
    let title: String
    let author: String?
    let pageCount: Int
    let sceneCount: Int
    let wordCount: Int
    let updatedAt: Date
    let importedFrom: String?

    init(
        id: UUID,
        title: String,
        author: String? = nil,
        pageCount: Int = 0,
        sceneCount: Int = 0,
        wordCount: Int = 0,
        updatedAt: Date = Date(),
        importedFrom: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.pageCount = pageCount
        self.sceneCount = sceneCount
        self.wordCount = wordCount
        self.updatedAt = updatedAt
        self.importedFrom = importedFrom
    }
}
