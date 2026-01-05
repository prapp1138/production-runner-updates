import Foundation

public struct SceneStrip: Identifiable, Hashable, Comparable, Codable {
    // Stable identifier so reordering the array doesn't create a new ID
    public var id: UUID

    /// 1-based position in the board; also shown as Scene #
    public var index: Int

    /// Full scene heading pieces mirrored from Breakdowns
    public var slugline: String              // e.g., "LIVING ROOM"
    public var intExt: String               // e.g., "INT." or "EXT."
    public var location: String             // e.g., "HOUSE"
    public var dayNight: String             // e.g., "DAY" / "NIGHT"

    /// Optional real-world shoot location (address / stage), shown on strips
    public var shootLocation: String?

    /// Script page range (whole-page granularity); page length is derived
    public var startPage: Int
    public var endPage: Int

    /// Scene number from the script (e.g., "1", "1A", "2", "OMIT 3")
    public var sceneNumber: String?

    /// Whether this scene is marked as omitted in the script
    public var isOmitted: Bool

    /// The raw heading line from the script (unparsed)
    public var rawHeading: String?

    /// Page length in eighths (8 eighths = 1 page, e.g., 4 = half page)
    public var pageEighths: Int

    // MARK: - Derived values
    /// Total number of whole pages between start and end (never negative)
    public var pageCount: Double {
        max(0, Double(endPage - startPage))
    }

    /// Single-line heading that matches the classic strip style
    public var headingLine: String {
        "\(index). \(intExt) \(slugline.isEmpty ? location : slugline) - \(dayNight)"
    }

    /// Page length text (e.g., "Pg. 1" or "Pg. 2")
    public var pageLengthText: String {
        let pages = max(0, endPage - startPage)
        return pages <= 1 ? "Pg. 1" : "Pg. \(pages)"
    }

    /// Optional shoot location line (prefixed for direct display)
    public var shootLocationLine: String? {
        guard let shoot = shootLocation, !shoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return "Location: \(shoot)"
    }

    // MARK: - Ordering
    /// Sort by numeric index (ascending)
    public static func < (lhs: SceneStrip, rhs: SceneStrip) -> Bool { lhs.index < rhs.index }

    /// Return a copy with a different index
    public func withIndex(_ newIndex: Int) -> SceneStrip {
        var copy = self
        copy.index = newIndex
        return copy
    }

    /// Normalize an array of strips to sequential indices (1..n) based on current sort order
    public static func normalized(from strips: [SceneStrip]) -> [SceneStrip] {
        let sorted = strips.sorted() // uses Comparable (index)
        return sorted.enumerated().map { (offset, strip) in
            var s = strip
            s.index = offset + 1
            return s
        }
    }

    /// In-place renumbering convenience to keep indices contiguous after inserts/deletes
    public static func renumberInPlace(_ strips: inout [SceneStrip]) {
        strips = SceneStrip.normalized(from: strips)
    }

    // MARK: - Init
    public init(
        id: UUID = UUID(),
        index: Int,
        slugline: String,
        intExt: String,
        location: String,
        dayNight: String,
        startPage: Int,
        endPage: Int,
        shootLocation: String? = nil,
        sceneNumber: String? = nil,
        isOmitted: Bool = false,
        rawHeading: String? = nil,
        pageEighths: Int = 1
    ) {
        self.id = id
        self.index = index
        self.slugline = slugline
        self.intExt = intExt
        self.location = location
        self.dayNight = dayNight
        self.startPage = startPage
        self.endPage = endPage
        self.shootLocation = shootLocation
        self.sceneNumber = sceneNumber
        self.isOmitted = isOmitted
        self.rawHeading = rawHeading
        self.pageEighths = pageEighths
    }
}
