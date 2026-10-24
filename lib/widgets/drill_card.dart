import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../model/model.dart';
import '../state/drill_config.dart';
import '../util/colors.dart';
import 'arcade.dart';
import 'measure_view.dart';

/// A drill as a "stage" card: its [number] on a banner, its title, a strip previewing its first
/// line of notes, and its settings (once [config] is known, e.g. loaded). [trailing] goes beside
/// the title, in place of the usual chevron.
class DrillCard extends StatelessWidget {
  final int number;
  final Drill drill;
  final DrillConfig? config;
  final VoidCallback onTap;
  final Widget? trailing;

  const DrillCard({
    super.key,
    required this.number,
    required this.drill,
    required this.config,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.creamShadow, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(number: number, title: drill.title, trailing: trailing),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _NotesPreview(drill: drill),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: _SettingsLine(drill: drill, config: config),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group of drills as a "stage" card for picking one: a main drill (first in [drills]) with its
/// [number] on a banner, its title and a strip previewing its notes, then the same (minus the
/// banner) for each of its variations below it. Tapping a drill's title or preview passes that drill
/// to [onTap].
class DrillGroupCard extends StatelessWidget {
  final int number;
  final List<Drill> drills;
  final void Function(Drill drill) onTap;

  const DrillGroupCard({
    super.key,
    required this.number,
    required this.drills,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.creamShadow, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < drills.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 2,
                  thickness: 2,
                  indent: 10,
                  endIndent: 10,
                  color: AppColors.creamShadow,
                ),
              InkWell(
                onTap: () => onTap(drills[i]),
                child: Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      i == 0
                          ? _CardHeader(number: number, title: drills[i].title)
                          : _VariationHeader(title: drills[i].title),
                      SizedBox(height: i == 0 ? 8 : 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _NotesPreview(drill: drills[i]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A card's top row: its [number] on a banner, then [title], then [trailing] (or a chevron).
class _CardHeader extends StatelessWidget {
  final int number;
  final String title;
  final Widget? trailing;

  const _CardHeader({required this.number, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HudBanner(
          label: number.toString().padLeft(2, '0'),
          color: AppColors.banner(number - 1),
          fontSize: 14,
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 17,
                height: 1.1,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 10, 0),
          child: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

/// A variation's title row in a [DrillGroupCard], set in from under the main drill's banner.
class _VariationHeader extends StatelessWidget {
  final String title;

  const _VariationHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Row(
        children: [
          const Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 15,
                height: 1.1,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

/// A navy strip showing the first line of [drill]'s first section, as small candy blocks:
/// centered if it fits, or else as much of it as fits, fading out at the right.
class _NotesPreview extends StatelessWidget {
  final Drill drill;

  const _NotesPreview({required this.drill});

  @override
  Widget build(BuildContext context) {
    final firstSection = drill.rows.firstOrNull?.firstOrNull;
    final line = firstSection?.lines.firstOrNull;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: line == null
          ? null
          : _CenterOrFade(
              // Scaled down only to fit the strip's height (e.g. a line with beat labels, or two
              // hands stacked on one beat); a long line runs off the right edge rather than being
              // shrunk to fit its width.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var m = 0; m < line.measures.length; m++) ...[
                      if (m > 0) const SizedBox(width: 6),
                      MeasureView(
                        measure: line.measures[m],
                        strokeSize: 26,
                        labelColor: AppColors.cream,
                        scrollable: false,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// Lays out [child] at whatever width it likes (but no taller than this box), then centers it if
/// it fits, or else starts it at the left edge, clipped at the right edge, and fading out as it
/// gets there.
class _CenterOrFade extends SingleChildRenderObjectWidget {
  const _CenterOrFade({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCenterOrFade();
}

class _RenderCenterOrFade extends RenderShiftedBox {
  _RenderCenterOrFade() : super(null);

  bool _overflows = false;

  @override
  bool get alwaysNeedsCompositing => _overflows;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(BoxConstraints(maxHeight: size.height), parentUsesSize: true);
    final overflows = child.size.width > size.width;
    if (overflows != _overflows) {
      _overflows = overflows;
      markNeedsCompositingBitsUpdate();
    }
    (child.parentData! as BoxParentData).offset = Offset(
      overflows ? 0 : (size.width - child.size.width) / 2,
      (size.height - child.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final childOffset = (child.parentData! as BoxParentData).offset;
    if (!_overflows) {
      this.layer = null;
      context.paintChild(child, offset + childOffset);
      return;
    }
    final layer = (this.layer as ShaderMaskLayer?) ?? ShaderMaskLayer();
    this.layer = layer;
    layer
      ..shader = const LinearGradient(
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.88, 1],
      ).createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(
      layer,
      (context, offset) => context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        (context, offset) => context.paintChild(child, offset + childOffset),
      ),
      offset,
    );
  }
}

/// A drill's saved settings, e.g. "60 BPM  +5  ×3", and its total time.
class _SettingsLine extends StatelessWidget {
  final Drill drill;
  final DrillConfig? config;

  const _SettingsLine({required this.drill, required this.config});

  @override
  Widget build(BuildContext context) {
    final config = this.config;
    if (config == null) return const SizedBox.shrink();
    const style = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 13,
      height: 1,
      fontWeight: FontWeight.w800,
      color: AppColors.inkMuted,
    );
    final parts = [
      '${config.bpm} BPM',
      if (config.bpmIncrease > 0) '+${config.bpmIncrease}',
      if (config.drillRepeat > 1) '×${config.drillRepeat}',
      if (config.swapHands) 'L↔R',
    ];
    final time = formatDrillClock(drillDuration(drill, config));
    return Row(
      children: [
        Expanded(
          child: Text(
            parts.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.inkMuted),
        const SizedBox(width: 4),
        Text(time, style: style),
      ],
    );
  }
}
