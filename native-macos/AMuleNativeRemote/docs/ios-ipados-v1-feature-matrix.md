# iOS/iPadOS v1 Feature Matrix and Platform Rules

## Defaults and non-negotiable platform rules

- Minimum target: **iOS 26.0** and **iPadOS 26.0**.
- Assume the latest iOS/iPadOS platform APIs available at that deployment target may be used.
- iPhone v1 is **single-window**.
- iPadOS v1 is **single scene** with a **native split layout** where it improves task flow.
- **No iPad multiwindow in v1**.
- The iOS/iPadOS app must remain **App Store-compatible**: self-contained, no downloaded-code execution, no external helper process model.
- macOS stays visually and structurally **as-is**. **macOS must not adopt iOS navigation, tab structure, or altered window layout** as part of this port.

## Scope defaults for v1

Included in v1 across iPhone and iPad unless the matrix says otherwise:

- remote connection/session status
- search
- downloads
- download details
- eD2k/link import
- server list basics
- essential preferences needed to connect and control transfer limits

Deferred unless they become nearly free after shared-contract extraction:

- advanced logs and diagnostics workflows
- IP filter management
- background automation beyond normal foreground app behavior

## Delivery legend

- **iOS v1**: included on both iPhone and iPad in v1
- **iPadOS v1**: included in v1 on iPad only
- **deferred**: not part of v1
- **macOS-only**: preserved on macOS, not ported in v1

## Window and feature matrix

| Surface / operation | macOS source | iPhone | iPad | Classification | Delivery mode | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Downloads | `downloads-window` | Yes | Yes | iOS v1 | Shared domain/state + native iOS/iPadOS container UI | Primary home surface for active transfers. |
| Download details | `download-details-window` | Yes | Yes | iOS v1 | Shared models + native navigation/detail presentation | Separate macOS window becomes push/sheet on iPhone and detail pane/presentation on iPad. |
| Search | `search-window` | Yes | Yes | iOS v1 | Shared search contracts + native search UI | Includes search query, scope, results, progress, and result actions. |
| Mock Search | `search-mock-window` | No | No | macOS-only | macOS-only | Keep as a macOS development/demo surface; do not port for v1. |
| Servers | `servers-window` | Yes | Yes | iOS v1 | Shared server contracts + native list/forms | Covers browse, refresh, connect, and basic add-server flows. |
| Diagnostics | `diagnostics-window` | No | No | deferred | Shared parsers later if extracted safely | Advanced logs/debug output/IP filter workflows are not MVP requirements. |
| Uploads | `uploads-window` | No | No | deferred | Shared payloads later | Useful parity target, but not required for first mobile release. |
| Shared Files | `shared-files-window` | No | No | deferred | Shared payloads later | Defer until core remote-control flows are stable. |
| Categories | `categories-window` | No | No | deferred | Shared payloads later | Defer dedicated management UI in v1. |
| Friends | `friends-window` | No | No | deferred | Shared payloads later | Not a v1 mobile-critical workflow. |
| Statistics | `stats-window` | No | No | deferred | Shared stats contracts later | Graph/tree monitoring is valuable but not MVP-critical. |
| Preferences | `preferences-window` | Yes | Yes | iOS v1 | Shared settings models + native Settings/Form UI | v1 includes connection endpoint, password, bridge capability display, and transfer limit controls; advanced diagnostics/IP-filter-oriented settings remain deferred. |
| Session status / remote control | `AppModel.status`, `isSessionConnected`, `bridgeOps`, `bridgeSchemaVersion` | Yes | Yes | iOS v1 | Shared domain contracts + native status presentation | Required top-level capability for launch, reconnect, and error handling. |
| eD2k / link import | App-level URL handling and add-links flow | Yes | Yes | iOS v1 | Native iOS/iPadOS URL/share handling + shared link parsing | Use native share/open-url intake on mobile; preserve current macOS handling unchanged. |
| Search progress / busy state | `searchProgress`, `isSearchInProgress`, `isBusy` | Yes | Yes | iOS v1 | Shared state + native progress UI | Required for clear remote operation feedback. |
| Download sources inspection | `downloadSourcesByHash`, `isRefreshingSources` | Yes | Yes | iOS v1 | Shared payloads + native nested detail UI | Lives inside downloads/details rather than a separate scene. |
| Core log / debug log viewing | `coreLogLines`, `coreDebugLogLines`, `lastCoreLogRawOutput`, `lastCoreDebugLogRawOutput` | No | No | deferred | Shared parsing only if needed later | Explicitly outside v1. |
| Connection rate controls | `connectionMaxDownloadKBps`, `connectionMaxUploadKBps` and saved settings | Yes | Yes | iOS v1 | Shared settings state + native form controls | Part of MVP preferences because transfer control is core remote functionality. |
| IP filter URL management | `ipFilterURLInput` | No | No | deferred | Deferred | Explicit non-goal for v1. |

## Shared vs native vs deferred vs macOS-only rules

### Shared across macOS and mobile

These should be shared only at the contract/model/parser level, not by forcing identical platform chrome:

- status/session models
- search request/result contracts
- downloads, sources, server, and connection-limit payloads
- link parsing/import validation
- bridge capability and error envelope handling

### Native iOS/iPadOS responsibilities

These stay mobile-native even when they use shared data/contracts:

- tab/navigation structure
- iPhone navigation stacks and sheets
- iPad split layout in a single scene
- share sheet / open-url intake
- clipboard/pasteboard integration
- settings forms and mobile error presentation

### Deferred from v1

- diagnostics window workflows
- uploads window
- shared files window
- categories window
- friends window
- statistics window
- advanced preference areas beyond connection and transfer-limit control
- IP filter management
- background automation/reliability work beyond normal foreground mobile operation

### macOS-only in v1

- existing macOS multiwindow scene model
- current macOS command/menu structure
- separate standalone macOS window layout for tools such as details/diagnostics/preferences
- mock-search development window

## Explicit scope exclusions / non-goals

The following are out of scope for this task and for iOS/iPadOS v1 planning:

- widgets
- notifications
- App Store submission workstreams beyond technical compatibility constraints
- macOS redesign
- iPad multiwindow in v1
- background download engine redesign

## Implementation guardrail summary

1. Port the **remote-control MVP**, not macOS window parity.
2. Keep macOS behavior and layout unchanged.
3. Prefer shared contracts/models where safe, but use native mobile navigation and platform services.
4. Treat deferred surfaces as intentional v1 omissions, not silent backlog drift.
