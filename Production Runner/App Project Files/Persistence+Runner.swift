//  Persistence+Runner.swift
//  Production Runner
import CoreData

enum RunnerPersistenceError: Error {
    case invalidProjectURL
    case missingStore
}

final class RunnerPersistence {
    static func container(forProjectURL projectURL: URL, modelName: String = "ProductionRunner") throws -> NSPersistentContainer {
        // Store is inside the package: <project>.runner/Store/ProductionRunner.sqlite
        let storeURL = projectURL
            .appendingPathComponent("Store", isDirectory: true)
            .appendingPathComponent("\(modelName).sqlite", isDirectory: false)

        let description = NSPersistentStoreDescription(url: storeURL)
        // WAL mode by default; journal files will live alongside the sqlite file
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let container = NSPersistentContainer(name: modelName)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, err in
            if let err = err { loadError = err }
        }
        if let loadError = loadError { throw loadError }

        return container
    }

    /// Ensures the package has the minimum folder layout for a new project.
    static func preparePackageSkeleton(at projectURL: URL) throws {
        let fm = FileManager.default
        let requiredDirs = [
            "Store",
            "Thumbnails",
            "Assets"
        ]
        for d in requiredDirs {
            let dirURL = projectURL.appendingPathComponent(d, isDirectory: true)
            if !fm.fileExists(atPath: dirURL.path) {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            }
        }
        // Basic metadata
        let metaURL = projectURL.appendingPathComponent("Metadata.plist")
        if !fm.fileExists(atPath: metaURL.path) {
            let meta: [String: Any] = [
                "name": projectURL.deletingPathExtension().lastPathComponent,
                "created": Date().timeIntervalSince1970,
                "version": 1
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: meta, format: .xml, options: 0)
            try data.write(to: metaURL)
        }
    }
}
