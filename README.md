# HWANGTODO

A **system-surface-first Eisenhower Matrix** assistant. The idea:
**Capture instantly. Decide by matrix. Execute through calendar, notes, widgets, and chat.**

Capture happens from Siri / Shortcuts / Action Button / Control Center / widgets
(or an in-app fallback). Everything lands in the Inbox, then you sort it into a
2×2 matrix and schedule what matters. The app is for judgment and organization.

## Build & run

```bash
xcodegen generate
xcodebuild -project HWANGTODO.xcodeproj -scheme HWANGTODO \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Requires `xcodegen` (`brew install xcodegen`). iOS 17 base; Control Center control
is iOS 18+, Live Activity is iOS 16.1+ (both availability-guarded).

### Running a widget from Xcode

Running the `HWANGTODOWidgets` scheme requires telling Xcode which widget kind to
launch via the `_XCWidgetKind` environment variable (Edit Scheme → Run →
Arguments → Environment Variables). Otherwise Xcode reports
`Please specify the widget kind … '_XCWidgetKind'` — this is a missing run
configuration, not a build failure. See **[TESTING.md](TESTING.md)** for the full
steps, the list of supported kind values, and the widget verification checklist.

## Targets (`project.yml`)

- **HWANGTODO** (app): SwiftUI UI, `TaskModel`, AppIntents + `AppShortcutsProvider`,
  EventKit, notifications, Live Activity start/stop, deep-link routing.
- **HWANGTODOWidgets** (WidgetKit extension): Home Screen matrix widgets
  (small/medium/large), Lock Screen accessory widgets (circular/rectangular),
  the iOS 18 Control Center control, and the Live Matrix Focus Live Activity UI.

Both targets carry the **App Group `group.com.hwangtodo.shared`** entitlement and
compile `Sources/Shared`, so they read/write one source of truth.

> Simulator signing: **manual ad-hoc** (`CODE_SIGN_STYLE: Manual`). Automatic
> signing with no team strips the App Group entitlement, silently breaking shared
> storage. For a device, set `DEVELOPMENT_TEAM` and register the App Group.

## Shared storage (no split-brain)

`TaskStore` (in `Sources/Shared`) persists JSON files (`hwangtodo_tasks.json`,
`hwangtodo_chat.json`) in the App Group container. App, widgets, and AppIntents
all use it. AppIntent writes call `WidgetCenter.reloadAllTimelines()`; the app
reloads from the store on foreground and on every deep link. Verified: a task
written via the AppIntent path appears in the correct Matrix quadrant.

## Product direction

HWANGTODO is **system-surface-first**: the main interface is Siri / Shortcuts /
Action Button / Control Center / widgets / Live Activity. The app is the control
center for review, organization, and setup — **capture first, organize later**.
UI copy is Korean.

## Tabs

`받은함` (Quick Inbox — the default home, capture-first) · `매트릭스` (organization
layer) · `캘린더` · `루틴` · `설정`. `채팅`(self-chat) and `집중`(Live Matrix focus) are
presented as sheets and reachable via deep link.

## Deep links

`hwangtodo://inbox · matrix · capture · chat · calendar · routine · setup · focus`
and `hwangtodo://quadrant/<urgentImportant|importantNotUrgent|urgentNotImportant|notUrgentNotImportant>`.

## iOS reality — impossible vs. implemented

| Surface | Impossible | Implemented instead |
| --- | --- | --- |
| Lock Screen | Live text field | Glanceable accessory widgets (matrix counts / status) that deep-link into capture / a quadrant |
| Notification Center | Custom interactive input cards | Standard local notifications (per-task reminder, daily matrix review, test) with action buttons |
| Dynamic Island / Live Activity | Arbitrary text input / editing | "Live Matrix Focus": current task, quadrant, elapsed timer, next action — start/stop from the app |
| Control Center | Full editor | iOS 18 control that opens Quick Capture |
| Apple Notes | Private database access | Note **link** (URL) + app-owned internal note body per task |
| Apple Calendar | Silent writes | EventKit with explicit permission; events created only on user action |

Captured tasks carry a `source` (app / shortcut / siri / actionButton /
lockScreenWidget / homeWidget / controlCenter / selfChat) surfaced as a badge.
