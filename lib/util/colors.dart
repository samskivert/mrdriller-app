import 'package:flutter/widgets.dart';

import '../model/model.dart';

/// Central color palette, mirroring the web app's hand colors, button palette, and highlight
/// styling (see web/src/StrokeView.tsx, web/src/ui.tsx, web/src/components.tsx).
class AppColors {
  AppColors._();

  static const handRight = Color(0xFF0072B7);
  static const handLeft = Color(0xFFFF9A00);

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

  static Color handColor(Hand hand) => hand == Hand.R ? handRight : handLeft;
}
