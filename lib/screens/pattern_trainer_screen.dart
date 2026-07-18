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
}

const _ptNotPlaying = _PTState();

class _TickResult {
  final _PTState state;
  final Stroke? strokeToPlay;

  const _TickResult(this.state, this.strokeToPlay);
}

List<Measure> _flatMeasures(Section pattern) => [
  for (final l in pattern.lines) ...l.measures,
];

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
    measures = [
      pool.getMeasure(),
      pool.getMeasure(),
      pool.getMeasure(),
      pool.getMeasure(),
    ];
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
    final strokeToPlay = _flatMeasures(
      patterns[prev.pattern],
    )[0][0]?.strokes[0];
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

class PatternTrainerScreen extends StatefulWidget {
  const PatternTrainerScreen({super.key});

  @override
  State<PatternTrainerScreen> createState() => _PatternTrainerScreenState();
}

class _PatternTrainerScreenState extends State<PatternTrainerScreen> {
  int _bpm = 60;
  Difficulty _difficulty = Difficulty.easy;
  int _numPatterns = 5;
  bool _swapHands = false;
  SectionVisibility _sectionVisibility = SectionVisibility.showAll;

  _PTState _state = _ptNotPlaying;
  List<Section> _patterns = [];

  MetronomeSounds? _sounds;
  late final _metronome = Metronome(onDue: _handleBeatsDue);

  @override
  void initState() {
    super.initState();
    _sounds = MetronomeSounds();
    loadPatternTrainerConfig().then((config) {
      if (!mounted) return;
      setState(() {
        _bpm = config.bpm;
        _difficulty = config.difficulty;
        _numPatterns = config.numPatterns;
        _swapHands = config.swapHands;
        _sectionVisibility = config.sectionVisibility;
      });
    });
  }

  @override
  void dispose() {
    _metronome.dispose();
    _sounds?.dispose();
    super.dispose();
  }

  void _saveConfig() {
    savePatternTrainerConfig(
      PatternTrainerConfig(
        bpm: _bpm,
        difficulty: _difficulty,
        numPatterns: _numPatterns,
        swapHands: _swapHands,
        sectionVisibility: _sectionVisibility,
      ),
    );
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
    if (!s.playing) _sounds?.pause();
    if (s.playing && _patterns.isNotEmpty) {
      _metronome.ensureRunning(bpm: s.bpm);
    } else {
      _metronome.stop();
    }
  }

  // See drill_practice_screen.dart's _handleBeatsDue for why this catches up on however many
  // beats Metronome says are newly due instead of assuming it's always exactly one, and why only
  // the final caught-up beat's stroke gets played.
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

  void _handleStart() {
    final pool = _MeasurePool();
    final newPatterns = [
      for (var i = 0; i < _numPatterns; i++)
        _generatePattern(_difficulty, pool),
    ];
    setState(() => _patterns = newPatterns);
    // Wait for the tones to finish loading before processing the very first beat -- otherwise
    // that first beep/boop races the (asynchronous, even for these tiny local assets) load and
    // silently gets dropped.
    _sounds?.ready.then((_) {
      if (!mounted) return;
      _applyState(
        const _PTState(playing: true, intro: true, mode: _Mode.listen),
      );
    });
  }

  void _handleStop() => _applyState(_ptNotPlaying);

  bool get _visibilityOk {
    switch (_sectionVisibility) {
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
    final displayPattern = _swapHands ? swapSectionHands(pattern) : pattern;
    return SectionView(
      section: displayPattern,
      isHighlighted: isHighlighted,
      highlight: highlight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: AppHeader(title: 'Pattern Trainer', showSettings: false),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            NumberInputField(
                              label: 'BPM',
                              value: _bpm,
                              onChanged: (v) => setState(() {
                                _bpm = v;
                                _saveConfig();
                              }),
                              min: 30,
                              max: 120,
                              width: 60,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Difficulty: '),
                                DropdownButton<Difficulty>(
                                  value: _difficulty,
                                  items: const [
                                    DropdownMenuItem(
                                      value: Difficulty.easy,
                                      child: Text('Easy'),
                                    ),
                                    DropdownMenuItem(
                                      value: Difficulty.medium,
                                      child: Text('Medium'),
                                    ),
                                    DropdownMenuItem(
                                      value: Difficulty.hard,
                                      child: Text('Hard'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _difficulty = v;
                                      _saveConfig();
                                    });
                                  },
                                ),
                              ],
                            ),
                            NumberInputField(
                              label: 'Patterns',
                              value: _numPatterns,
                              onChanged: (v) => setState(() {
                                _numPatterns = v;
                                _saveConfig();
                              }),
                              min: 1,
                              max: 20,
                              width: 60,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _swapHands,
                                  onChanged: (v) => setState(() {
                                    _swapHands = v;
                                    _saveConfig();
                                  }),
                                ),
                                const Text('L↔︎R'),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Show: '),
                                DropdownButton<SectionVisibility>(
                                  value: _sectionVisibility,
                                  items: const [
                                    DropdownMenuItem(
                                      value: SectionVisibility.showAll,
                                      child: Text('All'),
                                    ),
                                    DropdownMenuItem(
                                      value: SectionVisibility.showListen,
                                      child: Text('Listen'),
                                    ),
                                    DropdownMenuItem(
                                      value: SectionVisibility.showRepeat,
                                      child: Text('Repeat'),
                                    ),
                                    DropdownMenuItem(
                                      value: SectionVisibility.dontShow,
                                      child: Text('Never'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _sectionVisibility = v;
                                      _saveConfig();
                                    });
                                  },
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: _state.playing ? null : _handleStart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.btnGreen,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Start'),
                            ),
                            if (_state.playing)
                              ElevatedButton(
                                onPressed: _handleStop,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.btnRed,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Stop'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (!_state.playing || _state.intro)
                          CountdownSection(
                            beat: _state.beat,
                            beatsPerMeasure: _beatsPerMeasure,
                            intro: _state.intro,
                          )
                        else if (_patterns.isNotEmpty &&
                            _state.pattern < _patterns.length) ...[
                          HighlightedCard(
                            isHighlighted: true,
                            minHeight: 100,
                            child: Center(
                              child: Text(
                                _state.mode == _Mode.listen
                                    ? 'Listen'
                                    : 'Repeat',
                                style: TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.btnBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_visibilityOk)
                            _mkPatternView(
                              _patterns[_state.pattern],
                              _state.pattern,
                            ),
                        ],
                      ],
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
