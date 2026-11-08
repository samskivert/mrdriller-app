// Hears how a player's hits line up with the clicks they're playing along to, in the air: from a
// microphone recording of both, while they play. Nothing to do with the app's clocks or
// calibration, so it says what the player actually heard.
//
// The clicks of the count-in come first, with the player listening, not playing: those are found
// by their tones (each sound lined up with a click of its own tone, so not with the next click's),
// averaged into a clean copy of each kind of click (a template), and give how long after its
// rough position (its scheduled time, mapped roughly to a frame) a click is heard. That's steady,
// so each click after is taken to be there. (Matching later clicks against their templates only
// says whether they could be: a match can be off, by a cycle of its tone or onto something else,
// and once pulled the clicks off by 10ms or more.) Hits are found the same way: how long after its rough position (from
// its MIDI time) a hit's burst of high frequencies (which the clicks' pure tones don't have) is
// heard is steady too, learnt by lining up the first few hits with the bursts around them; then
// each hit's burst is looked for just there, so it's found even right on top of a click. Then each
// click's hit is how far from it the hit was, and the difference between the two delays is the
// system's delay (sound coming out, hits coming in), with the player's lead or lag left out.

import 'dart:math' as math;
import 'dart:typed_data';

import 'mic_calibration.dart';
import 'timing.dart';

/// One click (after the count-in), and how the player's hit on it went, in the air.
class EarBeat {
  /// Which click it was (counting the count-in's).
  final int index;

  /// Whether the click was found in the recording by matching its template (or else, with a hit
  /// right on top of it, or too faint to match, where it was predicted to be is used).
  final bool clickMatched;

  /// How far from the click the hit nearest it was, in milliseconds (negative if early), if there
  /// was one within half a click of it.
  final double? hitMs;

  /// Whether that hit's burst was heard (or, too faint or masked, it's where it was expected to
  /// be, from when it came in over MIDI).
  final bool hitHeard;

  /// The click's shape (as the count-in's clicks of its kind sounded, when nothing else was
  /// playing, so not mixed up with a hit's ringing) and the hit's high frequencies, from [halfMs]
  /// before the click to [halfMs] after (half a click either way), each in [EarCheck.bins] steps,
  /// from 0 to 1.
  final Float32List tone;
  final Float32List hit;
  final double halfMs;

  const EarBeat({
    required this.index,
    required this.clickMatched,
    required this.hitMs,
    this.hitHeard = true,
    required this.tone,
    required this.hit,
    required this.halfMs,
  });
}

enum EarCheckState {
  /// Waiting for the count-in to be recorded.
  listening,

  /// The count-in's clicks were found, and each click after it is being checked.
  checking,

  /// The count-in's clicks couldn't be heard (e.g. playing through headphones away from the mic).
  cantHear,
}

class EarCheck {
  /// How many clicks the count-in has (which the player listens to, not playing).
  final int countIn;

  /// How far apart the clicks are, in milliseconds.
  final double intervalMs;

  /// Each click's tone frequency, by its index (e.g. alternating beeps and boops).
  final double Function(int index) toneHz;

  final double sampleRate;

  /// How many steps a beat's [EarBeat.tone] and [EarBeat.hit] are drawn in.
  static const bins = 100;

  // The clicks' templates (by tone).
  final _templates = <double, Float32List>{};
  // Each kind of click's shape (as [EarBeat.tone] is), by tone.
  final _shapes = <double, Float32List>{};
  EarCheckState _state = EarCheckState.listening;
  final _beats = <EarBeat>[];
  int _next = 0;

  EarCheck({
    required this.countIn,
    required this.intervalMs,
    required this.toneHz,
    required this.sampleRate,
  });

  EarCheckState get state => _state;

  /// Which of the count-in's clicks were heard (by index), once it's been listened to.
  Set<int> get countInHeard => Set.unmodifiable(_countInHeard);
  final _countInHeard = <int>{};

  /// The beats checked so far, in order.
  List<EarBeat> get beats => List.unmodifiable(_beats);

  /// How far from their clicks the hits were, summed up.
  OffsetStats get stats => OffsetStats.of([for (final b in _beats) ?b.hitMs]);

  int _frames(double ms) => (ms * sampleRate / 1000).round();

  /// Checks whatever clicks (scheduled at [clicks], on the MIDI clock, in milliseconds) can be
  /// now, from the recording so far ([samples], whose first is the recorder's frame [startFrame]),
  /// with the [hits] played (when they came in over MIDI, on the same clock). [frameAt] gives the
  /// recorder's frame at a time on that clock, roughly (to within some tens of milliseconds).
  /// Returns whether any more beats were checked.
  bool update({
    required Float32List samples,
    required int startFrame,
    required List<double> clicks,
    required List<double> hits,
    required double Function(double ms) frameAt,
  }) {
    final recorded = startFrame + samples.length;
    int index(double frame) => (frame - startFrame).round();
    if (_state == EarCheckState.listening) {
      if (clicks.length < countIn) return false;
      // Once the whole count-in (and a little after) is recorded, find its clicks.
      final last = frameAt(clicks[countIn - 1]);
      if (last + _frames(_maxDelayMs + 100) > recorded) return false;
      _learnCountIn(samples, startFrame, clicks, frameAt);
      if (_state != EarCheckState.checking) return false;
      _next = countIn;
    }
    if (_state != EarCheckState.checking) return false;
    _hearHits(samples, startFrame, hits, frameAt);
    final hitDelay = _hitDelay;
    // Not until hits have been heard, to know where to find them.
    if (hitDelay == null) return false;
    var any = false;
    final half = intervalMs / 2;
    while (_next < clicks.length) {
      final predicted = frameAt(clicks[_next]) + _clickDelay;
      // Not until it's recorded to half a click after (and a little more, for the bursts of the
      // hits up to there to be found).
      if (predicted + _frames(half + _hitSearchMs + 50) > recorded) break;
      // The hits around it, where their sounds start: heard where expected (from when they came
      // in over MIDI), or if not, expected.
      // (Each with whether it was heard.)
      final heardOnsets = <(double, bool)>[
        for (final hit in hits)
          if (frameAt(hit) + hitDelay case final expected
              when (expected - predicted).abs() <= _frames(half + 20))
            (_heardHits[hit] ?? expected, _heardHits[hit] != null),
      ];
      final onsets = [for (final (onset, _) in heardOnsets) onset];
      // Where the click is: matched against its template, unless a hit's burst is on top of it
      // (whose loudness would pull the match off), when where it's expected (from the count-in
      // and the clean matches) is better.
      final overlapped = onsets.any(
        (o) => o > predicted - _frames(20) && o < predicted + _frames(_templateMs + 10),
      );
      // (A tone not heard in the count-in has no template, so isn't matched.)
      final template = _templates[toneHz(_next)];
      final match = overlapped || template == null
          ? null
          : _bestMatch(
              samples,
              template,
              index(predicted) - _frames(15),
              index(predicted) + _frames(15),
            );
      // (Only to show whether it was matched: where a click is comes from the count-in alone, as
      // clicks come out a steady time after they're scheduled, and a match can be off, a cycle of
      // its tone either side, or onto something else altogether.)
      final matched = match != null && match.$2 >= 0.4;
      final clickFrame = frameAt(clicks[_next]) + _clickDelay;
      // The hit nearest the click, if there's one within half a click of it.
      double? hitMs;
      var hitHeard = false;
      for (final (onset, heard) in heardOnsets) {
        final ms = (onset - clickFrame) * 1000 / sampleRate;
        if (ms.abs() <= half && (hitMs == null || ms.abs() < hitMs.abs())) {
          (hitMs, hitHeard) = (ms, heard);
        }
      }
      log.add({
        'click': _next,
        'rough': frameAt(clicks[_next]),
        'recorded': recorded,
        'clickDelay': _clickDelay,
        'hitDelay': hitDelay,
        'match': match == null ? null : [match.$1 + startFrame, match.$2],
        'hitMs': hitMs,
      });
      final from = index(clickFrame) - _frames(half);
      _beats.add(
        EarBeat(
          index: _next,
          clickMatched: matched,
          hitMs: hitMs,
          hitHeard: hitHeard,
          // (Or, for a tone not heard in the count-in, the other's.)
          tone: _shapes[toneHz(_next)] ?? _shapes.values.first,
          hit: _hitShape(samples, from, _frames(intervalMs)),
          halfMs: half,
        ),
      );
      _next++;
      any = true;
    }
    return any;
  }

  /// For working out what went wrong: what it worked out for each click and hit, as it went.
  final log = <Map<String, Object?>>[];

  // How many frames after a click's rough position ([frameAt] its scheduled time) it's heard,
  // from the latest clicks found (the count-in's, then clean matches).
  double _clickDelay = 0;
  final _clickDelays = <double>[];

  // The same for hits (after when they came in over MIDI), once enough have been heard to tell;
  // and each hit heard so far, by its MIDI time, where its sound starts (or null where it
  // couldn't be found).
  double? _hitDelay;
  final _hitDelays = <double>[];
  final _heardHits = <double, double?>{};
  // Each hit waiting to be placed, the bursts around it (see _hearHits).
  final _burstsByHit = <double, List<int>>{};

  static void _addDelay(List<double> delays, double delay) {
    delays.add(delay);
    if (delays.length > 16) delays.removeAt(0);
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// How long sound takes to come out, and hits to come in, in all (in milliseconds): how much
  /// later than they're scheduled the clicks are heard, less how much later than they come in
  /// over MIDI the hits are, so the rough mapping of times to frames cancels out. Null until
  /// hits have been heard.
  double? get systemDelayMs {
    final hitDelay = _hitDelay;
    return hitDelay == null ? null : (_clickDelay - hitDelay) * 1000 / sampleRate;
  }

  // Finds the sounds of the [hits] not yet heard, as far as they're recorded. A hit's sound comes
  // some unknown but steady time after its rough position, the same for all of them: until
  // that's known, it's the time that lines up the most hits with the bursts around them; then
  // each hit's burst is looked for just there.
  void _hearHits(
    Float32List samples,
    int startFrame,
    List<double> hits,
    double Function(double ms) frameAt,
  ) {
    final recorded = startFrame + samples.length;
    // (Recorded far enough after it to find its burst: anywhere it might be, until where is
    // known.)
    final after = _hitDelay == null
        ? _frames(_maxDelayMs + 30)
        : _hitDelay! + _frames(_hitSearchMs + 25);
    final ready = [
      for (final hit in hits)
        if (!_heardHits.containsKey(hit) && frameAt(hit) + after <= recorded) hit,
    ];
    if (_hitDelay == null) {
      // (The hits not yet heard, which until they're placed is all of them so far: the latest
      // few, so that if it has to start over, it's from how things are now.)
      final pending = ready.length > 12 ? ready.sublist(ready.length - 12) : ready;
      if (pending.length < _minHitsToPlace) return;
      final bucket = _frames(2);
      // Each hit's vote for each delay that lines it up with a burst (once per delay, however
      // many bursts there).
      final votes = <int, int>{};
      final candidates = <double, List<int>>{};
      for (final hit in pending) {
        final rough = frameAt(hit);
        final from = (rough - startFrame).round() - _frames(50);
        // (Found once for each hit, as it's waited on: looking afresh at every update, for every
        // hit waiting, stalled the app.)
        final bursts = _burstsByHit[hit] ??= _bursts(
          samples,
          from,
          from + _frames(_maxDelayMs + 50),
        );
        candidates[hit] = bursts;
        final keys = <int>{};
        for (final b in bursts) {
          final key = (b + startFrame - rough) ~/ bucket;
          keys.addAll([key - 1, key, key + 1]);
        }
        for (final key in keys) {
          votes.update(key, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      // The delay lining up the most hits with bursts, if enough do, and most of them. (Or a
      // shorter one lining up almost as many: as the hits come evenly, lining each up with the
      // next one's burst does nearly as well, and a hit's own burst can be missed.)
      if (votes.isEmpty) return;
      final most = votes.values.reduce(math.max);
      if (most < _minHitsToPlace || most * 2 < pending.length + 1) return;
      final best = votes.entries
          .where((e) => e.value >= math.max(_minHitsToPlace, most - 1))
          .reduce((a, b) => b.key < a.key ? b : a);
      final center = (best.key + 0.5) * bucket;
      _hitDelays.clear();
      for (final hit in pending) {
        final rough = frameAt(hit);
        final near = candidates[hit]!
            .map((b) => b + startFrame - rough)
            .where((d) => (d - center).abs() <= bucket * 2);
        if (near.isNotEmpty) _addDelay(_hitDelays, near.first);
      }
      if (_hitDelays.isEmpty) return;
      _hitDelay = _median(_hitDelays);
      log.add({
        'placed': _hitDelay,
        'from': [..._hitDelays],
        'hits': pending,
      });
      _recentlyHeard.clear();
    }
    for (final hit in ready) {
      final expected = frameAt(hit) + _hitDelay!;
      final at = (expected - startFrame).round();
      final onset = _hitOnset(samples, at - _frames(_hitSearchMs), at + _frames(_hitSearchMs));
      _heardHits[hit] = onset == null ? null : (onset + startFrame).toDouble();
      log.add({
        'hit': hit,
        'rough': frameAt(hit),
        'recorded': recorded,
        'hitDelay': _hitDelay,
        'onset': _heardHits[hit],
      });
      if (onset != null) {
        _addDelay(_hitDelays, onset + startFrame - frameAt(hit));
        _hitDelay = _median(_hitDelays);
      }
      // If hardly any of the latest hits are heard where they're expected, where that is must
      // have been placed wrong (or changed): starting over, from the hits since.
      _recentlyHeard.add(onset != null);
      if (_recentlyHeard.length > 10) _recentlyHeard.removeAt(0);
      if (_recentlyHeard.length == 10 && _recentlyHeard.where((h) => h).length <= 2) {
        log.add({'unplaced': _hitDelay});
        _hitDelay = null;
        _hitDelays.clear();
        _recentlyHeard.clear();
        return;
      }
    }
  }

  // Whether each of the latest hits looked for was heard where expected.
  final _recentlyHeard = <bool>[];

  static const _minHitsToPlace = 4;

  // How far from where it's expected a hit's sound is looked for.
  static const _hitSearchMs = 6.0;

  // The longest a click may take to come out and be recorded, after its rough position.
  static const _maxDelayMs = 500.0;

  /// How the count-in went, in a line, for working out what went wrong if it couldn't hear it.
  String? diagnosis;
  String _levels = '';

  // Where each click-like sound starts in [samples] from [from] to [to]: each time the content at
  // one of the clicks' tones ([tones]) rises well above that tone's background (after it's been
  // quiet a while). (By their tones, rather than how loud it is in all, which room noise, spread
  // over every frequency, mostly isn't loud in; and each tone on its own terms, as speakers may
  // play one much more quietly than the other, as small ones do low notes.) Each with the tones
  // it was heard at.
  List<(int, Set<double>)> _sounds(Float32List samples, int from, int to, Iterable<double> tones) {
    from = math.max(0, from);
    to = math.min(samples.length, to);
    final step = _frames(1);
    final window = _frames(5);
    final count = (to - from - window) ~/ step;
    if (count <= 0) return const [];
    final quiet = (intervalMs * 0.5).round();
    final found = <(int, double)>[];
    final levelNotes = <String>[];
    for (final hz in tones) {
      final levels = Float32List(count);
      // Each window's content at the tone, |Σ x[n]·e^(−iωn)|, from running sums of x[n]·cos(ωn)
      // and x[n]·sin(ωn): one window's is the difference of two, so each sample is multiplied once,
      // not once for every window it's in. (The phase is measured from the stretch's start rather
      // than each window's, which doesn't change the size.)
      final w = 2 * math.pi * hz / sampleRate;
      // (Keeping the running sums only where windows start and end.)
      final length = (count - 1) * step + window;
      final startRe = Float64List(count), startIm = Float64List(count);
      final endRe = Float64List(count), endIm = Float64List(count);
      // (Rotating by ω each sample, rather than calling cos and sin for each.)
      final cw = math.cos(w), sw = math.sin(w);
      var c = 1.0, sn = 0.0, re = 0.0, im = 0.0;
      for (var j = 0; j <= length; j++) {
        if (j % step == 0 && j ~/ step < count) {
          startRe[j ~/ step] = re;
          startIm[j ~/ step] = im;
        }
        if (j >= window && (j - window) % step == 0) {
          endRe[(j - window) ~/ step] = re;
          endIm[(j - window) ~/ step] = im;
        }
        if (j == length) break;
        final x = samples[from + j];
        re += x * c;
        im -= x * sn;
        final next = c * cw - sn * sw;
        sn = sn * cw + c * sw;
        c = next;
      }
      for (var k = 0; k < count; k++) {
        final dr = endRe[k] - startRe[k], di = endIm[k] - startIm[k];
        levels[k] = math.sqrt(dr * dr + di * di) / window;
      }
      final sorted = Float32List.fromList(levels)..sort();
      // (The quietest stretches', so the clicks themselves don't count as background.)
      final background = sorted[sorted.length ~/ 5];
      final loudest = sorted.last;
      levelNotes.add(
        '${hz.round()}Hz loudest ${loudest.toStringAsFixed(4)}, '
        'background ${background.toStringAsFixed(4)}',
      );
      final threshold = math.max(background * 5, loudest * 0.2);
      var lastAbove = -quiet;
      for (var k = 0; k < count; k++) {
        if (levels[k] < threshold) continue;
        // (The window's start, as that's where its content first comes from.)
        if (k - lastAbove >= quiet) found.add((from + k * step, hz));
        lastAbove = k;
      }
    }
    _levels = levelNotes.join('; ');
    found.sort((a, b) => a.$1.compareTo(b.$1));
    // One sound heard at both tones counts once.
    final sounds = <(int, Set<double>)>[];
    for (final (frame, hz) in found) {
      if (sounds.isEmpty || frame - sounds.last.$1 >= _frames(quiet.toDouble())) {
        sounds.add((frame, {hz}));
      } else {
        sounds.last.$2.add(hz);
      }
    }
    return sounds;
  }

  // Templates start this long before their clicks' onsets.
  static const _templateLeadMs = 2.0;
  static const _templateMs = 30.0;

  void _learnCountIn(
    Float32List samples,
    int startFrame,
    List<double> clicks,
    double Function(double ms) frameAt,
  ) {
    // Every sound in the count-in's stretch (only its clicks, with the player listening), each
    // click coming out some unknown time (up to [_maxDelayMs]) after its rough position...
    final rough = [for (final t in clicks.take(countIn)) (frameAt(t) - startFrame).round()];
    final tones = {for (var i = 0; i < countIn; i++) toneHz(i)};
    final sounds = _sounds(
      samples,
      rough.first - _frames(50),
      rough.last + _frames(_maxDelayMs),
      tones,
    );
    // ...the same time for all of them, so it's the delay that lines up the most of them with the
    // clicks of their tones. (By tone, as with alternating tones, lining each click up with the
    // next one's sound would do almost as well otherwise; and the shortest delay of any that do as
    // well, as with one tone, it would.)
    final votes = <int, int>{};
    for (final (i, r) in rough.indexed) {
      for (final (sound, heardAt) in sounds) {
        if (!heardAt.contains(toneHz(i))) continue;
        final delay = sound - r;
        if (delay < -_frames(50) || delay > _frames(_maxDelayMs)) continue;
        final bucket = delay ~/ _frames(5);
        votes.update(bucket, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final onsets = <(double, int)>[];
    if (votes.isNotEmpty) {
      final best = votes.entries
          .reduce((a, b) => b.value > a.value || (b.value == a.value && b.key < a.key) ? b : a)
          .key;
      final delay = best * _frames(5) + _frames(2.5);
      for (final (i, r) in rough.indexed) {
        final near = [
          for (final (s, heardAt) in sounds)
            if (heardAt.contains(toneHz(i)) && (s - (r + delay)).abs() <= _frames(15)) s,
        ];
        if (near.isEmpty) continue;
        // Precisely, where it rises out of the background, in the clean stretch around it (with
        // more of the quiet before it than of it, for the background to be the quiet).
        final exact = findOnset(samples, near.first - _frames(30), near.first + _frames(15));
        onsets.add((clicks[i], exact?.index.round() ?? near.first));
        _countInHeard.add(i);
      }
    }
    diagnosis =
        'Count-in: heard ${sounds.length} sounds, ${onsets.length} of $countIn clicks lined up '
        '($_levels); '
        'recorded ${(samples.length / sampleRate).toStringAsFixed(2)}s from frame $startFrame, '
        'the count-in looked for from ${(rough.first / sampleRate).toStringAsFixed(2)}s to '
        '${(rough.last / sampleRate).toStringAsFixed(2)}s into it';
    // Enough of the count-in to go by. Not necessarily every tone: through headphones held to the
    // microphone, say, the low one may not come through at all. (With one tone, lining a click up
    // with a later click's sound means one two clicks on, at the edge of the delays allowed, and
    // the shortest delay wins a tie.)
    if (onsets.length < math.min(3, countIn)) {
      _state = EarCheckState.cantHear;
      return;
    }
    // Each kind of click's template: its count-in clicks, averaged.
    final length = _frames(_templateMs);
    final byTone = <double, List<Float32List>>{};
    for (var i = 0; i < countIn; i++) {
      final found = onsets.where((o) => o.$1 == clicks[i]).firstOrNull;
      if (found == null) continue;
      final from = found.$2 - _frames(_templateLeadMs);
      if (from < 0 || from + length > samples.length) continue;
      byTone
          .putIfAbsent(toneHz(i), () => [])
          .add(Float32List.sublistView(samples, from, from + length));
    }
    for (final MapEntry(key: hz, value: copies) in byTone.entries) {
      final template = Float32List(length);
      for (final copy in copies) {
        for (var j = 0; j < length; j++) {
          template[j] += copy[j] / copies.length;
        }
      }
      _templates[hz] = template;
    }
    if (_templates.isEmpty) {
      _state = EarCheckState.cantHear;
      return;
    }
    for (final (time, onset) in onsets) {
      _addDelay(_clickDelays, onset + startFrame - frameAt(time));
    }
    _clickDelay = _median(_clickDelays);
    // Each kind of click's shape: its count-in clicks' tones, averaged.
    final half = _frames(intervalMs / 2);
    final shapeSums = <double, Float32List>{};
    final shapeCounts = <double, int>{};
    for (var i = 0; i < countIn; i++) {
      final found = onsets.where((o) => o.$1 == clicks[i]).firstOrNull;
      if (found == null) continue;
      final hz = toneHz(i);
      final shape = _toneShape(samples, found.$2 - half, _frames(intervalMs), hz);
      final sum = shapeSums.putIfAbsent(hz, () => Float32List(bins));
      for (var b = 0; b < bins; b++) {
        sum[b] += shape[b];
      }
      shapeCounts.update(hz, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final MapEntry(key: hz, value: sum) in shapeSums.entries) {
      // (Before the click is silence, whatever the recording had there.)
      for (var b = 0; b < bins ~/ 2; b++) {
        sum[b] = 0;
      }
      _shapes[hz] = _normalized(sum);
    }
    if (!_templates.keys.every(_shapes.containsKey)) {
      _state = EarCheckState.cantHear;
      return;
    }
    _state = EarCheckState.checking;
  }

  /// Where [template] best matches [samples], starting between [from] and [to], and how well (its
  /// normalized correlation, from -1 to 1), or null if that's out of the recording. Coarsely
  /// first, then finely around the best.
  static (int, double)? _bestMatch(Float32List samples, Float32List template, int from, int to) {
    from = math.max(0, from);
    to = math.min(samples.length - template.length, to);
    if (to < from) return null;
    var templateNorm = 0.0;
    for (final v in template) {
      templateNorm += v * v;
    }
    templateNorm = math.sqrt(templateNorm);
    if (templateNorm == 0) return null;
    double correlation(int at) {
      var dot = 0.0, energy = 0.0;
      for (var j = 0; j < template.length; j++) {
        final s = samples[at + j];
        dot += s * template[j];
        energy += s * s;
      }
      return energy == 0 ? 0 : dot / (math.sqrt(energy) * templateNorm);
    }

    const coarse = 4;
    var best = from;
    var bestScore = -2.0;
    for (var at = from; at <= to; at += coarse) {
      final score = correlation(at);
      if (score > bestScore) (best, bestScore) = (at, score);
    }
    for (var at = math.max(from, best - coarse); at <= math.min(to, best + coarse); at++) {
      final score = correlation(at);
      if (score > bestScore) (best, bestScore) = (at, score);
    }
    return (best, bestScore);
  }

  // A hit's high frequencies: the size of the recording's second difference (which all but
  // silences a click's low, pure tone), smoothed over half a millisecond.
  Float32List _highs(Float32List samples, int from, int to) {
    from = math.max(2, from);
    to = math.min(samples.length, to);
    final smooth = math.max(1, _frames(0.5));
    final out = Float32List(math.max(0, to - from));
    var sum = 0.0;
    final raw = Float32List(out.length);
    for (var i = 0; i < out.length; i++) {
      final n = from + i;
      raw[i] = (samples[n] - 2 * samples[n - 1] + samples[n - 2]).abs();
      sum += raw[i];
      if (i >= smooth) sum -= raw[i - smooth];
      out[i] = sum / smooth;
    }
    return out;
  }

  /// Where each burst of high frequencies (a hit's) starts in [samples] between [from] and [to]:
  /// each sharp rise, after a few milliseconds of quiet (so the ringing of a hit before doesn't
  /// count), judged against the quietest part of the stretch.
  List<int> _bursts(Float32List samples, int from, int to) {
    from = math.max(2, from);
    final highs = _highs(samples, from, to);
    if (highs.length < 64) return const [];
    // (The background from every eighth value, which is plenty to tell it by: sorting them all,
    // for each of a dozen hits at once, stalled the app.)
    final sorted = Float32List.fromList([for (var i = 0; i < highs.length; i += 8) highs[i]])
      ..sort();
    final background = sorted[sorted.length ~/ 5];
    final peak = highs.fold(0.0, (m, v) => math.max(m, v));
    if (peak < background * 15 || peak < 1e-4) return const [];
    final threshold = math.max(peak * 0.15, background * 8);
    final quiet = _frames(5);
    final found = <int>[];
    var below = quiet;
    for (var i = 0; i < highs.length; i++) {
      if (highs[i] < threshold) {
        below++;
        continue;
      }
      if (below >= quiet) found.add(from + i);
      below = 0;
    }
    return found;
  }

  /// Where a hit's burst starts in [samples] between [from] and [to], if one does: where the high
  /// frequencies first rise 30% of the way from the background just before to the loudest they
  /// get shortly after, if that's clearly above the background.
  int? _hitOnset(Float32List samples, int from, int to) {
    from = math.max(2, from);
    final before = _highs(samples, from - _frames(15), from);
    final highs = _highs(samples, from, to + _frames(20));
    if (highs.length <= to - from || before.isEmpty) return null;
    final sorted = Float32List.fromList(before)..sort();
    final background = sorted[sorted.length ~/ 2];
    final peak = highs.fold(0.0, (m, v) => math.max(m, v));
    // (Even a faint burst, as it's only looked for just where a hit is expected.)
    if (peak < background * 2.5 || peak < 1e-4) return null;
    final threshold = background + (peak - background) * 0.3;
    for (var i = 0; i <= to - from; i++) {
      if (highs[i] >= threshold) return from + i;
    }
    return null;
  }

  // The click's tone over [length] samples from [from], in [bins] steps: its content at [hz].
  Float32List _toneShape(Float32List samples, int from, int length, double hz) {
    final out = Float32List(bins);
    final window = _frames(5);
    final w = 2 * math.pi * hz / sampleRate;
    // (Rotating by ω each sample rather than calling cos and sin for each; the phase each window
    // starts at doesn't change the size.)
    final cw = math.cos(w), sw = math.sin(w);
    for (var b = 0; b < bins; b++) {
      final center = from + (b + 0.5) * length ~/ bins;
      var re = 0.0, im = 0.0, c = 1.0, sn = 0.0;
      for (var j = -window ~/ 2; j < window ~/ 2; j++) {
        final n = center + j;
        if (n >= 0 && n < samples.length) {
          re += samples[n] * c;
          im -= samples[n] * sn;
        }
        final next = c * cw - sn * sw;
        sn = sn * cw + c * sw;
        c = next;
      }
      out[b] = math.sqrt(re * re + im * im);
    }
    return _normalized(out);
  }

  // The hit's high frequencies over [length] samples from [from], in [bins] steps (each's
  // loudest).
  Float32List _hitShape(Float32List samples, int from, int length) {
    final highs = _highs(samples, from, from + length);
    final out = Float32List(bins);
    final offset = math.max(2, from) - from;
    for (var i = 0; i < highs.length; i++) {
      final b = ((i + offset) * bins ~/ length).clamp(0, bins - 1);
      out[b] = math.max(out[b], highs[i]);
    }
    return _normalized(out);
  }

  static Float32List _normalized(Float32List values) {
    final peak = values.fold(0.0, (m, v) => math.max(m, v));
    if (peak > 0) {
      for (var i = 0; i < values.length; i++) {
        values[i] /= peak;
      }
    }
    return values;
  }
}

/// Everything between a click being scheduled and a hit on it reaching the app, apart from the
/// player (the sound's delay in coming out, and the hit's in coming in): what hits need adjusting
/// by, as a calibration. It's measured from [beats] heard in the air and the MIDI hits' offsets
/// from when each click was scheduled ([midiOffsets], by click index): for each click with both,
/// the MIDI offset less the in-air one, so the player's own lead or lag cancels out. (Of a click's
/// MIDI hits, the one agreeing best with the rest is used, and clicks far off from the rest, whose
/// hit heard wasn't the one played, are left out.)
OffsetStats systemDelay(List<EarBeat> beats, Map<int, List<double>> midiOffsets) {
  double median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  final candidates = <List<double>>[
    for (final beat in beats)
      if ((beat.hitMs, midiOffsets[beat.index]) case (
        final heard?,
        final offsets?,
      ) when offsets.isNotEmpty)
        [for (final offset in offsets) offset - heard],
  ];
  if (candidates.isEmpty) return OffsetStats.empty;
  // Roughly, from the clicks with only one MIDI hit (or all, if none do).
  final single = [
    for (final c in candidates)
      if (c.length == 1) c.single,
  ];
  final rough = median(single.length >= 3 ? single : candidates.expand((c) => c).toList());
  final delays = [
    for (final c in candidates) c.reduce((a, b) => (a - rough).abs() <= (b - rough).abs() ? a : b),
  ];
  final middle = median(delays);
  final deviation = math.max(2.0, median([for (final d in delays) (d - middle).abs()]));
  return OffsetStats.of(delays.where((d) => (d - middle).abs() <= 4 * deviation));
}
