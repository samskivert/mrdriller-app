import 'package:flutter/widgets.dart';

import '../model/model.dart';

/// The shading for one family of candy-block colors (a stroke block, a candy button): a vertical
/// gradient from [hi] through [base] to [lo], sitting on a solid [outline] drop-shadow, with
/// [icing] for the drippy frosting on top of accented blocks. [outline] also outlines any white
/// text drawn on the block, which is what keeps that text legible on the lighter candy colors.
class CandyColors {
  final Color base;
  final Color hi;
  final Color lo;
  final Color outline;
  final Color icing;

  const CandyColors({
    required this.base,
    required this.hi,
    required this.lo,
    required this.outline,
    required this.icing,
  });
}

/// Central color palette: the arcade (Mr. Driller inspired) theme -- a navy "playfield" for drill
/// notation, cream "HUD" panels around it, saturated banner colors for labels, and candy colors
/// for strokes and buttons. Also still holds the original flat palette, for the screens that
/// haven't been converted to the arcade look yet.
class AppColors {
  AppColors._();

  // Playfield
  static const navy = Color(0xFF121C36);
  static const navyTop = Color(0xFF17244C);
  static const navyBottom = Color(0xFF111A35);
  static const panel = Color(0xFF1F2D55);
  static const panelBorder = Color(0xFF2F4277);
  static const gold = Color(0xFFFFD24A);
  static const goldOutline = Color(0xFF6E3F00);
  static const repeatDot = Color(0xFFFF9A4D);

  // HUD
  static const cream = Color(0xFFFFF6E3);
  static const creamShadow = Color(0xFFEAD8B2);
  static const ink = Color(0xFF2B2350);
  static const inkShadow = Color(0xFF14102A);
  static const inkMuted = Color(0xFF6B5E7E);
  static const tileTop = Color(0xFFFAFAFC);
  static const tileBottom = Color(0xFFC9CBD6);
  static const tileText = Color(0xFF33354A);
  static const gaugeBlue = Color(0xFF2E7BE6);
  static const gaugeEmpty = Color(0xFFD8E6FA);
  static const gaugeRing = Color(0xFF3FBF68);

  // Banner colors: dark enough for white bold text to meet contrast, in the order sections cycle
  // through them.
  static const bannerOrange = Color(0xFFC24E00);
  static const bannerRed = Color(0xFFD01F4C);
  static const bannerMagenta = Color(0xFFA928B5);
  static const bannerBlue = Color(0xFF2F62D6);
  static const bannerGreen = Color(0xFF1E8046);
  static const banners = [bannerOrange, bannerRed, bannerMagenta, bannerBlue, bannerGreen];

  static Color banner(int index) => banners[index % banners.length];

  // Candy colors
  static const candyBlue = CandyColors(
    base: Color(0xFF3BA4F0),
    hi: Color(0xFF9AD8FF),
    lo: Color(0xFF1A6CC0),
    outline: Color(0xFF0D3B70),
    icing: Color(0xFFE6F6FF),
  );
  static const candyOrange = CandyColors(
    base: Color(0xFFFFAE1F),
    hi: Color(0xFFFFDB75),
    lo: Color(0xFFE57A00),
    outline: Color(0xFF7E3E00),
    icing: Color(0xFFFFF5CC),
  );
  static const candyPink = CandyColors(
    base: Color(0xFFFF6FA0),
    hi: Color(0xFFFFB3CD),
    lo: Color(0xFFE03A73),
    outline: Color(0xFF7E1239),
    icing: Color(0xFFFFE6EF),
  );
  static const candyGreen = CandyColors(
    base: Color(0xFF49C96B),
    hi: Color(0xFF9BEBA9),
    lo: Color(0xFF23A04A),
    outline: Color(0xFF125A28),
    icing: Color(0xFFE4FBE8),
  );

  static const candyRed = CandyColors(
    base: Color(0xFFF0545F),
    hi: Color(0xFFFF9AA2),
    lo: Color(0xFFD02B3A),
    outline: Color(0xFF7A1020),
    icing: Color(0xFFFFE3E6),
  );
  static const candyGray = CandyColors(
    base: Color(0xFFA49CB5),
    hi: Color(0xFFCFC9DB),
    lo: Color(0xFF857C99),
    outline: Color(0xFF4E4760),
    icing: Color(0xFFEEEAF4),
  );

  static CandyColors handCandy(Hand hand) => hand == Hand.R ? candyBlue : candyOrange;

  // The original flat palette, mirroring the web app's (see web/src/ui.tsx,
  // web/src/components.tsx), still used by the not-yet-converted screens.
  static const btnBlue = Color(0xFF3E63DD);
  static const btnGreen = Color(0xFF30A46C);
  static const btnRed = Color(0xFFEF4444);
  static const btnGray = Color(0xFF6B7280);

  static const textGray = Color(0xFF6B7280);

  static const highlightBg = Color(0xFFFFF3C4);
  static const normalBorder = Color(0xFF999999);
  static const normalBg = Color(0xFFF9F9FB);

  static const brandRed = Color(0xFFF03564);
  static const brandOutline = Color(0xFF6F2223);
}

/// Font families bundled in assets/fonts (see pubspec.yaml).
class AppFonts {
  AppFonts._();

  /// Rounded UI font (weights 400-900), with the app's Japanese glyphs.
  static const body = 'MPLUSRounded1c';

  /// Puffy display font for titles and big arcade text (single weight).
  static const display = 'MochiyPopOne';
}
