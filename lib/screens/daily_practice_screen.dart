import 'dart:async';

import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/practice_log.dart';
import '../state/practice_plan.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/app_header.dart';
import '../widgets/components.dart';
import '../widgets/drill_practice_host.dart';

const _introDuration = Duration(seconds: 5);

enum _Phase { intro, running, outro }

/// Runs through every drill in the user's practice plan, one at a time: a few seconds showing the
/// drill's name/config (the "intro"), then the drill itself via [DrillPracticeView], then the next
/// drill's intro, and so on -- ending on a summary/congratulations screen once every drill in the
/// plan has been completed. The header's back button abandons the whole session, not just the
/// current drill.
class DailyPracticeScreen extends StatefulWidget {
  const DailyPracticeScreen({super.key});

  @override
  State<DailyPracticeScreen> createState() => _DailyPracticeScreenState();
}

class _DailyPracticeScreenState extends State<DailyPracticeScreen> {
  late final List<PracticePlanEntry> _entries = practicePlan.entries;

  int _index = 0;
  _Phase _phase = _Phase.intro;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    _goToIndex(0);
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  // A drill referenced by the plan can, in principle, no longer exist (e.g. it was renamed or
  // removed from the catalog after being added to a saved plan) -- skip silently past any entry
  // that no longer resolves rather than getting stuck or crashing.
  void _goToIndex(int index) {
    var i = index;
    while (i < _entries.length && data.findDrillById(_entries[i].drillId) == null) {
      i++;
    }
    _introTimer?.cancel();
    if (i >= _entries.length) {
      setState(() {
        _index = i;
        _phase = _Phase.outro;
      });
      return;
    }
    setState(() {
      _index = i;
      _phase = _Phase.intro;
    });
    _introTimer = Timer(_introDuration, () {
      if (!mounted) return;
      setState(() => _phase = _Phase.running);
    });
  }

  void _handleDrillDone() => _goToIndex(_index + 1);

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.running) {
      final entry = _entries[_index];
      final drill = _activeDrillFor(entry)!;
      return DrillPracticeHost(
        key: ValueKey(_index),
        title: '${drill.title} - ${_index + 1} of ${_entries.length}',
        drill: drill,
        config: entry.config,
        onDone: _handleDrillDone,
      );
    }

    final Widget content;
    final String title;
    if (_phase == _Phase.outro) {
      title = 'Practice Complete';
      content = _OutroView(entries: _entries);
    } else {
      final entry = _entries[_index];
      final drill = _activeDrillFor(entry)!;
      title = 'Drill ${_index + 1} of ${_entries.length}';
      content = _IntroView(drill: drill, config: entry.config);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppHeader(title: title, showSettings: false),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Drill? _activeDrillFor(PracticePlanEntry entry) {
    final drill = data.findDrillById(entry.drillId);
    if (drill == null) return null;
    return entry.config.swapHands ? swapHands(drill) : drill;
  }
}

class _IntroView extends StatelessWidget {
  final Drill drill;
  final DrillConfig config;

  const _IntroView({required this.drill, required this.config});

  @override
  Widget build(BuildContext context) {
    final duration = formatDrillDuration(
      computeDrillDuration(
        drill,
        config.bpm,
        config.bpmIncrease,
        config.drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: HighlightedCard(
            isHighlighted: true,
            minHeight: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  drill.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.btnBlue,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${formatBpmSummary(config.bpm, config.bpmIncrease)} · x${config.drillRepeat}'
                  '${config.swapHands ? ' · R↔︎L' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: AppColors.textGray),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textGray),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutroView extends StatelessWidget {
  final List<PracticePlanEntry> entries;

  const _OutroView({required this.entries});

  // Only entries that actually resolved to a real drill (and so actually got practiced) count
  // toward the log -- an entry whose drill no longer exists was silently skipped, not completed.
  Iterable<({Drill drill, DrillConfig config})> get _completed sync* {
    for (final entry in entries) {
      final drill = data.findDrillById(entry.drillId);
      if (drill != null) yield (drill: drill, config: entry.config);
    }
  }

  // The drill's own computed duration, not wall-clock time actually spent -- this way pausing
  // mid-drill (or the 5-second intro between drills) doesn't affect the logged total.
  void _handleLogIt(BuildContext context) {
    var totalSeconds = 0.0;
    var count = 0;
    for (final c in _completed) {
      count++;
      totalSeconds += computeDrillDuration(
        c.drill,
        c.config.bpm,
        c.config.bpmIncrease,
        c.config.drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      );
    }
    practiceLog.add(
      PracticeLogEntry(
        completedAt: DateTime.now(),
        drillCount: count,
        totalSeconds: totalSeconds.round(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed.map((c) => c.drill).toList();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, size: 64, color: AppColors.btnGreen),
              const SizedBox(height: 16),
              Text(
                'Great practice!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You completed ${completed.length} '
                'drill${completed.length == 1 ? '' : 's'}:',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGray),
              ),
              const SizedBox(height: 16),
              for (final drill in completed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    drill.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _handleLogIt(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.btnGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Log it!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
