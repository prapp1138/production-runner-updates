// ProjectFileStore.swift
import Foundation

public final class ProjectFileStore: ObservableObject {
    @Published public var url: URL? = nil
    public init(url: URL? = nil) { self.url = url }
}
