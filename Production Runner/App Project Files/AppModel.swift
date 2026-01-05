import SwiftUI

final class AppModel: ObservableObject {
    enum Root {
        case launch
        case project(url: URL)
    }

    @Published var root: Root = .launch

    @AppStorage("lastProjectURL") private var lastProjectURLData: Data?
    var hasRestorableProject: Bool { lastProjectURLData != nil }

    func openProject(at url: URL) {
        lastProjectURLData = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        root = .project(url: url)
    }

    func closeProject() { root = .launch }

    func restoreLastIfAvailable() -> Bool {
        guard let data = lastProjectURLData else { return false }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale), !stale {
            root = .project(url: url)
            return true
        }
        return false
    }
}
