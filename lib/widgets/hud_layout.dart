import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/screen_cutout.dart';
import '../util/colors.dart';
import 'arcade.dart';

/// The arcade screen layout shared by the drill screens: a navy playfield holding [playfield], and
/// a cream HUD panel -- [hud] across the top of the screen in portrait, or [sidebar] down the right
/// of the playfield in landscape -- joined by a frosting drip edge.
///
/// Handles the safe area: in landscape it keeps clear of the camera cutout on whichever side it's
/// on, but reclaims most of the inset on the other side (which is only there for the screen's
/// rounded corners), and lets the playfield run beneath the home indicator. [playfield] itself is
/// already kept clear of every inset, so it sees none in its [MediaQuery].
///
/// [playfield] keeps its state when the phone rotates between portrait and landscape (which puts it
/// at a different spot in the widget tree), so e.g. a running drill carries on uninterrupted.
class HudLayout extends StatefulWidget {
  final Widget playfield;
  final Widget hud;
  final Widget sidebar;

  const HudLayout({super.key, required this.playfield, required this.hud, required this.sidebar});

  @override
  State<HudLayout> createState() => _HudLayoutState();
}

class _HudLayoutState extends State<HudLayout> {
  // Lets Flutter move the same playfield (and all its state) between the portrait and landscape
  // trees when the phone rotates, instead of tearing it down and building a new one.
  final _playfieldKey = GlobalKey();

  // The screen size we last asked the platform about its cutout for: asked again whenever it
  // changes (i.e. on rotation), with any change in the answer notified via cutoutSideChanges.
  Size? _cutoutQueriedFor;

  // In landscape, the safe-area insets to actually keep clear of: the full inset on the side with
  // the camera cutout, but on the other side (where the inset is only there for the screen's
  // rounded corners) just a small margin, to reclaim the rest for the playfield.
  EdgeInsets _landscapeInsets(EdgeInsets safe) {
    const cornerMargin = 16.0;
    final cutout = landscapeCutoutSide(View.of(context));
    if (cutout == null) return safe;
    return EdgeInsets.only(
      left: cutout == CutoutSide.left ? safe.left : math.min(safe.left, cornerMargin),
      top: safe.top,
      right: cutout == CutoutSide.right ? safe.right : math.min(safe.right, cornerMargin),
      bottom: safe.bottom,
    );
  }

  Widget _playfield() => KeyedSubtree(
    key: _playfieldKey,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
      ),
      // The layout has already kept the playfield clear of any safe-area insets.
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: widget.playfield,
      ),
    ),
  );

  Widget _portrait(EdgeInsets safe) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ColoredBox(
        color: AppColors.cream,
        // The bubbles fill the whole panel, right up behind the status bar, not just the padded
        // area the HUD itself sits in.
        child: Stack(
          children: [
            const Positioned.fill(child: Bubbles()),
            Padding(
              padding: EdgeInsets.fromLTRB(safe.left + 16, safe.top + 14, safe.right + 16, 14),
              child: widget.hud,
            ),
          ],
        ),
      ),
      const DripEdge(),
      Expanded(
        // The playfield can run beneath the home indicator.
        child: Padding(
          padding: EdgeInsets.only(left: safe.left, right: safe.right),
          child: _playfield(),
        ),
      ),
    ],
  );

  Widget _landscape(EdgeInsets safe, double height) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Container(
          color: AppColors.navyTop,
          // The playfield can run beneath the home indicator.
          padding: EdgeInsets.only(left: safe.left, top: safe.top),
          child: _playfield(),
        ),
      ),
      const DripEdge(axis: Axis.vertical),
      Container(
        // Narrower on a short phone held sideways, where every pixel of playfield counts.
        width: (height < 500 ? 240 : 290) + safe.right,
        color: AppColors.cream,
        child: Stack(
          children: [
            const Positioned.fill(child: Bubbles()),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14, safe.top + 14, safe.right + 14, safe.bottom + 14),
              child: widget.sidebar,
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.size.width > media.size.height;
    if (media.size != _cutoutQueriedFor) {
      _cutoutQueriedFor = media.size;
      refreshCutoutSide();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status bar icons sit over the cream HUD in portrait, but over the navy playfield in
      // landscape.
      value: isLandscape ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: isLandscape
            ? ListenableBuilder(
                listenable: cutoutSideChanges,
                builder: (context, _) =>
                    _landscape(_landscapeInsets(media.padding), media.size.height),
              )
            : _portrait(media.padding),
      ),
    );
  }
}

/// The HUD's round back button.
class HudBackButton extends StatelessWidget {
  const HudBackButton({super.key});

  @override
  Widget build(BuildContext context) => RoundIconButton(
    icon: Icons.arrow_back_rounded,
    tooltip: 'Back',
    onPressed: () => Navigator.of(context).pop(),
  );
}

/// The HUD's round settings button.
class HudSettingsButton extends StatelessWidget {
  const HudSettingsButton({super.key});

  @override
  Widget build(BuildContext context) => RoundIconButton(
    icon: Icons.settings_rounded,
    tooltip: 'Settings',
    onPressed: () => Navigator.of(context).pushNamed('/settings'),
  );
}

/// A screen's title in the HUD, in the display font: one line in a portrait HUD, or up to two
/// (smaller) in a landscape sidebar. An optional [subtitle] goes on a line of its own below it.
class HudTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool sidebar;

  const HudTitle(this.title, {super.key, this.subtitle, this.sidebar = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      maxLines: sidebar ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: sidebar ? 17 : 21,
        height: 1.15,
        color: AppColors.ink,
      ),
    );
    final subtitle = this.subtitle;
    if (subtitle == null) return text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text,
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 13,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// The layout for the app's non-playfield screens: a cream background with bubbles, under a header
/// of a back button, [title], any [actions] (e.g. more [RoundIconButton]s), and (if
/// [showSettings]) a settings button, with [child] filling the
/// rest of the screen (and doing its own scrolling, if it needs to). [child] is responsible for
/// keeping its content clear of the left/right/bottom safe-area insets, so that it can scroll
/// beneath them.
class CreamScreen extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final bool showSettings;
  final Widget child;

  const CreamScreen({
    super.key,
    required this.title,
    this.actions = const [],
    this.showSettings = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Bubbles(
                bubbles: [(1.0, 0.0, 90), (0.82, 0.05, 30), (0.0, 0.45, 70), (0.95, 0.8, 50)],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(safe.left + 16, safe.top + 14, safe.right + 16, 10),
                  child: Row(
                    children: [
                      const HudBackButton(),
                      const SizedBox(width: 12),
                      Expanded(child: HudTitle(title)),
                      for (final action in actions) ...[const SizedBox(width: 10), action],
                      if (showSettings) ...[const SizedBox(width: 10), const HudSettingsButton()],
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
