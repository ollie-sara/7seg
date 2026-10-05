---
name: OpenAlarm
description: An alarm you cannot dismiss half-asleep, drawn as an unlit 7-segment LCD clock.
colors:
  lcd: "#C7CCB6"
  ink: "#1A1D15"
  ink2: "#474C3D"
  lcd-dark: "#0D0F0C"
  ink-dark: "#D0D6C3"
  ink2-dark: "#8A917D"
  delete-red: "#8E2618"
  delete-red-dark: "#CC5A45"
  night-red: "#990000"
  night-black: "#000000"
typography:
  segment:
    fontFamily: "7-segment shapes drawn in SwiftUI (no font file)"
    fontSize: "50pt rows (scales with largeTitle), up to 150pt ringing, up to 220pt nightstand"
    letterSpacing: "0.105 of digit height"
  large-title:
    fontFamily: "SF Pro (system)"
    fontSize: "34pt (largeTitle)"
    fontWeight: 700
  title:
    fontFamily: "SF Pro (system)"
    fontSize: "28pt (title)"
    fontWeight: 600
  button:
    fontFamily: "SF Pro (system)"
    fontSize: "22pt (title2)"
    fontWeight: 600
  headline:
    fontFamily: "SF Pro (system)"
    fontSize: "17pt (headline)"
    fontWeight: 600
  body:
    fontFamily: "SF Pro (system)"
    fontSize: "17pt (body)"
    fontWeight: 400
  secondary:
    fontFamily: "SF Pro (system)"
    fontSize: "15pt (subheadline) / 13pt (footnote)"
    fontWeight: 400
  legend:
    fontFamily: "SF Pro (system)"
    fontSize: "12pt (caption)"
    fontWeight: 700
    letterSpacing: "0.8pt"
rounded:
  legend: "3pt"
  chip: "4pt"
  button: "6pt"
  tile-ring: "9pt"
spacing:
  xs: "4pt"
  sm: "6pt"
  md: "12pt"
  lg: "16pt"
  xl: "24pt"
  section: "28pt"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.lcd}"
    typography: "{typography.button}"
    rounded: "{rounded.button}"
    height: "84pt min"
    width: "full"
  button-secondary:
    backgroundColor: "{colors.lcd}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.button}"
    height: "64pt min"
    width: "full"
  weekday-chip-on:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.lcd}"
    rounded: "{rounded.chip}"
    height: "44pt min"
  weekday-chip-off:
    backgroundColor: "{colors.lcd}"
    textColor: "{colors.ink}"
    rounded: "{rounded.chip}"
    height: "44pt min"
  legend-boxed:
    textColor: "{colors.ink}"
    typography: "{typography.legend}"
    rounded: "{rounded.legend}"
    padding: "1pt 4pt"
  switch-on:
    backgroundColor: "{colors.ink}"
    rounded: "{rounded.chip}"
    size: "52pt x 30pt"
  switch-off:
    backgroundColor: "transparent, 1.5pt {colors.ink} stroke"
    rounded: "{rounded.chip}"
    size: "52pt x 30pt"
  button-toolbar:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.lcd}"
    rounded: "{rounded.button}"
    height: "36pt min"
  button-toolbar-secondary:
    backgroundColor: "transparent, 1.5pt {colors.ink} stroke"
    textColor: "{colors.ink}"
    rounded: "{rounded.button}"
    height: "36pt min"
  appearance-tile:
    backgroundColor: "{colors.lcd} in the tile's own scheme"
    textColor: "{colors.ink2}, {colors.ink} when selected"
    typography: "{typography.legend}"
    rounded: "{rounded.button}"
  appearance-tile-selected:
    backgroundColor: "transparent, 2pt {colors.ink} ring at 4pt offset"
    rounded: "{rounded.tile-ring}"
  nightstand-face:
    backgroundColor: "{colors.night-black}"
    textColor: "{colors.night-red}"
    typography: "{typography.segment}"
---

# Design System: OpenAlarm

## Overview

**Creative North Star: "Unlit Glass"**

The whole screen is one unlit, reflective LCD. Every state is a printed segment, either inked or ghosted. Nothing appears that the glass could not show. In light mode the glass is grey-green with near-black ink; in dark mode it is a negative LCD with pale ink on near-black.

Identity lives in three places only: the ground color, the 7-segment digits, and the small bold legends printed beside them. Navigation, sheets, menu pickers and swipe actions stay native iOS, tinted ink. Controls that would show stock iOS chrome (switches, the time wheel, the volume slider, glass toolbar buttons) are redrawn as printed LCD parts (`Controls.swift`). The app refuses the Clock-app default of thin rounded digits on grouped cards.

The nightstand face is a separate, darker state of the same world: pure black, dim red segments, no ghosts.

**Key Characteristics:**
- One flat ground per screen; no cards, no shadows.
- Two-tone: ground and ink, with one secondary ink for supporting text.
- Time is always drawn as 7-segment shapes, with faint ghost segments behind.
- Small bold uppercase legends act as LCD annunciators.
- Native navigation and menu pickers, tinted ink. Switches, time setter, level bar and toolbar buttons drawn as LCD parts.

## Colors

A two-tone LCD palette: one ground, one ink, one secondary ink, each with a light and a dark value. Defined in code (`Segments.swift`), no asset catalog.

### Primary
- **Segment Ink** (`ink` / `ink-dark`): all primary text, lit segments, the app tint, the on switch and its off outline, lit level-bar cells, the Add, Save and Done buttons, the outline of the gear button, the selection ring of the appearance tile, the solid Stop button, selected weekday chips, the outline of Snooze and boxed legends.

### Neutral
- **Unlit Glass** (`lcd` / `lcd-dark`): the background of every screen (list, editor, sound picker, settings, ringing). Also the text color on solid-ink fills.
- **Faded Ink** (`ink2` / `ink2-dark`): secondary text: the "Next" line, footers, section headers, snoozes left, empty-state hint, unselected appearance-tile legends. It exists because plain `.secondary` (ink at half opacity) fails contrast on the ground.

### Destructive
- **Delete Red** (`delete-red` / `delete-red-dark`): brick red, like the red legends printed on old LCD faces. Only the Delete Alarm text in the editor and the Delete swipe action in the list. 5.2:1 on the light ground, 4.6:1 on the dark ground.

### Nightstand
- **Night Red** (`night-red`, red channel only): nightstand digits and its AL legend. The least light an OLED can emit for a readable face. Nightstand only.
- **Night Black** (`night-black`): nightstand background. Pure black so the OLED pixels are off.

### Derived opacities of ink (not separate tokens)
- Ghost segments: 7.5% ink, both appearances.
- Off weekday letters in the row strip: 20%.
- Off weekday chips in the editor: 7% ink fill.
- Row separators and the appearance-tile hairline: 16% ink.
- Outline toolbar button pressed: 12% ink fill.
- Disabled alarm row: whole row at 35%.
- Ringing flash low phase: 15%.

### Named Rules
**The Two-Tone Rule.** A screen uses ground and ink, plus Faded Ink for supporting text. States are made with ink opacity, never a new hue. The one exception is Delete Red, on destructive actions (Delete).

**The Red-Only-At-Night Rule.** Night Red appears only on the nightstand face, on pure black. It never appears in the daytime screens.

## Typography

**Display:** 7-segment digits drawn as SwiftUI shapes (`SegmentText`, `SegmentClock`), no font file.
**Text:** SF Pro through iOS text styles, so everything follows Dynamic Type.

**Character:** The segment digits carry the identity; the system face stays plain and native around them.

### Hierarchy
- **Segment** (digit height 50pt in rows, scaled with largeTitle; up to 150pt on ringing; up to 220pt on nightstand): every displayed time. Digit width 0.52 and segment thickness 0.14 of the height, slanted-end segments with a small gap, square colon dots. 12-hour locales add the AM/PM legend top-right of the digits.
- **Large Title** (largeTitle, bold, native): "Alarms" nav title, in ink. Sheets (editor, Settings) use the native inline title instead.
- **Title** (title, semibold): alarm label on the ringing screen.
- **Button** (title2, semibold): Snooze and Stop. Also the empty-state "No Alarms" (bold).
- **Headline** (headline): alarm label in rows.
- **Body** (body): editor rows; weekday chips use body semibold.
- **Secondary** (subheadline / footnote, Faded Ink): "Next" line, snoozes left, repeat summary.
- **Legend** (caption, bold, 0.8pt tracking, uppercase): annunciators LOUD, ONCE, AL, AM/PM, the weekday strip, and the appearance-tile names.

### Named Rules
**The Segment-For-Time Rule.** A displayed clock time is drawn with `SegmentClock`, never with a text font. In prose lines (the "Next" line, legends) the time is plain text formatted by `Segments.label`, so "AL 06:30" matches the digits.

**The Ghost Rule.** Segment digits show unlit ghost segments behind them (7.5% ink), like an "8" printed on the glass. Only the nightstand face turns ghosts off.

## Layout

Plain native lists on the ground: `List` with `.plain` style, hidden content background, clear row backgrounds. Rows are separated by hairline rules (16% ink). Every `Form` sheet (editor, Settings) goes through `sheetForm()`: hidden scroll background on the bare ground, horizontal content margin 0 so rows share the list's 16pt gutter, 28pt between sections so each header reads with its own rows, clear row backgrounds, and hidden section separators (`listSectionSeparator(.hidden)`).

Alarm row: segment time on the left, native switch top-right at the digit height; below, the label on the left and the legends on the right (LOUD boxed if on, then ONCE or the 7-day strip). Row vertical padding 6pt, 10pt between time and label line, 12pt between label-line items. Day strip cells are 15pt wide (scaled with caption) at fixed positions in locale weekday order.

Ringing screen: 24pt padding. Portrait stacks face over buttons (24pt gap); landscape (compact height) puts them side by side (32pt gap, buttons max 320pt wide). Face: legend line on top, time, label, flexible space. Buttons stack 12pt apart.

Settings sheet: Appearance section with three tiles in a row, 12pt apart, legend 8pt below each tile; then About.

Nightstand: landscape only, content centered with 60pt side padding, legend 12pt above the digits.

## Elevation & Depth

Flat. There are no shadows and no layered surfaces. Depth comes only from ink opacity: ghost segments, faded secondary ink, and dimmed disabled rows. Native sheets keep their system presentation (corners, dimming) but carry the bare ground, not system material. Toolbar buttons hide the shared glass background (`sharedBackgroundVisibility(.hidden)`).

### Named Rules
**The Flat Glass Rule.** Nothing floats above the glass. No cards, no shadows, no grouped-list backgrounds.

## Shapes

Small, tight corners. Buttons 6pt, editor weekday chips 4pt, boxed legends 3pt with a 1.5pt ink stroke. Snooze uses a 2pt ink stroke; the outline toolbar button a 1.5pt ink stroke. Appearance tiles 6pt corners with a 1pt hairline; the selection ring 9pt corners, 2pt, 4pt outside the tile. Switch track 4pt corners with a 1.5pt ink stroke, knob 2pt. Segments are hexagonal bars with pointed ends. Native pickers keep their system shapes.

## Components

### Buttons
Large and unambiguous for a half-asleep user.
- **Shape:** 6pt corners.
- **Primary (Stop):** solid ink fill, ground-colored text, title2 semibold, full width, 84pt min height. The biggest target on the ringing screen.
- **Secondary (Snooze):** ground fill with a 2pt ink outline, ink text, full width, 64pt min height, optional "N of M left" line in Faded Ink below.
- **Toolbar (Add, Save):** solid ink, ground-colored icon or text, body semibold, 6pt corners, 44 × 36pt min, no glass. Pressed at 70% ink. Cancel is plain ink text.
- **Toolbar secondary (gear):** `OutlineButtonStyle`, ground with a 1.5pt ink stroke, ink icon, 6pt corners, 44 × 36pt min, no glass. Pressed fills 12% ink. Paired with the solid +, so a top bar has one primary (solid) and at most one secondary (outlined) button.
- **Plain buttons in lists** (Open Settings, row tap target) are bold or plain ink text with no chrome.

### Settings Sheet
- Inline title "Settings", solid-ink Done at the confirmation position, no Cancel.
- **Appearance:** three appearance tiles, footer in Faded Ink ("System follows the iPhone's Light and Dark setting."). Selection haptic on change.
- **About:** the version row only (native `LabeledContent`, "0.1 (1)"). Link rows come later in the same section.

### Appearance Tile
- A small piece of real glass: `Color.lcd` with a ghosted segment "12:00" (10pt side inset, aspect 1.15), rendered in its own palette by setting the `colorScheme` environment, so Light and Dark show their true ground and ink whatever the app's appearance.
- System splits on the diagonal: light glass with the dark glass masked to the lower-right triangle.
- 6pt corners, 1pt hairline at 16% ink. Selected adds a 2pt ink ring at a 4pt offset with 9pt corners.
- Legend below: Faded Ink when unselected, ink when selected.
- One VoiceOver button per tile, Selected trait on the current one.

### Appearance Setting
- System / Light / Dark, stored per device (`@AppStorage("appearance")`).
- Applied window-wide (`overrideUserInterfaceStyle` on every window), so sheets and the ringing cover follow. Set without animation on launch; on change the whole window crossfades in 0.35 s rather than views snapping one by one.
- The nightstand face is unaffected: it is black and red in every appearance.

### Weekday Chips (editor)
- **Style:** seven equal-width chips, 4pt gap, 44pt min height, body semibold, 4pt corners.
- **State:** on = solid ink with ground text; off = 7% ink fill with ink text. Selected trait for VoiceOver.

### Switch
- 52 × 30pt cell, 4pt corners. On = solid ink with a ground-colored square knob at the trailing end. Off = hollow cell (1.5pt ink stroke) with an ink knob at the leading end.
- The knob slides across in 0.2 s (snappy), with a selection haptic. Instant under Reduce Motion.
- One VoiceOver element with the toggle trait and On/Off value.

### Level Bar (Loud volume)
- Ten cells for 10–100%, 3pt apart, growing from 46% to 100% of the 28pt height toward loud. Lit cells full ink, the rest 7.5% (ghost).
- Tap or drag sets the level in 10% steps. VoiceOver sees a native adjustable slider.
- The percent sits right of the bar in a box sized for "100%", monospaced digits, so the bar never changes width.

### Time Setter (editor)
- Replaces the wheel picker with two wheels of segment digits, hours and minutes, with a fixed colon between them. Digits 72pt (scaled with largeTitle, max 110pt), ghosts on, AM/PM legend top-right on 12-hour locales.
- Native scroll physics: flick with momentum, snap to the center row, loop in both directions. Rows above and below fade out through a gradient mask. Selection haptic on every row change.
- VoiceOver: hour and minute are each one adjustable element whose value is the full time.

### Alarm Row
- A plain button (opens the editor) with the native toggle layered at top-trailing so each keeps its own tap target.
- Disabled alarms drop the whole row content to 35%.

### Legend (annunciator)
- Caption bold, uppercase, 0.8pt tracking, ink. Boxed variant: 1.5pt ink stroke, 3pt corners, 4pt / 1pt padding (used for LOUD).
- LOUD shows only when on, never ghosted, to keep rows calm.

### Day Strip
- All seven weekday letters in fixed positions, caption bold. Active days in full ink, others at 20%. One-shot alarms show the ONCE legend instead.

### Segment Clock (signature)
- Ghosted 7-segment time with AM/PM legend on 12-hour locales; one VoiceOver label with the spoken time.
- **Ringing:** flashes at 1 Hz (full ink, then 15% on alternate half-seconds). Steady under Reduce Motion.

### Nightstand Face (signature)
- Pure black, Night Red digits without ghosts, steady colon, small "AL <next ring>" legend above.
- Screen brightness 0 and idle timer off while shown; restored on exit.
- Moves through 8 offsets, one per minute, up to 12pt, against burn-in.
- Shown only in landscape while charging with an enabled alarm; tap to leave.

## Do's and Don'ts

### Do:
- **Do** use `Color.lcd` as the background of every screen and `Color.ink` as foreground and tint.
- **Do** use `Color.ink2` for secondary text instead of `.secondary`.
- **Do** draw every displayed time with `SegmentClock`, with ghosts on (except the nightstand).
- **Do** format times in legends and text with `Segments.label` so they match the digits.
- **Do** express state with ink opacity (7.5% ghost, 20% off, 35% disabled) rather than new colors.
- **Do** use native iOS menu pickers and navigation, tinted ink, and the LCD switch, level bar and ink buttons from `Controls.swift` for everything else.
- **Do** keep ringing actions full width: Stop solid ink and larger, Snooze outlined.
- **Do** give every `Form` sheet `sheetForm()` and hidden section separators, so sheets share the list's ground and gutter.
- **Do** honor Reduce Motion: anything that flashes or moves becomes steady.

### Don't:
- **Don't** use thin rounded digit fonts or any text font for clock times.
- **Don't** put content on cards, grouped backgrounds, or shadows.
- **Don't** add accent colors; ink is the tint.
- **Don't** use Night Red, or pure black ground, outside the nightstand face.
- **Don't** show ghost segments on the nightstand face.
- **Don't** let stock iOS switches, sliders or glass toolbar buttons through.
- **Don't** put two solid ink buttons in one bar; one solid primary, the rest outlined or plain ink text.
