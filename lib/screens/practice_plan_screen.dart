import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../state/drill_config.dart';
import '../state/practice_plan.dart';
import '../util/colors.dart';
import '../widgets/app_header.dart';
import '../widgets/components.dart';
import 'configure_plan_entry_screen.dart';
import 'select_drill_for_plan_screen.dart';

/// Lists the drills in the user's practice plan (drag the handle to reorder), each with an Edit
/// action -- deleting an entry happens from the edit screen, not here -- plus a button to add
/// another drill. Creation and editing only for now -- actually running the plan is a follow-up
/// feature.
class PracticePlanScreen extends StatelessWidget {
  const PracticePlanScreen({super.key});

  String _titleFor(String drillId) {
    for (final drill in data.drills) {
      if (drill.id == drillId) return drill.title;
    }
    return drillId;
  }

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
              child: AppHeader(title: 'Practice Plan'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 512),
                    child: AnimatedBuilder(
                      animation: practicePlan,
                      builder: (context, _) {
                        final entries = practicePlan.entries;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (entries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                child: Text(
                                  'No drills in your plan yet. Add one to get started.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                ),
                              )
                            else
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                // The default drag handle only shows up on desktop platforms --
                                // on iOS/Android there'd be no visible affordance at all (just an
                                // undiscoverable long-press-anywhere gesture). An explicit handle
                                // works the same, visibly, everywhere.
                                buildDefaultDragHandles: false,
                                itemCount: entries.length,
                                onReorderItem: practicePlan.reorder,
                                itemBuilder: (context, i) {
                                  final entry = entries[i];
                                  return Padding(
                                    key: ObjectKey(entry),
                                    padding: EdgeInsets.only(
                                      bottom: i == entries.length - 1 ? 0 : 12,
                                    ),
                                    child: _PlanEntryTile(
                                      title: _titleFor(entry.drillId),
                                      config: entry.config,
                                      dragHandle: ReorderableDragStartListener(
                                        index: i,
                                        child: Icon(
                                          Icons.drag_handle,
                                          color: AppColors.textGray,
                                        ),
                                      ),
                                      onEdit: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ConfigurePlanEntryScreen(
                                                drillId: entry.drillId,
                                                drillTitle: _titleFor(
                                                  entry.drillId,
                                                ),
                                                initialConfig: entry.config,
                                                editIndex: i,
                                              ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SelectDrillForPlanScreen(),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: AppColors.btnBlue,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Drill'),
                            ),
                          ],
                        );
                      },
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

class _PlanEntryTile extends StatelessWidget {
  final String title;
  final DrillConfig config;
  final Widget dragHandle;
  final VoidCallback onEdit;

  const _PlanEntryTile({
    required this.title,
    required this.config,
    required this.dragHandle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return HighlightedCard(
      isHighlighted: false,
      child: Row(
        children: [
          dragHandle,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${config.bpm} bpm'
                  '${config.bpmIncrease > 0 ? ' +${config.bpmIncrease}' : ''}'
                  ' · x${config.drillRepeat}',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
        ],
      ),
    );
  }
}
