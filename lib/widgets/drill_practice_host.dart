import 'package:flutter/material.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../state/drill_config.dart';
import 'app_header.dart';
import 'drill_practice_view.dart';
import 'drill_status_view.dart';

/// The screen-level shell for running one drill: a [Scaffold] with an [AppHeader] titled [title],
/// hosting a [DrillPracticeView] for [drill]/[config]. Owns the [Metronome] and live-status
/// notifier that [DrillPracticeView] and [DrillStatusView] both need, and decides where the status
/// (bpm/repeat/Pause) goes -- merged into the header's trailing slot to save vertical space on a
/// short landscape phone, or in its own row above the drill content otherwise.
///
/// Give this a fresh [Key] (e.g. keyed by the drill's id or an index) when reusing it across a
/// sequence of drills, so each gets its own freshly-initialized metronome/status/drill state
/// instead of one being update-reused for another.
class DrillPracticeHost extends StatefulWidget {
  final String title;
  final Drill drill;
  final DrillConfig config;
  final VoidCallback onDone;

  const DrillPracticeHost({
    super.key,
    required this.title,
    required this.drill,
    required this.config,
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
    ),
  );

  @override
  void dispose() {
    _metronome.dispose();
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Short-and-wide, like a phone held sideways — as opposed to a desktop/web window that
    // happens to be wider than tall but still has plenty of vertical room to spare. Only the
    // former is cramped enough to be worth reclaiming the status row's height for.
    final screenSize = MediaQuery.of(context).size;
    final isCompactLandscape = screenSize.width > screenSize.height && screenSize.height < 500;

    Widget statusFor(bool compact) => ValueListenableBuilder(
      valueListenable: _status,
      builder: (context, status, _) =>
          DrillStatusView(status: status, metronome: _metronome, compact: compact),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppHeader(
                title: widget.title,
                showSettings: false,
                trailing: isCompactLandscape ? statusFor(true) : null,
              ),
            ),
            if (!isCompactLandscape) ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: statusFor(false)),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: DrillPracticeView(
                drill: widget.drill,
                config: widget.config,
                metronome: _metronome,
                status: _status,
                onDone: widget.onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
