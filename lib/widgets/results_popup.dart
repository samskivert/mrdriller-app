import 'dart:async';

import 'package:flutter/material.dart';

import '../model/grading.dart';
import '../util/colors.dart';
import 'arcade.dart';

/// The results of grading a player's hits on a drum pad over a drill (see grading.dart), shown
/// over the drill once it's done: a card of how it went (see [_GradeSummaryView]) on a backdrop
/// darkening the drill. The card is laid out [width] wide (or as wide as fits, if less), then
/// scaled up to fill some of a big screen, or down to fit a short one.
class ResultsPopup extends StatelessWidget {
  static const width = 380.0;

  // How much of a big screen's width it fills, scaled up, at most so much bigger.
  static const _screenShare = 0.6;
  static const _maxScale = 2.0;
  static const _margin = 16.0;

  final GradeSummary summary;

  /// The audio output the pad wasn't calibrated for, if it wasn't.
  final String? uncalibratedFor;

  /// How long it waits before moving on by itself, if it does.
  final Duration? timeout;
  final VoidCallback onDone;

  const ResultsPopup({
    super.key,
    required this.summary,
    this.uncalibratedFor,
    this.timeout,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy.withValues(alpha: 0.75),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final room = Size(
            constraints.maxWidth - _margin * 2,
            constraints.maxHeight - _margin * 2,
          );
          final layoutWidth = room.width < width ? room.width : width;
          final scale = (constraints.maxWidth * _screenShare / width).clamp(1.0, _maxScale);
          return Center(
            child: ConstrainedBox(
              // As wide as scaled up, and (scaled down, if need be) no taller than the screen.
              constraints: BoxConstraints(
                minWidth: layoutWidth * scale,
                maxWidth: layoutWidth * scale,
                maxHeight: room.height,
              ),
              child: FittedBox(
                child: SizedBox(
                  width: layoutWidth,
                  child: PlayfieldPanel(
                    active: true,
                    padding: const EdgeInsets.all(20),
                    child: _GradeSummaryView(
                      summary: summary,
                      uncalibratedFor: uncalibratedFor,
                      timeout: timeout,
                      onDone: onDone,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// How the player's hits on a drum pad went, over the whole drill, at a glance, as HUD cards: how
/// many of each judgement (in the colors their marks on the strokes have), on average how early or
/// late and give or take how much, and how many mistakes of each kind. If there's a [timeout], once
/// it runs out (a bar draining as it does), [onDone] moves on; otherwise it stays until the player
/// leaves.
class _GradeSummaryView extends StatefulWidget {
  final GradeSummary summary;

  /// The audio output the pad wasn't calibrated for, if it wasn't.
  final String? uncalibratedFor;
  final Duration? timeout;
  final VoidCallback onDone;

  const _GradeSummaryView({
    required this.summary,
    this.uncalibratedFor,
    this.timeout,
    required this.onDone,
  });

  @override
  State<_GradeSummaryView> createState() => _GradeSummaryViewState();
}

// The banner colors of the judgements, like their marks on the strokes.
const _perfectBanner = Color(0xFFB98400);
const _earlyLateBanner = AppColors.bannerMagenta;

const _judgementBanners = {
  Judgement.perfect: _perfectBanner,
  Judgement.good: AppColors.bannerGreen,
  Judgement.early: _earlyLateBanner,
  Judgement.late: _earlyLateBanner,
  Judgement.miss: AppColors.bannerRed,
};

const _gap = 8.0;
const _digitHeight = 28.0;

class _GradeSummaryViewState extends State<_GradeSummaryView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final timeout = widget.timeout;
    if (timeout != null) _timer = Timer(timeout, widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _judgement(Judgement judgement) =>
      _count(judgement.label, _judgementBanners[judgement]!, widget.summary.count(judgement));

  Widget _count(String label, Color color, int count, {bool stacked = false}) => _StatCard(
    label: label,
    color: color,
    faded: count == 0,
    stacked: stacked,
    child: DigitTiles(value: '$count', height: _digitHeight),
  );

  Widget _row(List<Widget> cards) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(child: card),
        ],
      ],
    ),
  );

  Widget _average() {
    final offsets = widget.summary.offsets;
    final mean = offsets.mean.round();
    final (tag, tagColor) = mean == 0
        ? ('On time', AppColors.bannerGreen)
        : (mean < 0 ? 'Early' : 'Late', _earlyLateBanner);
    return _StatCard(
      label: 'Average',
      color: AppColors.bannerBlue,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DigitTiles(value: '${mean.abs()}', height: _digitHeight),
          const _Unit('ms'),
          const SizedBox(width: 8),
          _Tag(tag, tagColor),
          const SizedBox(width: 12),
          const _Unit('±'),
          DigitTiles(value: '${offsets.spread.round()}', height: _digitHeight),
          const _Unit('ms'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final timeout = widget.timeout;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: PuffyText(
            'RESULTS',
            size: 30,
            color: AppColors.gold,
            shadow: AppColors.goldOutline,
          ),
        ),
        const SizedBox(height: 14),
        _row([_judgement(Judgement.perfect), _judgement(Judgement.good)]),
        const SizedBox(height: _gap),
        _row([_judgement(Judgement.early), _judgement(Judgement.late)]),
        const SizedBox(height: _gap),
        _row([
          for (final (label, color, count) in [
            (
              Judgement.miss.label,
              _judgementBanners[Judgement.miss]!,
              summary.count(Judgement.miss),
            ),
            ('Wrong hand', AppColors.bannerOrange, summary.wrongHands),
            ('Extra hits', AppColors.bannerOrange, summary.extras),
          ])
            // (Narrow, three to a row, so their counts go below their banners.)
            _count(label, color, count, stacked: true),
        ]),
        if (summary.offsets.count > 0) ...[const SizedBox(height: _gap), _average()],
        if (widget.uncalibratedFor != null) ...[
          const SizedBox(height: 6),
          const Center(child: _Tag('Not calibrated', AppColors.bannerRed)),
        ],
        if (timeout != null) ...[
          const SizedBox(height: 16),
          // Draining as the time to moving on runs out.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: timeout,
            builder: (context, left, _) => Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.panelBorder,
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: left,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A cream HUD card with a [label] on a banner in [color] in its top left corner, and [child] (a
/// number) beside it, or below it if [stacked] (for a narrow card); faded if it's nothing to look
/// at.
class _StatCard extends StatelessWidget {
  final String label;
  final Color color;
  final Widget child;
  final bool faded;
  final bool stacked;

  const _StatCard({
    required this.label,
    required this.color,
    required this.child,
    this.faded = false,
    this.stacked = false,
  });

  @override
  Widget build(BuildContext context) {
    final banner = HudBanner(
      label: label,
      color: color,
      fontSize: 12,
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
    );
    final value = FittedBox(fit: BoxFit.scaleDown, child: child);
    return Opacity(
      opacity: faded ? 0.45 : 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: AppColors.inkShadow, offset: Offset(0, 3))],
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: banner),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Center(child: value),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  banner,
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                      child: Align(alignment: Alignment.centerRight, child: value),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A unit (or sign) beside digit tiles, in the gray of their separators.
class _Unit extends StatelessWidget {
  final String text;

  const _Unit(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 18,
        height: 1,
        fontWeight: FontWeight.w900,
        color: Color(0xFF9A90A8),
      ),
    ),
  );
}

/// A little pill of a word, e.g. EARLY.
class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 13,
        height: 1,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 1,
        color: Colors.white,
      ),
    ),
  );
}
