import SwiftUI

// MARK: - Inspector Panel
struct CreateInspector: View {
    @ObservedObject var viewModel: CreateCanvasViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let block = viewModel.selectedBlock {
                // Single block selected
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        blockTypeSection(block)
                        positionSection(block)
                        sizeSection(block)
                        appearanceSection(block)
                        contentSection(block)
                        actionsSection(block)
                    }
                    .padding(16)
                }
            } else if viewModel.selectedBlockIDs.count > 1 {
                // Multiple blocks selected
                multipleSelectionView
            } else {
                // No selection
                noSelectionView
            }

            Spacer(minLength: 0)
        }
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
    }

    // MARK: - Block Type Section
    @ViewBuilder
    private func blockTypeSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Type", icon: block.blockType.icon) {
            HStack {
                Image(systemName: block.blockType.icon)
                    .foregroundStyle(block.blockType.accentColor)
                Text(block.blockType.displayName)
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    // MARK: - Position Section
    @ViewBuilder
    private func positionSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Position", icon: "arrow.up.and.down.and.arrow.left.and.right") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("X")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("X", value: Binding(
                        get: { block.positionX },
                        set: { newValue in
                            viewModel.updateBlock(block.id) { $0.positionX = newValue }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Y")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Y", value: Binding(
                        get: { block.positionY },
                        set: { newValue in
                            viewModel.updateBlock(block.id) { $0.positionY = newValue }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Size Section
    @ViewBuilder
    private func sizeSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Size", icon: "arrow.up.left.and.arrow.down.right") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("W", value: Binding(
                        get: { block.width },
                        set: { newValue in
                            viewModel.updateBlock(block.id) { $0.width = max(50, newValue) }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Height")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("H", value: Binding(
                        get: { block.height },
                        set: { newValue in
                            viewModel.updateBlock(block.id) { $0.height = max(50, newValue) }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Appearance Section
    @ViewBuilder
    private func appearanceSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Appearance", icon: "paintbrush") {
            VStack(alignment: .leading, spacing: 8) {
                // Color picker
                HStack {
                    Text("Color")
                        .font(.subheadline)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: {
                            if let hex = block.colorHex {
                                return Color(createHex: hex) ?? .clear
                            }
                            return .clear
                        },
                        set: { newColor in
                            viewModel.updateBlock(block.id) { $0.colorHex = newColor.createToHex() }
                        }
                    ))
                    .labelsHidden()
                }

                // Lock toggle
                Toggle(isOn: Binding(
                    get: { block.isLocked },
                    set: { newValue in
                        viewModel.updateBlock(block.id) { $0.isLocked = newValue }
                    }
                )) {
                    Text("Locked")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Content Section
    @ViewBuilder
    private func contentSection(_ block: CreateBlockModel) -> some View {
        switch block.blockType {
        case .note:
            noteContentSection(block)
        case .todo:
            todoContentSection(block)
        case .color:
            colorContentSection(block)
        case .link:
            linkContentSection(block)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func noteContentSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Content", icon: "note.text") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: Binding(
                    get: { block.noteContent?.title ?? "" },
                    set: { newValue in
                        viewModel.updateBlock(block.id) { b in
                            var content = b.noteContent ?? NoteContent()
                            content.title = newValue
                            b.encodeContent(content)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)

                TextEditor(text: Binding(
                    get: { block.noteContent?.content ?? "" },
                    set: { newValue in
                        viewModel.updateBlock(block.id) { b in
                            var content = b.noteContent ?? NoteContent()
                            content.content = newValue
                            b.encodeContent(content)
                        }
                    }
                ))
                .frame(height: 100)
                .font(.system(size: 12))
                #if os(macOS)
                .background(Color(NSColor.textBackgroundColor))
                #endif
                .cornerRadius(6)
            }
        }
    }

    @ViewBuilder
    private func todoContentSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Tasks", icon: "checklist") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("List Title", text: Binding(
                    get: { block.todoContent?.title ?? "Tasks" },
                    set: { newValue in
                        viewModel.updateBlock(block.id) { b in
                            var content = b.todoContent ?? TodoContent()
                            content.title = newValue
                            b.encodeContent(content)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)

                ForEach(block.todoContent?.items ?? []) { item in
                    HStack {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                        Text(item.text)
                            .strikethrough(item.isCompleted)
                        Spacer()
                    }
                    .font(.caption)
                }

                Button("Add Task") {
                    viewModel.updateBlock(block.id) { b in
                        var content = b.todoContent ?? TodoContent()
                        content.items.append(TodoItem(text: "New Task"))
                        b.encodeContent(content)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private func colorContentSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Color Swatch", icon: "paintpalette") {
            VStack(alignment: .leading, spacing: 8) {
                ColorPicker("Color", selection: Binding(
                    get: {
                        if let hex = block.colorContent?.colorHex {
                            return Color(createHex: hex) ?? .white
                        }
                        return .white
                    },
                    set: { newColor in
                        viewModel.updateBlock(block.id) { b in
                            var content = b.colorContent ?? ColorContent()
                            content.colorHex = newColor.createToHex() ?? "#FFFFFF"
                            b.encodeContent(content)
                        }
                    }
                ))

                TextField("Color Name", text: Binding(
                    get: { block.colorContent?.colorName ?? "" },
                    set: { newValue in
                        viewModel.updateBlock(block.id) { b in
                            var content = b.colorContent ?? ColorContent()
                            content.colorName = newValue
                            b.encodeContent(content)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)

                if let hex = block.colorContent?.colorHex {
                    Text(hex)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func linkContentSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Link", icon: "link") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("URL", text: Binding(
                    get: { block.linkContent?.url ?? "" },
                    set: { newValue in
                        viewModel.updateBlock(block.id) { b in
                            var content = b.linkContent ?? LinkContent()
                            content.url = newValue
                            b.encodeContent(content)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Title", text: Binding(
                    get: { block.linkContent?.title ?? "" },
                    set: { newValue in
                        viewModel.updateBlock(block.id) { b in
                            var content = b.linkContent ?? LinkContent()
                            content.title = newValue
                            b.encodeContent(content)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Actions Section
    @ViewBuilder
    private func actionsSection(_ block: CreateBlockModel) -> some View {
        InspectorSection(title: "Actions", icon: "ellipsis.circle") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Duplicate") {
                        viewModel.duplicateBlock(block.id)
                    }
                    .buttonStyle(.bordered)

                    Button("Delete", role: .destructive) {
                        viewModel.deleteBlock(block.id)
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 8) {
                    Button("Bring to Front") {
                        viewModel.bringToFront(block.id)
                    }
                    .buttonStyle(.bordered)

                    Button("Send to Back") {
                        viewModel.sendToBack(block.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Multiple Selection View
    private var multipleSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.on.square")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("\(viewModel.selectedBlockIDs.count) blocks selected")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("Delete All", role: .destructive) {
                viewModel.deleteSelectedBlocks()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - No Selection View
    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Select a block to inspect")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Click on a block in the canvas to view and edit its properties")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Inspector Section
struct InspectorSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#if DEBUG
struct CreateInspector_Previews: PreviewProvider {
    static var previews: some View {
        CreateInspector(viewModel: CreateCanvasViewModel())
            .frame(width: 300)
    }
}
#endif
