import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../services/metronome_sounds.dart';
import '../state/drill_config.dart';
import '../util/colors.dart';
import '../widgets/app_header.dart';
import '../widgets/components.dart';
import '../widgets/section_view.dart';

enum _Mode { listen, repeat }

const _beatsPerMeasure = 4;

class _PTState {
  final bool playing;
  final bool intro;
  final _Mode mode;
  final int beat;
  final int pattern;
  final int measure;
  final int offset;
  final int repeat;
  final int bpm;

  const _PTState({
    this.playing = false,
    this.intro = false,
    this.mode = _Mode.listen,
    this.beat = 0,
    this.pattern = 0,
    this.measure = 0,
    this.offset = 0,
    this.repeat = 0,
    this.bpm = 60,
  });

  String nOfM (PatternTrainerConfig config) {
    final patternNum = (pattern + 1).clamp(1, config.numPatterns);
    return '$patternNum / ${config.numPatterns}';
  }
}

const _ptNotPlaying = _PTState();

class _TickResult {
  final _PTState state;
  final Stroke? strokeToPlay;

  const _TickResult(this.state, this.strokeToPlay);
}

List<Measure> _flatMeasures(Section pattern) => [for (final l in pattern.lines) ...l.measures];

List<Measure> _generateAllPossibleMeasures() {
  final measures = <Measure>[];
  for (var ii = 0; ii < 16; ii++) {
    final m = <Beat?>[];
    for (var jj = 0; jj < _beatsPerMeasure; jj++) {
      final hand = jj % 2 == 0 ? Hand.R : Hand.L;
      final accent = (ii & (1 << jj)) != 0;
      m.add(beat([hit(hand, accent)]));
    }
    measures.add(m);
  }
  return measures;
}

class _MeasurePool {
  final List<Measure> _pool = [];
  final math.Random _random = math.Random();

  Measure getMeasure() {
    if (_pool.isEmpty) _pool.addAll(_generateAllPossibleMeasures());
    final idx = _random.nextInt(_pool.length);
    final m = _pool[idx];
    _pool.removeAt(idx);
    return m;
  }
}

Section _generatePattern(Difficulty difficulty, _MeasurePool pool) {
  List<Measure> measures;
  if (difficulty == Difficulty.easy) {
    final m = pool.getMeasure();
    measures = [m, m, m, m];
  } else if (difficulty == Difficulty.medium) {
    final m1 = pool.getMeasure();
    final m2 = pool.getMeasure();
    measures = [m1, m2, m1, m2];
  } else {
    measures = [pool.getMeasure(), pool.getMeasure(), pool.getMeasure(), pool.getMeasure()];
  }
  return section('', 1, [
    line([measures[0], measures[1]]),
    line([measures[2], measures[3]]),
  ]);
}

_TickResult _tickPT(_PTState prev, List<Section> patterns) {
  final beat = prev.beat + 1;
  const introBeats = _beatsPerMeasure * 4; // 4 measures for intro

  if (prev.intro && beat < introBeats) {
    return _TickResult(
      _PTState(
        playing: prev.playing,
        intro: prev.intro,
        mode: prev.mode,
        beat: beat,
        pattern: prev.pattern,
        measure: prev.measure,
        offset: prev.offset,
        repeat: prev.repeat,
        bpm: prev.bpm,
      ),
      null,
    );
  }
  if (prev.intro && beat == introBeats) {
    final next = _PTState(
      playing: prev.playing,
      intro: false,
      mode: _Mode.listen,
      beat: beat,
      pattern: prev.pattern,
      measure: 0,
      offset: 0,
      repeat: prev.repeat,
      bpm: prev.bpm,
    );
    final strokeToPlay = _flatMeasures(patterns[prev.pattern])[0][0]?.strokes[0];
    return _TickResult(next, strokeToPlay);
  }

  final currentPattern = patterns[prev.pattern];
  final currentMeasures = _flatMeasures(currentPattern);
  final currentMeasure = currentMeasures[prev.measure];

  var nextOffset = prev.offset + 1;
  var nextMeasure = prev.measure;
  var nextPattern = prev.pattern;
  var nextMode = prev.mode;

  if (nextOffset >= currentMeasure.length) {
    nextOffset = 0;
    nextMeasure = prev.measure + 1;
    if (nextMeasure >= currentMeasures.length) {
      if (prev.mode == _Mode.listen) {
        nextMode = _Mode.repeat;
        nextMeasure = 0;
        nextOffset = 0;
      } else {
        nextMode = _Mode.listen;
        nextMeasure = 0;
        nextOffset = 0;
        nextPattern = prev.pattern + 1;
        if (nextPattern >= patterns.length) {
          return const _TickResult(_ptNotPlaying, null);
        }
      }
    }
  }

  Stroke? strokeToPlay;
  if (nextMode == _Mode.listen) {
    final measureToPlay = _flatMeasures(patterns[nextPattern])[nextMeasure];
    strokeToPlay = measureToPlay[nextOffset]?.strokes[0];
  }

  final next = _PTState(
    playing: true,
    intro: false,
    mode: nextMode,
    beat: beat,
    pattern: nextPattern,
    measure: nextMeasure,
    offset: nextOffset,
    repeat: prev.repeat,
    bpm: prev.bpm,
  );
  return _TickResult(next, strokeToPlay);
}

String _difficultyLabel(Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.easy:
      return 'Easy';
    case Difficulty.medium:
      return 'Medium';
    case Difficulty.hard:
      return 'Hard';
  }
}

/// Runs an active pattern-trainer session at the given [config]: generates [config.numPatterns]
/// random patterns up front, then plays through them one at a time (an intro count-in, then
/// listen/repeat for each), starting automatically as soon as this screen appears. Pops back to
/// [PatternTrainerScreen] the moment every pattern is done. There's no dedicated stop affordance --
/// the header's back button already abandons the session -- but Pause/Resume halts the metronome
/// (and its beat sounds) in place without losing progress.
class PatternTrainerRunScreen extends StatefulWidget {
  final PatternTrainerConfig config;

  const PatternTrainerRunScreen({super.key, required this.config});

  @override
  State<PatternTrainerRunScreen> createState() => _PatternTrainerRunScreenState();
}

class _PatternTrainerRunScreenState extends State<PatternTrainerRunScreen> {
  _PTState _state = _ptNotPlaying;
  late final List<Section> _patterns;

  MetronomeSounds? _sounds;
  late final _metronome = Metronome(onDue: _handleBeatsDue);

  // Guards against the "finished" pop firing more than once (e.g. a beat tick arriving just as
  // the last pattern completes).
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final pool = _MeasurePool();
    _patterns = [
      for (var i = 0; i < widget.config.numPatterns; i++)
        _generatePattern(widget.config.difficulty, pool),
    ];
    _metronome.addListener(_handleMetronomeActiveChanged);
    _sounds = MetronomeSounds();
    // Wait for the tones to finish loading before processing the very first beat -- otherwise
    // that first beep/boop races the (asynchronous, even for these tiny local assets) load and
    // silently gets dropped.
    _sounds!.ready.then((_) {
      if (!mounted) return;
      _applyState(_PTState(playing: true, intro: true, mode: _Mode.listen, bpm: widget.config.bpm));
    });
  }

  // Mirrors drill_practice_view.dart's _handleMetronomeActiveChanged: the metronome is the single
  // source of truth for "is something actually happening right now", so pausing via the button
  // (which pauses the metronome directly) silences sound with no extra plumbing needed.
  void _handleMetronomeActiveChanged() {
    if (!_metronome.isActive) _sounds?.pause();
  }

  @override
  void dispose() {
    _metronome.removeListener(_handleMetronomeActiveChanged);
    _metronome.dispose();
    _sounds?.dispose();
    super.dispose();
  }

  void _playStroke(Stroke? stroke) {
    if (stroke == null) return;
    if (stroke.accent) {
      _sounds?.playBeep();
    } else {
      _sounds?.playBoop();
    }
  }

  void _applyState(_PTState next) {
    setState(() => _state = next);
    _afterStateChange();
  }

  void _afterStateChange() {
    final s = _state;
    if (s.playing && s.intro) {
      final beatInMeasure = s.beat % _beatsPerMeasure;
      if (beatInMeasure == 0) {
        _sounds?.playBeep();
      } else {
        _sounds?.playBoop();
      }
    }
    if (!s.playing) {
      _sounds?.pause();
      _metronome.stop();
      if (mounted && !_finished) {
        _finished = true;
        Navigator.of(context).pop();
      }
      return;
    }
    if (_patterns.isNotEmpty) {
      _metronome.ensureRunning(bpm: s.bpm);
    } else {
      _metronome.stop();
    }
  }

  // See drill_practice_view.dart's _handleBeatsDue for why this catches up on however many beats
  // Metronome says are newly due instead of assuming it's always exactly one, and why only the
  // final caught-up beat's stroke gets played.
  void _handleBeatsDue(int beatsDue) {
    var next = _state;
    Stroke? strokeToPlay;
    for (var i = 0; i < beatsDue; i++) {
      final result = _tickPT(next, _patterns);
      next = result.state;
      strokeToPlay = result.strokeToPlay;
      if (!next.playing) break;
    }
    _applyState(next);
    _playStroke(strokeToPlay);
  }

  bool get _visibilityOk {
    switch (widget.config.sectionVisibility) {
      case SectionVisibility.showAll:
        return true;
      case SectionVisibility.showListen:
        return _state.mode == _Mode.listen;
      case SectionVisibility.showRepeat:
        return _state.mode == _Mode.repeat;
      case SectionVisibility.dontShow:
        return false;
    }
  }

  Widget _mkPatternView(Section pattern, int patternIndex) {
    final isHighlighted = _state.playing && _state.pattern == patternIndex;
    final highlight = isHighlighted
        ? Pos(
            row: 0,
            section: 0,
            line: _state.measure ~/ 2,
            measure: _state.measure % 2,
            offset: _state.offset,
            repeat: _state.repeat,
          )
        : null;
    final displayPattern = widget.config.swapHands ? swapSectionHands(pattern) : pattern;
    return SectionView(section: displayPattern, isHighlighted: isHighlighted, highlight: highlight);
  }

  // Mirrors DrillPracticeHost's isCompactLandscape: short-and-wide, like a phone held sideways,
  // as opposed to a desktop/web window that happens to be wider than tall but still has plenty of
  // vertical room to spare. Only the former is cramped enough to be worth reclaiming the status
  // row's height by folding it into the header instead.
  bool _isCompactLandscape(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width > screenSize.height && screenSize.height < 500;
  }

  Widget _statusView(bool compact) {
    final label =
        '${_difficultyLabel(widget.config.difficulty)} - ${widget.config.bpm}bpm - '
        '${_state.nOfM(widget.config)}';
    return AnimatedBuilder(
      animation: _metronome,
      builder: (context, _) {
        final paused = _metronome.isPaused;
        final labelText = Text(
          label,
          style: TextStyle(
            fontSize: compact ? 16 : 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textGray,
          ),
        );
        final button = ElevatedButton(
          onPressed: paused ? _metronome.resume : _metronome.pause,
          style: ElevatedButton.styleFrom(
            backgroundColor: paused ? AppColors.btnGreen : AppColors.btnGray,
            foregroundColor: Colors.white,
            padding: compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : null,
            minimumSize: compact ? Size.zero : null,
            tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
          ),
          child: Text(paused ? 'Resume' : 'Pause'),
        );
        if (compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [labelText, const SizedBox(width: 12), button],
          );
        }
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [labelText, button],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLandscape = _isCompactLandscape(context);
    final action = _state.mode == _Mode.listen ? 'Listen' : 'Repeat';
    // Deliberately not ScreenScaffold: its scrollable body hands the pattern's SectionView an
    // unbounded height (a SingleChildScrollView always gives its child infinite height along the
    // scroll axis), so it never had any reason to size itself to fit -- it just rendered as large
    // as the width allowed and ran off the bottom of short landscape screens. A fixed,
    // non-scrolling Expanded layout instead gives the content a real height budget to fill (and,
    // via ClipRect below, to clip gracefully against if a pattern still doesn't quite fit).
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppHeader(
                title: 'Pattern Trainer',
                showSettings: false,
                trailing: isCompactLandscape ? _statusView(true) : null,
              ),
            ),
            if (!isCompactLandscape) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _statusView(false),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ClipRect(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_state.playing || _state.intro)
                            CountdownSection(
                              beat: _state.beat,
                              beatsPerMeasure: _beatsPerMeasure,
                              intro: _state.intro,
                            )
                          else if (_patterns.isNotEmpty && _state.pattern < _patterns.length) ...[
                            HighlightedCard(
                              isHighlighted: true,
                              child: Center(
                                child: Text(
                                  '$action - ${_state.nOfM(widget.config)}',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.btnBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_visibilityOk)
                              _mkPatternView(_patterns[_state.pattern], _state.pattern),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
