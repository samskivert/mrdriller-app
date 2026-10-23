import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../services/taiko_drum.dart';
import '../state/app_info.dart';
import '../state/app_name.dart';
import '../state/playlists.dart';
import '../state/reminders.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/drill_practice_view.dart';
import '../widgets/hud_layout.dart';
import '../widgets/taiko_drum_head.dart';

final List<Tool> tools = [const Tool(id: 'pattern-trainer', title: 'Pattern Trainer')];

/// The main menu: the logo and character artwork, and big candy buttons for each activity. The
/// artwork sits above the buttons in portrait, and to their left in landscape (or on a wide
/// screen).
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  // How wide a column of its own the settings button needs, in landscape.
  static const _settingsColumnWidth = 68.0;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width - safe.horizontal > size.height;
    // In landscape, the settings button gets a column of its own down the right side, so the
    // buttons can start at the top without running into it: in the safe-area inset there if
    // there's room (which, with the camera cutout on that side, is still clear of it at the top),
    // or else taking the room from the menu.
    final right = wide ? math.max(safe.right, _settingsColumnWidth) : safe.right;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Bubbles(
                bubbles: [(0.0, 0.18, 90), (0.12, 0.09, 32), (1.0, 0.42, 75), (0.0, 1.0, 60)],
              ),
            ),
            // Only the sides: the menus keep clear of the top and bottom insets themselves, so that
            // what scrolls can scroll under them.
            Padding(
              padding: EdgeInsets.only(left: safe.left, right: right),
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    wide ? _WideMenu(constraints.biggest) : _TallMenu(constraints.biggest),
              ),
            ),
            Positioned(
              // Lower in a side inset, to clear the screen's rounded corner.
              top: safe.top + (wide && safe.right > 0 ? 30 : 14),
              right: wide ? (right - RoundIconButton.defaultSize) / 2 : safe.right + 16,
              child: const HudSettingsButton(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portrait: the logo and artwork stacked above the buttons, all centered in a column. The artwork
/// shrinks to fit everything on screen, down to a point, past which the column scrolls (under the
/// top and bottom insets).
class _TallMenu extends StatelessWidget {
  final Size size;

  const _TallMenu(this.size);

  // The column's height, less the artwork's: the logo, buttons, footer, spacing, and the rings
  // around the artwork. (test/widget_test.dart checks that this keeps up with them.)
  static const nonHeroHeight = 642.0;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    // With a notch or Dynamic Island (a tall top inset), the logo tucks up into the bottom of the
    // status bar, which is empty in the middle, below the cutout. And the footer drops down into
    // the home indicator's inset, stopping just above the indicator itself.
    final top = insets.top >= 44 ? insets.top - 22 : insets.top;
    final bottom = math.max(insets.bottom - 26, 0.0);
    final height = size.height - top - bottom;
    final heroSize = math.min(size.width * 0.52, height - nonHeroHeight).clamp(110.0, 260.0);
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Logo(),
                  const SizedBox(height: 16),
                  _DrumPad(child: _Hero(size: heroSize)),
                  const SizedBox(height: 24),
                  const _MenuButtons(),
                  const SizedBox(height: 16),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Landscape (or a wide screen): the logo and artwork on the left, and the buttons on the right
/// (which scroll, under the top and bottom insets, if they don't fit). The settings button has its
/// own column to the right of this (see [MenuScreen]).
class _WideMenu extends StatelessWidget {
  final Size size;

  const _WideMenu(this.size);

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    // Room for the logo above it, and the rings around it.
    final heroSize = (size.height - insets.vertical - 190).clamp(100.0, 300.0);
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: insets.top, bottom: insets.bottom),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Logo(),
                      const SizedBox(height: 20),
                      _DrumPad(child: _Hero(size: heroSize)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, insets.top + 16, 16, insets.bottom + 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [_MenuButtons(), SizedBox(height: 20), _Footer()],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The puffy logo: the app's name (see [appName]) with its first word small, beside a star, over
/// the rest big -- e.g. "Taiko★" over "Trainer" -- and a tagline chip below.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: mrDrillerUnlocked, builder: (context, _) => _logo());
  }

  Widget _logo() {
    final name = appName();
    final space = name.indexOf(' ');
    final first = space < 0 ? '' : name.substring(0, space);
    final rest = name.substring(space + 1);
    return Semantics(
      header: true,
      label: name,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PuffyText(first, size: 30),
              const SizedBox(width: 4),
              const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 34, color: Colors.white),
                  Icon(Icons.star_rounded, size: 26, color: AppColors.gold),
                ],
              ),
            ],
          ),
          PuffyText(rest, size: 52),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'TAIKO DRILL TRAINER',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 1.8,
                color: AppColors.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Makes [child] (the round artwork, which looks like a drum) a drum: tapping its right or left
/// half plays a hit with that hand, and bumps it that way. Drumming the secret pattern on it (see
/// [DrumPatternDetector]) unlocks, or locks back up, the Mr. Driller easter egg.
class _DrumPad extends StatefulWidget {
  final Widget child;

  const _DrumPad({required this.child});

  @override
  State<_DrumPad> createState() => _DrumPadState();
}

class _DrumPadState extends State<_DrumPad> with SingleTickerProviderStateMixin {
  final _detector = DrumPatternDetector();
  late final _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
  Hand _side = Hand.R;

  @override
  void initState() {
    super.initState();
    preloadTaikoDrum();
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  void _handleHit(PointerDownEvent event) {
    final box = context.findRenderObject() as RenderBox;
    final hand = event.localPosition.dx < box.size.width / 2 ? Hand.L : Hand.R;
    hitTaikoDrum(hand);
    setState(() => _side = hand);
    _bump.forward(from: 0);
    if (_detector.hit(hand, DateTime.now())) {
      _toggleEasterEgg(box.localToGlobal(box.size.center(Offset.zero)));
    }
  }

  // (The name changes straight away, so that the logo already shows it as the celebration ends.)
  void _toggleEasterEgg(Offset from) {
    final unlocking = !mrDrillerUnlocked.value;
    setMrDrillerUnlocked(unlocking);
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      pageBuilder: (context, _, _) =>
          _EasterEggCelebration(text: unlocking ? 'MR. DRILLER!' : 'TAIKO TRAINER!', from: from),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A raw pointer listener, rather than a tap gesture: in the (scrolling) portrait menu, a tap
    // gesture would hold off until it's sure it isn't the start of a scroll, which would make the
    // drum lag behind the drumming.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handleHit,
      child: AnimatedBuilder(
        animation: _bump,
        builder: (context, child) {
          final bump = math.sin(math.pi * _bump.value);
          final direction = _side == Hand.R ? 1.0 : -1.0;
          return Transform.translate(
            offset: Offset(direction * 4 * bump, 3 * bump),
            child: Transform.rotate(
              angle: direction * 0.03 * bump,
              child: Transform.scale(scale: 1 - 0.035 * bump, child: child),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Celebrates the easter egg being found: [text] flies out of the logo (at [from]) with the clear
/// celebration's bling, then this closes itself (or sooner, if tapped).
class _EasterEggCelebration extends StatefulWidget {
  final String text;
  final Offset from;

  const _EasterEggCelebration({required this.text, required this.from});

  @override
  State<_EasterEggCelebration> createState() => _EasterEggCelebrationState();
}

class _EasterEggCelebrationState extends State<_EasterEggCelebration>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _animation.forward().whenComplete(_close);
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // (A dialog has no Material of its own above it, without which text is drawn with the
    // yellow-underlined "missing text style" look.)
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _close,
        child: ClearCelebration(
          text: widget.text,
          animation: _animation,
          start: widget.from,
          textSize: 40,
        ),
      ),
    );
  }
}

/// A taiko drum head (or, once the easter egg is unlocked, the Mr. Driller artwork) in a circle,
/// inside white, blue, white, and pink rings.
class _Hero extends StatelessWidget {
  final double size;

  const _Hero({required this.size});

  @override
  Widget build(BuildContext context) {
    return DrumBadge(
      size: size,
      child: ListenableBuilder(
        listenable: mrDrillerUnlocked,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: mrDrillerUnlocked.value
              // Zoomed in a little on Mr. Driller himself.
              ? Transform.scale(
                  key: const ValueKey('mr-driller'),
                  scale: 1.25,
                  alignment: const Alignment(0, -0.4),
                  child: Image.asset(
                    'assets/images/mrdriller.png',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.36),
                    semanticLabel: 'Mr. Driller playing a taiko drum',
                  ),
                )
              : Semantics(
                  key: const ValueKey('drum'),
                  image: true,
                  label: 'A taiko drum',
                  child: const TaikoDrumHead(),
                ),
        ),
      ),
    );
  }
}

/// The candy buttons for each activity, with a live subtitle under each.
class _MenuButtons extends StatelessWidget {
  const _MenuButtons();

  @override
  Widget build(BuildContext context) {
    void go(String route) => Navigator.of(context).pushNamed(route);
    return ListenableBuilder(
      listenable: Listenable.merge([playlists, reminders]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CandyMenuButton(
            title: 'Drills',
            subtitle: '${data.drills.length} drills to master',
            icon: Icons.sports_martial_arts_rounded,
            colors: AppColors.candyBlue,
            onPressed: () => go('/drills'),
          ),
          const SizedBox(height: 12),
          CandyMenuButton(
            title: 'Playlists',
            subtitle: _playlistsSummary(),
            icon: Icons.queue_music_rounded,
            colors: AppColors.candyOrange,
            onPressed: () => go('/playlists'),
          ),
          const SizedBox(height: 12),
          CandyMenuButton(
            title: 'Daily Practice',
            subtitle: _remindersSummary(),
            icon: Icons.event_available_rounded,
            colors: AppColors.candyPink,
            onPressed: () => go('/daily-practice'),
          ),
          for (final tool in tools) ...[
            const SizedBox(height: 12),
            CandyMenuButton(
              title: tool.title,
              subtitle: 'Listen, then repeat',
              icon: Icons.hearing_rounded,
              colors: AppColors.candyGreen,
              onPressed: () => go('/tool/${tool.id}'),
            ),
          ],
        ],
      ),
    );
  }

  // E.g. "3 playlists", or a nudge to make one.
  static String _playlistsSummary() {
    final count = playlists.playlists.length;
    if (count == 0) return 'Line up drills to play in a row';
    return count == 1 ? '1 playlist' : '$count playlists';
  }

  // E.g. "2 reminders", or a nudge to set one up.
  static String _remindersSummary() {
    final count = reminders.entries.length;
    if (count == 0) return 'Reminders and your practice log';
    return count == 1 ? '1 reminder · practice log' : '$count reminders · practice log';
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.inkMuted,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: 'v$appVersion · made with '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
              Icons.favorite_rounded,
              size: 13,
              color: AppColors.candyPink.base,
              semanticLabel: 'love',
            ),
          ),
          const TextSpan(text: ' by MDB + Claude'),
        ],
      ),
    );
  }
}
