//
//  SplashScreenView.swift
//  Production Runner
//
//  Adobe-style splash screen that appears during app launch.
//  Shows loading progress while checking internet and Firebase authentication.
//

import SwiftUI

// MARK: - Splash Screen View

struct SplashScreenView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var rotationAngle: Double = 0
    @State private var showRetry = false

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            VStack(spacing: 24) {
                Spacer()

                // App Icon
                appIconView

                // App Title
                Text("Production Runner")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.primary)

                Spacer()

                // Status Section
                statusSection

                Spacer()
                    .frame(height: 40)
            }
            .padding(40)
        }
        .frame(width: 400, height: 300)
        .onAppear {
            startLoadingAnimation()
        }
        .onChange(of: authService.connectionState) { newState in
            if newState == .disconnected {
                showRetry = true
            } else {
                showRetry = false
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        #if os(macOS)
        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        #else
        Color(.systemBackground)
        #endif
    }

    // MARK: - App Icon

    private var appIconView: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Icon background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 20, x: 0, y: 10)

            // Film icon
            Image(systemName: "film.stack")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 16) {
            if showRetry || authService.errorMessage != nil {
                // Error state
                errorStateView
            } else {
                // Loading state
                loadingStateView
            }
        }
    }

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            // Custom spinning loader
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 3)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(rotationAngle))
            }

            // Status message
            Text(authService.statusMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var errorStateView: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: "wifi.slash")
                .font(.system(size: 24))
                .foregroundStyle(.red)

            // Error message
            Text(authService.errorMessage ?? "No internet connection")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Retry button
            Button(action: retry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Animation

    private func startLoadingAnimation() {
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    // MARK: - Actions

    private func retry() {
        showRetry = false
        Task {
            await authService.retryConnection()
        }
    }
}

// MARK: - Visual Effect Blur (macOS)

#if os(macOS)
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#endif

// MARK: - Splash Window Controller (macOS)

#if os(macOS)
class SplashWindowController: NSWindowController {
    convenience init() {
        let splashView = SplashScreenView()
        let hostingController = NSHostingController(rootView: splashView)

        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.center()

        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 16
        window.contentView?.layer?.masksToBounds = true

        self.init(window: window)
    }

    func showSplash() {
        window?.orderFront(nil)
        window?.center()
    }

    func dismissSplash() {
        window?.close()
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
            .frame(width: 400, height: 300)
    }
}
#endif
