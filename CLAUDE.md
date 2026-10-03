# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mr. Driller is a Flutter app (iOS, Android, web, macOS) that displays drumming drills (mostly taiko)
and animates them in time with a metronome. It's a port of an earlier TypeScript web app in the
sibling directory `../web/`, which is where the "translated from web/src/drills.ts" comment in
`lib/data/drills.dart` points.

## Commands

```sh
flutter analyze                         # lint (flutter_lints; formatter page width is 100)
dart format lib test                    # format
flutter test                            # all tests
flutter test test/metronome_test.dart   # one file
flutter test --plain-name 'ticks once'  # tests whose name contains a string

flutter run -d chrome   # web
flutter run -d macos    # native macOS
flutter run -d ios      # iOS simulator

./deploy-web.sh         # build web with --base-href /mrdriller/ and rsync to samskivert.com
```

The web build is served from `/mrdriller/` by Apache. `web/.htaccess` falls back to `index.html`
so the path-based URLs below work, and it sets the `.wasm` MIME type that CanvasKit and SoLoud
need.

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
`/`, `/settings`, `/drills`, `/drills/<id>`, `/daily-practice`, `/tool/pattern-trainer`. Unknown
routes return null on purpose so deep links skip prefixes that aren't routes when the back stack
is built.

**Timing and playback:**
- `services/metronome.dart`: polls every 5ms against `clock.now()` and reports how many ticks are
  newly due (`onDue(n)`), so a late poll catches up instead of drifting. Tests drive it with
  `fake_async` (which is why it uses `package:clock`, not `DateTime.now()`).
- `services/metronome_sounds.dart`: beep/boop through `flutter_soloud`. SoLoud is FFI-based and
  low-jitter; `audioplayers` was dropped because of audible timing jitter. Don't swap it back.
- `widgets/drill_practice_view.dart`: the core playback state machine. `_tick()` advances an
  immutable `_PState` (intro → row/section/line/measure/offset → section repeat → drill repeat,
  with a bpm increase per drill repeat). It also auto-scrolls, plays sounds, and handles the
  wakelock.
- `widgets/drill_practice_host.dart`: the screen shell that owns the `Metronome` and a
  `ValueNotifier<DrillRunStatus>`. It's reused by single-drill practice and by daily practice
  (which keys a fresh host per drill).
- `screens/pattern_trainer_run_screen.dart`: a separate state machine for the pattern trainer
  tool, which plays randomly generated listen/repeat patterns.
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
and digit tiles, the time gauge, candy buttons, drips, bubbles) are in `lib/widgets/arcade.dart`.
Strokes are candy blocks: color = hand (blue R, orange L), a big iced rounded block = accent vs. a
smaller round candy = unaccented, pointed shape = down/up stroke. Screens with a playfield (drill
overview, drill practice) are built on `HudLayout` (`lib/widgets/hud_layout.dart`), which handles
the portrait HUD vs. landscape sidebar, cutout-aware safe areas, and keeping the playfield's state
across rotation; config controls (steppers, hands toggle, START!) are in
`lib/widgets/hud_controls.dart`. Other screens still use the original flat style (the old colors are
still in `AppColors`) and are being converted one at a time.

**State and persistence** (`lib/state/`): app-wide `ChangeNotifier` singletons (`settings`,
`practicePlan`, `practiceLog`, `reminders`), each `load()`ed in `main()` before `runApp` and
persisted with `shared_preferences`. Per-drill config is stored under `config.<drillId>`, and the
pattern trainer's under `config.pattern-trainer`. There's no state-management package; widgets
listen to these singletons directly.

**Reminders** (`services/reminder_scheduler.dart`): this clears and reschedules OS local
notifications at startup. It does nothing on web, and it must not import `dart:io` because that
breaks the web build.

## Assets

- `assets/sounds/*.wav` are generated by `assets/sounds/update_sounds.py` (standard library only).
  Edit the script, not the wav files.
- `assets/fonts/` holds subsets of M PLUS Rounded 1c (UI font) and Mochiy Pop One (display font),
  containing Latin plus only the non-ASCII characters used in `lib/`. **If you add new Japanese
  text or other non-Latin characters, regenerate them** with `assets/fonts/update_fonts.py`
  (instructions in `assets/fonts/README.md`).
