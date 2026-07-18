import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../services/metronome_sounds.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/app_header.dart';
import '../widgets/components.dart';
import '../widgets/section_view.dart';
import '../widgets/slide_in.dart';

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

/// Advances the drill state machine by exactly one tick (one sixteenth-note-ish subdivision).
_PState _tick(
  _PState prev,
  Drill drill,
  int drillRepeatTarget,
  bool replayIntroOnBpmIncrease,
) {
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
    final restart =
        (prev.bpmIncrease > 0 && replayIntroOnBpmIncrease) || drill.forceIntro;
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

/// Runs an active practice session for [drill] at the given starting [bpm]/[bpmIncrease]/
/// [drillRepeat] -- the metronome, the state machine driving which section is current, and the
/// section/countdown visuals. [drill] is expected to already be the one the user will actually
/// see (e.g. with swapHands already applied), since this screen has no notion of that config --
/// it just plays whatever [Drill] it's handed.
class DrillPracticeScreen extends StatefulWidget {
  final Drill drill;
  final int bpm;
  final int bpmIncrease;
  final int drillRepeat;

  const DrillPracticeScreen({
    super.key,
    required this.drill,
    required this.bpm,
    required this.bpmIncrease,
    required this.drillRepeat,
  });

  @override
  State<DrillPracticeScreen> createState() => _DrillPracticeScreenState();
}

class _DrillPracticeScreenState extends State<DrillPracticeScreen> {
  late _PState _state;

  MetronomeSounds? _sounds;
  late final _metronome = Metronome(onDue: _handleBeatsDue);

  // widget.drill never changes for the lifetime of this screen (swapHands, if requested, was
  // already applied by the caller before it was ever navigated to), so unlike the overview screen
  // this only needs to be computed once.
  late final List<_FlatSection> _allSections = _flattenSections(widget.drill);

  @override
  void initState() {
    super.initState();
    final sounds = MetronomeSounds();
    _sounds = sounds;
    _state = _PState(
      playing: true,
      intro: true,
      bpm: widget.bpm,
      bpmIncrease: widget.bpmIncrease,
    );
    // Wait for the tones to finish loading before processing the very first beat -- otherwise
    // that first beep/boop races the (asynchronous, even for these tiny local assets) load and
    // silently gets dropped, which is why the drill would seem to start on its *second* audible
    // tick instead of its first.
    sounds.ready.then((_) {
      if (!mounted) return;
      _afterStateChange();
    });
  }

  @override
  void dispose() {
    _metronome.dispose();
    _sounds?.dispose();
    WakelockPlus.disable();
    super.dispose();
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
      // _tick only ever produces a non-playing state by running out of repeats -- a manual Stop
      // pops directly instead of going through _applyState. Mirror the original single-screen
      // behavior of returning to the overview the instant the drill finishes on its own.
      if (mounted) Navigator.of(context).pop();
    }
    if (s.playing) {
      _metronome.ensureRunning(bpm: s.bpm, scale: widget.drill.scale);
    } else {
      _metronome.stop();
    }
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
        widget.drillRepeat,
        settings.replayIntroOnBpmIncrease,
      );
      if (!next.playing) break;
    }
    _applyState(next);
  }

  // For now, Stop does the same thing as the back button: abandon the session and return to the
  // drill's overview/config screen. dispose() above tears down the timer/sounds/wakelock either
  // way, since this whole screen is what gets popped.
  void _handleStop() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final drill = widget.drill;
    final allSections = _allSections;
    final currentFlatIndex = allSections.indexWhere(
      (s) => s.rowIndex == _state.row && s.sectionIndex == _state.section,
    );
    final idx = currentFlatIndex >= 0 ? currentFlatIndex : 0;
    final willRepeatDrill = _state.drillRepeat + 1 < widget.drillRepeat;
    final willAnnounceRepeat =
        willRepeatDrill && (_state.bpmIncrease > 0 || drill.forceIntro);
    final isLastSection = idx == allSections.length - 1;
    final currentSection = allSections[idx].section;
    final safeAreaPadding = MediaQuery.of(context).padding;
    final hasHorizontalSafeArea =
        safeAreaPadding.left > 0 || safeAreaPadding.right > 0;
    // Short-and-wide, like a phone held sideways — as opposed to a desktop/web window that
    // happens to be wider than tall but still has plenty of vertical room to spare. Only the
    // former is cramped enough to be worth reclaiming the status row's height for.
    final screenSize = MediaQuery.of(context).size;
    final isCompactLandscape =
        screenSize.width > screenSize.height && screenSize.height < 500;
    final mergeStatusIntoHeader = isCompactLandscape;

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

    Widget countdownSectionEl() {
      final isBpmUp = _state.drillRepeat > 0 && _state.bpmIncrease > 0;
      final isRepeat = _state.drillRepeat > 0;
      return CountdownSection(
        beat: _state.beat,
        beatsPerMeasure: drill.bpm,
        intro: _state.intro,
        preText: isBpmUp
            ? 'BPM up!'
            : (isRepeat ? 'Back to the start!' : 'Get ready...'),
      );
    }

    final topKey = _state.intro
        ? 'countdown-${_state.drillRepeat}'
        : 'section-$idx-${_state.drillRepeat}';
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

    Widget topContent() => _state.intro
        ? countdownSectionEl()
        : mkSectionView(currentSection, true);

    Widget bottomContent() {
      if (bottomKey == 'all-done') {
        return HighlightedCard(
          isHighlighted: false,
          minHeight: 100,
          child: Center(
            child: Text(
              'All done!',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: AppColors.textGray,
              ),
            ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppHeader(
                title: drill.title,
                trailing: mergeStatusIntoHeader
                    ? _HeaderStatus(
                        bpm: _state.bpm,
                        bpmIncrease: _state.bpmIncrease,
                        drillRepeat: widget.drillRepeat,
                        drillRepeatCount: _state.drillRepeat,
                        onStop: _handleStop,
                      )
                    : null,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                // On devices with no horizontal safe-area inset (no notch/rounded-corner cutout
                // to clear in landscape), content otherwise runs flush to the screen edge; add a
                // little breathing room ourselves. Devices that already have a horizontal
                // safe-area inset are left as-is.
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hasHorizontalSafeArea ? 0 : 10,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    // The drill controls what's on screen now, not a scroll view, so it's
                    // expected that the current section + preview sometimes won't all fit (e.g.
                    // a tall section on a short landscape phone). Clipping here tells Flutter
                    // that's intentional: clip the excess instead of raising the debug-only
                    // "RenderFlex overflowed" warning for expected behavior. (Column doesn't
                    // expose clipBehavior itself, so wrap it in ClipRect.)
                    child: ClipRect(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!mergeStatusIntoHeader) ...[
                            _StatusView(
                              bpm: _state.bpm,
                              bpmIncrease: _state.bpmIncrease,
                              drillRepeat: widget.drillRepeat,
                              drillRepeatCount: _state.drillRepeat,
                              onStop: _handleStop,
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Mirrors the web version's persistent-slot animation: content swaps
                          // instantly (like a Solid re-render), and a pure slide transform
                          // carries the already-updated slot up from roughly where the bottom
                          // preview card sat into its resting position. The changing `key`
                          // mounts a fresh SlideIn instance, which is what makes the animation
                          // restart each time (see widgets/slide_in.dart for why
                          // TweenAnimationBuilder can't do this).
                          SlideIn(key: ValueKey(topKey), child: topContent()),
                          const SizedBox(height: 16),
                          // Bottom preview fades in only after the top slide above finishes (a
                          // 400ms delay, then a 300ms fade), matching the original timing.
                          FadeInDelayed(
                            key: ValueKey(bottomKey),
                            child: bottomContent(),
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
            ),
          ],
        ),
      ),
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
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textGray,
          ),
        ),
        if (drillRepeat > 1)
          Text(
            '${drillRepeatCount + 1} / $drillRepeat',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
            ),
          ),
        ElevatedButton(
          onPressed: onStop,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.btnRed,
            foregroundColor: Colors.white,
          ),
          child: const Text('Stop'),
        ),
      ],
    );
  }
}

/// Compact stand-in for [_StatusView], shown inline in the header (in place of the settings
/// gear) instead of in its own row when the screen is too short to spare that row's height.
class _HeaderStatus extends StatelessWidget {
  final int bpm;
  final int bpmIncrease;
  final int drillRepeat;
  final int drillRepeatCount;
  final VoidCallback onStop;

  const _HeaderStatus({
    required this.bpm,
    required this.bpmIncrease,
    required this.drillRepeat,
    required this.drillRepeatCount,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$bpm bpm${bpmIncrease > 0 ? ' (+$bpmIncrease)' : ''}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textGray,
          ),
        ),
        if (drillRepeat > 1) ...[
          const SizedBox(width: 12),
          Text(
            '${drillRepeatCount + 1} / $drillRepeat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
            ),
          ),
        ],
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onStop,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.btnRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Stop'),
        ),
      ],
    );
  }
}
