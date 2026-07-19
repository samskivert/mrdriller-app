import 'package:flutter/material.dart';

import 'configure_plan_entry_screen.dart';
import 'drill_picker_screen.dart';

/// First step of adding a drill to the practice plan: pick which drill, then move on to
/// [ConfigurePlanEntryScreen] to set its bpm/increase/repeat before it's actually added.
class SelectDrillForPlanScreen extends StatelessWidget {
  const SelectDrillForPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DrillPickerScreen(
      title: 'Add a Drill',
      showSettings: false,
      onDrillTap: (context, drill) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConfigurePlanEntryScreen(drillId: drill.id, drillTitle: drill.title),
        ),
      ),
    );
  }
}
