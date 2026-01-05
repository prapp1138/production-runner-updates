import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AccountSheet: View {
    @AppStorage("account_name") var name: String = ""
    @AppStorage("account_email") var email: String = ""
    @AppStorage("account_phone") var phone: String = ""
    @AppStorage("account_role") var role: String = ""
    @AppStorage("account_user_type") var userType: String = "Admin"
    @AppStorage("account_avatar_color") var avatarColorHex: String = "#007AFF" // Default blue
    @AppStorage("account_avatar_image") var avatarImageData: Data?

    @ObservedObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var ctx
    @State private var showingImagePicker = false
    @State private var showingColorPicker = false
    @State private var selectedColor: Color = .blue
    @State private var availableRoles: [String] = []
    @State private var isSyncing = false
    @State private var showSignOutConfirmation = false

    private let userTypes = ["Admin", "Guest"]
    private let contactsPurple = Color.purple

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    avatarSection
                    Divider().padding(.horizontal, 24)
                    personalInfoSection
                    Spacer(minLength: 20)
                }
            }

            Divider()
            footerSection
        }
        .frame(width: 520, height: 680)
        .onAppear {
            selectedColor = hexToColor(avatarColorHex)
            loadRoles()
            syncFromCloud()
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result: result)
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Account")
                .font(.title2)
                .bold()
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var avatarSection: some View {
        VStack(spacing: 16) {
            Text("Profile Photo")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 20) {
                avatarDisplay
                avatarControls
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showingColorPicker {
                colorPickerSection
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var avatarDisplay: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            selectedColor.opacity(0.8),
                            selectedColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            if let imageData = avatarImageData,
               let image = loadImage(from: imageData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 2)
        )
    }

    private var avatarControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingImagePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Upload Photo")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(contactsPurple)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .shadow(color: contactsPurple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            if avatarImageData != nil {
                Button {
                    avatarImageData = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Remove Photo")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.red)

                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }

            Button {
                showingColorPicker.toggle()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 16, height: 16)
                    Text("Change Color")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(contactsPurple)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .shadow(color: contactsPurple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Background Color")
                .font(.caption)
                .foregroundStyle(.secondary)

            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    avatarColorHex = colorToHex(newColor)
                }

            presetColorsRow
        }
        .padding(16)
        .background(colorPickerBackground)
    }

    private var presetColorsRow: some View {
        HStack(spacing: 12) {
            ForEach(presetColors, id: \.self) { color in
                colorCircle(for: color)
            }
        }
    }

    private func colorCircle(for color: Color) -> some View {
        let isSelected = colorToHex(selectedColor) == colorToHex(color)
        return Circle()
            .fill(color)
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? Color.primary : Color.clear,
                        lineWidth: 2
                    )
            )
            .onTapGesture {
                selectedColor = color
                avatarColorHex = colorToHex(color)
            }
    }

    private var colorPickerBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Personal Information")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 16) {
                AccountFormField(label: "Name", placeholder: "Enter your name", text: $name)
                AccountFormField(label: "Email", placeholder: "Enter your email", text: $email)
                AccountFormField(label: "Phone", placeholder: "Enter your phone number", text: $phone)

                // Role Picker (replaced text field with dropdown)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Menu {
                        ForEach(availableRoles, id: \.self) { roleOption in
                            Button(roleOption) {
                                role = roleOption
                            }
                        }
                        if !availableRoles.isEmpty {
                            Divider()
                        }
                        Button("Clear") {
                            role = ""
                        }
                    } label: {
                        HStack {
                            Text(role.isEmpty ? "Select Role..." : role)
                                .font(.system(size: 14))
                                .foregroundColor(role.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // User Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("User Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("User Type", selection: $userType) {
                        ForEach(userTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var footerSection: some View {
        HStack {
            // Sign Out Button
            Button {
                showSignOutConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Sign Out")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            // Sync status indicator
            if authService.isAuthenticated {
                HStack(spacing: 6) {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.6)
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                    } else {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    Text(isSyncing ? "Syncing..." : "Synced")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Done Button
            Button {
                saveAndDismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(contactsPurple)

                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .shadow(color: contactsPurple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }

    private var presetColors: [Color] {
        [.blue, .purple, .pink, .red, .orange, .yellow, .green, .teal, .indigo, .cyan]
    }

    private func handleImageImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            #if os(macOS)
            if let nsImage = NSImage(contentsOf: url) {
                // Resize to reasonable size
                let resized = resizeImage(nsImage, targetSize: CGSize(width: 200, height: 200))
                if let tiffData = resized.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    avatarImageData = pngData
                }
            }
            #else
            if let uiImage = UIImage(contentsOfFile: url.path) {
                let resized = resizeImage(uiImage, targetSize: CGSize(width: 200, height: 200))
                avatarImageData = resized.pngData()
            }
            #endif

        case .failure(let error):
            print("Failed to import image: \(error.localizedDescription)")
        }
    }

    #if os(macOS)
    private func resizeImage(_ image: NSImage, targetSize: CGSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    private func loadImage(from data: Data) -> Image? {
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
    }
    #else
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? image
    }

    private func loadImage(from data: Data) -> Image? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
    #endif

    private func colorToHex(_ color: Color) -> String {
        #if os(macOS)
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return "#007AFF" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #endif
    }

    private func hexToColor(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private func loadRoles() {
        // Ensure default roles are loaded
        RolesDataManager.loadDefaultRoles(context: ctx)

        // Fetch all role names
        let roles = RolesDataManager.fetchAllRoles(context: ctx)
        availableRoles = roles.compactMap { $0.value(forKey: "name") as? String }.sorted()
    }

    // MARK: - Cloud Sync

    private func syncFromCloud() {
        // Pull data from Firestore if authenticated
        if let cloudData = authService.syncToLocalStorage() {
            // Only update local storage if local is empty or cloud has data
            if name.isEmpty && !cloudData.name.isEmpty {
                name = cloudData.name
            }
            if email.isEmpty && !cloudData.email.isEmpty {
                email = cloudData.email
            }
            if phone.isEmpty && !cloudData.phone.isEmpty {
                phone = cloudData.phone
            }
            // Always sync role from cloud when authenticated
            if authService.isAuthenticated && !cloudData.role.isEmpty {
                role = cloudData.role
            }
            // Always sync userType and avatarColorHex from cloud
            if authService.isAuthenticated {
                userType = cloudData.userType
                if !cloudData.avatarColorHex.isEmpty {
                    avatarColorHex = cloudData.avatarColorHex
                    selectedColor = hexToColor(avatarColorHex)
                }
            }
        }
    }

    private func saveAndDismiss() {
        // Save to Firestore if authenticated
        if authService.isAuthenticated {
            isSyncing = true
            Task {
                do {
                    try await authService.syncFromLocalStorage(
                        name: name,
                        email: email,
                        phone: phone,
                        role: role,
                        userType: userType,
                        avatarColorHex: avatarColorHex
                    )
                } catch {
                    print("Failed to sync to cloud: \(error)")
                }
                await MainActor.run {
                    isSyncing = false
                    dismiss()
                }
            }
        } else {
            dismiss()
        }
    }

    private func signOut() {
        do {
            try authService.signOut()
            dismiss()
        } catch {
            print("Failed to sign out: \(error)")
        }
    }
}

// Helper view for form fields
private struct AccountFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
