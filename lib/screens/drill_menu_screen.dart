import 'package:flutter/material.dart';

import 'drill_picker_screen.dart';

/// Lists every drill, linking to each one's overview/config screen.
class DrillMenuScreen extends StatelessWidget {
  const DrillMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DrillPickerScreen(
      title: 'Drills',
      onDrillTap: (context, drill) => Navigator.of(context).pushNamed('/drill/${drill.id}'),
    );
  }
}
