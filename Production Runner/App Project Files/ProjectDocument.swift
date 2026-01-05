//  ProjectDocument.swift
//  Production Runner

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Exported UTI for Production Runner package (.runner)
    static let productionRunnerProject = UTType(exportedAs: "com.m42.productionrunner.project", conformingTo: .package)
}

/// Minimal `.runner` package document using SwiftUI's FileDocument API.
/// Represented as a FileWrapper (directory) while ensuring a `Store/` folder exists.
final class ProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.productionRunnerProject] }
    static var writableContentTypes: [UTType] { [.productionRunnerProject] }

    private var wrapper: FileWrapper

    /// Create a brand-new, empty package with a Store/ directory
    init() {
        let root = FileWrapper(directoryWithFileWrappers: [:])
        root.preferredFilename = "Untitled.runner"
        let store = FileWrapper(directoryWithFileWrappers: [:])
        store.preferredFilename = "Store"
        root.addFileWrapper(store)
        self.wrapper = root
    }

    /// Load from an existing package wrapper and ensure it contains a Store/
    init(configuration: ReadConfiguration) throws {
        let root = configuration.file
        if root.fileWrappers?["Store"] == nil {
            let store = FileWrapper(directoryWithFileWrappers: [:])
            store.preferredFilename = "Store"
            root.addFileWrapper(store)
        }
        self.wrapper = root
    }

    /// Return the wrapper to be written to disk (ensuring Store/ exists)
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if wrapper.fileWrappers?["Store"] == nil {
            let store = FileWrapper(directoryWithFileWrappers: [:])
            store.preferredFilename = "Store"
            wrapper.addFileWrapper(store)
        }
        return wrapper
    }
}
