# SwipeNote Product Planning Document v0.1

> Status: Draft for PoC / MVP scoping
> Platform: iPhone (iOS), SwiftUI
> Author role: Product Strategy + iOS UX + SwiftUI Tech Lead

---

## 1. One-line product definition

**SwipeNote is a capture-first inbox for thoughts and tasks: you write one line in under two seconds, it lands in an Inbox, and you decide what it actually is — TODO, memo, today, or scheduled — later.**

---

## 2. Problem definition

**Existing TODO/memo apps are too slow at the only moment that matters: capture.**
The thought you want to record is fragile. It survives for a few seconds. Most apps ask you to make 3–6 decisions (date, time, priority, list, category, type) before the thought is saved. By the time the form is filled, the thought has either degraded or the urge to record it is gone.

**Why users postpone capturing thoughts:**
- The capture UI implies "you must organize this now."
- Choosing a list/category forces a classification decision the user hasn't made yet ("Is this a task or just a note?").
- Setting a date forces a planning decision ("When will I actually do this?") that is harder than the thought itself.
- The cost of capturing feels higher than the cost of trying to remember it — so the user gambles on memory and loses.

**Why date/time/priority/category at capture time creates friction:**
- These are *organizing* decisions, not *capture* decisions. They require context the user doesn't have mid-walk, mid-meeting, or mid-task.
- Each required field is a micro-interruption that breaks the flow of whatever the user was actually doing.
- Defaults are dishonest: "Today, no time, no priority" is noise that the user later has to clean up anyway.

**Why people forget tasks even with a TODO app installed:**
- The app is installed but not *reachable* in the 2-second window. Opening it, finding the right list, and filling a form exceeds the window.
- Items captured with heavy metadata feel "done" and get buried; items never captured are simply lost.
- The friction trains users to *not* open the app, so the app becomes a graveyard rather than a habit.

**Core insight:** Capture and organization are two different jobs with two different cost tolerances. Today's apps merge them and pay the merged cost at the worst possible time.

---

## 3. Target users

| Segment | Why they need SwipeNote |
| --- | --- |
| **Busy workers / knowledge workers** | Thoughts arrive during meetings and deep work; they can't stop to fill a form. |
| **Developers** | Context-switch constantly ("fix TokenForge layout", "summarize SSO"); need to dump and return to flow instantly. |
| **Students** | Mix of tasks, reminders, and study notes that don't yet have a structure. |
| **High context-switchers** | People juggling multiple projects/roles who lose items in the gaps between contexts. |
| **"Capture now, sort later" people** | Anyone whose mental model is a single brain-dump stream, not a pre-sorted hierarchy. |

Anti-persona: users who want a full project-management system, Gantt charts, or team task assignment. SwipeNote is not for them (see §12).

---

## 4. Core user scenarios

**S1 — A thought appears while walking.**
> As a user walking to the station, I remember I need hair wax. I raise my phone, the app (via Action Button or Lock Screen widget) opens straight into a focused text field. I type "Buy hair wax", press return, pocket the phone. Total interaction: ~2 seconds. No date, no list chosen.

**S2 — A task appears during work.**
> While coding, I realize the TokenForge layout is broken. I don't want to lose focus. I trigger quick capture, type "Review TokenForge layout issue", hit return, and I'm back in my editor. The item sits in Inbox as `undecided`.

**S3 — A memo appears while using another app.**
> Reading a Slack thread, I want to remember to "Summarize LoroTopik SSO". I select the text, tap Share, choose SwipeNote. The text becomes an Inbox card without me leaving Slack.

**S4 — The user checks unorganized items from a card-style Inbox.**
> At lunch, I open the Inbox and see a stack of notification-style cards: "Call mom", "Check credit card bill", "AX workflow automation idea". I scan them in 5 seconds, swipe "Call mom" to Done, and leave the rest.

**S5 — The user organizes the Inbox at night.**
> Before bed, a gentle reminder says "12 items waiting in your Inbox." I open it, tap each card, and lightly sort: "Write today's work log tomorrow" → Scheduled (tomorrow morning), "AX workflow automation idea" → Memo, "Check credit card bill" → Today. The app never scolds me for the backlog.

**S6 — The user turns one rough memo into a scheduled task.**
> "Write today's work log tomorrow" was captured as raw text. I tap it; the app has already detected "tomorrow" and suggests a due date. I accept, set a 9:00 AM reminder, mark it TODO, and move it to Scheduled. One card, three taps.

---

## 5. Core UX principles

1. **Capture in 1–2 seconds.** From intent to saved, nothing should exceed two interactions (open → type → return).
2. **Organize later.** Organization is a separate, optional, deliberate session — never blocking capture.
3. **One input field only.** The capture screen has exactly one text field. No type toggle, no date picker, no list selector.
4. **Inbox-first structure.** Every capture goes to Inbox with `status = inbox`, `type = undecided`. Inbox is the default home of new thoughts.
5. **TODO/memo distinction happens later.** The app does not ask "is this a task or a note?" at capture time.
6. **Date/time/priority are optional, always.** They exist only in the organizing flow and never block anything.
7. **No forced category selection.** Tags are optional and added later; there is no required taxonomy.
8. **Completion and archive over deletion.** The primary verbs are Done and Archive. Delete exists but is de-emphasized — finishing or filing should feel better than erasing.
9. **Reduce guilt, not create pressure.** Backlog is normal. Copy and visuals are calm and non-punitive. No red overdue badges screaming at the user, no "you failed" framing.

---

## 6. Main screen structure

### 6.1 Quick Capture screen
- **Purpose:** The fastest possible path from thought → stored card.
- **Main UI elements:** Single multi-line-capable text field (keyboard auto-focused), a subtle "Saved ✓" confirmation toast, an unobtrusive "View Inbox" affordance.
- **Primary actions:** Type → Return/Save (creates card, clears field, keeps focus for the next item). Optional swipe-down/Done to dismiss.
- **Empty state:** Placeholder text in the field (see §17). No instructions cluttering the screen.
- **Important UX details:** Keyboard MUST be focused on appear. Return key = save + keep capturing (does not dismiss). No modal, no confirmation dialog, no metadata prompts. Haptic tick on save.

### 6.2 Inbox screen
- **Purpose:** Holding area for all unorganized captures, displayed as scannable cards.
- **Main UI elements:** Vertically stacked notification-style cards (newest on top or grouped — see §9), a count header ("12 in Inbox"), a prominent "＋ Capture" button.
- **Primary actions:** Swipe right = Done, swipe left = Later, long-press = Organize sheet, tap = Detail. Pull to capture / floating capture button.
- **Empty state:** Calm "Inbox zero" message (see §17), not an error.
- **Important UX details:** Cards show raw text and relative time. Aging unorganized items get gently resurfaced (§9). No required action — the user can leave everything.

### 6.3 Today screen
- **Purpose:** The short list of things the user chose to handle today.
- **Main UI elements:** Compact list of items with `status = today` (plus scheduled items whose date is today), each with a checkbox/swipe-to-complete.
- **Primary actions:** Complete (→ Done), bump to Later, open Detail.
- **Empty state:** "Nothing scheduled for today. Capture freely." (see §17)
- **Important UX details:** Today is curated, not auto-flooded. Items only appear here if the user moved them here or scheduled them for today. AI may *suggest* "Handle today" candidates, never auto-assign.

### 6.4 Organize / Detail screen (sheet)
- **Purpose:** Optional enrichment of a single item.
- **Main UI elements:** Editable text, Type segmented control (Undecided / TODO / Memo), Date, Time, Reminder toggle, Priority, Tags, Pin, and a status/destination row (Today / Later / Scheduled / Done / Archive). AI suggestion chips at top (accept/dismiss).
- **Primary actions:** Set any subset of fields; choose a destination; Save.
- **Empty state:** N/A (always operates on an item). All fields start empty/optional.
- **Important UX details:** Presented as a bottom sheet, dismissable without saving changes destructively. Nothing is required. AI suggestions are pre-filled as *dismissible chips*, never silently applied.

### 6.5 Done / Archive screen
- **Purpose:** A satisfying record of finished and filed items.
- **Main UI elements:** Two segments — Done (completed) and Archive (filed without completion). Grouped by date.
- **Primary actions:** Restore to Inbox/Today, permanently delete (secondary).
- **Empty state:** "Finished items will gather here." / "Nothing archived yet."
- **Important UX details:** Completion is celebrated lightly (subtle animation/haptic on the act, calm list here). Restore is easy; delete is intentionally one step removed.

### 6.6 Settings screen
- **Purpose:** Minimal configuration.
- **Main UI elements:** Notifications (Inbox cleanup reminder time/toggle), default capture behavior, AI suggestions on/off, Action Button / Shortcuts help, sample-data reset, About.
- **Primary actions:** Toggle reminders, manage permissions, enable/disable AI.
- **Empty state:** N/A.
- **Important UX details:** Keep it short. No account, no sync settings in MVP.

---

## 7. Capture flow

```
User triggers SwipeNote (icon / Action Button / widget / Shortcut)
        │
        ▼
App opens DIRECTLY on Quick Capture; keyboard is already focused
        │
        ▼
User types one line of text
        │
        ▼
User presses Return (or taps Save)
        │
        ▼
CaptureItem created: status = inbox, type = undecided, createdAt = now
        │
        ▼
Field clears, keyboard stays up, subtle "Saved ✓" toast + haptic
        │
        ▼
User immediately types the next item  ──►  (repeat)
```

**Hard rules:**
- No modal sheet appears.
- No date/time/category/priority question appears.
- No "are you sure" dialog.
- Return does not dismiss — it saves and keeps the user in capture mode.
- The only way capture "fails" is an empty string (silently ignored).

---

## 8. Organizing flow

```
User opens Inbox
        │
        ▼
User taps a card  ──►  Organize/Detail sheet opens
        │
        ├─ (optional) Type:     undecided | TODO | memo
        ├─ (optional) Date
        ├─ (optional) Time
        ├─ (optional) Reminder  (schedules a local notification)
        ├─ (optional) Priority
        ├─ (optional) Tags
        ├─ (optional) Pin
        │
        ▼
User chooses a destination (status):
        Today | Later | Scheduled | Done | Archive
        │
        ▼
Save → item leaves Inbox view according to new status; updatedAt = now
```

**Notes:**
- Every field is skippable. A user can move a card to Today and set nothing else.
- "Later" keeps it in the backlog but de-prioritizes resurfacing.
- "Scheduled" requires a date (the only conditional requirement) and may attach a reminder.
- AI suggestions (detected date, suggested type, suggested priority) appear as chips the user taps to accept.

---

## 9. Card UX

The Inbox should *feel* like iOS notification cards — glanceable, stacked, dismissible.

**Card layout (before organization):**
```
┌─────────────────────────────────────┐
│  Review TokenForge layout issue      │
│  2h ago · Inbox                       │
└─────────────────────────────────────┘
```
- Line 1: raw text (truncated to ~2 lines).
- Line 2: relative time + status hint.
- Minimal chrome, rounded corners, soft shadow — notification aesthetic.

**Card layout (after organization):**
```
┌─────────────────────────────────────┐
│ ● TODO  ★                            │
│  Write today's work log              │
│  Tomorrow 9:00 · #work · 🔔          │
└─────────────────────────────────────┘
```
- Type dot (TODO/Memo color), pin star, priority accent.
- Metadata row: due date/time, tags, reminder icon — only what exists.

**Swipe actions:**
| Gesture | Action |
| --- | --- |
| Swipe right | Done (complete) |
| Swipe left | Later (defer in backlog) |
| Long press | Open Organize sheet |
| Tap | Open Detail |

**Card stacking behavior:**
- Default sort: newest first.
- Optional grouping by capture day ("Today", "Yesterday", "Earlier").
- Many items present as a clean vertical stack, not a literal physical pile (avoid gimmicks that hurt scannability).

**Visual priority rules:**
- Pinned items float to the top with a star.
- High priority = subtle left accent bar (not aggressive red).
- Reminder/due-today items get a small clock highlight.
- Color is used sparingly; default unorganized cards are neutral.

**Surfacing old unorganized items:**
- Items in Inbox for > N days (e.g., 3) get a soft "Still here?" tag and may bubble up in a "Needs review" group.
- The nightly Inbox cleanup notification counts these.
- No red, no guilt — phrasing stays neutral ("7 older items").

---

## 10. MVP scope

A realistic SwiftUI iOS MVP includes:

- **Local-first storage** (SwiftData, on-device only).
- **Quick capture** screen (keyboard-focused, one field, return-to-save-and-continue).
- **Inbox** with notification-style cards and swipe actions.
- **Today** list (curated + scheduled-for-today).
- **Done / Archive** screen.
- **Basic reminder** via local notifications (single fire date/time).
- **Simple natural-language date detection** ("today", "tomorrow", "this week", "morning", "night").
- **Basic tags** (free-form, optional).
- **Basic priority** (e.g., none / normal / high).
- **Sample data** seeded on first run for demoability.
- **Clean SwiftUI UI** following the card aesthetic.

---

## 11. Out of scope for MVP

Explicitly excluded from MVP:
- Team collaboration / shared lists.
- Complex project management (sub-projects, dependencies).
- Two-way calendar sync.
- Gantt charts / timeline views.
- Full conversational AI chatbot.
- Social features (sharing feeds, following).
- Account system / login.
- Server sync.
- Multi-device sync (incl. iCloud) — deferred to future.
- Complex recurring tasks (custom RRULE-style recurrence).
- Notion-style customizable databases / properties.

---

## 12. Differentiation

| App | What it is | How SwipeNote differs |
| --- | --- | --- |
| **Apple Reminders** | List-centric reminder system; capture nudges you toward a list + date. | SwipeNote needs no list/date at capture; one stream, sorted later. |
| **Todoist** | Powerful task manager with projects, labels, filters, NL parsing. | SwipeNote rejects upfront structure; it's a capture funnel, not a manager. |
| **Things** | Beautifully structured GTD app (Inbox → Today → Areas/Projects). | Things' Inbox is a feature; SwipeNote makes *capture + later-sorting the whole product* and strips planning ceremony. |
| **Notion** | Flexible database/workspace; high setup cost. | SwipeNote is zero-setup, single-purpose, offline, instant. |
| **Bear / Apple Notes** | Note editors optimized for long-form writing. | SwipeNote treats each line as a liftable card that can become a task; notes and tasks share one capture path. |

**Positioning statement:** SwipeNote is **not** a productivity-management system. It is a **fast capture and later-organization tool** — the thinnest possible layer between a thought and a place to put it. It complements, rather than replaces, a heavier task manager downstream.

---

## 13. Data model draft

### Entity: `CaptureItem`
| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID | Primary key |
| `rawText` | String | The captured line (source of truth) |
| `type` | enum | `undecided` / `todo` / `memo` |
| `status` | enum | `inbox` / `today` / `scheduled` / `done` / `archived` (+ `later`) |
| `createdAt` | Date | Capture time |
| `updatedAt` | Date | Last modification |
| `dueDate` | Date? | Optional |
| `reminderDate` | Date? | Optional, drives local notification |
| `priority` | enum? | `none` / `normal` / `high` |
| `tags` | [String] | Optional free-form |
| `isPinned` | Bool | Default false |
| `aiSuggestedDate` | Date? | Detected, not applied until accepted |
| `aiSuggestedType` | enum? | Suggested `todo`/`memo` |
| `completedAt` | Date? | Set when moved to `done` |
| `archivedAt` | Date? | Set when moved to `archived` |

### Suggested Swift enums

```swift
enum ItemType: String, Codable, CaseIterable {
    case undecided, todo, memo
}

enum ItemStatus: String, Codable, CaseIterable {
    case inbox, today, later, scheduled, done, archived
}

enum ItemPriority: String, Codable, CaseIterable {
    case none, normal, high
}
```

> Note: `later` is added to the spec'd status list because the swipe-left action needs a distinct backlog state separate from `inbox`. Treat `later` as "in backlog, de-prioritized for resurfacing."

### Suggested SwiftData model direction

```swift
import SwiftData
import Foundation

@Model
final class CaptureItem {
    @Attribute(.unique) var id: UUID
    var rawText: String
    var typeRaw: String          // ItemType.rawValue
    var statusRaw: String        // ItemStatus.rawValue
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var reminderDate: Date?
    var priorityRaw: String?     // ItemPriority.rawValue
    var tags: [String]
    var isPinned: Bool
    var aiSuggestedDate: Date?
    var aiSuggestedTypeRaw: String?
    var completedAt: Date?
    var archivedAt: Date?

    init(rawText: String) {
        self.id = UUID()
        self.rawText = rawText
        self.typeRaw = ItemType.undecided.rawValue
        self.statusRaw = ItemStatus.inbox.rawValue
        self.createdAt = .now
        self.updatedAt = .now
        self.tags = []
        self.isPinned = false
    }
}
```

- Expose computed `type`/`status`/`priority` accessors that bridge to the enums, keeping stored values as String for forward-compatibility.
- Consider keeping enums as String-backed to avoid migration pain if new cases are added.

### Local-first persistence notes
- SwiftData with the default on-device store; no CloudKit container in MVP.
- All writes are synchronous and local; capture must never await network.
- Seed sample data on first launch behind a `hasSeeded` flag in `UserDefaults`.
- Keep the model flat (single entity) for MVP; tags as `[String]` rather than a separate Tag entity until grouping features demand it.

---

## 14. Technical design direction

- **SwiftUI** — entire UI; `@Query`-driven lists from SwiftData; bottom sheets via `.sheet`/`.presentationDetents`.
- **SwiftData vs CoreData** — **SwiftData** for MVP (less boilerplate, native @Model, good enough for a single entity). CoreData only if a hard SwiftData limitation appears; the model is simple enough that switching later is low-risk.
- **UserNotifications** — request authorization lazily (first time a reminder or cleanup reminder is enabled). Schedule `UNCalendarNotificationTrigger`/`UNTimeIntervalNotificationTrigger` for item reminders and the nightly Inbox-cleanup nudge.
- **App Shortcuts / Siri Shortcuts** — `AppIntents` framework: a "New SwipeNote capture" intent that accepts a text parameter; enables "Hey Siri, add to SwipeNote …" and Shortcuts automations.
- **Share Sheet extension** — a Share Extension that accepts text/URL and writes a `CaptureItem` to the shared store (App Group) so captures from other apps land in Inbox.
- **Home Screen widgets** — WidgetKit: a capture-launch widget (deep links to Quick Capture) and optionally a small Inbox-count widget.
- **Lock Screen widgets** — WidgetKit accessory widgets (`.accessoryCircular`/`.accessoryRectangular`) that deep-link straight into Quick Capture from the Lock Screen.
- **Action Button shortcut support** — expose the capture App Intent so users can bind the Action Button (15 Pro+) to "open SwipeNote quick capture."
- **Spotlight search** — `CSSearchableItem` / Core Spotlight indexing of `rawText` so captures are findable system-wide; reasonable as a fast-follow.
- **iCloud sync** — **future only.** SwiftData + CloudKit is the planned path; keep the model CloudKit-compatible (optional fields, no unique constraints that break sync) to ease the later switch.

**App Group note:** Share Extension, widgets, and the main app must share a store via an App Group container for captures to be unified.

---

## 15. iOS platform constraints (reality check)

**Can a third-party app freely add a custom panel inside iOS Control Center?**
No. Apps cannot inject arbitrary custom UI into Control Center. iOS 18 added **Control Center controls via the `WidgetKit`/`AppIntents` Controls API**, which lets an app ship a *control* (a button/toggle) the user can add to Control Center. So SwipeNote can offer a **Control Center control that launches Quick Capture** — but it cannot render its own full panel/text field inside Control Center.

**Can the app directly control Notification Center UI?**
No. Apps cannot draw into or manage Notification Center. They can only post notifications through `UserNotifications`. The "notification card" look in SwipeNote is an **in-app visual style**, not real system notifications.

**Can the app display persistent notification-like cards (in the system)?**
No persistent system cards. Notifications are transient and user-dismissable; there is no API to pin a permanent card to the Lock Screen or Notification Center. (Live Activities exist but are for time-sensitive, ongoing events — not a general inbox; not appropriate here for MVP.)

**What can be done instead — practical alternatives:**
- **App opens directly into focused Quick Capture** (keyboard up on launch) — the single most important lever.
- **Lock Screen widget** → deep-links to Quick Capture.
- **Home Screen widget** → deep-links to Quick Capture.
- **Action Button** (15 Pro+) → bound to the capture App Intent.
- **Control Center control** (iOS 18+) → one tap to launch capture.
- **Siri Shortcut / App Intent** → "Add to SwipeNote …" creates a capture by voice.
- **Share Sheet extension** → capture selected text/links from any app.
- **Local notifications** → nightly "clean your Inbox" nudge (the closest legitimate analog to notification-center surfacing).
- **In-app Inbox** styled to *mimic* notification cards — delivering the desired feel without needing system-level control.

**Takeaway:** SwipeNote cannot own Control Center or Notification Center. It can be *reachable* from every fast entry point iOS allows (widgets, Action Button, Control Center control, Siri, Share Sheet) and can *recreate* the notification-card experience inside its own Inbox.

---

## 16. PoC implementation scope (Codex-friendly)

A self-contained SwiftUI app, no backend, no login:

- **3–5 screens:** Quick Capture, Inbox (card list), Today, Detail/Organize sheet, Done/Archive.
- **Local sample data** seeded on first launch (the example inputs from the brief).
- **Quick capture input:** keyboard-focused field; Return creates an Inbox card and keeps focus.
- **Inbox card list:** notification-style cards; swipe right = Done, swipe left = Later, tap = Detail, long-press = Organize.
- **Today list:** items with `status == today` or scheduled for today; complete via swipe/checkbox.
- **Detail organizer sheet:** type, date, time, reminder toggle, priority, tags, pin, destination.
- **Done / Archive:** segmented list with restore.
- **UserNotifications:** request permission on first reminder use; schedule item reminders.
- **Test notification button** (in Settings) to fire a sample local notification.
- **Simple NL date parser** for: "today", "tomorrow", "this week", "morning", "night" → returns a candidate `Date` / time-of-day, surfaced as an AI suggestion chip.
- **No backend, no login, no sync.**

PoC acceptance: a user can launch → type a line → see it in Inbox → swipe to Done → organize one item with a reminder → receive that reminder.

---

## 17. UX copy

- **Empty Inbox:** "Inbox zero. Nothing waiting — capture a thought whenever one shows up."
- **Quick capture placeholder:** "What's on your mind? Just type it."
- **Save confirmation (toast):** "Saved ✓ — keep going."
- **Inbox cleanup reminder (notification):** "You've got 12 thoughts in your Inbox. A quick sort takes a minute."
- **Today screen empty state:** "Nothing set for today. That's fine — capture freely, sort later."
- **Archive empty state:** "Nothing archived yet. Filed items will rest here."
- **Notification permission explanation:** "Allow notifications so SwipeNote can remind you about a task or nudge you to tidy your Inbox. You're always in control — turn this off anytime."
- **AI suggestion label:** "Suggested — tap to apply" (e.g., "Suggested: Tomorrow 9:00 AM · tap to apply").

Tone rule: calm, never punitive. No red "OVERDUE", no "You failed to complete." Backlog is treated as normal.

---

## 18. Success metrics

| Metric | Definition | Target direction |
| --- | --- | --- |
| **Time to capture** | App-foreground → item saved (ms) | Minimize (< 2s) |
| **Captures per day** | Mean `CaptureItem`s created/active user/day | Increase |
| **Inbox cleanup rate** | % of inbox items moved to any non-inbox status within 7 days | Increase |
| **Completion rate** | % of `todo` items reaching `done` | Increase |
| **Return rate** | D1 / D7 / D30 active-user retention | Increase |
| **Notification open rate** | % of cleanup/reminder notifications opened | Increase |
| **Organized-later %** | % of items that get any field set after capture | Increase (validates the model) |
| **Taps per capture** | Interactions from trigger to saved | Minimize (target ≤ 2) |

Primary north-star: **Captures per day × Inbox cleanup rate** — proving people both dump freely *and* come back to sort.

---

## 19. Future expansion (post-MVP, clearly separated)

- **iCloud sync** (SwiftData + CloudKit) and multi-device.
- **AI daily planning** ("here's a suggested Today list").
- **Smart grouping** of similar items (cluster "TokenForge" / "LoroTopik" threads).
- **Calendar integration** (read/write EventKit).
- **Voice capture** (dictation-first quick capture).
- **Apple Watch app** (wrist capture).
- **Mac menu-bar app** (global hotkey capture).
- **Natural-language recurring reminders** ("every Monday morning").
- **Focus mode integration** (surface relevant items per Focus).
- **Lightweight project grouping** (soft groupings, not full PM).

None of these block MVP; each is additive on top of the single-entity, local-first core.

---

## 20. Codex Implementation Summary

> Use this as the seed for a SwiftUI coding prompt.

**App goal:** Build *SwipeNote*, a capture-first iOS app. The user writes one line in under two seconds; it lands in an Inbox as an unorganized card. Organizing (type, date, time, reminder, priority, tags, status) happens later in a separate flow. Optimize relentlessly for speed of capture.

**MVP screens (SwiftUI):**
1. Quick Capture — single keyboard-focused text field; Return saves to Inbox and keeps capturing.
2. Inbox — notification-style cards; swipe right = Done, swipe left = Later, tap = Detail, long-press = Organize.
3. Today — curated/scheduled-for-today items with complete action.
4. Detail / Organize (sheet) — optional type/date/time/reminder/priority/tags/pin + destination.
5. Done / Archive — segmented, with restore.
6. Settings — notifications, AI toggle, test notification, sample-data reset.

**Data model (SwiftData, single entity `CaptureItem`):**
`id: UUID, rawText: String, type: {undecided,todo,memo}, status: {inbox,today,later,scheduled,done,archived}, createdAt, updatedAt, dueDate?, reminderDate?, priority?: {none,normal,high}, tags: [String], isPinned: Bool, aiSuggestedDate?, aiSuggestedType?, completedAt?, archivedAt?`. String-backed enums; local-only store; seed sample data on first run.

**Core flows:**
- *Capture:* open → keyboard focused → type → Return → card in Inbox (`status=inbox`, `type=undecided`) → field clears, focus retained. No modal, no metadata prompts.
- *Organize:* Inbox → tap card → set any optional fields → choose destination status → save.
- *Reminder:* setting `reminderDate` schedules a local notification.
- *NL date detection:* parse "today/tomorrow/this week/morning/night" → suggestion chip (never auto-applied).

**iOS APIs:** SwiftUI, SwiftData, UserNotifications, AppIntents (Action Button + Siri Shortcut capture), WidgetKit (Home + Lock Screen capture-launch widgets; iOS 18 Control Center control), Share Extension (App Group store), Core Spotlight (fast-follow). iCloud/CloudKit deferred.

**Excluded (MVP):** teams, project management, calendar two-way sync, Gantt, AI chatbot, social, accounts, server/multi-device sync, complex recurrence, Notion-style databases.

**Key UX rule (non-negotiable):** **Capture must NEVER require selecting date, time, type, priority, or category.** The only required input is one line of text. Everything else is optional and happens later.
