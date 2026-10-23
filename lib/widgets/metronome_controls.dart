import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/model.dart';
import '../services/metronome_player.dart';
import '../state/metronome_settings.dart';
import '../util/colors.dart';
import 'arcade.dart';
import 'hud_controls.dart';
import 'stroke_view.dart';

/// The metronome's settings, on its main screen and on a preset's: steppers for the bpm and how
/// many beats are in a measure, the beats themselves (tap one to switch it between high, low, and
/// off), and speeding up every so many measures. While [player] plays, the beat it's on lights up.
class MetronomeControls extends StatelessWidget {
  final MetronomeConfig config;
  final ValueChanged<MetronomeConfig> onChanged;
  final MetronomePlayer player;

  const MetronomeControls({
    super.key,
    required this.config,
    required this.onChanged,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final c = config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 84,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: HudStepperCard(
                  HudStepperSpec(
                    label: 'BPM',
                    bannerColor: AppColors.bannerOrange,
                    value: c.bpm,
                    min: metronomeBpmLimits.min,
                    max: metronomeBpmLimits.max,
                    onChanged: (v) => onChanged(c.copyWith(bpm: v)),
                    decreaseLabel: 'Slower',
                    increaseLabel: 'Faster',
                  ),
                  inline: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HudStepperCard(
                  HudStepperSpec(
                    label: 'Beats',
                    bannerColor: AppColors.bannerRed,
                    value: c.beats.length,
                    min: metronomeBeatLimits.min,
                    max: metronomeBeatLimits.max,
                    onChanged: (v) => onChanged(c.withBeatCount(v)),
                    decreaseLabel: 'Fewer beats',
                    increaseLabel: 'More beats',
                  ),
                  inline: true,
                  trailing: _NoteButton(
                    note: c.note,
                    onTap: () => onChanged(c.copyWith(note: c.note.next)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BannerCard(
          label: 'Measure',
          color: AppColors.bannerBlue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: player,
                builder: (context, _) => _BeatsPanel(
                  beats: c.beats,
                  current: player.beat,
                  onTap: (i) => onChanged(c.withBeatToggled(i)),
                ),
              ),
              const SizedBox(height: 10),
              const _Description('Tap a beat to switch it between high, low, and off.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SpeedUpCard(
          steppers: [
            HudStepperRow(
              HudStepperSpec(
                label: '+BPM',
                bannerColor: AppColors.bannerMagenta,
                value: c.bpmIncrease,
                min: metronomeIncreaseLimits.min,
                max: metronomeIncreaseLimits.max,
                onChanged: (v) => onChanged(c.copyWith(bpmIncrease: v)),
                decreaseLabel: 'Speed up less',
                increaseLabel: 'Speed up more',
              ),
              bannerWidth: _SpeedUpCard.bannerWidth,
              digits: 2,
            ),
            HudStepperRow(
              HudStepperSpec(
                label: 'Every',
                bannerColor: AppColors.bannerMagenta,
                value: c.increaseEvery,
                min: metronomeIncreaseEveryLimits.min,
                max: metronomeIncreaseEveryLimits.max,
                onChanged: (v) => onChanged(c.copyWith(increaseEvery: v)),
                decreaseLabel: 'Fewer measures',
                increaseLabel: 'More measures',
              ),
              bannerWidth: _SpeedUpCard.bannerWidth,
              digits: 2,
            ),
          ],
          summary: ListenableBuilder(
            listenable: player,
            builder: (context, _) =>
                _Description(_speedUpSummary(c, player), textAlign: TextAlign.start),
          ),
        ),
      ],
    );
  }

  // E.g. "+5 BPM every 4 measures, now at 110 BPM." (once it's sped up).
  static String _speedUpSummary(MetronomeConfig c, MetronomePlayer player) {
    if (c.increaseEvery == 0) return 'Set EVERY above 0 to speed up.';
    final every = c.increaseEvery == 1 ? 'every measure' : 'every ${c.increaseEvery} measures';
    final now = player.playing && player.bpm != c.bpm ? ', now at ${player.bpm} BPM' : '';
    return '+${c.bpmIncrease} BPM $every$now.';
  }
}

/// The measure's beats on a navy panel, in a row: a high beat as a big accented candy block, a low
/// one as a small round candy, and an off one as an empty ring. The [current] beat pops up.
class _BeatsPanel extends StatelessWidget {
  final List<BeatLevel> beats;
  final int? current;
  final ValueChanged<int> onTap;

  const _BeatsPanel({required this.beats, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PlayfieldPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Sized for a full eight beats, so they don't change size as beats come and go. (Each
          // block has a 4px margin all around.)
          final size = (constraints.maxWidth / metronomeBeatLimits.max - 8).clamp(20.0, 40.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < beats.length; i++)
                _Beat(
                  number: i + 1,
                  level: beats[i],
                  current: i == current,
                  size: size,
                  onTap: () => onTap(i),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Beat extends StatelessWidget {
  final int number;
  final BeatLevel level;
  final bool current;
  final double size;
  final VoidCallback onTap;

  const _Beat({
    required this.number,
    required this.level,
    required this.current,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Beat $number, ${level.name}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (level) {
              BeatLevel.high => StrokeView(stroke: R, highlight: current, size: size),
              BeatLevel.low => StrokeView(stroke: r, highlight: current, size: size),
              BeatLevel.off => Container(
                margin: const EdgeInsets.all(4),
                width: size,
                height: size,
                alignment: Alignment.center,
                child: Container(
                  width: size * 0.5,
                  height: size * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current ? AppColors.gold : AppColors.panelBorder,
                      width: 2,
                    ),
                  ),
                ),
              ),
            },
            const SizedBox(height: 4),
            Text(
              '$number',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w900,
                color: current ? AppColors.gold : AppColors.cream.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What note each beat is, drawn in notation (a quarter note, two eighths, three triplets, or four
/// sixteenths): tap it to switch to the next.
class _NoteButton extends StatelessWidget {
  final NoteValue note;
  final VoidCallback onTap;

  const _NoteButton({required this.note, required this.onTap});

  // How wide each note is drawn (centered in the widest's width).
  static const _widths = {
    NoteValue.quarter: 12.0,
    NoteValue.eighth: 24.0,
    NoteValue.triplet: 32.0,
    NoteValue.sixteenth: 40.0,
  };
  static final _width = _widths.values.reduce(math.max);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Beats are ${note.plural}. Tap to change.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // As wide as the widest notes (sixteenths), so that it doesn't change size as the note
          // does, plus some space around them to tap.
          width: _width + 2 * HudStepperCard.trailingInset,
          height: 38,
          padding: const EdgeInsets.fromLTRB(
            HudStepperCard.trailingInset,
            3,
            HudStepperCard.trailingInset,
            4,
          ),
          child: Center(
            child: CustomPaint(size: Size(_widths[note]!, 31), painter: _NotesPainter(note)),
          ),
        ),
      ),
    );
  }
}

/// Draws one beat's worth of [note]s: their heads along the bottom, stems up from them, and (for
/// more than one) a beam across their tops -- doubled for sixteenths, with a 3 over it for
/// triplets.
class _NotesPainter extends CustomPainter {
  final NoteValue note;

  const _NotesPainter(this.note);

  @override
  void paint(Canvas canvas, Size size) {
    final n = note.perQuarter;
    final h = size.height;
    // Smaller heads when there are more of them, so they don't run into each other.
    final headW = n == 1 ? h * 0.36 : math.min(h * 0.36, size.width / (n + 0.4));
    final headH = headW * 0.72;
    final stemW = h * 0.07, beamH = h * 0.12;
    // Leave room at the top for the triplets' 3.
    final top = note == NoteValue.triplet ? h * 0.3 : 0.0;
    final spacing = n == 1 ? 0.0 : (size.width - headW) / (n - 1);
    final ink = Paint()..color = AppColors.ink;
    final xs = [
      for (var i = 0; i < n; i++) (size.width - headW - spacing * (n - 1)) / 2 + spacing * i,
    ];
    for (final x in xs) {
      final head = Offset(x + headW / 2, h - headH / 2);
      canvas.save();
      canvas.translate(head.dx, head.dy);
      canvas.rotate(-0.35);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: headW, height: headH), ink);
      canvas.restore();
      // The stem rises from the head's right side.
      canvas.drawRect(Rect.fromLTRB(x + headW - stemW, top, x + headW, head.dy), ink);
    }
    if (n == 1) return;
    final left = xs.first + headW - stemW, right = xs.last + headW;
    canvas.drawRect(Rect.fromLTRB(left, top, right, top + beamH), ink);
    if (note == NoteValue.sixteenth) {
      final y = top + beamH * 1.8;
      canvas.drawRect(Rect.fromLTRB(left, y, right, y + beamH), ink);
    }
    if (note == NoteValue.triplet) {
      final three = TextPainter(
        text: TextSpan(
          text: '3',
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: top * 1.1,
            height: 1,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: AppColors.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      three.paint(canvas, Offset((left + right - three.width) / 2, top - three.height - h * 0.02));
    }
  }

  @override
  bool shouldRepaint(covariant _NotesPainter oldDelegate) => oldDelegate.note != note;
}

/// PLAY, or PAUSE while [player] plays.
class MetronomePlayButton extends StatelessWidget {
  final MetronomePlayer player;

  const MetronomePlayButton({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => player.playing
          ? CandyButton(
              label: 'PAUSE',
              icon: Icons.pause_rounded,
              colors: AppColors.candyOrange,
              height: 76,
              fontSize: 76 * 0.3,
              onPressed: player.pause,
            )
          : StartButton(label: 'PLAY', onPressed: player.play),
    );
  }
}

/// The SPEED UP card: its banner in the top-left corner with the [summary] below it, and the
/// [steppers] down the right side, from the top of the card. Too narrow for that (on a small
/// phone), the summary goes below the steppers instead.
class _SpeedUpCard extends StatelessWidget {
  final List<Widget> steppers;
  final Widget summary;

  const _SpeedUpCard({required this.steppers, required this.summary});

  // Just wide enough for +BPM and EVERY.
  static const bannerWidth = 62.0;
  // Wide enough for the steppers' banners, buttons, and values.
  static const _steppersWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    // Matching a BannerCard's.
    const banner = HudBanner(
      label: 'Speed up',
      color: AppColors.bannerMagenta,
      fontSize: 13,
      padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
    );
    final steppers = Column(
      children: [
        for (var i = 0; i < this.steppers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          this.steppers[i],
        ],
      ],
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 340
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: banner),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(children: [steppers, const SizedBox(height: 10), summary]),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        banner,
                        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 8, 14), child: summary),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: SizedBox(width: _steppersWidth, child: steppers),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Description extends StatelessWidget {
  final String text;
  final TextAlign textAlign;

  const _Description(this.text, {this.textAlign = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.inkMuted,
      ),
    );
  }
}
