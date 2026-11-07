import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../model/timing.dart';
import '../services/metronome_sounds.dart';
import '../services/audio_latency.dart';
import '../services/mic_recorder.dart';
import '../services/midi_input.dart';
import '../util/colors.dart';
import 'arcade.dart';
import 'hud_controls.dart';

/// A test of hitting in time with a click: plays a steady click and measures how early or late
/// each hit on the MIDI pad is.
///
/// The beats are laid out on the MIDI input's clock (the one hits are timestamped with), and each
/// hit is compared with its nearest beat on that ideal schedule. So the average offset includes
/// everything between a beat being due and the player hearing it: the audio engine's buffering,
/// the OS and the speakers (and, if clicks are played rather than scheduled, the app getting round
/// to playing them). That average (less any tendency of the player to rush or drag) is what hit
/// timing will need to be calibrated by. How widely the offsets spread around it is how steady
/// the player is.
///
/// Clicks are either scheduled ahead on the audio engine's clock, which plays them exactly on
/// time however busy the app is, or (to compare) played when a poll finds them due, which is what
/// the metronome does, and is late whenever the main thread is busy.
class MidiTimingTest extends StatefulWidget {
  /// The messages to count hits from (its note ons).
  final Stream<MidiMessage> hits;

  /// The current time on the clock that [hits] are timestamped with, in milliseconds.
  final double Function() now;

  /// The calibration that hits are adjusted by (see Calibration), if any, in milliseconds, and
  /// what it's for, to say so.
  final double? calibrationMs;
  final String? calibrationLabel;

  /// Saves a calibration from a test's (unadjusted) hits, at a tempo. Without it, there's no way
  /// to save one.
  final void Function(OffsetStats hits, int bpm)? onSave;

  const MidiTimingTest({
    super.key,
    required this.hits,
    required this.now,
    this.calibrationMs,
    this.calibrationLabel,
    this.onSave,
  });

  @override
  State<MidiTimingTest> createState() => _MidiTimingTestState();
}

class _MidiTimingTestState extends State<MidiTimingTest> {
  static const _tempos = [60, 90, 120, 150];
  static const _beatsPerMeasure = 4;
  // Clicks come twice a beat (on it, and halfway to the next), which is easier to keep time with
  // than once. The grid is of clicks, not beats.
  static const _clicksPerBeat = 2;
  // A measure of clicks to settle into the beat, whose hits don't count.
  static const _countInClicks = _beatsPerMeasure * _clicksPerBeat;
  static const _shownHits = 40;
  static const _pollInterval = Duration(milliseconds: 2);
  // Before the first click, after starting.
  static const _leadInMs = 600.0;
  // How far ahead clicks are scheduled. The main thread would have to stall for longer than this
  // for one to be late.
  static const _lookaheadMs = 400.0;
  // A scheduled click that's due longer ago than this is skipped rather than played late.
  static const _tooLateMs = 20.0;
  // Hits closer together than this are one hit, retriggering (or setting off another pad).
  static const _doubleTriggerMs = 30.0;
  // Fewer hits than this aren't enough to calibrate by.
  static const _minCalibrationHits = 16;

  int _bpm = 90;
  bool _scheduled = true;
  MetronomeSounds? _sounds;
  StreamSubscription<MidiMessage>? _messages;
  Timer? _poll;
  bool _starting = false;
  final _clockSync = ClockSync();
  // While it's playing.
  BeatGrid? _grid;
  // The next beat to schedule or play.
  int _nextBeat = 0;
  // The beat that's sounded most recently, for the count-in (-1 before the first).
  int _shownBeat = -1;
  // Scheduled clicks that may not have played yet: when they're due, and their handles.
  final _pending = <(double, SoundHandle)>[];
  double? _lastHitAt;

  // Since it last started, with these settings: each hit's offset and the beat it was nearest,
  // the hits ignored as double triggers, and for each click, how far ahead it was scheduled or
  // how late it was played.
  int _testedBpm = 0;
  bool _testedScheduled = true;
  final _offsets = <double>[];
  final _hitBeats = <int>[];
  int _doubleTriggers = 0;
  final _clickTiming = <double>[];

  bool get _running => _starting || _grid != null;

  // To check whether recording the microphone (as the microphone calibration does) changes how
  // long sound takes to come out: the microphone recording (into nothing) while switched on, and
  // the browser's estimates of the output delay, as last checked.
  MicRecorder? _mic;
  var _micOpening = false;
  String? _micError;
  AudioLatency? _latency;
  var _checkedLatency = false;

  Future<void> _setMicOpen(bool open) async {
    if (!open) {
      _mic?.close();
      setState(() => _mic = null);
      return;
    }
    setState(() {
      _micOpening = true;
      _micError = null;
    });
    try {
      final mic = await MicRecorder.open();
      if (!mounted) return mic.close();
      setState(() => _mic = mic);
    } on MicUnavailable catch (e) {
      if (mounted) setState(() => _micError = e.message);
    } finally {
      if (mounted) setState(() => _micOpening = false);
    }
  }

  Future<void> _checkLatency() async {
    final latency = await browserAudioLatency();
    if (mounted) {
      setState(() {
        _latency = latency;
        _checkedLatency = true;
      });
    }
  }

  // The hits' offsets, adjusted by the calibration.
  List<double> get _adjusted {
    final calibration = widget.calibrationMs;
    return calibration == null ? _offsets : [for (final o in _offsets) o - calibration];
  }

  void _save() {
    widget.onSave?.call(OffsetStats.of(_offsets), _testedBpm);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved the calibration'), duration: Duration(seconds: 2)),
    );
  }

  @override
  void initState() {
    super.initState();
    _messages = widget.hits.listen(_onMessage);
  }

  @override
  void dispose() {
    _mic?.close();
    _poll?.cancel();
    _messages?.cancel();
    _cancelPending();
    _sounds?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final sounds = _sounds ??= MetronomeSounds();
    await sounds.start();
    if (!mounted || !_starting) return;
    setState(() {
      _starting = false;
      _restartGrid();
    });
    _poll = Timer.periodic(_pollInterval, (_) => _tick());
  }

  void _stop() {
    setState(() {
      _starting = false;
      _grid = null;
    });
    _poll?.cancel();
    _poll = null;
    _cancelPending();
    _sounds?.pause();
  }

  // Starts counting in afresh, with the current settings.
  void _restartGrid() {
    _cancelPending();
    _grid = BeatGrid(start: widget.now() + _leadInMs, interval: 60000 / _bpm / _clicksPerBeat);
    _nextBeat = 0;
    _shownBeat = -1;
    _lastHitAt = null;
    _testedBpm = _bpm;
    _testedScheduled = _scheduled;
    _offsets.clear();
    _hitBeats.clear();
    _doubleTriggers = 0;
    _clickTiming.clear();
  }

  void _cancelPending() {
    for (final (_, handle) in _pending) {
      _sounds?.cancel(handle);
    }
    _pending.clear();
  }

  void _setBpm(int bpm) {
    setState(() {
      _bpm = bpm;
      if (_grid != null) _restartGrid();
    });
  }

  void _setScheduled(bool scheduled) {
    setState(() {
      _scheduled = scheduled;
      if (_grid != null) _restartGrid();
    });
  }

  void _tick() {
    final grid = _grid;
    final sounds = _sounds;
    if (grid == null || sounds == null) return;
    final now = widget.now();
    final engineTime = sounds.engineTime();
    if (engineTime != null) _clockSync.sample(now, engineTime.inMicroseconds / 1000);
    if (_testedScheduled) {
      _scheduleClicks(grid, sounds, now);
    } else {
      _playDueClick(grid, sounds, now);
    }
    final current = ((now - grid.start) / grid.interval).floor();
    if (current != _shownBeat) setState(() => _shownBeat = current);
  }

  // Schedules every click that's due within the lookahead.
  void _scheduleClicks(BeatGrid grid, MetronomeSounds sounds, double now) {
    _pending.removeWhere((pending) => pending.$1 < now - 1000);
    while (grid.timeOf(_nextBeat) <= now + _lookaheadMs) {
      final time = grid.timeOf(_nextBeat);
      final at = _clockSync.toStepped(time);
      if (at == null) return;
      if (time >= now - _tooLateMs) {
        final atTime = Duration(microseconds: (at * 1000).round());
        // A beep on the beat, and a boop between.
        final handle = _nextBeat % _clicksPerBeat == 0
            ? sounds.scheduleBeep(atTime)
            : sounds.scheduleBoop(atTime);
        if (handle != null) _pending.add((time, handle));
      }
      _clickTiming.add(time - now);
      _nextBeat++;
    }
  }

  // Plays the latest click that's due, now, if there is one.
  void _playDueClick(BeatGrid grid, MetronomeSounds sounds, double now) {
    if (now < grid.timeOf(_nextBeat)) return;
    // If it's somehow fallen more than a beat behind, skip to the latest beat that's due.
    var beat = _nextBeat;
    while (grid.timeOf(beat + 1) <= now) {
      beat++;
    }
    if (beat % _clicksPerBeat == 0) {
      sounds.playBeep();
    } else {
      sounds.playBoop();
    }
    _clickTiming.add(now - grid.timeOf(beat));
    _nextBeat = beat + 1;
  }

  void _onMessage(MidiMessage message) {
    final grid = _grid;
    if (grid == null || !message.isNoteOn) return;
    final last = _lastHitAt;
    if (last != null && message.timestamp - last < _doubleTriggerMs) {
      setState(() => _doubleTriggers++);
      return;
    }
    _lastHitAt = message.timestamp;
    final beat = grid.nearestBeat(message.timestamp);
    if (beat < _countInClicks) return;
    setState(() {
      _offsets.add(grid.offsetOf(message.timestamp));
      _hitBeats.add(beat);
    });
  }

  Future<void> _copyResults() async {
    await Clipboard.setData(ClipboardData(text: _results()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied the results'), duration: Duration(seconds: 2)),
    );
  }

  // The browser's estimates of the output delay, as last checked, in a sentence.
  String _latencyText() {
    if (!_checkedLatency) return "The browser's estimate of the output delay: not checked yet.";
    final latency = _latency;
    if (latency == null) return "The browser couldn't estimate the output delay.";
    return "The browser's estimate of the output delay: ${_ms(latency.output)}, plus "
        '${_ms(latency.base)} of its own buffering.';
  }

  // How the clicks went, in a sentence.
  String _clickSummary() {
    final timing = OffsetStats.of(_clickTiming);
    if (_testedScheduled) {
      final least = _clickTiming.reduce(math.min);
      final late = _clickTiming.where((t) => t < 0).length;
      return 'The clicks were scheduled at least ${_ms(least)} ahead'
          '${late == 0 ? '' : ', but $late were scheduled after they were due'}.';
    }
    return 'The clicks were played ${_ms(timing.mean)} late on average (worst '
        '${_ms(timing.worst)}).';
  }

  // The results in full, as text to paste elsewhere.
  String _results() {
    final stats = OffsetStats.of(_offsets);
    String list(Iterable<double> values) => values.map((v) => v.toStringAsFixed(1)).join(', ');
    return [
      'Timing test at $_testedBpm bpm, clicks ${_testedScheduled ? 'scheduled' : 'played now'}, '
          'microphone ${_mic == null ? 'closed' : 'open'} '
          '($_clicksPerBeat clicks a beat; count-in of $_countInClicks clicks not counted)',
      if (_latency case final latency?)
        "Browser's output delay estimate: ${_ms(latency.output)} + ${_ms(latency.base)} buffering",
      'Hits: ${stats.count}, average ${_ms(stats.mean)}, spread ${_ms(stats.spread)}, '
          'worst ${_ms(stats.worst)} (negative is early); $_doubleTriggers double triggers '
          'ignored',
      if (widget.calibrationMs case final calibration?)
        'Adjusted by a calibration of ${_ms(calibration)}: average '
            '${_ms(OffsetStats.of(_adjusted).mean)}',
      _clickSummary(),
      'Hit offsets by beat, unadjusted (beat: ms):',
      [
        for (var i = 0; i < _offsets.length; i++)
          '${_hitBeats[i]}: ${_offsets[i].toStringAsFixed(1)}',
      ].join(', '),
      _testedScheduled
          ? 'How far ahead each click was scheduled, from beat 0 (ms):'
          : 'How late each click was played, from beat 0 (ms):',
      list(_clickTiming),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final adjusted = _adjusted;
    final stats = OffsetStats.of(adjusted);
    final calibration = widget.calibrationMs;
    final countingIn = _grid != null && _shownBeat < _countInClicks;
    return BannerCard(
      label: 'Timing test',
      color: AppColors.bannerRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Text(
            'Play along with the clicks, twice a beat: a high one on the beat, and a low one '
            'between. After a measure to count in, each hit is compared with its nearest click.',
          ),
          const SizedBox(height: 12),
          CandySegmented<int>(
            options: [for (final bpm in _tempos) (bpm, '$bpm bpm')],
            value: _bpm,
            onChanged: _setBpm,
            colors: AppColors.candyPink,
          ),
          const SizedBox(height: 8),
          CandySegmented<bool>(
            options: const [(true, 'Scheduled clicks'), (false, 'Play clicks now')],
            value: _scheduled,
            onChanged: _setScheduled,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: _Text('Microphone open', strong: true)),
              CandySwitch(
                value: _mic != null,
                onChanged: (open) => _micOpening ? null : _setMicOpen(open),
              ),
            ],
          ),
          if (_micError case final error?) _Text(error),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _Text(_latencyText())),
              const SizedBox(width: 10),
              CandyButton(
                label: 'CHECK',
                colors: AppColors.candyBlue,
                height: 36,
                fontSize: 13,
                onPressed: _checkLatency,
              ),
            ],
          ),
          const SizedBox(height: 12),
          CandyButton(
            label: _running ? 'STOP' : 'START',
            icon: _running ? Icons.stop_rounded : Icons.play_arrow_rounded,
            colors: _running ? AppColors.candyRed : AppColors.candyGreen,
            onPressed: _starting ? null : (_running ? _stop : _start),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: Center(
              child: countingIn
                  ? _Readout(
                      // (By beat, though it counts clicks.)
                      _shownBeat < 0 ? 'Ready...' : 'Count in: ${_shownBeat ~/ _clicksPerBeat + 1}',
                      AppColors.candyBlue,
                    )
                  : _offsets.isEmpty
                  ? const SizedBox.shrink()
                  : _Readout(_describe(adjusted.last), AppColors.candyOrange),
            ),
          ),
          const SizedBox(height: 8),
          RepaintBoundary(
            child: _OffsetStrip(
              // A copy (sublist always is), so that the painter sees that it changed.
              offsets: adjusted.sublist(math.max(0, adjusted.length - _shownHits)),
              mean: stats.count == 0 ? null : stats.mean,
            ),
          ),
          const SizedBox(height: 12),
          if (stats.count > 0) ...[
            _Text(
              '${stats.count} hit${stats.count == 1 ? '' : 's'}. On average '
              '${_describe(stats.mean)}, spread ${_ms(stats.spread)}, worst '
              '${_describe(stats.worst)}.',
              strong: true,
            ),
            const SizedBox(height: 4),
          ],
          if (calibration != null) ...[
            _Text(
              'Hits are adjusted by the ${_ms(calibration)} calibration'
              '${widget.calibrationLabel == null ? '' : ' for ${widget.calibrationLabel}'}.',
            ),
            const SizedBox(height: 4),
          ],
          if (_doubleTriggers > 0) ...[
            _Text(
              'Ignored $_doubleTriggers double trigger${_doubleTriggers == 1 ? '' : 's'} (hits '
              'within ${_doubleTriggerMs.round()}ms of the one before).',
            ),
            const SizedBox(height: 4),
          ],
          if (_clickTiming.isNotEmpty) ...[_Text(_clickSummary()), const SizedBox(height: 4)],
          if (widget.onSave != null && stats.count > 0 && !_running) ...[
            const SizedBox(height: 8),
            if (stats.count >= _minCalibrationHits)
              CandyButton(
                label: 'SAVE CALIBRATION',
                icon: Icons.tune_rounded,
                colors: AppColors.candyGreen,
                onPressed: _save,
              )
            else
              _Text('Play at least $_minCalibrationHits hits to save a calibration.'),
          ],
          if (stats.count > 0 && !_running) ...[
            const SizedBox(height: 8),
            CandyButton(
              label: 'COPY RESULTS',
              icon: Icons.copy_rounded,
              colors: AppColors.candyBlue,
              onPressed: _copyResults,
            ),
            const SizedBox(height: 12),
          ],
          const _Text(
            "Playing along well, the average is roughly how long a click takes to reach your ears, "
            "which is what hits will need to be adjusted by. The spread is how steady you are.",
          ),
        ],
      ),
    );
  }
}

String _ms(double ms) => '${ms.toStringAsFixed(1)}ms';

String _describe(double offset) => offset < 0 ? '${_ms(-offset)} early' : '${_ms(offset)} late';

class _Text extends StatelessWidget {
  final String text;
  final bool strong;

  const _Text(this.text, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        height: 1.4,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
        color: strong ? AppColors.ink : AppColors.inkMuted,
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  final String text;
  final CandyColors colors;

  const _Readout(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return OutlinedText(
      text,
      style: const TextStyle(fontFamily: AppFonts.display, fontSize: 26, height: 1.1),
      color: colors.base,
      outline: colors.outline,
    );
  }
}

/// The recent hits' [offsets] as dots on a line from early (left) to late (right), the newest
/// biggest and the oldest faintest, with the [mean] marked.
class _OffsetStrip extends StatelessWidget {
  final List<double> offsets;
  final double? mean;

  const _OffsetStrip({required this.offsets, required this.mean});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
        border: Border.all(color: AppColors.panelBorder, width: 2),
      ),
      child: CustomPaint(painter: _OffsetStripPainter(offsets, mean)),
    );
  }
}

class _OffsetStripPainter extends CustomPainter {
  final List<double> offsets;
  final double? mean;

  _OffsetStripPainter(this.offsets, this.mean);

  @override
  void paint(Canvas canvas, Size size) {
    // Wide enough for every offset and the mean, in steps of 50ms.
    final widest = [...offsets, ?mean].fold(0.0, (m, o) => math.max(m, o.abs()));
    final range = math.max(50.0, (widest / 50).ceil() * 50.0);
    const margin = 14.0;
    final width = size.width - margin * 2;
    double x(double offset) => margin + width * (offset + range) / (range * 2);
    final midY = size.height / 2;

    final tick = Paint()
      ..color = AppColors.panelBorder
      ..strokeWidth = 2;
    for (var t = -range; t <= range; t += 50) {
      final length = t == 0 ? size.height * 0.4 : size.height * 0.15;
      canvas.drawLine(Offset(x(t), midY - length), Offset(x(t), midY + length), tick);
    }
    canvas.drawLine(Offset(margin, midY), Offset(size.width - margin, midY), tick);
    _label(canvas, 'early', Offset(margin, 4), Alignment.topLeft, size);
    _label(canvas, 'late', Offset(size.width - margin, 4), Alignment.topRight, size);
    _label(
      canvas,
      '${range.round()}ms',
      Offset(size.width - margin, size.height - 4),
      Alignment.bottomRight,
      size,
    );

    if (mean case final mean?) {
      canvas.drawLine(
        Offset(x(mean), 6),
        Offset(x(mean), size.height - 6),
        Paint()
          ..color = AppColors.gold
          ..strokeWidth = 2,
      );
    }
    for (var i = 0; i < offsets.length; i++) {
      final newest = i == offsets.length - 1;
      final age = (offsets.length - 1 - i) / math.max(1, offsets.length - 1);
      canvas.drawCircle(
        Offset(x(offsets[i]), midY),
        newest ? 7 : 4.5,
        Paint()..color = AppColors.candyOrange.base.withValues(alpha: newest ? 1 : 0.8 - 0.6 * age),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset at, Alignment align, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.panelBorder,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align.x < 0 ? 0.0 : -painter.width;
    final dy = align.y < 0 ? 0.0 : -painter.height;
    painter.paint(canvas, at.translate(dx, dy));
  }

  @override
  bool shouldRepaint(_OffsetStripPainter old) => old.offsets != offsets || old.mean != mean;
}
