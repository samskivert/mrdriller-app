// Building blocks for the app's arcade (Mr. Driller inspired) look: outlined and puffy text, HUD
// banners and digit tiles, the AIR gauge, candy buttons, and the decorative drips/bubbles/ruler.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../util/colors.dart';

/// Text drawn with a solid [outline] around each glyph (and optionally a solid drop [shadow]
/// [shadowOffset] below it), so it stays legible on top of busy or light candy colors. [style]
/// must not set a color; the fill color is [color].
class OutlinedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color color;
  final Color outline;
  final double outlineWidth;
  final Color? shadow;
  final double shadowOffset;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const OutlinedText(
    this.text, {
    super.key,
    required this.style,
    required this.color,
    required this.outline,
    this.outlineWidth = 3,
    this.shadow,
    this.shadowOffset = 0,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  Widget _text(TextStyle style, {bool excludeSemantics = true}) {
    final text = Text(
      this.text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
    return excludeSemantics ? ExcludeSemantics(child: text) : text;
  }

  TextStyle _stroke(Color color, double width) => style.copyWith(
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..color = color,
  );

  @override
  Widget build(BuildContext context) {
    final shadow = this.shadow;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (shadow != null) ...[
          Transform.translate(
            offset: Offset(0, shadowOffset),
            child: _text(_stroke(shadow, outlineWidth * 2)),
          ),
          Transform.translate(
            offset: Offset(0, shadowOffset),
            child: _text(style.copyWith(color: shadow)),
          ),
        ],
        _text(_stroke(outline, outlineWidth * 2)),
        _text(style.copyWith(color: color), excludeSemantics: false),
      ],
    );
  }
}

/// Big puffy display text: the display font in a candy [color], with a thick white outline and a
/// solid [shadow] beneath it, like the game's logo lettering.
class PuffyText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final Color shadow;
  final TextAlign? textAlign;

  const PuffyText(
    this.text, {
    super.key,
    required this.size,
    this.color = const Color(0xFFF0457A),
    this.shadow = const Color(0xFF7E1239),
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedText(
      text,
      style: TextStyle(fontFamily: AppFonts.display, fontSize: size, height: 1.1),
      color: color,
      outline: Colors.white,
      outlineWidth: math.max(2, size * 0.06),
      shadow: shadow,
      shadowOffset: math.max(2, size * 0.08),
      textAlign: textAlign,
    );
  }
}

/// The bold, white, italic, all-caps label on a solid colored tab, like the game's DEPTH / SCORE /
/// AIR headings. A label too long for the space available shrinks to fit rather than truncating.
class HudBanner extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  const HudBanner({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 12,
    this.borderRadius = const BorderRadius.only(bottomRight: Radius.circular(12)),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: fontSize * 0.9, vertical: fontSize * 0.5),
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: fontSize * 0.1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A number shown as the game's rounded gray digit tiles: every digit in [value] gets its own tile,
/// and any other character (a `:` or `/` separator) is drawn smaller between them. [pips] adds that
/// many orange placeholder dots in front, the way the game pads its counters.
class DigitTiles extends StatelessWidget {
  final String value;
  final double height;
  final int pips;

  const DigitTiles({super.key, required this.value, this.height = 32, this.pips = 0});

  @override
  Widget build(BuildContext context) {
    final width = height * 0.75;
    return Semantics(
      label: value,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < pips; i++)
            Container(
              width: height * 0.31,
              height: height * 0.31,
              margin: EdgeInsets.only(right: height * 0.1),
              decoration: const BoxDecoration(color: Color(0xFFE8650E), shape: BoxShape.circle),
            ),
          for (final c in value.split(''))
            if (RegExp(r'\d').hasMatch(c))
              Container(
                width: width,
                height: height,
                margin: EdgeInsets.symmetric(horizontal: height * 0.05),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height * 0.22),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.tileTop, AppColors.tileBottom],
                  ),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), offset: Offset(0, 1))],
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: height * 0.68,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.tileText,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: height * 0.04),
                child: Text(
                  c,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: height * 0.56,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF9A90A8),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// A white HUD card with a [HudBanner] tab in its top-left corner, holding [child] centered below.
class HudCard extends StatelessWidget {
  final String label;
  final Color bannerColor;
  final Widget child;
  final double? height;

  const HudCard({
    super.key,
    required this.label,
    required this.bannerColor,
    required this.child,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudBanner(label: label, color: bannerColor),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }
}

/// The game's round AIR gauge: a blue pie showing [fraction] (0..1) remaining inside a green
/// ring, with [label] in a white center.
class AirGauge extends StatelessWidget {
  final double fraction;
  final String label;
  final double size;

  const AirGauge({super.key, required this.fraction, required this.label, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label remaining',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AirGaugePainter(fraction.clamp(0.0, 1.0)),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: size * 0.22,
                height: 1,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AirGaugePainter extends CustomPainter {
  final double fraction;

  _AirGaugePainter(this.fraction);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final ringWidth = size.width * 0.07;
    final pieRadius = radius - ringWidth;
    canvas.drawCircle(center, radius, Paint()..color = AppColors.airRing);
    canvas.drawCircle(center, pieRadius, Paint()..color = AppColors.airEmpty);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: pieRadius),
      -math.pi / 2,
      2 * math.pi * fraction,
      true,
      Paint()..color = AppColors.airBlue,
    );
    canvas.drawCircle(center, pieRadius * 0.7, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AirGaugePainter oldDelegate) => oldDelegate.fraction != fraction;
}

/// A chunky candy-colored pill button: candy gradient on a solid [CandyColors.outline] drop
/// shadow, which it sinks into while pressed.
class CandyButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final CandyColors colors;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  const CandyButton({
    super.key,
    required this.label,
    required this.colors,
    required this.onPressed,
    this.icon,
    this.height = 44,
    this.fontSize = 15,
  });

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final depth = widget.height * 0.09;
    final sink = _pressed ? depth * 0.7 : 0.0;
    final textStyle = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: widget.fontSize,
      height: 1,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: widget.fontSize * 0.08,
    );
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: Container(
          height: widget.height + depth,
          padding: EdgeInsets.only(top: sink, bottom: depth - sink),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: widget.height * 0.38),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.hi, c.base, c.lo],
                stops: const [0, 0.5, 1],
              ),
              boxShadow: [BoxShadow(color: c.outline, offset: Offset(0, depth - sink))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: widget.fontSize * 1.2,
                    color: Colors.white,
                    shadows: [Shadow(color: c.outline, offset: const Offset(0, 1.5))],
                  ),
                  SizedBox(width: widget.fontSize * 0.4),
                ],
                OutlinedText(
                  widget.label,
                  style: textStyle,
                  color: Colors.white,
                  outline: c.outline,
                  outlineWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A strip of round frosting drips in [color] hanging off one edge onto [background] -- the
/// border between a cream HUD panel and the navy playfield. [axis] horizontal hangs the drips
/// down from the top edge; vertical hangs them leftwards from the right edge.
class DripEdge extends StatelessWidget {
  final Color color;
  final Color background;
  final Axis axis;
  final double depth;

  const DripEdge({
    super.key,
    this.color = AppColors.cream,
    this.background = AppColors.navyTop,
    this.axis = Axis.horizontal,
    this.depth = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: axis == Axis.vertical ? depth : double.infinity,
      height: axis == Axis.horizontal ? depth : double.infinity,
      child: CustomPaint(painter: _DripPainter(color, background, axis)),
    );
  }
}

class _DripPainter extends CustomPainter {
  final Color color;
  final Color background;
  final Axis axis;

  _DripPainter(this.color, this.background, this.axis);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()..color = color;
    const period = 46.0;
    final length = axis == Axis.horizontal ? size.width : size.height;
    for (var p = 0.0; p < length + period; p += period) {
      for (final (offset, radius) in const [(18.0, 11.0), (31.0, 7.0)]) {
        final along = p + offset;
        canvas.drawCircle(
          axis == Axis.horizontal ? Offset(along, 0) : Offset(size.width, along),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DripPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.axis != axis;
}

/// Soft white bubbles scattered behind a cream HUD panel's content. Positions are fractions of the
/// panel's size, and radii are in pixels, so they look the same however the panel is sized.
class Bubbles extends StatelessWidget {
  final List<(double x, double y, double radius)> bubbles;

  const Bubbles({
    super.key,
    this.bubbles = const [(1.0, 0.0, 60), (0.78, 0.04, 23), (0.8, 0.3, 11), (0.05, 0.95, 30)],
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _BubblesPainter(bubbles)));
  }
}

class _BubblesPainter extends CustomPainter {
  final List<(double, double, double)> bubbles;

  _BubblesPainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (final (x, y, r) in bubbles) {
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) => oldDelegate.bubbles != bubbles;
}

/// The game's rainbow depth ruler, with a glowing marker at [progress] (0..1) down its length.
class DepthRuler extends StatelessWidget {
  final double progress;
  final double width;

  const DepthRuler({super.key, required this.progress, this.width = 12});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: CustomPaint(painter: _DepthRulerPainter(progress.clamp(0.0, 1.0))),
    );
  }
}

class _DepthRulerPainter extends CustomPainter {
  final double progress;

  _DepthRulerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.width / 2);
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF5A6E),
            Color(0xFFFFA23B),
            Color(0xFFFFE15C),
            Color(0xFF5BD37A),
            Color(0xFF3BA4F0),
            Color(0xFF8B6CF0),
          ],
        ).createShader(Offset.zero & size),
    );
    final tick = Paint()..color = AppColors.navyBottom.withValues(alpha: 0.6);
    for (var y = 22.0; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), tick);
    }
    canvas.restore();

    final y = 3 + (size.height - 6) * progress;
    final marker = RRect.fromRectAndRadius(
      Rect.fromLTWH(-4, y - 3, size.width + 8, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      marker,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(marker, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DepthRulerPainter oldDelegate) => oldDelegate.progress != progress;
}

/// A rounded navy panel on the playfield, holding a section of a drill or a count-in. While
/// [active] its border turns gold and it gets a soft gold glow.
class PlayfieldPanel extends StatelessWidget {
  final Widget child;
  final bool active;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  const PlayfieldPanel({
    super.key,
    required this.child,
    this.active = false,
    this.minHeight,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      padding: padding,
      // Only needed to center content within a minHeight. Without one, leave it off: a Container
      // with an alignment expands to fill any bounded height it's given (e.g. a SectionView
      // capped at the viewport's height), instead of shrink-wrapping its content.
      alignment: minHeight != null ? Alignment.center : null,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? AppColors.gold : AppColors.panelBorder, width: 2),
        boxShadow: active
            ? [
                BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), spreadRadius: 4),
                const BoxShadow(color: Color(0x59000000), offset: Offset(0, 8), blurRadius: 24),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// A round dark-ink icon button (back, settings, etc.) for cream HUD panels.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.inkShadow, offset: Offset(0, 3))],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}
