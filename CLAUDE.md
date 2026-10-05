# OpenAlarm

Small open-source iOS alarm app (Swift, SwiftUI, iOS 26+, no dependencies). It solves two problems: alarms must ring reliably, and the user must not be able to dismiss an alarm while half asleep. Snooze and Stop exist **only inside the app**. Any dismissal outside the app (lock-screen Stop slider, side or volume buttons, swiping the app closed) re-fires the alarm after ~2 s.

`docs/description.md` is the spec and source of truth for product decisions: phases, platform facts, spike results, out-of-scope list. Read it before changing behaviour. Keep it in sync when a decision changes.

## Status

- **Phase One (MVP): implemented** in `OpenAlarm/`. Alarm list, editor, sounds (bundled + imported), snooze limits, in-app ringing screen, nag loop, Loud mode.
- **Phase Two (deep-sleeper tasks): not started.** Math, type text, odd tile out, QR scan, shake, walk. See the spec for task rules (inactivity timeout, fallback alarm, Skip after 3 fails held 5 s).
- `OpenAlarm/Sounds/Beep.caf` is a synthesized placeholder. The user supplies the real freely licensed sounds. Do not source or generate sound files without asking.

## Layout

- `OpenAlarm/` – the app. Xcode uses file-system synchronized groups, so new files in this folder join the target automatically (no pbxproj edit). `Info.plist` is excluded from membership; other plist keys are generated via `INFOPLIST_KEY_*` build settings.
  - `OpenAlarmApp.swift` – entry point. Injects `AlarmStore.shared`, hosts the hidden `VolumeHack`, shows `RingingView` as a full-screen cover while `store.ringing != nil`, forwards scene phase changes.
  - `AlarmItem.swift` – `AlarmItem` (one alarm's settings; `nextFire`, `finishOccurrence`, `transientID`, `daysSummary`) and `Session` (the alarm currently ringing or snoozed, with snooze count).
  - `AlarmStore.swift` – `@MainActor @Observable` singleton. Owns alarms + session, persistence, all AlarmKit calls, ringing logic, Loud-mode loop. Also `StopIntent` (the AlarmKit `stopIntent`: runs in the background to schedule the nag, then `continueInForeground` to open the app).
  - `Audio.swift` – `Sounds` (bundled + `Library/Sounds` files, import) and `Audio` (in-app playback via `AVAudioPlayer`, silent keepalive, system volume via hidden `MPVolumeView`, 15 s fade-in). `VolumeHack` must stay in the view hierarchy.
  - `AlarmListView.swift`, `AlarmEditor.swift` (includes `SoundPicker`), `RingingView.swift` – UI.
  - `Segments.swift` – the visual identity: palette (`lcd`, `ink`, `ink2`, `nightRed`, defined in code, no asset catalog), 7-segment digit shapes (`SegmentText`, `SegmentClock`), `Legend` annunciators, and `Segments.clock`/`label` for 12/24-hour formatting.
  - `Controls.swift` – LCD replacements for stock iOS chrome: `LCDToggleStyle` (set on the root and again on the editor `Form`, because the sheet does not inherit it; it ignores `.labelsHidden()`, so pass an empty label plus `accessibilityLabel`), `LevelBar` (Loud volume), `TimeSetter` (editor time: looping segment-digit wheels, replaces the `DatePicker`), `InkButtonStyle` (toolbar Add/Save; pair with `.sharedBackgroundVisibility(.hidden)` to drop the glass).
  - `SettingsView.swift` – Settings sheet (gear, top-left of the list): appearance tiles (System / Light / Dark, stored in `@AppStorage("appearance")`, applied as the window's `overrideUserInterfaceStyle` from `OpenAlarmApp`) and About (version). Author and donation link rows go here once the user supplies the URLs.
  - `Nightstand.swift` – nightstand mode (`NightstandHost` modifier on the root) and `AppDelegate`, which allows landscape only while charging with an enabled alarm. The simulator always reports charging.
- `OpenAlarmTests/` – Swift Testing unit tests for pure logic only (`AlarmItem`, `Segments.clock`).
- `DESIGN.md` – the visual system (Unlit Glass: unlit LCD look, 7-segment digits). `PRODUCT.md` and `.impeccable/` hold the design context and the decision mockups.
- `spike/` – throwaway device-verification app (`OpenAlarmSpike.xcodeproj`) and `spike/README.md` with raw spike results. Not part of the real app; don't extend it.

## How it works

- **Persistence:** one JSON file, `Documents/alarms.json`, holding `alarms` and the current `session`. Written on every change (`persist()`). AlarmKit holds the schedule; the JSON holds everything else, linked by alarm UUID.
- **Two AlarmKit alarms per item at most:** the main one (`id`, relative schedule, weekly or `.never` for one-shot) and a transient one (`transientID`, fixed date) used for nag, snooze and the Loud-mode fallback. `transientID` is `id` with the last byte flipped, so it is derivable without storage.
- **`sync()`** makes AlarmKit match `alarms`: cancels orphans, then cancels and reschedules every alarm except the one in the active session. Called after every save/delete.
- **Ringing flow:**
  - AlarmKit fires. If the user slides Stop (or any other system dismissal), `StopIntent.perform` calls `externalStop`. It marks the session ringing and schedules the transient alarm 2 s later (60 s plus a local notification if Loud-mode audio is already playing).
  - When the app becomes active, `takeOver()` stops any alerting AlarmKit alarm and the app plays the sound itself. A foreground AlarmKit alarm is only a banner, so the app must ring itself.
  - Going to background while ringing: non-Loud alarms stop app audio and nag in 2 s; Loud alarms keep playing, notify, and set a 60 s fallback.
  - `snooze()` increments the count and schedules the transient alarm at the snooze end. `stop()` clears the session, cancels the transient alarm, and calls `finishOccurrence()` (one-shot switches off), then `save()`.
- **Loud mode:** while any enabled alarm is Loud, `Audio` plays silence in the background to keep the process alive (`UIBackgroundModes: audio`). `loudLoop()` wakes ~5 s before the next Loud event, cancels the main AlarmKit alarm, sets the transient alarm 60 s later as fallback, then plays the sound itself at the configured volume. Only one session exists at a time (marked with a `ponytail:` comment).

## Decisions to keep

- The alarm keeps ringing in-app until the user acts. There must be no quiet window to fall back asleep in.
- Phase Two: silent while the user works on tasks, with an inactivity timer (default 20 s). Every task action restarts the timer. On timeout, the alarm rings again and the current task restarts.
- Nag delay after external dismissal is ~2 s, not 30 s.
- Snooze never requires tasks; only Stop does. Max snoozes default 3.
- Persistence stays a Codable JSON file. Move to SwiftData only if the model gains relations or queries.
- No third-party dependencies.
- Build to App Store quality (permission texts, accessibility labels, onboarding), because the plan is TestFlight first, App Store later.

## Build and test

- Open `OpenAlarm.xcodeproj`, scheme `OpenAlarm`. Bundle ID `com.osaravanja.openalarm`, team `42LC9M65RJ`, deployment target iOS 26.0, Swift 5 language mode.
- Unit tests (11 tests, all pass as of 2026-10-04):
  ```sh
  xcodebuild test -project OpenAlarm.xcodeproj -scheme OpenAlarm -destination 'platform=iOS Simulator,name=iPhone 17'
  ```
  The first run against a cold simulator can fail with "Simulator device failed to launch com.osaravanja.openalarm". Run it again.
- Alarm behaviour (AlarmKit, lock screen, Loud mode, volume) cannot be tested in unit tests or reliably in the simulator. The user tests it by hand on a real device. Say so when a change needs device verification.
- Tests cover pure logic only: next-fire date, one-shot auto-disable, and later math problem generation. Don't add UI or AlarmKit test scaffolding.

## Code style

- Small files, terse SwiftUI, doc comments only where behaviour is non-obvious (match the existing density).
- Errors from AlarmKit and file IO are mostly `try?` or printed; there is no logging framework.
- Weekdays use `Calendar` numbering: 1 = Sunday … 7 = Saturday. Empty `days` = one-shot.

## iOS Simulator Testing

When I ask you to test a feature or verify a UI change:

1. **Build the app**: Run the build command and wait for success
2. **Launch in simulator**: Use `launch_app` with the bundle ID
3. **Navigate to the feature**: Use `ui_tap` and `ui_swipe` to get there (refer to sitemap.md available in the root directory)
4. **Verify the state**: Use the accessibility describe tools to read what’s on screen
5. **Take a screenshot**: Capture the result for confirmation
6. **Report back**: Tell me what you found

### When Something Looks Wrong
1. Read the accessibility tree
2. Compare expected vs actual element states
3. Take a screenshot for my review
4. Suggest a fix
