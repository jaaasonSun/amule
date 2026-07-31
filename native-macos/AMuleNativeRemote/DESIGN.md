# aMule Native Remote Design System

## 1. Atmosphere & Identity

aMule Native Remote is a quiet macOS control room for a daemon that may be running elsewhere. The signature is native restraint: standard sidebars, toolbars, settings tabs, grouped forms, and semantic status surfaces rather than decorative panels.

## 2. Color

### Palette

| Role | Token | Light | Dark | Usage |
|------|-------|-------|------|-------|
| Surface/primary | system-window | system window background | system window background | Root content and settings |
| Surface/secondary | quaternary-fill | quaternary system fill | quaternary system fill | Pills, subtle value badges |
| Surface/elevated | system-popover | system popover material | system popover material | Inspectors, sheets, popovers |
| Text/primary | primary | primary | primary | Main labels and values |
| Text/secondary | secondary | secondary | secondary | Help text, empty states, metadata |
| Border/default | separator | separator | separator | Native dividers only when needed |
| Accent/primary | accentColor | accentColor | accentColor | Primary actions and selected controls |
| Status/success | green | green | green | Connected or healthy state |
| Status/warning | orange | orange | orange | Transitional or caution state |
| Status/error | red | red | red | Error and disconnected state |
| Status/info | blue | blue | blue | Download and network informational state |

### Rules

- Prefer SwiftUI semantic colors and system materials over custom hex colors.
- Use color to communicate status or interactivity, not decoration.
- Let sidebars and settings windows keep native macOS backgrounds.

## 3. Typography

### Scale

| Level | Size | Weight | Line Height | Tracking | Usage |
|-------|------|--------|-------------|----------|-------|
| Title | system title | semibold | system | 0 | Window and section titles |
| Headline | `.headline` | semibold | system | 0 | Group headings |
| Subheadline | `.subheadline` | regular/semibold | system | 0 | Secondary headings |
| Body | `.body` | regular | system | 0 | Forms and row text |
| Callout | `.callout` | regular | system | 0 | Dense rows and tree labels |
| Caption | `.caption` | regular/medium | system | 0 | Metadata, helper text, badges |

### Font Stack

- Primary: system San Francisco through SwiftUI system fonts.
- Mono: system monospaced for numeric or raw directory text.

### Rules

- Use `.monospacedDigit()` for live counters and graph values.
- Keep toolbar labels short; use `help` for clarification.
- Avoid hero-sized type inside utility windows.

## 4. Spacing & Layout

### Base Unit

All spacing derives from the native 4 px rhythm.

| Token | Value | Usage |
|-------|-------|-------|
| space-1 | 4 | Tight row internals |
| space-2 | 8 | Control groups, label/value gaps |
| space-3 | 12 | Compact section padding |
| space-4 | 16 | Standard content padding |
| space-5 | 20 | Sheet padding |
| space-6 | 24 | Settings page padding and major group gaps |

### Rules

- Stable primary window layout uses `NavigationSplitView` with native sidebar rows.
- Secondary controls belong in toolbar, inspector, popover, or settings tabs.
- Settings uses conventional macOS tabs, not a sidebar.

## 5. Components

### Source-List Sidebar Row

- **Structure**: `Label(title, systemImage:)` with optional badge.
- **Variants**: downloads filter row, remote page row.
- **States**: native selected, hover, focus, disabled.
- **Accessibility**: title is always visible; badge is supplementary.
- **Motion**: none.

### Page Toolbar Action

- **Structure**: `ToolbarItemGroup` with `Button` or `Menu` using SF Symbols.
- **Variants**: refresh, reload, download, stop, advanced.
- **States**: disabled when busy or capability missing; `help` explains icon-only items.
- **Accessibility**: label text remains present in `Label`.
- **Motion**: native button feedback only.

### Grouped Settings Form

- **Structure**: grouped `Form` pages selected by a standard preferences toolbar.
- **Variants**: connection, files, servers, security, remote, maintenance, interface.
- **States**: disabled for unsupported daemon operations.
- **Accessibility**: controls use labels, footers explain daemon limitations.
- **Motion**: native tab switching only.

### Preference Toolbar Tab

- **Structure**: macOS `NSToolbar` in `.preference` style with large icon-and-label tabs.
- **Variants**: network, files, servers, security, remote, interface, maintenance.
- **States**: selected tab uses the native toolbar selected appearance; unsupported controls remain disabled inside the active page.
- **Accessibility**: each tab has a visible label and SF Symbol.
- **Motion**: native preference tab switching only.

### Search Toolbar and Advanced Panel

- **Structure**: native toolbar search field for the query; fixed-width in-window Advanced panel with native grouped form sections.
- **Variants**: Criteria for pre-search daemon inputs; Results for post-search filtering and summary.
- **States**: editable, disabled while operation unsupported.
- **Accessibility**: the toolbar search field uses the file-name prompt; Advanced toggle semantics are native.
- **Motion**: no window resize when toggled.

### Statistics Panel

- **Structure**: transfer summary, graph cards, tree section.
- **Variants**: empty graphs, populated graphs.
- **States**: refresh disabled while busy or capability missing.
- **Accessibility**: chart labels and transfer summary remain visible.
- **Motion**: none.

## 6. Motion & Interaction

- Use native SwiftUI/AppKit interaction feedback.
- Do not add decorative animation.
- Avoid layout animation when switching sidebar destinations.
- Respect system reduced motion automatically by using native controls.

## 7. Depth & Surface

### Strategy

Mixed native: system materials for windows, tonal system fills for subtle badges, native dividers only for structural separation.

### Rules

- Do not nest cards inside cards.
- Do not paint custom opaque backgrounds on sidebar roots.
- Use grouped forms and inspectors for secondary settings instead of custom bordered panels.
