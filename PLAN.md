# Script Revision Sync Implementation Plan

## Overview
Wire up a complete script revision workflow that allows users to send revisions from Screenplay to Scheduler, Shots, and Breakdowns with intelligent merge capabilities.

---

## Architecture

### Central Service: `ScriptRevisionSyncService.swift` (NEW)
A singleton service that coordinates revision sync across all apps:
- Tracks "sent" revisions available for loading
- Notifies apps when new revisions are available
- Provides merge logic for loading revisions

---

## Implementation Steps

### Phase 1: Core Infrastructure

#### 1.1 Create ScriptRevisionSyncService.swift
Location: `/Production Runner/Services/ScriptRevisionSyncService.swift`

```swift
@MainActor
final class ScriptRevisionSyncService: ObservableObject {
    static let shared = ScriptRevisionSyncService()

    @Published var sentRevisions: [SentRevision] = []
    @Published var pendingUpdates: [AppType: SentRevision] = [:]

    enum AppType: String { case scheduler, shots, breakdowns }

    // Send a revision from Screenplay
    func sendRevision(_ revision: StoredRevision, document: ScreenplayDocument)

    // Load a revision into an app (with merge)
    func loadRevision(_ revision: SentRevision, into app: AppType, context: NSManagedObjectContext) async throws -> MergeResult

    // Check if updates are available for an app
    func hasUpdatesAvailable(for app: AppType) -> Bool
}
```

#### 1.2 Create SentRevision Model
```swift
struct SentRevision: Identifiable, Codable {
    let id: UUID
    let revisionId: UUID           // Reference to ScriptRevisionEntity
    let colorName: String
    let sentDate: Date
    let sceneCount: Int
    let pageCount: Int
    var loadedInScheduler: Bool
    var loadedInShots: Bool
    var loadedInBreakdowns: Bool
}
```

#### 1.3 Create MergeResult Model
```swift
struct MergeResult {
    let scenesAdded: [UUID]
    let scenesRemoved: [UUID]
    let scenesModified: [UUID]
    let conflicts: [MergeConflict]
    let preservedLocalEdits: Int
}

struct MergeConflict {
    let sceneId: UUID
    let sceneNumber: String
    let localChange: String
    let incomingChange: String
}
```

---

### Phase 2: Screenplay - "Send Revision" Feature

#### 2.1 Add "Send Revision" Button to Revisions View
Location: `ScreenplayEditorView.swift` around line 2027

Add a new button in the ACTIONS section:
```swift
Button(action: {
    sendRevisionToApps(revision)
}) {
    HStack(spacing: 6) {
        Image(systemName: "paperplane.fill")
        Text("Send to Apps")
    }
    ...
}
```

#### 2.2 Implement sendRevisionToApps Function
```swift
private func sendRevisionToApps(_ revision: StoredRevision) {
    Task {
        guard let document = revisionImporter.loadRevisionDocument(id: revision.id) else { return }
        await ScriptRevisionSyncService.shared.sendRevision(revision, document: document)

        // Post notification
        NotificationManager.shared.addNotification(
            title: "Script Revision Sent",
            message: "\(revision.displayName) is now available in Scheduler, Shots, and Breakdowns",
            category: .schedule
        )
    }
}
```

#### 2.3 Implement "Open in Editor" (Line 1997 TODO)
```swift
Button(action: {
    loadRevisionIntoEditor(revision)
}) {
    // existing UI
}

private func loadRevisionIntoEditor(_ revision: StoredRevision) {
    guard let document = revisionImporter.loadRevisionDocument(id: revision.id) else { return }
    currentDocument = document
    selectedRevisionId = nil
    selectedTab = .editor
}
```

---

### Phase 3: Add Notifications to Notifications.swift

#### 3.1 Add New Notification Category
```swift
enum NotificationCategory: String, Codable, CaseIterable {
    // existing...
    case scriptRevision = "Script Revision"  // NEW

    var icon: String {
        switch self {
        // existing...
        case .scriptRevision: return "doc.badge.arrow.up"
        }
    }

    var color: Color {
        switch self {
        // existing...
        case .scriptRevision: return .orange
        }
    }
}
```

#### 3.2 Add Notification.Name Extensions
```swift
extension Notification.Name {
    static let scriptRevisionSent = Notification.Name("scriptRevisionSent")
    static let scriptRevisionAvailable = Notification.Name("scriptRevisionAvailable")
    static let scriptRevisionLoaded = Notification.Name("scriptRevisionLoaded")
}
```

---

### Phase 4: Scheduler - Load Script Version

#### 4.1 Update ScheduleVersion Model
Location: `ScheduleVersion.swift`

Add script revision reference:
```swift
struct ScheduleVersion: Identifiable, Codable, Hashable {
    // existing properties...
    var scriptRevisionId: UUID?     // NEW: Reference to loaded script revision
    var scriptColorName: String?    // NEW: Color name for display
}
```

#### 4.2 Add Script Version Section to versionDropdown
Location: `SchedulerView.swift` line 588

Add new section before Schedule Versions:
```swift
Menu {
    // NEW: Script Versions Section
    Section("Script Revision") {
        if let currentScript = selectedVersion?.scriptRevisionId,
           let revision = ScriptRevisionSyncService.shared.getRevision(currentScript) {
            HStack {
                Circle().fill(revision.color).frame(width: 8, height: 8)
                Text(revision.displayName)
                Image(systemName: "checkmark")
            }
        } else {
            Text("No script loaded").foregroundStyle(.secondary)
        }

        Divider()

        ForEach(ScriptRevisionSyncService.shared.sentRevisions) { revision in
            Button(action: { loadScriptRevision(revision) }) {
                HStack {
                    Circle().fill(revision.color).frame(width: 8, height: 8)
                    Text(revision.displayName)
                    if hasNewChanges(revision) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    Divider()

    // existing Schedule Versions section...
}
```

#### 4.3 Add loadScriptRevision Function
```swift
private func loadScriptRevision(_ revision: SentRevision) {
    Task {
        let result = try await ScriptRevisionSyncService.shared.loadRevision(
            revision,
            into: .scheduler,
            context: moc
        )

        // Update version with script reference
        if var version = selectedVersion {
            version.scriptRevisionId = revision.revisionId
            version.scriptColorName = revision.colorName
            selectVersion(version)
        }

        // Show merge result
        showMergeResult(result)
        reload()
    }
}
```

#### 4.4 Add Update Available Indicator
In productionOverview or toolbar, add:
```swift
if ScriptRevisionSyncService.shared.hasUpdatesAvailable(for: .scheduler) {
    Button(action: { /* show available updates */ }) {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
            Text("Script Update Available")
        }
        .foregroundStyle(.orange)
    }
}
```

---

### Phase 5: Shots - Load Script Version

#### 5.1 Add State Variables
Location: `ShotListerView.swift`

```swift
@State private var currentScriptRevision: SentRevision? = nil
@State private var showScriptVersionPicker: Bool = false
@ObservedObject private var syncService = ScriptRevisionSyncService.shared
```

#### 5.2 Add Script Version Dropdown to Toolbar
Add near the top toolbar:
```swift
private var scriptVersionDropdown: some View {
    Menu {
        Section("Script Revision") {
            // Similar pattern to Scheduler
        }
    } label: {
        HStack {
            Image(systemName: "doc.text")
            Text(currentScriptRevision?.displayName ?? "Load Script")
            if syncService.hasUpdatesAvailable(for: .shots) {
                Circle().fill(.orange).frame(width: 6, height: 6)
            }
        }
    }
}
```

#### 5.3 Add Sync Functionality
Wire shots to receive scene data from script revisions.

---

### Phase 6: Breakdowns - Load Script Version

#### 6.1 Update Breakdowns View State
Location: `Breakdowns.swift` around line 460

```swift
// Existing
@State private var breakdownVersions: [BreakdownVersion] = []

// Add
@State private var currentScriptRevision: SentRevision? = nil
@ObservedObject private var syncService = ScriptRevisionSyncService.shared
```

#### 6.2 Add Script Version Dropdown
Add to toolbar (pattern similar to Scheduler):
```swift
private var scriptVersionDropdown: some View {
    Menu {
        Section("Script Revision") {
            // Current script info
            // Available revisions
            // Update indicator
        }
    } label: {
        // Similar styling to Scheduler
    }
}
```

#### 6.3 Update BreakdownVersion Model
```swift
struct BreakdownVersion: Identifiable, Codable, Hashable {
    // existing...
    var scriptRevisionId: UUID?    // NEW
    var scriptColorName: String?   // NEW
}
```

---

### Phase 7: Merge Logic

#### 7.1 Implement Smart Merge in ScriptRevisionSyncService

```swift
func mergeRevision(
    incoming: ScreenplayDocument,
    existing: [SceneEntity],
    context: NSManagedObjectContext
) async throws -> MergeResult {
    var result = MergeResult(...)

    // 1. Build maps by scene number and normalized hash
    let existingByNumber = Dictionary(grouping: existing) { $0.number }
    let incomingScenes = incoming.scenes

    // 2. Detect additions (new scenes not in existing)
    for scene in incomingScenes {
        if !existingByNumber.keys.contains(scene.number) {
            // Add new scene
            result.scenesAdded.append(createScene(from: scene, in: context))
        }
    }

    // 3. Detect removals (scenes no longer in script)
    let incomingNumbers = Set(incomingScenes.map { $0.number })
    for scene in existing {
        if let number = scene.number, !incomingNumbers.contains(number) {
            // Mark as omitted (don't delete - preserve local work)
            scene.provenance.insert(.removed)
            result.scenesRemoved.append(scene.objectID)
        }
    }

    // 4. Detect modifications (preserve local edits)
    for scene in incomingScenes {
        if let existingScene = existingByNumber[scene.number]?.first {
            if existingScene.hasLocalEdits {
                // Conflict - local edits exist
                result.conflicts.append(MergeConflict(
                    sceneId: existingScene.id,
                    sceneNumber: scene.number,
                    localChange: "Local edits exist",
                    incomingChange: "Script updated"
                ))
                result.preservedLocalEdits += 1
            } else {
                // Safe to update
                updateScene(existingScene, from: scene)
                result.scenesModified.append(existingScene.objectID)
            }
        }
    }

    return result
}
```

#### 7.2 Conflict Resolution UI
Create a simple conflict resolution view:
```swift
struct MergeConflictSheet: View {
    let conflicts: [MergeConflict]
    let onResolve: (MergeConflict, ConflictResolution) -> Void

    enum ConflictResolution {
        case keepLocal
        case useIncoming
        case keepBoth
    }
}
```

---

### Phase 8: Listen for Notifications in Each App

#### 8.1 Scheduler
```swift
.onReceive(NotificationCenter.default.publisher(for: .scriptRevisionSent)) { _ in
    // Refresh available revisions
    // Show update indicator
}
```

#### 8.2 Shots
```swift
.onReceive(NotificationCenter.default.publisher(for: .scriptRevisionSent)) { _ in
    // Same pattern
}
```

#### 8.3 Breakdowns
```swift
.onReceive(NotificationCenter.default.publisher(for: .scriptRevisionSent)) { _ in
    // Same pattern
}
```

---

## Files to Create

1. `/Services/ScriptRevisionSyncService.swift` - Central sync service
2. `/Models/SentRevision.swift` - Sent revision model
3. `/Models/MergeResult.swift` - Merge result and conflict models
4. `/Views/MergeConflictSheet.swift` - Conflict resolution UI

## Files to Modify

1. `Notifications.swift` - Add scriptRevision category and Notification.Name extensions
2. `ScreenplayEditorView.swift` - Add "Send to Apps" button, implement "Open in Editor"
3. `SchedulerView.swift` - Add script version dropdown section
4. `ScheduleVersion.swift` - Add scriptRevisionId property
5. `ShotListerView.swift` - Add script version dropdown
6. `Breakdowns.swift` - Add script version dropdown
7. `BreakdownVersion.swift` - Add scriptRevisionId property
8. `ScreenplayBreakdownSync.swift` - Extend to support merge operations

---

## Execution Order

1. Create core models (SentRevision, MergeResult)
2. Create ScriptRevisionSyncService
3. Update Notifications.swift
4. Add "Send Revision" to Screenplay
5. Add "Open in Editor" to Screenplay
6. Update ScheduleVersion model
7. Add script version dropdown to Scheduler
8. Add script version dropdown to Breakdowns
9. Add script version dropdown to Shots
10. Implement merge logic
11. Add conflict resolution UI
12. Wire notification listeners in all apps
13. Test end-to-end workflow

---

## Testing Checklist

- [ ] Import script in Screenplay
- [ ] Save as revision
- [ ] Send revision to apps
- [ ] Notification appears
- [ ] Load revision in Scheduler
- [ ] Load revision in Breakdowns
- [ ] Load revision in Shots
- [ ] Make local edits in Breakdowns
- [ ] Send new revision from Screenplay
- [ ] Verify merge preserves local edits
- [ ] Verify conflicts are detected and shown
