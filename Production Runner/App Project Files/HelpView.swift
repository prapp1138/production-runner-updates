//
//  HelpView.swift
//  Production Runner
//
//  Help Guide viewer for Production Runner
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Help Section Model
struct HelpSection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let content: [HelpItem]

    static func == (lhs: HelpSection, rhs: HelpSection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct HelpItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let tip: String?

    init(title: String, description: String, tip: String? = nil) {
        self.title = title
        self.description = description
        self.tip = tip
    }
}

// MARK: - Help Data
struct HelpData {
    static let sections: [HelpSection] = [
        HelpSection(
            title: "Getting Started",
            icon: "star.fill",
            content: [
                HelpItem(
                    title: "Creating a New Project",
                    description: "From the Projects Dashboard, click 'Create New Project', choose a location, enter your project name, and click Create. Your project is saved as a .runner package.",
                    tip: "Projects auto-save every 10 seconds"
                ),
                HelpItem(
                    title: "Opening a Project",
                    description: "Click 'Open Project' from the dashboard and navigate to your .runner file. Recent projects appear in the sidebar for quick access.",
                    tip: "Use ⌘O to quickly open a project"
                ),
                HelpItem(
                    title: "Project Settings",
                    description: "Access settings via the gear icon to edit project name, start/wrap dates, aspect ratio, and header theme.",
                    tip: nil
                )
            ]
        ),
        HelpSection(
            title: "Dashboard",
            icon: "square.grid.2x2.fill",
            content: [
                HelpItem(
                    title: "Overview",
                    description: "The Dashboard is your production command center, showing at-a-glance status for all modules including contacts, scenes, budget, and schedule.",
                    tip: nil
                ),
                HelpItem(
                    title: "Module Cards",
                    description: "Each colored card represents an app module. Click any card to navigate directly to that section. Cards display live data from your project.",
                    tip: "Use the sidebar for persistent navigation between modules"
                ),
                HelpItem(
                    title: "Header Customization",
                    description: "Customize the dashboard header theme in Project Settings. Choose from Aurora, Sunset, Ocean, Forest, Midnight, or create a Custom color scheme.",
                    tip: nil
                ),
                HelpItem(
                    title: "Theme Options",
                    description: "Choose from 5 visual themes for the app sidebar: Standard (minimal clean), Aqua (brushed metal), Retro (80s terminal green), Neon (cyberpunk), and Cinema (Letterboxd-inspired dark).",
                    tip: "Access themes via App Settings to personalize your workspace"
                )
            ]
        ),
        HelpSection(
            title: "Plan",
            icon: "list.bullet.clipboard",
            content: [
                HelpItem(
                    title: "Pre-Production Planning",
                    description: "The Plan app is your pre-production organization hub with four dedicated tabs: Ideas, Casting, Crew, and Visuals. Use it to develop concepts and organize all production planning before shooting begins.",
                    tip: nil
                ),
                HelpItem(
                    title: "Ideas Tab",
                    description: "Organize production concepts with hierarchical sections and notes. Create ideas with titles, descriptions, due dates, and priority levels. Mark items as completed as planning progresses.",
                    tip: "Use priority levels to focus on critical planning tasks first"
                ),
                HelpItem(
                    title: "Casting & Crew Tabs",
                    description: "Plan casting decisions and actor selections in the Casting tab. Organize crew assignments and department planning in the Crew tab. All information integrates with the Contacts app.",
                    tip: nil
                ),
                HelpItem(
                    title: "Visuals Tab",
                    description: "Collect and organize visual references, mood boards, and creative inspiration for your production. Build a visual library that guides your creative direction.",
                    tip: "Gather visual references early to align your team's creative vision"
                )
            ]
        ),
        HelpSection(
            title: "Calendar",
            icon: "calendar",
            content: [
                HelpItem(
                    title: "Event Types",
                    description: "Create events for Shoot Days, Prep Days, Rehearsals, Location Scouts, Meetings, Milestones, Wrap Days, Pre-Production, and Post-Production. Each type has a distinct color.",
                    tip: nil
                ),
                HelpItem(
                    title: "View Modes",
                    description: "Switch between Month View (calendar grid), Week View (detailed schedule), and Timeline View (Gantt-style visualization).",
                    tip: nil
                ),
                HelpItem(
                    title: "Creating Events",
                    description: "Click a date or use the + button. Fill in event details including title, date/time, location, scenes, and crew assignments.",
                    tip: "Events can span multiple days and link to locations"
                )
            ]
        ),
        HelpSection(
            title: "Contacts",
            icon: "person.2.fill",
            content: [
                HelpItem(
                    title: "Categories",
                    description: "Organize contacts as Cast, Crew, or Vendors. Assign departments like Production, Art, Grip & Electric, Wardrobe, Camera, or Sound.",
                    tip: nil
                ),
                HelpItem(
                    title: "Contact Information",
                    description: "Store name, role, phone, email, allergies (for catering), and paperwork status for each contact.",
                    tip: nil
                ),
                HelpItem(
                    title: "Import & Export",
                    description: "Import contacts from CSV files with column mapping. Export contact lists as PDF for distribution.",
                    tip: "Use ⌘Click for multi-select operations"
                )
            ]
        ),
        HelpSection(
            title: "Screenplay",
            icon: "doc.text.magnifyingglass",
            content: [
                HelpItem(
                    title: "Getting Started with Scripts",
                    description: "Production Runner supports two workflows: Import a Final Draft (FDX) file to preserve professional formatting, or write directly in the built-in screenplay editor with industry-standard formatting tools. Your script is the foundation of your entire production - all scenes, breakdowns, and schedules flow from here.",
                    tip: "Start by importing or writing your script before using other features"
                ),
                HelpItem(
                    title: "Importing Final Draft Files",
                    description: "Click the Import button in the Screenplay toolbar and select 'Final Draft (FDX)'. Production Runner imports all formatting, scene headings, dialogue, action, transitions, and special elements. Scene numbers are automatically extracted. Character names populate the cast list. INT/EXT and DAY/NIGHT information feeds into the scheduler.",
                    tip: "Import creates a read-only reference - use revision imports to track script changes"
                ),
                HelpItem(
                    title: "Writing in Production Runner",
                    description: "Use Writers View to create your screenplay from scratch. The editor provides industry-standard element types: Scene Heading (INT/EXT location - DAY/NIGHT), Action (scene description), Character (speaker name), Dialogue (character speech), Parenthetical (actor direction in dialogue), and Transition (CUT TO:, FADE TO:). Smart formatting automatically detects and applies the correct element type as you write.",
                    tip: "Press Tab or Enter to cycle through element types while writing"
                ),
                HelpItem(
                    title: "Screenplay Formatting Toolbar",
                    description: "The formatting toolbar provides text styling (Bold ⌘B, Italic ⌘I, Underline ⌘U) and element formatting buttons. Click any element button or use keyboard shortcuts to change the selected paragraph's type. The toolbar also includes page break insertion, scene numbering tools, and revision marking controls.",
                    tip: "Bold, italic, and underline are typically used for emphasis in action lines"
                ),
                HelpItem(
                    title: "Revision Tracking & Script Versions",
                    description: "Track script changes using the 9 industry-standard revision colors in sequential order: White (original), Blue (1st revision), Pink (2nd), Yellow (3rd), Green (4th), Goldenrod (5th), Buff (6th), Salmon (7th), and Cherry (8th). When importing a revised FDX file, select the revision color to maintain version history. The Revised Scripts tab shows all imported versions with their revision colors. This allows you to track how scenes have changed throughout development and production.",
                    tip: "Import each script revision with its color to build a complete history"
                ),
                HelpItem(
                    title: "View Modes Explained",
                    description: "Writers View is your editable workspace for creating and modifying scripts. Imported Script provides a read-only view of your Final Draft import, preserving the exact formatting from FDX. Revised Scripts shows all script versions side-by-side with their revision colors, making it easy to compare changes between drafts.",
                    tip: "Use Imported Script view to reference the original while working in Writers View"
                ),
                HelpItem(
                    title: "Scene Headings & Scene Sync",
                    description: "Every Scene Heading you create (e.g., 'INT. COFFEE SHOP - DAY') automatically becomes a scene in the Breakdowns and Scheduler apps. Production Runner parses INT/EXT, location names, and time of day. Scene numbers can be added manually or generated automatically. Changes to scene headings in the screenplay automatically update throughout Production Runner, keeping everything in sync.",
                    tip: "Use consistent location names in scene headings for accurate scheduler grouping"
                ),
                HelpItem(
                    title: "Script Pagination & Page Counts",
                    description: "Production Runner calculates page counts based on industry-standard screenplay formatting (approximately 55-60 lines per page). Fractional page counts (e.g., 2 3/8 pages) are calculated for accurate scene length tracking. Page counts feed directly into shooting schedules and budget calculations. Use the pagination view to see page breaks and ensure proper formatting.",
                    tip: "Accurate page counts are critical for scheduling - one page equals roughly one minute of screen time"
                ),
                HelpItem(
                    title: "Script Sides & Distribution",
                    description: "Generate script sides (partial script pages) for specific scenes to distribute to cast and crew. Select scenes from your shooting schedule, and Production Runner creates a formatted PDF with only those scenes, maintaining proper formatting and page numbers. Perfect for call sheet attachments and daily script distribution.",
                    tip: "Export script sides the night before shooting for next-day scenes"
                )
            ]
        ),
        HelpSection(
            title: "Breakdowns",
            icon: "list.clipboard.fill",
            content: [
                HelpItem(
                    title: "Understanding Script Breakdowns",
                    description: "Script Breakdown is the process of analyzing each scene in your screenplay to identify every production element required to shoot it. This includes cast, props, wardrobe, vehicles, special effects, animals, equipment, and more. Breaking down your script thoroughly is essential for accurate budgeting, scheduling, and ensuring nothing is overlooked on shoot days. Production Runner automatically creates scene entries from your screenplay's scene headings.",
                    tip: "A thorough breakdown prevents costly mistakes and missed elements on set"
                ),
                HelpItem(
                    title: "Scene Information Display",
                    description: "Each scene breakdown shows: Scene Number (e.g., 1, 2A, 15), INT/EXT designation (Interior or Exterior), Scene Heading/Location (e.g., COFFEE SHOP), Time of Day (Day, Night, Dawn, Dusk, Magic Hour), Page Count (fractional, e.g., 2 3/8 pages), and Script Day (narrative day in the story). This information is automatically extracted from your screenplay and can be edited if needed.",
                    tip: "Keep scene numbers consistent between script and breakdown for crew clarity"
                ),
                HelpItem(
                    title: "Breakdown Elements Overview",
                    description: "Elements are the building blocks of your breakdown. Each element type has a specific color code following industry standards: Cast (red), Background Actors/Extras (green), Stunts (orange), Vehicles (pink), Props (purple), Wardrobe (sky blue), Makeup/Hair (yellow), Special Effects (blue), Animal Wranglers (green), Equipment (brown), Set Dressing (orange), Sound Effects (brown), and Additional Labor (gold). Click the element category buttons to add items to your scene.",
                    tip: "Use consistent element names across scenes for accurate cross-referencing"
                ),
                HelpItem(
                    title: "Adding Cast to Scenes",
                    description: "Click the Cast button to add actors to the scene. Select from your Contacts list or create new cast members on the fly. For each cast member, you can specify: Character name, Actor name, and whether they have dialogue or are just present in the scene. Cast marked with dialogue automatically appear in call sheets. Production Runner tracks which scenes each actor appears in for scheduling continuity.",
                    tip: "Add all speaking roles first, then background/extras for complete coverage"
                ),
                HelpItem(
                    title: "Props, Wardrobe & Set Dressing",
                    description: "Document every prop that actors handle (hand props), every wardrobe piece characters wear, and every set dressing element visible in the scene. For props, note if they're hero props (featured/important) or background. For wardrobe, track changes between scenes for continuity. Detailed breakdown ensures the art department and wardrobe have complete lists for sourcing and preparation.",
                    tip: "Note if props need to be multiples (for multiple takes or destruction)"
                ),
                HelpItem(
                    title: "Special Requirements & Notes",
                    description: "Add special effects (practical effects, blood, rain, fog), stunts (fight choreography, falls, car stunts), vehicles (picture cars that appear on camera), animals (with handler requirements), special equipment (cranes, dollies, drones), and makeup/hair specifics (special makeup FX, wigs, aging). Include detailed notes about complexity, safety requirements, and prep time needed.",
                    tip: "Flag complex elements early so departments have adequate prep time"
                ),
                HelpItem(
                    title: "Breakdown Sheets & Export",
                    description: "Generate professional breakdown sheets in PDF format for distribution to department heads. Each breakdown sheet shows the scene with all elements organized by category. Export options include: Single scene breakdown, Multiple selected scenes, or Complete breakdown book for entire script. Include or exclude specific element categories based on which departments need the information.",
                    tip: "Distribute breakdown sheets to all HODs before pre-production meetings"
                ),
                HelpItem(
                    title: "Sync with Scheduler",
                    description: "Every element you add in Breakdowns automatically appears in the Scheduler. When you build your stripboard shooting schedule, you'll see all cast, props, and requirements for each scene. This ensures you're scheduling scenes efficiently by grouping actors, locations, and equipment. Changes to breakdowns instantly update the scheduler, keeping your entire production in sync.",
                    tip: "Complete breakdowns before scheduling to identify location and cast groupings"
                ),
                HelpItem(
                    title: "Department-Specific Views",
                    description: "Filter breakdown views by department to see only relevant elements. Camera Department sees equipment and special rigs. Art Department sees props, set dressing, and vehicles. Wardrobe sees only costume elements. AD Department sees complete breakdowns for scheduling. This allows each department to focus on their specific responsibilities without information overload.",
                    tip: "Export department-specific breakdowns to reduce paperwork clutter"
                )
            ]
        ),
        HelpSection(
            title: "Budgeting",
            icon: "dollarsign.circle.fill",
            content: [
                HelpItem(
                    title: "Budget Versions",
                    description: "Create multiple budget versions to compare different scenarios. Rename or delete versions as needed.",
                    tip: nil
                ),
                HelpItem(
                    title: "Line Items",
                    description: "Add budget items with description, category, rate, and quantity. Categories follow industry-standard film budget structure.",
                    tip: nil
                ),
                HelpItem(
                    title: "Rate Cards & Templates",
                    description: "Create reusable rate templates for consistent pricing across your budget. Use the Standard Budget Template as a starting point for professional-grade budgets.",
                    tip: "Use templates to quickly set up standard budgets"
                ),
                HelpItem(
                    title: "Budget Analysis",
                    description: "Track budget variance, search and filter line items, export budgets to various formats, and maintain an audit trail of all changes. The system validates all entries automatically.",
                    tip: "Monitor variance regularly to stay on budget"
                )
            ]
        ),
        HelpSection(
            title: "Shots",
            icon: "video.fill",
            content: [
                HelpItem(
                    title: "Scene-Based Organization",
                    description: "Browse scenes in the sidebar, then view and edit shots for the selected scene in the detail pane.",
                    tip: nil
                ),
                HelpItem(
                    title: "Shot Details",
                    description: "Track shot number, type (Wide, Medium, Close-up), camera movement, description, equipment, and notes.",
                    tip: nil
                ),
                HelpItem(
                    title: "Storyboard View",
                    description: "Visualize your shots with storyboard frames. Add visual references and shot compositions to plan your coverage. Perfect for sharing shot lists with cinematographers.",
                    tip: "Import reference images to build a complete visual shotlist"
                ),
                HelpItem(
                    title: "Top Down Shot Planner",
                    description: "Aerial view planning tool for blocking camera positions and actor movement. Design overhead diagrams showing camera placement, actor positions, and movement paths for complex scenes.",
                    tip: "Use Top Down view for multi-camera setups and choreographed sequences"
                ),
                HelpItem(
                    title: "Management",
                    description: "Add shots with the + button, reorder by dragging, and filter/search to find specific shots.",
                    tip: nil
                )
            ]
        ),
        HelpSection(
            title: "Locations",
            icon: "mappin.circle.fill",
            content: [
                HelpItem(
                    title: "Location Details",
                    description: "Store name, address, contact person, phone, email, permit status, scout date, GPS coordinates, and notes for each location.",
                    tip: nil
                ),
                HelpItem(
                    title: "Permit Status",
                    description: "Track permits as Pending, Approved, Needs Scout, or Denied.",
                    tip: nil
                ),
                HelpItem(
                    title: "Maps & Photos",
                    description: "View locations on Apple Maps with address autocomplete. Import multiple photos per location for visual reference.",
                    tip: nil
                )
            ]
        ),
        HelpSection(
            title: "Scheduler",
            icon: "calendar.circle.fill",
            content: [
                HelpItem(
                    title: "Understanding the Stripboard",
                    description: "The stripboard (or production board) is the traditional tool for building a shooting schedule. Each colored strip represents one scene from your script. Strips are arranged in shooting order (not script order) to optimize production efficiency. The goal is to minimize company moves, group actors' work days, and maximize location usage. Production Runner's digital stripboard provides all the flexibility of a physical board with powerful sorting, filtering, and export capabilities.",
                    tip: "Scenes are rarely shot in script order - group by location and cast first"
                ),
                HelpItem(
                    title: "Strip Color Coding",
                    description: "Scene strips are automatically color-coded based on INT/EXT and time of day: Interior Day (white), Interior Night (blue), Exterior Day (yellow), Exterior Night (green), Interior Dusk/Dawn (cyan), Exterior Dusk/Dawn (orange). This color system provides instant visual recognition of scene types, helping you balance shoot days with appropriate coverage. You can customize strip colors if your production has specific requirements.",
                    tip: "Avoid too many day-to-night transitions in one shoot day"
                ),
                HelpItem(
                    title: "Strip Information Display",
                    description: "Each scene strip shows comprehensive information at a glance: Scene Number (1, 2A, 15, etc.), INT/EXT designation, Location/Set Name, Time of Day (Day, Night, Dusk, Dawn, Magic Hour), Page Count (e.g., 2 3/8 pages), Script Day (D1, D2 - narrative day in the story), Cast Members (actor initials or numbers), Special Requirements icons (stunts, SFX, animals, etc.). This compressed view lets you see your entire shooting schedule on one screen.",
                    tip: "Use the page count total at bottom to track daily shooting load"
                ),
                HelpItem(
                    title: "Creating Your Shooting Schedule",
                    description: "Start with all scenes from your breakdown in script order. Identify your locations and group scenes by location to minimize company moves (expensive and time-consuming). Within each location, group by INT/EXT and day/night to maintain lighting continuity. Consider cast availability - group scenes with expensive actors or limited-availability talent. Balance page counts across shoot days (typically 3-5 pages per 12-hour day, depending on complexity). Add Day Break markers between shooting days to separate the schedule into distinct production days.",
                    tip: "Start scheduling with the most complex or restrictive scenes first"
                ),
                HelpItem(
                    title: "Day Breaks & Shooting Days",
                    description: "Insert Day Break elements to separate your schedule into individual shooting days. Production Runner automatically numbers shoot days (Day 1, Day 2, etc.) and calculates page count totals for each day. Each Day Break can include: Shoot date (if known), Location/Set for that day, Call time, Estimated wrap time, and Notes (weather concerns, special equipment, etc.). Day Breaks appear in bold in the stripboard and provide structure for call sheet generation.",
                    tip: "Aim for consistent page counts per day - avoid overloading early days"
                ),
                HelpItem(
                    title: "Off Days & Hiatus",
                    description: "Mark days when the crew is not shooting using Off Day markers. Common off days include: Prep days (before principal photography), Company moves (travel between distant locations), Forced weather days, Holidays and weekends, Post-production days (after wrap). Off Days don't count toward your shooting schedule but maintain calendar accuracy for overall production timeline tracking.",
                    tip: "Build in contingency days for weather or unexpected delays"
                ),
                HelpItem(
                    title: "Drag & Drop Reordering",
                    description: "Click and drag any scene strip to reorder your schedule. Drag scenes between Day Breaks to move them to different shoot days. Multi-select scenes (⇧Click for range, ⌘Click for individual) to move multiple strips at once. Production Runner automatically recalculates page totals, cast work days, and location counts as you reorder. This allows rapid iteration on your schedule to find the optimal shooting order.",
                    tip: "Save different schedule versions to compare alternative approaches"
                ),
                HelpItem(
                    title: "Filters & Sorting",
                    description: "Use filters to view subsets of your schedule: INT or EXT only, Day or Night only, specific locations, scenes with specific cast members, scenes with special requirements (stunts, SFX, animals). Sort options include: Script order, Scene number, Page count (longest first), Location grouping, Cast grouping. Filters help you analyze schedule efficiency and identify potential conflicts.",
                    tip: "Filter by actor to see all their scenes for contract negotiations"
                ),
                HelpItem(
                    title: "One-Liner Schedule Export",
                    description: "Generate a one-liner schedule - a text-based, condensed shooting schedule showing each scene on one line. The one-liner includes scene number, INT/EXT, location, time of day, page count, cast, and brief description. Export as PDF for distribution to cast and crew. The one-liner is essential for crew members who need to see the big picture without the full stripboard detail.",
                    tip: "Update and redistribute one-liners whenever schedule changes significantly"
                ),
                HelpItem(
                    title: "Production Strip Export",
                    description: "Export production strips as PDF in the traditional stripboard layout. Each strip appears in color with all scene information. This format is perfect for: Posting on the production office wall, Distribution to department heads who prefer visual schedules, Archival documentation of the shooting plan. Export options include full schedule or specific date ranges.",
                    tip: "Post a large-format strip schedule in the production office for easy reference"
                ),
                HelpItem(
                    title: "Schedule Changes & Updates",
                    description: "Production schedules change constantly. When you add, remove, or modify scenes in Breakdowns, those changes automatically flow to the Scheduler. Moved scenes retain their scheduling position unless you manually reorder them. Deleted scenes are removed from the schedule with warnings if they affect multi-scene shoot days. Version your schedules by date to track changes (e.g., 'Schedule v3 - Jan 15').",
                    tip: "Communicate all schedule changes immediately to avoid confusion on set"
                ),
                HelpItem(
                    title: "Advanced Scheduling Strategies",
                    description: "Shoot coverage masters before close-ups (easier to match performance). Schedule emotionally intense scenes when actors are fresh (early in week). Group night exteriors together to minimize day-to-night crew changeovers. Schedule complex stunts or SFX early in the day when crew is sharp. Build 'float days' for pickup shots or overages. Consider actor turnaround times between shoot days (typically 10-12 hours). Balance hero actors across the schedule to avoid exhaustion.",
                    tip: "Review your schedule with all department heads before locking it"
                )
            ]
        ),
        HelpSection(
            title: "Call Sheets",
            icon: "doc.text.fill",
            content: [
                HelpItem(
                    title: "What is a Call Sheet?",
                    description: "The call sheet is the most critical daily production document. Distributed the night before each shoot day, it tells every cast and crew member when and where to report, what scenes are shooting, and all essential production information. A well-organized call sheet ensures everyone arrives on time, prepared, and informed. Production Runner generates professional call sheets from your schedule data with all industry-standard sections and formatting.",
                    tip: "Distribute call sheets by 6pm the night before shooting - earlier is better"
                ),
                HelpItem(
                    title: "Header Information",
                    description: "The call sheet header contains: Production Title, Production Company name, Director and Producer names, Shoot Date, Day Number (e.g., 'Day 5 of 20'), and Call Sheet version/revision number. This information appears at the top of every call sheet and immediately identifies the production and shoot day. Update the header template once, and it populates all future call sheets automatically.",
                    tip: "Include both shoot day number and total days for crew morale tracking"
                ),
                HelpItem(
                    title: "General Crew Call",
                    description: "The crew call time is when most of the crew should arrive and be ready to work. This appears prominently at the top of the call sheet. Shooting call (when cameras roll) is typically 30-60 minutes after crew call to allow for setup. Specify both times clearly. Special crew members (camera, grip/electric, hair/makeup) may have earlier calls - list these as exceptions with specific times.",
                    tip: "Build in setup time - don't schedule shooting call immediately after crew arrival"
                ),
                HelpItem(
                    title: "Cast Call Times",
                    description: "Each cast member receives an individual call time based on their hair/makeup requirements and first scene. List actors in order of call time (earliest first). Include: Actor name, Character name, Pickup location (if using transport), Makeup/Wardrobe time, and Set Call (when they should be camera-ready on set). Production Runner automatically lists cast from your schedule and calculates times based on your makeup duration settings.",
                    tip: "Add 30-45 min for makeup, 60-90 min for complex makeup or wigs"
                ),
                HelpItem(
                    title: "Schedule Section - Scenes Shooting Today",
                    description: "List all scenes scheduled for the shoot day in planned shooting order. For each scene include: Scene number, INT/EXT, Location/Set name, Brief scene description (1-2 sentences), Page count, Cast appearing in scene (by character name or number), and Estimated timing. This section is the heart of the call sheet - it tells everyone what you're shooting and in what order.",
                    tip: "Keep scene descriptions brief but clear enough for crew to understand"
                ),
                HelpItem(
                    title: "Location Details",
                    description: "Provide complete location information: Exact address with GPS coordinates, Parking instructions for crew, Base Camp location (trucks, catering, trailers), Nearest hospital address and distance, and Map or directions if location is difficult to find. If shooting at multiple locations in one day, clearly separate them with timing and travel notes. Include location contact phone numbers for emergencies.",
                    tip: "Test GPS coordinates before distributing - some apps use different formats"
                ),
                HelpItem(
                    title: "Weather & Sunrise/Sunset",
                    description: "Include forecasted weather (temperature, conditions, precipitation chance) so crew can prepare appropriate gear. List sunrise and sunset times for exterior shoots - critical for maintaining continuity and maximizing golden hour. Magic hour (20-30 min after sunrise or before sunset) should be highlighted if shooting during that time. Production Runner can fetch weather automatically based on your location and shoot date.",
                    tip: "Have a weather contingency plan and communicate it on the call sheet if relevant"
                ),
                HelpItem(
                    title: "Meals & Catering",
                    description: "Specify meal times and locations: Breakfast (if provided - typically for early calls), Lunch (6 hours after crew call by union rules), and 2nd Meal (if shooting runs long - 6 hours after lunch). Note any dietary restrictions from cast/crew and confirm with catering. Include catering company contact information. Meal penalties apply if lunch is missed or delayed, so timing is critical.",
                    tip: "Plan lunch during a scene transition or location move to save shooting time"
                ),
                HelpItem(
                    title: "Production Notes",
                    description: "Use this section for: Special equipment needed (crane, Steadicam, drone), Special FX or stunts with safety notes, COVID protocols or health requirements, Walkie channel assignments, and any unusual circumstances for the day. Production notes keep everyone informed of special considerations without cluttering the main schedule section.",
                    tip: "Highlight safety-critical information in production notes"
                ),
                HelpItem(
                    title: "Advanced Schedule (Next Day Preview)",
                    description: "The bottom of the call sheet should preview the next shoot day to help cast and crew prepare. Include: Next shoot date, Tentative crew call time, Locations for next day, and scenes scheduled for next day. This allows actors to study upcoming scenes and crew to prep equipment. Mark this section 'Subject to Change' as schedules often shift.",
                    tip: "Reviewing upcoming scenes helps actors prepare and reduces day-of surprises"
                ),
                HelpItem(
                    title: "Key Crew Contact List",
                    description: "List key crew contact phone numbers: Director, 1st AD, UPM/Line Producer, Production Coordinator, Location Manager, Transportation Captain, and Production Office number. This ensures quick communication for any issues, delays, or emergencies. Update this list as crew changes occur.",
                    tip: "Keep the contact list concise - only essential personnel to reduce clutter"
                ),
                HelpItem(
                    title: "Status Workflow - Draft to Published",
                    description: "Mark call sheets as Draft while building them - this prevents accidental distribution of incomplete information. Change to Ready when all details are confirmed and reviewed. Mark as Published when distributed to cast and crew. Track distribution time to ensure compliance with notification requirements (typically 12 hours minimum notice).",
                    tip: "Have the director and UPM review every call sheet before publishing"
                ),
                HelpItem(
                    title: "Export & Distribution",
                    description: "Export call sheets as PDF for maximum compatibility. Distribution methods: Email to full cast and crew list (use BCC for privacy), Upload to crew app or production platform, Print copies for set (always have paper backups), and Post in production office. Track who receives call sheets to ensure no one is missed.",
                    tip: "Always carry printed call sheets on set - technology fails"
                )
            ]
        ),
        HelpSection(
            title: "Tasks",
            icon: "checklist.checked",
            content: [
                HelpItem(
                    title: "Task Management",
                    description: "Create tasks with title, notes, and optional reminder date/time. Toggle completion with the checkbox.",
                    tip: nil
                ),
                HelpItem(
                    title: "Reminders",
                    description: "Tasks with reminders appear color-coded: Red (overdue), Orange (due in 1 hour), Yellow (due in 24 hours), Blue (future).",
                    tip: nil
                ),
                HelpItem(
                    title: "Dashboard Integration",
                    description: "Upcoming reminders display on the Dashboard for quick reference. Filter to hide completed tasks.",
                    tip: nil
                )
            ]
        ),
        HelpSection(
            title: "Keyboard Shortcuts",
            icon: "keyboard",
            content: [
                HelpItem(
                    title: "File Operations",
                    description: "⌘N New Project • ⌘O Open Project • ⌘S Save • ⇧⌘S Save As • ⌘W Close • ⇧⌘L Switch Project",
                    tip: nil
                ),
                HelpItem(
                    title: "Navigation",
                    description: "⌘1-8 Go to modules (Breakdowns, Scheduler, Shots, Contacts, Locations, Assets, Call Sheets, Budget)",
                    tip: nil
                ),
                HelpItem(
                    title: "Editing",
                    description: "⌘B Bold • ⌘I Italic • ⌘U Underline • ⌘F Find • ⌘A Select All",
                    tip: nil
                ),
                HelpItem(
                    title: "View",
                    description: "⌘+ Zoom In • ⌘- Zoom Out • ⌘0 Actual Size • ⌥⌘S Toggle Sidebar • ⌥⌘I Toggle Inspector",
                    tip: nil
                )
            ]
        )
    ]
}

// MARK: - Main Help View
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedSection: HelpSection?

    private var filteredSections: [HelpSection] {
        if searchText.isEmpty {
            return HelpData.sections
        }
        return HelpData.sections.filter { section in
            section.title.localizedCaseInsensitiveContains(searchText) ||
            section.content.contains { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar with sections
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Help", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()

                Divider()

                // Section list
                List(filteredSections, selection: $selectedSection) { section in
                    HelpSectionRow(section: section)
                        .tag(section)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 250)
            .navigationTitle("Help")
        } detail: {
            if let section = selectedSection {
                HelpDetailView(section: section, searchText: searchText)
            } else {
                WelcomeHelpView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        #endif
    }
}

// MARK: - Section Row
struct HelpSectionRow: View {
    let section: HelpSection

    var body: some View {
        Label {
            Text(section.title)
                .font(.system(size: 13, weight: .medium))
        } icon: {
            Image(systemName: section.icon)
                .foregroundStyle(.tint)
                .frame(width: 20)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Welcome View (no selection)
struct WelcomeHelpView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Production Runner Help")
                .font(.system(size: 28, weight: .bold))

            Text("Select a topic from the sidebar to learn more about Production Runner's features.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Divider()
                .frame(width: 200)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                QuickLinkRow(icon: "star.fill", title: "Getting Started", description: "Create and open projects")
                QuickLinkRow(icon: "doc.text.magnifyingglass", title: "Screenplay", description: "Write or import your script")
                QuickLinkRow(icon: "list.clipboard.fill", title: "Breakdowns", description: "Break down scenes and elements")
                QuickLinkRow(icon: "calendar.circle.fill", title: "Scheduler", description: "Build your stripboard schedule")
                QuickLinkRow(icon: "doc.text.fill", title: "Call Sheets", description: "Generate professional call sheets")
                QuickLinkRow(icon: "keyboard", title: "Keyboard Shortcuts", description: "Speed up your workflow")
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.02))
    }
}

struct QuickLinkRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Detail View
struct HelpDetailView: View {
    let section: HelpSection
    let searchText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: section.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(.tint)
                    }

                    Text(section.title)
                        .font(.system(size: 32, weight: .bold))
                }
                .padding(.bottom, 8)

                Divider()

                // Items
                ForEach(section.content) { item in
                    HelpItemCard(item: item, highlightText: searchText)
                }
            }
            .padding(32)
        }
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - Help Item Card
struct HelpItemCard: View {
    let item: HelpItem
    let highlightText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(.system(size: 18, weight: .semibold))

            Text(item.description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            if let tip = item.tip {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Text(tip)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Keyboard Shortcuts View
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 20, weight: .bold))
                    Text("Quick reference for Production Runner")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ShortcutSection(title: "File", shortcuts: [
                        ("⌘N", "New Project"),
                        ("⌘O", "Open Project"),
                        ("⌘S", "Save"),
                        ("⇧⌘S", "Save As"),
                        ("⌘W", "Close Window"),
                        ("⇧⌘W", "Close Project"),
                        ("⇧⌘L", "Switch Project")
                    ])

                    ShortcutSection(title: "Edit", shortcuts: [
                        ("⌘Z", "Undo"),
                        ("⇧⌘Z", "Redo"),
                        ("⌘X", "Cut"),
                        ("⌘C", "Copy"),
                        ("⌘V", "Paste"),
                        ("⌘A", "Select All"),
                        ("⌘F", "Find"),
                        ("⌥⌘F", "Find and Replace"),
                        ("⌘G", "Find Next"),
                        ("⇧⌘G", "Find Previous")
                    ])

                    ShortcutSection(title: "View", shortcuts: [
                        ("⌥⌘S", "Toggle Sidebar"),
                        ("⌥⌘I", "Toggle Inspector"),
                        ("⌘+", "Zoom In"),
                        ("⌘-", "Zoom Out"),
                        ("⌘0", "Actual Size"),
                        ("⌥⌘↵", "Toggle Full Screen")
                    ])

                    ShortcutSection(title: "Navigation", shortcuts: [
                        ("⌘[", "Back"),
                        ("⌘]", "Forward"),
                        ("⌘1", "Go to Breakdowns"),
                        ("⌘2", "Go to Scheduler"),
                        ("⌘3", "Go to Shot List"),
                        ("⌘4", "Go to Contacts"),
                        ("⌘5", "Go to Locations"),
                        ("⌘6", "Go to Assets"),
                        ("⌘7", "Go to Call Sheets"),
                        ("⌘8", "Go to Budget")
                    ])

                    ShortcutSection(title: "Screenplay", shortcuts: [
                        ("⌘B", "Bold"),
                        ("⌘I", "Italic"),
                        ("⌘U", "Underline")
                    ])

                    ShortcutSection(title: "Help", shortcuts: [
                        ("⌘?", "Production Runner Help"),
                        ("⇧⌘/", "Keyboard Shortcuts")
                    ])
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct ShortcutSection: View {
    let title: String
    let shortcuts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 8) {
                ForEach(shortcuts, id: \.0) { shortcut in
                    HStack {
                        Text(shortcut.0)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(shortcut.1)
                            .font(.system(size: 13))

                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview
#if DEBUG
struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
#endif
