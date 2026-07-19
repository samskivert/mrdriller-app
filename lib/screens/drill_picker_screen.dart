import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../widgets/components.dart';
import '../widgets/screen_scaffold.dart';

/// A grid of every drill, for screens whose only job is picking one -- what happens on tap is up
/// to the caller (deep-linking to it, configuring it for a practice plan, etc).
class DrillPickerScreen extends StatelessWidget {
  final String title;
  final bool showSettings;
  final void Function(BuildContext context, Drill drill) onDrillTap;

  const DrillPickerScreen({
    super.key,
    required this.title,
    this.showSettings = true,
    required this.onDrillTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: title,
      showSettings: showSettings,
      contentMaxWidth: 512,
      child: ActivityGrid(
        items: [
          for (final drill in data.drills)
            ActivityButton(title: drill.title, onTap: () => onDrillTap(context, drill)),
        ],
      ),
    );
  }
}
