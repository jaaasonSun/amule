# Native macOS Settings Toolbar Style

## Bootstrap

- Brief: implement the classic macOS Settings/Preferences top icon-and-text toolbar tab style, replacing the segmented strip, and polish every settings page.
- Session: `.omo/ulw-loop/native-macos-settings-toolbar-20260709/`.
- Tier: HEAVY. Reason: user-facing macOS settings redesign with AppKit window toolbar bridge and full visual QA expectations.
- Shape: delivery.

## Skills

- `omo:ulw-loop`: durable criteria, evidence, checkpoint.
- `build-macos-apps:swiftui-patterns`: native Settings scene and TabView settings guidance.
- `build-macos-apps:appkit-interop`: narrow `NSWindow` access for `.preference` toolbar style/display mode.
- `build-macos-apps:build-run-debug`: Swift/Xcode build verification.
- `omo:frontend`: existing UI redesign and DESIGN.md contract.
- `omo:visual-qa`: rendered settings screenshots and visual inspection.

## Subagent Note

`multi_agent_v1` is available but its tool contract says not to spawn agents unless the user explicitly asks for subagents/delegation. This conflicts with ULW's default HEAVY delegation language, so implementation/review will be main-thread with artifact-backed self review unless the user explicitly asks for subagents.

## Initial Findings

- Current `PreferencesWindowView` is the prior round's segmented picker plus manual `switch`, not the classic macOS icon-and-text settings toolbar.
- Existing `DESIGN.md` already says settings should use conventional macOS tabs, but its component section still says `TabView` and should be refined to the AppKit preference toolbar style.
- Existing `MacUIRedesignTests` covers no sidebar and optional Categories/Friends, but now needs stricter proof that segmented tabs are removed and a `TabView` + preference toolbar bridge exists.

## Planned Criteria

- C001: Source guard RED/GREEN for classic settings toolbar style.
- C002: Render Preferences settings pages in representative tabs and inspect screenshots for layout, sizing, and section polish.
- C003: Regression build/test gate for native app settings integration.

## Implementation Notes

- Initial SwiftUI `TabView` implementation rendered as an oversized content tab bar in the screenshot surface, without the requested icon-and-label preferences toolbar feel.
- Final implementation uses an AppKit `NSToolbar` configured with `.preference`, selectable toolbar item identifiers, SF Symbol images, and `.iconAndLabel` display mode.
- SwiftUI now switches grouped `Form` pages from the toolbar selection state, avoiding the visible content tab bar while preserving native macOS preferences behavior.
- Text input rows were changed from `LabeledContent`/field-title rendering to explicit row labels plus hidden field titles, because macOS Form rendered duplicate placeholder/value text in screenshots.
- Representative screenshots confirmed the toolbar, Connection, Files, Interface, and Maintenance settings pages.

## Verification

- `swift test --filter MacSettingsToolbarStyleTests`: pass.
- `swift test --filter MacNativeNavigationTests`: pass.
- `swift test`: pass, 125 tests.
- `swift build -Xswiftc -warnings-as-errors`: pass.
- `./scripts/build-app.sh`: pass, `BUILD SUCCEEDED`, rebuilt `dist/aMule Remote.app`.
- `git diff --check`: pass.
