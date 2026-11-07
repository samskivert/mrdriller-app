import 'package:flutter/material.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../state/drill_config.dart';
import '../state/practice_log.dart';
import 'arcade.dart';
import 'drill_practice_view.dart';
import 'drill_status_view.dart';
import 'hud_layout.dart';

/// The screen-level shell for running one drill, laid out like the arcade game (see [HudLayout]):
/// a navy playfield with a rainbow depth ruler, hosting a [DrillPracticeView] for [drill]/[config],
/// and a cream HUD (back button, [title], the [DrillStatusView] readouts (plus [extraReadout], if
/// any) and a [PauseButton], which becomes a [ReplayButton] once the drill is done, or (with a
/// [nextLabel]) a [NextButton]).
/// Owns the [Metronome] and live-status notifier that the playfield and HUD share. When the drill
/// finishes on its own, it's recorded in the [practiceLog] (whether or not [onDone] follows: the
/// player can leave from its results instead).
///
/// Give this a fresh [Key] (e.g. keyed by the drill's id or an index) when reusing it across a
/// sequence of drills, so each gets its own freshly-initialized metronome/status/drill state
/// instead of one being update-reused for another.
class DrillPracticeHost extends StatefulWidget {
  final String title;
  final Drill drill;
  final DrillConfig config;
  // E.g. ALL CLEAR!, celebrated once the drill is done.
  final String clearText;
  // E.g. a playlist run's progress.
  final ExtraReadout? extraReadout;
  final VoidCallback onDone;
  // How long the summary of graded hits waits before moving on (see DrillPracticeView).
  final Duration? summaryTimeout;
  // In a sequence of drills (e.g. a playlist), what the button the pause button becomes once the
  // drill is done says (e.g. Next drill): it moves on ([onDone]) straight away. Without one, it's
  // a button to replay the drill.
  final String? nextLabel;

  const DrillPracticeHost({
    super.key,
    required this.title,
    required this.drill,
    required this.config,
    this.clearText = 'ALL CLEAR!',
    this.extraReadout,
    required this.onDone,
    this.summaryTimeout,
    this.nextLabel,
  });

  @override
  State<DrillPracticeHost> createState() => _DrillPracticeHostState();
}

class _DrillPracticeHostState extends State<DrillPracticeHost> {
  late final Metronome _metronome = Metronome();
  late final ValueNotifier<DrillRunStatus> _status = ValueNotifier(_startingStatus());
  // Once the drill has finished, the pause button becomes a replay button. Each replay is a fresh
  // run of the drill, keyed by [_run].
  var _finished = false;
  var _run = 0;
  // Whether it's moved on from the drill (by its next button), which it only does once.
  var _movedOn = false;

  DrillRunStatus _startingStatus() => DrillRunStatus(
    bpm: widget.config.bpm,
    bpmIncrease: widget.config.bpmIncrease,
    drillRepeat: widget.config.drillRepeat,
    drillRepeatCount: 0,
    elapsedSeconds: 0,
    totalSeconds: drillDuration(widget.drill, widget.config),
  );

  @override
  void dispose() {
    _metronome.dispose();
    _status.dispose();
    super.dispose();
  }

  void _handleFinished() {
    practiceLog.recordDrill(widget.drill, widget.config);
    setState(() => _finished = true);
  }

  // Plays the drill again from the start, with a new DrillPracticeView (and everything it has).
  void _replay() {
    _metronome.stop();
    _status.value = _startingStatus();
    setState(() {
      _finished = false;
      _run++;
    });
  }

  // Moves on from the drill straight away, skipping the rest of its celebration or results.
  void _next() {
    if (_movedOn) return;
    _movedOn = true;
    widget.onDone();
  }

  Widget _playButton({bool showLabel = false}) {
    if (!_finished) return PauseButton(metronome: _metronome, showLabel: showLabel);
    if (widget.nextLabel case final label?) {
      return NextButton(label: label, onPressed: _next, showLabel: showLabel);
    }
    return ReplayButton(onPressed: _replay, showLabel: showLabel);
  }

  Widget _statusView({required bool vertical}) => ValueListenableBuilder(
    valueListenable: _status,
    builder: (context, status, _) =>
        DrillStatusView(status: status, vertical: vertical, extra: widget.extraReadout),
  );

  @override
  Widget build(BuildContext context) {
    return HudLayout(
      playfield: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 0, 16),
            child: ValueListenableBuilder(
              valueListenable: _status,
              builder: (context, status, _) => DepthRuler(progress: status.progress),
            ),
          ),
          Expanded(
            child: DrillPracticeView(
              key: ValueKey(_run),
              drill: widget.drill,
              config: widget.config,
              clearText: widget.clearText,
              metronome: _metronome,
              status: _status,
              onFinished: _handleFinished,
              onDone: _next,
              summaryTimeout: widget.summaryTimeout,
            ),
          ),
        ],
      ),
      hud: Column(
        children: [
          Row(
            children: [
              const HudBackButton(),
              const SizedBox(width: 12),
              Expanded(child: HudTitle(widget.title)),
              const SizedBox(width: 12),
              _playButton(),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _statusView(vertical: false),
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
              Expanded(child: HudTitle(widget.title, sidebar: true)),
            ],
          ),
          const SizedBox(height: 14),
          _playButton(showLabel: true),
          const SizedBox(height: 14),
          _statusView(vertical: true),
        ],
      ),
    );
  }
}
