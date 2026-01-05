//
//  AppSectioniOS.swift
//  Production Runner
//
//  Created by Brandon on 11/25/25.
//

import SwiftUI

#if os(iOS)
// MARK: - iOS App Section Panel (Icons Only, Compact)
/// Compact icon-only version of the app section panel for iOS
struct AppSectionPaneliOS: View {
    @Binding var selected: AppSection
    @AppStorage("AppSectionSelected") private var selectedRaw: String = ""
    var onSelect: ((AppSection) -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            ForEach(AppSection.allCases) { s in
                AppSectionTileiOS(section: s, isSelected: s == selected) {
                    selectedRaw = s.rawValue
                    selected = s
                    onSelect?(s)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: 52)
        .onAppear {
            if let persisted = AppSection(rawValue: selectedRaw), !selectedRaw.isEmpty {
                selected = persisted
            } else {
                selected = .productionRunner
                selectedRaw = AppSection.productionRunner.rawValue
            }
        }
        .onChange(of: selected) { newValue in
            selectedRaw = newValue.rawValue
        }
    }
}

// MARK: - iOS App Section Tile (Square Icon Only)
struct AppSectionTileiOS: View {
    var section: AppSection
    var isSelected: Bool = false
    @AppStorage("AppSectionSelected") private var selectedRaw: String = ""
    var action: () -> Void

    var body: some View {
        let active = isSelected || selectedRaw == section.rawValue
        let sectionColor = section.accentColor

        Button(action: {
            selectedRaw = section.rawValue
            action()
        }) {
            ZStack(alignment: .leading) {
                // Vertical accent bar (left edge)
                if active {
                    Rectangle()
                        .fill(sectionColor)
                        .frame(width: 3)
                        .clipShape(Capsule())
                }

                // Icon
                Image(systemName: section.icon)
                    .font(.system(size: 22, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? sectionColor : .secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.rawValue)
    }
}
#endif
