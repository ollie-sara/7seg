# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Primary: deep sleepers who dismiss alarms half-asleep and wake up late as a result. They need an alarm they cannot turn off without being awake. General users who just want a reliable alarm are served too, but design decisions favor the deep sleeper.

The user is half-asleep, in a dark bedroom, often without glasses, at the moment that matters most (ringing). Setup happens awake, usually in the evening.

## Product Purpose

7seg is a small open-source iOS alarm app. It solves two problems: alarms must ring reliably (AlarmKit, iOS 26+), and the user must not be able to dismiss an alarm while half-asleep. Snooze and Stop exist only inside the app; any outside dismissal re-fires the alarm after ~2 s. Success means the user is out of bed at the set time.

## Positioning

The alarm cannot be dismissed from the lock screen, side button, volume buttons, or by swiping the app closed. Phase Two adds tasks (math, type text, odd tile out, QR scan, shake, walk) that must be completed before Stop unlocks.

## Operating Context

- Alarms are set in the evening, awake, often in bed.
- Ringing happens in a dark room, user half-asleep.
- Phone is usually plugged in overnight. Lock-Screen volume can only be a share of the ringer volume (no API).
- Nightstand mode: when the phone is landscape, charging, and an alarm is enabled, the app shows a time-only clock face, like a bedside alarm clock. The app may keep the screen awake, drop brightness to minimum, and restore it on exit.

## Capabilities and Constraints

Phase One (implemented): alarm list (add, edit, delete, toggle, sorted by time), editor (time, label, repeat weekdays, empty = one-shot, sound from bundled or imported files with preview, snooze duration 1–30 min, max snoozes 0–10 or unlimited, max volume and fade-in from 15 s to 5 min, baked into the sound AlarmKit plays), in-app ringing screen with Snooze and Stop, nag loop, AlarmKit authorization banner when denied.

Phase Two (planned): per-alarm ordered task list; silent while working on tasks with inactivity timeout (default 20 s); fallback alarm; Skip button after 3 failed attempts, held 5 s.

Planned: nightstand mode (see Operating Context).

Constraints: iOS 26+, SwiftUI, no third-party dependencies. 12/24-hour format follows system locale. Weekdays follow locale order. The user supplies the real sound files.

Localization: English now, more languages later. Layouts must survive longer strings (German, Croatian) and other weekday abbreviations.

## Brand Commitments

- Name: 7seg (renamed from OpenAlarm, which was unsearchable). Code identifiers use `SevenSeg`, since Swift names can't start with a digit. Open source under the MIT License.
- The user pinned the visual reference: an old-school 7-segment alarm clock without a backlight (unlit LCD), modern with a touch of retro. Dark and light mode both required.
- No visuals without a specific purpose.

## Evidence on Hand

- No logo, icon, or brand assets exist yet.
- `SevenSeg/Sounds/Beep.caf` is a placeholder; real sounds come from the user.
- No users, testimonials, or metrics exist. Do not invent them.

## Product Principles

1. Readable half-asleep: the ringing screen and the clock face must be legible at a glance, in the dark, without glasses.
2. No quiet window: nothing in the design gives the user an easy way back to sleep.
3. Every element earns its place. No decoration without a function.
4. Native first: iOS conventions for navigation and controls; identity lives in type, color, and the clock face.
5. Build to App Store quality from the start.

## Accessibility & Inclusion

- Dynamic Type, VoiceOver labels, and sufficient contrast in both appearances.
- Ringing controls must be large and unambiguous for a half-asleep user.
- Honor Reduce Motion.
