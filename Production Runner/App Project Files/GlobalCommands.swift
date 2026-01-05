//
//  GlobalCommands.swift
//  Production Runner
//
//  Created by Editing on 11/2/25.
//

import SwiftUI
#if os(macOS)
import AppKit
import Sparkle
#endif

struct GlobalCommands: Commands {
    @CommandsBuilder
    var body: some Commands {
        fileMenuCommands
        editMenuCommands
        viewMenuCommands
        goMenuCommands
        windowMenuCommands
        helpMenuCommands
        projectMenuCommands
        userMenuCommands
    }

    // MARK: - File Menu Commands
    @CommandsBuilder
    var fileMenuCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                NotificationCenter.default.post(name: .prNewProject, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])
            
            Button("Open Project…") {
                NotificationCenter.default.post(name: .prOpenProject, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        
        CommandGroup(replacing: .saveItem) {
            Button("Save Project") {
                NotificationCenter.default.post(name: .prSaveProject, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command])
            
            Button("Save Project As…") {
                NotificationCenter.default.post(name: .prSaveProjectAs, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        
        CommandGroup(replacing: .importExport) {
            Button("Import…") {
                NotificationCenter.default.post(name: .prImport, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Export…") {
                NotificationCenter.default.post(name: .prExport, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Close") {
                NotificationCenter.default.post(name: .prClose, object: nil)
            }
            .keyboardShortcut("w", modifiers: [.command])

            Button("Close Project") {
                NotificationCenter.default.post(name: .prCloseProject, object: nil)
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])

            Divider()

            Button("Switch Project") {
                NotificationCenter.default.post(name: .prSwitchProject, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }

    // MARK: - Edit Menu Commands
    @CommandsBuilder
    var editMenuCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                #if os(macOS)
                // Try native action first (for standard text fields)
                NSApp.sendAction(NSSelectorFromString("undo:"), to: nil, from: nil)
                // Also post notification (for custom views)
                NotificationCenter.default.post(name: .prUndo, object: nil)
                #endif
            }
            .keyboardShortcut("z", modifiers: [.command])

            Button("Redo") {
                #if os(macOS)
                // Try native action first (for standard text fields)
                NSApp.sendAction(NSSelectorFromString("redo:"), to: nil, from: nil)
                // Also post notification (for custom views)
                NotificationCenter.default.post(name: .prRedo, object: nil)
                #endif
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                #if os(macOS)
                // Try native action first (for standard text fields)
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                // Also post notification (for custom views)
                NotificationCenter.default.post(name: .prCut, object: nil)
                #endif
            }
            .keyboardShortcut("x", modifiers: [.command])

            Button("Copy") {
                #if os(macOS)
                // Try native action first (for standard text fields)
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                // Also post notification (for custom views)
                NotificationCenter.default.post(name: .prCopy, object: nil)
                #endif
            }
            .keyboardShortcut("c", modifiers: [.command])

            Button("Paste") {
                #if os(macOS)
                // Try native action first (for standard text fields)
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                // Also post notification (for custom views)
                NotificationCenter.default.post(name: .prPaste, object: nil)
                #endif
            }
            .keyboardShortcut("v", modifiers: [.command])

            Divider()

            Button("Delete") {
                #if os(macOS)
                // Try native action first (for standard text fields)
                NSApp.sendAction(#selector(NSText.delete(_:)), to: nil, from: nil)
                // Also post notification (for custom views)
                NotificationCenter.default.post(name: .prDelete, object: nil)
                #endif
            }
            .keyboardShortcut(.delete, modifiers: [])

            Divider()

            Button("Select All") {
                #if os(macOS)
                // Try native action first (for standard text fields)
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                // Also post notification (for custom views)
                NotificationCenter.default.post(name: .prSelectAll, object: nil)
                #endif
            }
            .keyboardShortcut("a", modifiers: [.command])
        }
        
        CommandGroup(after: .pasteboard) {
            Divider()
            
            Button("Find") {
                NotificationCenter.default.post(name: .prFind, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command])
            
            Button("Find and Replace") {
                NotificationCenter.default.post(name: .prFindAndReplace, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            
            Button("Find Next") {
                NotificationCenter.default.post(name: .prFindNext, object: nil)
            }
            .keyboardShortcut("g", modifiers: [.command])
            
            Button("Find Previous") {
                NotificationCenter.default.post(name: .prFindPrevious, object: nil)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }
    }

    // MARK: - View Menu Commands
    @CommandsBuilder
    var viewMenuCommands: some Commands {
        CommandGroup(replacing: .sidebar) {
            Button("Show/Hide Sidebar") {
                NotificationCenter.default.post(name: .prToggleSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button("Show/Hide Inspector") {
                NotificationCenter.default.post(name: .prToggleInspector, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Divider()

            Button("Zoom In") {
                NotificationCenter.default.post(name: .prZoomIn, object: nil)
            }
            .keyboardShortcut("+", modifiers: [.command])

            Button("Zoom Out") {
                NotificationCenter.default.post(name: .prZoomOut, object: nil)
            }
            .keyboardShortcut("-", modifiers: [.command])

            Button("Actual Size") {
                NotificationCenter.default.post(name: .prActualSize, object: nil)
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()

            Button("Enter Full Screen") {
                NotificationCenter.default.post(name: .prToggleFullScreen, object: nil)
            }
            .keyboardShortcut(.return, modifiers: [.command, .option])
        }
    }

    // MARK: - App Menu Commands (Dynamic based on active app)
    @CommandsBuilder
    var goMenuCommands: some Commands {
        AppMenuCommands()
    }

    // MARK: - Window Menu Commands
    @CommandsBuilder
    var windowMenuCommands: some Commands {
        CommandGroup(after: .windowArrangement) {
            Divider()
            
            Button("Show All Projects") {
                NotificationCenter.default.post(name: .prShowAllProjects, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            
            Button("Minimize") {
                NotificationCenter.default.post(name: .prMinimizeWindow, object: nil)
            }
            .keyboardShortcut("m", modifiers: [.command])
        }
    }

    // MARK: - Help Menu Commands
    @CommandsBuilder
    var helpMenuCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("Production Runner Help") {
                NotificationCenter.default.post(name: .prShowHelp, object: nil)
            }
            .keyboardShortcut("?", modifiers: [.command])

            Button("Keyboard Shortcuts") {
                NotificationCenter.default.post(name: .prShowKeyboardShortcuts, object: nil)
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])

            Divider()

            Button("Get Started") {
                NotificationCenter.default.post(name: .prShowGetStarted, object: nil)
            }

            Button("What's New in Production Runner") {
                NotificationCenter.default.post(name: .prShowWhatsNew, object: nil)
            }

            Divider()

            Button("Report an Issue...") {
                NotificationCenter.default.post(name: .prReportIssue, object: nil)
            }

            Button("Send Feedback...") {
                NotificationCenter.default.post(name: .prSendFeedback, object: nil)
            }

            #if os(macOS)
            Divider()

            Button("Check for Updates...") {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.updaterController.checkForUpdates(nil)
                }
            }
            #endif
        }
    }

    // MARK: - Project Menu
    @CommandsBuilder
    var projectMenuCommands: some Commands {
        CommandMenu("Project") {
            Button("Project Settings…") {
                NotificationCenter.default.post(name: .prProjectSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: [.command, .shift])

            Divider()

            Button("Import Script…") {
                NotificationCenter.default.post(name: .prImportScript, object: nil)
            }

            Button("Import Schedule…") {
                NotificationCenter.default.post(name: .prImportSchedule, object: nil)
            }

            Button("Import Budget…") {
                NotificationCenter.default.post(name: .prImportBudget, object: nil)
            }

            Button("Import Contacts…") {
                NotificationCenter.default.post(name: .prImportContacts, object: nil)
            }

            Divider()

            Button("Archive Project…") {
                NotificationCenter.default.post(name: .prArchiveProject, object: nil)
            }

            Button("Duplicate Project…") {
                NotificationCenter.default.post(name: .prDuplicateProject, object: nil)
            }

            Divider()

            Button("Production Calendar") {
                NotificationCenter.default.post(name: .prProductionCalendar, object: nil)
            }

            Button("Set Production Dates…") {
                NotificationCenter.default.post(name: .prSetProductionDates, object: nil)
            }
        }
    }

    // MARK: - User Menu
    @CommandsBuilder
    var userMenuCommands: some Commands {
        CommandMenu("User") {
            Button("Account Settings…") {
                NotificationCenter.default.post(name: .prAccountSettings, object: nil)
            }

            Button("Edit Profile…") {
                NotificationCenter.default.post(name: .prEditProfile, object: nil)
            }

            Divider()

            Button("Preferences…") {
                NotificationCenter.default.post(name: .prUserPreferences, object: nil)
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button("Switch User…") {
                NotificationCenter.default.post(name: .prSwitchUser, object: nil)
            }

            Button("Sign Out") {
                NotificationCenter.default.post(name: .prSignOut, object: nil)
            }
        }
    }
}

// MARK: - Notification Names Extension
extension Notification.Name {
    // File Operations
    static let prNewProject = Notification.Name("pr.newProject")
    static let prOpenProject = Notification.Name("pr.openProject")
    static let prSaveProject = Notification.Name("pr.saveProject")
    static let prSaveProjectAs = Notification.Name("pr.saveProjectAs")
    static let prClose = Notification.Name("pr.close")
    static let prCloseProject = Notification.Name("pr.closeProject")
    static let prSwitchProject = Notification.Name("pr.switchProject")
    static let prImport = Notification.Name("pr.import")
    static let prExport = Notification.Name("pr.export")
    static let prImportFile = Notification.Name("pr.importFile")
    static let prExportFile = Notification.Name("pr.exportFile")

    // Edit Operations
    static let prUndo = Notification.Name("pr.undo")
    static let prRedo = Notification.Name("pr.redo")
    static let prCut = Notification.Name("pr.cut")
    static let prCopy = Notification.Name("pr.copy")
    static let prPaste = Notification.Name("pr.paste")
    static let prDuplicate = Notification.Name("pr.duplicate")
    static let prDelete = Notification.Name("pr.delete")
    static let prSelectAll = Notification.Name("pr.selectAll")
    static let prFind = Notification.Name("pr.find")
    static let prFindAndReplace = Notification.Name("pr.findAndReplace")
    static let prFindNext = Notification.Name("pr.findNext")
    static let prFindPrevious = Notification.Name("pr.findPrevious")
    
    // View Operations
    static let prToggleSidebar = Notification.Name("pr.toggleSidebar")
    static let prToggleInspector = Notification.Name("pr.toggleInspector")
    static let prZoomIn = Notification.Name("pr.zoomIn")
    static let prZoomOut = Notification.Name("pr.zoomOut")
    static let prActualSize = Notification.Name("pr.actualSize")
    static let prToggleFullScreen = Notification.Name("pr.toggleFullScreen")
    
    // Navigation
    static let prGoBack = Notification.Name("pr.goBack")
    static let prGoForward = Notification.Name("pr.goForward")
    static let prGoToBreakdowns = Notification.Name("pr.goToBreakdowns")
    static let prGoToScheduler = Notification.Name("pr.goToScheduler")
    static let prGoToShotList = Notification.Name("pr.goToShotList")
    static let prGoToContacts = Notification.Name("pr.goToContacts")
    static let prGoToLocations = Notification.Name("pr.goToLocations")
    static let prGoToAssets = Notification.Name("pr.goToAssets")
    static let prGoToCallSheets = Notification.Name("pr.goToCallSheets")
    static let prGoToBudget = Notification.Name("pr.goToBudget")
    
    // Window Operations
    static let prShowAllProjects = Notification.Name("pr.showAllProjects")
    static let prMinimizeWindow = Notification.Name("pr.minimizeWindow")
    
    // Help
    static let prShowHelp = Notification.Name("pr.showHelp")
    static let prShowKeyboardShortcuts = Notification.Name("pr.showKeyboardShortcuts")
    static let prShowGetStarted = Notification.Name("pr.showGetStarted")
    static let prShowWhatsNew = Notification.Name("pr.showWhatsNew")
    static let prReportIssue = Notification.Name("pr.reportIssue")
    static let prSendFeedback = Notification.Name("pr.sendFeedback")
    
    // Project Operations
    static let prNewScene = Notification.Name("pr.newScene")
    static let prNewShot = Notification.Name("pr.newShot")
    static let prNewContact = Notification.Name("pr.newContact")
    static let prImportScript = Notification.Name("pr.importScript")
    static let prExportBreakdown = Notification.Name("pr.exportBreakdown")
    static let prProjectSettings = Notification.Name("pr.projectSettings")

    // Project Menu
    static let prImportSchedule = Notification.Name("pr.importSchedule")
    static let prImportBudget = Notification.Name("pr.importBudget")
    static let prArchiveProject = Notification.Name("pr.archiveProject")
    static let prDuplicateProject = Notification.Name("pr.duplicateProject")
    static let prProductionCalendar = Notification.Name("pr.productionCalendar")
    static let prSetProductionDates = Notification.Name("pr.setProductionDates")

    // User Menu
    static let prAccountSettings = Notification.Name("pr.accountSettings")
    static let prEditProfile = Notification.Name("pr.editProfile")
    static let prUserPreferences = Notification.Name("pr.userPreferences")
    static let prSwitchUser = Notification.Name("pr.switchUser")
    static let prSignOut = Notification.Name("pr.signOut")

    // App Menu - Dynamic commands per app section
    // Screenplay
    static let prNewDraft = Notification.Name("pr.newDraft")
    static let prExportScreenplay = Notification.Name("pr.exportScreenplay")
    static let prCompareRevisions = Notification.Name("pr.compareRevisions")

    // Plan
    static let prNewIdea = Notification.Name("pr.newIdea")
    static let prNewMoodBoard = Notification.Name("pr.newMoodBoard")
    static let prNewReference = Notification.Name("pr.newReference")

    // Breakdowns
    static let prNewBreakdownElement = Notification.Name("pr.newBreakdownElement")
    static let prGenerateBreakdowns = Notification.Name("pr.generateBreakdowns")

    // Design
    static let prNewMoodBoardImage = Notification.Name("pr.newMoodBoardImage")
    static let prNewColorPalette = Notification.Name("pr.newColorPalette")

    // Scheduler
    static let prNewShootDay = Notification.Name("pr.newShootDay")
    static let prOptimizeSchedule = Notification.Name("pr.optimizeSchedule")
    static let prExportSchedule = Notification.Name("pr.exportSchedule")

    // Shots
    static let prNewShotList = Notification.Name("pr.newShotList")
    static let prExportShotList = Notification.Name("pr.exportShotList")
    static let prGenerateStoryboard = Notification.Name("pr.generateStoryboard")

    // Locations
    static let prNewLocation = Notification.Name("pr.newLocation")
    static let prExportLocations = Notification.Name("pr.exportLocations")

    // Call Sheets
    static let prNewCallSheet = Notification.Name("pr.newCallSheet")
    static let prExportCallSheet = Notification.Name("pr.exportCallSheet")
    static let prSendCallSheet = Notification.Name("pr.sendCallSheet")

    // Budget
    static let prNewBudgetLine = Notification.Name("pr.newBudgetLine")
    static let prNewTransaction = Notification.Name("pr.newTransaction")
    static let prExportBudgetReport = Notification.Name("pr.exportBudgetReport")

    // Tasks
    static let prNewTask = Notification.Name("pr.newTask")
    static let prMarkComplete = Notification.Name("pr.markComplete")

    // Chat
    static let prNewConversation = Notification.Name("pr.newConversation")

    // Paperwork
    static let prNewDocument = Notification.Name("pr.newDocument")
    static let prNewContract = Notification.Name("pr.newContract")

    // Live Mode
    static let prStartLiveMode = Notification.Name("pr.startLiveMode")
    static let prStopLiveMode = Notification.Name("pr.stopLiveMode")
    static let prNewProductionReport = Notification.Name("pr.newProductionReport")

    // Scripty
    static let prNewNote = Notification.Name("pr.newNote")
    static let prNewContinuityPhoto = Notification.Name("pr.newContinuityPhoto")

    // Screenplay Insert
    static let prInsertPageBreak = Notification.Name("pr.insertPageBreak")
    static let prInsertLine = Notification.Name("pr.insertLine")
    static let prApplyFormat = Notification.Name("pr.applyFormat")

    // Screenplay Text Formatting
    static let prToggleBold = Notification.Name("pr.toggleBold")
    static let prToggleItalic = Notification.Name("pr.toggleItalic")
    static let prToggleUnderline = Notification.Name("pr.toggleUnderline")
    static let prToggleStrikethrough = Notification.Name("pr.toggleStrikethrough")

    // Screenplay Scene Management
    static let prNumberScenes = Notification.Name("pr.numberScenes")
    static let prRemoveSceneNumbers = Notification.Name("pr.removeSceneNumbers")
    static let prLockScript = Notification.Name("pr.lockScript")
    static let prUnlockScript = Notification.Name("pr.unlockScript")
    static let prSetRevisionColor = Notification.Name("pr.setRevisionColor")
    static let prShowTitlePage = Notification.Name("pr.showTitlePage")

    // Screenplay File Operations
    static let prNewScript = Notification.Name("pr.newScript")
    static let prOpenScript = Notification.Name("pr.openScript")
    static let prSaveScript = Notification.Name("pr.saveScript")
    static let prRenameScript = Notification.Name("pr.renameScript")
    static let prCloseScript = Notification.Name("pr.closeScript")
    static let prPrintScript = Notification.Name("pr.printScript")
    static let prExportPDF = Notification.Name("pr.exportPDF")
    static let prExportFDX = Notification.Name("pr.exportFDX")
    static let prExportFountain = Notification.Name("pr.exportFountain")
    static let prImportFDX = Notification.Name("pr.importFDX")
    static let prImportFountain = Notification.Name("pr.importFountain")
    static let prImportPDF = Notification.Name("pr.importPDF")

    // Create
    static let prCreateNewBoard = Notification.Name("pr.createNewBoard")
    static let prCreateAddNote = Notification.Name("pr.createAddNote")
    static let prCreateAddImage = Notification.Name("pr.createAddImage")
    static let prCreateAddLink = Notification.Name("pr.createAddLink")
    static let prCreateAddTodo = Notification.Name("pr.createAddTodo")
    static let prCreateAddColor = Notification.Name("pr.createAddColor")
    static let prCreateZoomIn = Notification.Name("pr.createZoomIn")
    static let prCreateZoomOut = Notification.Name("pr.createZoomOut")
    static let prCreateZoomToFit = Notification.Name("pr.createZoomToFit")
}

// MARK: - Dynamic App Menu Commands
struct AppMenuCommands: Commands {
    @FocusedValue(\.activeAppSection) private var activeAppSection: AppSection?

    private var menuTitle: String {
        guard let section = activeAppSection else { return "App" }
        return section.rawValue
    }

    var body: some Commands {
        CommandMenu("App") {
            // Show current app name as header when an app is active
            if let section = activeAppSection {
                Text(section.rawValue)
                    .font(.headline)
                Divider()
            }

            // Dynamic content based on active app
            switch activeAppSection {
            case .productionRunner:
                dashboardCommands
            case .screenplay:
                screenplayCommands
            #if INCLUDE_PLAN
            case .plan:
                planCommands
            #endif
            #if INCLUDE_CALENDAR
            case .calendar:
                calendarCommands
            #endif
            case .contacts:
                contactsCommands
            case .breakdowns:
                breakdownsCommands
            #if INCLUDE_SCRIPTY
            case .scripty:
                scriptyCommands
            #endif
            #if INCLUDE_BUDGETING
            case .budget:
                budgetCommands
            #endif
            case .shotLister:
                shotsCommands
            case .locations:
                locationsCommands
            case .scheduler:
                schedulerCommands
            case .callSheets:
                callSheetsCommands
            case .tasks:
                tasksCommands
            #if INCLUDE_CHAT
            case .chat:
                chatCommands
            #endif
            #if INCLUDE_PAPERWORK
            case .paperwork:
                paperworkCommands
            #endif
            #if INCLUDE_LIVE_MODE
            case .liveMode:
                liveModeCommands
            #endif
            case .none:
                noAppCommands
            }
        }
    }

    // MARK: - Dashboard Commands
    @ViewBuilder
    private var dashboardCommands: some View {
        Button("Project Overview") {
            NotificationCenter.default.post(name: .prProjectSettings, object: nil)
        }

        Divider()

        Button("Quick Stats") {
            // Navigate to stats
        }
        .disabled(true)
    }

    // MARK: - Screenplay Commands
    @ViewBuilder
    private var screenplayCommands: some View {
        // Script file operations submenu
        Menu("Script") {
            Button("New Script...") {
                NotificationCenter.default.post(name: .prNewScript, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Open Script...") {
                NotificationCenter.default.post(name: .prOpenScript, object: nil)
            }

            Divider()

            Button("Save") {
                NotificationCenter.default.post(name: .prSaveScript, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Rename...") {
                NotificationCenter.default.post(name: .prRenameScript, object: nil)
            }

            Divider()

            // Export submenu
            Menu("Export") {
                Button("Export as PDF...") {
                    NotificationCenter.default.post(name: .prExportPDF, object: nil)
                }

                Button("Export as Final Draft (.fdx)...") {
                    NotificationCenter.default.post(name: .prExportFDX, object: nil)
                }

                Button("Export as Fountain (.fountain)...") {
                    NotificationCenter.default.post(name: .prExportFountain, object: nil)
                }
            }

            // Import submenu
            Menu("Import") {
                Button("Import Final Draft (.fdx)...") {
                    NotificationCenter.default.post(name: .prImportFDX, object: nil)
                }

                Button("Import Fountain (.fountain)...") {
                    NotificationCenter.default.post(name: .prImportFountain, object: nil)
                }

                Button("Import PDF...") {
                    NotificationCenter.default.post(name: .prImportPDF, object: nil)
                }
            }

            Divider()

            Button("Print...") {
                NotificationCenter.default.post(name: .prPrintScript, object: nil)
            }
            .keyboardShortcut("p", modifiers: .command)

            Divider()

            Button("Close Script") {
                NotificationCenter.default.post(name: .prCloseScript, object: nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        Divider()

        // Insert submenu
        Menu("Insert") {
            Button("Page Break") {
                NotificationCenter.default.post(name: .prInsertPageBreak, object: nil)
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])

            Button("Line") {
                NotificationCenter.default.post(name: .prInsertLine, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Divider()

            Text("Script Elements")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Scene Heading") {
                NotificationCenter.default.post(name: .prApplyFormat, object: "sceneHeading")
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Action") {
                NotificationCenter.default.post(name: .prApplyFormat, object: "action")
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Character") {
                NotificationCenter.default.post(name: .prApplyFormat, object: "character")
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Dialogue") {
                NotificationCenter.default.post(name: .prApplyFormat, object: "dialogue")
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("Parenthetical") {
                NotificationCenter.default.post(name: .prApplyFormat, object: "parenthetical")
            }
            .keyboardShortcut("5", modifiers: .command)

            Button("Transition") {
                NotificationCenter.default.post(name: .prApplyFormat, object: "transition")
            }
            .keyboardShortcut("6", modifiers: .command)

            Button("Shot") {
                NotificationCenter.default.post(name: .prApplyFormat, object: "shot")
            }
            .keyboardShortcut("7", modifiers: .command)
        }

        Divider()

        // Text formatting submenu
        Menu("Format") {
            Button("Bold") {
                NotificationCenter.default.post(name: .prToggleBold, object: nil)
            }
            .keyboardShortcut("b", modifiers: .command)

            Button("Italic") {
                NotificationCenter.default.post(name: .prToggleItalic, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)

            Button("Underline") {
                NotificationCenter.default.post(name: .prToggleUnderline, object: nil)
            }
            .keyboardShortcut("u", modifiers: .command)

            Button("Strikethrough") {
                NotificationCenter.default.post(name: .prToggleStrikethrough, object: nil)
            }
        }

        Divider()

        // Scene management
        Menu("Scene") {
            Button("Number All Scenes") {
                NotificationCenter.default.post(name: .prNumberScenes, object: nil)
            }

            Button("Remove Scene Numbers") {
                NotificationCenter.default.post(name: .prRemoveSceneNumbers, object: nil)
            }

            Divider()

            Button("Lock Script") {
                NotificationCenter.default.post(name: .prLockScript, object: nil)
            }

            Button("Unlock Script") {
                NotificationCenter.default.post(name: .prUnlockScript, object: nil)
            }
        }

        // Revision color submenu
        Menu("Revision Color") {
            Button("White (Original)") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "white")
            }
            Button("Blue") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "blue")
            }
            Button("Pink") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "pink")
            }
            Button("Yellow") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "yellow")
            }
            Button("Green") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "green")
            }
            Button("Goldenrod") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "goldenrod")
            }
            Button("Buff") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "buff")
            }
            Button("Salmon") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "salmon")
            }
            Button("Cherry") {
                NotificationCenter.default.post(name: .prSetRevisionColor, object: "cherry")
            }
        }

        Divider()

        Button("Import Script...") {
            NotificationCenter.default.post(name: .prImportScript, object: nil)
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])

        Divider()

        Button("Title Page...") {
            NotificationCenter.default.post(name: .prShowTitlePage, object: nil)
        }
        .keyboardShortcut("t", modifiers: [.command, .shift])

        Button("Compare Revisions...") {
            NotificationCenter.default.post(name: .prCompareRevisions, object: nil)
        }
    }

    // MARK: - Plan Commands
    #if INCLUDE_PLAN
    @ViewBuilder
    private var planCommands: some View {
        Button("New Idea") {
            NotificationCenter.default.post(name: .prNewIdea, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Mood Board") {
            NotificationCenter.default.post(name: .prNewMoodBoard, object: nil)
        }

        Button("Add Reference") {
            NotificationCenter.default.post(name: .prNewReference, object: nil)
        }
    }
    #endif

    // MARK: - Calendar Commands
    #if INCLUDE_CALENDAR
    @ViewBuilder
    private var calendarCommands: some View {
        Button("New Event") {
            NotificationCenter.default.post(name: .prNewCalendarEvent, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Divider()

        Button("Today") {
            // Navigate to today
        }
        .keyboardShortcut("t", modifiers: [.command])

        Button("Refresh Calendar") {
            NotificationCenter.default.post(name: .prRefreshCalendar, object: nil)
        }
        .keyboardShortcut("r", modifiers: [.command])
    }
    #endif

    // MARK: - Contacts Commands
    @ViewBuilder
    private var contactsCommands: some View {
        Button("New Contact") {
            NotificationCenter.default.post(name: .prNewContact, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Divider()

        Button("Import Contacts...") {
            NotificationCenter.default.post(name: .prImportContacts, object: nil)
        }

        Button("Export Contacts...") {
            NotificationCenter.default.post(name: .prExportContacts, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }

    // MARK: - Breakdowns Commands
    @ViewBuilder
    private var breakdownsCommands: some View {
        Button("New Scene") {
            NotificationCenter.default.post(name: .prNewScene, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Element") {
            NotificationCenter.default.post(name: .prNewBreakdownElement, object: nil)
        }

        Divider()

        Button("Generate Breakdowns") {
            NotificationCenter.default.post(name: .prGenerateBreakdowns, object: nil)
        }

        Button("Export Breakdown...") {
            NotificationCenter.default.post(name: .prExportBreakdown, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }

    #if INCLUDE_SCRIPTY
    // MARK: - Scripty Commands
    @ViewBuilder
    private var scriptyCommands: some View {
        Button("New Note") {
            NotificationCenter.default.post(name: .prNewNote, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("Add Continuity Photo") {
            NotificationCenter.default.post(name: .prNewContinuityPhoto, object: nil)
        }
    }
    #endif

    #if INCLUDE_BUDGETING
    // MARK: - Budget Commands
    @ViewBuilder
    private var budgetCommands: some View {
        Button("New Budget Line") {
            NotificationCenter.default.post(name: .prNewBudgetLine, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Transaction") {
            NotificationCenter.default.post(name: .prNewTransaction, object: nil)
        }

        Divider()

        Button("Import Budget...") {
            NotificationCenter.default.post(name: .prImportBudget, object: nil)
        }

        Button("Export Report...") {
            NotificationCenter.default.post(name: .prExportBudgetReport, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }
    #endif

    // MARK: - Shots Commands
    @ViewBuilder
    private var shotsCommands: some View {
        Button("New Shot") {
            NotificationCenter.default.post(name: .prNewShot, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Shot List") {
            NotificationCenter.default.post(name: .prNewShotList, object: nil)
        }

        Divider()

        Button("Generate Reference Shot") {
            NotificationCenter.default.post(name: .prGenerateStoryboard, object: nil)
        }

        Button("Export Shot List...") {
            NotificationCenter.default.post(name: .prExportShotList, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }

    // MARK: - Locations Commands
    @ViewBuilder
    private var locationsCommands: some View {
        Button("New Location") {
            NotificationCenter.default.post(name: .prNewLocation, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Divider()

        Button("Export Locations...") {
            NotificationCenter.default.post(name: .prExportLocations, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }

    // MARK: - Scheduler Commands
    @ViewBuilder
    private var schedulerCommands: some View {
        Button("New Shoot Day") {
            NotificationCenter.default.post(name: .prNewShootDay, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Divider()

        Button("Optimize Schedule") {
            NotificationCenter.default.post(name: .prOptimizeSchedule, object: nil)
        }

        Button("Import Schedule...") {
            NotificationCenter.default.post(name: .prImportSchedule, object: nil)
        }

        Button("Export Schedule...") {
            NotificationCenter.default.post(name: .prExportSchedule, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }

    // MARK: - Call Sheets Commands
    @ViewBuilder
    private var callSheetsCommands: some View {
        Button("New Call Sheet") {
            NotificationCenter.default.post(name: .prNewCallSheet, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Divider()

        Button("Send Call Sheet...") {
            NotificationCenter.default.post(name: .prSendCallSheet, object: nil)
        }

        Button("Export Call Sheet...") {
            NotificationCenter.default.post(name: .prExportCallSheet, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }

    // MARK: - Tasks Commands
    @ViewBuilder
    private var tasksCommands: some View {
        Button("New Task") {
            NotificationCenter.default.post(name: .prNewTask, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Divider()

        Button("Mark Complete") {
            NotificationCenter.default.post(name: .prMarkComplete, object: nil)
        }
        .keyboardShortcut(.return, modifiers: [.command])
    }

    #if INCLUDE_CHAT
    // MARK: - Chat Commands
    @ViewBuilder
    private var chatCommands: some View {
        Button("New Conversation") {
            NotificationCenter.default.post(name: .prNewConversation, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
    #endif

    #if INCLUDE_PAPERWORK
    // MARK: - Paperwork Commands
    @ViewBuilder
    private var paperworkCommands: some View {
        Button("New Document") {
            NotificationCenter.default.post(name: .prNewDocument, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Contract") {
            NotificationCenter.default.post(name: .prNewContract, object: nil)
        }
    }
    #endif

    #if INCLUDE_LIVE_MODE
    // MARK: - Live Mode Commands
    @ViewBuilder
    private var liveModeCommands: some View {
        Button("Start Live Mode") {
            NotificationCenter.default.post(name: .prStartLiveMode, object: nil)
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])

        Button("Stop Live Mode") {
            NotificationCenter.default.post(name: .prStopLiveMode, object: nil)
        }

        Divider()

        Button("New Production Report") {
            NotificationCenter.default.post(name: .prNewProductionReport, object: nil)
        }
    }
    #endif

    // MARK: - Create Commands
    @ViewBuilder
    private var createCommands: some View {
        Button("New Board") {
            NotificationCenter.default.post(name: .prCreateNewBoard, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command])

        Divider()

        Button("Add Note") {
            NotificationCenter.default.post(name: .prCreateAddNote, object: nil)
        }
        .keyboardShortcut("1", modifiers: [.command])

        Button("Add Image") {
            NotificationCenter.default.post(name: .prCreateAddImage, object: nil)
        }
        .keyboardShortcut("2", modifiers: [.command])

        Button("Add Link") {
            NotificationCenter.default.post(name: .prCreateAddLink, object: nil)
        }
        .keyboardShortcut("3", modifiers: [.command])

        Button("Add Todo List") {
            NotificationCenter.default.post(name: .prCreateAddTodo, object: nil)
        }
        .keyboardShortcut("4", modifiers: [.command])

        Button("Add Color Swatch") {
            NotificationCenter.default.post(name: .prCreateAddColor, object: nil)
        }
        .keyboardShortcut("5", modifiers: [.command])

        Divider()

        Button("Zoom In") {
            NotificationCenter.default.post(name: .prCreateZoomIn, object: nil)
        }
        .keyboardShortcut("+", modifiers: [.command])

        Button("Zoom Out") {
            NotificationCenter.default.post(name: .prCreateZoomOut, object: nil)
        }
        .keyboardShortcut("-", modifiers: [.command])

        Button("Zoom to Fit") {
            NotificationCenter.default.post(name: .prCreateZoomToFit, object: nil)
        }
        .keyboardShortcut("0", modifiers: [.command])
    }

    // MARK: - No App Selected
    @ViewBuilder
    private var noAppCommands: some View {
        Text("Select an app to see available commands")
            .foregroundColor(.secondary)
    }
}
