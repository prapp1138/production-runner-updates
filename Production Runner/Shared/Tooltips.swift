//
//  Tooltips.swift
//  Production Runner
//
//  Centralized tooltip strings for all apps and UI elements.
//  Use this file as the single source of truth for all user-facing help text.
//  Organized by app/module for easy maintenance and localization.
//

import Foundation

/// Centralized tooltip strings for the Production Runner app suite.
/// All tooltips are organized by module/app for easy maintenance.
enum Tooltips {

    // MARK: - Authentication

    enum Auth {
        // Login
        static let emailField = "Enter your registered email address"
        static let passwordField = "Enter your account password"
        static let signInButton = "Sign in to your account"
        static let forgotPasswordButton = "Reset your password via email"
        static let createAccountButton = "Create a new Production Runner account"

        // Sign Up
        static let displayNameField = "Your name as it will appear to team members"
        static let confirmPasswordField = "Re-enter your password to confirm"
        static let createAccountSubmit = "Create your account and send verification email"
        static let backToLoginButton = "Return to the sign in screen"
        static let closeButton = "Close this window"

        // Password Reset
        static let resetEmailField = "Enter the email associated with your account"
        static let sendResetButton = "Send password reset link to your email"
        static let backToSignInButton = "Return to the sign in screen"
    }

    // MARK: - Dashboard & Settings

    enum Dashboard {
        // Project Actions
        static let newProject = "Create a new production project"
        static let openProject = "Open an existing project"
        static let saveProject = "Save the current project"
        static let closeProject = "Close the current project"
        static let projectSettings = "Open project settings"

        // App Navigation
        static let breakdownsApp = "Scene breakdowns and element management"
        static let budgetingApp = "Budget tracking and financial management"
        static let callSheetApp = "Create and manage call sheets"
        static let schedulerApp = "Production scheduling and stripboard"
        static let screenplayApp = "Screenplay editor and script management"
        static let shotListApp = "Shot planning and storyboarding"
        static let planApp = "Pre-production planning and ideas"
        static let contactsApp = "Cast and crew contact management"
        static let locationsApp = "Location scouting and management"
        static let chatApp = "Team communication"
        static let calendarApp = "Production calendar and events"
        static let designApp = "Mood boards and visual references"
        static let paperworkApp = "Production paperwork and forms"
        static let liveModeApp = "On-set live production tools"
        static let scriptyApp = "Script supervising tools"
    }

    enum Settings {
        // Window Controls
        static let closeSettings = "Close settings window"
        static let saveChanges = "Save all changes and close"
        static let cancelChanges = "Discard changes and close"

        // Project Title
        static let editProjectName = "Click to edit the project name"
        static let confirmProjectName = "Confirm project name change"

        // Basic Info
        static let productionCompany = "Your production company name"
        static let projectStatus = "Current status of the production"

        // Typography
        static let fontFamily = "Choose the typeface for project titles"
        static let fontSize = "Adjust the size of project title text"

        // Header Colors
        static let colorPreset = "Choose a color theme for the dashboard header"
        static let customHue = "Adjust the hue for custom header color"
        static let colorIntensity = "Adjust the intensity of the header gradient"

        // Roles Management
        static let searchRoles = "Search for crew roles"
        static let addCustomRole = "Add a new custom crew role"
        static let expandCategory = "Click to expand or collapse this category"
        static let deleteRole = "Delete this custom role"
    }

    // MARK: - Breakdowns

    enum Breakdowns {
        // Tabs
        static let elementsTab = "View and edit scene elements"
        static let reportsTab = "Generate breakdown reports"

        // Toolbar
        static let importFDX = "Import scenes from Final Draft (.fdx)"
        static let importPDF = "Import scenes from PDF script"
        static let screenplayDraftPicker = "Select screenplay draft to sync with"
        static let newVersion = "Create a new breakdown version"
        static let renameVersion = "Rename the current version"
        static let deleteVersion = "Delete the current version"
        static let exportPDF = "Export breakdowns as PDF"
        static let showInspector = "Show or hide the inspector panel"

        // Scene List
        static let sceneRow = "Click to select, double-click to expand"
        static let expandScene = "Expand to view scene details"
        static let deleteScene = "Delete selected scene(s)"

        // Elements
        static let addCastMember = "Add a cast member to this scene"
        static let removeCastMember = "Remove this cast member from the scene"
        static let addElement = "Add an element to this category"
        static let removeElement = "Remove this element"
        static let locationPicker = "Select or search for a location"
        static let timeOfDay = "Set the time of day for this scene"
        static let locationType = "Set interior or exterior"

        // Categories
        static let castSection = "Principal cast members in this scene"
        static let extrasSection = "Background actors and extras"
        static let stuntsSection = "Stunt performers and coordinators"
        static let propsSection = "Props required for this scene"
        static let wardrobeSection = "Costume and wardrobe items"
        static let vehiclesSection = "Vehicles appearing in scene"
        static let makeupSection = "Special makeup requirements"
        static let sfxSection = "Practical special effects"
        static let vfxSection = "Visual effects requirements"
        static let specialEquipmentSection = "Special equipment needed"
        static let notesSection = "Additional notes for this scene"
    }

    // MARK: - Budgeting

    enum Budgeting {
        // Tabs
        static let lineItemsTab = "View budget line items"
        static let transactionsTab = "View transactions and expenses"
        static let costTrackingTab = "Track costs against budget"
        static let costOfSceneTab = "View costs by scene"

        // Toolbar
        static let addItem = "Add a new budget line item"
        static let addTransaction = "Record a new transaction"
        static let rateCards = "Manage rate cards for crew and equipment"
        static let saveTemplate = "Save current budget as a template"
        static let newVersion = "Create a new budget version"
        static let renameVersion = "Rename the current version"
        static let deleteVersion = "Delete the current version"
        static let clearAll = "Clear all budget items"
        static let sortPicker = "Change how items are sorted"
        static let searchBudget = "Search budget items"
        static let showInspector = "Show or hide the inspector panel"

        // Items
        static let editItem = "Edit this budget item"
        static let deleteItem = "Delete this budget item"
        static let categoryPicker = "Select budget category"
        static let amountField = "Enter the budgeted amount"
        static let actualField = "Enter the actual spent amount"
    }

    // MARK: - Call Sheets

    enum CallSheet {
        // Toolbar
        static let newCallSheet = "Create a new call sheet"
        static let editCallSheet = "Edit the selected call sheet"
        static let duplicateCallSheet = "Duplicate the selected call sheet"
        static let deleteCallSheet = "Delete the selected call sheet"
        static let exportCallSheet = "Export call sheet as PDF"
        static let searchCallSheets = "Search call sheets"
        static let sortOrder = "Change sort order"
        static let viewModeGrid = "View as grid"
        static let viewModeList = "View as list"

        // Editor
        static let shootDate = "Date of the shoot"
        static let dayNumber = "Shoot day number"
        static let totalDays = "Total days in schedule"
        static let crewCall = "General crew call time"
        static let shootingLocation = "Primary shooting location"
        static let projectName = "Name of the production"
        static let addCrewMember = "Add crew member to call sheet"
        static let addCastMember = "Add cast member to call sheet"
        static let addScene = "Add scene to call sheet"
        static let saveCallSheet = "Save call sheet changes"
        static let closeEditor = "Close editor without saving"
    }

    // MARK: - Scheduler

    enum Scheduler {
        // Tabs
        static let stripboardTab = "View and organize the stripboard"
        static let doodTab = "Day Out of Days report"
        static let callSheetsTab = "Manage call sheets"

        // Toolbar
        static let newStrip = "Add a new strip to the stripboard"
        static let dayBreak = "Insert a day break"
        static let offDay = "Insert an off day (weekend/holiday)"
        static let banner = "Add a banner strip"
        static let deleteStrip = "Delete selected strip(s)"
        static let duplicateStrip = "Duplicate selected strip(s)"
        static let exportPDF = "Export schedule as PDF"
        static let printSchedule = "Print the schedule"
        static let stripColors = "Customize strip colors"
        static let density = "Change row density (compact/medium/comfortable)"
        static let showInspector = "Show or hide the inspector panel"
        static let showElements = "Show elements column"
        static let showShots = "Show shots count column"
        static let locationSync = "Sync locations across scenes"

        // Filters
        static let filterInt = "Show interior scenes"
        static let filterExt = "Show exterior scenes"
        static let filterDay = "Show day scenes"
        static let filterNight = "Show night scenes"
        static let filterDawn = "Show dawn scenes"
        static let filterDusk = "Show dusk scenes"
        static let searchScenes = "Search scenes"

        // Version Management
        static let versionDropdown = "Select schedule version"
        static let newVersion = "Create a new schedule version"
        static let renameVersion = "Rename the current version"
        static let deleteVersion = "Delete the current version"

        // Inspector
        static let sceneDataTab = "View and edit scene data"
        static let overviewTab = "View schedule overview"
        static let setDates = "Set production start date and schedule dates"
        static let generateCallSheet = "Generate call sheet for selected day"
    }

    // MARK: - Screenplay Editor

    enum ScreenplayEditor {
        // View Modes
        static let writersMode = "Edit screenplay in writing mode"
        static let importedMode = "View imported script"

        // Toolbar
        static let appearanceMode = "Switch between light, dark, or system appearance"
        static let zoomLevel = "Adjust page zoom level"
        static let showInspector = "Show or hide the inspector panel"
        static let elementType = "Select script element type"
        static let importFDX = "Import Final Draft (.fdx) file"
        static let exportPDF = "Export screenplay as PDF"

        // Inspector Tabs
        static let scenesTab = "View and navigate to scenes"
        static let commentsTab = "View and manage comments"
        static let revisionsTab = "Manage script revisions"

        // Revisions
        static let saveRevision = "Save current draft as a revision"
        static let deleteRevision = "Delete selected revision"
        static let revisionColor = "Select revision color"
        static let lockScript = "Lock script to prevent editing"
        static let unlockScript = "Unlock script for editing"

        // Documents
        static let newDraft = "Create a new screenplay draft"
        static let renameDraft = "Rename the current draft"
        static let deleteDraft = "Delete the current draft"
        static let closeDraft = "Close the current draft"
    }

    // MARK: - Shot List

    enum ShotList {
        // View Modes
        static let shotsView = "View and edit shot list"
        static let storyboardView = "View reference shot layout"
        static let topDownView = "Top-down set layout view"

        // Toolbar
        static let aspectRatio = "Select frame aspect ratio"
        static let cameraSelector = "Select camera system"
        static let lensPackage = "Select lens package"
        static let showInspector = "Show or hide the inspector panel"
        static let drawingTool = "Select drawing tool for top-down view"
        static let showStoryboard = "Show reference shot popup"
        static let browserPopup = "Open reference browser"

        // Scene List
        static let sceneRow = "Click to view shots for this scene"
        static let addShot = "Add a new shot"
        static let deleteShot = "Delete selected shot"
        static let duplicateShot = "Duplicate selected shot"

        // Shot Details
        static let shotType = "Select shot type (wide, medium, close-up, etc.)"
        static let cameraMovement = "Select camera movement"
        static let shotDescription = "Describe the shot"
        static let storyboardImage = "Click to add or change reference shot image"

        // Reference Shot
        static let expandScene = "Expand scene to show all shots"
        static let collapseScene = "Collapse scene"
        static let zoomIn = "Zoom in on reference shots"
        static let zoomOut = "Zoom out on reference shots"
    }

    // MARK: - Plan

    enum Plan {
        // Tabs
        static let ideasTab = "Capture and organize ideas"
        static let castingTab = "Track casting choices"
        static let crewTab = "Plan crew positions"

        // Toolbar
        static let addItem = "Add new item to current section"

        // Ideas
        static let addSection = "Create a new idea section"
        static let renameSection = "Rename this section"
        static let deleteSection = "Delete this section and all notes"
        static let addNote = "Add a new note"
        static let deleteNote = "Delete this note"

        // Casting
        static let addActor = "Add an actor to consider"
        static let editActor = "Edit actor details"
        static let deleteActor = "Remove this actor"
        static let roleField = "Character role this actor is considered for"

        // Crew
        static let addCrewMember = "Add a crew position"
        static let editCrewMember = "Edit crew member details"
        static let deleteCrewMember = "Remove this crew member"
    }

    // MARK: - Contacts

    enum Contacts {
        // Toolbar
        static let addContact = "Add a new contact"
        static let deleteContact = "Delete selected contact(s)"
        static let searchContacts = "Search contacts by name, role, or department"
        static let importContacts = "Import contacts from file"
        static let exportContacts = "Export contacts to PDF or CSV"
        static let manageDepartments = "Manage production departments"
        static let manageUnits = "Manage production units"

        // Filters
        static let filterAll = "Show all contacts"
        static let filterCast = "Show cast members only"
        static let filterCrew = "Show crew members only"
        static let filterVendors = "Show vendors only"
        static let departmentFilter = "Filter by department"

        // Contact Fields
        static let nameField = "Contact's full name"
        static let roleField = "Job title or role"
        static let phoneField = "Phone number"
        static let emailField = "Email address"
        static let allergiesField = "Dietary restrictions or allergies"
        static let categoryPicker = "Select cast, crew, or vendor"
        static let departmentPicker = "Select department"
        static let paperworkStarted = "Paperwork has been started"
        static let paperworkComplete = "All paperwork is complete"
    }

    // MARK: - Locations

    enum Locations {
        // Toolbar
        static let addLocation = "Add a new location"
        static let deleteLocation = "Delete selected location"
        static let searchLocations = "Search locations"
        static let showMapView = "Show locations on map"
        static let showListView = "Show locations as list"

        // Location Fields
        static let locationName = "Name or description of location"
        static let addressField = "Street address"
        static let notesField = "Additional notes about this location"
        static let addPhoto = "Add a photo of this location"
        static let deletePhoto = "Remove this photo"
        static let contactInfo = "Location contact information"
        static let permitRequired = "Mark if filming permit is required"
    }

    // MARK: - Chat

    enum Chat {
        static let messageInput = "Type your message"
        static let sendMessage = "Send message"
        static let attachFile = "Attach a file"
        static let emojiPicker = "Add emoji"
    }

    // MARK: - Calendar

    enum Calendar {
        // View Controls
        static let todayButton = "Jump to today"
        static let previousButton = "Go to previous period"
        static let nextButton = "Go to next period"
        static let dayView = "View by day"
        static let weekView = "View by week"
        static let monthView = "View by month"

        // Events
        static let addEvent = "Create a new calendar event"
        static let editEvent = "Edit this event"
        static let deleteEvent = "Delete this event"
    }

    // MARK: - Design / Mood Board

    enum Design {
        // Toolbar
        static let addImage = "Add an image to the mood board"
        static let deleteImage = "Delete selected image"
        static let uploadImage = "Upload an image file"
        static let organizeImages = "Arrange images on the board"

        // Director's Notebook
        static let saveNotes = "Save director's notes"
        static let formatBold = "Bold text"
        static let formatItalic = "Italic text"
        static let addHeading = "Insert a heading"
    }

    // MARK: - Paperwork

    enum Paperwork {
        static let generatePaperwork = "Generate production paperwork"
        static let downloadPaperwork = "Download paperwork as file"
        static let printPaperwork = "Print paperwork"
        static let editPaperwork = "Edit paperwork content"
        static let templateSelector = "Select paperwork template"
    }

    // MARK: - Live Mode

    enum LiveMode {
        // Categories
        static let realTimeCategory = "Real-time on-set tools"
        static let newAppsCategory = "Additional production apps"
        static let viewOnlyCategory = "View-only reference tools"

        // Real Time
        static let digitalCallSheetShotList = "View today's call sheet and shot list"
        static let dayByDayBudget = "Track daily spending"
        static let addTimes = "Record scene timing data"
        static let teleprompter = "Display teleprompter text"

        // Teleprompter
        static let playPause = "Start or pause scrolling"
        static let scrollSpeed = "Adjust scroll speed"
        static let textSize = "Adjust text size"

        // View Only
        static let directorsNotes = "View director's notes"
        static let storyboardViewer = "View storyboard"
        static let scriptSupervising = "View script notes"
        static let cameraNotes = "View camera notes"
        static let soundNotes = "View sound notes"
        static let projectNotes = "View project notes"

        // New Apps
        static let wrapReport = "Fill out wrap report"
        static let productionReport = "Complete production report"
        static let signatures = "Collect digital signatures"
        static let signaturePad = "Draw your signature"
        static let clearSignature = "Clear and start over"
        static let confirmSignature = "Confirm signature"
    }

    // MARK: - Scripty (Script Supervising)

    enum Scripty {
        static let takeNumber = "Current take number"
        static let pageNumber = "Script page number"
        static let timingStart = "Start timing for this take"
        static let timingStop = "Stop timing"
        static let timingReset = "Reset timer"
        static let takeNotes = "Notes for this take"
        static let takeStatus = "Mark take as good, print, or false start"
        static let previousTake = "Go to previous take"
        static let nextTake = "Go to next take"
        static let addTake = "Add a new take"
    }

    // MARK: - Common / Shared

    enum Common {
        // Window Controls
        static let close = "Close"
        static let save = "Save changes"
        static let cancel = "Cancel"
        static let delete = "Delete"
        static let edit = "Edit"
        static let add = "Add"
        static let duplicate = "Duplicate"
        static let export = "Export"
        static let print = "Print"
        static let search = "Search"
        static let filter = "Filter"
        static let refresh = "Refresh"
        static let undo = "Undo"
        static let redo = "Redo"

        // Inspector
        static let showInspector = "Show inspector panel"
        static let hideInspector = "Hide inspector panel"

        // Navigation
        static let back = "Go back"
        static let forward = "Go forward"
        static let home = "Return to home"

        // View Modes
        static let gridView = "View as grid"
        static let listView = "View as list"
        static let expandAll = "Expand all"
        static let collapseAll = "Collapse all"
    }
}
