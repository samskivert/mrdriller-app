import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/drill_config.dart';
import '../widgets/drill_practice_host.dart';

/// Thin screen wrapper around [DrillPracticeHost] for practicing a single drill on its own
/// (reached from [DrillScreen]'s Start button): pops back to the drill's overview the moment the
/// drill finishes on its own, or whenever the header's back button is tapped.
class DrillPracticeScreen extends StatelessWidget {
  final Drill drill;
  final DrillConfig config;

  const DrillPracticeScreen({super.key, required this.drill, required this.config});

  @override
  Widget build(BuildContext context) {
    return DrillPracticeHost(
      title: drill.title,
      drill: drill,
      config: config,
      onDone: () => Navigator.of(context).pop(),
    );
  }
}
