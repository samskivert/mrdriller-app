import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/model.dart';
import '../services/metronome_sounds.dart';
import '../state/drill_config.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../util/size_config.dart';
import '../widgets/app_header.dart';
import '../widgets/components.dart';
import '../widgets/drill_overview_view.dart';
import '../widgets/section_view.dart';

class _PState {
  final bool playing;
  final bool intro;
  final int beat;
  final int row;
  final int section;
  final int line;
  final int measure;
  final int offset;
  final int repeat;
  final int drillRepeat;
  final int bpm;
  final int bpmIncrease;

  const _PState({
    this.playing = false,
    this.intro = false,
    this.beat = 0,
    this.row = 0,
    this.section = 0,
    this.line = 0,
    this.measure = 0,
    this.offset = 0,
    this.repeat = 0,
    this.drillRepeat = 0,
    this.bpm = 60,
    this.bpmIncrease = 0,
  });
}

const _notPlaying = _PState();

/// Advances the drill state machine by exactly one tick (one sixteenth-note-ish subdivision),
/// mirroring the reducer in the web app's PracticeView.tsx.
_PState _tick(_PState prev, Drill drill, int drillRepeatTarget, bool replayIntroOnBpmIncrease) {
  final row = drill.rows[prev.row];
  final section = row[prev.section];
  final line = section.lines[prev.line];
  final measure = line.measures[prev.measure];

  final beat = prev.beat + 1;

  if (prev.intro && beat < drill.bpm * 4) {
    return _PState(
      playing: prev.playing,
      intro: prev.intro,
      beat: beat,
      row: prev.row,
      section: prev.section,
      line: prev.line,
      measure: prev.measure,
      offset: prev.offset,
      repeat: prev.repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }
  const intro = false;
  if (beat == drill.bpm * 4) {
    return _PState(
      playing: prev.playing,
      intro: intro,
      beat: beat,
      row: prev.row,
      section: prev.section,
      line: prev.line,
      measure: prev.measure,
      offset: prev.offset,
      repeat: prev.repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }

  var offset = prev.offset + 1;
  if (offset < measure.length) {
    return _PState(
      playing: prev.playing,
      intro: intro,
      beat: beat,
      row: prev.row,
      section: prev.section,
      line: prev.line,
      measure: prev.measure,
      offset: offset,
      repeat: prev.repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }
  offset = 0;

  var measureIdx = prev.measure + 1;
  if (measureIdx < line.measures.length) {
    return _PState(
      playing: prev.playing,
      intro: intro,
      beat: beat,
      row: prev.row,
      section: prev.section,
      line: prev.line,
      measure: measureIdx,
      offset: offset,
      repeat: prev.repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }
  measureIdx = 0;

  var lineIdx = prev.line + 1;
  if (lineIdx < section.lines.length) {
    return _PState(
      playing: prev.playing,
      intro: intro,
      beat: beat,
      row: prev.row,
      section: prev.section,
      line: lineIdx,
      measure: measureIdx,
      offset: offset,
      repeat: prev.repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }
  lineIdx = 0;

  var repeat = prev.repeat + 1;
  if (repeat < section.repeat) {
    return _PState(
      playing: prev.playing,
      intro: intro,
      beat: beat,
      row: prev.row,
      section: prev.section,
      line: lineIdx,
      measure: measureIdx,
      offset: offset,
      repeat: repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }
  repeat = 0;

  var sectionIdx = prev.section + 1;
  if (sectionIdx < row.length) {
    return _PState(
      playing: prev.playing,
      intro: intro,
      beat: beat,
      row: prev.row,
      section: sectionIdx,
      line: lineIdx,
      measure: measureIdx,
      offset: offset,
      repeat: repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }
  sectionIdx = 0;

  var rowIdx = prev.row + 1;
  if (rowIdx < drill.rows.length) {
    return _PState(
      playing: prev.playing,
      intro: intro,
      beat: beat,
      row: rowIdx,
      section: sectionIdx,
      line: lineIdx,
      measure: measureIdx,
      offset: offset,
      repeat: repeat,
      drillRepeat: prev.drillRepeat,
      bpm: prev.bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }
  rowIdx = 0;

  final drillRepeat = prev.drillRepeat + 1;
  if (drillRepeat < drillRepeatTarget) {
    final bpm = (prev.bpm + prev.bpmIncrease).clamp(0, maxBpm);
    final restart = (prev.bpmIncrease > 0 && replayIntroOnBpmIncrease) || drill.forceIntro;
    return _PState(
      playing: true,
      intro: restart ? true : intro,
      beat: restart ? 0 : beat,
      row: rowIdx,
      section: sectionIdx,
      line: lineIdx,
      measure: measureIdx,
      offset: offset,
      repeat: repeat,
      drillRepeat: drillRepeat,
      bpm: bpm,
      bpmIncrease: prev.bpmIncrease,
    );
  }

  return _notPlaying;
}

String _formatDuration(double seconds) {
  final mins = seconds ~/ 60;
  final secs = (seconds % 60).round();
  return '${mins}m ${secs.toString().padLeft(2, '0')}s';
}

typedef _FlatSection = ({Section section, int rowIndex, int sectionIndex});

class DrillScreen extends StatefulWidget {
  final Drill drill;

  const DrillScreen({super.key, required this.drill});

  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  int _bpm = 60;
  int _bpmIncrease = 0;
  int _drillRepeat = 1;
  bool _swapHandsEnabled = false;
  _PState _state = _notPlaying;

  MetronomeSounds? _sounds;
  Timer? _timer;
  int? _timerBpm;

  @override
  void initState() {
    super.initState();
    _sounds = MetronomeSounds();
    loadDrillConfig(widget.drill.id).then((config) {
      if (!mounted) return;
      setState(() {
        _bpm = config.bpm;
        _bpmIncrease = config.bpmIncrease;
        _drillRepeat = config.drillRepeat;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sounds?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _saveConfig() {
    saveDrillConfig(widget.drill.id, DrillConfig(bpm: _bpm, bpmIncrease: _bpmIncrease, drillRepeat: _drillRepeat));
  }

  void _applyState(_PState next) {
    setState(() => _state = next);
    _afterStateChange();
  }

  void _afterStateChange() {
    final s = _state;
    if (s.playing) {
      final beatInMeasure = s.beat % widget.drill.bpm;
      final beeps = widget.drill.beeps;
      if (beeps != null) {
        if (beeps.contains(beatInMeasure + 1)) {
          if (beatInMeasure + 1 == beeps.first) {
            _sounds?.playBeep();
          } else {
            _sounds?.playBoop();
          }
        }
      } else {
        if (beatInMeasure == 0) {
          _sounds?.playBeep();
        } else {
          _sounds?.playBoop();
        }
      }
      WakelockPlus.enable();
    } else {
      _sounds?.pause();
      WakelockPlus.disable();
    }
    _ensureTimer();
  }

  void _ensureTimer() {
    if (!_state.playing) {
      _timer?.cancel();
      _timer = null;
      _timerBpm = null;
      return;
    }
    if (_timer != null && _timerBpm == _state.bpm) return;
    _timer?.cancel();
    final delayMs = (60000 / _state.bpm / 4) * widget.drill.scale;
    _timerBpm = _state.bpm;
    _timer = Timer.periodic(Duration(microseconds: (delayMs * 1000).round()), (_) {
      _applyState(_tick(_state, widget.drill, _drillRepeat, settings.replayIntroOnBpmIncrease));
    });
  }

  void _handleStart() {
    _sounds?.resume();
    _applyState(_PState(playing: true, intro: true, bpm: _bpm, bpmIncrease: _bpmIncrease));
  }

  void _handleStop() {
    _applyState(_notPlaying);
  }

  List<_FlatSection> _allSections(Drill drill) => [
        for (var r = 0; r < drill.rows.length; r++)
          for (var s = 0; s < drill.rows[r].length; s++) (section: drill.rows[r][s], rowIndex: r, sectionIndex: s),
      ];

  String _mkRepeat(int current, int total) {
    const empty = '○';
    return '●' * (current + 1) + empty * (total - current - 1);
  }

  @override
  Widget build(BuildContext context) {
    final drill = widget.drill;
    final activeDrill = _swapHandsEnabled ? swapHands(drill) : drill;
    final allSections = _allSections(activeDrill);
    final currentFlatIndex = allSections.indexWhere((s) => s.rowIndex == _state.row && s.sectionIndex == _state.section);
    final idx = currentFlatIndex >= 0 ? currentFlatIndex : 0;
    final willRepeatDrill = _state.drillRepeat + 1 < _drillRepeat;
    final willAnnounceRepeat = willRepeatDrill && (_state.bpmIncrease > 0 || drill.forceIntro);
    final isLastSection = idx == allSections.length - 1;
    final windowWidth = MediaQuery.of(context).size.width;
    final sizeLevel = computeDrillSizeLevel(activeDrill, windowWidth);
    final currentSection = allSections[idx].section;

    Widget mkSectionView(Section section, bool isHighlighted) {
      final repeatDisplay = isHighlighted
          ? _mkRepeat(_state.repeat, section.repeat)
          : '○' * section.repeat;
      return SectionView(
        section: section,
        isHighlighted: isHighlighted,
        repeatDisplay: repeatDisplay,
        sizeLevel: sizeLevel,
        highlight: (isHighlighted && _state.playing && settings.showBouncingDot)
            ? Pos(row: _state.row, section: _state.section, line: _state.line, measure: _state.measure, offset: _state.offset, repeat: _state.repeat)
            : null,
      );
    }

    Widget countdownSectionEl() {
      final isBpmUp = _state.drillRepeat > 0 && _state.bpmIncrease > 0;
      final isRepeat = _state.drillRepeat > 0;
      return CountdownSection(
        beat: _state.beat,
        beatsPerMeasure: drill.bpm,
        intro: _state.intro,
        preText: isBpmUp ? 'BPM up!' : (isRepeat ? 'Back to the start!' : 'Get ready...'),
      );
    }

    final topKey = _state.intro ? 'countdown-${_state.drillRepeat}' : 'section-$idx-${_state.drillRepeat}';
    final showRepeatPreview = isLastSection && willAnnounceRepeat;

    String bottomKey;
    if (_state.intro) {
      bottomKey = 'section-$idx-${_state.drillRepeat}-preview';
    } else if (isLastSection && !willRepeatDrill) {
      bottomKey = 'all-done';
    } else if (showRepeatPreview) {
      bottomKey = 'countdown-next-${_state.drillRepeat + 1}';
    } else {
      final nextIdx = (idx + 1) % allSections.length;
      final nextDR = nextIdx == 0 ? _state.drillRepeat + 1 : _state.drillRepeat;
      bottomKey = 'section-$nextIdx-$nextDR-preview';
    }

    Widget topContent() => _state.intro ? countdownSectionEl() : mkSectionView(currentSection, true);

    Widget bottomContent() {
      if (bottomKey == 'all-done') {
        return HighlightedCard(
          isHighlighted: false,
          minHeight: 100,
          child: Center(
            child: Text('All done!', style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: AppColors.textGray)),
          ),
        );
      }
      if (bottomKey.startsWith('countdown-next-')) {
        return CountdownSection(
          beat: 0,
          beatsPerMeasure: drill.bpm,
          intro: false,
          preText: _state.bpmIncrease > 0 ? 'BPM up!' : 'Back to the start!',
        );
      }
      final nextIdx = _state.intro ? idx : (idx + 1) % allSections.length;
      return mkSectionView(allSections[nextIdx].section, false);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppHeader(title: drill.title),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: !_state.playing
                          ? Column(
                              children: [
                                _DrillControls(
                                  drill: drill,
                                  bpm: _bpm,
                                  onBpmChanged: (v) => setState(() {
                                    _bpm = v;
                                    _saveConfig();
                                  }),
                                  bpmIncrease: _bpmIncrease,
                                  onBpmIncreaseChanged: (v) => setState(() {
                                    _bpmIncrease = v;
                                    _saveConfig();
                                  }),
                                  drillRepeat: _drillRepeat,
                                  onDrillRepeatChanged: (v) => setState(() {
                                    _drillRepeat = v;
                                    _saveConfig();
                                  }),
                                  swapHands: _swapHandsEnabled,
                                  onSwapHandsChanged: (v) => setState(() => _swapHandsEnabled = v),
                                  onStart: _handleStart,
                                ),
                                const SizedBox(height: 24),
                                DrillOverviewView(drill: activeDrill),
                              ],
                            )
                          : Column(
                              children: [
                                _StatusView(
                                  bpm: _state.bpm,
                                  bpmIncrease: _state.bpmIncrease,
                                  drillRepeat: _drillRepeat,
                                  drillRepeatCount: _state.drillRepeat,
                                  onStop: _handleStop,
                                ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  transitionBuilder: (child, anim) => FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                                          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                                      child: child,
                                    ),
                                  ),
                                  child: KeyedSubtree(key: ValueKey(topKey), child: topContent()),
                                ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: KeyedSubtree(key: ValueKey(bottomKey), child: bottomContent()),
                                ),
                                if (showRepeatPreview) ...[
                                  const SizedBox(height: 16),
                                  mkSectionView(allSections[0].section, false),
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
      ),
    );
  }
}

class _DrillControls extends StatelessWidget {
  final Drill drill;
  final int bpm;
  final ValueChanged<int> onBpmChanged;
  final int bpmIncrease;
  final ValueChanged<int> onBpmIncreaseChanged;
  final int drillRepeat;
  final ValueChanged<int> onDrillRepeatChanged;
  final bool swapHands;
  final ValueChanged<bool> onSwapHandsChanged;
  final VoidCallback onStart;

  const _DrillControls({
    required this.drill,
    required this.bpm,
    required this.onBpmChanged,
    required this.bpmIncrease,
    required this.onBpmIncreaseChanged,
    required this.drillRepeat,
    required this.onDrillRepeatChanged,
    required this.swapHands,
    required this.onSwapHandsChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final duration = _formatDuration(
      computeDrillDuration(drill, bpm, bpmIncrease, drillRepeat, replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        NumberInputField(label: 'BPM', value: bpm, onChanged: onBpmChanged, min: 30, max: maxBpm, width: 60),
        NumberInputField(
            label: 'BPM Increase', value: bpmIncrease, onChanged: onBpmIncreaseChanged, min: 0, max: 50, width: 70),
        NumberInputField(label: 'Repeat', value: drillRepeat, onChanged: onDrillRepeatChanged, min: 1, max: 10, width: 60),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: swapHands, onChanged: onSwapHandsChanged),
            const Text('L↔︎R'),
          ],
        ),
        Text(duration, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textGray)),
        ElevatedButton(
          onPressed: onStart,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.btnGreen, foregroundColor: Colors.white),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  final int bpm;
  final int bpmIncrease;
  final int drillRepeat;
  final int drillRepeatCount;
  final VoidCallback onStop;

  const _StatusView({
    required this.bpm,
    required this.bpmIncrease,
    required this.drillRepeat,
    required this.drillRepeatCount,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(
          '$bpm bpm${bpmIncrease > 0 ? ' (+$bpmIncrease)' : ''}',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textGray),
        ),
        if (drillRepeat > 1)
          Text('${drillRepeatCount + 1} / $drillRepeat',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textGray)),
        ElevatedButton(
          onPressed: onStop,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.btnRed, foregroundColor: Colors.white),
          child: const Text('Stop'),
        ),
      ],
    );
  }
}
