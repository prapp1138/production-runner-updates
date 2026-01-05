import SwiftUI
import CoreData

// MARK: - Budget View Type Enum

enum BudgetViewType: String, CaseIterable, Identifiable {
    case lineItems = "Line Items"
    case transactions = "Transactions"
    case costTracking = "Cost Tracking"
    case costToDate = "Cost of Scene"
    case payroll = "Payroll"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .lineItems: return "list.bullet.rectangle"
        case .transactions: return "doc.text"
        case .costTracking: return "chart.line.uptrend.xyaxis"
        case .costToDate: return "dollarsign.circle"
        case .payroll: return "person.2.fill"
        }
    }
}

struct BudgetView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: BudgetViewModel
    @StateObject private var stripStore: StripStore
    @State private var showingAddItem = false
    @State private var showingRateCards = false
    @State private var showingTemplateSelection = false
    @State private var showingNewVersionDialog = false
    @State private var showingRenameVersionDialog = false
    @State private var showingDeleteVersionAlert = false
    @State private var newVersionName = ""
    @State private var versionToRename: BudgetVersion?
    @State private var versionToDelete: BudgetVersion?
    @State private var selectedItem: BudgetLineItem?
    @State private var selectedItemID: UUID?
    @State private var showInspector = true
    @State private var selectedView: BudgetViewType = .lineItems
    @State private var showingClearAllAlert = false
    @State private var showingAddTransactionForm = false
    @State private var editingTransactionID: UUID?
    @State private var showBudgetSidebar = true
    @State private var showingCategoryManager = false
    @State private var showingSaveTemplateSheet = false

    // Cost of Scene state
    @State private var selectedSceneID: NSManagedObjectID? = nil
    @State private var expandedSceneIDs: Set<NSManagedObjectID> = []
    @State private var costOfSceneSearchText: String = ""

    // Undo/Redo state
    @StateObject private var undoRedoManager = UndoRedoManager<[BudgetLineItem]>(maxHistorySize: 10)

    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: BudgetViewModel(context: context))

        // Initialize StripStore with project
        let project: ProjectEntity = {
            let req = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
            req.fetchLimit = 1
            if let fetched = try? context.fetch(req), let existing = fetched.first {
                return existing
            }
            return ProjectEntity(context: context)
        }()
        _stripStore = StateObject(wrappedValue: StripStore(context: context, project: project))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Unified Header
                unifiedHeaderToolbar

                Divider()

                // Budget Summary Header
                budgetSummaryHeader

                Divider()

                // View Picker
                viewPicker

                Divider()

                // Main content with sidebar
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left sidebar with section navigation (25% width)
                        if showBudgetSidebar {
                            sectionNavigationPane
                                .frame(width: geometry.size.width * 0.25)

                            Divider()
                        }

                        // Content based on selected view
                        Group {
                            switch selectedView {
                            case .lineItems:
                                lineItemsFullView
                            case .transactions:
                                transactionsFullView
                            case .costTracking:
                                costTrackingFullView
                            case .costToDate:
                                costToDateFullView
                            case .payroll:
                                payrollFullView
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddBudgetItemView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingRateCards) {
                RateCardsView(viewModel: viewModel)
                    .frame(minWidth: 600, idealWidth: 650, maxWidth: 800)
            }
            .sheet(isPresented: $showingTemplateSelection) {
                TemplateSelectionView(viewModel: viewModel)
                    .frame(minWidth: 600, idealWidth: 650, maxWidth: 800)
            }
            .sheet(isPresented: $showingNewVersionDialog) {
                NewVersionDialog(viewModel: viewModel)
                    .frame(minWidth: 500, idealWidth: 550, maxWidth: 600, minHeight: 400, idealHeight: 450, maxHeight: 500)
            }
            .sheet(isPresented: $showingRenameVersionDialog) {
                if let version = versionToRename {
                    RenameVersionDialog(viewModel: viewModel, version: version, isPresented: $showingRenameVersionDialog)
                }
            }
            .sheet(isPresented: $showingCategoryManager) {
                BudgetCategoryManagerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSaveTemplateSheet) {
                SaveCustomTemplateView(viewModel: viewModel)
            }
            .alert("Delete Budget Version", isPresented: $showingDeleteVersionAlert, presenting: versionToDelete) { version in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteVersion(version)
                }
            } message: { version in
                Text("Are you sure you want to delete '\(version.name)'? This action cannot be undone.")
            }
            .alert("Clear All Budget Items", isPresented: $showingClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllBudgetItems()
                }
            } message: {
                Text("Are you sure you want to clear all budget items? This will delete all line items in the current version. This action cannot be undone.")
            }
            #if os(macOS)
            .undoRedoSupport(
                canUndo: undoRedoManager.canUndo,
                canRedo: undoRedoManager.canRedo,
                onUndo: performUndo,
                onRedo: performRedo
            )
            .onReceive(NotificationCenter.default.publisher(for: .prDelete)) { _ in
                if let item = selectedItem {
                    deleteItem(item)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prSelectAll)) { _ in
                // Budget view doesn't have multi-select in the traditional sense
            }
            .onReceive(NotificationCenter.default.publisher(for: .prCut)) { _ in
                performCutCommand()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prCopy)) { _ in
                performCopyCommand()
            }
            .onReceive(NotificationCenter.default.publisher(for: .prPaste)) { _ in
                performPasteCommand()
            }
            #endif
        }
    }

    // MARK: - Undo/Redo Functions
    #if os(macOS)
    private func saveToUndoStack() {
        undoRedoManager.saveState(viewModel.lineItems)
    }

    private func performUndo() {
        guard let previousState = undoRedoManager.undo(currentState: viewModel.lineItems) else { return }
        restoreLineItems(previousState)
    }

    private func performRedo() {
        guard let nextState = undoRedoManager.redo(currentState: viewModel.lineItems) else { return }
        restoreLineItems(nextState)
    }

    private func restoreLineItems(_ items: [BudgetLineItem]) {
        // Clear current items and restore from state
        viewModel.lineItems = items
        // You'd also need to sync with Core Data here if the viewModel persists to Core Data
    }

    private func deleteItem(_ item: BudgetLineItem) {
        saveToUndoStack()
        viewModel.deleteLineItem(item)
    }

    // MARK: - Clipboard Operations (Cut, Copy, Paste)

    private func performCutCommand() {
        // Check if text field has focus - let system handle cut
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text cut
            }
        }
        // No clipboard support for budget items yet
    }

    private func performCopyCommand() {
        // Check if text field has focus - let system handle copy
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text copy
            }
        }
        // No clipboard support for budget items yet
    }

    private func performPasteCommand() {
        // Check if text field has focus - let system handle paste
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView || firstResponder is NSTextField {
                return // Let system handle text paste
            }
        }
        // No clipboard support for budget items yet
    }
    #endif

    // MARK: - Unified Header Toolbar
    
    private var unifiedHeaderToolbar: some View {
        VStack(spacing: 0) {
            // Single merged toolbar row
            HStack(spacing: 16) {
                // Left: Version dropdown
                versionDropdown

                Divider()
                    .frame(height: 20)

                // Action buttons
                actionButtonsGroup

                Spacer()

                // Search bar
                searchBarView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    private var versionDropdown: some View {
        Menu {
            // Versions Section
            Section("Budget Versions") {
                ForEach(viewModel.budgetVersions) { version in
                    Button(action: {
                        viewModel.selectVersion(version)
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.caption)
                            Text(version.name)
                            Spacer()
                            if version.id == viewModel.selectedVersion?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            Divider()

            // Actions Section
            Section {
                Button(action: {
                    showingNewVersionDialog = true
                }) {
                    Label("New Budget Version", systemImage: "plus.circle")
                }

                if let selectedVersion = viewModel.selectedVersion {
                    Button(action: {
                        viewModel.duplicateVersion(selectedVersion)
                    }) {
                        Label("Duplicate Current", systemImage: "doc.on.doc")
                    }

                    Button(action: {
                        versionToRename = selectedVersion
                        showingRenameVersionDialog = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }

                    if viewModel.budgetVersions.count > 1 {
                        Divider()

                        Button(role: .destructive, action: {
                            versionToDelete = selectedVersion
                            showingDeleteVersionAlert = true
                        }) {
                            Label("Delete Version", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                // Version icon with background
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Budget")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(viewModel.selectedVersion?.name ?? "No Version")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .frame(maxWidth: 220)
        .menuStyle(.borderlessButton)
    }
    
    private var actionButtonsGroup: some View {
        HStack(spacing: 8) {
            // Template button
            Button {
                showingTemplateSelection = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.plus")
                    Text("Template")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.blue.gradient)
                )
            }
            .buttonStyle(BorderlessButtonStyle())

            // Save Template button (only show if budget has items)
            if !viewModel.lineItems.isEmpty {
                Button {
                    showingSaveTemplateSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Template")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.orange.gradient)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .customTooltip("Save current budget as a reusable template")
            }

            Spacer()

            // Rates button
            Button {
                showingRateCards = true
            } label: {
                Image(systemName: "creditcard")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            .buttonStyle(BorderlessButtonStyle())
            .customTooltip("Rates")

            // Duplicate button
            Button {
                if let version = viewModel.selectedVersion {
                    viewModel.duplicateVersion(version)
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            .buttonStyle(BorderlessButtonStyle())
            .customTooltip("Duplicate Version")

            // Clear All button
            Button {
                showingClearAllAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            .buttonStyle(BorderlessButtonStyle())
            .customTooltip("Clear All Items")
        }
        .layoutPriority(1)
    }
    

    private var categoryTabsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BudgetCategory.allCases) { category in
                    CategoryTab(
                        category: category,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
            }
        }
    }
    
    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search items...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(minWidth: 120, idealWidth: 180, maxWidth: 250)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private var inspectorToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showInspector.toggle()
            }
        } label: {
            Image(systemName: showInspector ? "sidebar.right" : "sidebar.left")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
    
    // MARK: - Section Navigation Pane

    private var sectionNavigationPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Categories Header
            HStack {
                Text("Categories")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingCategoryManager = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .customTooltip("Manage Categories")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Category List - Using custom categories (synced with header)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.customCategories) { category in
                        CustomCategoryNavigationRow(
                            category: category,
                            isSelected: viewModel.selectedCustomCategoryID == category.id,
                            amount: viewModel.customCategorySummary.amount(for: category.id),
                            itemCount: viewModel.itemCount(for: category)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedCustomCategoryID = category.id
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                Divider()
                    .padding(.vertical, 8)

                // Sections for selected category
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Sections")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()

                        Button {
                            showingAddItem = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .customTooltip("Add Item to Category")
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                    let sections = uniqueSectionsForCustomCategory()

                    if sections.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                                Text("No sections")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(sections, id: \.self) { section in
                            SectionNavigationRow(
                                sectionName: section,
                                itemCount: itemCountForCustomCategory(section: section),
                                total: sectionTotalForCustomCategory(section: section)
                            ) {
                                scrollToSection(section)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private func uniqueSectionsForCustomCategory() -> [String] {
        guard let categoryID = viewModel.selectedCustomCategoryID,
              let category = viewModel.customCategories.first(where: { $0.id == categoryID }) else {
            return []
        }

        // Only match items where category matches the custom category name
        let items = viewModel.lineItems.filter { item in
            item.category == category.name
        }

        let sections = items.compactMap { $0.section }.filter { !$0.isEmpty }
        return Array(Set(sections)).sorted()
    }

    private func itemCountForCustomCategory(section: String) -> Int {
        guard let categoryID = viewModel.selectedCustomCategoryID,
              let category = viewModel.customCategories.first(where: { $0.id == categoryID }) else {
            return 0
        }

        return viewModel.lineItems.filter { item in
            item.category == category.name && item.section == section
        }.count
    }

    private func sectionTotalForCustomCategory(section: String) -> Double {
        guard let categoryID = viewModel.selectedCustomCategoryID,
              let category = viewModel.customCategories.first(where: { $0.id == categoryID }) else {
            return 0
        }

        return viewModel.lineItems.filter { item in
            item.category == category.name && item.section == section
        }.reduce(0) { $0 + $1.total }
    }

    private func categoryItemCount(for category: BudgetCategory) -> Int {
        return viewModel.lineItems.filter { item in
            guard let itemCategory = BudgetCategory.allCases.first(where: { $0.rawValue == item.category }) else {
                return false
            }
            return itemCategory == category
        }.count
    }

    // Helper functions for section navigation
    private func uniqueSections(for category: BudgetCategory) -> [String] {
        let items = viewModel.lineItems.filter { item in
            guard let itemCategory = BudgetCategory.allCases.first(where: { $0.rawValue == item.category }) else {
                return false
            }
            return itemCategory == category
        }

        let sections = items.compactMap { $0.section }.filter { !$0.isEmpty }
        return Array(Set(sections)).sorted()
    }

    private func itemCount(for section: String, in category: BudgetCategory) -> Int {
        return viewModel.lineItems.filter { item in
            guard let itemCategory = BudgetCategory.allCases.first(where: { $0.rawValue == item.category }) else {
                return false
            }
            return itemCategory == category && item.section == section
        }.count
    }

    private func sectionTotal(for section: String, in category: BudgetCategory) -> Double {
        return viewModel.lineItems.filter { item in
            guard let itemCategory = BudgetCategory.allCases.first(where: { $0.rawValue == item.category }) else {
                return false
            }
            return itemCategory == category && item.section == section
        }.reduce(0) { $0 + $1.total }
    }

    private func scrollToSection(_ section: String) {
        // This will be implemented with ScrollViewReader in lineItemsFullView
        // For now, just a placeholder
    }

    // MARK: - Budget Summary Header

    private var budgetSummaryHeader: some View {
        HStack(spacing: 12) {
            // Total Budget Card (on the left)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("Total Budget")
                        .font(.caption)
                        .foregroundStyle(.blue.opacity(0.8))
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Use short film summary if that template is active
                    let totalAmount = viewModel.currentTemplateType == .shortFilm
                        ? viewModel.shortFilmSummary.totalBudget
                        : viewModel.summary.totalBudget

                    Text(totalAmount.asCurrency())
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    // Item count
                    if viewModel.lineItems.count > 0 {
                        Text("\(viewModel.lineItems.count) line items")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1)
            )

            // Category Breakdown - Using custom categories (synced with sidebar)
            ForEach(viewModel.customCategories) { category in
                CustomCategorySummaryCard(
                    category: category,
                    amount: viewModel.customCategorySummary.amount(for: category.id),
                    percentage: viewModel.customCategorySummary.percentage(for: category.id),
                    isSelected: viewModel.selectedCustomCategoryID == category.id
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedCustomCategoryID = category.id
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - View Picker

    private var viewPicker: some View {
        HStack(spacing: 8) {
            // Section navigation toggle (moved to left)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showBudgetSidebar.toggle()
                }
            } label: {
                Image(systemName: showBudgetSidebar ? "sidebar.leading" : "sidebar.leading")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(showBudgetSidebar ? .primary : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(showBudgetSidebar ? Color.primary.opacity(0.08) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .customTooltip("Toggle Section Navigator")

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            ForEach(BudgetViewType.allCases) { viewType in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedView = viewType
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewType.icon)
                            .font(.caption)
                        Text(viewType.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedView == viewType ? .semibold : .regular)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(selectedView == viewType ? Color.primary.opacity(0.1) : Color.clear)
                    )
                    .foregroundStyle(selectedView == viewType ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Inspector toggle (only show on Line Items view)
            if selectedView == .lineItems {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showInspector.toggle()
                    }
                } label: {
                    Image(systemName: showInspector ? "sidebar.trailing" : "sidebar.trailing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(showInspector ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(showInspector ? Color.primary.opacity(0.08) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .customTooltip("Toggle Inspector")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Line Items Full View

    private var lineItemsFullView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Center: Line Items List
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.filteredLineItems.isEmpty {
                        emptyStateView
                    } else {
                        budgetListView
                    }
                }
                .frame(width: showInspector ? geometry.size.width * (2.0/3.0) : geometry.size.width)

                // Right: Item Details (Inspector)
                if showInspector {
                    Divider()
                    budgetInspector
                        .frame(width: geometry.size.width * (1.0/3.0))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Transactions Full View

    private var transactionsFullView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Transactions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Spacer()

                Button {
                    withAnimation {
                        showingAddTransactionForm.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showingAddTransactionForm ? "chevron.down.circle.fill" : "plus.circle.fill")
                        Text(showingAddTransactionForm ? "Cancel" : "Add Transaction")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(showingAddTransactionForm ? Color.gray.gradient : Color.mint.gradient)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 60)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Split view: Transaction list (70%) and Categories (30%)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left: Transaction List (70%)
                    transactionsList
                        .frame(width: geometry.size.width * 0.7)

                    Divider()

                    // Right: Categories (30%)
                    transactionCategories
                        .frame(width: geometry.size.width * 0.3)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        VStack(spacing: 0) {
            // Inline Add Transaction Form
            if showingAddTransactionForm {
                InlineAddTransactionForm(
                    viewModel: viewModel,
                    isShowing: $showingAddTransactionForm
                )
                .transition(.move(edge: .top).combined(with: .opacity))

                Divider()
            }

            // Transaction List or Empty State
            Group {
                if viewModel.transactions.isEmpty && !showingAddTransactionForm {
                    // Empty State
                    ScrollView {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 64))
                                .foregroundStyle(.tertiary)

                            Text("No transactions")
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            Text("Add your first transaction to start tracking budget changes")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 80)
                    }
                } else {
                    // Transaction List
                    List {
                        ForEach(viewModel.transactions.sorted(by: { $0.date > $1.date })) { transaction in
                            VStack(spacing: 0) {
                                // Transaction Row
                                TransactionRow(
                                    transaction: transaction,
                                    isExpanded: editingTransactionID == transaction.id,
                                    onTap: {
                                        withAnimation {
                                            if editingTransactionID == transaction.id {
                                                editingTransactionID = nil
                                            } else {
                                                editingTransactionID = transaction.id
                                                showingAddTransactionForm = false
                                            }
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteTransaction(transaction)
                                        if editingTransactionID == transaction.id {
                                            editingTransactionID = nil
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

                                // Inline Edit Form
                                if editingTransactionID == transaction.id {
                                    InlineEditTransactionForm(
                                        transaction: transaction,
                                        viewModel: viewModel,
                                        isShowing: Binding(
                                            get: { editingTransactionID == transaction.id },
                                            set: { if !$0 { editingTransactionID = nil } }
                                        )
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Transaction Categories

    private var transactionCategories: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Categories header
                Text("Categories")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()

                // Category list
                VStack(spacing: 1) {
                    TransactionCategoryRow(
                        categoryName: "Development",
                        icon: "lightbulb.fill",
                        color: .purple,
                        count: 0,
                        total: 0
                    )

                    TransactionCategoryRow(
                        categoryName: "Above the Line",
                        icon: "star.fill",
                        color: .yellow,
                        count: 0,
                        total: 0
                    )

                    TransactionCategoryRow(
                        categoryName: "Production (Below the Line)",
                        icon: "film.fill",
                        color: .blue,
                        count: 0,
                        total: 0
                    )

                    TransactionCategoryRow(
                        categoryName: "Art / Camera / Lighting / Sound",
                        icon: "camera.fill",
                        color: .orange,
                        count: 0,
                        total: 0
                    )

                    TransactionCategoryRow(
                        categoryName: "Locations & Logistics",
                        icon: "mappin.circle.fill",
                        color: .red,
                        count: 0,
                        total: 0
                    )

                    TransactionCategoryRow(
                        categoryName: "Post-Production",
                        icon: "film.stack.fill",
                        color: .indigo,
                        count: 0,
                        total: 0
                    )

                    TransactionCategoryRow(
                        categoryName: "Marketing / Distribution",
                        icon: "megaphone.fill",
                        color: .green,
                        count: 0,
                        total: 0
                    )

                    TransactionCategoryRow(
                        categoryName: "Admin / Office / Misc",
                        icon: "folder.fill",
                        color: .gray,
                        count: 0,
                        total: 0
                    )
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Cost Tracking Full View

    private var costTrackingFullView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Cost Tracking")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 60)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Split view: Category totals (30%) and Chart (70%)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left: Category Totals (30%)
                    categoryTotalsList
                        .frame(width: geometry.size.width * 0.3)

                    Divider()

                    // Right: Chart (70%)
                    costTrackingChart
                        .frame(width: geometry.size.width * 0.7)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Category Totals List

    private var categoryTotalsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Category Totals")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ForEach(BudgetCategory.allCases) { category in
                    CategoryTotalRow(
                        category: category,
                        total: viewModel.summary.categoryBreakdown[category] ?? 0,
                        percentage: viewModel.summary.percentage(for: category)
                    )
                    .environmentObject(viewModel)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Cost Tracking Chart

    private var costTrackingChart: some View {
        VStack(spacing: 16) {
            if viewModel.lineItems.isEmpty && viewModel.transactions.isEmpty {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)

                    Text("No cost data")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Cost tracking data will appear here as your budget progresses")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Chart View
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Summary Cards
                        let totalExpenses = viewModel.transactions.filter { $0.transactionType == "Expense" }.reduce(0) { $0 + $1.amount }
                        let remaining = viewModel.summary.totalBudget - totalExpenses

                        HStack(spacing: 12) {
                            CostSummaryCard(
                                title: "Budgeted",
                                amount: viewModel.summary.totalBudget,
                                icon: "dollarsign.circle.fill",
                                color: .blue
                            )

                            CostSummaryCard(
                                title: "Spent",
                                amount: totalExpenses,
                                icon: "arrow.down.circle.fill",
                                color: .red
                            )

                            CostSummaryCard(
                                title: "Remaining",
                                amount: remaining,
                                icon: remaining >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                color: remaining >= 0 ? .green : .orange
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Category Comparison Bars
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Budget vs. Spent by Category")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)

                            ForEach(BudgetCategory.allCases) { category in
                                let matchingCategories = category.matchingTransactionCategories()
                                let actualSpent = viewModel.transactions
                                    .filter { matchingCategories.contains($0.category) && $0.transactionType == "Expense" }
                                    .reduce(0) { $0 + $1.amount }

                                CategoryComparisonBar(
                                    category: category,
                                    budgeted: viewModel.summary.categoryBreakdown[category] ?? 0,
                                    actual: actualSpent
                                )
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Cost of Scene Full View

    private var costToDateFullView: some View {
        HStack(spacing: 0) {
            // Scene list sidebar
            costOfSceneSidebar
                .frame(width: 320)

            Divider()

            // Scene detail pane
            costOfSceneDetailPane
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Payroll Full View

    private var payrollFullView: some View {
        PayrollFullView(viewModel: viewModel)
    }

    // MARK: - Cost of Scene Sidebar

    private var costOfSceneSidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scenes")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(stripStore.scenes.count) scenes in script")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    Spacer()
                    Button {
                        if expandedSceneIDs.count == stripStore.scenes.count {
                            expandedSceneIDs.removeAll()
                        } else {
                            expandedSceneIDs = Set(stripStore.scenes.map { $0.objectID })
                        }
                    } label: {
                        Image(systemName: expandedSceneIDs.count == stripStore.scenes.count ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .customTooltip(expandedSceneIDs.count == stripStore.scenes.count ? "Collapse all" : "Expand all")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemBackground))

            Divider()

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search scenes...", text: $costOfSceneSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !costOfSceneSearchText.isEmpty {
                    Button {
                        costOfSceneSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Scene list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCostOfSceneScenes, id: \.objectID) { scene in
                        CostOfSceneRow(
                            scene: scene,
                            isSelected: selectedSceneID == scene.objectID,
                            isExpanded: expandedSceneIDs.contains(scene.objectID),
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedSceneID = scene.objectID
                                }
                            },
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if expandedSceneIDs.contains(scene.objectID) {
                                        expandedSceneIDs.remove(scene.objectID)
                                    } else {
                                        expandedSceneIDs.insert(scene.objectID)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(.systemBackground))
    }

    private var filteredCostOfSceneScenes: [SceneEntity] {
        if costOfSceneSearchText.isEmpty {
            return stripStore.scenes
        }
        return stripStore.scenes.filter { scene in
            let number = scene.number ?? ""
            let heading = costOfSceneHeading(for: scene)
            return number.localizedCaseInsensitiveContains(costOfSceneSearchText) ||
                   heading.localizedCaseInsensitiveContains(costOfSceneSearchText)
        }
    }

    private func costOfSceneHeading(for scene: SceneEntity) -> String {
        let locType = (scene.locationType ?? "INT.").trimmingCharacters(in: .whitespacesAndNewlines)
        let tod = (scene.timeOfDay ?? "DAY").trimmingCharacters(in: .whitespacesAndNewlines)
        var location = ""
        if scene.entity.attributesByName.keys.contains("heading"),
           let h = scene.value(forKey: "heading") as? String,
           !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            location = h.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let loc = scene.scriptLocation?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
            location = loc
        } else {
            location = "Untitled Scene"
        }
        return "\(locType) \(location) - \(tod)"
    }

    // MARK: - Cost of Scene Detail Pane

    private var costOfSceneDetailPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let sceneID = selectedSceneID,
               let scene = stripStore.scenes.first(where: { $0.objectID == sceneID }) {
                // Scene header
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Scene \(scene.number ?? "?")")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.blue))

                                Text(costOfSceneHeading(for: scene))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }

                            if let pageEighths = scene.pageEighthsString, !pageEighths.isEmpty {
                                Text("\(pageEighths) pages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color(.secondarySystemBackground))

                Divider()

                // Scene breakdown items
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let breakdown = scene.breakdown {
                            let castIDs = breakdown.getCastIDs()
                            if !castIDs.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Cast",
                                    icon: "person.2.fill",
                                    color: .blue,
                                    items: castIDs,
                                    context: context
                                )
                            }

                            let props = breakdown.getProps()
                            let art = breakdown.getArt()
                            let artItems = props + art
                            if !artItems.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Art Department",
                                    icon: "paintbrush.fill",
                                    color: .orange,
                                    items: artItems,
                                    context: context
                                )
                            }

                            let wardrobe = breakdown.getWardrobe()
                            if !wardrobe.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Wardrobe",
                                    icon: "tshirt.fill",
                                    color: .purple,
                                    items: wardrobe,
                                    context: context
                                )
                            }

                            let makeup = breakdown.getMakeup()
                            if !makeup.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Makeup/Hair",
                                    icon: "face.smiling",
                                    color: .pink,
                                    items: makeup,
                                    context: context
                                )
                            }

                            let vehicles = breakdown.getVehicles()
                            if !vehicles.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Vehicles",
                                    icon: "car.fill",
                                    color: .gray,
                                    items: vehicles,
                                    context: context
                                )
                            }

                            let spfx = breakdown.getSPFX()
                            if !spfx.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Special Effects",
                                    icon: "flame.fill",
                                    color: .red,
                                    items: spfx,
                                    context: context
                                )
                            }

                            let soundfx = breakdown.getSoundFX()
                            if !soundfx.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Sound",
                                    icon: "waveform",
                                    color: .green,
                                    items: soundfx,
                                    context: context
                                )
                            }

                            let vfx = breakdown.getVisualEffects()
                            if !vfx.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Visual Effects",
                                    icon: "sparkles",
                                    color: .cyan,
                                    items: vfx,
                                    context: context
                                )
                            }

                            let extras = breakdown.getExtras()
                            if !extras.isEmpty {
                                CostOfSceneCategorySection(
                                    title: "Extras/Background",
                                    icon: "person.3.fill",
                                    color: .indigo,
                                    items: extras,
                                    context: context
                                )
                            }

                            let customCategories = breakdown.getCustomCategories()
                            ForEach(customCategories, id: \.name) { category in
                                if !category.items.isEmpty {
                                    CostOfSceneCategorySection(
                                        title: category.name,
                                        icon: "tag.fill",
                                        color: .secondary,
                                        items: category.items,
                                        context: context
                                    )
                                }
                            }

                            if castIDs.isEmpty && artItems.isEmpty && wardrobe.isEmpty &&
                               makeup.isEmpty && vehicles.isEmpty && spfx.isEmpty &&
                               soundfx.isEmpty && vfx.isEmpty && extras.isEmpty &&
                               customCategories.allSatisfy({ $0.items.isEmpty }) {
                                emptyBreakdownState
                            }
                        } else {
                            emptyBreakdownState
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "film.stack")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)

                    Text("Select a Scene")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text("Choose a scene from the list to view its breakdown items and associated costs")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
    }

    private var emptyBreakdownState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Breakdown Items")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("This scene has no breakdown items yet.\nAdd items in Breakdowns to see them here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Budget List

    private var budgetListView: some View {
        List {
            // Display sections
            ForEach(viewModel.sectionsForCurrentCategory, id: \.self) { sectionName in
                Section {
                    if viewModel.isSectionExpanded(sectionName) {
                        ForEach(viewModel.items(forSection: sectionName)) { item in
                            BudgetLineItemRow(item: item, viewModel: viewModel, selectedItem: $selectedItem, selectedItemID: $selectedItemID)
                        }
                    }
                } header: {
                    BudgetSectionHeader(
                        sectionName: sectionName,
                        isExpanded: viewModel.isSectionExpanded(sectionName),
                        total: viewModel.totalForSection(sectionName),
                        itemCount: viewModel.items(forSection: sectionName).count
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.toggleSection(sectionName)
                        }
                    }
                }
            }
            
            // Display ungrouped items (items without a section) directly without a header
            ForEach(viewModel.ungroupedItems) { item in
                BudgetLineItemRow(item: item, viewModel: viewModel, selectedItem: $selectedItem, selectedItemID: $selectedItemID)
            }
        }
#if os(macOS)
        .listStyle(.inset)
#else
        .listStyle(.insetGrouped)
#endif
    }
    
    // MARK: - Empty State

    // Check if the entire budget is empty (no items in any category)
    private var isBudgetCompletelyEmpty: Bool {
        viewModel.lineItems.isEmpty
    }

    // Get the currently selected category name
    private var selectedCategoryName: String {
        if let categoryID = viewModel.selectedCustomCategoryID,
           let category = viewModel.customCategories.first(where: { $0.id == categoryID }) {
            return category.name
        }
        return "this category"
    }

    // Background for the Add Item button in empty state
    @ViewBuilder
    private var addItemButtonBackground: some View {
        if isBudgetCompletelyEmpty {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.gradient)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: isBudgetCompletelyEmpty ? "doc.text.fill" : "tray")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue.gradient)

                VStack(spacing: 8) {
                    Text(isBudgetCompletelyEmpty ? "Ready to Build Your Budget" : "No Items in \(selectedCategoryName)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(isBudgetCompletelyEmpty
                         ? "Start with a professional template or add items manually"
                         : "Add budget items to this category to get started")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 16) {
                // Only show template option if the entire budget is empty
                if isBudgetCompletelyEmpty {
                    Button {
                        showingTemplateSelection = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Load Budget Template")
                                    .fontWeight(.semibold)
                                Text("Choose from Short Film, Feature Film, or TV Show")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                Button {
                    showingAddItem = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Item Manually")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(addItemButtonBackground)
                    .foregroundStyle(isBudgetCompletelyEmpty ? Color.primary : Color.white)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading budget...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Budget Inspector

    private var budgetInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Item Details")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()

                if selectedItem != nil {
                    Button {
                        selectedItem = nil
                        selectedItemID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Content - restore selection from ID if needed
            if let item = selectedItem ?? restoreSelectedItem() {
                EditableItemInspector(item: item, viewModel: viewModel, selectedItem: $selectedItem, selectedItemID: $selectedItemID)
                    .id(item.id)
                    .onChange(of: item.id) { newID in
                        selectedItemID = newID
                    }
            } else {
                // No Selection State
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("No Item Selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Click an item to view details")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helper Functions

    private func restoreSelectedItem() -> BudgetLineItem? {
        guard let id = selectedItemID else { return nil }
        let item = viewModel.lineItems.first { $0.id == id }
        if item != nil {
            selectedItem = item
        }
        return item
    }

    private func clearAllBudgetItems() {
        // Delete all line items for the current version
        viewModel.lineItems.forEach { item in
            viewModel.deleteLineItem(item)
        }

        // Clear selection
        selectedItem = nil
        selectedItemID = nil
    }

    // MARK: - Old Pane Views (Removed - Now using full-page views)

    // The transactionsPane, costTrackingPane, and costToDatePane have been
    // replaced by transactionsFullView, costTrackingFullView, and costToDateFullView
}

// MARK: - Editable Item Inspector

private struct EditableItemInspector: View {
    let item: BudgetLineItem
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var selectedItem: BudgetLineItem?
    @Binding var selectedItemID: UUID?

    @State private var name: String
    @State private var selectedAccount: BudgetAccount
    @State private var selectedCategoryID: UUID?
    @State private var selectedSubcategory: String
    @State private var section: String
    @State private var quantity: Double
    @State private var days: Double
    @State private var unitCost: Double
    @State private var totalBudget: Double
    @State private var notes: String
    @State private var ignoreTotal: Bool

    // Computed property for the selected custom category
    private var selectedCategory: CustomBudgetCategory? {
        viewModel.customCategories.first { $0.id == selectedCategoryID }
    }

    init(item: BudgetLineItem, viewModel: BudgetViewModel, selectedItem: Binding<BudgetLineItem?>, selectedItemID: Binding<UUID?>) {
        self.item = item
        self.viewModel = viewModel
        self._selectedItem = selectedItem
        self._selectedItemID = selectedItemID

        _name = State(initialValue: item.name)
        // Try to match the account code to the enum, default to .none if not found
        if let matchedAccount = BudgetAccount.allCases.first(where: { $0.code == item.account }) {
            _selectedAccount = State(initialValue: matchedAccount)
        } else {
            _selectedAccount = State(initialValue: .none)
        }
        // Match item.category to custom category by name
        let matchedCategoryID = viewModel.customCategories.first(where: { $0.name == item.category })?.id
        _selectedCategoryID = State(initialValue: matchedCategoryID)
        _selectedSubcategory = State(initialValue: item.subcategory)
        _section = State(initialValue: item.section ?? "")
        _quantity = State(initialValue: item.quantity)
        _days = State(initialValue: item.days)
        _unitCost = State(initialValue: item.unitCost)
        _totalBudget = State(initialValue: item.totalBudget)
        _notes = State(initialValue: item.notes)
        _ignoreTotal = State(initialValue: item.ignoreTotal)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section and Name on one line (half width each)
                HStack(spacing: 12) {
                    // Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECTION (Department)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)

                        TextField("e.g. Cast, Camera, Lighting", text: $section)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: section) { _ in saveChanges() }
                    }

                    // Item Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)

                        TextField("Item name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _ in saveChanges() }
                    }
                }

                // Account, Category, Subcategory - on one line (hidden in Short Film mode)
                if viewModel.currentTemplateType != .shortFilm {
                    HStack(spacing: 12) {
                        // Account
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ACCOUNT")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontWeight(.semibold)

                            Picker("Account", selection: $selectedAccount) {
                                ForEach(BudgetAccount.allCases) { account in
                                    Text(account.rawValue).tag(account)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: selectedAccount) { _ in saveChanges() }
                        }
                        .frame(maxWidth: .infinity)

                        // Category (using custom categories)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CATEGORY")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontWeight(.semibold)

                            Picker("Category", selection: $selectedCategoryID) {
                                ForEach(viewModel.customCategories) { category in
                                    Label(category.name, systemImage: category.icon)
                                        .tag(category.id as UUID?)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: selectedCategoryID) { newValue in
                                // Update subcategory when category changes
                                if let categoryID = newValue,
                                   let category = viewModel.customCategories.first(where: { $0.id == categoryID }) {
                                    if !category.subcategories.contains(selectedSubcategory) {
                                        selectedSubcategory = category.subcategories.first ?? ""
                                    }
                                }
                                saveChanges()
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Subcategory (from selected category's subcategories)
                        if let category = selectedCategory, !category.subcategories.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SUBCATEGORY")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.semibold)

                                Picker("Subcategory", selection: $selectedSubcategory) {
                                    Text("None").tag("")
                                    ForEach(category.subcategories, id: \.self) { subcategory in
                                        Text(subcategory).tag(subcategory)
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: selectedSubcategory) { _ in saveChanges() }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Divider()
                }

                // Personnel Section (for ALL items)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("PERSONNEL")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.7))
                            .fontWeight(.semibold)
                        Spacer()
                        PersonnelDropdownMenu(
                            parentItem: item,
                            viewModel: viewModel,
                            selectedItem: $selectedItem
                        )
                    }

                    // Display personnel sub-items with editable cost details
                    if let childIDs = item.childItemIDs, !childIDs.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(viewModel.lineItems.filter { childIDs.contains($0.id) }) { personnelItem in
                                PersonnelItemRow(
                                    personnelItem: personnelItem,
                                    viewModel: viewModel,
                                    parentItem: item,
                                    selectedItem: $selectedItem,
                                    selectedItemID: $selectedItemID,
                                    onRemove: { removePersonnel(personnelItem) }
                                )
                            }
                        }
                    } else {
                        Text("No personnel added")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    }
                }

                Divider()

                // Ignore Total Checkbox
                Toggle(isOn: $ignoreTotal) {
                    Text("Ignore total (exclude from budget calculations)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .onChange(of: ignoreTotal) { _ in saveChanges() }

                // Total Display (for personnel groups) - only show if not ignored
                if !ignoreTotal {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("TOTAL")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.7))
                            .fontWeight(.semibold)

                        VStack(spacing: 12) {
                        // Total Budget (editable)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOTAL BUDGET")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))
                                .fontWeight(.semibold)

                            TextField("$0.00", value: $totalBudget, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: totalBudget) { _ in saveChanges() }
                                .font(.system(size: 16, weight: .medium))
                        }

                        Divider()

                        // Budget vs Actual comparison
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Budget")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.7))
                                Text(item.totalBudget.asCurrency())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Actual")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.7))
                                Text(calculateGroupTotal(for: item).asCurrency())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }

                        Divider()

                        // Over/Under status
                        let variance = item.totalBudget - calculateGroupTotal(for: item)
                        let isOverBudget = variance < 0

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isOverBudget ? "Over Budget" : "Under Budget")
                                    .font(.caption)
                                    .foregroundStyle(isOverBudget ? .red : .green)
                                    .fontWeight(.semibold)
                                Text(abs(variance).asCurrency())
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(isOverBudget ? .red : .green)
                            }
                            Spacer()
                            Image(systemName: isOverBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(isOverBudget ? .red : .green)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                } // End if !ignoreTotal

                Divider()
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("NOTES")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        Spacer()
                        if !notes.isEmpty {
                            Button {
                                notes = ""
                                saveChanges()
                            } label: {
                                Text("Clear")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 200)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    #if os(macOS)
                                    .fill(Color(.textBackgroundColor).opacity(0.5))
                                    #else
                                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                                    #endif
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .onChange(of: notes) { _ in saveChanges() }

                        if notes.isEmpty {
                            Text("Add notes about this budget item...")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                }
                
                Divider()
                
                // Delete Button
                Button(role: .destructive) {
                    viewModel.deleteLineItem(item)
                    selectedItem = nil
                    selectedItemID = nil
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Item")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
    }
    
    private func saveChanges() {
        var updatedItem = item
        updatedItem.name = name
        updatedItem.account = selectedAccount.code
        // Use custom category name
        updatedItem.category = selectedCategory?.name ?? item.category
        updatedItem.subcategory = selectedSubcategory
        // Use section if provided, otherwise default to subcategory for grouping
        if !section.isEmpty {
            updatedItem.section = section
        } else if !selectedSubcategory.isEmpty {
            updatedItem.section = selectedSubcategory
        } else {
            updatedItem.section = nil
        }
        updatedItem.quantity = quantity
        updatedItem.days = days
        updatedItem.unitCost = unitCost
        updatedItem.totalBudget = totalBudget
        updatedItem.notes = notes
        updatedItem.ignoreTotal = ignoreTotal

        viewModel.updateLineItem(updatedItem)

        // Update the selected item from the viewModel to keep it in sync
        if let updatedFromVM = viewModel.lineItems.first(where: { $0.id == updatedItem.id }) {
            selectedItem = updatedFromVM
        }
    }

    private func addCustomItem() {
        // Create a new custom line item
        let newItem = BudgetLineItem(
            name: "New Item",
            account: item.account,
            category: item.category,
            subcategory: item.subcategory,
            section: item.section,
            quantity: 1.0,
            days: 1.0,
            unitCost: 0.0,
            totalBudget: 0.0,
            parentItemID: item.id
        )

        // Add to viewModel
        viewModel.addLineItem(newItem)

        // Update parent's childItemIDs
        var updatedParent = item
        if updatedParent.childItemIDs != nil {
            updatedParent.childItemIDs?.append(newItem.id)
        } else {
            updatedParent.childItemIDs = [newItem.id]
        }
        viewModel.updateLineItem(updatedParent)
        selectedItem = updatedParent
    }

    private func removePersonnel(_ personnel: BudgetLineItem) {
        // Remove from parent's child list
        var updatedItem = item
        if var childIDs = updatedItem.childItemIDs {
            childIDs.removeAll { $0 == personnel.id }
            updatedItem.childItemIDs = childIDs
            viewModel.updateLineItem(updatedItem)
            selectedItem = updatedItem
        }

        // Delete the personnel item
        viewModel.deleteLineItem(personnel)
    }

    private func calculateGroupTotal(for item: BudgetLineItem) -> Double {
        // If item has children, sum their totals
        if let childIDs = item.childItemIDs, !childIDs.isEmpty {
            let children = viewModel.lineItems.filter { childIDs.contains($0.id) }
            return children.reduce(0) { $0 + $1.total }
        }
        // Otherwise use the item's own total
        return item.total
    }
}

// MARK: - Personnel Item Row with Editable Cost

private struct PersonnelItemRow: View {
    let personnelItem: BudgetLineItem
    @ObservedObject var viewModel: BudgetViewModel
    let parentItem: BudgetLineItem
    @Binding var selectedItem: BudgetLineItem?
    @Binding var selectedItemID: UUID?
    let onRemove: () -> Void

    @State private var isExpanded = false
    @State private var quantity: Double
    @State private var days: Double
    @State private var unitCost: Double

    init(personnelItem: BudgetLineItem, viewModel: BudgetViewModel, parentItem: BudgetLineItem, selectedItem: Binding<BudgetLineItem?>, selectedItemID: Binding<UUID?>, onRemove: @escaping () -> Void) {
        self.personnelItem = personnelItem
        self.viewModel = viewModel
        self.parentItem = parentItem
        self._selectedItem = selectedItem
        self._selectedItemID = selectedItemID
        self.onRemove = onRemove

        _quantity = State(initialValue: personnelItem.quantity)
        _days = State(initialValue: personnelItem.days)
        _unitCost = State(initialValue: personnelItem.unitCost)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(personnelItem.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if !isExpanded {
                        Text("\(personnelItem.quantity.formatted()) × \(personnelItem.days.formatted()) days @ \(personnelItem.unitCost.asCurrency())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(personnelItem.total.asCurrency())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(isExpanded ? 0 : 6)
            .cornerRadius(isExpanded ? 6 : 0, corners: [.topLeft, .topRight])

            // Expanded cost details
            if isExpanded {
                VStack(spacing: 12) {
                    Text("Cost Details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quantity")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("0", value: $quantity, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: quantity) { _ in updateCosts() }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Days")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("0", value: $days, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: days) { _ in updateCosts() }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unit Cost")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("$0.00", value: $unitCost, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: unitCost) { _ in updateCosts() }
                        }
                    }

                    HStack {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text((quantity * days * unitCost).asCurrency())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.03))
                .cornerRadius(6, corners: [.bottomLeft, .bottomRight])
            }
        }
    }

    private func updateCosts() {
        var updatedItem = personnelItem
        updatedItem.quantity = quantity
        updatedItem.days = days
        updatedItem.unitCost = unitCost
        viewModel.updateLineItem(updatedItem)

        // Keep the parent item selected after updating costs
        DispatchQueue.main.async {
            if selectedItem?.id != parentItem.id {
                selectedItem = parentItem
            }
        }
    }
}

// Helper for custom corner radius - macOS compatible
struct RectCorner: OptionSet {
    let rawValue: UInt

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                       radius: topRight,
                       startAngle: Angle(degrees: -90),
                       endAngle: Angle(degrees: 0),
                       clockwise: false)
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                       radius: bottomRight,
                       startAngle: Angle(degrees: 0),
                       endAngle: Angle(degrees: 90),
                       clockwise: false)
        }

        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                       radius: bottomLeft,
                       startAngle: Angle(degrees: 90),
                       endAngle: Angle(degrees: 180),
                       clockwise: false)
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                       radius: topLeft,
                       startAngle: Angle(degrees: 180),
                       endAngle: Angle(degrees: 270),
                       clockwise: false)
        }

        return path
    }
}

// MARK: - Personnel Dropdown Menu

private struct PersonnelDropdownMenu: View {
    let parentItem: BudgetLineItem
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var selectedItem: BudgetLineItem?
    @Environment(\.managedObjectContext) private var context
    @State private var allContacts: [ContactInfo] = []

    struct ContactInfo: Identifiable {
        let id: UUID
        let name: String
        let role: String?
        let category: String
    }

    var body: some View {
        Menu {
            // Cast Section
            if !castContacts.isEmpty {
                Section("Cast") {
                    ForEach(castContacts) { contact in
                        Button(action: {
                            addPersonnelFromContact(contact, type: .cast)
                        }) {
                            VStack(alignment: .leading) {
                                Text(contact.name)
                                if let role = contact.role, !role.isEmpty {
                                    Text(role)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Crew Section
            if !crewContacts.isEmpty {
                Section("Crew") {
                    ForEach(crewContacts) { contact in
                        Button(action: {
                            addPersonnelFromContact(contact, type: .crew)
                        }) {
                            VStack(alignment: .leading) {
                                Text(contact.name)
                                if let role = contact.role, !role.isEmpty {
                                    Text(role)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // All Others
            if !otherContacts.isEmpty {
                Section("Other") {
                    ForEach(otherContacts) { contact in
                        Button(action: {
                            addPersonnelFromContact(contact, type: .crew)
                        }) {
                            VStack(alignment: .leading) {
                                Text(contact.name)
                                if let role = contact.role, !role.isEmpty {
                                    Text(role)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if allContacts.isEmpty {
                Text("No contacts available")
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                Text("Add Personnel")
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
        .menuStyle(.borderlessButton)
        .onAppear {
            loadContacts()
        }
    }

    var castContacts: [ContactInfo] {
        allContacts.filter { $0.category == "cast" }
    }

    var crewContacts: [ContactInfo] {
        allContacts.filter { $0.category == "crew" }
    }

    var otherContacts: [ContactInfo] {
        allContacts.filter { $0.category == "all" }
    }

    private func loadContacts() {
        let req = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            let results = try context.fetch(req)
            allContacts = results.compactMap { mo in
                guard let id = mo.value(forKey: "id") as? UUID,
                      let name = mo.value(forKey: "name") as? String else {
                    return nil
                }

                let role = mo.value(forKey: "role") as? String
                var category = "all"

                if let note = mo.value(forKey: "note") as? String {
                    if note.lowercased().contains("[cast]") {
                        category = "cast"
                    } else if note.lowercased().contains("[vendor]") {
                        category = "vendor"
                    } else if note.lowercased().contains("[crew]") {
                        category = "crew"
                    }
                }

                return ContactInfo(id: id, name: name, role: role, category: category)
            }
        } catch {
            print("Error fetching contacts: \(error)")
        }
    }

    private func addPersonnelFromContact(_ contact: ContactInfo, type: BudgetLineItem.ContactType) {
        let newPersonnel = BudgetLineItem(
            name: contact.name,
            account: parentItem.account,
            category: parentItem.category,
            subcategory: contact.role ?? parentItem.subcategory,
            linkedContactID: contact.id,
            linkedContactType: type,
            parentItemID: parentItem.id,
            childItemIDs: nil
        )

        // Add the new personnel item
        viewModel.addLineItem(newPersonnel)

        // Update parent item to include this child
        var updatedParent = parentItem
        var childIDs = updatedParent.childItemIDs ?? []
        childIDs.append(newPersonnel.id)
        updatedParent.childItemIDs = childIDs
        viewModel.updateLineItem(updatedParent)

        // Keep the parent item selected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedItem = updatedParent
        }
    }
}

// MARK: - Category Summary Card

private struct CategorySummaryCard: View {
    let category: BudgetCategory
    let amount: Double
    let percentage: Double
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white : category.color)

                    Text(category.rawValue)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : category.color.opacity(0.8))
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(amount.asCurrency())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : category.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? category.color : category.color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(category.color.opacity(isSelected ? 1.0 : 0.4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Short Film Category Summary Card

private struct ShortFilmCategorySummaryCard: View {
    let category: ShortFilmCategory
    let amount: Double
    let percentage: Double
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white : category.color)

                    Text(category.rawValue)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : category.color.opacity(0.8))
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(amount.asCurrency())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : category.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? category.color : category.color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(category.color.opacity(isSelected ? 1.0 : 0.4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Navigation Row

private struct SectionNavigationRow: View {
    let sectionName: String
    let itemCount: Int
    let total: Double
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(sectionName)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(itemCount)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )

                Text(total.asCurrency())
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Category Navigation Row

private struct CategoryNavigationRow: View {
    let category: BudgetCategory
    let isSelected: Bool
    let amount: Double
    let itemCount: Int
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Category icon
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(category.color)
                    .frame(width: 20)

                // Category name
                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Item count badge
                Text("\(itemCount)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )

                // Amount
                Text(amount.asCurrency())
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? category.color.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? category.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Custom Category Summary Card (for header rectangles)

private struct CustomCategorySummaryCard: View {
    let category: CustomBudgetCategory
    let amount: Double
    let percentage: Double
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white : category.color)

                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : category.color.opacity(0.8))
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(amount.asCurrency())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : category.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? category.color : category.color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(category.color.opacity(isSelected ? 1.0 : 0.4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Category Navigation Row (for sidebar)

private struct CustomCategoryNavigationRow: View {
    let category: CustomBudgetCategory
    let isSelected: Bool
    let amount: Double
    let itemCount: Int
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Category icon
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(category.color)
                    .frame(width: 20)

                // Category name
                Text(category.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Item count badge
                Text("\(itemCount)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )

                // Amount
                Text(amount.asCurrency())
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? category.color.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? category.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Transaction Category Row

private struct TransactionCategoryRow: View {
    let categoryName: String
    let icon: String
    let color: Color
    let count: Int
    let total: Double

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.15))
                )

            // Category name and stats
            VStack(alignment: .leading, spacing: 3) {
                Text(categoryName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text("\(count) transaction\(count != 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if total != 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(total.asCurrency())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(Color(.systemBackground))
#if os(iOS)
        .hoverEffect(.highlight)
#endif
    }
}

// MARK: - Category Tab

private struct CategoryTab: View {
    let category: BudgetCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? category.color : Color.clear)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Budget Section Header

private struct BudgetSectionHeader: View {
    let sectionName: String
    let isExpanded: Bool
    let total: Double
    let itemCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Expand/Collapse Icon
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                
                // Section Name
                Text(sectionName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Item Count
                Text("\(itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Total
                Text(total.asCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Budget Line Item Row

private struct BudgetLineItemRow: View {
    let item: BudgetLineItem
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var selectedItem: BudgetLineItem?
    @Binding var selectedItemID: UUID?
    @State private var showingContactPicker = false
    @State private var showingCastMemberPicker = false
    @State private var showChildItems = true
    
    var body: some View {
        VStack(spacing: 0) {
            rowContent
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedItem?.id == item.id ? Color.blue.opacity(0.1) : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    // Only select if not tapping on a button
                    selectedItem = item
                    selectedItemID = item.id
                }
                .contextMenu {
                    Button {
                        showingContactPicker = true
                    } label: {
                        Label("Attach Contact", systemImage: "person.badge.plus")
                    }

                    if item.canHaveCastMembers {
                        if !viewModel.childItems(for: item.id).isEmpty {
                            Button {
                                showChildItems.toggle()
                            } label: {
                                Label(showChildItems ? "Hide Personnel" : "Show Personnel",
                                      systemImage: showChildItems ? "eye.slash" : "eye")
                            }
                        }
                    }
                    
                    if item.parentItemID != nil {
                        Divider()
                        Button(role: .destructive) {
                            viewModel.removeCastMember(item.id)
                        } label: {
                            Label("Remove Cast Member", systemImage: "trash")
                        }
                    }
                }
                .sheet(isPresented: $showingContactPicker) {
                    ContactPickerView(item: item, viewModel: viewModel)
                        .frame(minWidth: 500, idealWidth: 550, maxWidth: 600)
                }
                .sheet(isPresented: $showingCastMemberPicker) {
                    AddCastMemberView(parentItem: item, viewModel: viewModel, isPresented: $showingCastMemberPicker)
                        .frame(minWidth: 600, idealWidth: 650, maxWidth: 700)
                }
            
            // Show child cast members if this is a parent item
            if item.canHaveCastMembers && showChildItems {
                let childItems = viewModel.childItems(for: item.id)
                if !childItems.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(childItems) { childItem in
                            BudgetCastMemberRow(item: childItem, viewModel: viewModel, selectedItem: $selectedItem, selectedItemID: $selectedItemID)
                        }
                    }
                    .padding(.leading, 32)
                }
            }
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            // Left side - Account, Name and category
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if !item.account.isEmpty {
                        Text(item.account)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            .fixedSize()
                    }

                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .fixedSize()

                    // Show cast member count badge if this is a parent item
                    if item.canHaveCastMembers {
                        let childCount = viewModel.childItems(for: item.id).count
                        if childCount > 0 {
                            Text("\(childCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Circle()
                                        .fill(Color.purple)
                                )
                                .fixedSize()
                        }
                    }
                }

                Text(item.subcategory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            // Middle - Cost details
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.caption2)
                    Text("\(Int(item.quantity))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .fixedSize()

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("\(Int(item.days))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .fixedSize()

                Text(item.unitCost.asCurrency())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .fixedSize()

            // Right side - Total and badges
            HStack(spacing: 8) {
                if item.isLinkedToRateCard {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .fixedSize()
                }

                if let contactType = item.linkedContactType {
                    Image(systemName: contactIconName(for: contactType))
                        .font(.caption2)
                        .foregroundStyle(contactColor(for: contactType))
                        .fixedSize()
                }

                Text(calculateGroupTotal(for: item).asCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .fixedSize()
            }
            .fixedSize()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func contactIconName(for type: BudgetLineItem.ContactType) -> String {
        switch type {
        case .crew: return "person.fill"
        case .cast: return "person.2.fill"
        case .vendor: return "building.2.fill"
        }
    }
    
    private func contactColor(for type: BudgetLineItem.ContactType) -> Color {
        switch type {
        case .crew: return .blue
        case .cast: return .purple
        case .vendor: return .green
        }
    }

    private func calculateGroupTotal(for item: BudgetLineItem) -> Double {
        // If item has children, sum their totals
        if let childIDs = item.childItemIDs, !childIDs.isEmpty {
            let children = viewModel.lineItems.filter { childIDs.contains($0.id) }
            return children.reduce(0) { $0 + $1.total }
        }
        // Otherwise use the item's own total
        return item.total
    }
}

// MARK: - Cast Member Row (Child Item)

private struct BudgetCastMemberRow: View {
    let item: BudgetLineItem
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var selectedItem: BudgetLineItem?
    @Binding var selectedItemID: UUID?

    var body: some View {
        HStack(spacing: 12) {
            // Connector line
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize()

            // Cast member name
            if item.linkedContactID != nil {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .fixedSize()

                    Text(item.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .fixedSize()
                }
                .fixedSize()
            } else {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .fixedSize()
            }

            Spacer()

            // Days
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("\(Int(item.days)) days")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .fixedSize()

            // Day rate
            Text(item.unitCost.asCurrency())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()

            // Total
            Text(item.total.asCurrency())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)
                .fixedSize()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
            selectedItemID = item.id
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removeCastMember(item.id)
            } label: {
                Label("Remove Cast Member", systemImage: "trash")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Template Selection View

private struct TemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel
    @State private var isLoadingTemplate = false
    @State private var alertConfig: AlertConfig?
    @State private var templateToDelete: CustomBudgetTemplate?
    @State private var showDeleteConfirmation = false

    private struct AlertConfig: Identifiable {
        enum Kind {
            case success, error
        }

        let id = UUID()
        let title: String
        let message: String
        let kind: Kind
    }

    enum TemplateType {
        case shortFilm
        case featureFilm
        case tvShow
        
        var title: String {
            switch self {
            case .shortFilm: return "Short Film"
            case .featureFilm: return "Feature Film"
            case .tvShow: return "TV Show"
            }
        }
        
        var icon: String {
            switch self {
            case .shortFilm: return "film"
            case .featureFilm: return "film.fill"
            case .tvShow: return "tv"
            }
        }
        
        var description: String {
            switch self {
            case .shortFilm: return "Compact budget for short films and student projects"
            case .featureFilm: return "Comprehensive budget with 389 professional line items"
            case .tvShow: return "Episodic budget template for television production"
            }
        }
        
        var itemCount: String {
            switch self {
            case .shortFilm: return "15 line items"
            case .featureFilm: return "319 line items"
            case .tvShow: return "Coming Soon"
            }
        }
        
        var color: Color {
            switch self {
            case .shortFilm: return .green
            case .featureFilm: return .blue
            case .tvShow: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)

                        Text("Choose Budget Template")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Select a template to get started quickly")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 8)

                    // Custom Templates Section
                    if !viewModel.customTemplates.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.orange)
                                Text("My Templates")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 12) {
                                ForEach(viewModel.customTemplates) { template in
                                    CustomTemplateCard(
                                        template: template,
                                        action: { loadCustomTemplate(template) },
                                        deleteAction: {
                                            templateToDelete = template
                                            showDeleteConfirmation = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }

                    // Built-in Templates Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundStyle(.blue)
                            Text("Built-in Templates")
                                .font(.headline)
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 16) {
                            TemplateCard(
                                type: .shortFilm,
                                isAvailable: true,
                                action: { loadTemplate(.shortFilm) }
                            )

                            TemplateCard(
                                type: .featureFilm,
                                isAvailable: true,
                                action: { loadTemplate(.featureFilm) }
                            )

                            TemplateCard(
                                type: .tvShow,
                                isAvailable: false,
                                action: { loadTemplate(.tvShow) }
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    Text("Items will replace your current budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("Templates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if isLoadingTemplate {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(2)
                                .tint(.white)
                            Text("Loading template...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(40)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .alert(item: $alertConfig) { config in
                Alert(
                    title: Text(config.title),
                    message: Text(config.message),
                    dismissButton: .default(Text("OK")) {
                        if config.kind == .success {
                            dismiss()
                        }
                    }
                )
            }
            .alert("Delete Template?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let template = templateToDelete {
                        viewModel.deleteCustomTemplate(template)
                    }
                }
            } message: {
                Text("This will permanently delete \"\(templateToDelete?.name ?? "this template")\". This cannot be undone.")
            }
        }
    }

    private func loadCustomTemplate(_ template: CustomBudgetTemplate) {
        guard !isLoadingTemplate else { return }

        isLoadingTemplate = true
        Task {
            defer { isLoadingTemplate = false }
            do {
                let itemCount = try viewModel.loadCustomTemplate(template)
                await MainActor.run {
                    alertConfig = AlertConfig(
                        title: "Template Loaded",
                        message: "Imported \(itemCount) line items from \"\(template.name)\".",
                        kind: .success
                    )
                }
            } catch {
                await MainActor.run {
                    alertConfig = AlertConfig(
                        title: "Failed to Load Template",
                        message: error.localizedDescription,
                        kind: .error
                    )
                }
            }
        }
    }
    
    private func loadTemplate(_ type: TemplateType) {
        switch type {
        case .featureFilm:
            loadFeatureFilmTemplate()
        case .shortFilm:
            loadShortFilmTemplate()
        case .tvShow:
            // Coming soon - show alert
            alertConfig = AlertConfig(
                title: "Coming Soon",
                message: "\(type.title) template will be available in a future update.",
                kind: .error
            )
        }
    }
    
    private func loadFeatureFilmTemplate() {
        print("🚀 TemplateSelectionView: loadFeatureFilmTemplate() called")
        guard !isLoadingTemplate else {
            print("⚠️ Already loading template, returning")
            return
        }
        
        print("⏳ Setting isLoadingTemplate = true")
        isLoadingTemplate = true
        Task {
            print("📱 Task started")
            defer {
                print("🔄 Task defer block - setting isLoadingTemplate = false")
                isLoadingTemplate = false
            }
            do {
                print("🎯 About to call viewModel.loadStandardTemplateWithResult()")
                let itemCount = try viewModel.loadStandardTemplateWithResult()
                print("✅ Successfully loaded \(itemCount) items in Task")
                await MainActor.run {
                    // Load the default categories for feature film template
                    viewModel.loadDefaultCategories(for: .featureFilm)
                    alertConfig = AlertConfig(
                        title: "Template Loaded",
                        message: "Imported \(itemCount) line items from Feature Film template.",
                        kind: .success
                    )
                }
            } catch {
                print("❌ Task caught error: \(error)")
                print("❌ Error localized description: \(error.localizedDescription)")
                await MainActor.run {
                    alertConfig = AlertConfig(
                        title: "Failed to Load Template",
                        message: error.localizedDescription,
                        kind: .error
                    )
                }
            }
        }
        print("🏁 loadFeatureFilmTemplate() function completed (Task is running async)")
    }

    private func loadShortFilmTemplate() {
        print("🚀 TemplateSelectionView: loadShortFilmTemplate() called")
        guard !isLoadingTemplate else {
            print("⚠️ Already loading template, returning")
            return
        }

        print("⏳ Setting isLoadingTemplate = true")
        isLoadingTemplate = true
        Task {
            print("📱 Task started for Short Film template")
            defer {
                print("🔄 Task defer block - setting isLoadingTemplate = false")
                isLoadingTemplate = false
            }
            do {
                print("🎯 About to call viewModel.loadShortFilmTemplate()")
                let itemCount = try viewModel.loadShortFilmTemplate()
                print("✅ Successfully loaded \(itemCount) items in Task")
                await MainActor.run {
                    // Load the default categories for short film template
                    viewModel.loadDefaultCategories(for: .shortFilm)
                    alertConfig = AlertConfig(
                        title: "Template Loaded",
                        message: "Imported \(itemCount) line items from Short Film template.",
                        kind: .success
                    )
                }
            } catch {
                print("❌ Task caught error: \(error)")
                print("❌ Error localized description: \(error.localizedDescription)")
                await MainActor.run {
                    alertConfig = AlertConfig(
                        title: "Failed to Load Template",
                        message: error.localizedDescription,
                        kind: .error
                    )
                }
            }
        }
        print("🏁 loadShortFilmTemplate() function completed (Task is running async)")
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let type: TemplateSelectionView.TemplateType
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: isAvailable ? action : {}) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(type.color.gradient)
                    .frame(width: 60)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(type.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if !isAvailable {
                            Text("Soon")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .cornerRadius(6)
                        }
                    }
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Text(type.itemCount)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(type.color)
                }
                
                Spacer()
                
                // Arrow
                if isAvailable {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(type.color)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isAvailable ? type.color.opacity(0.3) : Color.gray.opacity(0.2),
                        lineWidth: 2
                    )
            )
            .opacity(isAvailable ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

// MARK: - Custom Template Card

private struct CustomTemplateCard: View {
    let template: CustomBudgetTemplate
    let action: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "doc.badge.gearshape.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !template.description.isEmpty {
                        Text(template.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Label("\(template.itemCount) items", systemImage: "list.bullet")
                        Label("\(template.categoryCount) categories", systemImage: "folder")
                    }
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }

                Spacer()

                // Actions
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    Text(template.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    #if os(macOS)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    #else
                    .fill(Color(uiColor: .secondarySystemBackground))
                    #endif
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: deleteAction) {
                Label("Delete Template", systemImage: "trash")
            }
        }
    }
}

// MARK: - Save Custom Template View

private struct SaveCustomTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel

    @State private var templateName: String = ""
    @State private var templateDescription: String = ""
    @State private var showSuccessAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save Custom Template")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Save your current budget as a reusable template")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .customTooltip("Close")
            }
            .padding(20)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Template Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.badge.gearshape")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.orange)
                            Text("Template Information")
                                .font(.system(size: 14, weight: .semibold))
                        }

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Name")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)

                                TextField("My Custom Template", text: $templateName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack(alignment: .top, spacing: 12) {
                                Text("Description")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)

                                TextEditor(text: $templateDescription)
                                    .font(.system(size: 13))
                                    .frame(minHeight: 60)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            #if os(macOS)
                                            .fill(Color(nsColor: .textBackgroundColor))
                                            #else
                                            .fill(Color(uiColor: .secondarySystemBackground))
                                            #endif
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            #if os(macOS)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            #else
                            .fill(Color(uiColor: .secondarySystemBackground))
                            #endif
                    )

                    // Template Preview Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "eye")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.blue)
                            Text("Template Preview")
                                .font(.system(size: 14, weight: .semibold))
                        }

                        VStack(spacing: 12) {
                            HStack {
                                Label("\(viewModel.lineItems.count) line items", systemImage: "list.bullet")
                                Spacer()
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                            HStack {
                                Label("\(viewModel.customCategories.count) categories", systemImage: "folder")
                                Spacer()
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Categories included:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)

                                BudgetFlowLayout(spacing: 8) {
                                    ForEach(viewModel.customCategories) { category in
                                        HStack(spacing: 4) {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 10))
                                            Text(category.name)
                                                .font(.system(size: 11))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(category.color.opacity(0.15))
                                        )
                                        .foregroundStyle(category.color)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            #if os(macOS)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            #else
                            .fill(Color(uiColor: .secondarySystemBackground))
                            #endif
                    )
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save Template") {
                    saveTemplate()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 480, height: 520)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .alert("Template Saved", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your template \"\(templateName)\" has been saved and can be loaded from the Templates menu.")
        }
    }

    private func saveTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        _ = viewModel.saveAsCustomTemplate(name: name, description: templateDescription)
        showSuccessAlert = true
    }
}

// MARK: - Flow Layout for Category Tags

private struct BudgetFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            height = y + rowHeight
        }
    }
}

// MARK: - Rate Cards View

private struct RateCardsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingAddRateCard = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.rateCards, id: \.id) { rateCard in
                    RateCardRow(rateCard: rateCard)
                }
                .onDelete { offsets in
                    for index in offsets {
                        viewModel.deleteRateCard(viewModel.rateCards[index])
                    }
                }
            }
            .navigationTitle("Rate Cards")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRateCard = true
                    } label: {
                        Label("Add Rate Card", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if viewModel.rateCards.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No Rate Cards")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Create rate cards to quickly apply standard rates to budget items")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
            .sheet(isPresented: $showingAddRateCard) {
                AddRateCardView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Rate Card Row

private struct RateCardRow: View {
    let rateCard: RateCardEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rateCard.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(rateCard.formattedRate)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            HStack {
                Label(rateCard.categoryType, systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Label(rateCard.defaultUnit ?? "N/A", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let notes = rateCard.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Rate Card View

private struct AddRateCardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel
    
    @State private var name: String = ""
    @State private var category: String = "Cast"
    @State private var unit: String = "Day"
    @State private var rateValue: String = ""
    @State private var notes: String = ""
    
    private let categories = ["Cast", "Crew", "Vendor", "Equipment", "Location"]
    private let units = ["Day", "Week", "Flat Rate", "Hourly", "Per Item"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Rate Card Details") {
                    TextField("Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    Picker("Unit", selection: $unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    
                    HStack {
                        Text("Rate")
                        Spacer()
                        TextField("0.00", text: $rateValue)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Rate Card")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let rate = Double(rateValue) {
                            viewModel.createRateCard(
                                name: name,
                                category: category,
                                unit: unit,
                                rate: rate,
                                notes: notes
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || rateValue.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

struct BudgetView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
