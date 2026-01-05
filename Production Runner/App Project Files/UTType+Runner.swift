//  UTType+Runner.swift
//  Production Runner
import UniformTypeIdentifiers

extension UTType {
    /// The document type for `.runner` projects treated as macOS packages (bundles).
    static let runnerProject = UTType(exportedAs: "com.m42.productionrunner.runner", conformingTo: .package)
}
