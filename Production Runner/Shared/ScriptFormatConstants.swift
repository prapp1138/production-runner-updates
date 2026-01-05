//
//  ScriptFormatConstants.swift
//  Production Runner
//
//  Shared formatting constants for screenplay rendering.
//  Used by ScreenplayEditor and EnhancedFDXRenderer to ensure consistent formatting.
//

import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
public typealias ScriptPlatformColor = NSColor
public typealias ScriptPlatformFont = NSFont
#else
import UIKit
public typealias ScriptPlatformColor = UIColor
public typealias ScriptPlatformFont = UIFont
#endif

// MARK: - Script Format Constants

public enum ScriptFormatConstants {

    // MARK: - Page Dimensions (US Letter)

    /// 8.5 inches
    public static let pageWidth: CGFloat = 612
    /// 11 inches
    public static let pageHeight: CGFloat = 792

    // MARK: - Margins (Final Draft standard)

    /// 1.5 inches (left margin)
    public static let marginLeft: CGFloat = 108
    /// 1.0 inch (right margin)
    public static let marginRight: CGFloat = 72
    /// 1.0 inch (top margin)
    public static let marginTop: CGFloat = 72
    /// 0.5 inch (bottom margin)
    public static let marginBottom: CGFloat = 36

    /// Content width = 8.5" - 1.5" - 1" = 6" = 432pt
    public static let contentWidth: CGFloat = pageWidth - marginLeft - marginRight
    /// Content height = 11" - 1" - 0.5" = 9.5" = 684pt
    public static let contentHeight: CGFloat = pageHeight - marginTop - marginBottom

    // MARK: - Typography

    public static let fontName = "Courier"
    public static let fontSize: CGFloat = 12
    public static let lineHeight: CGFloat = 12  // Single-spaced

    // MARK: - Page Calculation

    /// Characters per line (standard screenplay)
    public static let charsPerLine = 60
    /// Lines per page (standard screenplay)
    public static let linesPerPage = 55

    // MARK: - Element Indents (from content left edge)

    /// Scene Heading: Left margin (0 indent)
    public static let sceneHeadingLeftIndent: CGFloat = 0
    public static let sceneHeadingRightIndent: CGFloat = 0

    /// Action: Left margin (0 indent)
    public static let actionLeftIndent: CGFloat = 0
    public static let actionRightIndent: CGFloat = 0

    /// Character: 144pt from content edge (centered above dialogue block)
    public static let characterLeftIndent: CGFloat = 144
    public static let characterRightIndent: CGFloat = 0

    /// Dialogue: 72pt left indent, 72pt right indent
    public static let dialogueLeftIndent: CGFloat = 72
    public static let dialogueRightIndent: CGFloat = 72

    /// Parenthetical: 108pt left indent, 108pt right indent
    public static let parentheticalLeftIndent: CGFloat = 108
    public static let parentheticalRightIndent: CGFloat = 108

    /// Transition: 288pt left indent (right-aligned effect)
    public static let transitionLeftIndent: CGFloat = 288
    public static let transitionRightIndent: CGFloat = 0

    // MARK: - Paragraph Spacing (in points)

    /// 1 blank line = 12pt
    public static let blankLine: CGFloat = 12

    /// Scene Heading: 2 blank lines before
    public static let sceneHeadingSpaceBefore: CGFloat = 24
    public static let sceneHeadingSpaceAfter: CGFloat = 0

    /// Action: 1 blank line before
    public static let actionSpaceBefore: CGFloat = 12
    public static let actionSpaceAfter: CGFloat = 0

    /// Character: 1 blank line before
    public static let characterSpaceBefore: CGFloat = 12
    public static let characterSpaceAfter: CGFloat = 0

    /// Parenthetical: No space
    public static let parentheticalSpaceBefore: CGFloat = 0
    public static let parentheticalSpaceAfter: CGFloat = 0

    /// Dialogue: No space
    public static let dialogueSpaceBefore: CGFloat = 0
    public static let dialogueSpaceAfter: CGFloat = 0

    /// Transition: 1 blank line before, 0 after (scene heading provides its own spacing)
    public static let transitionSpaceBefore: CGFloat = 12
    public static let transitionSpaceAfter: CGFloat = 0
}

// MARK: - Revision Colors

public enum ScriptRevisionColors {

    /// Get platform color for revision color name
    public static func platformColor(for colorName: String) -> ScriptPlatformColor {
        switch colorName.lowercased() {
        case "white", "":
            return ScriptPlatformColor.black
        case "blue":
            return ScriptPlatformColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        case "pink":
            return ScriptPlatformColor(red: 0.85, green: 0.2, blue: 0.5, alpha: 1.0)
        case "yellow":
            return ScriptPlatformColor(red: 0.7, green: 0.55, blue: 0.0, alpha: 1.0)
        case "green":
            return ScriptPlatformColor(red: 0.0, green: 0.6, blue: 0.3, alpha: 1.0)
        case "goldenrod":
            return ScriptPlatformColor(red: 0.72, green: 0.53, blue: 0.04, alpha: 1.0)
        case "buff":
            return ScriptPlatformColor(red: 0.6, green: 0.45, blue: 0.2, alpha: 1.0)
        case "salmon":
            return ScriptPlatformColor(red: 0.9, green: 0.35, blue: 0.25, alpha: 1.0)
        case "cherry":
            return ScriptPlatformColor(red: 0.75, green: 0.15, blue: 0.4, alpha: 1.0)
        case "tan":
            return ScriptPlatformColor(red: 0.55, green: 0.4, blue: 0.25, alpha: 1.0)
        case "gray", "grey":
            return ScriptPlatformColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        default:
            return ScriptPlatformColor.black
        }
    }

    /// Get SwiftUI Color for revision color name
    public static func swiftUIColor(for colorName: String) -> Color? {
        switch colorName.lowercased() {
        case "white", "":
            return nil
        case "blue":
            return Color(red: 0.0, green: 0.4, blue: 0.8)
        case "pink":
            return Color(red: 0.85, green: 0.2, blue: 0.5)
        case "yellow":
            return Color(red: 0.7, green: 0.55, blue: 0.0)
        case "green":
            return Color(red: 0.0, green: 0.6, blue: 0.3)
        case "goldenrod":
            return Color(red: 0.72, green: 0.53, blue: 0.04)
        case "buff":
            return Color(red: 0.6, green: 0.45, blue: 0.2)
        case "salmon":
            return Color(red: 0.9, green: 0.35, blue: 0.25)
        case "cherry":
            return Color(red: 0.75, green: 0.15, blue: 0.4)
        case "tan":
            return Color(red: 0.55, green: 0.4, blue: 0.25)
        case "gray", "grey":
            return Color(red: 0.5, green: 0.5, blue: 0.5)
        default:
            return nil
        }
    }

    /// Standard revision color order (film industry standard)
    public static let colorOrder: [String] = [
        "White",      // Original
        "Blue",       // 1st revision
        "Pink",       // 2nd revision
        "Yellow",     // 3rd revision
        "Green",      // 4th revision
        "Goldenrod",  // 5th revision
        "Buff",       // 6th revision
        "Salmon",     // 7th revision
        "Cherry",     // 8th revision
        "Tan",        // 9th revision
        "Gray"        // 10th revision (then cycle repeats)
    ]
}
