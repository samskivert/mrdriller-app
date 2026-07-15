import 'package:flutter/material.dart';

/// The back / title / settings row used atop the drill, pattern-trainer, and settings screens
/// (a hand-rolled header rather than a native AppBar, matching the web app's layout).
class AppHeader extends StatelessWidget {
  final String title;
  final bool showSettings;

  const AppHeader({super.key, required this.title, this.showSettings = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showSettings)
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}
