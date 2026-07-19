import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/app_info.dart';
import '../util/colors.dart';
import '../widgets/components.dart';

final List<Tool> tools = [const Tool(id: 'pattern-trainer', title: 'Pattern Trainer')];

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return constraints.maxWidth >= 1024 || isLandscape
                ? _DesktopMenu(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight)
                : const _CompactMenu();
          },
        ),
      ),
    );
  }
}

ActivityButton buildNavButton(BuildContext context, String title, String route) {
  return ActivityButton(title: title, onTap: () => Navigator.of(context).pushNamed(route));
}

/// The desktop/wide (or phone-landscape) layout: the character artwork is on the left side of the
/// screen and the app title and menu items are on the right.
class _DesktopMenu extends StatelessWidget {
  final double maxWidth;
  final double maxHeight;

  const _DesktopMenu({required this.maxWidth, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    // The artwork is naturally 512x768 -- shown at its native size on a spacious desktop window,
    // but scaled down to fit the available height on a short landscape phone, where 768 of height
    // is far more than there is room for.
    final imageHeight = maxHeight < 768 ? maxHeight : 768.0;
    final imageWidth = imageHeight * (512 / 768);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 32),
                  const Expanded(child: _TitleText()),
                  IconButton(
                    onPressed: () => Navigator.of(context).pushNamed('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ActivityGrid(
                items: [
                  buildNavButton(context, 'Drills', '/drills'),
                  buildNavButton(context, 'Daily Practice', '/daily-practice'),
                  for (final tool in tools) buildNavButton(context, tool.title, '/tool/${tool.id}'),
                ],
              ),
              const SizedBox(height: 24),
              const Center(child: _FooterText()),
            ],
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned(
          left: maxWidth * 0.25 - imageWidth / 2,
          top: 0,
          child: Image.asset(
            'assets/images/mrdriller.png',
            width: imageWidth,
            height: imageHeight,
            fit: BoxFit.fitWidth,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(widthFactor: 0.5, child: content),
        ),
      ],
    );
  }
}

/// The narrow/mobile layout: the character artwork fills the top two-thirds of the screen, the
/// title sits at the screen's vertical center (overlapping the artwork's lower half), the settings
/// gear stays pinned to the top-right corner, and the menu buttons stack full-width in the bottom
/// third, below the artwork.
class _CompactMenu extends StatelessWidget {
  const _CompactMenu();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 2,
              child: Center(child: Image.asset('assets/images/mrdriller.png', fit: BoxFit.contain)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildNavButton(context, 'Drills', '/drills'),
                    const SizedBox(height: 16),
                    buildNavButton(context, 'Daily Practice', '/daily-practice'),
                    const SizedBox(height: 16),
                    for (final tool in tools)
                      buildNavButton(context, tool.title, '/tool/${tool.id}'),
                    const SizedBox(height: 16),
                    const Center(child: _FooterText()),
                  ],
                ),
              ),
            ),
          ],
        ),
        const Positioned.fill(child: Align(child: _TitleText())),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ),
      ],
    );
  }
}

class _FooterText extends StatelessWidget {
  const _FooterText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Made with ❤️ by MDB • v$appVersion',
      style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.65)),
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    const text = 'Mr. Driller';
    const style = TextStyle(fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: 4, height: 1);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = AppColors.brandRed,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(color: Color(0xFFFFFFFF)),
        ),
      ],
    );
  }
}
