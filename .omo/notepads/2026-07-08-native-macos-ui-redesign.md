# Native macOS UI Redesign ULW Notepad

## Bootstrap
- Tier: HEAVY. Reason: redesign crosses Search, Shared Files, Uploads, Statistics, Settings, sidebar navigation, AppStorage preferences, tests, and rendered macOS surfaces.
- Skills used:
  - omo:ulw-loop: durable criteria/evidence/checkpoint workflow.
  - omo:frontend: UI redesign routing; existing-project redesign plus design-system gate.
  - build-macos-apps:swiftui-patterns: native macOS Settings, toolbar, sidebar/detail, inspector patterns.
  - build-macos-apps:build-run-debug: SwiftPM/Xcode-style macOS build verification.
  - omo:visual-qa: post-change rendered-surface evidence.
  - superpowers:brainstorming: design baseline established in notepad because user already provided concrete redesign goals; no extra approval gate to avoid blocking requested ULW execution.
- Subagent constraint: multi_agent_v1 exists but tool schema explicitly forbids spawning unless the user explicitly asks for subagents/delegation. User requested ULW but not subagents; delegation/reviewer steps are recorded as unavailable and work is done in-thread with evidence.
- Design system: no DESIGN.md found. Existing SwiftUI component patterns exist, so extract a macOS design baseline before UI edits.

## Findings
- Search toolbar search field is currently `SearchCapabilityGate` over `model.searchQuery`; it starts the remote network search, not just filtering results. This is confusing because macOS toolbar search fields usually filter the current view.
- Advanced search is currently a disclosure `Grid` at the top of the search page; it consumes vertical room and reads like a custom form strip.
- Shared Files and Uploads both put refresh/reload buttons in the content area above a divider.
- Statistics mixes refresh and graph width/scale controls inside content section headers.
- Preferences currently uses `NavigationSplitView`, which matches post-Tahoe-style sidebar preferences more than the conventional macOS tabbed settings window requested.
- Categories and Friends are implemented as EC surfaces in this repo (`createCategory`, `updateCategory`, `deleteCategory`, `friends`, `friend-add`, `friend-shared`), but amuled support/availability is capability-dependent and not central for every user. Hide options should be local UI preferences, not protocol claims that the pages do not exist.

## Design Baseline
- Use native system materials and standard SwiftUI controls; no custom card-heavy dashboard look.
- Promote command actions to toolbar items when they affect the whole page.
- Keep page-local forms inside content only when users are entering primary task data.
- Use inspector/popover for advanced/secondary controls.
- Settings should be a conventional macOS tabbed `TabView`, with grouped forms inside each tab.
- Sidebar rows stay standard source-list rows; optional sections are controlled by `@AppStorage` settings.

## Success Criteria
- C001 Search: source-level RED proves the old confusing toolbar search/modifier and disclosure-grid advanced UI exist; after change, Search has a named query row, toolbar actions, and inspector advanced controls. Rendered screenshot proves the surface.
- C002 Sidebar/Settings: source-level RED proves Preferences uses split view and optional Categories/Friends are always visible; after change, Preferences is TabView-based and hide toggles remove sidebar pages/redirect selection safely. Rendered screenshot proves settings and sidebar behavior.
- C003 Toolbar/Stats: source-level RED proves Shared Files/Uploads content buttons and Stats inline controls; after change, actions are in toolbars and Stats uses native overview/graph layout. Rendered screenshots prove surfaces.

