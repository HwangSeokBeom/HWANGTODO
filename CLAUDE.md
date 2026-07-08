# HWANGTODO

Capture-first Korean iOS TODO app: 잠금화면·액션 버튼·Siri·단축어·제어센터·위젯·알림에서
1초 안에 기록하고, 앱 본체는 정리·계획·루틴을 위한 HQ. Product spec: `Docs/REQUIREMENTS.md`.

## Build & tools

- `make gen` — regenerate `HWANGTODO.xcodeproj` from `project.yml` (**source of truth**;
  never edit the pbxproj by hand, always regen after adding/removing files).
- `make build` / `make test` / `make run` — simulator: iPhone 17 Pro.
- `make lint` / `make format` — SwiftLint + SwiftFormat.
- `make icon` — re-render the app icon from `Scripts/render_appicon.swift`.
- Signing is **Manual on purpose** (see comment in project.yml): automatic signing
  with no team silently strips the App Group entitlement.

## Architecture

- iOS 26.0 minimum, Swift 6 language mode, Approachable Concurrency,
  **MainActor-by-default isolation** (app target + package). The widget target is
  `nonisolated` by default — hop with `await`.
- `Packages/HWANGTODOKit`:
  - `HWANGTODOCore` — SwiftData models (`TodoItem`, `Routine`, `ChatEntry`),
    `SharedStore` (App Group SQLite container), `TodoRepository` (the ONLY write
    path; observable arrays for UI), `GlanceSnapshot` (Sendable widget snapshot),
    `DeepLink`, `Terminology`, `ThoughtSplitter`, `SurfaceStatusService`,
    `FocusActivityAttributes`, `WidgetKind`, `LegacyJSONImporter`, `DebugSeeder`.
  - `HWANGTODODesign` — `Theme` tokens, adaptive colors (`Color.hwangAccent`,
    `Quadrant.accent`), components (`cardSurface()`, `SourceBadge`, `QuadrantTag`,
    `ProgressRing`, `EmptyStateView`, `SectionHeader`, `QuickCaptureField`).
- App target: `Sources/App` (views, `AppRouter`, services, AppIntents).
  Widget extension: `Sources/Widgets`.
- Pure data types in the package are explicitly `nonisolated`; UI-facing state
  is `@Observable` injected via `.environment()` — no `ObservableObject`.

## Invariants (do not break)

- **Frozen strings**: enum raw values (`Quadrant`, `TaskStatus`, `CaptureSource`),
  `WidgetKind` kinds, deep-link hosts, App Group id `group.com.hwangtodo.shared`.
- Every store mutation goes through `TodoRepository` (saves + reloads +
  `WidgetCenter.reloadAllTimelines()`); widget-process intents write via
  `SharedStore.context` and reload timelines themselves.
- Capture-source honesty: each surface passes its real `CaptureSource` — never
  fake a badge.
- 용어 (spec §14): user-facing Korean only. **Banned**: 받은함, 보관함, Inbox,
  Archive, AI 분석, Dashboard. Vocabulary constants live in `Terminology`;
  quadrant names come from `Quadrant.title` (지금 할 일/계획할 일/맡길 일/줄일 일).
  나와의 채팅 is deterministic extraction — never call it AI.
- Sample data: `DebugSeeder` is DEBUG-only and never runs automatically.

## Verification vocabulary (spec §16)

Report feature states as: Built / Wired / Visually Verified / Simulator Verified /
Real Device Verified / Not Verified / iOS Limited. "Build succeeded" is not "done".
The living matrix is `VERIFICATION.md`.
