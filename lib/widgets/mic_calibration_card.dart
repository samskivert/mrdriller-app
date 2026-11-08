import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/click_sound.dart';
import '../model/mic_calibration.dart';
import '../services/click_scheduler.dart';
import '../services/metronome.dart';
import '../services/metronome_sounds.dart';
import '../services/mic_recorder.dart';
import '../services/midi_input.dart';
import '../util/colors.dart';
import '../util/debug_tools.dart';
import 'arcade.dart';
import 'hud_controls.dart';

/// Measures a drum pad's calibration with the microphone (see mic_calibration.dart): plays a
/// click every second, through the same scheduling as drills, while the player hits the pad
/// between the clicks, and the microphone hears both.
class MicCalibrationCard extends StatefulWidget {
  /// The pad's hits (its note ons), timestamped on the clock of [now].
  final Stream<MidiMessage> hits;
  final double Function() now;

  /// Saves a measurement as the pad's calibration.
  final void Function(MicMeasurement measurement) onSave;

  /// Called when a measurement starts.
  final VoidCallback? onStarted;

  /// Shown at the top of the card, if given.
  final Widget? header;

  const MicCalibrationCard({
    super.key,
    required this.hits,
    required this.now,
    required this.onSave,
    this.onStarted,
    this.header,
  });

  @override
  State<MicCalibrationCard> createState() => _MicCalibrationCardState();
}

enum _Phase { idle, starting, listening, done }

class _MicCalibrationCardState extends State<MicCalibrationCard> {
  static const _hitsWanted = 12;
  // Hits before this many clicks don't count, while the player settles in.
  static const _countInClicks = 2;
  static const _doubleTriggerMs = 30.0;
  // Fewer agreeing measurements than this aren't enough to go by.
  static const _minAgreeing = 4;

  _Phase _phase = _Phase.idle;
  late final _metronome = Metronome(onDue: _onDue);
  MetronomeSounds? _sounds;
  ClickScheduler? _scheduler;
  MicRecorder? _recorder;
  StreamSubscription<MidiMessage>? _subscription;
  Timer? _levelTimer;
  Timer? _finishTimer;
  double _level = 0;
  String? _error;

  // The MIDI clock's time less the metronome's.
  double _clockOffset = 0;
  // When the clicks were scheduled and the hits came in, on the MIDI clock.
  final _clicks = <double>[];
  final _hits = <double>[];
  // For each click, the clock mapping's offset onto the audio engine's clock, when it came due.
  final _engineOffsets = <double?>[];
  MicMeasurement? _result;
  double _sampleRate = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.hits.listen(_onHit);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _cancel();
    _scheduler?.dispose();
    _metronome.dispose();
    _sounds?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    widget.onStarted?.call();
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _result = null;
    });
    final MicRecorder recorder;
    try {
      recorder = await MicRecorder.open();
    } on MicUnavailable catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _error = e.message;
        });
      }
      return;
    }
    // (Always the classic tones, whatever the metronome's set to.)
    final sounds = _sounds ??= MetronomeSounds(sound: ClickSound.classic);
    _scheduler ??= ClickScheduler(
      metronome: _metronome,
      sounds: sounds,
      clicksFor: (_) => const [Click.beep],
    );
    await sounds.start();
    if (!mounted || _phase != _Phase.starting) {
      recorder.close();
      return;
    }
    _recorder = recorder;
    _clicks.clear();
    _hits.clear();
    _engineOffsets.clear();
    _clockOffset = widget.now() - _metronome.now();
    // Its ticks are sixteenths, so a quarter note's 15 bpm is a tick a second.
    _metronome.ensureRunning(bpm: 15);
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _level = recorder.level);
    });
    setState(() => _phase = _Phase.listening);
  }

  void _onDue(int due) {
    setState(() {
      for (var tick = _metronome.ticks - due + 1; tick <= _metronome.ticks; tick++) {
        _clicks.add(_metronome.timeOfTick(tick)! + _clockOffset);
        _engineOffsets.add(_scheduler?.engineOffsetMs);
      }
    });
  }

  void _onHit(MidiMessage message) {
    if (_phase != _Phase.listening || _clicks.length < _countInClicks) return;
    if (_finishTimer != null) return;
    if (_hits.isNotEmpty && message.timestamp - _hits.last < _doubleTriggerMs) return;
    setState(() => _hits.add(message.timestamp));
    // Once there are enough, finish after the last one's sound has been recorded.
    if (_hits.length >= _hitsWanted) {
      _finishTimer = Timer(const Duration(milliseconds: 300), _finish);
    }
  }

  void _finish() {
    final recorder = _recorder;
    if (recorder == null) return;
    final result = measureMicDelay(
      clicks: _clicks,
      hits: _hits,
      samples: recorder.samples,
      startFrame: recorder.startFrame,
      sampleRate: recorder.sampleRate,
      frameAt: recorder.frameAt,
    );
    _sampleRate = recorder.sampleRate;
    _cancel();
    setState(() {
      _phase = _Phase.done;
      _result = result;
    });
  }

  void _stop() {
    if (_hits.length >= _minAgreeing) {
      _finish();
    } else {
      _cancel();
      setState(() => _phase = _Phase.idle);
    }
  }

  // Stops the clicks and the recording.
  void _cancel() {
    _finishTimer?.cancel();
    _finishTimer = null;
    _levelTimer?.cancel();
    _levelTimer = null;
    _metronome.stop();
    _scheduler?.reset();
    _sounds?.pause();
    _recorder?.close();
    _recorder = null;
  }

  Future<void> _copyResults() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: _describe(result)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied the results'), duration: Duration(seconds: 2)),
    );
  }

  void _save() {
    final result = _result;
    if (result == null) return;
    // (The messenger first, as saving may leave the page.)
    final messenger = ScaffoldMessenger.of(context);
    widget.onSave(result);
    messenger.showSnackBar(
      const SnackBar(content: Text('Saved the calibration'), duration: Duration(seconds: 2)),
    );
  }

  String _describe(MicMeasurement result) {
    final stats = result.stats;
    String f(double v) => v.toStringAsFixed(1);
    String onset(Onset? o) => o == null
        ? '-'
        : 'peak ${o.peak.toStringAsFixed(3)}, background ${o.noise.toStringAsFixed(4)}';
    return [
      'Microphone calibration: ${result.pairs.length} hits, '
          '${result.pairs.where((p) => p.delayMs != null).length} measured, '
          '${result.agreeing.length} agreeing (sample rate ${_sampleRate.round()})',
      'System delay: average ${f(stats.mean)}ms, spread ${f(stats.spread)}ms',
      'Each hit: hit - click (ms), click sound - hit sound (ms), delay (ms) or problem; clock '
          "mapping's offset, from the first click's (ms); click sound; hit sound",
      for (final p in result.pairs)
        '${f(p.hitMs - p.clickMs)}, '
            '${p.clickOnset == null || p.hitOnset == null ? '-' : f((p.clickOnset!.index - p.hitOnset!.index) * 1000 / _sampleRate)}, '
            '${p.delayMs == null ? p.problem : f(p.delayMs!)}; '
            '${_offsetChange(p.clickMs)}; '
            '${onset(p.clickOnset)}; ${onset(p.hitOnset)}',
    ].join('\n');
  }

  // How much the clock mapping's offset had changed by the click at [clickMs], since the first.
  String _offsetChange(double clickMs) {
    final index = _clicks.indexOf(clickMs);
    final first = _engineOffsets.nonNulls.firstOrNull;
    final offset = index < 0 ? null : _engineOffsets[index];
    if (first == null || offset == null) return '-';
    return (offset - first).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final listening = _phase == _Phase.listening;
    final result = _result;
    return BannerCard(
      label: 'Between clicks',
      color: AppColors.bannerGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header case final header?) ...[header, const SizedBox(height: 12)],
          CandyButton(
            label: listening ? 'STOP' : 'START',
            icon: listening ? Icons.stop_rounded : Icons.mic_rounded,
            colors: listening ? AppColors.candyRed : AppColors.candyGreen,
            onPressed: _phase == _Phase.starting ? null : (listening ? _stop : _start),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            Text(error, style: _style(strong: true)),
          ],
          const SizedBox(height: 16),
          // What's happening, in big letters, as Play along has it.
          SizedBox(
            height: 40,
            child: Center(
              child: listening
                  ? _readout(
                      _clicks.length < _countInClicks
                          ? 'Ready...'
                          : 'Hits: ${_hits.length} of $_hitsWanted',
                      AppColors.candyBlue,
                    )
                  : _phase == _Phase.done &&
                        result != null &&
                        result.agreeing.length >= _minAgreeing
                  ? _readout('DONE', AppColors.candyGreen)
                  : const SizedBox.shrink(),
            ),
          ),
          if (listening) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Microphone', style: _style()),
                const SizedBox(width: 10),
                Expanded(child: _LevelBar(level: _level)),
              ],
            ),
          ],
          if (_phase == _Phase.done && result != null) ...[
            const SizedBox(height: 12),
            ..._resultWidgets(result),
          ],
        ],
      ),
    );
  }

  List<Widget> _resultWidgets(MicMeasurement result) {
    final stats = result.stats;
    if (result.agreeing.length < _minAgreeing) {
      final problems = <String, int>{};
      for (final pair in result.pairs) {
        if (pair.problem case final problem?) {
          problems.update(problem, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      final why = [
        for (final MapEntry(:key, :value) in problems.entries) '$key ($value)',
      ].join(', ');
      return [
        Text(
          "Couldn't measure it reliably${why.isEmpty ? '' : ': $why'}. Try again, with the pad "
          'nearer the microphone, or the sound louder.',
          style: _style(strong: true),
        ),
        if (debugTools) ...[const SizedBox(height: 8), _copyButton()],
      ];
    }
    return [
      Text('Calibration over ${result.agreeing.length} hits:', style: _style(strong: true)),
      Text(
        'System delay: ${stats.mean.toStringAsFixed(1)}ms (±${stats.spread.toStringAsFixed(1)}ms)',
        style: _style(),
      ),
      const SizedBox(height: 10),
      CandyButton(
        label: 'SAVE CALIBRATION',
        icon: Icons.tune_rounded,
        colors: AppColors.candyGreen,
        onPressed: _save,
      ),
      if (debugTools) ...[const SizedBox(height: 8), _copyButton()],
    ];
  }

  static Widget _readout(String text, CandyColors colors) => OutlinedText(
    text,
    style: const TextStyle(fontFamily: AppFonts.display, fontSize: 26, height: 1.1),
    color: colors.base,
    outline: colors.outline,
  );

  Widget _copyButton() => CandyButton(
    label: 'COPY RESULTS',
    icon: Icons.copy_rounded,
    colors: AppColors.candyBlue,
    onPressed: _copyResults,
  );
}

TextStyle _style({bool strong = false}) => TextStyle(
  fontFamily: AppFonts.body,
  fontSize: 14,
  height: 1.4,
  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
  color: strong ? AppColors.ink : AppColors.inkMuted,
);

class _LevelBar extends StatelessWidget {
  final double level;

  const _LevelBar({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.creamShadow,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: level.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.candyGreen.base,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }
}
