import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../widgets/app_header.dart';
import '../widgets/components.dart';
import 'configure_plan_entry_screen.dart';

/// First step of adding a drill to the practice plan: pick which drill, then move on to
/// [ConfigurePlanEntryScreen] to set its bpm/increase/repeat before it's actually added.
class SelectDrillForPlanScreen extends StatelessWidget {
  const SelectDrillForPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: AppHeader(title: 'Add a Drill', showSettings: false),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 512),
                    child: ActivityGrid(
                      items: [
                        for (final drill in data.drills)
                          ActivityButton(
                            title: drill.title,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConfigurePlanEntryScreen(
                                  drillId: drill.id,
                                  drillTitle: drill.title,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
