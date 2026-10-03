import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../services/metronome_sounds.dart';
import '../state/drill_config.dart';
import '../state/settings.dart';
import 'components.dart';
import 'drill_status_view.dart';
import 'section_view.dart';

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

const _scrollDuration = Duration(milliseconds: 400);
const _scrollCurve = Curves.easeInOut;

/// Advances the drill state machine by exactly one tick (one sixteenth-note-ish subdivision).
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

typedef _FlatSection = ({Section section, int rowIndex, int sectionIndex});

List<_FlatSection> _flattenSections(Drill drill) => [
  for (var r = 0; r < drill.rows.length; r++)
    for (var s = 0; s < drill.rows[r].length; s++)
      (section: drill.rows[r][s], rowIndex: r, sectionIndex: s),
];

/// Runs an active practice session for [drill] at the given starting [config] -- the metronome,
/// the state machine driving which section is current, and the section/countdown visuals. [drill]
/// is expected to already be the one the user will actually see (e.g. with swapHands already
/// applied), since this widget has no notion of that config -- it just plays whatever [Drill] it's
/// handed.
///
/// This is the reusable "run one drill" content, with no [Scaffold]/header/navigation of its own:
/// [onDone] fires once when the drill finishes all its repeats on its own, and it's up to the
/// caller to decide what that means (pop back to an overview screen, advance to the next drill in
/// a practice plan, etc). There's no dedicated "stop" affordance here -- the caller's own back
/// button already abandons the session.
///
/// [metronome] is created and owned by the caller (typically [DrillPracticeHost]), not by this
/// widget -- that's what lets a sibling [DrillStatusView] elsewhere in the tree (e.g. in the
/// screen's header) show/control the same running metronome. This widget wires itself up as the
/// metronome's [Metronome.onDue] consumer in [initState], and publishes its live bpm/repeat
/// progress to [status] as it changes, for that same sibling to display. Give it (and its
/// metronome/status notifier) a fresh identity per drill (e.g. keyed by the drill's id) when
/// reusing one across a sequence of drills, so each gets its own freshly-initialized
/// state/sounds instead of one being update-reused for another.
class DrillPracticeView extends StatefulWidget {
  final Drill drill;
  final DrillConfig config;
  final Metronome metronome;
  final ValueNotifier<DrillRunStatus> status;
  final VoidCallback onDone;

  const DrillPracticeView({
    super.key,
    required this.drill,
    required this.config,
    required this.metronome,
    required this.status,
    required this.onDone,
  });

  @override
  State<DrillPracticeView> createState() => _DrillPracticeViewState();
}

class _DrillPracticeViewState extends State<DrillPracticeView> {
  late _PState _state;

  MetronomeSounds? _sounds;

  // widget.drill never changes for the lifetime of this widget (swapHands, if requested, was
  // already applied by the caller before it was ever handed to us), so unlike the overview screen
  // this only needs to be computed once.
  late final List<_FlatSection> _allSections = _flattenSections(widget.drill);
  late final List<GlobalKey> _sectionKeys = [for (final _ in _allSections) GlobalKey()];

  final _scrollController = ScrollController();
  double _lastSectionHeight = 0;

  // Guards against onDone firing more than once (e.g. a beat tick arriving just as the drill
  // finishes).
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    widget.metronome.onDue = _handleBeatsDue;
    widget.metronome.addListener(_handleMetronomeActiveChanged);
    final sounds = MetronomeSounds();
    _sounds = sounds;
    _state = _PState(
      playing: true,
      intro: true,
      bpm: widget.config.bpm,
      bpmIncrease: widget.config.bpmIncrease,
    );
    // Wait for the tones to finish loading before processing the very first beat -- otherwise
    // that first beep/boop races the (asynchronous, even for these tiny local assets) load and
    // silently gets dropped, which is why the drill would seem to start on its *second* audible
    // tick instead of its first.
    sounds.ready.then((_) {
      if (!mounted) return;
      _playBeatSound();
      _publishStatus();
      widget.metronome.ensureRunning(bpm: _state.bpm, scale: widget.drill.scale);
    });
  }

  @override
  void dispose() {
    widget.metronome.removeListener(_handleMetronomeActiveChanged);
    _sounds?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // The metronome is the single source of truth for "is something actually happening right now" --
  // reacting to it here (rather than tying wakelock/sound-pausing to _state.playing directly) means
  // pausing via the Pause button (which pauses the metronome directly, with no involvement from
  // this widget) automatically releases the wakelock and silences sound too, and resuming
  // re-acquires the wakelock, with no extra plumbing needed for either.
  void _handleMetronomeActiveChanged() {
    if (widget.metronome.isActive) {
      WakelockPlus.enable();
    } else {
      _sounds?.pause();
      WakelockPlus.disable();
    }
  }

  void _applyState(_PState next) {
    _scrollIfMoved(_state, next);
    setState(() => _state = next);
    _playBeatSound();
    _publishStatus();
    if (next.playing) {
      widget.metronome.ensureRunning(bpm: next.bpm, scale: widget.drill.scale);
    } else {
      widget.metronome.stop();
      if (mounted && !_finished) {
        _finished = true;
        widget.onDone();
      }
    }
  }

  void _playBeatSound() {
    final s = _state;
    if (!s.playing) return;
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
  }

  void _publishStatus() {
    widget.status.value = DrillRunStatus(
      bpm: _state.bpm,
      bpmIncrease: _state.bpmIncrease,
      drillRepeat: widget.config.drillRepeat,
      drillRepeatCount: _state.drillRepeat,
    );
  }

  // Applies as many ticks as [beatsDue] says are actually due (usually one), and applies the
  // resulting state exactly once. This is what keeps the drill from permanently lagging behind
  // after something delays a beat (a GC pause, a slow frame, background/foreground switching on
  // some platforms): Metronome notices multiple beats are due and reports them all at once here,
  // so this catches all the way up in one step rather than the drill quietly falling further and
  // further behind. Sound only plays for the final, caught-up state -- catching up by replaying
  // every skipped beat's sound in a rapid burst would be worse than just skipping ahead silently.
  void _handleBeatsDue(int beatsDue) {
    var next = _state;
    for (var i = 0; i < beatsDue; i++) {
      next = _tick(
        next,
        widget.drill,
        widget.config.drillRepeat,
        settings.replayIntroOnBpmIncrease,
      );
      if (!next.playing) break;
    }
    _applyState(next);
  }

  int _flatIndexOf(_PState s) {
    final idx = _allSections.indexWhere(
      (fs) => fs.rowIndex == s.row && fs.sectionIndex == s.section,
    );
    return idx >= 0 ? idx : 0;
  }

  // Scrolls the now-current section to the top of the viewport (or, while the intro countdown is
  // playing, back to the very top so the countdown shows), but only when that actually changed --
  // a new section, the intro starting/ending, or the drill wrapping around -- not on every beat
  // tick, which would keep restarting the animation.
  void _scrollIfMoved(_PState prev, _PState next) {
    final prevIdx = _flatIndexOf(prev);
    final nextIdx = _flatIndexOf(next);
    if (prevIdx == nextIdx && prev.intro == next.intro && prev.drillRepeat == next.drillRepeat) {
      return;
    }
    // Wait for this frame's layout so the target's position reflects the state just applied.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (next.intro) {
        _scrollController.animateTo(0, duration: _scrollDuration, curve: _scrollCurve);
      } else {
        final target = _sectionKeys[nextIdx].currentContext;
        if (target == null) return;
        Scrollable.ensureVisible(
          target,
          alignment: 0,
          duration: _scrollDuration,
          curve: _scrollCurve,
        );
      }
    });
  }

  // Keeps [_lastSectionHeight] in sync with the last section's actual laid-out height, which the
  // trailing spacer in [build] needs. Section heights depend on the available width (and so change
  // on rotation/resizing), so this re-checks after every build, but only rebuilds on a change.
  void _measureLastSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _sectionKeys.last.currentContext?.size?.height;
      if (height != null && height != _lastSectionHeight) {
        setState(() => _lastSectionHeight = height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final drill = widget.drill;
    final idx = _flatIndexOf(_state);
    final safeAreaPadding = MediaQuery.of(context).padding;
    final hasHorizontalSafeArea = safeAreaPadding.left > 0 || safeAreaPadding.right > 0;

    Widget mkSectionView(Section section, bool isHighlighted) {
      return SectionView(
        section: section,
        isHighlighted: isHighlighted,
        repeatDotsFilled: isHighlighted ? _state.repeat + 1 : 0,
        highlight: (isHighlighted && _state.playing && settings.showBouncingDot)
            ? Pos(
                row: _state.row,
                section: _state.section,
                line: _state.line,
                measure: _state.measure,
                offset: _state.offset,
                repeat: _state.repeat,
              )
            : null,
      );
    }

    final isBpmUp = _state.drillRepeat > 0 && _state.bpmIncrease > 0;
    final isRepeat = _state.drillRepeat > 0;

    _measureLastSection();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: _scrollController,
        // On devices with no horizontal safe-area inset (no notch/rounded-corner cutout to clear in
        // landscape), content otherwise runs flush to the screen edge; add a little breathing room
        // ourselves. Devices that already have a horizontal safe-area inset are left as-is.
        padding: EdgeInsets.fromLTRB(
          hasHorizontalSafeArea ? 0 : 10,
          0,
          hasHorizontalSafeArea ? 0 : 10,
          0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                CountdownSection(
                  beat: _state.beat,
                  beatsPerMeasure: drill.bpm,
                  intro: _state.intro,
                  preText: isBpmUp ? 'BPM up!' : (isRepeat ? 'Back to the start!' : 'Get ready...'),
                ),
                for (var i = 0; i < _allSections.length; i++) ...[
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _sectionKeys[i],
                    child: mkSectionView(_allSections[i].section, !_state.intro && i == idx),
                  ),
                ],
                // Enough trailing room that even the last section can be scrolled all the way to the
                // top of the viewport, rather than the list running out of scroll extent first.
                SizedBox(height: math.max(16, constraints.maxHeight - _lastSectionHeight)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
