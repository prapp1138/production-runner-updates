//
//  BreakdownFDXParser.swift
//  Production Runner
//
//  FDX (Final Draft) file parsing for the Breakdowns module.
//  Extracted from Breakdowns.swift for better organization.
//

import Foundation

// MARK: - FDX Scene Model

struct FDXScene {
    var number: String
    var heading: String
    var pageLengthEighths: Int
}

// MARK: - FDX Importer

final class FDXImporter: NSObject, XMLParserDelegate {
    private var scenes: [FDXScene] = []
    private var currentElement: String = ""
    private var isInSceneHeading: Bool = false
    private var isTentativeHeading: Bool = false
    private var currentHeadingText: String = ""
    private var pendingSceneNumber: String = ""
    private var lastSceneIndexWithoutNumber: Int? = nil
    private var headingAttributeNumberCandidate: String = ""
    private var pendingLengthEighths: Int? = nil
    private var headingAttributeLengthCandidate: Int? = nil

    // MARK: - Public API

    func parse(url: URL) -> [FDXScene] {
        scenes.removeAll()
        pendingSceneNumber = ""
        lastSceneIndexWithoutNumber = nil
        headingAttributeNumberCandidate = ""
        pendingLengthEighths = nil
        headingAttributeLengthCandidate = nil

        guard let parser = XMLParser(contentsOf: url) else { return [] }
        parser.delegate = self
        _ = parser.parse()
        return scenes
    }

    // MARK: - Private Helpers

    private func parseLengthToEighths(_ raw: String) -> Int? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if s.contains(" ") && s.contains("/") {
            let parts = s.split(separator: " ", maxSplits: 1).map(String.init)
            if let whole = Int(parts[0]) {
                let fracPart = parts.count > 1 ? parts[1] : ""
                let frac = parseLengthToEighths(fracPart) ?? 0
                return whole * 8 + frac
            }
        }
        if s.contains("/") {
            let comps = s.split(separator: "/")
            if comps.count == 2, let num = Int(comps[0]), let den = Int(comps[1]), den != 0 {
                return Int(round(Double(num) * 8.0 / Double(den)))
            }
        }
        if let pages = Int(s) { return pages * 8 }
        if let d = Double(s) { return Int(round(d * 8.0)) }
        return nil
    }

    private func attrDictLooksLikeHeading(_ attrs: [String: String]) -> Bool {
        let keys = ["Type", "type", "Style", "style", "ParagraphStyle", "paragraphStyle", "ParaStyle", "paraStyle", "Class", "class", "Element", "element"]
        for k in keys {
            if let v = attrs[k]?.lowercased() {
                if v.contains("slug") { return true }
                if v == "scene heading" { return true }
                if v.contains("scene") && v.contains("heading") { return true }
                if v.replacingOccurrences(of: " ", with: "").contains("sceneheading") { return true }
            }
        }
        for (_, raw) in attrs {
            let v = raw.lowercased()
            if v.contains("slug") { return true }
            if v == "scene heading" { return true }
            if v.contains("scene") && v.contains("heading") { return true }
            if v.replacingOccurrences(of: " ", with: "").contains("sceneheading") { return true }
        }
        return false
    }

    private func textLooksLikeSlug(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        let upper = t.uppercased()
        if upper.hasPrefix("INT.") { return true }
        if upper.hasPrefix("EXT.") { return true }
        if upper.hasPrefix("INT./EXT.") { return true }
        if upper.hasPrefix("I/E.") { return true }
        return false
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        currentElement = elementName

        if elementName == "SceneProperties" {
            if let num = (attributeDict["Number"] ?? attributeDict["number"])?.trimmingCharacters(in: .whitespacesAndNewlines), !num.isEmpty {
                if let idx = lastSceneIndexWithoutNumber {
                    scenes[idx].number = num
                    lastSceneIndexWithoutNumber = nil
                } else {
                    pendingSceneNumber = num
                }
            }
            if let rawLen = (attributeDict["Length"] ?? attributeDict["length"] ?? attributeDict["PageLength"] ?? attributeDict["pageLength"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               let len8 = parseLengthToEighths(rawLen) {
                if let last = scenes.indices.last {
                    scenes[last].pageLengthEighths = len8
                } else {
                    pendingLengthEighths = len8
                }
            }
        }

        if elementName == "Paragraph" || elementName == "SceneHeading" {
            let isHeadingByAttrs: Bool = {
                if elementName == "SceneHeading" { return true }
                return attrDictLooksLikeHeading(attributeDict)
            }()

            currentHeadingText = ""
            isTentativeHeading = !isHeadingByAttrs && (elementName == "Paragraph")
            isInSceneHeading = isHeadingByAttrs

            if isHeadingByAttrs {
                if let num = (attributeDict["Number"] ?? attributeDict["number"])?.trimmingCharacters(in: .whitespacesAndNewlines), !num.isEmpty {
                    headingAttributeNumberCandidate = num
                } else {
                    headingAttributeNumberCandidate = ""
                }
                if let rawLen = (attributeDict["Length"] ?? attributeDict["length"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let len8 = parseLengthToEighths(rawLen) {
                    headingAttributeLengthCandidate = len8
                } else {
                    headingAttributeLengthCandidate = nil
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInSceneHeading || isTentativeHeading {
            currentHeadingText.append(string)
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "Paragraph" || elementName == "SceneHeading" {
            var finalizeAsHeading = isInSceneHeading
            if !finalizeAsHeading && isTentativeHeading {
                let test = currentHeadingText
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if textLooksLikeSlug(test) {
                    finalizeAsHeading = true
                }
            }

            if finalizeAsHeading {
                let heading = currentHeadingText
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()

                if !heading.isEmpty {
                    let numberToUse: String = {
                        if !headingAttributeNumberCandidate.isEmpty { return headingAttributeNumberCandidate }
                        if !pendingSceneNumber.isEmpty { return pendingSceneNumber }
                        return ""
                    }()

                    let lengthToUse: Int = {
                        if let v = headingAttributeLengthCandidate { return v }
                        if let v = pendingLengthEighths { return v }
                        return 0
                    }()

                    let scene = FDXScene(number: numberToUse,
                                         heading: heading,
                                         pageLengthEighths: lengthToUse)
                    scenes.append(scene)

                    if !pendingSceneNumber.isEmpty && numberToUse == pendingSceneNumber { pendingSceneNumber = "" }
                    if let pend = pendingLengthEighths, pend == lengthToUse { pendingLengthEighths = nil }
                    if numberToUse.isEmpty { lastSceneIndexWithoutNumber = scenes.count - 1 } else { lastSceneIndexWithoutNumber = nil }
                }
            }

            isInSceneHeading = false
            isTentativeHeading = false
            currentHeadingText = ""
            headingAttributeNumberCandidate = ""
            headingAttributeLengthCandidate = nil
        }
    }
}
