import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../services/metronome_sounds.dart';
import '../state/drill_config.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/components.dart';
import '../widgets/drill_practice_view.dart';
import '../widgets/drill_status_view.dart';
import '../widgets/hud_layout.dart';
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

  String nOfM(PatternTrainerConfig config) {
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

class _PatternTrainerRunScreenState extends State<PatternTrainerRunScreen>
    with SingleTickerProviderStateMixin {
  _PTState _state = _ptNotPlaying;
  late final List<Section> _patterns;

  MetronomeSounds? _sounds;
  late final _metronome = Metronome(onDue: _handleBeatsDue);

  // Guards against the "finished" pop firing more than once (e.g. a beat tick arriving just as
  // the last pattern completes).
  bool _finished = false;

  // How much of the session's playing time has gone by, counted note by note, for the HUD's time
  // gauge and depth ruler.
  double _elapsedSeconds = 0;

  // Once every pattern is done: the ALL CLEAR! celebration, before popping back to the setup
  // screen.
  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _celebrating = false;

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

  bool _left = false;

  void _leave() {
    if (!mounted || _left) return;
    _left = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _celebration.dispose();
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
        setState(() => _celebrating = true);
        _celebration.forward().whenComplete(_leave);
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
      _elapsedSeconds += 60 / next.bpm / 4;
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

  DrillRunStatus get _status => DrillRunStatus(
    bpm: widget.config.bpm,
    bpmIncrease: 0,
    drillRepeat: widget.config.numPatterns,
    drillRepeatCount: _state.pattern.clamp(0, widget.config.numPatterns - 1),
    elapsedSeconds: _elapsedSeconds,
    totalSeconds: patternTrainerSeconds(widget.config),
  );

  Widget _playfield() {
    final listening = _state.mode == _Mode.listen;
    final counting = !_state.playing || _state.intro;
    final pattern = _state.pattern.clamp(0, _patterns.length - 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 0, 16),
          child: DepthRuler(progress: _status.progress),
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ModeBanner(
                          listening: listening,
                          pattern: pattern + 1,
                          patterns: widget.config.numPatterns,
                        ),
                        const SizedBox(height: 14),
                        if (_patterns.isNotEmpty)
                          Flexible(
                            child: _visibilityOk
                                ? _mkPatternView(_patterns[pattern], pattern)
                                : _MysteryPanel(listening: listening),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !counting,
                  child: AnimatedOpacity(
                    opacity: counting && !_celebrating ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: CountInOverlay(
                      index: _state.playing ? _state.beat ~/ _beatsPerMeasure : -1,
                      heading: 'GET READY',
                      details:
                          '${widget.config.bpm} BPM · ${widget.config.numPatterns} '
                          'PATTERN${widget.config.numPatterns == 1 ? '' : 'S'}',
                    ),
                  ),
                ),
              ),
              if (_celebrating)
                Positioned.fill(
                  child: GestureDetector(
                    // A tap skips the rest of the celebration.
                    onTap: _leave,
                    child: ClearCelebration(animation: _celebration, start: null, textSize: 36),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _difficultyLabel(widget.config.difficulty);
    return HudLayout(
      playfield: _playfield(),
      hud: Column(
        children: [
          Row(
            children: [
              const HudBackButton(),
              const SizedBox(width: 12),
              Expanded(child: HudTitle('Pattern Trainer', subtitle: subtitle)),
              const SizedBox(width: 12),
              PauseButton(metronome: _metronome),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: DrillStatusView(status: _status, loopLabel: 'Pattern'),
          ),
        ],
      ),
      sidebar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const HudBackButton(),
              const SizedBox(width: 10),
              Expanded(child: HudTitle('Pattern Trainer', subtitle: subtitle, sidebar: true)),
            ],
          ),
          const SizedBox(height: 14),
          DrillStatusView(status: _status, vertical: true, loopLabel: 'Pattern'),
          const SizedBox(height: 14),
          PauseButton(metronome: _metronome, showLabel: true),
        ],
      ),
    );
  }
}

/// Whose turn it is: LISTEN (to the pattern being played) or YOUR TURN (to play it back), and
/// which pattern this is.
class _ModeBanner extends StatelessWidget {
  final bool listening;
  final int pattern;
  final int patterns;

  const _ModeBanner({required this.listening, required this.pattern, required this.patterns});

  @override
  Widget build(BuildContext context) {
    final candy = listening ? AppColors.candyBlue : AppColors.candyPink;
    return Semantics(
      liveRegion: true,
      label: '${listening ? 'Listen' : 'Your turn'}: pattern $pattern of $patterns',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(18, 10, 22, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [candy.hi, candy.base, candy.lo],
              ),
              boxShadow: [BoxShadow(color: candy.outline, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  listening ? Icons.hearing_rounded : Icons.sports_martial_arts_rounded,
                  color: Colors.white,
                  size: 26,
                  shadows: [Shadow(color: candy.outline, offset: const Offset(0, 2))],
                ),
                const SizedBox(width: 8),
                OutlinedText(
                  listening ? 'LISTEN' : 'YOUR TURN',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.5,
                  ),
                  color: Colors.white,
                  outline: candy.outline,
                  outlineWidth: 2.5,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PATTERN $pattern OF $patterns',
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for the pattern while it's hidden (see [SectionVisibility]): a mystery "?" and a
/// reminder of what to do.
class _MysteryPanel extends StatelessWidget {
  final bool listening;

  const _MysteryPanel({required this.listening});

  @override
  Widget build(BuildContext context) {
    return PlayfieldPanel(
      active: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PuffyText('?', size: 72, color: AppColors.gold, shadow: AppColors.goldOutline),
            const SizedBox(height: 10),
            Text(
              listening ? 'Listen closely…' : 'Play it back from memory!',
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
