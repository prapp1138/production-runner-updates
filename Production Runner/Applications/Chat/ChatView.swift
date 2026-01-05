import SwiftUI

// MARK: - Legacy Models (kept for UI components that still use them)
struct Role: Identifiable, Hashable {
    let id: UUID = UUID()
    var name: String
    var color: Color
}

struct UserProfile: Identifiable, Hashable {
    let id: UUID = UUID()
    var displayName: String
    var initials: String { String(displayName.split(separator: " ").compactMap { $0.first }.prefix(2)) }
    var roles: [Role] = []
    init(displayName: String, roles: [Role] = []) {
        self.displayName = displayName
        self.roles = roles
    }
}

// MARK: - Chat View (Firebase-powered)
struct ChatView: View {
    @StateObject private var chatService = ChatService.shared
    @State private var selectedChannel: FirestoreChannel?
    @State private var showMembersSheet = false
    @State private var showRightPanel = true
    @State private var showProfileSheet = false

    var body: some View {
        mainChatView
    }

    private var mainChatView: some View {
        HStack(spacing: 0) {
            // Main chat area on the left
            Group {
                if let channel = selectedChannel {
                    FirestoreChannelView(
                        channel: channel,
                        showMembers: $showMembersSheet,
                        showRightPanel: $showRightPanel
                    )
                } else {
                    EmptyState()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Channels sidebar on the right
            if showRightPanel {
                Divider()
                FirestoreSidebarView(
                    selectedChannel: $selectedChannel,
                    showProfileSheet: $showProfileSheet
                )
                .frame(width: 280)
                .transition(.move(edge: .trailing))
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileSheet()
                .frame(minWidth: 400, minHeight: 300)
        }
        .background(appBackground)
    }

    private var appBackground: some View {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }
}

// MARK: - Profile Sheet
private struct ProfileSheet: View {
    @ObservedObject private var chatService = ChatService.shared
    @State private var displayName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Profile")
                .font(.system(size: 22, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Enter your name", text: $displayName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Save") {
                    Task {
                        await chatService.updateDisplayName(displayName)
                        dismiss()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            Button(action: {
                do {
                    try AuthService.shared.signOut()
                    dismiss()
                } catch {
                    print("Failed to sign out: \(error)")
                }
            }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                    Text("Sign Out")
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .onAppear {
            displayName = chatService.currentUser?.displayName ?? ""
        }
    }
}

// MARK: - Firestore Sidebar
private struct FirestoreSidebarView: View {
    @ObservedObject private var chatService = ChatService.shared
    @Binding var selectedChannel: FirestoreChannel?
    @Binding var showProfileSheet: Bool

    @State private var search = ""
    @State private var showingNewChannel = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Production Chat")
                            .font(.system(size: 18, weight: .bold))
                        Text("\(chatService.channels.count) channels")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { showingNewChannel = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .customTooltip("New channel")
                }

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13, weight: .medium))
                    TextField("Search channels...", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), Color.accentColor.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .background(.ultraThinMaterial)
            )

            // Channels list
            List(selection: $selectedChannel) {
                Section {
                    if filteredChannels.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text("No channels yet")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Click + to create one")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(filteredChannels) { channel in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(channel.isPrivate ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: channel.isPrivate ? "lock.fill" : "number")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(channel.isPrivate ? Color.orange : Color.blue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.name)
                                        .font(.system(size: 14, weight: selectedChannel?.id == channel.id ? .semibold : .regular))
                                        .foregroundStyle(selectedChannel?.id == channel.id ? Color.accentColor : .primary)
                                    if let preview = channel.lastMessagePreview {
                                        Text(preview)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .tag(channel)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await chatService.deleteChannel(channel)
                                        if selectedChannel?.id == channel.id {
                                            selectedChannel = nil
                                        }
                                    }
                                } label: {
                                    Label("Delete Channel", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Channels")
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Spacer()
                        if !filteredChannels.isEmpty {
                            Text("\(filteredChannels.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedChannel) { newChannel in
                if let channel = newChannel {
                    chatService.listenToMessages(in: channel)
                }
            }
        }
        .sheet(isPresented: $showingNewChannel) {
            FirestoreNewChannelSheet()
                .frame(minWidth: 420)
        }
    }

    private var filteredChannels: [FirestoreChannel] {
        guard !search.isEmpty else { return chatService.channels }
        return chatService.channels.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
}

// MARK: - Firestore Channel View
private struct FirestoreChannelView: View {
    @ObservedObject private var chatService = ChatService.shared
    var channel: FirestoreChannel
    @Binding var showMembers: Bool
    @Binding var showRightPanel: Bool

    @State private var draft = ""
    @State private var editingMessage: FirestoreMessage?
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(channel.isPrivate ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: channel.isPrivate ? "lock.fill" : "number")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(channel.isPrivate ? Color.orange : Color.blue)
                    }
                    Text(channel.name)
                        .font(.system(size: 17, weight: .bold))
                }

                Divider().frame(height: 20)

                Button(action: { showMembers = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text("\(channel.memberIDs.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.purple.opacity(0.12)))
                    .foregroundStyle(Color.purple)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { withAnimation(.spring(response: 0.3)) { showRightPanel.toggle() } }) {
                    Image(systemName: showRightPanel ? "sidebar.trailing" : "sidebar.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.04), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .background(.ultraThinMaterial)
            )

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(chatService.messages) { msg in
                            FirestoreMessageRow(
                                message: msg,
                                isOwn: msg.authorID == chatService.currentUser?.id,
                                onEdit: msg.authorID == chatService.currentUser?.id ? { startEditing(msg) } : nil,
                                onDelete: msg.authorID == chatService.currentUser?.id ? {
                                    Task { await chatService.deleteMessage(msg) }
                                } : nil
                            )
                            .id(msg.id)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: chatService.messages.count) { _ in
                    if let lastID = chatService.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Composer
            VStack(spacing: 12) {
                if editingMessage != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                        Text("Editing message")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: cancelEditing) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.08))
                    )
                }

                HStack(spacing: 8) {
                    Button(action: { /* attach */ }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color.primary.opacity(0.04)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(draft.count)/1000")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )

                    TextEditor(text: $draft)
                        .frame(minHeight: 80, maxHeight: 140)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .padding(12)
                        .background(Color.clear)
                        .focused($isTextEditorFocused)

                    if draft.isEmpty {
                        Text(editingMessage != nil ? "Edit your message..." : "Message #\(channel.name)")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 14))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Spacer()
                    Button(action: send) {
                        HStack(spacing: 8) {
                            Image(systemName: editingMessage != nil ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(editingMessage != nil ? "Update" : "Send")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      ? Color.secondary.opacity(0.2)
                                      : (editingMessage != nil ? Color.orange : Color.accentColor))
                        )
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : Color.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    #if os(macOS)
                    .keyboardShortcut(.return, modifiers: [.command])
                    #endif
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.015))
        }
        .onAppear {
            isTextEditorFocused = true
        }
    }

    private func send() {
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        if let editing = editingMessage {
            Task {
                await chatService.editMessage(editing, newText: clean)
            }
            cancelEditing()
        } else {
            Task {
                await chatService.sendMessage(text: clean, in: channel)
            }
            draft = ""
        }
    }

    private func startEditing(_ message: FirestoreMessage) {
        editingMessage = message
        draft = message.text
        isTextEditorFocused = true
    }

    private func cancelEditing() {
        editingMessage = nil
        draft = ""
        isTextEditorFocused = true
    }
}

// MARK: - Firestore Message Row
private struct FirestoreMessageRow: View {
    var message: FirestoreMessage
    var isOwn: Bool
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(initials: String(message.authorName.split(separator: " ").compactMap { $0.first }.prefix(2)), size: 36)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(message.authorName)
                        .font(.system(size: 14, weight: .semibold))
                    TimestampView(date: message.timestamp)
                    if message.isEdited {
                        Text("(edited)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(message.text)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)

            if isHovered, isOwn {
                HStack(spacing: 6) {
                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(6)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Edit message")
                    }

                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                                .padding(6)
                                .background(Circle().fill(Color.red.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Delete message")
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isOwn ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.02))
        )
        .onHover { hovering in isHovered = hovering }
        .contextMenu {
            if isOwn {
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                if let onDelete = onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button(action: {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
                #else
                UIPasteboard.general.string = message.text
                #endif
            }) {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Firestore Thread Panel
private struct FirestoreThreadPanelView: View {
    @ObservedObject private var chatService = ChatService.shared
    var channel: FirestoreChannel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Channel Info")
                            .font(.system(size: 18, weight: .bold))
                        Text(channel.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(channel.isPrivate ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: channel.isPrivate ? "lock.fill" : "number")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(channel.isPrivate ? Color.orange : Color.blue)
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), Color.accentColor.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .background(.ultraThinMaterial)
            )

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Stats Section
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(icon: "bubble.left.and.bubble.right.fill", label: "Messages", value: "\(chatService.messages.count)", color: .blue)
                        StatRow(icon: "person.2.fill", label: "Members", value: "\(channel.memberIDs.count)", color: .purple)
                        StatRow(icon: channel.isPrivate ? "lock.fill" : "number", label: "Type", value: channel.isPrivate ? "Private" : "Public", color: channel.isPrivate ? .orange : .green)
                    }

                    Divider().padding(.vertical, 4)

                    // Cloud Sync Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.blue)
                            Text("Cloud Synced")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text("Messages sync in real-time across all your devices and team members.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.08))
                    )
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.systemGroupedBackground))
        #endif
    }

    private struct StatRow: View {
        let icon: String
        let label: String
        let value: String
        let color: Color

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - New Channel Sheet
private struct FirestoreNewChannelSheet: View {
    @ObservedObject private var chatService = ChatService.shared
    @State private var name: String = ""
    @State private var isPrivate: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create Channel")
                    .font(.system(size: 22, weight: .bold))
                Text("Start a new conversation space")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Channel Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("e.g., general, production", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }

                Toggle(isOn: $isPrivate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private Channel")
                            .font(.system(size: 14, weight: .medium))
                        Text("Only invited members can see and access")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )

                Spacer()

                Button(action: create) {
                    Text("Create Channel")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
                        )
                        .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color.white)
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 460)
    }

    private func create() {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        Task {
            _ = await chatService.createChannel(name: clean, isPrivate: isPrivate)
            dismiss()
        }
    }
}

// MARK: - UI Components
private struct Avatar: View {
    var initials: String
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
    }
}

private struct TimestampView: View {
    var date: Date
    var body: some View {
        Text(date.formatted(date: .omitted, time: .shortened))
            .foregroundStyle(.secondary)
            .font(.system(size: 11, weight: .medium))
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                Text("Production Chat")
                    .font(.system(size: 22, weight: .bold))
                Text("Select a channel or create a new one to start messaging")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                    Text("Messages sync in real-time with Firebase")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
