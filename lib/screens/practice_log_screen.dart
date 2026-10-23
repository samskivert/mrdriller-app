import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/practice_log.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/rainbow_drum.dart';
import '../widgets/taiko_drum_head.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The user's practice record: a summary (current streak, number of drills completed, total time),
/// a calendar of which days they've practiced over the last few weeks, and the drills completed on
/// each day, most recent first.
class PracticeLogScreen extends StatelessWidget {
  /// For tests: what counts as "now" (and so today), instead of the real time.
  final DateTime? now;

  const PracticeLogScreen({super.key, this.now});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: 'Practice Log',
      showSettings: false,
      child: ListenableBuilder(
        listenable: practiceLog,
        builder: (context, _) {
          final entries = [...practiceLog.entries]
            ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
          final today = practiceDay(now ?? DateTime.now());
          final practice = practiceByDay(entries);
          // Each day's drills, in the order completed (most recent day first).
          final days = <DateTime, List<PracticeLogEntry>>{};
          for (final e in entries.reversed) {
            days.putIfAbsent(practiceDay(e.completedAt), () => []).add(e);
          }
          final dayList = days.entries.toList().reversed.toList();
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entries.isEmpty)
                      const _EmptyCard()
                    else ...[
                      _StatsCard(
                        streak: practiceStreak(practice.keys.toSet(), today),
                        drills: entries.length,
                        totalSeconds: entries.fold(0, (sum, e) => sum + e.seconds),
                      ),
                      const SizedBox(height: 14),
                      _CalendarCard(practice: practice, today: today),
                      const SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: HudBanner(
                          label: 'History',
                          color: AppColors.bannerOrange,
                          fontSize: 14,
                          borderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < dayList.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _DayCard(day: dayList[i].key, entries: dayList[i].value),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamShadow, width: 2),
      ),
      child: const Text(
        'No practice logged yet. Every drill you finish, on its own or in a playlist, will show '
        'up here!',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

/// The headline numbers: the current streak, how many drills, and how long, all told.
class _StatsCard extends StatelessWidget {
  final int streak;
  final int drills;
  final int totalSeconds;

  const _StatsCard({required this.streak, required this.drills, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final total = formatPracticeTotal(totalSeconds);
    Widget row(String label, Color color, String value, String unit) => Row(
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
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DigitTiles(value: value, height: 32),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          row('Streak', AppColors.bannerRed, '$streak', streak == 1 ? 'day' : 'days'),
          const SizedBox(height: 10),
          row('Drills', AppColors.bannerBlue, '$drills', ''),
          const SizedBox(height: 10),
          row('Total', AppColors.bannerMagenta, total, ''),
        ],
      ),
    );
  }
}

/// The last five weeks, a row per week (Monday first), as [PracticeDayCell]s.
class _CalendarCard extends StatelessWidget {
  final Map<DateTime, int> practice;
  final DateTime today;

  const _CalendarCard({required this.practice, required this.today});

  static const _weeks = 5;

  @override
  Widget build(BuildContext context) {
    final thisMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final start = DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * (_weeks - 1));
    const label = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w900,
      color: AppColors.inkMuted,
    );
    return BannerCard(
      label: 'Last 5 weeks',
      color: AppColors.bannerGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final cell = ((constraints.maxWidth - gap * 6) / 7).clamp(20.0, 44.0);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var d = 0; d < 7; d++)
                      Container(
                        width: cell,
                        margin: EdgeInsets.only(left: d == 0 ? 0 : gap),
                        alignment: Alignment.center,
                        child: Text(_weekdayNames[d][0], style: label),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var w = 0; w < _weeks; w++)
                  Padding(
                    padding: EdgeInsets.only(top: w == 0 ? 0 : gap),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var d = 0; d < 7; d++)
                          Padding(
                            padding: EdgeInsets.only(left: d == 0 ? 0 : gap),
                            child: PracticeDayCell(
                              day: DateTime(start.year, start.month, start.day + w * 7 + d),
                              today: today,
                              practice: practice,
                              size: cell,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A day on a practice calendar, as a rounded square, badged with a taiko motif that gets fancier
/// the longer the day's [practice] was: a white mitsudomoe on candy green, then a drum head on
/// candy blue (like the app's badge) from ten minutes, then a glowing navy tile with a spinning
/// rainbow drum and sparkles from twenty. A little gold cursor points at it if it's [today], and
/// it's faded out if it's still to come.
class PracticeDayCell extends StatelessWidget {
  final DateTime day;
  final DateTime today;
  // Seconds of practice by day (see practiceByDay).
  final Map<DateTime, int> practice;
  final double size;

  const PracticeDayCell({
    super.key,
    required this.day,
    required this.today,
    required this.practice,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = practice[day];
    final tier = PracticeTier.of(seconds);
    final done = tier != PracticeTier.none;
    final isToday = day == today;
    final future = day.isAfter(today);
    final minutes = ((seconds ?? 0) / 60).round();
    return Semantics(
      label:
          '${_weekdayNames[day.weekday - 1]} ${_monthNames[day.month - 1]} ${day.day}'
          '${done ? ', practiced $minutes ${minutes == 1 ? 'minute' : 'minutes'}' : ''}'
          '${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          _tile(tier, future, size),
          // Today gets a little gold cursor pointing up at it, poking out from under it.
          if (isToday)
            Positioned(
              bottom: -size * 0.12,
              child: CustomPaint(
                size: Size(size * 0.4, size * 0.24),
                painter: const _TodayCursorPainter(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(PracticeTier tier, bool future, double size) {
    final done = tier != PracticeTier.none;
    final superstar = tier == PracticeTier.twentyMinutes;
    final candy = switch (tier) {
      PracticeTier.practiced => AppColors.candyGreen,
      PracticeTier.tenMinutes => AppColors.candyBlue,
      _ => null,
    };
    // A day gone by without practice is a hole in the card, showing the screen's cream through it,
    // with a thin shadow in the card's shadow color (see BannerCard) across the top of it.
    final hole = !done && !future;
    final radius = BorderRadius.circular(size * 0.28);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: hole ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: candy != null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [candy.hi, candy.base, candy.lo],
              )
            : superstar
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.panel, AppColors.navy],
              )
            : null,
        color: hole ? AppColors.creamShadow : null,
        border: superstar ? Border.all(color: AppColors.gold, width: 1.5) : null,
        boxShadow: [
          if (candy != null) BoxShadow(color: candy.outline, offset: const Offset(0, 2)),
          if (superstar) ...[
            BoxShadow(color: AppColors.gold.withValues(alpha: 0.7), blurRadius: size * 0.2),
            const BoxShadow(color: AppColors.inkShadow, offset: Offset(0, 2)),
          ],
        ],
      ),
      child: switch (tier) {
        // Filling the whole tile, not just shrinking to fit the date.
        PracticeTier.none => SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hole)
                Positioned.fill(
                  top: 2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.cream, borderRadius: radius),
                  ),
                ),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.inkMuted.withValues(alpha: future ? 0.35 : 0.8),
                ),
              ),
            ],
          ),
        ),
        PracticeTier.practiced => SizedBox.square(
          dimension: size * 0.8,
          child: const Mitsudomoe(color: Colors.white),
        ),
        PracticeTier.tenMinutes => SizedBox.square(
          dimension: size * 0.83,
          child: const TaikoDrumHead(),
        ),
        PracticeTier.twentyMinutes => RainbowDrum(
          size: size,
          seed: day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
        ),
      },
    );
  }
}

class _TodayCursorPainter extends CustomPainter {
  const _TodayCursorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cursor = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final outline = Paint()
      ..color = AppColors.goldOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(cursor, outline);
    canvas.drawPath(cursor, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant _TodayCursorPainter oldDelegate) => false;
}

/// One day's practice: a calendar-page badge for its date, how many drills and how long, which
/// weekday, and a chip for each drill completed (in the order they were completed).
class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<PracticeLogEntry> entries;

  const _DayCard({required this.day, required this.entries});

  @override
  Widget build(BuildContext context) {
    final drills = entries.length == 1 ? '1 drill' : '${entries.length} drills';
    final seconds = entries.fold(0, (sum, e) => sum + e.seconds);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A little page off a calendar.
          Container(
            width: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.creamShadow, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.bannerRed,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  child: Text(
                    _monthNames[day.month - 1].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      height: 1.1,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$drills · ${formatDrillDuration(seconds.toDouble())}',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_weekdayNames[day.weekday - 1]}, ${day.year}',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in entries)
                      _DrillChip(
                        title: data.findDrillById(e.drillId)?.title ?? e.drillId,
                        bpm: e.config.bpm,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A completed drill: its title and the bpm it started at.
class _DrillChip extends StatelessWidget {
  final String title;
  final int bpm;

  const _DrillChip({required this.title, required this.bpm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.creamShadow, width: 1.5),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: title),
            TextSpan(
              text: ' · $bpm BPM',
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
