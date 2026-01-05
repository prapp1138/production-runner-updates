//
//  ContactPhotoManager.swift
//  Production Runner
//
//  Handles photo operations for contacts: picking, thumbnail generation, and display.
//

import SwiftUI
import CoreData

#if os(macOS)
import AppKit

// MARK: - Photo Utilities for macOS

struct ContactPhotoManager {
    /// Generate a thumbnail from image data
    static func generateThumbnail(from imageData: Data, size: CGFloat = 200) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }

        let targetSize = NSSize(width: size, height: size)
        let newImage = NSImage(size: targetSize)

        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        let aspectRatio = image.size.width / image.size.height
        var drawRect = NSRect(origin: .zero, size: targetSize)

        if aspectRatio > 1 {
            // Wider than tall - crop sides
            let newHeight = targetSize.height
            let newWidth = newHeight * aspectRatio
            drawRect = NSRect(
                x: -(newWidth - targetSize.width) / 2,
                y: 0,
                width: newWidth,
                height: newHeight
            )
        } else {
            // Taller than wide - crop top/bottom
            let newWidth = targetSize.width
            let newHeight = newWidth / aspectRatio
            drawRect = NSRect(
                x: 0,
                y: -(newHeight - targetSize.height) / 2,
                width: newWidth,
                height: newHeight
            )
        }

        image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()

        guard let tiffData = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }

        return jpegData
    }

    /// Open a file picker to select an image
    static func pickImage(completion: @escaping (Data?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a profile photo"
        panel.prompt = "Choose Photo"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }

            do {
                let data = try Data(contentsOf: url)
                completion(data)
            } catch {
                print("Failed to load image: \(error)")
                completion(nil)
            }
        }
    }
}

// MARK: - Photo View for macOS

struct ContactPhotoView: View {
    let photoData: Data?
    let thumbnailData: Data?
    let name: String
    let size: CGFloat
    let categoryColor: Color

    init(photoData: Data?, thumbnailData: Data?, name: String, size: CGFloat = 60, categoryColor: Color = .purple) {
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.name = name
        self.size = size
        self.categoryColor = categoryColor
    }

    var body: some View {
        Group {
            if let data = thumbnailData ?? photoData,
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback to initials
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.6), categoryColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials(from: name))
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

#elseif os(iOS)
import UIKit
import PhotosUI

// MARK: - Photo Utilities for iOS

struct ContactPhotoManager {
    /// Generate a thumbnail from image data
    static func generateThumbnail(from imageData: Data, size: CGFloat = 200) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }

        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        let thumbnailImage = renderer.image { context in
            let aspectRatio = image.size.width / image.size.height
            var drawRect = CGRect(origin: .zero, size: targetSize)

            if aspectRatio > 1 {
                // Wider than tall - crop sides
                let newHeight = targetSize.height
                let newWidth = newHeight * aspectRatio
                drawRect = CGRect(
                    x: -(newWidth - targetSize.width) / 2,
                    y: 0,
                    width: newWidth,
                    height: newHeight
                )
            } else {
                // Taller than wide - crop top/bottom
                let newWidth = targetSize.width
                let newHeight = newWidth / aspectRatio
                drawRect = CGRect(
                    x: 0,
                    y: -(newHeight - targetSize.height) / 2,
                    width: newWidth,
                    height: newHeight
                )
            }

            image.draw(in: drawRect)
        }

        return thumbnailImage.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Photo View for iOS

struct ContactPhotoView: View {
    let photoData: Data?
    let thumbnailData: Data?
    let name: String
    let size: CGFloat
    let categoryColor: Color

    init(photoData: Data?, thumbnailData: Data?, name: String, size: CGFloat = 60, categoryColor: Color = .purple) {
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.name = name
        self.size = size
        self.categoryColor = categoryColor
    }

    var body: some View {
        Group {
            if let data = thumbnailData ?? photoData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback to initials
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.6), categoryColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials(from: name))
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

// MARK: - iOS Photo Picker

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let uiImage = image as? UIImage {
                        self?.parent.imageData = uiImage.jpegData(compressionQuality: 0.9)
                    }
                }
            }
        }
    }
}

#endif
