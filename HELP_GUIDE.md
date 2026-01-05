# Production Runner Help Guide

## Table of Contents
1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Dashboard](#dashboard)
4. [Application Modules](#application-modules)
   - [Calendar](#calendar)
   - [Contacts](#contacts)
   - [Screenplay](#screenplay)
   - [Breakdowns](#breakdowns)
   - [Budgeting](#budgeting)
   - [Shots](#shots)
   - [Locations](#locations)
   - [Scheduler](#scheduler)
   - [Call Sheets](#call-sheets)
   - [Tasks](#tasks)
   - [Chat](#chat)
5. [Project Management](#project-management)
6. [Import & Export](#import--export)
7. [Keyboard Shortcuts](#keyboard-shortcuts)
8. [Troubleshooting](#troubleshooting)

---

## Overview

**Production Runner** is a comprehensive film and video production management application designed for macOS and iOS. It provides an all-in-one solution for managing every aspect of your production, from screenplay import to call sheet distribution.

### Key Features
- Full screenplay import with Final Draft (FDX) support
- Scene breakdown management
- Production scheduling with stripboard
- Budget tracking and rate cards
- Contact management (Cast, Crew, Vendors)
- Location scouting with map integration
- Call sheet generation
- Task management with reminders
- Production calendar with timeline view
- Shot list management

### Supported Platforms
- macOS (native SwiftUI)
- iOS/iPadOS (native SwiftUI)

---

## Getting Started

### Creating a New Project

1. Launch Production Runner
2. From the Projects Dashboard, click **"Create New Project"**
3. Choose a location to save your `.runner` project file
4. Enter your project name
5. Click **Create**

Your project is stored as a `.runner` package containing:
- Core Data database (`Store/ProductionRunner.sqlite`)
- Project manifest (`project.json`)
- Associated assets

### Opening an Existing Project

1. From the Projects Dashboard, click **"Open Project"**
2. Navigate to your `.runner` project file
3. Select and open

Recent projects appear in the sidebar for quick access.

### Project Settings

Access project settings via the gear icon in the toolbar:
- **Project Name**: Edit your production title
- **Start Date**: Principal photography start
- **Wrap Date**: Expected wrap date
- **Aspect Ratio**: Set your shooting format
- **Header Theme**: Choose from Aurora, Sunset, Ocean, Forest, Midnight, or Custom

---

## Dashboard

The Dashboard is your production command center, providing at-a-glance status for all modules.

### Dashboard Header
- **Project Name**: Displayed prominently
- **Live Clock**: Shows current time and location
- **Start/Wrap Dates**: Quick reference for production timeline

### Module Cards
Each app module is represented by a colored card showing:
- **Calendar**: Production date range
- **Contacts**: Cast/Crew/Vendor counts
- **Screenplay**: Draft status and scene count
- **Breakdowns**: Completion status
- **Budgeting**: Total budget and category count
- **Shots**: Number of shots added
- **Locations**: Location count and scout status
- **Scheduler**: Strip count and status
- **Call Sheets**: Number of call sheets created
- **Tasks**: Total and pending task counts
- **Chat**: Recent message preview

### Navigation
- Click any module card to navigate directly to that section
- Use the sidebar on the left for persistent navigation
- Access your account settings from the bottom of the sidebar

---

## Application Modules

### Calendar

The Production Calendar helps you plan and visualize your entire production timeline.

#### Event Types
- **Shoot Day** (Red): Principal photography days
- **Prep Day** (Orange): Pre-production preparation
- **Rehearsal** (Purple): Cast rehearsals
- **Location Scout** (Blue): Scouting appointments
- **Meeting** (Teal): Production meetings
- **Milestone** (Yellow): Key deadlines
- **Wrap Day** (Green): Wrap activities
- **Pre-Production** (Indigo): General prep work
- **Post-Production** (Pink): Post activities

#### View Modes
- **Month View**: Traditional calendar grid
- **Week View**: Detailed weekly schedule
- **Timeline View**: Gantt-style production timeline

#### Creating Events
1. Click on a date or use the **+** button
2. Select event type
3. Fill in event details:
   - Title
   - Date/Time
   - Location
   - Associated scenes
   - Crew assignments
   - Notes
4. Save the event

#### Features
- Color-coded events by type
- Custom colors available
- Multi-day event support
- Link events to locations and tasks
- Drag-and-drop reordering in timeline view

---

### Contacts

Manage all personnel involved in your production.

#### Categories
- **Cast**: Actors and performers
- **Crew**: Production team members
- **Vendors**: Equipment rentals, catering, etc.

#### Departments
- Production
- Art
- Grip and Electric
- Wardrobe
- Camera
- Sound

#### Contact Fields
- Name
- Role/Position
- Phone
- Email
- Allergies (important for catering)
- Paperwork status

#### Features
- **Search**: Find contacts instantly
- **Filter**: By category or department
- **Import**: CSV file support
- **Export**: Generate contact lists as PDF
- **Multi-select**: Bulk operations with Cmd+Click

#### Adding a Contact
1. Click the **+** button
2. Select category (Cast/Crew/Vendor)
3. Fill in contact information
4. Assign department if applicable
5. Save

---

### Screenplay

Import, view, and manage your screenplay with professional formatting.

#### View Modes
- **Writers View**: Full editing capabilities
- **Imported Script**: Read-only view of imported screenplay
- **Revised Scripts**: Version history and revision tracking

#### Import Formats
- **Final Draft (FDX)**: Full support with formatting preservation
- **Celtx**: Basic import (UI ready, parser in development)
- **Fade In**: Basic import (UI ready, parser in development)

#### Writers View Features
- Zoom controls (50% - 200%)
- Font size adjustment (8pt - 24pt)
- Text formatting: Bold, Italic, Underline, Strikethrough
- Element formatting:
  - ACTION
  - DIALOGUE
  - CHARACTER
  - SCENE HEADING
  - TRANSITION
  - PARENTHETICAL
- Title page toggle
- Page count display

#### Revision Tracking
The system supports industry-standard revision colors:
1. White (Initial)
2. Blue
3. Pink
4. Yellow
5. Green
6. Goldenrod
7. Buff
8. Salmon
9. Cherry

#### Importing a Script
1. Click **Import** in the toolbar
2. Select **Final Draft (FDX)**
3. Choose your FDX file
4. Enter revision name (e.g., "Initial White")
5. The script imports with full formatting

#### Features
- Professional Final Draft formatting
- Scene numbers in margins
- Revision marks and tracking
- Page break handling
- Bold/italic/underline preservation

---

### Breakdowns

Break down your screenplay into production elements.

#### Scene Information
- Scene number
- INT/EXT (Interior/Exterior)
- Scene heading
- Time of day (Day/Night/Dawn/Dusk)
- Page length
- Shooting location

#### Breakdown Elements
Add elements to each scene using color-coded chips:
- Cast members
- Props
- Wardrobe
- Special equipment
- Vehicles
- Animals
- Special effects
- And more...

#### Features
- Modern card-based interface
- Color-coded elements
- Search and filter scenes
- Sync with scheduler
- Map integration for locations

#### Working with Breakdowns
1. Select a scene from the list
2. View scene details in the inspector
3. Add elements by clicking **+** or typing
4. Elements appear as removable chips
5. Changes sync automatically to Scheduler

---

### Budgeting

Create and manage production budgets with version control.

#### Budget Versions
- Create multiple budget versions
- Compare different scenarios
- Rename and delete versions

#### Budget Categories
Standard film budget categories following industry norms:
- Above the Line
- Production
- Post-Production
- And more...

#### Features
- **Line Items**: Individual budget entries
- **Rate Cards**: Reusable rate templates
- **Templates**: Pre-built budget structures
- **Inspector Panel**: Detailed item editing
- **Search**: Find items quickly
- **Category Filtering**: View by category

#### Creating a Budget
1. Click **Load Template** or start from scratch
2. Select a budget version or create new
3. Add line items with:
   - Description
   - Category
   - Rate
   - Quantity
   - Total
4. Use Rate Cards for consistent pricing

#### Summary Header
View at-a-glance totals:
- Total Budget
- By Category
- Spent vs. Remaining

---

### Shots

Plan and organize your shot list scene by scene.

#### Interface
- **Scene Sidebar**: Browse scenes from your screenplay
- **Shot Detail Pane**: View and edit shots for selected scene

#### Shot Information
- Shot number
- Shot type (Wide, Medium, Close-up, etc.)
- Camera movement
- Description
- Equipment needed
- Notes

#### Features
- Scene-based organization
- Visual shot cards
- Sync with screenplay scenes
- Filter and search

#### Adding Shots
1. Select a scene from the sidebar
2. Click **Add Shot** in the detail pane
3. Configure shot details
4. Reorder shots by dragging

---

### Locations

Manage all shooting locations with scouting tools.

#### Location Information
- Location name
- Address
- Contact person
- Phone and email
- Permit status
- Scout date
- Scout status
- Notes
- GPS coordinates
- Photos

#### Permit Status Options
- Pending
- Approved
- Needs Scout
- Denied

#### Map Integration
- Apple Maps integration
- Address autocomplete
- View location on map
- Get directions

#### Photos
- Import multiple photos per location
- Photo gallery view
- Visual reference for crew

#### Features
- Search locations
- Filter by permit status
- Scout date scheduling
- Contact information storage
- GPS coordinates with map view

---

### Scheduler

Create your shooting schedule with a professional stripboard.

#### Stripboard Interface
- Visual scene strips with color coding
- Day breaks between shooting days
- Drag-and-drop reordering
- Inspector panel for details

#### Strip Types
- **Scene Strips**: Individual scenes
- **Day Breaks**: Mark new shooting days
- **Off Days**: Non-shooting days

#### Strip Information
Each strip displays:
- Scene number
- INT/EXT indicator
- Scene heading
- Time of day
- Page length
- Shooting location
- Color tint

#### Filtering
Filter scenes by:
- Search text
- Interior/Exterior
- Day/Night/Dawn/Dusk
- Location

#### Density Options
- **Compact**: More scenes visible
- **Medium**: Balanced view
- **Comfortable**: Detailed strips

#### Inspector Panel
View and edit for selected day:
- Selected date
- Call time
- Company moves
- Day notes
- Production overview

#### Features
- Multi-select with Shift/Cmd
- Keyboard navigation
- Delete scenes
- Sync with Breakdowns
- Auto-reload on changes

---

### Call Sheets

Generate professional call sheets for your crew.

#### Call Sheet Sections
1. **Header**: Production info, day number
2. **Overview**: Weather, times, locations
3. **Schedule**: Day's shooting order
4. **Cast**: Call times for actors
5. **Production Notes**: Important announcements
6. **Crew**: Department call times
7. **Advanced Schedule**: Upcoming days
8. **Safety First**: Safety reminders

#### Call Sheet Information
- Project name
- Production company
- Shoot date
- Day number / Total days
- Director, AD, Producer, DP
- General call, Shooting call, Crew call
- Breakfast, Lunch times
- Estimated wrap
- Location details with parking
- Weather information
- Sunrise/sunset times

#### Status Options
- Draft
- Ready
- Published

#### Features
- Section reordering
- Cast and crew management
- Schedule items
- Notes sections
- Export to PDF

---

### Tasks

Track production tasks with reminders.

#### Task Information
- Title
- Notes
- Reminder date/time
- Completion status

#### Features
- Search tasks
- Filter completed tasks
- Upcoming reminders on Dashboard
- Color-coded reminder urgency:
  - Red: Overdue
  - Orange: Due within 1 hour
  - Yellow: Due within 24 hours
  - Blue: Future tasks

#### Creating Tasks
1. Click **Add Task**
2. Enter title
3. Add optional notes
4. Set reminder date/time
5. Save

#### Task Management
- Toggle completion with checkbox
- Edit existing tasks
- Delete completed tasks
- View upcoming on Dashboard

---

### Chat

Team communication within your project.

#### Features
- Message history
- Team collaboration
- Message timestamps
- Recent message preview on Dashboard

---

## Project Management

### Project Files
Production Runner uses `.runner` packages to store all project data:
```
MyProject.runner/
├── project.json          # Project manifest
└── Store/
    └── ProductionRunner.sqlite  # Core Data database
```

### Auto-Save
Projects auto-save every 10 seconds and when:
- Switching projects
- App goes to background
- App closes

### Recent Projects
- Up to 10 recent projects tracked
- Security-scoped bookmarks for sandbox compliance
- Quick access from Projects Dashboard

### Switching Projects
1. Click **Switch Project** in toolbar (Cmd+Shift+L)
2. Select from recent projects or open new
3. Previous project saves automatically

---

## Import & Export

### Screenplay Import

#### Final Draft (FDX)
Full support for Final Draft files:
1. Go to Screenplay module
2. Click **Import** > **Final Draft (FDX)**
3. Select your `.fdx` file
4. Choose revision name
5. Script imports with full formatting

#### What's Preserved
- Scene headings with numbers
- All element types (action, dialogue, character, etc.)
- Bold, italic, underline formatting
- Page breaks
- Dual dialogue

### Contacts Import/Export

#### Import CSV
1. Go to Contacts module
2. Click **Import**
3. Select CSV file
4. Map columns to fields
5. Import contacts

#### Export PDF
1. Select contacts or use current filter
2. Click **Export**
3. Choose PDF format
4. Save contact list

### Call Sheet Export
- Export to PDF for distribution
- Print-ready formatting

---

## Keyboard Shortcuts

### Global
| Shortcut | Action |
|----------|--------|
| ⌘N | New Project |
| ⌘O | Open Project |
| ⌘S | Save |
| ⇧⌘L | Switch Project |

### Screenplay
| Shortcut | Action |
|----------|--------|
| ⌘B | Bold |
| ⌘I | Italic |
| ⌘U | Underline |
| ⌘+ | Zoom In |
| ⌘- | Zoom Out |

### Scheduler
| Shortcut | Action |
|----------|--------|
| ⌘N | Add Strip |
| Delete | Remove Selected |
| ↑↓ | Navigate Strips |
| ⇧Click | Multi-select Range |
| ⌘Click | Toggle Selection |

### Contacts
| Shortcut | Action |
|----------|--------|
| ⌘C | Copy |
| ⌘V | Paste |
| Delete | Remove Selected |

---

## Troubleshooting

### Common Issues

#### Script Not Displaying After Import
1. Ensure you selected "Imported Script" view mode
2. Check that the FDX file is valid
3. Try re-importing the file

#### Scenes Not Appearing in Scheduler
1. Import or create scenes in Breakdowns first
2. Check filter settings in Scheduler
3. Ensure scenes are synced (automatic)

#### Call Sheet Missing Information
1. Fill in project details in Settings
2. Add cast and crew in Contacts
3. Create schedule in Scheduler first

#### Project Won't Open
1. Ensure the `.runner` file exists
2. Check file permissions
3. Try creating a new project and importing data

#### Auto-Save Not Working
1. Check disk space
2. Ensure write permissions
3. App auto-saves every 10 seconds

### Performance Tips
- Close unused modules
- Archive completed projects
- Keep scene breakdowns concise
- Use filters to limit displayed items

### Getting Help
- Report issues: https://github.com/anthropics/claude-code/issues
- Check for updates regularly
- Backup your `.runner` files

---

## Version Information
- **App Version**: Production Runner 2025
- **Build Date**: 2025-12-17
- **Platforms**: macOS, iOS

---

*This guide covers Production Runner for Xcode. Features may vary between versions.*
