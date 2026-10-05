# OpenAlarm

## Problem

1. **Reliability.** People depend on their alarm, so it has to ring at the set time every time. Users report that the built-in Clock app sometimes doesn't.
2. **Sleep dismissal.** Some users learn the motions for turning off an alarm so well that they do it without waking up. The result is the same as an alarm that never rang.

Honest framing: a third-party app can't be more reliable than the OS scheduler it sits on. What we can do is (a) use the system alarm path (AlarmKit), not ordinary notifications, and (b) make dismissal require being awake. Problem 2 is where OpenAlarm actually adds value.

## Proposed Solution

A small, open-source iOS app for alarms at set times on chosen weekdays. You can't dismiss an alarm from the lock screen; you have to open the app, and later also complete tasks.

### Key platform facts (these drive the design)

- **AlarmKit** (iOS 26+) is the public API for real alarms: they break through Silent and Focus, show full-screen on the lock screen, and appear in the Dynamic Island. Before iOS 26 the only option was local notifications, which cut out after 30 s and are silenced by Focus. That makes AlarmKit a requirement, and **the minimum iOS version is 26**.
- An AlarmKit alert shows system buttons: a **Stop** button and an optional secondary button. The secondary button can either start a countdown (snooze) or run an App Intent that **opens the app**.
- AlarmKit plays at the system **ringer** volume, and there is no API to override it. Apps also cannot use Apple's built-in ringtones.
- Custom sounds for AlarmKit must be a file in the app bundle or in the app's `Library/Sounds` folder. Imported sounds get copied there.
- Verified on device (spike app, see `spike/README.md`):
  - Sliding Stop can open the app (`stopIntent` with `openAppWhenRun`), even after the app was swiped closed.
  - The system Stop slider, the side button, the volume buttons and swiping the app closed all run our `stopIntent`, and the app can schedule a new alarm from there. The nag loop works.
  - Found in Phase One testing: with `openAppWhenRun`, a side or volume button press on a locked phone shows the passcode pad, and the intent only runs after unlocking. If the user doesn't unlock, there is no nag. The `stopIntent` therefore starts in the background (`supportedModes: [.background, .foreground(.dynamic)]`), schedules the nag, then calls `continueInForeground` to open the app. *(Needs device verification.)*
  - The app can stop a ringing AlarmKit alarm from inside the app; the sound and the lock-screen alert both go away.
  - An AlarmKit alarm that fires while the app is in the foreground shows only a small banner, not the full-screen alert.
  - AlarmKit plays `.caf`, `.wav`, `.m4a` and imported `.mp3` files, with no conversion. Short sounds loop; a 45 s sound is not cut off at 30 s.
  - Loud mode: with ringer volume near zero and Silent on, the app raised the system volume from 0.0 to 1.0 and rang loudly from the background.

### Phase One: MVP

**Alarm list**
- Add, edit and delete alarms. Swipe to delete, tap to edit.
- Toggle each alarm on or off. Off means the alarm is unscheduled in AlarmKit, not just hidden.
- Sorted by time. Each row shows the time, label and repeat days.

**Alarm settings**
- Time (hour and minute).
- Label (optional, default "Alarm"). It is shown on the lock-screen alert.
- Repeat weekdays. **No days selected = one-shot:** it fires at the next occurrence of that time and then switches itself off.
- Sound: pick from a set of bundled, freely licensed sounds, or import your own (Files picker, copied into `Library/Sounds` as-is; `.caf`, `.wav`, `.m4a` and `.mp3` all work). Preview plays on tap. Swipe an imported sound to delete it; alarms that used it fall back to the default sound.
- Volume ("Loud mode"): see below.
- Snooze duration: default 5 min, choices 1–30 min.
- Max snoozes: default 3, choices 0–10 or unlimited. Once the limit is reached, the in-app Snooze button is hidden and only Stop remains.

**Ringing behaviour (the core)**
- The alarm fires through AlarmKit at the set time.
- No button on the lock screen or on the device snoozes or dismisses the alarm. Snooze and Stop exist **only inside the app**.
- **Sliding the system Stop button opens the app** straight to the ringing alarm's screen, the way the competitor app does it. The alarm is not actually dismissed. *(Verified in spike 5, also when the app was swiped closed. The alert has no separate "Open" button.)*
- **Nag loop (verified):** if the alert is dismissed any other way (side button, swiping the app closed), the app schedules the alarm again ~2 s later. This repeats until the user stops the alarm inside the app.
- The in-app ringing screen has two large buttons: **Snooze** and **Stop**.
  - Snooze: silences the alarm and re-fires it after the snooze duration, with the same in-app-only rules.
  - Stop: ends this occurrence. A one-shot alarm switches off; a repeating alarm stays scheduled for its next day.

**Loud mode (custom volume)**

AlarmKit can't set volume, so custom volume needs a second mechanism. Competitor apps do this with background audio, and they have the same limit: it only works while the app is running.

- AlarmKit stays the backbone. Every enabled alarm is always scheduled in AlarmKit.
- Loud mode is per alarm, with a volume slider. When at least one Loud-mode alarm is enabled, the app keeps an `AVAudioSession` (`.playback`) alive in the background by playing silence.
- At alarm time the app plays the sound itself at the configured volume.
- **Fade-in** (per-alarm toggle, on by default in Loud mode): the volume ramps from low to the configured level over 15 s, in steps. To go above the current media volume, it sets the system volume through a hidden `MPVolumeView` slider. This is unofficial but widely used.
- A few seconds before alarm time, the app pushes the AlarmKit alarm back by ~1 min. The AlarmKit alarm then acts as a fallback if the app's own playback fails.
- Dismissing the lock-screen alert (side button etc.) doesn't stop the app's own audio. It keeps ringing, and the app posts a local notification as a quick way back into the app. This needs notification permission, which is asked for when Loud mode is first switched on.
- **Assumption:** the phone is plugged in overnight and the app stays open in the background. Loud mode is not designed for a phone on battery with Low Power Mode.
- If the user swipe-kills the app, the background audio stops, and the alarm falls back to AlarmKit at ringer volume (verified). The app shows a clear warning about this in the Loud mode setting.
- Downsides: battery drain from the silent keepalive, and App Review risk (guideline 2.5.4 allows background audio only for audible content). Alarm apps with this feature are on the App Store, but this is the part most likely to be rejected.

**Nightstand mode (planned)**
- When the app is open, the phone is landscape and charging, and at least one alarm is enabled, the app shows a clock face like an old bedside alarm clock.
- Content: the current time and a small "AL" legend with the next alarm time. Nothing else.
- OLED power saving: pure black background, dim red digits, no ghost segments, steady colon. The app keeps the screen awake, drops brightness to minimum, and restores it on exit.
- The clock shifts a few points each minute to prevent burn-in.
- Exits when the phone is rotated to portrait or unplugged, or on tap. A ringing alarm takes over the screen.
- Keeping the app in the foreground also makes Loud mode more reliable.

**Settings**
- Opened from a gear at the top left of the alarm list, as a sheet.
- Appearance: System (default), Light or Dark. The choice applies to the whole app, including the ringing screen, and is kept across launches. The nightstand face stays black and red whatever the choice.
- About: the app version. Links to the author and a donation page come later, once the URLs exist.

**Permissions and first run**
- Ask for AlarmKit authorization on first launch. If it's denied, show a permanent banner explaining that alarms won't ring, with a link to Settings.

### Phase Two: Deep-sleeper tasks

- Each alarm can have an ordered **list of tasks**. When the list isn't empty, the in-app Snooze and Stop buttons stay locked until every task is done.
- **While the user is working on tasks, the alarm is silent.** The app stops the AlarmKit alarm when it opens (verified). When a task times out, the app plays the sound itself, because a foreground AlarmKit alarm is only a small banner.
- **Inactivity timeout** (default 20 s, configurable per alarm): if the user doesn't interact for that long, the current task is forfeit, the alarm rings again, and the user **restarts that task**. Completed tasks stay completed.
- **Backgrounding safety net:** when tasks start, schedule a fallback AlarmKit alarm for about 1 minute later, and push it back while the user is active. If the user locks the phone or the app is killed, the fallback alarm rings.
- Snoozing does **not** require the tasks. Only Stop does. The snooze limit (Phase One) prevents endless snoozing.
- **Escape hatch:** after 3 failed attempts at a task (wrong answers, forfeits, or unrecognised QR scans), a **Skip** button appears. It must be held for 5 s to skip that task. This covers a lost QR code, travel, or no room to walk.
- Task types and their options:

| Task | Options | Implementation |
|---|---|---|
| Math | operations (+, ×, ÷), difficulty (digit count), number of problems | Plain SwiftUI |
| Type text | number of words | Plain SwiftUI, bundled word list |
| Odd tile out | grid size / colour difference (difficulty), rounds | Plain SwiftUI |
| Scan QR code | which registered code | VisionKit `DataScannerViewController` |
| Shake | duration in seconds | CoreMotion accelerometer |
| Walk | number of steps | CoreMotion `CMPedometer` |

- **QR setup:** the app generates a unique code (`openalarm://<uuid>`) and saves it. The user prints or screenshots it and puts it somewhere away from the bed. Only a registered code completes the task, so any random QR code won't work.
- **Chaining:** a task list has no fixed length limit. The UI uses a plain reorderable list.
- Walk and Shake require the Motion & Fitness permission. Ask for it only when one of those tasks is added.

### Out of scope (for now)

- **"Intervals"** (from the original draft): cut. Weekdays plus one-shot cover the real use cases. Add it back later if a concrete need comes up, e.g. "every 2 days".
- Apple Music / streaming tracks as alarm sounds (DRM, no file access).
- Fade-in outside Loud mode (AlarmKit has no volume control), sleep tracking, bedtime reminders, widgets, Apple Watch, iCloud sync, Android.
- Holiday/skip-next-occurrence. Nice to have, and cheap to add after the MVP.

## Tech Stack

- **Language/UI:** Swift, SwiftUI.
- **Min target:** iOS 26 (because of AlarmKit).
- **Alarms:** AlarmKit (`AlarmManager`), with App Intents for the "Open" button and the stop handler.
- **Persistence:** alarm settings (label, sound, snooze, tasks) stored as a Codable array in one JSON file in the app's documents directory. AlarmKit keeps the schedule; our JSON keeps everything else, linked by the alarm's UUID. Switch to SwiftData only if the model grows relations or queries.
- **Audio:** bundled and imported sound files in `Library/Sounds`, used by the AlarmKit alert. The app plays sounds itself with `AVAudioPlayer` for Loud mode and for task timeouts. `MPVolumeView` sets the system volume in Loud mode.
- **Phase two frameworks:** VisionKit (QR scanning), CoreImage `CIQRCodeGenerator` (QR generation), CoreMotion (shake, steps).
- **Dependencies:** none.
- **Tests:** unit tests for the pure logic only: next-fire-date calculation, one-shot auto-disable, math problem generation. The alarm behaviour itself is tested by hand on a device.
- **License:** MIT (proposed).
- **Distribution:** source on GitHub. Personal use via TestFlight first, App Store release later, so build to App Store quality from the start (onboarding, permission texts, accessibility). A free Apple ID can sideload, but the app expires after 7 days, which is unacceptable for an alarm. Real use needs a paid developer account.

## Spikes (verify on a real device before building on them)

Setup and raw results: `spike/README.md`.

1. **Stop-button nag loop:** ✅ Works for the Stop slider, the side button and swiping the app closed. The volume buttons also stop the alarm, and the nag re-fires after that too.
2. **Loud mode:** ✅ Short test: 0.0 → 1.0 system volume, loud while locked and on Silent. Overnight test skipped by decision: Loud mode assumes the phone is plugged in and the app stays open in the background. Swipe-close fallback: the AlarmKit backup rings.
3. **Silence during tasks:** ✅ The app can stop the AlarmKit alarm. A foreground re-fire is only a banner, so the app plays timeout sounds itself.
4. **Sounds:** ✅ All formats play, no 30 s cut-off. Short sounds loop.
5. **Stop opens app:** ✅ Sliding Stop runs a `stopIntent` with `openAppWhenRun` and opens the app, also after the app was swiped closed.

## Open Questions

Resolved:
- *How do we make the alarm take precedence?* → AlarmKit, iOS 26+.
- *Notification to open the app?* → Sliding the system Stop button opens the app (verified). In Loud mode, a local notification is also posted as a quick-link.
- *One-shot behaviour?* → Fires at the next occurrence of that time, then switches itself off.
- *Task forfeit?* → The alarm rings again and the current task restarts; completed tasks stay completed.

- *Max volume?* → AlarmKit can't do it. Add opt-in Loud mode using background audio, with AlarmKit as the fallback (see Phase One). Validate with spike 2.
- *Snooze with tasks?* → Only Stop requires the tasks. Add a max-snoozes setting (default 3).
- *Emergency escape?* → After 3 failed attempts, show a Skip button that must be held for 5 s.
- *Distribution?* → Personal/TestFlight first, App Store later. Build to App Store quality.
- *Importable sounds?* → Yes, in Phase One.

- *Volume fade-in?* → Yes, in Loud mode: 15 s ramp, per-alarm toggle.

Still open:
- Nothing. All spikes are done; Phase One can start. None of them block starting Phase One.
