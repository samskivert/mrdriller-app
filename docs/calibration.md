# Drum pad calibration

How the app measures the delay between a click being scheduled and a pad hit reaching it, and why
it works the way it does. Much of this was learned the hard way, from real recordings that broke
earlier versions; those lessons are written down here so they aren't relearned.

Code map:

| What | Where |
|---|---|
| Calibration model, storage (per device, per audio output) | `lib/state/midi_devices.dart` |
| Calibration pages (Play along, Between clicks) | `lib/screens/calibration_screen.dart` |
| Play along: the run, the grid, results, saving recordings | `lib/widgets/midi_timing_test.dart` (`listen` mode), `lib/widgets/calibration_grid.dart`, `lib/widgets/ear_raster.dart` |
| Play along: the audio analysis | `lib/model/ear_check.dart` |
| Between clicks: the run and the analysis | `lib/widgets/mic_calibration_card.dart`, `lib/model/mic_calibration.dart` |
| Microphone recording, time-to-frame mapping | `lib/services/mic_recorder.dart`, `mic_recorder_web.dart` |
| Clock smoothing | `ClockSync` in `lib/model/timing.dart` |
| Where grading applies it | `_handleMidi` in `lib/widgets/drill_practice_view.dart` |
| Real-recording regression tests | `test/ear_check_recording_test.dart`, `test/recordings/` |

## What's being measured, and why

Grading compares when a pad hit arrives with when the stroke's click was scheduled. Two delays sit
between them that have nothing to do with the player:

- **D_out**: from scheduling a click to its sound leaving the speakers (the audio engine's buffer,
  the browser's and OS's output buffers, the device). Varies a lot by output: tens of milliseconds
  for laptop speakers, far more for Bluetooth or a TV. Hence a calibration per device per output.
- **d_midi**: from the stick hitting the pad to the browser getting the MIDI message (the pad's
  sensor scan, about 1ms on a 31.25kbaud serial line for 3 bytes, the USB adapter, the OS).

A player who hits exactly when they hear a click produces a MIDI message at
`Cout + D_out + d_midi`. So the calibration is **D_out + d_midi**, the "system delay", and grading
subtracts it from every hit. Grading then sees the player's real timing against the click they
heard.

The calibration deliberately does **not** include the player's own habit of hitting early or late.
An early design calibrated from a timing test (play along, average the offset), which folds the
player's lead into the calibration, so grading would then hide it. The player in question turned
out to play about 45ms ahead of the click without perceiving it, confirmed by a phone recording at
their ear. Hiding that would defeat the point of grading, so both methods measure the delays only,
with the microphone, and the timing test can no longer save a calibration (old saved ones without
a recognized method aren't loaded).

The two delays can't be measured separately. Doing so would need the microphone's own input delay
(see below), which would take a loopback test. Luckily only their sum is needed.

## Clocks, and why the unknowns cancel

**There is one clock.** Clicks are scheduled on `performance.now()`. Web MIDI timestamps
(`MIDIMessageEvent.timeStamp`) are the browser's arrival times on the same clock. The pad has no
clock of its own: MIDI 1.0 carries no timestamps.

**Microphone samples are numbered by the recorder's audio clock** (its frame counter).
`MicRecorder.frameAt(ms)` maps a `performance.now()` time to a frame by reading the audio clock
alongside `performance.now()` (smoothed, see [ClockSync](#a-stepped-clock-keep-the-freshest-reading)).
Call the result a time's **rough position**. The mapping is precise and stable, but it's off from
reality by an unknown constant **E**: the microphone's input delay (mic, ADC, OS buffers, browser)
plus however the audio clock relates to the moment sound reaches the mic.

Measure two gaps, each a sound's actual position in the recording less its rough position:

- A click scheduled at `Cout` is heard at `frameAt(Cout) + K_c`, where **K_c = D_out + E**.
- A hit that reached the browser at `Hmidi` is heard at `frameAt(Hmidi) + K_h`, where
  **K_h = E − d_midi** (the sound happened d_midi *before* the MIDI message arrived).

Then **K_c − K_h = D_out + d_midi**, and E drops out. Neither D_out, d_midi nor E is ever needed
on its own.

A free by-product: **the player's lead "in the air"**, the hit's sound less the click's sound in
the same recording, which involves none of the app's clocks at all. Equivalently, per click,
`(MIDI time − scheduled time) − system delay`.

## The two methods

### Play along (the main one)

Listen to a count-in of 8 clicks (4 beats, 2 clicks a beat, the beep on the beat and the boop
between), then play every click, 64 hits, at 120bpm by default. It ends by itself 1.2s after the
last click (time for that click to be recorded and checked) and shows the system delay and the
player's lead, each ± its standard deviation. A grid shows every click, filled in live about one
click behind the sound. Needs at least 16 usable clicks to save. All the sections below are about
this method.

### Between clicks (the fallback)

A click every second; the player hits the pad roughly halfway between clicks, 12 times. For each
hit, with the click before it scheduled at T, the hit's MIDI time M, and their sounds at frames C
and S:

```
system delay = (C − S) / sampleRate + (M − T)
```

The same cancellation in another form: E is in both C and S. Each sound's start is found with
`findOnset` (see [1d](#1d-pinning-down-each-click)), the hit first (searched from 50ms before to
150ms after its rough position), then the click (from 20ms before its rough position up to 20ms
before the hit). Hits within 150ms of a click are skipped so the sounds don't overlap. The result
is the mean of the measurements within 10ms of their median.

It's simpler and doesn't need the voting below, but it asks the player to do something unnatural,
and it gives fewer measurements. It was within a few milliseconds of Play along on the same
hardware.

## Play along, step by step

### Step 1: the count-in clicks

Done once the count-in plus the longest allowed delay (500ms) has been recorded. Goal: K_c.
(`_learnCountIn`, `_sounds`.)

#### 1a. Listening for each tone separately

The clicks are pure tones (800Hz beep, 400Hz boop, about 35ms with a 2ms fade-in). At every 1ms
step, for each tone, take a 5ms window and compute one bin of a Fourier transform:

```
level(t) = | Σₙ x[n] · e^(−iωn) | / N,   ω = 2π·f / sampleRate,   over the window's N samples
```

(the Goertzel algorithm's quantity, evaluated directly). About a million multiply-adds per tone
for a whole count-in.

- A 5ms window resolves about 1/5ms = 200Hz, so each tone only picks up noise in a narrow band;
  room noise is spread over everything. A typical count-in: 800Hz clicks at 0.014, background
  0.0001.
- The two tones are measured separately because speakers aren't flat: a MacBook plays the 400Hz
  boop about twice as loud as the 800Hz beep, and one threshold for both would miss the beeps.
- 5ms trades separating the tones against smearing where a click starts. The precise start comes
  in 1d.

#### 1b. Levels into sounds

Per tone: background = the **20th percentile** of the levels (the quietest fifth: each tone's
clicks take up only about 10% of the stretch), threshold = max(5 × background, 0.2 × loudest).
A sound starts wherever the level crosses the threshold after at least half a click interval
below it, so a click's fade-out isn't a second sound. A sound heard at both tones within that
time counts once, remembering both tones (a loud boop leaks into the 800Hz band).

An earlier version averaged for the background, and the clicks themselves inflated it until the
threshold sat above the beeps.

#### 1c. Lining up by voting

Each click comes out an unknown delay after its rough position, the same for all of them, from
−50 to 500ms. That's twice the click interval, so no single click can be placed on its own. So
every pair (click i, sound s) **of the same tone** votes for delay = s − roughᵢ, in 5ms buckets;
the delay with the most votes wins, and **ties go to the shortest delay**. In effect a histogram
of pairwise time differences (a cross-correlation of two spike trains). A stray sound adds one
harmless vote.

The tone condition is essential. Without it, the delay one click interval later (each click
paired with the next click's sound) scores as well. One recording had 9 sounds (the 8 clicks and
the first hit after), so that delay also got 8 votes, and it was picked: about 350ms where the
truth was about 100ms. That also built each pitch's template from the other pitch's clicks, which
is why no boop matched in an earlier run. With alternating tones, the shifted delay pairs beeps
with boops and gets nothing.

#### 1d. Pinning down each click

For each click, the sound of its tone within ±15ms of rough + the winning delay, refined by
`findOnset` (`lib/model/mic_calibration.dart`) on the raw waveform: over |x| from **30ms before
to 15ms after**, noise = the median, require peak ≥ 12 × noise, and the start is the first sample
above max(0.2 × peak, 6 × noise).

The window is lopsided on purpose. A symmetric one held enough of the click to raise the "noise",
and starts came out 3ms late.

Give up ("can't hear the clicks") unless at least half the clicks were found and both tones were
heard. Otherwise **K_c = the median of (start − rough position)**. It stays fixed for the run.

**Precision.** |x| peaks only twice per cycle (every 0.625ms at 800Hz, 1.25ms at 400Hz), so the
first sample over 20% wobbles by a fraction of a millisecond with the tone's phase; the median
over 8 smooths that. And "20% of the peak" lands a little after the true start, part way up the
fade-in. That consistent offset only partly cancels with the hits' own one (step 3), which is
probably why one setup's runs give 55.5, 56.1 and 57.2ms: the method is good to about a
millisecond.

### Step 2: click templates and matching (display only)

Each tone's count-in clicks, from 2ms before their starts for 30ms, are averaged into a template
(averaging 4 copies halves uncorrelated noise). Each later click is searched for over ±15ms of its
prediction by normalized cross-correlation, `NCC(k) = Σ x[k+j]·t[j] / (‖x[k..k+L]‖·‖t‖)`, the
cosine between template and recording, so loudness doesn't matter. Coarsely (every 4 samples),
then finely. Skipped when a hit's sound is right on top of the click. A score ≥ 0.4 marks the
click as matched (the `*` for "predicted" in copied results, the faded click in the raster), and
**that's all it does now**.

It used to keep the click positions up to date (a median of the latest matches scoring ≥ 0.6).
That was removed because:

1. **A pure tone matches itself one cycle over.** Shifting a 30ms steady tone by one period
   (2.5ms at 400Hz) changes only its edges, so the correlation drops by just 5–10%, and noise or
   a hit's ringing can tip the best match a cycle either way. One recording's matches:
   58.0, 58.1, 60.5, 58.0, 63.1, 58.1, 55.6, … 52.8, whole cycles off. **A high correlation
   score says the shape matches, not that it's in the right place.**
2. **It fed back into itself.** The search window was centered on a prediction made from recent
   matches, so a few bad matches moved the window, which found more. In one run the matches
   drifted from about 98ms to 110–122ms (some 15–20ms off, onto hits' ringing, not just cycle
   slips) and dragged the system delay into a 10ms hump.
3. **Even good matches disagreed with step 1 by about 4ms.** Matching aligns the bulk of the
   waveform; step 1 marks where it first crosses a threshold. That's two definitions of a click's
   position, and swapping one for the other made the delay creep. (The exact makeup of the 4ms
   wasn't pinned down: beeps and boops cross their thresholds about 2ms apart, and only one pitch
   matched reliably.)

Clicks are scheduled on the audio engine's clock and come out sample-accurately; every recording
showed them not moving against their schedule. So K_c from the count-in serves the whole run.

If clicks ever did need tracking, the fix would be the sound, not the matching: a pure tone has
autocorrelation peaks every cycle. A sharp transient or a **chirp** (say 500Hz→4kHz over 20ms, as
radar and sonar use) has a single sharp peak and would match unambiguously to a fraction of a
millisecond. Calibration could play its own.

### Step 3: the hits

Goal: K_h, then every hit's sound, including hits right on top of clicks. (`_hearHits`,
`_bursts`, `_hitOnset`, `_highs`.)

#### 3a. Hearing the stick, not the clicks

A stick on a pad is a broadband crack, strong from a few kHz to past 10kHz; the clicks are pure
low tones. The second difference keeps one and drops the other:

```
y[n] = | x[n] − 2·x[n−1] + x[n−2] |,   smoothed by a 0.5ms moving average
```

Its gain is |1 − e^(−iω)|² = 4·sin²(ω/2). At 44.1kHz:

| Frequency | Gain | vs. Nyquist |
|---|---|---|
| 400Hz | 0.0032 | −62dB |
| 800Hz | 0.013 | −50dB |
| 5kHz | 0.49 | −18dB |
| 10kHz | 1.7 | −7dB |

The clicks all but vanish (a little leaks where a tone starts or stops, since abrupt edges are
broadband), which is why a hit on top of a click can still be found.

#### 3b. Placing hits the first time: voting

K_h is unknown at first (−50 to 500ms). For each hit waiting to be placed (the latest 12, at least
4), recorded far enough past it:

1. Find **bursts** in the high-frequency envelope from 50ms before its rough position to 550ms
   after: background = the 20th percentile, threshold = max(15% of the loudest, 8 × background),
   and a burst starts at a crossing after at least 5ms below threshold (so a hit's ringing isn't
   more hits).
2. Each burst votes for its delay (burst − rough position) in a 2ms bucket and the two neighbours
   (so a delay on a boundary isn't split). **Each hit votes at most once per bucket.**

Accept only if the best has **at least 4 votes and a majority** of the waiting hits; then take
**the shortest delay with at least max(4, best − 1) votes**. Seed the running list with each
waiting hit's burst nearest it, and K_h = their median.

Why "shortest within one vote": hits share the clicks' "one off" trap with no pitch to break it.
Hits come evenly, so the delay lining each hit up with the *next* hit's crack scores nearly as
well. One recording placed hits at 286ms instead of 43.7ms: with 3 hits waiting, one hit's own
crack was missed (a louder hit elsewhere in its 550ms window set the threshold), so the truth got
2 votes to the wrong delay's 3. The false delays are always the longer ones (the *previous* hit's
crack would give about −200ms, outside the range), so the shortest delay within one vote wins
even with one crack missed, and needing 4 hits leaves room for that.

"Once per bucket" and "the latest few" came from a bug: hits waiting to be placed were re-added on
every 100ms update, so "3 hits agree" could be one hit counted three times. That's how a live run
placed itself on a stray burst and found only 22 of 95 hits.

#### 3c. Finding each hit where it's expected

Each new hit's sound is expected at rough position + K_h; look only **±6ms** around it:

- background = the median of the envelope over the 15ms *before* the window,
- peak = the loudest from the window's start to 20ms past its end,
- accept if peak ≥ **2.5 ×** background; the start is the first sample **30% of the way from
  background to peak**.

The narrow window is justified by measurement: in real recordings a hit's sound lands within
0.7ms of where its MIDI time predicts. And it's what makes the low 2.5× bar safe (a stray burst
would have to fall in a 12ms window; the clicks don't register in this view). Lowering it from 8×
took one recording from 39 to 63 of 63 hits heard: the player's softer hand had been rising only
3–6× above the background. Measuring a fraction of the rise rather than a fixed level makes the
start independent of how hard the hit was; a stick's crack rises in well under a millisecond.

A hit found adds (start − rough position) to the latest 16, and K_h is their median. A hit not
found is placed where expected and flagged (`EarBeat.hitHeard`), shown faded in the grid.

**Starting over:** if 2 or fewer of the last 10 hits are heard where expected, K_h was wrong (or
something changed): drop it and vote afresh from the hits after.

#### 3d. Results

Per click: its position is rough position + K_c. The **in-air offset** is the start of the hit
nearest it within half a click, less that position. The **per-click system delay** is the MIDI
offset (MIDI time − scheduled time) less the in-air offset, which is exactly K_c − K_h per click,
so it shows whether the steadiness held.

`systemDelay()` sums them up: of a click's MIDI hits (a double trigger, say) it uses the one
agreeing best with the rest, sets aside clicks more than 4 × the median absolute deviation from
the median (floor 2ms), and reports the mean and standard deviation of the rest. That's the
calibration saved, "54.6ms ± 1.2ms". (`EarCheck.systemDelayMs` gives K_c − K_h directly.)

## The robustness principles

1. **Medians, not means.** A median ignores up to half its values being wrong; a mean moves with
   every bad one. K_c, K_h and all the backgrounds are medians or percentiles.
2. **Vote, don't take the first thing found.** When the pattern is known but its position isn't,
   let all the evidence vote. Two refinements: use whatever structure rules out wrong answers (the
   alternating pitch; for hits, that false answers are longer), and count each piece of evidence
   once.
3. **Learn each constant once, then look only where it predicts.** Both delays are physically
   steady. Narrow windows mean fewer false finds, fainter sounds can be accepted, and overlapping
   sounds stop mattering. The cost is depending on the constants really being constant, so that
   was checked against recordings first, and the per-click spread is shown so drift would be
   visible.
4. **Don't let an estimate set its own search window.** That loop is what made click matching
   walk off by 10–20ms.
5. **Thresholds relative to the signal.** To the background (and measured from where it really is
   background: the lopsided `findOnset` window), to the peak, and per tone. Never absolute.
6. **Trim outliers on a robust scale.** The MAD is about 0.67σ for normal data, so 4 × MAD is
   about 2.7σ; outliers can't inflate it the way they inflate a standard deviation. The floor
   stops it trimming honest clicks on a very clean run.
7. **Never fake a measurement, and check yourself.** Fallbacks are flagged as such (heard vs.
   assumed hits), and too many fallbacks trigger starting over. One run reported a spread of
   0.6ms that looked perfect, but 26 of 65 hits had silently fallen back to where they were
   expected, which agrees with the prediction exactly: the spread was measuring how often it
   *didn't* hear the hits.
8. **Test on real data, the way it runs live.** Every simulated test passed while real recordings
   failed three ways nobody had modelled (the 9th sound, evenly spaced hits, matches slipping).
   The replay test feeds recordings in 100ms at a time, as live, which is what exposed the
   bookkeeping bug.

### A stepped clock: keep the freshest reading

The audio clock (`AudioContext.currentTime`) only advances once per block of samples. Read
alongside `performance.now()` at arbitrary moments, the offset between them ranges from right
(just after a step) to a block late (just before the next). `ClockSync` keeps the **largest offset
seen over a window** (a monotonic deque, so it's O(1) amortized), which is the freshest reading.
It's used both to schedule clicks on SoLoud's engine clock and for the recorder's `frameAt`.
Logged runs show the recorder's mapping steady to under a millisecond over 15–20s. Reading
`currentTime` directly wobbled by up to a block between calls. Before that, `getOutputTimestamp`
was tried and found stale on an output-silent context (it mapped times to before the recording
started).

## Where it's still fragile

- **Playing during the listen row.** A hit has energy at 400 and 800Hz too. Voting tolerates a
  stray hit or two, but steady playing through the count-in could confuse it.
- **About ±1ms between runs**, from clicks' and hits' starts being defined differently. Fine for
  grading (the tightest window, Expert, is ±10ms perfect), but it's the method's floor.
- **The output's delay changing mid-run** (a Bluetooth headset renegotiating). K_c is fixed after
  the count-in, so the change wouldn't be followed; it would show as a large spread, so the run
  can be redone.
- **Headphones held to the microphone** haven't been tried since the rework, and **mobile**
  hasn't been tried at all: the recorder is web-only so far.
- The count-in's clicks must be heard: too quiet, or headphones away from the mic, and it stops
  with "Couldn't hear the clicks".

## Investigating a run

- **COPY RESULTS** (after a run) copies the summary, every hit's MIDI offset, every click's in-air
  offset (`*` where the click was predicted rather than matched), and the count-in's diagnosis:
  how many sounds were heard, how many clicks lined up, each tone's loudest level and background.
- **SAVE RECORDING** (debug builds, web) downloads the run as a WAV (32-bit float, `model/wav.dart`)
  with a `json` chunk after the samples (players skip it) holding:
  - `startFrame`, `bpm`, `intervalMs`, `countIn`, `clicksPerBeat`
  - `clicks`: index, scheduled time, rough frame (by the mapping at the end of the run), tone
  - `hits`: MIDI time, rough frame; `midiOffsets` by click
  - `beats`, `diagnosis`, `results`: what the check made of it
  - `arrivals`: for each block of samples received, `[performance.now(), audio clock ms, frame
    after the block]`, enough to rebuild the live time-to-frame mapping
  - `earLog`: the check's decisions as it went: each hit's rough frame, K_h then, and where its
    start was found (or null); each click's rough frame, K_c, K_h, match and in-air offset; when
    hits were placed (`placed`, with the delays it was placed from) or unplaced
- **Replaying:** `test/ear_check_recording_test.dart` runs `EarCheck` over every recording in
  `test/recordings/`, a tenth of a second at a time, with the saved rough frames as the mapping,
  and checks nearly every hit is heard, nothing had to start over, and the system delay is steady
  (spread under 2ms) and near the expected value. A new recording can go straight in; its reader
  takes 32-bit float or 16-bit (the ones in the repository are converted to 16-bit to halve their
  size, with no effect on the results).
- **Offline analysis:** the WAV's chunks are easy to read with Python's `struct` and numpy (RIFF
  chunks: `fmt `, `data`, `json`). Measuring each hit's sound against its rough frame
  independently of the app (the first sample above a threshold of the raw waveform, within a few
  ms of where it should be) is how the 0.7ms MIDI-to-sound jitter and the steadiness of the clicks
  were established.

## Reference figures (MacBook Pro 14", Chrome, KAT KTMP1 by stick)

| | |
|---|---|
| System delay, laptop speakers (three recordings) | 55.5, 56.1, 57.2ms; ±1.0–1.6ms per click |
| Between clicks, laptop speakers | about 55ms |
| Browser's own estimate (`outputLatency` + `baseLatency`), plus SoLoud's ~12ms buffer and ~2ms MIDI | about 48ms |
| Hit's sound vs. where its MIDI time predicts | within 0.7ms (standard deviation) |
| Clicks' position against their schedule over a run | steady to under 0.5ms |
| The player's lead in the air | 35–50ms ahead, varying within and between runs |
