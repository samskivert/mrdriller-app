// Building blocks for the app's arcade (Mr. Driller inspired) look: outlined and puffy text, HUD
// banners and digit tiles, the time gauge, candy buttons, and the decorative drips/bubbles/ruler.

import 'dart:async';
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
/// and any other character (a `:` or `/` separator) is drawn smaller between them.
class DigitTiles extends StatelessWidget {
  final String value;
  final double height;

  const DigitTiles({super.key, required this.value, this.height = 32});

  @override
  Widget build(BuildContext context) {
    final width = height * 0.75;
    return Semantics(
      label: value,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

/// A chunky candy-colored pill button: candy gradient on a solid [CandyColors.outline] drop
/// shadow, which it sinks into while pressed. With no [label] it's a round icon-only button, which
/// needs a [tooltip] (also used as its accessibility label). [below] is shown under the label.
/// With [repeat], holding it down keeps pressing it (e.g. a stepper's -/+), faster than tapping.
/// It's faded out while disabled (with no [onPressed]).
class CandyButton extends StatefulWidget {
  final String? label;
  final String? tooltip;
  final IconData? icon;
  final Widget? below;
  final CandyColors colors;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final bool repeat;

  const CandyButton({
    super.key,
    this.label,
    this.tooltip,
    required this.colors,
    required this.onPressed,
    this.icon,
    this.below,
    this.height = 44,
    this.fontSize = 15,
    this.repeat = false,
  });

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _pressed = false;
  Timer? _repeatTimer;
  bool _repeated = false;

  void _setPressed(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  void _handleDown() {
    _setPressed(true);
    if (!widget.repeat) return;
    _repeated = false;
    _repeatTimer?.cancel();
    _repeatTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        _repeated = true;
        widget.onPressed?.call();
      });
    });
  }

  void _handleUp() {
    _setPressed(false);
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _handleTap() {
    // A hold that already repeated doesn't also count as a tap when it's released.
    if (!_repeated) widget.onPressed?.call();
    _repeated = false;
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  Widget _withBelow(Widget content) {
    final below = widget.below;
    if (below == null) return content;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        SizedBox(height: widget.fontSize * 0.3),
        below,
      ],
    );
  }

  /// Trims the blank margin off the leading side of [icon] (of [size]), which would otherwise shift
  /// a button's icon and label off center: Material icons leave a sixth or so of their width blank
  /// on each side (a third on the play arrow's left), so this splits the difference at 5/24.
  Widget _trimmed(Widget icon, {required double size}) => SizedBox(
    width: size * 19 / 24,
    height: size,
    child: OverflowBox(
      minWidth: size,
      maxWidth: size,
      alignment: Alignment.centerRight,
      child: icon,
    ),
  );

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
    final label = widget.label;
    Widget icon(double size) => Icon(
      widget.icon,
      size: size,
      color: Colors.white,
      shadows: [Shadow(color: c.outline, offset: const Offset(0, 1.5))],
    );
    final iconSize = widget.fontSize * 1.2;
    final button = Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.tooltip,
      child: GestureDetector(
        onTapDown: widget.onPressed == null ? null : (_) => _handleDown(),
        onTapUp: (_) => _handleUp(),
        onTapCancel: _handleUp,
        onTap: widget.onPressed == null ? null : _handleTap,
        child: Container(
          height: widget.height + depth,
          padding: EdgeInsets.only(top: sink, bottom: depth - sink),
          child: Container(
            width: label == null ? widget.height : null,
            // Enough to keep the label clear of the rounded ends, but capped: on a tall button the
            // label is much shorter than the button, so the ends barely curve in beside it.
            padding: label == null
                ? null
                : EdgeInsets.symmetric(horizontal: math.min(widget.height * 0.38, 18)),
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
            // Shrinks to fit if squeezed (e.g. a long label in a narrow sidebar).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _withBelow(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null)
                      label == null
                          ? icon(widget.height * 0.6)
                          : _trimmed(icon(iconSize), size: iconSize),
                    if (widget.icon != null && label != null)
                      SizedBox(width: widget.fontSize * 0.4),
                    if (label != null) ...[
                      OutlinedText(
                        label,
                        style: textStyle,
                        color: Colors.white,
                        outline: c.outline,
                        outlineWidth: 2,
                      ),
                      // The font has no italic, so the label is slanted synthetically, which
                      // leans its top past the end of its box: make room for that, so the label
                      // looks centered.
                      SizedBox(width: widget.fontSize * 0.2),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Faded out while disabled.
    final shown = widget.onPressed == null ? Opacity(opacity: 0.4, child: button) : button;
    final tooltip = widget.tooltip;
    return tooltip == null ? shown : Tooltip(message: tooltip, child: shown);
  }
}

/// A strip of round frosting drips in [color] hanging off one edge onto [background] -- the
/// border between a cream HUD panel and the navy playfield. [axis] horizontal hangs the drips
/// down from the top edge; vertical hangs them rightwards from the left edge.
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
          axis == Axis.horizontal ? Offset(along, 0) : Offset(0, along),
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
          colors: AppColors.rainbow,
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
/// [active] its border turns gold and it gets a soft gold glow. It stretches to the full width
/// available unless not [expand]ed, in which case it shrinks to fit [child].
class PlayfieldPanel extends StatelessWidget {
  final Widget child;
  final bool active;
  final bool expand;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  const PlayfieldPanel({
    super.key,
    required this.child,
    this.active = false,
    this.expand = true,
    this.minHeight,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expand ? double.infinity : null,
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

  static const defaultSize = 44.0;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = defaultSize,
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

/// A big candy menu button with icing dripping off its top: an [icon] on a dark chip, a [title]
/// and [subtitle] in outlined white text, and a chevron. It sinks into its drop shadow while
/// pressed.
class CandyMenuButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final CandyColors colors;
  final VoidCallback onPressed;
  // Squeezed in (e.g. two side by side on a phone): no chevron, less space, and the text shrinking
  // to fit if need be.
  final bool compact;

  const CandyMenuButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onPressed,
    this.compact = false,
  });

  /// How tall it is, including its drop shadow.
  static const totalHeight = 75.0;

  @override
  State<CandyMenuButton> createState() => _CandyMenuButtonState();
}

class _CandyMenuButtonState extends State<CandyMenuButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    const depth = 5.0;
    const height = CandyMenuButton.totalHeight - depth;
    final compact = widget.compact;
    // Shrinks [text] to fit, when compact.
    Widget fit(Widget text) => compact
        ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: text)
        : text;
    final sink = _pressed ? 3.5 : 0.0;
    TextStyle style(double size) => TextStyle(
      fontFamily: AppFonts.body,
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w900,
    );
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: Padding(
          padding: EdgeInsets.only(top: sink, bottom: depth - sink),
          child: CustomPaint(
            painter: _IcedPainter(c, depth - sink),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 9, compact ? 12 : 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.outline,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                    SizedBox(width: compact ? 10 : 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fit(
                            OutlinedText(
                              widget.title,
                              style: style(21),
                              color: Colors.white,
                              outline: c.outline,
                              outlineWidth: 2,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          fit(
                            OutlinedText(
                              widget.subtitle,
                              style: style(12),
                              color: Colors.white,
                              outline: c.outline,
                              outlineWidth: 1.5,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 30,
                        shadows: [Shadow(color: c.outline, offset: const Offset(0, 2))],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a candy-colored rounded slab on a [depth]-deep solid drop shadow, with a band of icing
/// across its top and round drips hanging off it.
class _IcedPainter extends CustomPainter {
  final CandyColors colors;
  final double depth;

  _IcedPainter(this.colors, this.depth);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawRRect(rrect.shift(Offset(0, depth)), Paint()..color = colors.outline);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.hi, colors.base, colors.lo],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, size.height - 4, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    final icing = Paint()..color = colors.icing;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 9), icing);
    for (var x = 0.0; x < size.width + 44; x += 44) {
      canvas.drawCircle(Offset(x + 14, 9), 7, icing);
      canvas.drawCircle(Offset(x + 34, 8), 4, icing);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IcedPainter old) => old.colors != colors || old.depth != depth;
}
