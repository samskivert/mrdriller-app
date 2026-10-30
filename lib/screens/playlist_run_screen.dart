import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/playlists.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/components.dart';
import '../widgets/drill_overview_view.dart';
import '../widgets/drill_practice_host.dart';
import '../widgets/drill_status_view.dart';
import '../widgets/hud_layout.dart';

const _introDuration = Duration(seconds: 5);

enum _Phase { intro, running, outro }

/// Plays a playlist's drills ([entries], in the order given, so shuffled already if it's being
/// shuffled), one at a time: a few seconds showing the drill's name/config (the "intro"), then the
/// drill itself via [DrillPracticeView], then the next drill's intro, and so on -- ending on a
/// summary/congratulations screen once every drill has been completed. The header's back button
/// abandons the whole run, not just the current drill (though drills already completed stay
/// recorded in the practice log).
class PlaylistRunScreen extends StatefulWidget {
  final String title;
  final List<PlaylistEntry> entries;

  const PlaylistRunScreen({super.key, required this.title, required this.entries});

  @override
  State<PlaylistRunScreen> createState() => _PlaylistRunScreenState();
}

class _PlaylistRunScreenState extends State<PlaylistRunScreen> {
  late final List<PlaylistEntry> _entries = widget.entries;

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

  // A drill referenced by a playlist can, in principle, no longer exist (e.g. it was renamed or
  // removed from the catalog after being added to a saved playlist) -- skip silently past any entry
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

  // Skips the rest of the intro, starting the drill straight away.
  void _startNow() {
    _introTimer?.cancel();
    setState(() => _phase = _Phase.running);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.outro) return PlaylistResults(entries: _entries);

    final entry = _entries[_index];
    final drill = _activeDrillFor(entry)!;
    final drillCount = _DrillCountCard(index: _index, count: _entries.length);
    if (_phase == _Phase.running) {
      return DrillPracticeHost(
        key: ValueKey(_index),
        title: drill.title,
        subtitle: '${_index + 1} of ${_entries.length}',
        drill: drill,
        config: entry.config,
        // There are usually more drills to come, so not "ALL CLEAR!".
        clearText: 'DRILL CLEAR!',
        sidebarFooter: drillCount,
        onDone: _handleDrillDone,
      );
    }

    final startNow = CandyButton(
      label: 'START NOW',
      icon: Icons.skip_next_rounded,
      colors: AppColors.candyGreen,
      onPressed: _startNow,
    );
    return HudLayout(
      playfield: _IntroView(
        key: ValueKey(_index),
        drill: drill,
        config: entry.config,
        number: _index + 1,
        count: _entries.length,
      ),
      hud: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Row(
              children: [
                const HudBackButton(),
                const SizedBox(width: 12),
                Expanded(child: HudTitle(widget.title)),
              ],
            ),
            const SizedBox(height: 14),
            drillCount,
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: startNow),
          ],
        ),
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
          startNow,
          const SizedBox(height: 14),
          drillCount,
        ],
      ),
    );
  }

  Drill? _activeDrillFor(PlaylistEntry entry) {
    final drill = data.findDrillById(entry.drillId);
    if (drill == null) return null;
    return entry.config.swapHands ? swapHands(drill) : drill;
  }
}

/// The HUD's progress through the playlist: which drill this is, DRILL n/N.
class _DrillCountCard extends StatelessWidget {
  final int index;
  final int count;

  const _DrillCountCard({required this.index, required this.count});

  @override
  Widget build(BuildContext context) =>
      BigReadoutCard(label: 'Drill', color: AppColors.bannerBlue, value: '${index + 1}/$count');
}

/// The playfield while the next drill is introduced: a preview of the drill, under a translucent
/// scrim showing which drill of the playlist it is, its name and settings, and a bar counting down
/// to its start.
class _IntroView extends StatelessWidget {
  final Drill drill;
  final DrillConfig config;
  final int number;
  final int count;

  const _IntroView({
    super.key,
    required this.drill,
    required this.config,
    required this.number,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final time = formatDrillClock(drillDuration(drill, config));
    final details = [
      '${config.bpm} BPM',
      if (config.bpmIncrease > 0) '+${config.bpmIncrease}',
      if (config.drillRepeat > 1) '×${config.drillRepeat}',
      if (config.swapHands) 'L↔R',
      time,
    ].join('  ·  ');
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
            child: Center(child: DrillOverviewView(drill: drill)),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xC7090E20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = playfieldOverlayScale(constraints);
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20 * scale),
                    child: FittedBox(fit: BoxFit.scaleDown, child: _info(details, scale)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _info(String details, double scale) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 22 * scale, vertical: 11 * scale),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 4 * scale))],
        ),
        child: Text(
          'DRILL $number OF $count',
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 17 * scale,
            height: 1,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 3 * scale,
            color: AppColors.ink,
          ),
        ),
      ),
      SizedBox(height: 22 * scale),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560 * scale),
        child: PuffyText(drill.title, size: 44 * scale, textAlign: TextAlign.center),
      ),
      SizedBox(height: 18 * scale),
      Text(
        details,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 18 * scale,
          height: 1,
          fontWeight: FontWeight.w900,
          color: AppColors.cream,
        ),
      ),
      SizedBox(height: 24 * scale),
      // Drains over the intro, counting down to the drill's start.
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: _introDuration,
        builder: (context, remaining, _) => Container(
          width: 240 * scale,
          height: 10 * scale,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5 * scale),
          ),
          child: FractionallySizedBox(
            widthFactor: remaining,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(5 * scale),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// The end of the run: STAGE CLEAR!, a results card (how many drills, the total time, the top bpm
/// reached, and which drills were cleared), and a button to go back to the playlist. (Each drill
/// was already recorded in the practice log as it was completed.)
class PlaylistResults extends StatelessWidget {
  final List<PlaylistEntry> entries;

  const PlaylistResults({super.key, required this.entries});

  // Only entries that actually resolved to a real drill (and so actually got practiced) count --
  // an entry whose drill no longer exists was silently skipped, not completed.
  Iterable<({Drill drill, DrillConfig config})> get _completed sync* {
    for (final entry in entries) {
      final drill = data.findDrillById(entry.drillId);
      if (drill != null) yield (drill: drill, config: entry.config);
    }
  }

  // The drills' own computed durations, not wall-clock time actually spent -- this way pausing
  // mid-drill (or the intro between drills) doesn't affect the total.
  double get _totalSeconds {
    var total = 0.0;
    for (final c in _completed) {
      total += drillDuration(c.drill, c.config);
    }
    return total;
  }

  // The fastest any drill got, on its last (fastest) loop.
  int get _topBpm {
    var top = 0;
    for (final c in _completed) {
      final last = (c.config.bpm + c.config.bpmIncrease * (c.config.drillRepeat - 1)).clamp(
        0,
        maxBpm,
      );
      if (last > top) top = last;
    }
    return top;
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed.map((c) => c.drill).toList();
    final safe = MediaQuery.paddingOf(context);
    Widget row(String label, Color color, String value) => Row(
      children: [
        SizedBox(
          width: 100,
          child: HudBanner(
            label: label,
            color: color,
            fontSize: 13,
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const Spacer(),
        DigitTiles(value: value, height: 34),
      ],
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Bubbles(
                bubbles: [(1.0, 0.0, 100), (0.08, 0.06, 30), (0.0, 0.55, 80), (1.0, 0.9, 50)],
              ),
            ),
            for (final (x, y, size, color, angle) in const [
              (0.1, 0.13, 38.0, AppColors.gold, -0.25),
              (0.86, 0.08, 28.0, Color(0xFF5DB7F5), 0.2),
              (0.88, 0.24, 32.0, Color(0xFFFF6FA0), -0.1),
              (0.06, 0.3, 22.0, Color(0xFF49C96B), 0.3),
            ])
              Align(
                alignment: Alignment(x * 2 - 1, y * 2 - 1),
                child: Transform.rotate(
                  angle: angle,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.star_rounded, size: size + 8, color: Colors.white),
                      Icon(Icons.star_rounded, size: size, color: color),
                    ],
                  ),
                ),
              ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                safe.left + 20,
                safe.top + 36,
                safe.right + 20,
                safe.bottom + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bounces in.
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.3, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Semantics(
                          header: true,
                          label: 'Stage clear!',
                          excludeSemantics: true,
                          child: const Column(
                            children: [
                              PuffyText('STAGE', size: 50),
                              PuffyText(
                                'CLEAR!',
                                size: 50,
                                color: AppColors.gold,
                                shadow: AppColors.goldOutline,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Great practice!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            row('Drills', AppColors.bannerOrange, '${completed.length}'),
                            const SizedBox(height: 10),
                            row('Time', AppColors.bannerMagenta, formatDrillClock(_totalSeconds)),
                            const SizedBox(height: 10),
                            row('Top BPM', AppColors.bannerBlue, '$_topBpm'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 2, thickness: 2, color: Color(0xFFF3E8D2)),
                            ),
                            const Text(
                              'CLEARED',
                              style: TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 1.6,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < completed.length; i++)
                                  _ClearedChip(
                                    title: completed[i].title,
                                    color: AppColors.banner(i),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      CandyButton(
                        label: 'DONE!',
                        icon: Icons.check_rounded,
                        colors: AppColors.candyGreen,
                        height: 62,
                        fontSize: 22,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
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

/// A cleared drill, as a little candy chip with a check mark.
class _ClearedChip extends StatelessWidget {
  final String title;
  final Color color;

  const _ClearedChip({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 11, 7),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
