# HWANGTODO — Testing & Running Guide

## Running a widget from Xcode

A WidgetKit extension can't just be "run" — Xcode needs to know *which* widget
kind to launch. If you run the `HWANGTODOWidgets` scheme without specifying one,
Xcode fails with:

```
Please specify the widget kind in the scheme's Environment Variables using the
key '_XCWidgetKind' to be one of:
'HWANGTODOHomeLarge', 'HWANGTODOHomeMedium', 'HWANGTODOHomeSmall',
'HWANGTODOLockCircular', 'HWANGTODOLockRectangular', 'com.hwangtodo.control.capture'
```

This is **not** a build or implementation failure — it's a missing run
configuration. Fix it by telling the scheme which widget kind to preview.

### Steps

1. **Run the main `HWANGTODO` app first** (select the `HWANGTODO` scheme and run
   it once on your target simulator). This installs the app and seeds the shared
   App Group store, so the widget has real data to read.
2. In the scheme selector, **select the `HWANGTODOWidgets` scheme**.
3. Open **Product → Scheme → Edit Scheme…** (Edit Scheme).
4. Go to **Run → Arguments → Environment Variables**.
5. Add an environment variable:
   - **Name:** `_XCWidgetKind`
   - **Value:** `HWANGTODOHomeMedium`
6. Close the scheme editor and **Run** the `HWANGTODOWidgets` scheme. Xcode
   launches that single widget in the widget preview host.

### Supported `_XCWidgetKind` values

Set the value to exactly one of the following (these are the `kind` strings
declared in the widget implementations):

| `_XCWidgetKind` value          | Widget                          | Family                | Source |
| ------------------------------ | ------------------------------- | --------------------- | ------ |
| `HWANGTODOHomeSmall`           | Home Screen matrix (small)      | `.systemSmall`        | `Sources/Widgets/HomeMatrixWidgets.swift` |
| `HWANGTODOHomeMedium`          | Home Screen matrix (medium)     | `.systemMedium`       | `Sources/Widgets/HomeMatrixWidgets.swift` |
| `HWANGTODOHomeLarge`           | Home Screen matrix (large)      | `.systemLarge`        | `Sources/Widgets/HomeMatrixWidgets.swift` |
| `HWANGTODOLockCircular`        | Lock Screen count               | `.accessoryCircular`  | `Sources/Widgets/LockScreenWidgets.swift` |
| `HWANGTODOLockRectangular`     | Lock Screen status              | `.accessoryRectangular` | `Sources/Widgets/LockScreenWidgets.swift` |
| `com.hwangtodo.control.capture`| Control Center capture control  | Control (iOS 18+)     | `Sources/Widgets/HWANGTODOControl.swift` |

### Important notes

- **One widget kind per run.** `_XCWidgetKind` selects a single widget to launch;
  to preview a different one, change the value and run again. You cannot launch
  multiple kinds in a single run.
- **The value must exactly match the `kind` string** declared in the widget
  implementation (case-sensitive, no extra spaces). The table above is the
  source of truth; the strings are defined as `let kind = "…"` in each `Widget`
  (and `StaticControlConfiguration(kind: "…")` for the control).
- The **Control Center control** (`com.hwangtodo.control.capture`) only runs on a
  simulator/iOS runtime that supports Control Center controls (**iOS 18+**). On
  iOS 17 runtimes it will not be launchable; that is expected.
- Widgets read the **shared App Group store**, so run the app at least once first
  (and capture a few tasks) to see real matrix counts instead of placeholder data.

### Adding widgets to the Home / Lock Screen (alternative to the preview host)

Instead of the `_XCWidgetKind` preview, you can also add the widgets the normal
way after running the app:

- **Home Screen:** long-press the Home Screen → **+** → search "HWANGTODO" → pick
  Small / Medium / Large.
- **Lock Screen:** long-press the Lock Screen → **Customize** → **Lock Screen** →
  add a widget → pick the HWANGTODO circular or rectangular accessory.
- **Control Center (iOS 18+):** edit Control Center → **Add a Control** → HWANGTODO.

## Widget verification checklist

Run each kind via `_XCWidgetKind` (or add it to the Home/Lock Screen) and confirm
it launches and renders without clipping:

- [ ] `HWANGTODOHomeSmall` — Home Small launches
- [ ] `HWANGTODOHomeMedium` — Home Medium launches
- [ ] `HWANGTODOHomeLarge` — Home Large launches
- [ ] `HWANGTODOLockCircular` — Lock Circular launches
- [ ] `HWANGTODOLockRectangular` — Lock Rectangular launches
- [ ] `com.hwangtodo.control.capture` — Control Center control launches *(only if
      the current simulator/iOS runtime supports Control Center controls, iOS 18+)*

## Troubleshooting: "Failed to get descriptors for extensionBundleID"

If Xcode's widget debug launcher reports:

```
Failed to show Widget 'com.hwangtodo.app.widgets'
SBAvocadoDebuggingControllerErrorDomain Code=1
"Failed to get descriptors for extensionBundleID (com.hwangtodo.app.widgets)"
```

this is almost always **stale simulator/SpringBoard state**, not a code or config
problem. Diagnosed cause on this project: a `_XPC_MISUSE_FAULT` inside BoardServices
(`BSBundleIDForXPCConnection…`) when SpringBoard's Avocado service connects to the
extension — the fault is entirely in Apple frameworks; no HWANGTODO code runs. The
extension is correctly built, embedded, signed, and its bundle id / `NSExtension`
are valid.

Fix (clean install state):

```bash
DEV=<your-simulator-udid>          # e.g. `xcrun simctl list devices | grep Booted`
xcrun simctl uninstall "$DEV" com.hwangtodo.app
rm -rf ~/Library/Developer/Xcode/DerivedData/HWANGTODO-*
xcodebuild -project HWANGTODO.xcodeproj -scheme HWANGTODO \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" clean build
# If the fault persists, fully erase the simulator state:
xcrun simctl shutdown "$DEV"; xcrun simctl erase "$DEV"; xcrun simctl boot "$DEV"
# Reinstall and LAUNCH THE HOST APP ONCE so SpringBoard registers the extension:
APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*Debug-iphonesimulator/HWANGTODO.app" -type d | head -1)
xcrun simctl install "$DEV" "$APP"
xcrun simctl launch "$DEV" com.hwangtodo.app
# Verify the extension is registered (descriptor-discoverable):
xcrun simctl spawn "$DEV" pluginkit -m | grep com.hwangtodo.app.widgets
```

The host app **must be launched at least once after install** before the widget
gallery or Xcode's widget debug launcher can read the extension's descriptors.

## Kind-string source of truth

Verified that the `kind` strings in code exactly match the values Xcode expects:

| Code location                                   | `kind` string                   |
| ----------------------------------------------- | ------------------------------- |
| `HomeMatrixWidgets.swift` → `HomeMatrixSmall`   | `HWANGTODOHomeSmall`            |
| `HomeMatrixWidgets.swift` → `HomeMatrixMedium`  | `HWANGTODOHomeMedium`          |
| `HomeMatrixWidgets.swift` → `HomeMatrixLarge`   | `HWANGTODOHomeLarge`           |
| `LockScreenWidgets.swift` → `LockMatrixCircular`| `HWANGTODOLockCircular`        |
| `LockScreenWidgets.swift` → `LockMatrixRectangular` | `HWANGTODOLockRectangular`  |
| `HWANGTODOControl.swift` → `HWANGTODOControl`   | `com.hwangtodo.control.capture` |

If you rename a widget's `kind`, update this table **and** your scheme's
`_XCWidgetKind` value to match.
