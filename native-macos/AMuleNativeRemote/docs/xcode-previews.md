# Using Xcode Previews in aMule Remote

## Quick Start

1. **Open the workspace**
   ```bash
   cd native-macos/AMuleNativeRemote
   open AMuleNativeRemote.xcworkspace
   ```

2. **Open any SwiftUI view file** (e.g., `DownloadsView.swift`)

3. **Show the Canvas**
   - Menu: `Editor > Canvas` (or press `Option + Command + Return`)
   - The preview canvas appears on the right side of the editor

4. **Resume the preview**
   - Click the **Resume** button (▶) in the canvas toolbar if it shows "Preview paused"
   - Previews auto-update when you edit the code

## Switching Between Preview States

Each view now has **multiple named previews** showing different states. For example, `DownloadsView.swift` has:
- **Disconnected** — shows the "Not Connected" empty state
- **Empty Connected** — shows connected but no downloads
- **Active Downloads** — shows downloading + paused items
- **Completed Downloads** — shows finished items
- **iPad** — shows the iPad layout variant

In the canvas, click the **preview selector** (top of canvas) to switch between named previews.

## Preview Devices & Sizes

Most previews default to **iPhone 17 Pro** size. To preview on a different device:

1. In the canvas toolbar, click the **device picker** (looks like a phone icon)
2. Select a device: iPhone SE, iPhone 17 Pro, iPad Pro, etc.
3. The preview re-renders at that size

For iPad-specific previews (like ContentView's "iPad - Sidebar"), use the iPad device to see the full sidebar-detail layout.

## Live vs Static Preview

- **Static** (default): Shows the view at compile time. Fastest.
- **Live**: Click the **Live Preview** button (▶️) in the canvas toolbar. Lets you tap buttons, scroll lists, and interact with the UI.
- **Live preview is slower** — use static for quick layout checks, live only when testing interaction.

## Where Previews Work

| Platform | Files with Previews |
|---|---|
| **iOS** | `ContentView.swift`, `DownloadsView.swift`, `SearchView.swift`, `ServersView.swift`, `SettingsView.swift`, `DownloadDetailView.swift` |
| **macOS** | `ContentView.swift`, `DownloadsPanel.swift`, `SearchWindowView.swift`, `ServersWindowView.swift`, `PreferencesWindowView.swift`, `DownloadDetailsWindowView.swift` |
| **SharedUI** | `SharedDownloadRow.swift`, `DownloadProgressViews.swift`, `SharedEmptyState.swift`, `SharedStatusBadge.swift`, `SharedConnectionIndicator.swift`, `SharedPanels.swift` |

## How the Preview Data Works

All preview data comes from **fixture helpers** that create model instances in specific states:

- **iOS**: `iOS/AMuleRemoteiOS/PreviewHelpers.swift` — `IOSAppModel.previewDisconnected()`, `.previewWithDownloads()`, etc.
- **macOS**: `Sources/AMuleNativeRemote/PreviewHelpers.swift` — `AppModel.previewDisconnected()`, `.previewWithDownloads()`, etc.
- **Shared**: `Packages/Shared/Sources/SharedViews/PreviewFixtures.swift` — `PreviewFixtures.downloadingDownload`, `.pausedDownload`, etc.

All helpers are wrapped in `#if DEBUG` so they don't ship in release builds.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Preview paused" / canvas is blank | Click **Resume** (▶) in the canvas toolbar |
| "Cannot preview in this file" | Make sure `ENABLE_PREVIEWS = YES` in build settings (already set) |
| Preview shows old code | Press **Option + Command + P** to refresh, or clean build folder (`Shift + Command + K`) |
| Live preview crashes | Switch back to static preview; live preview is more fragile |
| Build succeeds but preview fails | The preview compiler is separate from the app compiler. Try **Editor > Previews > Refresh** |
| iPad preview looks wrong | Make sure you selected an iPad device in the canvas device picker |

## Adding a New Preview

To add a preview state to an existing view:

```swift
#Preview("My New State") {
    NavigationStack {
        MyView(model: IOSAppModel.previewWithSomeData())
    }
}
```

For views that need `@State` in previews:

```swift
#Preview("Toggle State") {
    @Previewable @State var isOn = true
    MyToggleView(isEnabled: $isOn)
}
```

Keep previews in `#if DEBUG` blocks if they import preview helpers or use mock data.

## Performance Tips

- **Static previews are fast** — don't use live preview for layout tweaks
- **Previews compile incrementally** — only the changed file recompiles
- **Don't do real network calls in previews** — all our previews use fixture data, no network
- **If previews feel slow**, close unused preview tabs and reduce the number of named previews per file
