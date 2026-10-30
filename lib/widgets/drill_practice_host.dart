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
/// and a cream HUD (back button, [title] and [subtitle], the [DrillStatusView] readouts and a
/// [PauseButton]), plus an optional [sidebarFooter] below the readouts in the landscape sidebar.
/// Owns the [Metronome] and live-status notifier that the playfield and HUD share. When the drill
/// finishes on its own, it's recorded in the [practiceLog] before [onDone] is called.
///
/// Give this a fresh [Key] (e.g. keyed by the drill's id or an index) when reusing it across a
/// sequence of drills, so each gets its own freshly-initialized metronome/status/drill state
/// instead of one being update-reused for another.
class DrillPracticeHost extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Drill drill;
  final DrillConfig config;
  // E.g. ALL CLEAR!, celebrated once the drill is done.
  final String clearText;
  // E.g. a playlist run's progress, shown in the sidebar (only) below the readouts.
  final Widget? sidebarFooter;
  final VoidCallback onDone;

  const DrillPracticeHost({
    super.key,
    required this.title,
    this.subtitle,
    required this.drill,
    required this.config,
    this.clearText = 'ALL CLEAR!',
    this.sidebarFooter,
    required this.onDone,
  });

  @override
  State<DrillPracticeHost> createState() => _DrillPracticeHostState();
}

class _DrillPracticeHostState extends State<DrillPracticeHost> {
  late final Metronome _metronome = Metronome();
  late final ValueNotifier<DrillRunStatus> _status = ValueNotifier(
    DrillRunStatus(
      bpm: widget.config.bpm,
      bpmIncrease: widget.config.bpmIncrease,
      drillRepeat: widget.config.drillRepeat,
      drillRepeatCount: 0,
      elapsedSeconds: 0,
      totalSeconds: drillDuration(widget.drill, widget.config),
    ),
  );

  @override
  void dispose() {
    _metronome.dispose();
    _status.dispose();
    super.dispose();
  }

  void _handleDone() {
    practiceLog.recordDrill(widget.drill, widget.config);
    widget.onDone();
  }

  Widget _statusView({required bool vertical}) => ValueListenableBuilder(
    valueListenable: _status,
    builder: (context, status, _) => DrillStatusView(status: status, vertical: vertical),
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
              drill: widget.drill,
              config: widget.config,
              clearText: widget.clearText,
              metronome: _metronome,
              status: _status,
              onDone: _handleDone,
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
              Expanded(child: HudTitle(widget.title, subtitle: widget.subtitle)),
              const SizedBox(width: 12),
              PauseButton(metronome: _metronome),
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
              Expanded(child: HudTitle(widget.title, subtitle: widget.subtitle, sidebar: true)),
            ],
          ),
          const SizedBox(height: 14),
          PauseButton(metronome: _metronome, showLabel: true),
          const SizedBox(height: 14),
          _statusView(vertical: true),
          if (widget.sidebarFooter case final footer?) ...[const SizedBox(height: 14), footer],
        ],
      ),
    );
  }
}
