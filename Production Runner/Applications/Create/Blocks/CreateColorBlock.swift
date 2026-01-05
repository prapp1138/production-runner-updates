import SwiftUI

// MARK: - Color Block
struct CreateColorBlock: View {
    let block: CreateBlockModel
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @State private var isEditing: Bool = false

    private var content: ColorContent {
        block.colorContent ?? ColorContent()
    }

    private var displayColor: Color {
        Color(createHex: content.colorHex) ?? .white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Color swatch
            displayColor
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Label
            VStack(spacing: 2) {
                if !content.colorName.isEmpty {
                    Text(content.colorName)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                Text(content.colorHex.uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.03))
        }
        .onTapGesture(count: 2) {
            isEditing = true
        }
        .popover(isPresented: $isEditing) {
            colorEditor
        }
    }

    // MARK: - Color Editor
    private var colorEditor: some View {
        VStack(spacing: 16) {
            ColorPicker("Color", selection: Binding(
                get: { displayColor },
                set: { newColor in
                    onContentUpdate { b in
                        var c = b.colorContent ?? ColorContent()
                        c.colorHex = newColor.createToHex() ?? "#FFFFFF"
                        b.encodeContent(c)
                    }
                }
            ))

            TextField("Color Name", text: Binding(
                get: { content.colorName },
                set: { newValue in
                    onContentUpdate { b in
                        var c = b.colorContent ?? ColorContent()
                        c.colorName = newValue
                        b.encodeContent(c)
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)

            // Preset colors
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 4), count: 8), spacing: 4) {
                    ForEach(presetColors, id: \.hex) { preset in
                        Button {
                            onContentUpdate { b in
                                let c = ColorContent(colorHex: preset.hex, colorName: preset.name)
                                b.encodeContent(c)
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(createHex: preset.hex) ?? .clear)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                    }
                }
            }

            Button("Done") {
                isEditing = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 260)
    }

    // MARK: - Preset Colors
    private var presetColors: [(hex: String, name: String)] {
        [
            ("#FF0000", "Red"),
            ("#FF6B00", "Orange"),
            ("#FFD600", "Yellow"),
            ("#00C853", "Green"),
            ("#00BCD4", "Cyan"),
            ("#2196F3", "Blue"),
            ("#9C27B0", "Purple"),
            ("#E91E63", "Pink"),
            ("#795548", "Brown"),
            ("#607D8B", "Gray"),
            ("#000000", "Black"),
            ("#FFFFFF", "White"),
            ("#F44336", "Light Red"),
            ("#4CAF50", "Light Green"),
            ("#03A9F4", "Light Blue"),
            ("#FFC107", "Amber")
        ]
    }
}

// MARK: - Preview
#if DEBUG
struct CreateColorBlock_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            CreateColorBlock(
                block: {
                    var block = CreateBlockModel.createColor(at: .zero, hex: "#FF6B00")
                    let content = ColorContent(colorHex: "#FF6B00", colorName: "Orange")
                    block.encodeContent(content)
                    return block
                }(),
                onContentUpdate: { _ in }
            )
            .frame(width: 80, height: 80)

            CreateColorBlock(
                block: {
                    var block = CreateBlockModel.createColor(at: .zero, hex: "#2196F3")
                    let content = ColorContent(colorHex: "#2196F3", colorName: "Blue")
                    block.encodeContent(content)
                    return block
                }(),
                onContentUpdate: { _ in }
            )
            .frame(width: 80, height: 80)
        }
        .padding()
    }
}
#endif
