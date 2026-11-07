# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Dokodoko Drills (formerly Taiko Trainer) is a Flutter app (iOS, Android, web) that
displays drumming drills (mostly taiko) and animates them in time with a metronome. It was
originally called Mr. Driller, after the Namco games its look is inspired by, and it still is
internally (package name, bundle IDs, web path). The name shown anywhere in the app must come from
`appName()` (`lib/state/app_name.dart`), never be hard-coded: a secret easter egg can switch it
back to "Mr. Driller". It's a port of an earlier TypeScript web app in the sibling directory
`../web/`, which is where the "translated from web/src/drills.ts" comment in
`lib/data/drills.dart` points.

## Commands

```sh
flutter analyze                         # lint (flutter_lints; formatter page width is 100)
dart format lib test                    # format
flutter test                            # all tests
flutter test test/metronome_test.dart   # one file
flutter test --plain-name 'ticks once'  # tests whose name contains a string

flutter run -d web-server   # web: open http://localhost:8123 in your own Chrome (keeps settings)
flutter run -d chrome       # web, in a fresh Chrome profile (settings and permissions reset)
flutter run -d ios          # iOS simulator

./deploy-web.sh         # build web with --base-href /mrdriller/ and rsync to samskivert.com
./appstore-publish.sh   # build the iOS app and upload it to TestFlight (as Xcode's Apple account)
```

The web build is served from `/mrdriller/` by Apache. `web/.htaccess` falls back to `index.html`
so the path-based URLs below work, and it sets the `.wasm` MIME type that CanvasKit and SoLoud
need. It also sets COOP/COEP headers (as does `web_dev_config.yaml` for `flutter run`) so the page
is cross-origin isolated: only then does flutter_soloud use its AudioWorklet build. It also fixes
the dev server's port (8123), so the origin, and with it the settings in local storage, stays the
same between runs. Without them it
mixes audio on the main thread, which pops and stalls.

## Architecture

**Drill data model** (`lib/model/model.dart`): `Drill` → rows (`DrillRow` = `List<Section>`, shown
side by side) → `Section` (label, repeat count, lines) → `Line` → `Measure` (`List<Beat?>`) →
`Beat` (optional label, `List<Stroke?>`). A null beat is a rest. One "beat" in a measure is one
tick, which is a sixteenth of a quarter note at the configured bpm, multiplied by `Drill.scale`.
`Drill.bpm` is confusingly *beats per measure*: it sets the length of the count-in intro
(`bpm * 4` ticks), not the tempo. Tempo comes from the user's `DrillConfig`. `swapHands()` mirrors
L and R across the whole drill.

**Drill definitions** (`lib/data/drills.dart`): every drill is written in a compact DSL
(`R`/`r`/`L`/`l` accented and unaccented hits, `rd`/`ru` down and up strokes, `measure`, `line`,
`oneLineSection`, `labeledBeat`) inside a `// dart format off` block. Keep it unformatted. A new
drill has to be added to the `drills` list to appear in the app and to be reachable at
`/drills/<id>`.

**Routing** (`lib/main.dart`): path URLs (`usePathUrlStrategy`) parsed in `_onGenerateRoute`:
`/`, `/settings`, `/drills`, `/drills/<id>`, `/playlists`, `/playlists/<id>`, `/daily-practice`,
`/metronome`, `/metronome/<presetId>`, `/tool/pattern-trainer`, `/tool/midi-diagnostics` (not on
the menu), and in debug builds only, `/debug` (`screens/debug_screen.dart`, behind a bug icon on
the menu): a menu of screens filled in with made-up data, for working on how they look
(`/debug/drill-results`, `/debug/playlist-results`). Unknown routes return null on purpose so deep links skip prefixes that aren't routes
when the back stack is built. A reminder linked to a playlist carries its route as
the notification's payload: a tap that launches the app becomes `MaterialApp`'s initial route (see
`notificationLaunchRoute()`), and one while it's running rebuilds the back stack via
`_openDeepLink`.

**Timing and playback:**
- `services/metronome.dart`: polls every 5ms against a steady clock (a `Stopwatch`, so
  microseconds even on web, where `DateTime.now()` has only milliseconds) and reports how many
  ticks are newly due (`onDue(n)`), so a late poll catches up instead of drifting. Tests drive it
  with `fake_async`: when `package:clock`'s clock is overridden, it uses that instead.
- `services/metronome_sounds.dart`: beep/boop through `flutter_soloud`. SoLoud is FFI-based and
  low-jitter; `audioplayers` was dropped because of audible timing jitter. Don't swap it back.
- `services/click_scheduler.dart`: every player's clicks (drills, the pattern trainer, the
  metronome tool) are scheduled 400ms ahead with SoLoud's `playScheduled`, on the audio engine's
  clock, so they play exactly on time however busy the main thread is. Playing them when a poll
  found them due wobbled audibly, by up to 90ms. Each player answers what sounds on the tick n
  ahead (`ClicksFor`) by playing its state forward on a copy, and says null where a tempo change
  comes first, as the ticks after it are timed at the new tempo. Only each run's first click is
  played immediately.
- `widgets/drill_practice_view.dart`: the core playback state machine. `_tick()` advances an
  immutable `_PState` (intro → row/section/line/measure/offset → section repeat → drill repeat,
  with a bpm increase per drill repeat). It also auto-scrolls, plays sounds, and handles the
  wakelock.
- `widgets/drill_practice_host.dart`: the screen shell that owns the `Metronome` and a
  `ValueNotifier<DrillRunStatus>`. It's reused by single-drill practice and by playlist runs
  (`screens/playlist_run_screen.dart`, which keys a fresh host per drill). It records every drill
  that finishes on its own in `practiceLog`, so that's the only place drills are logged.
- `screens/pattern_trainer_run_screen.dart`: a separate state machine for the pattern trainer
  tool, which plays randomly generated listen/repeat patterns.
- `services/metronome_player.dart`: plays the metronome tool (its screens are
  `screens/metronome_screen.dart` and `screens/metronome_preset_screen.dart`): each beat of the
  measure as beep (high), boop (low) or nothing, speeding up every so many measures. It's the
  other thing that writes to `practiceLog`: a minute or more of playing, logged (under
  `metronomeId`) on leaving the screen or the app going to the background.
- `services/midi_input.dart`: MIDI input (for a drum pad), web-only for now via Web MIDI
  (`midi_input_web.dart`, picked by conditional import; a stub elsewhere). Each message carries the
  browser's arrival timestamp and the time Dart got it, both on `performance.now()`'s clock.
  Screens share one connection, `midi` (`services/midi_connection.dart`): opening a second
  `MidiInput` closes the first. Settings lists MIDI devices, each opening
  `screens/midi_device_screen.dart` to rename it, map its pads (notes) to a hand, and calibrate
  it, saved in `midiDevices` (`state/midi_devices.dart`, keyed by port name). A `Calibration` (the
  timing test's average hit offset, which hits are adjusted by) is kept per device per audio
  output, as output delay varies a lot by device (Bluetooth, TVs). Outputs are named by the user
  on web and one is in use (`audioOutputs`, `state/audio_outputs.dart`); on mobile they could come
  from the audio route. Both are local only, not synced: calibrations hold for one host device.
  Playing along (the timing test) takes the player's own habit of hitting early or late into a
  calibration, so it can also be measured with the microphone (`model/mic_calibration.dart`,
  `services/mic_recorder.dart`, web-only for now): it hears both the click and the stick, and
  (click sound - stick sound) + (MIDI hit - click scheduled) is the delay, with the mic's own
  delay cancelling out.
  `screens/midi_diagnostics_screen.dart` shows the inputs, hit notes and a message log, and holds
  the timing test (`widgets/midi_timing_test.dart`), which schedules clicks on that same clock and
  compares hits with the ideal beat times (`model/timing.dart`).
- Grading (`model/grading.dart`): when a drum pad is set up, `drill_practice_view.dart` matches
  its hits (by pad role, less the calibration, on the metronome's clock) to the strokes expected,
  which it finds by playing the state machine forward like `ClicksFor` does. Grades are marked on
  the strokes (`StrokeView.grade`, drawn over the block so layout is unchanged). Accents are
  graded too once a device has an accent velocity (hits at or above it are accented). How close
  to a stroke a hit must be for perfect/good is the `GradingDifficulty` setting, and the clear
  card shows a summary and waits for DONE instead of moving on.
- `model.computeDrillDuration` has to agree with the state machine's intro and repeat rules. Change
  them together.

**Layout sizing** (`lib/util/size_config.dart`): it solves for the stroke size that makes a
section's widest line exactly fit the available width, and wraps lines onto more rows below
`minUnwrappedStrokeSize`. It has thorough tests in `test/size_config_test.dart`. Its height
equation mirrors `SectionView`'s layout (header banner, padding, rows), so a change to one must be
matched in the other.

**Visual theme:** an arcade look inspired by Namco's Mr. Driller games: a navy "playfield" for drill
notation, cream "HUD" panels, candy-colored blocks and buttons, and banner labels. The palette and
font names are in `lib/util/colors.dart`, and the shared pieces (puffy/outlined text, HUD banners
and digit tiles, the depth ruler, candy buttons, drips, bubbles) are in `lib/widgets/arcade.dart`.
Strokes are candy blocks: color = hand (blue R, orange L), a big iced rounded block = accent vs. a
smaller round candy = unaccented, pointed shape = down/up stroke. Screens with a playfield (drill
overview and practice, playlist-entry config, the playlist run-through, the pattern trainer run)
are built on `HudLayout` (`lib/widgets/hud_layout.dart`), which handles the portrait HUD vs.
landscape sidebar, cutout-aware safe areas, and keeping the playfield's state across rotation; the
drill config screens share `DrillConfigLayout`. The other screens are cream `CreamScreen`s (same
file) of white `BannerCard`s. Shared controls (steppers, hands toggle, count switch, START!, time
chip, candy switch and segmented picker, delete confirmation, name prompt, section headings) are in
`lib/widgets/hud_controls.dart`.

**State and persistence** (`lib/state/`): app-wide `ChangeNotifier` singletons (`settings`,
`playlists`, `metronomePresets`, `practiceLog`, `reminders`, `midiDevices`, `audioOutputs`), each
`load()`ed in `main()` before `runApp` and persisted with `shared_preferences`. Per-drill config is stored under
`config.<drillId>`, the pattern trainer's under `config.pattern-trainer`, and the metronome's
main screen's under `config.metronome`. There's no state-management package; widgets listen to these
singletons directly.

**Sync** (`state/sync.dart`, `services/cloud_store.dart`): on iOS, everything but reminders is also
kept in the iCloud key-value store (a method channel in `ios/Runner/AppDelegate.swift`, no plugin),
so it survives the app being deleted and syncs between devices. Android relies on its default Auto
Backup of `shared_preferences` instead. Each document is merged with its iCloud copy on load, on
every local change, and when another device changes it: configs and settings are `Stamped` (latest
change wins), playlists and metronome presets are `SyncedList`s (stamped per item, with deletion
markers), and the practice log is a union of entries, kept in iCloud as compact per-month keys to
fit its 1MB limit. Merges must cope with either side being empty or stale (a fresh install starts
empty, and iCloud's copy can arrive after launch). Data saved before syncing existed still loads
(stamped as oldest), so keep reading the old formats.

**Reminders** (`services/reminder_scheduler.dart`): this clears and reschedules OS local
notifications at startup. It does nothing on web, and it must not import `dart:io` because that
breaks the web build.

## Assets

- `assets/sounds/*.wav` (the metronome's beep and boop) are generated by
  `assets/sounds/update_sounds.py` (standard library only). Edit the script, not the wav files.
  `assets/sounds/don.mp3` (the taiko drum hit for the menu's drum easter egg) is a real recording.
- The app icon (`assets/icon/`), Android's notification icon
  (`res/drawable-*/ic_notification.png`), the launch screens' badge (iOS's `LaunchImage.imageset`,
  centered on cream by `LaunchScreen.storyboard`, and Android's `res/drawable-*/launch_image.png`,
  for before Android 12) and every platform's generated icons all come from the app's own widgets
  (`AppIcon` and `Mitsudomoe` in `lib/widgets/taiko_drum_head.dart`). Don't edit the PNGs: change
  the widgets, then run
  `flutter test tool/generate_icons_test.dart && dart run flutter_launcher_icons`.
- `assets/fonts/` holds subsets of M PLUS Rounded 1c (UI font) and Mochiy Pop One (display font),
  containing Latin plus only the non-ASCII characters used in `lib/`. **If you add new Japanese
  text or other non-Latin characters, regenerate them** with `assets/fonts/update_fonts.py`
  (instructions in `assets/fonts/README.md`).
