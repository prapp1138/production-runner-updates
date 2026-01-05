//  SceneParsingUtilities.swift
//  Production Runner
//
//  Created to consolidate duplicate parsing logic between FDX and PDF importers
//

import Foundation

/// Utility functions for parsing screenplay formatting elements
/// Shared between FDXImportService and PDFImportService to eliminate code duplication
struct SceneParsingUtilities {

    // MARK: - Page/Eighths Parsing

    /// Convert strings like "4/8", "1 4/8", "2 0/8" to total eighths (Int16).
    /// - Parameter s: The string representation of page eighths
    /// - Returns: Total eighths as Int16, or nil if parsing fails
    ///
    /// Examples:
    /// - "4/8" → 4 eighths (half page)
    /// - "1 4/8" → 12 eighths (1.5 pages)
    /// - "2" → 16 eighths (2 pages)
    /// - "1 0/8" → 8 eighths (1 page)
    static func parseEighths(_ s: String) -> Int16? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        var pages: Int16 = 0
        var eighths: Int16 = 0
        let parts = trimmed.split(separator: " ")

        if parts.count == 2 {
            // Format: "1 4/8" (whole pages + fraction)
            if let p = Int16(parts[0]) { pages = p }
            let frac = parts[1]
            let fracParts = frac.split(separator: "/")
            if fracParts.count == 2,
               let num = Int16(fracParts[0]),
               let den = Int16(fracParts[1]),
               den != 0 {
                eighths = Int16((Int(num) * 8) / Int(den))  // normalize to eighths
            }
        } else if parts.count == 1 {
            // Format: "4/8" (just fraction) or "2" (just pages)
            if parts[0].contains("/") {
                let fracParts = parts[0].split(separator: "/")
                if fracParts.count == 2,
                   let num = Int16(fracParts[0]),
                   let den = Int16(fracParts[1]),
                   den != 0 {
                    eighths = Int16((Int(num) * 8) / Int(den))
                }
            } else if let p = Int16(parts[0]) {
                pages = p
            }
        }

        return pages &* 8 &+ eighths
    }

    // MARK: - Scene Heading Parsing

    /// Parse a scene heading like "INT. KITCHEN - DAY" into components.
    /// - Parameter heading: The full scene heading text
    /// - Returns: A tuple containing (locationType, scriptLocation, timeOfDay)
    ///
    /// Examples:
    /// - "INT. KITCHEN - DAY" → ("INT", "KITCHEN", "DAY")
    /// - "EXT. PARK - NIGHT" → ("EXT", "PARK", "NIGHT")
    /// - "INT./EXT. CAR - DAY" → ("INT/EXT", "CAR", "DAY")
    /// - "12 INT. HOUSE - DAY" → ("INT", "HOUSE", "DAY") - strips leading scene number
    ///
    /// All returned strings are trimmed; may be empty if not found.
    static func parseHeadingComponents(_ heading: String) -> (locationType: String, scriptLocation: String, timeOfDay: String) {
        var raw = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return ("", "", "") }

        // Strip a leading scene number like "12 " or "#12 " that some templates include before INT/EXT
        if let firstSpace = raw.firstIndex(of: " ") {
            let prefix = raw[..<firstSpace]
            if prefix.rangeOfCharacter(from: .decimalDigits) != nil || raw.hasPrefix("#") {
                raw = String(raw[firstSpace...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Normalize multiple spaces and dots in INT./EXT.
        var s = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "INT", with: "INT.", options: [.caseInsensitive, .anchored])
        s = s.replacingOccurrences(of: "EXT", with: "EXT.", options: [.caseInsensitive, .anchored])

        // Detect prefix INT./EXT./INT./EXT. etc.
        var locationType = ""
        var remainder = s

        let upperRemainder = remainder.uppercased()

        if upperRemainder.hasPrefix("INT./EXT.") || upperRemainder.hasPrefix("INT/EXT.") {
            locationType = "INT/EXT"
            let dropCount = upperRemainder.hasPrefix("INT./EXT.") ? 9 : 8
            remainder = String(remainder.dropFirst(dropCount)).trimmingCharacters(in: .whitespaces)
        } else if upperRemainder.hasPrefix("I/E.") || upperRemainder.hasPrefix("I/E ") {
            locationType = "INT/EXT"
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if upperRemainder.hasPrefix("INT.") || upperRemainder.hasPrefix("INT ") {
            locationType = "INT"
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if upperRemainder.hasPrefix("EXT.") || upperRemainder.hasPrefix("EXT ") {
            locationType = "EXT"
            remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }

        // Split by trailing " - TIME"
        let parts = remainder.components(separatedBy: " - ")
        var scriptLocation = remainder
        var timeOfDay = ""

        if parts.count >= 2, let lastPart = parts.last {
            // Safe: using optional binding instead of force unwrap
            timeOfDay = lastPart.trimmingCharacters(in: .whitespaces)
            scriptLocation = parts.dropLast().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        }

        return (locationType, scriptLocation, timeOfDay)
    }

    // MARK: - Scene Number Parsing

    /// Parse a scene number that may contain a scene number and optional letter suffix
    /// - Parameter sceneNumber: The scene number string (e.g., "12", "12A", "12.5")
    /// - Returns: A tuple containing (intPart, letterSuffix, fracPart)
    ///
    /// Examples:
    /// - "12" → (12, "", nil)
    /// - "12A" → (12, "A", nil)
    /// - "12.5" → (12, "", 5)
    static func parseSceneNumber(_ sceneNumber: String) -> (intPart: Int, letterSuffix: String, fracPart: Int?) {
        var trimmed = sceneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        var letterSuffix = ""

        // Extract trailing letter suffix (A, B, C, etc.)
        if let lastChar = trimmed.last, lastChar.isLetter {
            letterSuffix = String(lastChar).uppercased()
            trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        var intPart = 0
        var fracPart: Int? = nil

        // Check for decimal notation (e.g., "12.5")
        if trimmed.contains(".") {
            let components = trimmed.split(separator: ".")
            if components.count >= 1 {
                intPart = Int(components[0]) ?? 0
            }
            if components.count >= 2 {
                fracPart = Int(components[1])
            }
        } else {
            intPart = Int(trimmed) ?? 0
        }

        return (intPart, letterSuffix, fracPart)
    }

    // MARK: - Validation Helpers

    /// Check if a string looks like a scene heading
    /// - Parameter text: The text to check
    /// - Returns: true if it appears to be a scene heading
    static func looksLikeSceneHeading(_ text: String) -> Bool {
        let upper = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return upper.hasPrefix("INT.") ||
               upper.hasPrefix("EXT.") ||
               upper.hasPrefix("INT/EXT") ||
               upper.hasPrefix("I/E.")
    }

    /// Check if a string looks like a time of day indicator
    /// - Parameter text: The text to check
    /// - Returns: true if it matches common time of day patterns
    static func looksLikeTimeOfDay(_ text: String) -> Bool {
        let upper = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let commonTimes = ["DAY", "NIGHT", "MORNING", "AFTERNOON", "EVENING", "DAWN", "DUSK", "CONTINUOUS", "LATER", "SAME"]
        return commonTimes.contains(upper)
    }
}

// MARK: - Unit Tests (can be moved to separate test file)

#if DEBUG
extension SceneParsingUtilities {

    /// Run basic validation tests
    static func runTests() {
        // Test parseEighths
        assert(parseEighths("4/8") == 4, "Failed: 4/8 should be 4 eighths")
        assert(parseEighths("1 4/8") == 12, "Failed: 1 4/8 should be 12 eighths")
        assert(parseEighths("2") == 16, "Failed: 2 should be 16 eighths")
        assert(parseEighths("") == nil, "Failed: empty should be nil")

        // Test parseHeadingComponents
        let test1 = parseHeadingComponents("INT. KITCHEN - DAY")
        assert(test1.locationType == "INT", "Failed: location type")
        assert(test1.scriptLocation == "KITCHEN", "Failed: script location")
        assert(test1.timeOfDay == "DAY", "Failed: time of day")

        let test2 = parseHeadingComponents("12 EXT. PARK - NIGHT")
        assert(test2.locationType == "EXT", "Failed: scene number strip")
        assert(test2.scriptLocation == "PARK", "Failed: location")
        assert(test2.timeOfDay == "NIGHT", "Failed: night")

        // Test parseSceneNumber
        let scene1 = parseSceneNumber("12")
        assert(scene1.intPart == 12 && scene1.letterSuffix == "", "Failed: scene 12")

        let scene2 = parseSceneNumber("12A")
        assert(scene2.intPart == 12 && scene2.letterSuffix == "A", "Failed: scene 12A")

        print("✅ SceneParsingUtilities: All tests passed")
    }
}
#endif
