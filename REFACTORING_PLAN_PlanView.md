# PlanView.swift Refactoring Plan

**Created:** December 15, 2025
**Status:** In Progress
**Estimated Time:** 6-8 hours total
**Priority:** High (Maintainability)

---

## 📋 Overview

**Current State:**
- Single file: 4,867 lines
- 36+ types (structs, classes, enums)
- 50+ MARK sections
- 4 major feature areas (Ideas, Casting, Crew, Visuals)

**Target State:**
- ~40 separate files
- Average 120-200 lines per file
- Clear directory structure
- Easy navigation and testing

---

## 🎯 Refactoring Phases

### Phase 1: Extract Models (1-2 hours) ✅ STARTING NOW
**Goal:** Move all data models to separate files

**Files to Create:**
1. `Models/IdeaModels.swift` - IdeaNote, IdeaSection
2. `Models/CastingModels.swift` - CastingActor, IMDBSearchResult, IMDBPhoto
3. `Models/CrewModels.swift` - PlanCrewMember, CrewMemberOption
4. `Models/VisualsModels.swift` - VisualImage
5. `Models/PlanItem.swift` - PlanItem (legacy model)

**Dependencies:** None - can start immediately

---

### Phase 2: Extract Utilities (30 minutes)
**Goal:** Move transfer types and extensions

**Files to Create:**
1. `Utilities/PlanDragDropTypes.swift` - ActorDragItem, CrewDragItem
2. `Utilities/PlanUTType+Extensions.swift` - UTType extension

**Dependencies:** Phase 1 complete

---

### Phase 3: Extract Tab Views (2-3 hours)
**Goal:** Separate each major tab into its own file

**Files to Create:**
1. `Views/Ideas/IdeasTabView.swift`
2. `Views/Casting/CastingTabView.swift`
3. `Views/Crew/CrewTabView.swift`
4. `Views/Visuals/VisualsTabView.swift`

**Dependencies:** Phase 1 & 2 complete (models and utilities needed)

---

### Phase 4: Extract Supporting Views (2-3 hours)
**Goal:** Break down tab views into component views

**Ideas Supporting Views:**
- `Views/Ideas/IdeasSectionRow.swift`
- `Views/Ideas/IdeasNoteRow.swift`
- `Views/Ideas/IdeasSectionRowCD.swift`
- `Views/Ideas/IdeasNoteRowCD.swift`

**Casting Supporting Views:**
- `Views/Casting/CastingActorCard.swift`
- `Views/Casting/AddCastingActorSheet.swift`
- `Views/Casting/EditCastingActorSheet.swift`
- `Views/Casting/IMDBPhotoThumbnail.swift`
- `Views/Casting/IMDBSearchResultRow.swift`

**Crew Supporting Views:**
- `Views/Crew/PlanCrewMemberCard.swift`
- `Views/Crew/AddPlanCrewMemberSheet.swift`
- `Views/Crew/EditPlanCrewMemberSheet.swift`
- `Views/Crew/CrewDepartmentSection.swift`
- `Views/Crew/CrewMemberRow.swift`

**Visuals Supporting Views:**
- `Views/Visuals/VisualsWebView.swift`
- `Views/Visuals/VisualsWebViewState.swift`

**Dependencies:** Phase 3 complete

---

### Phase 5: Final Cleanup (30 minutes)
**Goal:** Clean up main PlanView.swift file

**Tasks:**
- Remove all extracted code
- Keep only PlanView struct and toolbar
- Add proper imports
- Verify all references work
- Update documentation

**Dependencies:** All previous phases complete

---

## 📁 Final Directory Structure

```
Applications/Plan/
├── PlanView.swift                          (~200 lines - main container)
│
├── Models/
│   ├── IdeaModels.swift                    (~30 lines)
│   ├── CastingModels.swift                 (~80 lines)
│   ├── CrewModels.swift                    (~50 lines)
│   ├── VisualsModels.swift                 (~20 lines)
│   └── PlanItem.swift                      (~40 lines)
│
├── Utilities/
│   ├── PlanDragDropTypes.swift             (~20 lines)
│   └── PlanUTType+Extensions.swift         (~15 lines)
│
├── Views/
│   ├── Ideas/
│   │   ├── IdeasTabView.swift              (~260 lines)
│   │   ├── IdeasSectionRow.swift           (~80 lines)
│   │   ├── IdeasNoteRow.swift              (~55 lines)
│   │   ├── IdeasSectionRowCD.swift         (~80 lines)
│   │   └── IdeasNoteRowCD.swift            (~55 lines)
│   │
│   ├── Casting/
│   │   ├── CastingTabView.swift            (~315 lines)
│   │   ├── CastingActorCard.swift          (~225 lines)
│   │   ├── AddCastingActorSheet.swift      (~480 lines)
│   │   ├── EditCastingActorSheet.swift     (~360 lines)
│   │   ├── IMDBPhotoThumbnail.swift        (~35 lines)
│   │   └── IMDBSearchResultRow.swift       (~75 lines)
│   │
│   ├── Crew/
│   │   ├── CrewTabView.swift               (~315 lines)
│   │   ├── PlanCrewMemberCard.swift        (~225 lines)
│   │   ├── AddPlanCrewMemberSheet.swift    (~460 lines)
│   │   ├── EditPlanCrewMemberSheet.swift   (~355 lines)
│   │   ├── CrewDepartmentSection.swift     (~135 lines)
│   │   └── CrewMemberRow.swift             (~50 lines)
│   │
│   └── Visuals/
│       ├── VisualsTabView.swift            (~550 lines)
│       ├── VisualsWebView.swift            (~100 lines)
│       └── VisualsWebViewState.swift       (~20 lines)
│
└── Shared/
    └── AddPlanItemSheet.swift              (~120 lines)
```

**Total:** ~40 files, averaging 120-200 lines each

---

## ✅ Verification Checklist

After each phase, verify:

- [ ] Project builds successfully
- [ ] No compiler errors
- [ ] No missing imports
- [ ] All views render correctly
- [ ] No broken references
- [ ] Git commit created with descriptive message

---

## 🔧 Implementation Steps (Detailed)

### Phase 1 - Step by Step:

#### Step 1.1: Create Models Directory
```bash
mkdir -p "Applications/Plan/Models"
```

#### Step 1.2: Extract IdeaModels
1. Read lines 241-270 from PlanView.swift
2. Create new file `Models/IdeaModels.swift`
3. Add proper imports (SwiftUI, Foundation)
4. Copy IdeaNote and IdeaSection structs
5. Save file

#### Step 1.3: Extract CastingModels
1. Read lines 855-895 from PlanView.swift
2. Create new file `Models/CastingModels.swift`
3. Add proper imports
4. Copy CastingActor, IMDBSearchResult, IMDBPhoto
5. Save file

#### Step 1.4: Extract CrewModels
1. Read lines 2375-2413 from PlanView.swift
2. Create new file `Models/CrewModels.swift`
3. Add proper imports
4. Copy PlanCrewMember, CrewMemberOption
5. Save file

#### Step 1.5: Extract VisualsModels
1. Read lines 3944-3957 from PlanView.swift
2. Create new file `Models/VisualsModels.swift`
3. Add proper imports
4. Copy VisualImage
5. Save file

#### Step 1.6: Extract PlanItem
1. Read lines 4609-4640 from PlanView.swift
2. Create new file `Models/PlanItem.swift`
3. Add proper imports
4. Copy PlanItem struct
5. Save file

#### Step 1.7: Update PlanView.swift
1. Remove extracted model definitions
2. Keep only references to models
3. Models will be accessible automatically (same module)

#### Step 1.8: Build & Test
```bash
# Build project
xcodebuild -scheme "Production Runner" build
```

---

## 📊 Progress Tracking

| Phase | Status | Files Created | Lines Reduced | Time Spent |
|-------|--------|---------------|---------------|------------|
| Phase 1 | 🟡 In Progress | 0/5 | 0 | 0h |
| Phase 2 | ⏳ Pending | 0/2 | 0 | 0h |
| Phase 3 | ⏳ Pending | 0/4 | 0 | 0h |
| Phase 4 | ⏳ Pending | 0/17 | 0 | 0h |
| Phase 5 | ⏳ Pending | - | - | 0h |

**Total Progress:** 0% (0/28 files created)

---

## ⚠️ Important Notes

### Things to Watch Out For:

1. **Preview Providers:** Each extracted file may need its own preview provider
2. **Internal Access:** Models are internal by default, should work within module
3. **Import Statements:** Each file needs appropriate imports (SwiftUI, CoreData, etc.)
4. **Circular Dependencies:** Avoid - models shouldn't import views
5. **Build After Each Phase:** Don't wait until end to verify

### Best Practices:

- ✅ One commit per phase (easier to rollback)
- ✅ Test build after each file extraction
- ✅ Keep git history clean
- ✅ Add file headers with description
- ✅ Maintain existing functionality exactly

---

## 🎓 Learning Outcomes

After this refactoring:
- Better understanding of SwiftUI file organization
- Experience with large-scale refactoring
- Improved code navigation skills
- Foundation for future features

---

## 📝 Post-Refactoring Tasks

Once complete:
1. Update project documentation
2. Consider unit tests for models
3. Review extracted files for further optimization
4. Update team on new structure
5. Consider similar refactoring for other large files

---

## 🚀 Let's Begin!

**Starting with:** Phase 1 - Extract Models
**Next Update:** After each model file is created
**Estimated Completion:** Phase 1 complete in 1-2 hours

---

*This plan will be updated as we progress through each phase.*
