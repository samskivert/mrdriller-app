import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../services/metronome_sounds.dart';
import '../state/drill_config.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import 'arcade.dart';
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

// Vertical space between the cards in the list.
const double _gap = 16;

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
    final restart = prev.bpmIncrease > 0 && replayIntroOnBpmIncrease;
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
/// a playlist, etc). There's no dedicated "stop" affordance here -- the caller's own back
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
  // Shown on the card after the drill's last section, and celebrated once it's done.
  final String clearText;
  final DrillConfig config;
  final Metronome metronome;
  final ValueNotifier<DrillRunStatus> status;
  final VoidCallback onDone;

  const DrillPracticeView({
    super.key,
    required this.drill,
    this.clearText = 'ALL CLEAR!',
    required this.config,
    required this.metronome,
    required this.status,
    required this.onDone,
  });

  @override
  State<DrillPracticeView> createState() => _DrillPracticeViewState();
}

class _DrillPracticeViewState extends State<DrillPracticeView> with SingleTickerProviderStateMixin {
  late _PState _state;

  MetronomeSounds? _sounds;

  // widget.drill never changes for the lifetime of this widget (swapHands, if requested, was
  // already applied by the caller before it was ever handed to us), so unlike the overview screen
  // this only needs to be computed once.
  late final List<_FlatSection> _allSections = _flattenSections(widget.drill);

  // The list shows every pass through the drill, one after another: [_sectionKeys] is indexed by
  // [pass][flat section index], and [_interludeKeys] by pass, for the countdown/progress card that
  // opens each pass.
  late final List<List<GlobalKey>> _sectionKeys = [
    for (var p = 0; p < widget.config.drillRepeat; p++) [for (final _ in _allSections) GlobalKey()],
  ];
  late final List<GlobalKey> _interludeKeys = [
    for (var p = 0; p < widget.config.drillRepeat; p++) GlobalKey(),
  ];

  final _scrollController = ScrollController();
  final _allDoneKey = GlobalKey();
  double _tailHeight = 0;

  // Guards against onDone firing more than once (e.g. a beat tick arriving just as the drill
  // finishes).
  bool _finished = false;

  // Once the drill is finished: the clear celebration, which flies out of the clear card
  // from [_celebrationStart] (in the stack's coordinates) before [DrillPracticeView.onDone].
  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  final _stackKey = GlobalKey();
  bool _celebrating = false;
  Offset? _celebrationStart;
  bool _doneNotified = false;

  void _celebrate() {
    final card = _allDoneKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (card != null && stack != null && card.attached) {
      // (The keyed box includes the gap above the card itself.)
      final center = card.size.center(Offset.zero) + const Offset(0, _gap / 2);
      _celebrationStart = stack.globalToLocal(card.localToGlobal(center));
    }
    setState(() => _celebrating = true);
    _celebration.forward().whenComplete(_notifyDone);
  }

  void _notifyDone() {
    if (!mounted || _doneNotified) return;
    _doneNotified = true;
    widget.onDone();
  }

  // Fires [_start] one beat after the screen appears and the sounds are ready; until then, the
  // count-in overlay is up but hasn't started counting.
  Timer? _startTimer;
  bool _started = false;

  // How much of the drill's playing time has gone by, counted tick by tick at each tick's bpm (so
  // it lines up with computeDrillDuration's total), for the depth ruler.
  double _elapsedSeconds = 0;

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
    //
    // Then wait one more beat (as long as one call of the count-in) before starting, rather than
    // launching straight into the count-in the instant the screen appears.
    sounds.ready.then((_) {
      if (!mounted) return;
      final beatUs = widget.drill.bpm * 60e6 / widget.config.bpm / 4 * widget.drill.scale;
      _startTimer = Timer(Duration(microseconds: beatUs.round()), _start);
    });
  }

  void _start() {
    if (!mounted) return;
    setState(() => _started = true);
    _playBeatSound();
    _publishStatus();
    widget.metronome.ensureRunning(bpm: _state.bpm, scale: widget.drill.scale);
  }

  @override
  void dispose() {
    _celebration.dispose();
    _startTimer?.cancel();
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
        _celebrate();
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
      elapsedSeconds: _elapsedSeconds,
      totalSeconds: widget.status.value.totalSeconds,
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
      _elapsedSeconds += 60 / next.bpm / 4 * widget.drill.scale;
      next = _tick(
        next,
        widget.drill,
        widget.config.drillRepeat,
        widget.config.replayIntroOnBpmIncrease,
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

  // Scrolls the now-current card to the top of the viewport -- the interlude while its countdown
  // plays, otherwise the current section of the current pass -- but only when that actually
  // changed, not on every beat tick, which would keep restarting the animation.
  void _scrollIfMoved(_PState prev, _PState next) {
    if (!next.playing) return;
    final prevIdx = _flatIndexOf(prev);
    final nextIdx = _flatIndexOf(next);
    if (prevIdx == nextIdx && prev.intro == next.intro && prev.drillRepeat == next.drillRepeat) {
      return;
    }
    _scrollToCurrent(next);
  }

  void _scrollToCurrent(_PState s, {Duration duration = _scrollDuration}) {
    final key = s.intro
        ? _interludeKeys[s.drillRepeat]
        : _sectionKeys[s.drillRepeat][_flatIndexOf(s)];
    // Wait for this frame's layout so the target's position reflects the state just applied.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = key.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(target, alignment: 0, duration: duration, curve: _scrollCurve);
    });
  }

  // When the screen changes size (e.g. the phone rotates), every card is resized, which leaves the
  // current one wherever it lands in the old scroll offset; put it back at the top.
  Size? _lastScreenSize;

  void _rescrollIfResized(Size size) {
    final last = _lastScreenSize;
    _lastScreenSize = size;
    if (last != null && last != size && _state.playing) {
      _scrollToCurrent(_state, duration: Duration.zero);
    }
  }

  // Keeps [_tailHeight] in sync with the actual laid-out height of the very last section plus the
  // "All done!" card below it, which the trailing spacer in [build] needs. Heights depend on the
  // available width (and so change on rotation/resizing), so this re-checks after every build, but
  // only rebuilds on a change.
  void _measureTail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final section = _sectionKeys.last.last.currentContext?.size?.height;
      final allDone = _allDoneKey.currentContext?.size?.height;
      if (section == null || allDone == null) return;
      // (Both heights already include the gap above each.)
      final height = section + allDone;
      if (height != _tailHeight) setState(() => _tailHeight = height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final drill = widget.drill;
    final idx = _flatIndexOf(_state);
    final safeAreaPadding = MediaQuery.of(context).padding;
    final hasHorizontalSafeArea = safeAreaPadding.left > 0 || safeAreaPadding.right > 0;

    Widget mkSectionView(int pass, int index) {
      final isHighlighted = !_state.intro && _state.drillRepeat == pass && index == idx;
      final isDone =
          pass < _state.drillRepeat || (pass == _state.drillRepeat && !_state.intro && index < idx);
      return SectionView(
        section: _allSections[index].section,
        isHighlighted: isHighlighted,
        isDone: isDone,
        bannerColor: AppColors.banner(index),
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

    // Every pass opens with one of these, showing which pass it is and its bpm. While a pass is
    // counting in (ichi-ni-so-re), it's scrolled to the top, with the count-in overlaid on top of
    // it and the pass's first sections.
    Widget mkInterlude(int pass) {
      final config = widget.config;
      return _PassSeparator(
        pass: pass,
        passes: config.drillRepeat,
        bpm: (config.bpm + config.bpmIncrease * pass).clamp(0, maxBpm),
      );
    }

    // Never scrolled to itself (the drill just ends once the last section finishes), but visible
    // below the last section as a heads-up while it plays.
    final allDone = PlayfieldPanel(
      minHeight: 100,
      padding: const EdgeInsets.all(16),
      // Its text flies out of the card for the celebration once the drill is done.
      child: Opacity(
        opacity: _celebrating ? 0 : 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: PuffyText(
            widget.clearText,
            size: 36,
            color: AppColors.gold,
            shadow: AppColors.goldOutline,
          ),
        ),
      ),
    );

    _measureTail();

    _rescrollIfResized(MediaQuery.sizeOf(context));
    final counting = _state.playing && _state.intro;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        key: _stackKey,
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            // On devices with no horizontal safe-area inset (no notch/rounded-corner cutout to
            // clear in landscape), content otherwise runs flush to the screen edge; add a little
            // breathing room ourselves. Devices that already have a horizontal safe-area inset are
            // left as-is.
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
                  // Each card carries the gap above it as its own top padding, so that scrolling a
                  // card to the top of the viewport leaves that gap above it (and room for an
                  // active card's glow) rather than butting it right up against the viewport's
                  // edge.
                  children: [
                    for (var p = 0; p < widget.config.drillRepeat; p++) ...[
                      KeyedSubtree(
                        key: _interludeKeys[p],
                        child: Padding(
                          padding: const EdgeInsets.only(top: _gap),
                          child: mkInterlude(p),
                        ),
                      ),
                      for (var i = 0; i < _allSections.length; i++)
                        KeyedSubtree(
                          key: _sectionKeys[p][i],
                          child: Padding(
                            padding: const EdgeInsets.only(top: _gap),
                            // The scroll view would otherwise give each section unbounded height,
                            // so SectionView would size itself to the width alone. Capping it at
                            // the viewport's height makes each section shrink (individually, only
                            // as much as it needs) to fit entirely on screen once scrolled to the
                            // top.
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight - _gap * 2,
                              ),
                              child: mkSectionView(p, i),
                            ),
                          ),
                        ),
                    ],
                    KeyedSubtree(
                      key: _allDoneKey,
                      child: Padding(
                        padding: const EdgeInsets.only(top: _gap),
                        child: allDone,
                      ),
                    ),
                    // Enough trailing room that even the last section can be scrolled all the way
                    // to the top of the viewport, rather than the list running out of scroll extent
                    // first.
                    SizedBox(height: math.max(_gap, constraints.maxHeight - _tailHeight)),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !counting,
              child: AnimatedOpacity(
                opacity: counting ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: CountInOverlay(
                  index: _started ? _state.beat ~/ drill.bpm : -1,
                  heading: _state.drillRepeat > 0 && widget.config.bpmIncrease > 0
                      ? 'BPM UP'
                      : 'GET READY',
                  details: widget.config.drillRepeat > 1
                      ? '${_state.bpm} BPM · LOOP ${_state.drillRepeat + 1}/${widget.config.drillRepeat}'
                      : '${_state.bpm} BPM',
                ),
              ),
            ),
          ),
          if (_celebrating)
            Positioned.fill(
              child: GestureDetector(
                // A tap skips the rest of the celebration.
                onTap: _notifyDone,
                child: ClearCelebration(
                  text: widget.clearText,
                  animation: _celebration,
                  start: _celebrationStart,
                  textSize: 36,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A divider between passes through the drill: a HUD card reading e.g. "LOOP 2/3 BPM 101" (in
/// banners and digit tiles, like the HUD sidebar) between two lines. (Just the bpm, for a drill
/// that's only played once.)
class _PassSeparator extends StatelessWidget {
  final int pass;
  final int passes;
  final int bpm;

  const _PassSeparator({required this.pass, required this.passes, required this.bpm});

  Widget _line(bool leading) => Expanded(
    child: Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [AppColors.gold.withValues(alpha: 0), AppColors.gold.withValues(alpha: 0.7)],
          begin: leading ? Alignment.centerLeft : Alignment.centerRight,
          end: leading ? Alignment.centerRight : Alignment.centerLeft,
        ),
      ),
    ),
  );

  Widget _banner(String label, Color color) => HudBanner(
    label: label,
    color: color,
    fontSize: 18,
    borderRadius: BorderRadius.circular(13),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => _build(constraints.maxWidth));
  }

  Widget _build(double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _line(true),
          // Shrinks to fit on a narrow phone (always leaving a little of each line showing), rather
          // than overflowing.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.max(0, width - 40)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (passes > 1) ...[
                      _banner('Loop', AppColors.bannerRed),
                      const SizedBox(width: 12),
                      DigitTiles(value: '${pass + 1}/$passes', height: 42),
                      const SizedBox(width: 21),
                    ],
                    _banner('BPM', AppColors.bannerOrange),
                    const SizedBox(width: 12),
                    DigitTiles(value: '$bpm', height: 42),
                  ],
                ),
              ),
            ),
          ),
          _line(false),
        ],
      ),
    );
  }
}

/// The end-of-drill celebration (shown by [DrillPracticeView] once a drill is finished): over a
/// darkening scrim, [text] (e.g. ALL CLEAR!) flies from [start] (where it sat in the clear card, at
/// [textSize]; the bottom of the view if unknown) to the center, growing with a springy bounce to
/// as big as fits on screen, in front of a slowly turning starburst and a burst of candy stars.
class ClearCelebration extends StatelessWidget {
  final String text;
  final Animation<double> animation;
  final Offset? start;
  final double textSize;

  const ClearCelebration({
    super.key,
    required this.animation,
    required this.start,
    required this.textSize,
    this.text = 'ALL CLEAR!',
  });

  static const _fly = Interval(0, 0.35, curve: Curves.easeOutCubic);
  static const _grow = Interval(0, 0.5, curve: Curves.elasticOut);
  static const _scrim = Interval(0, 0.2, curve: Curves.easeOut);
  static const _burst = Interval(0.12, 0.85, curve: Curves.easeOutCubic);

  // The text, and the largest font size at which it fits within [screen] with some room to spare.
  (String, double) _fit(Size screen) {
    Size measure(String text) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontFamily: AppFonts.display, fontSize: 100, height: 1.1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    var best = ('', 0.0);
    // On one line, or broken over two at its first space.
    for (final text in [this.text, this.text.replaceFirst(' ', '\n')]) {
      final at100 = measure(text);
      final fontSize = math.min(
        100 * screen.width * 0.82 / at100.width,
        100 * screen.height * 0.5 / at100.height,
      );
      if (fontSize > best.$2) best = (text, fontSize);
    }
    return (best.$1, math.min(best.$2, 120));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = size.center(Offset.zero);
        final from = start ?? Offset(center.dx, size.height);
        // As big as fits on screen: on one line, or broken over two if that allows bigger text
        // (e.g. on a phone in portrait).
        final (text, bigSize) = _fit(size);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final pos = Offset.lerp(from, center, _fly.transform(t))!;
            final scale = textSize / bigSize + (1 - textSize / bigSize) * _grow.transform(t);
            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFF090E20).withValues(alpha: 0.8 * _scrim.transform(t)),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BlingPainter(
                      center: center,
                      reach: size.shortestSide * 0.48,
                      rays: _scrim.transform(t),
                      burst: _burst.transform(t),
                      spin: t,
                    ),
                  ),
                ),
                Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Transform.scale(
                      scale: scale,
                      child: PuffyText(
                        text,
                        size: bigSize,
                        color: AppColors.gold,
                        shadow: AppColors.goldOutline,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BlingPainter extends CustomPainter {
  final Offset center;
  final double reach;
  // 0..1: how far the starburst rays have faded in, and the stars have flown out.
  final double rays;
  final double burst;
  final double spin;

  _BlingPainter({
    required this.center,
    required this.reach,
    required this.rays,
    required this.burst,
    required this.spin,
  });

  static const _stars = 16;
  static const _colors = [
    AppColors.gold,
    Color(0xFFFF6FA0),
    Color(0xFF3BA4F0),
    Color(0xFF49C96B),
    Color(0xFFFFAE1F),
  ];

  Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // A slowly turning starburst of soft gold rays, like a stage-clear screen.
    if (rays > 0) {
      final rayPaint = Paint()..color = AppColors.gold.withValues(alpha: 0.16 * rays);
      final far = size.longestSide;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(spin * math.pi / 3);
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a - 0.12) * far, math.sin(a - 0.12) * far)
            ..lineTo(math.cos(a + 0.12) * far, math.sin(a + 0.12) * far)
            ..close(),
          rayPaint,
        );
      }
      canvas.restore();
    }

    // A ring of candy stars bursting outwards, spinning, and fading as they go.
    if (burst > 0 && burst < 1) {
      final fade = burst < 0.7 ? 1.0 : (1 - burst) / 0.3;
      for (var i = 0; i < _stars; i++) {
        // Alternate long and short throws, so it reads as a burst rather than a single ring.
        final a = i * 2 * math.pi / _stars + (i.isEven ? 0 : math.pi / _stars);
        final dist = reach * burst * (i.isEven ? 1 : 0.68);
        final r = reach * (i.isEven ? 0.07 : 0.05) * (0.4 + 0.6 * math.min(1, burst * 3));
        final color = _colors[i % _colors.length];
        canvas.save();
        canvas.translate(center.dx + math.cos(a) * dist, center.dy + math.sin(a) * dist);
        canvas.rotate(burst * math.pi * (i.isEven ? 1.5 : -1.5));
        final star = _star(r);
        canvas.drawPath(
          star,
          Paint()
            ..color = Colors.white.withValues(alpha: fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.35
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(star, Paint()..color = color.withValues(alpha: fade));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlingPainter old) =>
      old.rays != rays || old.burst != burst || old.spin != spin || old.center != center;
}
