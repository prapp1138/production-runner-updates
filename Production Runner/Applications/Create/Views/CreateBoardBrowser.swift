import SwiftUI

// MARK: - Board Browser Sidebar
struct CreateBoardBrowser: View {
    @ObservedObject var boardViewModel: CreateBoardViewModel
    let onSelectBoard: (UUID) -> Void

    @State private var expandedBoardIDs: Set<UUID> = []
    @State private var editingBoardID: UUID?
    @State private var editingName: String = ""
    @State private var showNewBoardAlert: Bool = false
    @State private var newBoardName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Boards")
                    .font(.headline)
                Spacer()
                Button {
                    showNewBoardAlert = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Board")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search boards...", text: $boardViewModel.searchText)
                    .textFieldStyle(.plain)
                if !boardViewModel.searchText.isEmpty {
                    Button {
                        boardViewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Board List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(boardViewModel.filteredBoards) { board in
                        BoardRow(
                            board: board,
                            isSelected: boardViewModel.selectedBoardID == board.id,
                            isExpanded: expandedBoardIDs.contains(board.id),
                            hasChildren: boardViewModel.hasChildren(board.id),
                            isEditing: editingBoardID == board.id,
                            editingName: $editingName,
                            onSelect: {
                                boardViewModel.selectedBoardID = board.id
                                onSelectBoard(board.id)
                            },
                            onToggleExpand: {
                                if expandedBoardIDs.contains(board.id) {
                                    expandedBoardIDs.remove(board.id)
                                } else {
                                    expandedBoardIDs.insert(board.id)
                                }
                            },
                            onStartEdit: {
                                editingBoardID = board.id
                                editingName = board.name
                            },
                            onEndEdit: {
                                if !editingName.isEmpty {
                                    boardViewModel.renameBoard(board.id, to: editingName)
                                }
                                editingBoardID = nil
                                editingName = ""
                            },
                            onDelete: {
                                boardViewModel.deleteBoard(board.id)
                            },
                            onDuplicate: {
                                if let newID = boardViewModel.duplicateBoard(board.id) {
                                    onSelectBoard(newID)
                                }
                            },
                            onAddSubBoard: {
                                let newID = boardViewModel.createBoard(name: "New Sub-Board", parentID: board.id)
                                expandedBoardIDs.insert(board.id)
                                onSelectBoard(newID)
                            }
                        )

                        // Child boards
                        if expandedBoardIDs.contains(board.id) {
                            ForEach(boardViewModel.childBoards(of: board.id)) { child in
                                BoardRow(
                                    board: child,
                                    isSelected: boardViewModel.selectedBoardID == child.id,
                                    isExpanded: expandedBoardIDs.contains(child.id),
                                    hasChildren: boardViewModel.hasChildren(child.id),
                                    isEditing: editingBoardID == child.id,
                                    editingName: $editingName,
                                    indentLevel: 1,
                                    onSelect: {
                                        boardViewModel.selectedBoardID = child.id
                                        onSelectBoard(child.id)
                                    },
                                    onToggleExpand: {
                                        if expandedBoardIDs.contains(child.id) {
                                            expandedBoardIDs.remove(child.id)
                                        } else {
                                            expandedBoardIDs.insert(child.id)
                                        }
                                    },
                                    onStartEdit: {
                                        editingBoardID = child.id
                                        editingName = child.name
                                    },
                                    onEndEdit: {
                                        if !editingName.isEmpty {
                                            boardViewModel.renameBoard(child.id, to: editingName)
                                        }
                                        editingBoardID = nil
                                        editingName = ""
                                    },
                                    onDelete: {
                                        boardViewModel.deleteBoard(child.id)
                                    },
                                    onDuplicate: {
                                        if let newID = boardViewModel.duplicateBoard(child.id) {
                                            onSelectBoard(newID)
                                        }
                                    },
                                    onAddSubBoard: {
                                        let newID = boardViewModel.createBoard(name: "New Sub-Board", parentID: child.id)
                                        expandedBoardIDs.insert(child.id)
                                        onSelectBoard(newID)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
        .alert("New Board", isPresented: $showNewBoardAlert) {
            TextField("Board Name", text: $newBoardName)
            Button("Cancel", role: .cancel) {
                newBoardName = ""
            }
            Button("Create") {
                let id = boardViewModel.createBoard(name: newBoardName.isEmpty ? "Untitled Board" : newBoardName)
                onSelectBoard(id)
                newBoardName = ""
            }
        }
    }
}

// MARK: - Board Row
struct BoardRow: View {
    let board: CreateBoardModel
    let isSelected: Bool
    let isExpanded: Bool
    let hasChildren: Bool
    let isEditing: Bool
    @Binding var editingName: String
    var indentLevel: Int = 0

    let onSelect: () -> Void
    let onToggleExpand: () -> Void
    let onStartEdit: () -> Void
    let onEndEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onAddSubBoard: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // Indent
            if indentLevel > 0 {
                Spacer()
                    .frame(width: CGFloat(indentLevel) * 16)
            }

            // Expand/collapse chevron
            if hasChildren {
                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                    .frame(width: 16)
            }

            // Board icon
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .teal : .secondary)

            // Name
            if isEditing {
                TextField("Board Name", text: $editingName, onCommit: onEndEdit)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            } else {
                Text(board.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.teal.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Rename") {
                onStartEdit()
            }

            Button("Duplicate") {
                onDuplicate()
            }

            Button("Add Sub-Board") {
                onAddSubBoard()
            }

            Divider()

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .draggable(CreateBoardDragItem(id: board.id, name: board.name))
    }
}

// MARK: - Preview
#if DEBUG
struct CreateBoardBrowser_Previews: PreviewProvider {
    static var previews: some View {
        CreateBoardBrowser(
            boardViewModel: CreateBoardViewModel(),
            onSelectBoard: { _ in }
        )
        .frame(width: 250)
    }
}
#endif
