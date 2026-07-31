# Code Review: Native macOS Settings Toolbar

## Scope

- Reviewed `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/PreferencesWindowView.swift`.
- Reviewed updated regression contracts in `MacSettingsToolbarStyleTests.swift`, `MacUIRedesignTests.swift`, and `DESIGN.md`.

## Findings

No blocking findings.

## Notes

- The settings selector is now a real AppKit `NSToolbar` using `.preference` style and icon-and-label display mode.
- SwiftUI content is driven by the toolbar selection state, avoiding the oversized SwiftUI content tab bar observed during visual QA.
- Text fields use explicit labels and hidden field titles to prevent duplicate labels/values in macOS grouped forms.
- Subagents were not spawned because the active tool contract disallows spawning agents unless explicitly requested by the user.
