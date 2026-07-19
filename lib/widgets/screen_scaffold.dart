import 'package:flutter/material.dart';

import 'app_header.dart';

/// The "header, then scrollable width-capped content" shell shared by most of the app's screens:
/// a [Scaffold] + [SafeArea] wrapping an [AppHeader] above a scrollable, centered,
/// [contentMaxWidth]-capped [child]. Defaults match the most common case; pass the other
/// parameters to match a screen that deviates (e.g. extra header spacing, different scroll
/// padding, or top-aligned instead of centered content).
class ScreenScaffold extends StatelessWidget {
  final String title;
  final bool showSettings;
  final Widget? headerTrailing;
  final EdgeInsetsGeometry headerPadding;
  // Extra space below the header -- used by screens whose headerPadding has no bottom inset of
  // its own (see settings/pattern-trainer, which reserve that room for other reasons).
  final double headerBottomSpacing;
  final double? contentMaxWidth;
  final EdgeInsetsGeometry contentPadding;
  final AlignmentGeometry contentAlignment;
  final Widget child;

  const ScreenScaffold({
    super.key,
    required this.title,
    this.showSettings = true,
    this.headerTrailing,
    this.headerPadding = const EdgeInsets.all(12),
    this.headerBottomSpacing = 0,
    this.contentMaxWidth,
    this.contentPadding = const EdgeInsets.all(16),
    this.contentAlignment = Alignment.center,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: headerPadding,
              child: AppHeader(title: title, showSettings: showSettings, trailing: headerTrailing),
            ),
            if (headerBottomSpacing > 0) SizedBox(height: headerBottomSpacing),
            Expanded(
              child: SingleChildScrollView(
                padding: contentPadding,
                child: Align(
                  alignment: contentAlignment,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth ?? double.infinity),
                    child: child,
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
