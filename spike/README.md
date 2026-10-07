# Alarm Spike

Throwaway app for answering the four spikes in `docs/description.md`. Not part of the real app.

## Run it

1. Open `SevenSegSpike.xcodeproj` in Xcode.
2. Target SevenSegSpike → Signing & Capabilities → pick your Team. If the bundle ID is rejected, change it to something unique.
3. Connect the iPhone, select it as run destination, press Run.
4. If Xcode says Developer Mode is off: on the phone, Settings → Privacy & Security → Developer Mode → on, restart, run again.
5. First launch with a free account: Settings → General → VPN & Device Management → trust your developer certificate.
6. In the app, tap **Request AlarmKit permission** and allow.

Everything the app sees is written to the log at the bottom (newest first). The log survives restarts. After each test, use the share button to send the log over, or copy the relevant lines.

## Test sounds

`rise*` files are generated on first launch into `Library/Sounds`. Their pitch rises steadily (440 Hz + 20 Hz per second) and they beep 0.25 s on / 0.25 s off. A **sudden drop in pitch** means the sound restarted (looped) or was cut.

## Spike 1: Stop button

1. Toggle **Nag** on. Sound: `rise10.caf`. Fire in: 30 s.
2. Tap **Schedule AlarmKit alarm**, lock the phone, wait.
3. When it rings, press the system **Stop** button on the lock screen.
4. Wait 30 s. Does it ring again? Repeat with the **side button** and the **volume buttons** instead of Stop.
5. Repeat once with the app swipe-closed before the alarm fires.
6. Tap **Cancel all alarms** when done.

Report: which buttons stop it, whether `StopIntent.perform` shows in the log, whether the nag alarm fires.

Result:
- Nag works when sliding to stop
- Nag works when pressing lock button to stop
- Nag works when closing out the app to stop
- At all times, StopIntent.perform is in the logs

## Spike 2: Loud mode

1. Set the phone ringer volume low (Settings → Sounds & Haptics) and the media volume low too. Slider in the app: 100%.
2. Tap **Arm loud alarm** (fire in 60 s), lock the phone, flip the Silent switch on.
3. When it rings: how loud is it? Tap into the app → **Silence loud mode** → **Cancel all alarms**.
4. Overnight test: set **Overnight time** to the morning, tap **Arm loud alarm at overnight time**, lock the phone and leave it charging. Try one night with Low Power Mode on.
5. Swipe-close the app after arming. Does the AlarmKit fallback ring at ringer volume?

Report: loudness, the `loud:` log lines (volume before/after, keepalive playing, interruptions).

Result:
- Loudness before is 0.0, after is 1.0
- It's pretty loud. Despite ringer volume being pretty much off.

## Spike 3: Silence during tasks

1. Schedule an AlarmKit alarm (not Loud mode). When it rings, tap **Open**.
2. In the app, tap **Stop alerting alarms**. Does the sound stop? Does the lock-screen alert disappear?
3. Tap **Re-fire in 10 s** while staying in the app. Does it ring while the app is in the foreground, and does it show full-screen?

Result:
- The sound stops
- The lock-screen alert disappears
- Re-fire in 10s staying in the app causes a small banner at the top to open and the sound to play, no full-screen.

## Spike 4: Sounds

1. Schedule an AlarmKit alarm with each of: `rise10.caf`, `rise10.wav`, `rise10.m4a`, `rise45.caf`. Let each ring for about a minute.
2. For each: does it play at all, does it loop (pitch drop every 10 s), does `rise45.caf` get cut at 30 s (pitch drop at 30 s)?
3. **Import sound…** an MP3 from Files and try it too.

Result:
- `rise10.m4a` plays
- `rise10.wav` plays
- `rise45.caf` is not cut off and runs the full 45s.
- An mp3 I imported plays as well

## Spike 5: Stop opens the app

1. Toggle **Stop opens app** on (and **Nag** on). Fire in: 30 s.
2. Tap **Schedule AlarmKit alarm**, lock the phone, wait.
3. When it rings, slide **Stop**. Does the app open (after Face ID / passcode)? Does `StopAndOpenIntent.perform` show in the log?
4. Repeat with the app swipe-closed before the alarm fires.

Result:
- Swipe to open works, and StopAndOpenIntent.perform is logged
- Works swipe-closed as well

## Leftovers

- Spike 1: do the **volume buttons** stop the alarm?
    - Yes, they do. Nag refires after stopping with volume buttons.
- Spike 2: overnight test, with Low Power Mode, and swipe-close fallback.
    - Let's ignore the overnight test. We assume the phone is plugged in and the app is open.
- Spike 4: does `rise10.caf` loop (pitch drop every 10 s), or stop after 10 s?
    - The pitch drops ever 10 s and continues playing

- In loud mode, the AlarmKit backup still rings if the app is closed.

---

## Comparison with competitor

- When the alarm triggers, the lockscreen turns into the alarm page that we are used to from AlarmKit
- The alarm starts getting louder slowly. I can see the volume indicator on the side slowly filling up in steps.
- No "Open" button, just "slide to stop"
- Sliding to stop immediately opens the app and the tasks, ends the audio, and retriggers the audio
- Pressing any button dismisses the alarm page, but the alarm continues blaring, and the volume continues increasing. I must now find my own way into the app, however.
- The app provides a notification as a quick-link to get to the app
- For all of this, the app needs to be open (in the background at least).