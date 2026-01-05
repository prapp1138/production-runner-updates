//
//  UndoRedoManager.swift
//  Production Runner
//
//  Created by Claude on 11/25/25.
//

import SwiftUI
import Combine

// MARK: - Generic Undo/Redo Manager
/// A reusable undo/redo manager that maintains a stack of states (up to 10 levels)
/// Each view can use its own instance with its specific state type
class UndoRedoManager<State>: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    private var undoStack: [State] = []
    private var redoStack: [State] = []
    private let maxHistorySize: Int

    init(maxHistorySize: Int = 10) {
        self.maxHistorySize = maxHistorySize
    }

    /// Save the current state before making a change
    func saveState(_ state: State) {
        undoStack.append(state)
        redoStack.removeAll()

        // Limit undo stack to maxHistorySize
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        updateFlags()
    }

    /// Undo to the previous state, returns the state to restore
    func undo(currentState: State) -> State? {
        guard !undoStack.isEmpty else { return nil }

        // Save current state to redo stack
        redoStack.append(currentState)

        // Limit redo stack to maxHistorySize
        if redoStack.count > maxHistorySize {
            redoStack.removeFirst()
        }

        // Restore previous state
        let previousState = undoStack.removeLast()
        updateFlags()
        return previousState
    }

    /// Redo to the next state, returns the state to restore
    func redo(currentState: State) -> State? {
        guard !redoStack.isEmpty else { return nil }

        // Save current state to undo stack
        undoStack.append(currentState)

        // Limit undo stack to maxHistorySize
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        // Restore next state
        let nextState = redoStack.removeLast()
        updateFlags()
        return nextState
    }

    /// Clear all history
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateFlags()
    }

    private func updateFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

// MARK: - Undo/Redo Responder (macOS)
#if os(macOS)
import AppKit

/// A transparent NSView that responds to Cmd+Z (undo) and Cmd+Shift+Z (redo) keyboard shortcuts
/// Also responds to the global prUndo and prRedo notifications from the menu
struct UndoRedoResponder: NSViewRepresentable {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void

    func makeNSView(context: Context) -> UndoRedoResponderView {
        let view = UndoRedoResponderView()
        view.canUndo = canUndo
        view.canRedo = canRedo
        view.onUndo = onUndo
        view.onRedo = onRedo
        return view
    }

    func updateNSView(_ nsView: UndoRedoResponderView, context: Context) {
        nsView.canUndo = canUndo
        nsView.canRedo = canRedo
        nsView.onUndo = onUndo
        nsView.onRedo = onRedo
    }

    class UndoRedoResponderView: NSView {
        var canUndo: Bool = false
        var canRedo: Bool = false
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?

        private var undoObserver: NSObjectProtocol?
        private var redoObserver: NSObjectProtocol?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupNotificationObservers()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupNotificationObservers()
        }

        private func setupNotificationObservers() {
            undoObserver = NotificationCenter.default.addObserver(
                forName: .prUndo,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.performUndo()
            }

            redoObserver = NotificationCenter.default.addObserver(
                forName: .prRedo,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.performRedo()
            }
        }

        deinit {
            if let observer = undoObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = redoObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        override var acceptsFirstResponder: Bool { true }

        override func responds(to aSelector: Selector!) -> Bool {
            if aSelector == #selector(undo(_:)) {
                return canUndo
            } else if aSelector == #selector(redo(_:)) {
                return canRedo
            }
            return super.responds(to: aSelector)
        }

        @objc func undo(_ sender: Any?) {
            performUndo()
        }

        @objc func redo(_ sender: Any?) {
            performRedo()
        }

        private func performUndo() {
            if canUndo {
                onUndo?()
            }
        }

        private func performRedo() {
            if canRedo {
                onRedo?()
            }
        }
    }
}

// MARK: - Edit Commands Responder (macOS)
/// A transparent NSView that responds to edit commands (Cut, Copy, Paste, Delete, Select All)
/// and forwards them via notifications
struct EditCommandsResponder: NSViewRepresentable {
    let canCut: Bool
    let canCopy: Bool
    let canPaste: Bool
    let canDelete: Bool
    let canSelectAll: Bool
    let onCut: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onDelete: () -> Void
    let onSelectAll: () -> Void

    func makeNSView(context: Context) -> EditCommandsResponderView {
        let view = EditCommandsResponderView()
        updateView(view)
        return view
    }

    func updateNSView(_ nsView: EditCommandsResponderView, context: Context) {
        updateView(nsView)
    }

    private func updateView(_ view: EditCommandsResponderView) {
        view.canCut = canCut
        view.canCopy = canCopy
        view.canPaste = canPaste
        view.canDelete = canDelete
        view.canSelectAll = canSelectAll
        view.onCut = onCut
        view.onCopy = onCopy
        view.onPaste = onPaste
        view.onDelete = onDelete
        view.onSelectAll = onSelectAll
    }

    class EditCommandsResponderView: NSView {
        var canCut: Bool = false
        var canCopy: Bool = false
        var canPaste: Bool = false
        var canDelete: Bool = false
        var canSelectAll: Bool = false
        var onCut: (() -> Void)?
        var onCopy: (() -> Void)?
        var onPaste: (() -> Void)?
        var onDelete: (() -> Void)?
        var onSelectAll: (() -> Void)?

        private var cutObserver: NSObjectProtocol?
        private var copyObserver: NSObjectProtocol?
        private var pasteObserver: NSObjectProtocol?
        private var deleteObserver: NSObjectProtocol?
        private var selectAllObserver: NSObjectProtocol?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupNotificationObservers()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupNotificationObservers()
        }

        private func setupNotificationObservers() {
            cutObserver = NotificationCenter.default.addObserver(
                forName: .prCut, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canCut == true { self?.onCut?() }
            }

            copyObserver = NotificationCenter.default.addObserver(
                forName: .prCopy, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canCopy == true { self?.onCopy?() }
            }

            pasteObserver = NotificationCenter.default.addObserver(
                forName: .prPaste, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canPaste == true { self?.onPaste?() }
            }

            deleteObserver = NotificationCenter.default.addObserver(
                forName: .prDelete, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canDelete == true { self?.onDelete?() }
            }

            selectAllObserver = NotificationCenter.default.addObserver(
                forName: .prSelectAll, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canSelectAll == true { self?.onSelectAll?() }
            }
        }

        deinit {
            [cutObserver, copyObserver, pasteObserver, deleteObserver, selectAllObserver]
                .compactMap { $0 }
                .forEach { NotificationCenter.default.removeObserver($0) }
        }

        override var acceptsFirstResponder: Bool { true }

        override func responds(to aSelector: Selector!) -> Bool {
            if aSelector == #selector(NSText.cut(_:)) { return canCut }
            if aSelector == #selector(NSText.copy(_:)) { return canCopy }
            if aSelector == #selector(NSText.paste(_:)) { return canPaste }
            if aSelector == #selector(deleteBackward(_:)) { return canDelete }
            if aSelector == #selector(NSText.selectAll(_:)) { return canSelectAll }
            return super.responds(to: aSelector)
        }

        @objc func cut(_ sender: Any?) {
            if canCut { onCut?() }
        }

        @objc func copy(_ sender: Any?) {
            if canCopy { onCopy?() }
        }

        @objc func paste(_ sender: Any?) {
            if canPaste { onPaste?() }
        }

        @objc override func deleteBackward(_ sender: Any?) {
            if canDelete { onDelete?() }
        }

        @objc override func selectAll(_ sender: Any?) {
            if canSelectAll { onSelectAll?() }
        }
    }
}
#endif

// MARK: - Undo/Redo Responder (iOS)
#if os(iOS)
import UIKit

/// A UIViewRepresentable that handles undo/redo gestures on iOS
/// Uses iOS native undo manager and shake-to-undo gesture
struct UndoRedoResponder: UIViewRepresentable {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void

    func makeUIView(context: Context) -> UndoRedoResponderViewiOS {
        let view = UndoRedoResponderViewiOS()
        view.canUndo = canUndo
        view.canRedo = canRedo
        view.onUndo = onUndo
        view.onRedo = onRedo
        return view
    }

    func updateUIView(_ uiView: UndoRedoResponderViewiOS, context: Context) {
        uiView.canUndo = canUndo
        uiView.canRedo = canRedo
        uiView.onUndo = onUndo
        uiView.onRedo = onRedo
    }

    class UndoRedoResponderViewiOS: UIView {
        var canUndo: Bool = false
        var canRedo: Bool = false
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?

        private var undoObserver: NSObjectProtocol?
        private var redoObserver: NSObjectProtocol?

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupNotificationObservers()
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupNotificationObservers()
            backgroundColor = .clear
        }

        private func setupNotificationObservers() {
            // Listen for undo/redo notifications
            undoObserver = NotificationCenter.default.addObserver(
                forName: .prUndo,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.performUndo()
            }

            redoObserver = NotificationCenter.default.addObserver(
                forName: .prRedo,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.performRedo()
            }
        }

        deinit {
            if let observer = undoObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = redoObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        override var canBecomeFirstResponder: Bool { true }

        private func performUndo() {
            if canUndo {
                onUndo?()
            }
        }

        private func performRedo() {
            if canRedo {
                onRedo?()
            }
        }
    }
}

/// A UIViewRepresentable that handles edit commands on iOS
/// Uses iOS clipboard and standard editing methods
struct EditCommandsResponder: UIViewRepresentable {
    let canCut: Bool
    let canCopy: Bool
    let canPaste: Bool
    let canDelete: Bool
    let canSelectAll: Bool
    let onCut: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onDelete: () -> Void
    let onSelectAll: () -> Void

    func makeUIView(context: Context) -> EditCommandsResponderViewiOS {
        let view = EditCommandsResponderViewiOS()
        updateView(view)
        return view
    }

    func updateUIView(_ uiView: EditCommandsResponderViewiOS, context: Context) {
        updateView(uiView)
    }

    private func updateView(_ view: EditCommandsResponderViewiOS) {
        view.canCut = canCut
        view.canCopy = canCopy
        view.canPaste = canPaste
        view.canDelete = canDelete
        view.canSelectAll = canSelectAll
        view.onCut = onCut
        view.onCopy = onCopy
        view.onPaste = onPaste
        view.onDelete = onDelete
        view.onSelectAll = onSelectAll
    }

    class EditCommandsResponderViewiOS: UIView {
        var canCut: Bool = false
        var canCopy: Bool = false
        var canPaste: Bool = false
        var canDelete: Bool = false
        var canSelectAll: Bool = false
        var onCut: (() -> Void)?
        var onCopy: (() -> Void)?
        var onPaste: (() -> Void)?
        var onDelete: (() -> Void)?
        var onSelectAll: (() -> Void)?

        private var cutObserver: NSObjectProtocol?
        private var copyObserver: NSObjectProtocol?
        private var pasteObserver: NSObjectProtocol?
        private var deleteObserver: NSObjectProtocol?
        private var selectAllObserver: NSObjectProtocol?

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupNotificationObservers()
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupNotificationObservers()
            backgroundColor = .clear
        }

        private func setupNotificationObservers() {
            cutObserver = NotificationCenter.default.addObserver(
                forName: .prCut, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canCut == true { self?.onCut?() }
            }

            copyObserver = NotificationCenter.default.addObserver(
                forName: .prCopy, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canCopy == true { self?.onCopy?() }
            }

            pasteObserver = NotificationCenter.default.addObserver(
                forName: .prPaste, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canPaste == true { self?.onPaste?() }
            }

            deleteObserver = NotificationCenter.default.addObserver(
                forName: .prDelete, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canDelete == true { self?.onDelete?() }
            }

            selectAllObserver = NotificationCenter.default.addObserver(
                forName: .prSelectAll, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.canSelectAll == true { self?.onSelectAll?() }
            }
        }

        deinit {
            [cutObserver, copyObserver, pasteObserver, deleteObserver, selectAllObserver]
                .compactMap { $0 }
                .forEach { NotificationCenter.default.removeObserver($0) }
        }

        override var canBecomeFirstResponder: Bool { true }

        // iOS UIResponderStandardEditActions
        override func cut(_ sender: Any?) {
            if canCut { onCut?() }
        }

        override func copy(_ sender: Any?) {
            if canCopy { onCopy?() }
        }

        override func paste(_ sender: Any?) {
            if canPaste { onPaste?() }
        }

        override func delete(_ sender: Any?) {
            if canDelete { onDelete?() }
        }

        override func selectAll(_ sender: Any?) {
            if canSelectAll { onSelectAll?() }
        }

        // Enable standard edit menu actions
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            switch action {
            case #selector(cut(_:)): return canCut
            case #selector(copy(_:)): return canCopy
            case #selector(paste(_:)): return canPaste
            case #selector(delete(_:)): return canDelete
            case #selector(selectAll(_:)): return canSelectAll
            default: return super.canPerformAction(action, withSender: sender)
            }
        }
    }
}
#endif

// MARK: - View Extension for Easy Undo/Redo Setup
extension View {
    /// Adds undo/redo keyboard shortcut support to a view
    #if os(macOS)
    func undoRedoSupport(
        canUndo: Bool,
        canRedo: Bool,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void
    ) -> some View {
        self.background(
            UndoRedoResponder(
                canUndo: canUndo,
                canRedo: canRedo,
                onUndo: onUndo,
                onRedo: onRedo
            )
        )
    }

    /// Adds edit command support (cut, copy, paste, delete, select all) to a view
    func editCommandsSupport(
        canCut: Bool = false,
        canCopy: Bool = false,
        canPaste: Bool = false,
        canDelete: Bool = false,
        canSelectAll: Bool = false,
        onCut: @escaping () -> Void = {},
        onCopy: @escaping () -> Void = {},
        onPaste: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {},
        onSelectAll: @escaping () -> Void = {}
    ) -> some View {
        self.background(
            EditCommandsResponder(
                canCut: canCut,
                canCopy: canCopy,
                canPaste: canPaste,
                canDelete: canDelete,
                canSelectAll: canSelectAll,
                onCut: onCut,
                onCopy: onCopy,
                onPaste: onPaste,
                onDelete: onDelete,
                onSelectAll: onSelectAll
            )
        )
    }
    #endif

    #if os(iOS)
    /// Adds undo/redo support to a view (iOS)
    /// Uses notifications for undo/redo actions
    func undoRedoSupport(
        canUndo: Bool,
        canRedo: Bool,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void
    ) -> some View {
        self.background(
            UndoRedoResponder(
                canUndo: canUndo,
                canRedo: canRedo,
                onUndo: onUndo,
                onRedo: onRedo
            )
        )
    }

    /// Adds edit command support (cut, copy, paste, delete, select all) to a view (iOS)
    func editCommandsSupport(
        canCut: Bool = false,
        canCopy: Bool = false,
        canPaste: Bool = false,
        canDelete: Bool = false,
        canSelectAll: Bool = false,
        onCut: @escaping () -> Void = {},
        onCopy: @escaping () -> Void = {},
        onPaste: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {},
        onSelectAll: @escaping () -> Void = {}
    ) -> some View {
        self.background(
            EditCommandsResponder(
                canCut: canCut,
                canCopy: canCopy,
                canPaste: canPaste,
                canDelete: canDelete,
                canSelectAll: canSelectAll,
                onCut: onCut,
                onCopy: onCopy,
                onPaste: onPaste,
                onDelete: onDelete,
                onSelectAll: onSelectAll
            )
        )
    }
    #endif
}
