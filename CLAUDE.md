## Collaboration rules

Before adding or modifying any segment of code, explain in plain language what that segment does and why it is being added. Each distinct segment (a function, a method, a meaningful block, a new file's purpose) gets its own short explanation before the code is written. Do not batch multiple segments under one vague explanation, and do not write code first and explain after.

## Product goal

Build a directly distributed macOS menu-bar utility that observes repeated mouse, trackpad, menu, and navigation behaviors, then teaches the relevant keyboard shortcut through a lightweight nonblocking overlay.

The app should behave like a passive desktop coach, not a training game.

The attached behavior list is the product backlog and should be treated as action-based, not shortcut-based: detect what the user is doing, then coach the keyboard path for that action. 
## Target platform and distribution

### Platform

macOS native app.

### Distribution

Direct distribution only.

Use:

- Developer ID signing
- Notarization
- Direct download
- Optional auto-update framework
- No Mac App Store requirement

Reason: the full product needs Accessibility and Input Monitoring permissions for cross-app observation. This is a poor fit for Mac App Store sandboxing.

### App form factor

Menu-bar utility app.

Implementation shape:

```text
LSUIElement menu-bar app
├── Status item / menu
├── Permission onboarding
├── Background observers
├── Local behavior store
├── Coaching rules engine
└── Floating overlay panel
```

Use Swift + AppKit. SwiftUI is acceptable for onboarding/settings, but the overlay and menu-bar behavior should be AppKit-first.

## Core macOS capabilities

### Required permissions

#### 1. Accessibility

Used for:

- Reading menu structure
- Detecting selected menu commands
- Reading UI element roles/titles when reliable
- Observing focused app/window changes
- Detecting standard controls where exposed
#### 2. Input Monitoring

Used for:

- Passive keyboard/mouse observation
- Detecting mouse-heavy workflows
- Detecting adoption of shortcuts
- Distinguishing mouse invocation from keyboard invocation

### Avoid in MVP: Screen Recording

Do not request Screen Recording in v1.

Avoid:

- OCR
- Pixel inspection
- Screenshot analysis
- Window image capture

This keeps permission friction lower and avoids making the app feel invasive.

## High-level architecture

```text
Event Sources
├── CGEventTap
│   ├── mouse down
│   ├── scroll
│   ├── key down
│   └── modifier changes
├── AXObserver
│   ├── menu opened
│   ├── menu item selected
│   ├── focused UI element changed
│   └── app/window changes
└── NSWorkspace
    ├── frontmost app
    └── app activation

Processing
├── EventNormalizer
├── ActionDetectors
├── ShortcutResolver
├── SuppressionEngine
├── LearningTracker
└── OverlayPresenter

Storage
├── local semantic event store
├── learned shortcut state
├── suppression state
└── app-specific rule config
```

Persist only semantic action data, not raw keystrokes or screen content.

Example stored record:

```json
{
  "bundleID": "com.apple.finder",
  "action": "file.rename",
  "suggestedShortcut": "Return",
  "mouseCount": 6,
  "keyboardSuccessCount": 1,
  "lastShownAt": "2026-05-20T10:00:00Z",
  "state": "active"
}
```

## Detector taxonomy

Implement detectors as independent modules.

```text
ActionDetectors
├── MenuCommandDetector
├── ContextMenuDetector
├── WindowControlDetector
├── BrowserChromeDetector
├── DockAndAppSwitchDetector
├── DialogNavigationDetector
├── FinderDetector
├── TextEditingDetector
├── AppSpecificDetector
├── SystemControlDetector
└── KeyboardShortcutDetector
```

### Detector responsibilities

|Detector|Purpose|
|---|---|
|`MenuCommandDetector`|Detect menu-selected commands and map them to menu-exposed shortcuts.|
|`ContextMenuDetector`|Detect right-click/context-menu actions where AX exposes command semantics.|
|`WindowControlDetector`|Detect close/minimize/window switching behavior.|
|`BrowserChromeDetector`|Detect address bar, new tab, tab close, reload, back/forward, tab switching.|
|`DockAndAppSwitchDetector`|Detect Dock-based app switching and coach `⌘Tab`.|
|`DialogNavigationDetector`|Detect repeated dialog button clicking and coach `Tab`, `Return`, `Esc`, `Space`.|
|`FinderDetector`|Detect file operations, rename, trash, views, navigation, search.|
|`TextEditingDetector`|Detect text selection, deletion, cursor movement, formatting. Use restraint.|
|`AppSpecificDetector`|Mail, Calendar, Notes, Preview, Slack, Teams, Discord adapters.|
|`SystemControlDetector`|Spotlight, Force Quit, Lock Screen, Character Viewer, screenshot tools.|
|`KeyboardShortcutDetector`|Detect successful shortcut adoption and retire hints.|

## Coaching behavior

### Default hint style

Small overlay near the cursor or relevant UI area.

Examples:

```text
Copy faster with ⌘C
```

```text
Same action, fewer clicks: ⌘L
```

```text
You often switch apps from the Dock. Try ⌘Tab.
```

### Overlay requirements

Use nonactivating AppKit panel:

```text
NSPanel / borderless NSWindow
├── nonactivating
├── click-through
├── does not steal focus
├── appears briefly
├── dismissible from menu/status item
└── suppressed in sensitive contexts
```

Default duration: 2–4 seconds.

Do not show:

- During screen sharing
- During presentations
- In games
- In remote desktop sessions
- In password fields
- In banking/medical/private apps
- For one-off actions
- For ambiguous actions
- Where mouse use may be optimal

## Suppression and learning rules

The suppression engine is as important as detection.

### Suggested defaults

```text
Show after:
- 1-2 repeated mouse/menu uses of same action, or
- 2 uses in short succession for very high-confidence actions

Cooldown:
- tbd

Retire hint after:
- User performs shortcut successfully 3 times

Re-activate hint after:
- A .learned hint sees mouse use again without recent keyboard use
  (e.g. no keyboard invocation in the last 30 days). Flip back to
  .active and resume coaching. Catches the user who learned a
  shortcut, then drifted back to the mouse over time.

Snooze:
- 1 hour
- Today
- This week
- Never for this shortcut
- Never for this app
```

## Priority scoring

Each candidate hint should receive a score:

```text
score =
  actionFrequency
+ confidence
+ shortcutValue
- recentHintPenalty
- ambiguityPenalty
- sensitiveContextPenalty
```

Only show if score exceeds threshold.

## Behavior coverage plan

### v1 shipped list

Ship these first:

```text
1. Copy → ⌘C
2. Paste → ⌘V
3. Cut → ⌘X
4. Undo → ⌘Z
5. Redo → ⌘⇧Z
6. Select All → ⌘A
7. Save → ⌘S
8. Find → ⌘F
9. Close Window/Tab → ⌘W
10. New Window/Document → ⌘N
11. New Browser Tab → ⌘T
12. Browser Address Bar → ⌘L
13. Browser Back → ⌘[
14. Browser Forward → ⌘]
15. Switch Apps via Dock → ⌘Tab
```

These are common, understandable, high-confidence, and broad enough to make the product feel systemwide.

### Full product coverage

Eventually support:

```text
Priority 1: Universal commands
Priority 2: App/window navigation
Priority 3: Browser behaviors
Priority 4: Text editing and cursor movement
Priority 5: Finder/file management
Priority 6: Screenshots/screen actions
Priority 7: App-specific adapters
Priority 8: Accessibility/system controls
Priority 9: Power-user shortcuts, opt-in only
```

Power-user shortcuts should never be default for family/non-technical users.

## Development stages

### Stage 0 — Technical spike

Goal: prove feasibility.

Deliverables:

- Menu-bar app shell
- Permission prompts for Accessibility and Input Monitoring
- `CGEventTap` listen-only event stream
- `AXObserver` attached to frontmost app
- Basic overlay panel
- Local debug log of semantic actions

Exit criteria:

- App detects `Edit → Copy`
- App extracts or resolves `⌘C`
- App displays nonblocking overlay
- App detects later `⌘C` adoption

### Stage 1 — Menu command coach

Goal: reliable universal menu coaching.

Implement:

- `MenuCommandDetector`
- `ContextMenuDetector`
- `ShortcutResolver`
- menu path extraction
- shortcut formatting
- app/bundle tracking
- local action store
- suppression rules v1
  - Suppress menu-driven hints when the same shortcut was just pressed via keyboard within a short window (~150 ms). The AX `MenuItemSelected` notification fires on shortcut invocation as well as on mouse selection, so the invocation source must be attributed by correlating with the event tap before showing a hint.
  - Re-activate retired hints when a `.learned` record sees mouse use without recent keyboard use (regression). Implemented alongside retirement on the per-(app, shortcut) record.

Support:

```text
Copy, Paste, Cut, Undo, Redo, Select All, Save, Find,
New, Open, Print, Preferences, Quit, Hide, Minimize
```

Exit criteria:

- Works in Finder, Safari, Chrome, Mail, Notes, TextEdit, Preview
- No hints for one-off actions
- No typed text stored
- Hints retire after shortcut adoption

### Stage 2 — Overlay and product shell

Goal: make it feel like a polished utility.

Implement:

- menu-bar status item
- onboarding
- permission health screen
- snooze controls
- per-app enable/disable
- hint history
- “learned shortcuts” view
- launch at login
- crash-safe event tap restart

Menu-bar menu:

```text
Shortcut Coach: On
├── Snooze for 1 hour
├── Snooze for today
├── Learned shortcuts
├── Settings
├── Permissions
└── Quit
```

Exit criteria:

- App can be used daily without opening a main window
- User can stop or reduce coaching instantly
- Overlay never steals focus or blocks clicks

### Stage 3 — Standard UI mouse actions

Goal: coach non-menu mouse behavior.

Implement:

- `WindowControlDetector`
- `DockAndAppSwitchDetector`
- `DialogNavigationDetector`

Support:

```text
red close button → ⌘W
Dock app switching → ⌘Tab
same-app window switching → ⌘`
Cancel button → Esc
default confirmation button → Return
dialog focus movement → Tab / Space
Mission Control usage → ⌃↑
App Exposé usage → ⌃↓
```

Exit criteria:

- App detects common system navigation behavior
- Hints are shown only after repetition
- Dialog hints are suppressed in sensitive contexts

### Stage 4 — Browser detector

Goal: make the product feel highly useful for everyday users.

Implement browser adapters for:

- Safari
- Chrome
- Edge
- Firefox, if feasible

Support:

```text
address bar click → ⌘L
new tab button → ⌘T
tab close button → ⌘W
reload button → ⌘R
back button → ⌘[
forward button → ⌘]
find in page → ⌘F
tab switching → ⌘⇧] / ⌘⇧[
numbered tab access → ⌘1…⌘9
zoom controls → ⌘+ / ⌘- / ⌘0
open link in new tab context menu → ⌘Click
```

Exit criteria:

- Browser hints are accurate enough to avoid false positives
- Browser-specific differences are handled by adapter config
- No arbitrary web-app button coaching in default mode

### Stage 5 — Finder and file management

Goal: cover the most common file workflows.

Implement `FinderDetector`.

Support:

```text
New Finder Window → ⌘N
New Folder → ⌘⇧N
Open selected file → ⌘O / Return, depending action
Rename file → Return
Move to Trash → ⌘Delete
Empty Trash → ⌘⇧Delete
Get Info → ⌘I
Duplicate → ⌘D
Finder views → ⌘1 / ⌘2 / ⌘3 / ⌘4
Finder search → ⌘F
Back/forward → ⌘[ / ⌘]
Enclosing folder → ⌘↑
Desktop/Documents/Downloads → Finder Go shortcuts
```

Exit criteria:

- Finder hints are reliable and conservative
- Rename/open distinction is handled carefully
- No coaching for ambiguous drag-and-drop workflows

### Stage 6 — Text editing detector

Goal: high-value coaching with strict restraint.

Implement `TextEditingDetector`.

Support only after repeated behavior:

```text
drag word selection → double-click
drag paragraph selection → triple-click
cursor to line start → ⌘←
cursor to line end → ⌘→
cursor by word → ⌥← / ⌥→
delete word → ⌥Delete
paste and match style → ⌘⌥⇧V where exposed
emoji picker → ⌃⌘Space
bold → ⌘B
italic → ⌘I
underline → ⌘U
```

Exit criteria:

- Text editing hints are rare
- No hints in password fields
- No hints while user is actively typing quickly
- No raw text is logged

### Stage 7 — App-specific adapters

Goal: support high-value native and communication apps.

Adapters:

```text
Mail
Calendar
Notes
Preview
Slack
Teams
Discord
```

Use adapter configs, not hardcoded global assumptions.

Example config:

```json
{
  "bundleID": "com.apple.mail",
  "actions": {
    "compose": "⌘N",
    "send": "⌘⇧D",
    "reply": "⌘R",
    "replyAll": "⌘⇧R",
    "forward": "⌘⇧F"
  }
}
```

Exit criteria:

- Each adapter has explicit confidence rules
- Unreliable actions are disabled by default
- App-specific hints can be independently disabled

### Stage 8 — System controls and opt-in power features

Goal: later-stage expansion.

Support:

```text
Spotlight → ⌘Space
Force Quit → ⌘⌥Esc
Lock Screen → ⌃⌘Q
Character Viewer → ⌃⌘Space
Screenshot app → ⌘⇧5
Full screenshot → ⌘⇧3
Selection screenshot → ⌘⇧4
```

Power-user opt-in:

```text
window management
terminal-specific shortcuts
custom shortcuts
multi-step workflow suggestions
automation suggestions
```

Do not enable these by default.

## Non-goals for MVP

Do not build in MVP:

```text
Screen recording
OCR
Cloud sync
AI interpretation of arbitrary screen contents
Web-app button coaching
Complex drag-and-drop inference
Gaming support
Video-editing timeline coaching
Remote desktop coaching
Banking/medical/private app coaching
Synthetic keyboard event posting
Shortcut automation
```

## Privacy requirements

Hard rules:

```text
Do not store typed text.
Do not store screenshots.
Do not store full click paths.
Do not upload behavior data by default.
Do not infer sensitive content.
Do not coach in password fields.
Do not coach in excluded apps.
```

Store:

```text
bundleID
semantic action ID
shortcut suggestion
timestamps
counts
hint exposure state
learned/snoozed state
```

Optional sync can come later, but only for learned/suppression state, not raw event history.

## Engineering milestones

### Milestone 1: Feasibility prototype

Deliver:

- menu-bar app
- permission onboarding
- event tap
- AX menu detection
- basic overlay
- 5 shortcuts

### Milestone 2: v1 alpha

Deliver:

- 15 shipped behaviors
- suppression engine
- learned shortcut retirement
- local store
- settings
- app exclusions
- Dock/app-switch detection
- browser basics

### Milestone 3: private beta

Deliver:

- Finder detector
- better browser adapters
- dialog navigation
- overlay polish
- onboarding polish
- diagnostics
- signed/notarized builds
- feedback capture

### Milestone 4: public direct release

Deliver:

- notarized installer or `.dmg`
- update mechanism
- privacy policy
- permission documentation
- crash reporting, if desired
- conservative default rules
- no Screen Recording requirement

## Core implementation principle

Favor reliable silence over noisy intelligence.

The app should show a hint only when all are true:

```text
The action is understood.
The shortcut is reliable.
The user repeated the mouse/menu behavior.
The context is not sensitive.
The hint has not been over-shown.
The user has not already learned it.
```

That is the product. Everything else is expansion.