import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../state/drill_config.dart';
import '../state/practice_plan.dart';
import '../util/colors.dart';
import '../widgets/app_header.dart';
import '../widgets/components.dart';
import 'configure_plan_entry_screen.dart';
import 'select_drill_for_plan_screen.dart';

/// Lists the drills in the user's practice plan, each with Edit/Delete actions, plus a button to
/// add another drill. Creation and editing only for now -- actually running the plan is a
/// follow-up feature.
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
                              for (var i = 0; i < entries.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _PlanEntryTile(
                                  title: _titleFor(entries[i].drillId),
                                  config: entries[i].config,
                                  onEdit: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ConfigurePlanEntryScreen(
                                        drillId: entries[i].drillId,
                                        drillTitle: _titleFor(
                                          entries[i].drillId,
                                        ),
                                        initialConfig: entries[i].config,
                                        editIndex: i,
                                      ),
                                    ),
                                  ),
                                  onDelete: () => practicePlan.removeAt(i),
                                ),
                              ],
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanEntryTile({
    required this.title,
    required this.config,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return HighlightedCard(
      isHighlighted: false,
      child: Row(
        children: [
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
                  '${config.bpm} BPM'
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
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
