import 'package:flutter/material.dart';

import '../util/colors.dart';

// The mitsudomoe, in units of the drum head's radius around its middle: three tomoe, each a
// round head with a tail swirling around the rim. Converted from the paths in Left3domoe.svg, by
// "mac an" on Wikimedia Commons, which is in the public domain.
final Path _mitsudomoe = Path()
  ..moveTo(0.0915, -0.8409)
  ..cubicTo(0.2240, -0.7898, 0.3344, -0.7096, 0.4127, -0.6067)
  ..cubicTo(0.5014, -0.4896, 0.5489, -0.3281, 0.5390, -0.1783)
  ..cubicTo(0.5335, -0.0957, 0.5353, -0.0988, 0.4934, -0.1142)
  ..cubicTo(0.4398, -0.1333, 0.3504, -0.1358, 0.2968, -0.1192)
  ..cubicTo(0.1895, -0.0871, 0.0952, 0.0078, 0.0570, 0.1219)
  ..cubicTo(0.0416, 0.1681, 0.0416, 0.2556, 0.0564, 0.2988)
  ..cubicTo(0.0884, 0.3900, 0.1766, 0.4800, 0.2746, 0.5213)
  ..cubicTo(0.4780, 0.6069, 0.7369, 0.4430, 0.8281, 0.1705)
  ..cubicTo(0.8515, 0.1003, 0.8515, 0.1003, 0.8509, -0.0014)
  ..cubicTo(0.8509, -0.1863, 0.8096, -0.3263, 0.7110, -0.4767)
  ..cubicTo(0.5735, -0.6868, 0.3344, -0.8311, 0.0823, -0.8551)
  ..lineTo(0.0453, -0.8588)
  ..lineTo(0.0915, -0.8409)
  ..close()
  ..moveTo(-0.2105, -0.8175)
  ..cubicTo(-0.2832, -0.8039, -0.3258, -0.7916, -0.3689, -0.7713)
  ..cubicTo(-0.5637, -0.6788, -0.7289, -0.4951, -0.8010, -0.2905)
  ..cubicTo(-0.8374, -0.1876, -0.8485, -0.1210, -0.8478, -0.0045)
  ..cubicTo(-0.8478, 0.1108, -0.8392, 0.1687, -0.8084, 0.2636)
  ..cubicTo(-0.7905, 0.3179, -0.7554, 0.3931, -0.7616, 0.3622)
  ..cubicTo(-0.7819, 0.2673, -0.7807, 0.1286, -0.7591, 0.0448)
  ..cubicTo(-0.7092, -0.1518, -0.5828, -0.3034, -0.3991, -0.3904)
  ..cubicTo(-0.3714, -0.4033, -0.3473, -0.4119, -0.3455, -0.4095)
  ..cubicTo(-0.3436, -0.4070, -0.3387, -0.3879, -0.3350, -0.3663)
  ..cubicTo(-0.2974, -0.1543, -0.0200, -0.0378, 0.1747, -0.1524)
  ..cubicTo(0.2838, -0.2159, 0.3492, -0.3910, 0.3165, -0.5303)
  ..cubicTo(0.2857, -0.6609, 0.1760, -0.7590, 0.0114, -0.8033)
  ..cubicTo(-0.0336, -0.8157, -0.1729, -0.8243, -0.2105, -0.8175)
  ..close()
  ..moveTo(-0.4571, -0.0982)
  ..cubicTo(-0.5840, -0.0600, -0.6654, 0.0189, -0.7011, 0.1373)
  ..cubicTo(-0.7159, 0.1853, -0.7159, 0.2988, -0.7018, 0.3573)
  ..cubicTo(-0.6753, 0.4652, -0.6173, 0.5693, -0.5415, 0.6458)
  ..cubicTo(-0.4583, 0.7302, -0.3023, 0.8036, -0.1433, 0.8350)
  ..cubicTo(-0.0638, 0.8504, 0.0884, 0.8486, 0.1698, 0.8313)
  ..cubicTo(0.3356, 0.7968, 0.4718, 0.7253, 0.5914, 0.6100)
  ..cubicTo(0.6450, 0.5589, 0.7141, 0.4769, 0.7141, 0.4639)
  ..cubicTo(0.7141, 0.4615, 0.6999, 0.4726, 0.6826, 0.4880)
  ..cubicTo(0.5581, 0.6002, 0.3664, 0.6673, 0.2043, 0.6556)
  ..cubicTo(0.0878, 0.6476, -0.0527, 0.5958, -0.1433, 0.5280)
  ..lineTo(-0.1772, 0.5022)
  ..lineTo(-0.1335, 0.4584)
  ..cubicTo(-0.0601, 0.3857, -0.0330, 0.3148, -0.0398, 0.2112)
  ..cubicTo(-0.0478, 0.0941, -0.0952, 0.0029, -0.1809, -0.0600)
  ..cubicTo(-0.2524, -0.1130, -0.3578, -0.1278, -0.4571, -0.0982)
  ..close();

// The mitsudomoe's path above fills a circle of radius 0.86; this scales it to fill a circle of
// radius 1.
const double _fill = 1 / 0.86;

/// The traditional mitsudomoe (three "commas" swirling around the middle), in [color], filling a
/// circle the size of this widget.
class Mitsudomoe extends StatelessWidget {
  final Color color;

  const Mitsudomoe({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 1, child: CustomPaint(painter: _MitsudomoePainter(color)));
  }
}

class _MitsudomoePainter extends CustomPainter {
  final Color color;

  const _MitsudomoePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.translate(center.dx, center.dy);
    canvas.scale(size.shortestSide / 2 * _fill);
    canvas.drawPath(_mitsudomoe, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MitsudomoePainter oldDelegate) => oldDelegate.color != color;
}

/// A taiko drum head, drawn abstractly: a white head with the mitsudomoe in pink, matching the
/// rings around a [DrumBadge].
class TaikoDrumHead extends StatelessWidget {
  const TaikoDrumHead({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Mitsudomoe(color: _DrumBadgeColors.pink),
    );
  }
}

class _DrumBadgeColors {
  static const pink = Color(0xFFF0457A);
  static const pinkShadow = Color(0xFFC21F55);
  static const blue = Color(0xFF5DB7F5);
}

/// The app's badge: a [TaikoDrumHead] (or some other [child], cropped to a circle [size] across)
/// inside white, blue, white, and pink rings, on a solid pink drop shadow. The rings are drawn
/// outside of [size], taking up [ringWidth] more on each side (and the shadow a little more below):
/// see [footprint].
class DrumBadge extends StatelessWidget {
  final double size;
  final Widget? child;

  const DrumBadge({super.key, required this.size, this.child, this.ringWidth = 29});

  /// How far out the rings reach beyond the head, on each side.
  final double ringWidth;

  /// The whole badge's width, rings included.
  double get footprint => size + 2 * ringWidth;

  @override
  Widget build(BuildContext context) {
    // The rings, out from the head: white to 7/29 of the way, blue to 15/29, white to 21/29, then
    // pink the rest of the way.
    final w = ringWidth;
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.all(w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _DrumBadgeColors.pinkShadow,
            spreadRadius: w,
            offset: Offset(0, w * 7 / 29),
          ),
          BoxShadow(color: _DrumBadgeColors.pink, spreadRadius: w),
          BoxShadow(color: Colors.white, spreadRadius: w * 21 / 29),
          BoxShadow(color: _DrumBadgeColors.blue, spreadRadius: w * 15 / 29),
          BoxShadow(color: Colors.white, spreadRadius: w * 7 / 29),
        ],
      ),
      child: ClipOval(child: child ?? const TaikoDrumHead()),
    );
  }
}

/// The app's icon, [size] across: a [DrumBadge] on the app's cream background -- or, if only its
/// [foreground], on nothing, and smaller (for an Android adaptive icon's foreground layer, which
/// the system crops into all sorts of shapes, so only its middle two thirds are sure to show).
/// This is what assets/icon/ is rendered from (see tool/generate_icons_test.dart).
class AppIcon extends StatelessWidget {
  final double size;
  final bool foreground;

  const AppIcon({super.key, required this.size, this.foreground = false});

  @override
  Widget build(BuildContext context) {
    // The badge's rings are as wide, relative to its head, as the menu's (29 around a 212 head).
    final badge = size * (foreground ? 0.62 : 0.86);
    final head = badge / (1 + 2 * 29 / 212);
    final ring = (badge - head) / 2;
    return Container(
      width: size,
      height: size,
      color: foreground ? null : AppColors.cream,
      alignment: Alignment.center,
      // Nudged up by half the badge's drop shadow, so it looks centered.
      padding: EdgeInsets.only(bottom: ring * 7 / 29),
      child: DrumBadge(size: head, ringWidth: ring),
    );
  }
}
