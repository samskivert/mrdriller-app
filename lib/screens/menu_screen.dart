import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/app_info.dart';
import '../state/practice_plan.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_layout.dart';

final List<Tool> tools = [const Tool(id: 'pattern-trainer', title: 'Pattern Trainer')];

/// The main menu: the logo and character artwork, and big candy buttons for each activity. The
/// artwork sits above the buttons in portrait, and to their left in landscape (or on a wide
/// screen).
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

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
                bubbles: [(0.0, 0.18, 90), (0.12, 0.09, 32), (1.0, 0.42, 75), (0.0, 1.0, 60)],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(safe.left, safe.top, safe.right, safe.bottom),
              child: LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth > constraints.maxHeight
                    ? _WideMenu(constraints.biggest)
                    : _TallMenu(constraints.biggest),
              ),
            ),
            Positioned(
              top: safe.top + 14,
              right: safe.right + 16,
              child: const HudSettingsButton(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portrait: the logo and artwork stacked above the buttons, all centered in a column (which
/// scrolls if the screen is too short to fit it).
class _TallMenu extends StatelessWidget {
  final Size size;

  const _TallMenu(this.size);

  @override
  Widget build(BuildContext context) {
    final heroSize = (size.shortestSide * 0.52).clamp(140.0, 260.0);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: size.height),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Logo(),
                  const SizedBox(height: 22),
                  _Hero(size: heroSize),
                  const SizedBox(height: 40),
                  const _MenuButtons(),
                  const SizedBox(height: 20),
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

/// Landscape (or a wide screen): the logo and artwork on the left, and the buttons on the right.
class _WideMenu extends StatelessWidget {
  final Size size;

  const _WideMenu(this.size);

  @override
  Widget build(BuildContext context) {
    // Room for the logo above it, and the rings around it.
    final heroSize = (size.height - 190).clamp(100.0, 300.0);
    return Row(
      children: [
        Expanded(
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
                    _Hero(size: heroSize),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 70, 24, 16),
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

/// The puffy "Mr.★ Driller" logo, over a "TAIKO DRILL TRAINER" chip.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Mr. Driller',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PuffyText('Mr.', size: 30),
              SizedBox(width: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 34, color: Colors.white),
                  Icon(Icons.star_rounded, size: 26, color: AppColors.gold),
                ],
              ),
            ],
          ),
          const PuffyText('Driller', size: 52),
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

/// The character artwork cropped to a circle, inside white, blue, white, and pink rings.
class _Hero extends StatelessWidget {
  final double size;

  const _Hero({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(29),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFDE7EF),
        boxShadow: [
          BoxShadow(color: Color(0xFFC21F55), spreadRadius: 29, offset: Offset(0, 7)),
          BoxShadow(color: Color(0xFFF0457A), spreadRadius: 29),
          BoxShadow(color: Colors.white, spreadRadius: 21),
          BoxShadow(color: Color(0xFF5DB7F5), spreadRadius: 15),
          BoxShadow(color: Colors.white, spreadRadius: 7),
        ],
      ),
      child: ClipOval(
        // Zoomed in a little on Mr. Driller himself.
        child: Transform.scale(
          scale: 1.25,
          alignment: const Alignment(0, -0.4),
          child: Image.asset(
            'assets/images/mrdriller.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.36),
            semanticLabel: 'Mr. Driller playing a taiko drum',
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
      listenable: Listenable.merge([practicePlan, settings]),
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
            title: 'Daily Practice',
            subtitle: _planSummary(),
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

  // E.g. "5 drills · 18m 40s", or a nudge to set one up.
  static String _planSummary() {
    final entries = practicePlan.entries;
    if (entries.isEmpty) return 'Plan your practice routine';
    var seconds = 0.0;
    for (final entry in entries) {
      final drill = data.findDrillById(entry.drillId);
      if (drill == null) continue;
      seconds += computeDrillDuration(
        drill,
        entry.config.bpm,
        entry.config.bpmIncrease,
        entry.config.drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      );
    }
    final drills = entries.length == 1 ? '1 drill' : '${entries.length} drills';
    return '$drills · ${formatDrillDuration(seconds)}';
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
          const TextSpan(text: 'Made with '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
              Icons.favorite_rounded,
              size: 13,
              color: AppColors.candyPink.base,
              semanticLabel: 'love',
            ),
          ),
          TextSpan(text: ' by MDB + Claude · v$appVersion'),
        ],
      ),
    );
  }
}
