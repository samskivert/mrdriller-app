import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/grading.dart';
import '../model/model.dart';
import '../model/timing.dart';
import '../state/drill_config.dart';
import '../state/playlists.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/results_popup.dart';
import '../widgets/section_view.dart';

/// For working on how things look (in debug builds only): a menu of screens to look at, filled in
/// with made-up data.
class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    void go(String route) => Navigator.of(context).pushNamed(route);
    return CreamScreen(
      title: 'Debug',
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CandyMenuButton(
                  title: 'Drill results',
                  subtitle: 'The results popup, over graded strokes',
                  icon: Icons.grading_rounded,
                  colors: AppColors.candyPink,
                  onPressed: () => go('/debug/drill-results'),
                ),
                const SizedBox(height: 16),
                CandyMenuButton(
                  title: 'Playlist results',
                  subtitle: 'The STAGE CLEAR screen after a playlist',
                  icon: Icons.emoji_events_rounded,
                  colors: AppColors.candyOrange,
                  onPressed: () => go('/debug/playlist-results'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A made-up playlist, as just played: its first five drills, at various settings.
List<PlaylistEntry> debugPlaylistEntries() => [
  for (final (i, drill) in data.allDrills.take(5).indexed)
    PlaylistEntry(
      drillId: drill.id,
      config: DrillConfig(bpm: 80 + i * 10, bpmIncrease: i.isEven ? 5 : 0, drillRepeat: 1 + i % 3),
    ),
];

/// The results popup shown at the end of a graded drill, over a drill's sections with grades
/// marked on their strokes, all from made-up grades, in a few kinds of run.
class DrillResultsDebugScreen extends StatefulWidget {
  const DrillResultsDebugScreen({super.key});

  @override
  State<DrillResultsDebugScreen> createState() => _DrillResultsDebugScreenState();
}

/// A made-up run: how many strokes it had of each judgement, how many with the wrong hand, how
/// many extra hits, and the average and spread of its hits' offsets.
class _Run {
  final String label;
  final Map<Judgement, int> counts;
  final int wrongHands;
  final int extras;
  final double meanMs;
  final double spreadMs;
  final bool uncalibrated;
  final bool playlist;

  const _Run(
    this.label, {
    required this.counts,
    this.wrongHands = 0,
    this.extras = 0,
    required this.meanMs,
    required this.spreadMs,
    this.uncalibrated = false,
    this.playlist = false,
  });

  static const _typical = {
    Judgement.perfect: 41,
    Judgement.good: 22,
    Judgement.early: 9,
    Judgement.late: 4,
    Judgement.miss: 3,
  };

  static const all = [
    _Run('Typical', counts: _typical, wrongHands: 2, extras: 1, meanMs: -14, spreadMs: 22),
    _Run(
      'Great',
      counts: {Judgement.perfect: 74, Judgement.good: 5, Judgement.early: 1},
      meanMs: -3,
      spreadMs: 9,
    ),
    _Run(
      'Rough',
      counts: {
        Judgement.perfect: 12,
        Judgement.good: 18,
        Judgement.early: 25,
        Judgement.late: 9,
        Judgement.miss: 16,
      },
      wrongHands: 11,
      extras: 7,
      meanMs: -38,
      spreadMs: 41,
    ),
    _Run('Uncal.', counts: _typical, meanMs: 31, spreadMs: 20, uncalibrated: true),
    _Run('Playlist', counts: _typical, wrongHands: 2, meanMs: -14, spreadMs: 22, playlist: true),
  ];

  // Made-up offsets with about the right average and spread.
  List<double> get _offsets {
    final random = math.Random(7);
    final hit = counts.entries.where((e) => e.key != Judgement.miss).fold(0, (n, e) => n + e.value);
    return [
      for (var i = 0; i < hit; i++)
        // (Roughly normal: the sum of a few uniform randoms.)
        meanMs +
            spreadMs *
                ([for (var j = 0; j < 3; j++) random.nextDouble() * 2 - 1].reduce((a, b) => a + b)),
    ];
  }

  GradeSummary get summary => GradeSummary(
    counts: counts,
    wrongHands: wrongHands,
    extras: extras,
    offsets: OffsetStats.of(_offsets),
  );

  // A made-up grade for each stroke in [section], spread over the judgements as this run's are.
  Map<(int, int, int, int), Grade> gradesFor(Section section, int seed) {
    final random = math.Random(seed);
    final total = counts.values.fold(0, (a, b) => a + b);
    final wrongChance = wrongHands / total;
    Judgement pick() {
      var n = random.nextInt(total);
      for (final MapEntry(:key, :value) in counts.entries) {
        if (n < value) return key;
        n -= value;
      }
      return Judgement.perfect;
    }

    double errorFor(Judgement judgement) => switch (judgement) {
      Judgement.perfect => random.nextDouble() * 50 - 25,
      Judgement.good => (25 + random.nextDouble() * 25) * (random.nextBool() ? 1 : -1),
      Judgement.early => -50 - random.nextDouble() * 60,
      Judgement.late => 50 + random.nextDouble() * 60,
      Judgement.miss => 0,
    };

    return {
      for (var l = 0; l < section.lines.length; l++)
        for (var m = 0; m < section.lines[l].measures.length; m++)
          for (var b = 0; b < section.lines[l].measures[m].length; b++)
            for (final (i, stroke) in (section.lines[l].measures[m][b]?.strokes ?? []).indexed)
              if (stroke != null)
                (l, m, b, i): () {
                  final judgement = pick();
                  return Grade(
                    stroke: ExpectedStroke(timeMs: 0, hand: stroke.hand, spot: (l, m, b, i)),
                    judgement: judgement,
                    errorMs: judgement == Judgement.miss ? null : errorFor(judgement),
                    wrongHand: judgement != Judgement.miss && random.nextDouble() < wrongChance,
                  );
                }(),
    };
  }
}

class _DrillResultsDebugScreenState extends State<DrillResultsDebugScreen> {
  var _run = _Run.all.first;
  var _showPopup = true;
  // Bumped to restart the popup (and its countdown), as if it were shown afresh.
  var _shown = 0;

  // A drill to show behind the popup: the first with a few sections.
  late final Drill _drill = data.allDrills.firstWhere(
    (d) => d.rows.expand((r) => r).length >= 3,
    orElse: () => data.allDrills.first,
  );

  void _onDone() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Done (showing it again)'), duration: Duration(seconds: 1)),
    );
    setState(() => _shown++);
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final sections = _drill.rows.expand((r) => r).toList();
    return Scaffold(
      backgroundColor: AppColors.navyBottom,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.navyTop, AppColors.navyBottom],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => ListView(
                  padding: EdgeInsets.fromLTRB(
                    safe.left + 10,
                    safe.top + 70,
                    safe.right + 10,
                    safe.bottom + 140,
                  ),
                  children: [
                    for (final (i, section) in sections.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: constraints.maxHeight - 32),
                          child: SectionView(
                            section: section,
                            isHighlighted: i == 0,
                            isDone: false,
                            bannerColor: AppColors.banner(i),
                            grades: _run.gradesFor(section, i),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showPopup)
            Positioned.fill(
              child: ResultsPopup(
                key: ValueKey((_run.label, _shown)),
                summary: _run.summary,
                uncalibratedFor: _run.uncalibrated ? 'This computer' : null,
                timeout: _run.playlist ? const Duration(seconds: 5) : null,
                onDone: _onDone,
              ),
            ),
          Positioned(top: safe.top + 12, left: safe.left + 12, child: const HudBackButton()),
          Positioned(
            left: safe.left + 12,
            right: safe.right + 12,
            bottom: safe.bottom + 12,
            child: _controls(),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.inkShadow, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CandySegmented<_Run>(
            options: [for (final run in _Run.all) (run, run.label)],
            value: _run,
            onChanged: (run) => setState(() => _run = run),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Results popup',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              CandySwitch(value: _showPopup, onChanged: (v) => setState(() => _showPopup = v)),
            ],
          ),
        ],
      ),
    );
  }
}
