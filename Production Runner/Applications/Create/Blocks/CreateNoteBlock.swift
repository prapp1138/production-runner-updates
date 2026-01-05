import SwiftUI

// MARK: - Note Block
struct CreateNoteBlock: View {
    let block: CreateBlockModel
    let onContentUpdate: ((inout CreateBlockModel) -> Void) -> Void

    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool

    private var content: NoteContent {
        block.noteContent ?? NoteContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            if isEditing {
                TextField("Title", text: Binding(
                    get: { content.title },
                    set: { newValue in
                        onContentUpdate { b in
                            var c = b.noteContent ?? NoteContent()
                            c.title = newValue
                            b.encodeContent(c)
                        }
                    }
                ))
                .font(.system(size: 14, weight: .semibold))
                .textFieldStyle(.plain)
                .focused($isFocused)
            } else if !content.title.isEmpty {
                Text(content.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }

            // Content
            if isEditing {
                TextEditor(text: Binding(
                    get: { content.content },
                    set: { newValue in
                        onContentUpdate { b in
                            var c = b.noteContent ?? NoteContent()
                            c.content = newValue
                            b.encodeContent(c)
                        }
                    }
                ))
                .font(.system(size: content.fontSize))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            } else {
                Text(content.content.isEmpty ? "Double-click to edit" : content.content)
                    .font(.system(size: content.fontSize))
                    .foregroundStyle(content.content.isEmpty ? .secondary : .primary)
                    .lineLimit(nil)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.yellow.opacity(0.1))
        .onTapGesture(count: 2) {
            isEditing = true
            isFocused = true
        }
        .onTapGesture {
            if isEditing {
                isEditing = false
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CreateNoteBlock_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CreateNoteBlock(
                block: {
                    var block = CreateBlockModel.createNote(at: .zero)
                    let content = NoteContent(title: "My Note", content: "This is some note content that can span multiple lines.")
                    block.encodeContent(content)
                    return block
                }(),
                onContentUpdate: { _ in }
            )
            .frame(width: 200, height: 150)

            CreateNoteBlock(
                block: .createNote(at: .zero),
                onContentUpdate: { _ in }
            )
            .frame(width: 200, height: 150)
        }
        .padding()
    }
}
#endif
