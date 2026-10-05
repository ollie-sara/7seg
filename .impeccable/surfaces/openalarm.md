---
version: 1
slug: "openalarm"
primary_target: "OpenAlarm"
related_targets: []
---

# OpenAlarm app surfaces

Scope: whole app (alarm list, editor sheet, sound picker, ringing screen, nightstand mode, Phase Two task screens). Mode: Operate.

Audience and job: deep sleepers setting alarms awake in the evening, and acting on them half-asleep in a dark room. Success: readable at a glance without glasses; Stop only by being awake.

Constraints: native iOS navigation and controls (NavigationStack, sheet, Form, Toggle, wheel DatePicker, swipe actions); Dynamic Type; VoiceOver; both appearances; strings must survive longer languages.

Mockups: `.impeccable/mocks/decision/proposals.html` (`?d=model-pick`), critique reference `.impeccable/mocks/decision/model-pick.png`.

## Direction contract

THESIS: The whole screen is one unlit reflective LCD. Every state is a printed segment, inked or ghosted; nothing appears the glass could not show. Refuses the Clock-app default of thin rounded digits on grouped cards.

OWN-WORLD: Light: grey-green LCD ground #C7CCB6, ink #1A1D15, secondary ink #474C3D, ghost segments at ~7.5% ink. Dark: negative LCD, ground #0D0F0C, ink #D0D6C3, secondary #8A917D, ghost ~6%. Upright 7-segment digits drawn as SwiftUI shapes (no font file), ghost "8" behind every digit. Bold small legends as annunciators (M T W T F S S, LOUD, ONCE, AL, SNZ). No cards; rows separated by hairline rules. Tint = ink. Buttons are ink-outlined (secondary) or solid ink (primary), 6 pt corners.

STORY: The user sees at once which alarms are armed and when the next one rings, edits with native controls, and when ringing sees a huge time, a big Snooze and a bigger Stop.

FIRST VIEWPORT: Large title "Alarms" with + top right; one line "Next Mon 06:30 · in 7 h 16 min"; then rows: segment time ~50 pt left, native switch right; below it the label left and the weekday annunciator strip right (active inked, inactive ghosted; "ONCE" for one-shots; "LOUD" outlined legend when on). Disabled rows drop to ~35% ink.

FORM: Unlit Glass, my rank 1 of 7 (IMPECCABLE'S PICK). Seed key e7950a3f.

NIGHTSTAND: Landscape + charging + alarm enabled. Pure black, dim red segments, no ghosts, steady colon, small "AL 06:30" legend with the next alarm time. Minimum brightness, idle timer off, restore on exit. Shifts a few points each minute against burn-in.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Unresolved

- App icon not designed yet.
- Ringing screen in landscape (nightstand to ringing transition) not mocked.
- Phase Two task screens inherit the world; not mocked beyond the task chips on the ringing screen.
