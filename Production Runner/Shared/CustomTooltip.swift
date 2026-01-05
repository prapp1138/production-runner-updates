//
//  CustomTooltip.swift
//  Production Runner
//
//  Custom tooltip implementation that works reliably with all button styles.
//  Solves the issue where SwiftUI's .help() modifier doesn't display on .plain buttons.
//

import SwiftUI

#if os(macOS)
import AppKit

/// A custom tooltip modifier that works with all button styles, including .plain
struct CustomTooltipModifier: ViewModifier {
    let text: String
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: TooltipPreferenceKey.self,
                        value: isHovering ? TooltipData(text: text, frame: geometry.frame(in: .global)) : nil
                    )
                }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovering = true
                case .ended:
                    isHovering = false
                }
            }
    }
}

/// Preference key to pass tooltip data up the view hierarchy
struct TooltipPreferenceKey: PreferenceKey {
    static var defaultValue: TooltipData?

    static func reduce(value: inout TooltipData?, nextValue: () -> TooltipData?) {
        value = nextValue() ?? value
    }
}

struct TooltipData: Equatable {
    let text: String
    let frame: CGRect
}

/// The tooltip overlay that displays the tooltip text
struct TooltipOverlay: View {
    let data: TooltipData?
    let containerFrame: CGRect

    var body: some View {
        if let data = data {
            // Convert global button frame to local coordinates relative to container
            let buttonRight = data.frame.maxX - containerFrame.minX
            let buttonBottom = data.frame.maxY - containerFrame.minY

            Text(data.text)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .foregroundColor(.primary)
                .fixedSize()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: buttonRight + 6, y: buttonBottom + 6)  // Position to bottom-right of button
                .transition(.opacity)
                .zIndex(999)
                .allowsHitTesting(false)
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Apply a custom tooltip that works with all button styles
    func customTooltip(_ text: String) -> some View {
        self.modifier(CustomTooltipModifier(text: text))
    }
}

/// Root view modifier to enable tooltip display
struct TooltipEnabler: ViewModifier {
    @State private var tooltipData: TooltipData?
    @State private var isVisible = false
    @State private var showTask: DispatchWorkItem?
    @State private var containerFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            containerFrame = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                            containerFrame = newFrame
                        }
                }
            )
            .onPreferenceChange(TooltipPreferenceKey.self) { data in
                // Cancel any pending show task
                showTask?.cancel()

                if data == nil {
                    // Hide immediately when hover ends
                    withAnimation(.easeOut(duration: 0.1)) {
                        isVisible = false
                    }
                    // Clear data after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if !isVisible {
                            tooltipData = nil
                        }
                    }
                } else if let newData = data {
                    // Store the data
                    tooltipData = newData
                    // Show after a short delay (prevents flicker on quick mouse movements)
                    let expectedText = newData.text
                    let task = DispatchWorkItem {
                        if let current = tooltipData, current.text == expectedText {
                            withAnimation(.easeIn(duration: 0.1)) {
                                isVisible = true
                            }
                        }
                    }
                    showTask = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
                }
            }
            .overlay(
                Group {
                    if isVisible, let data = tooltipData {
                        TooltipOverlay(data: data, containerFrame: containerFrame)
                    }
                }
            )
    }
}

extension View {
    /// Enable tooltips for this view hierarchy
    func enableTooltips() -> some View {
        self.modifier(TooltipEnabler())
    }
}

#else
// iOS fallback - use standard .help() which shows in long-press menus
extension View {
    func customTooltip(_ text: String) -> some View {
        self.help(text)
    }

    func enableTooltips() -> some View {
        self
    }
}
#endif
