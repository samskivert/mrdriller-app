import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/practice_plan.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/drill_config_layout.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';

/// The last step of adding a drill to the practice plan (reached from
/// [SelectDrillForPlanScreen]), or the sole screen for editing an existing entry in place, laid out
/// like the drill overview (see [DrillConfigLayout]): set the starting bpm/bpm-increase/
/// repeat-count/swap-hands, then ADD TO PLAN (or SAVE, when editing). When adding, CANCEL backs out
/// without creating an entry; when editing, that slot is instead a DELETE button (with a
/// confirmation) that removes the entry from the plan. The drill itself can't be changed here --
/// editing only ever touches the config.
///
/// [editIndex]/[initialConfig] being non-null means this is editing an existing entry rather than
/// adding a new one.
class ConfigurePlanEntryScreen extends StatefulWidget {
  final String drillId;
  final String drillTitle;
  final DrillConfig? initialConfig;
  final int? editIndex;

  const ConfigurePlanEntryScreen({
    super.key,
    required this.drillId,
    required this.drillTitle,
    this.initialConfig,
    this.editIndex,
  });

  @override
  State<ConfigurePlanEntryScreen> createState() => _ConfigurePlanEntryScreenState();
}

class _ConfigurePlanEntryScreenState extends State<ConfigurePlanEntryScreen> {
  late DrillConfig _config;

  bool get _isEditing => widget.editIndex != null;

  Drill? get _drill => data.findDrillById(widget.drillId);

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? const DrillConfig();
  }

  void _returnToPlan() {
    Navigator.of(context).popUntil((route) => route.settings.name == '/daily-practice');
  }

  void _save() {
    final entry = PracticePlanEntry(drillId: widget.drillId, config: _config);
    if (_isEditing) {
      practicePlan.updateAt(widget.editIndex!, entry);
    } else {
      practicePlan.add(entry);
    }
    _returnToPlan();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete drill?',
      message: 'Remove "${widget.drillTitle}" from your practice plan?',
    );
    if (!confirmed || !mounted) return;
    practicePlan.removeAt(widget.editIndex!);
    _returnToPlan();
  }

  // CANCEL (or DELETE), the drill's [time], and ADD TO PLAN (or SAVE): in a row across a portrait
  // HUD, or stacked in a landscape sidebar.
  Widget _actions(Widget time, bool sidebar) {
    final save = StartButton(
      // There isn't room for all of ADD TO PLAN in half a phone's width.
      label: _isEditing ? 'SAVE' : (sidebar ? 'ADD TO PLAN' : 'ADD'),
      icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
      height: 56,
      onPressed: _save,
    );
    final other = CandyButton(
      label: _isEditing ? 'DELETE' : 'CANCEL',
      icon: _isEditing ? Icons.delete_rounded : Icons.close_rounded,
      colors: _isEditing ? AppColors.candyRed : AppColors.candyGray,
      height: sidebar ? 46 : 56,
      fontSize: sidebar ? 15 : 17,
      onPressed: _isEditing ? _confirmDelete : _returnToPlan,
    );
    if (sidebar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: time),
          const SizedBox(height: 10),
          save,
          const SizedBox(height: 10),
          other,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: other),
        const SizedBox(width: 10),
        time,
        const SizedBox(width: 10),
        Expanded(child: save),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final drill = _drill;
    if (drill == null) {
      // The drill no longer exists (see DailyPracticeScreen._goToIndex); all that's left to do
      // with its entry is remove it.
      return CreamScreen(
        title: widget.drillTitle,
        showSettings: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isEditing
                ? CandyButton(
                    label: 'DELETE',
                    icon: Icons.delete_rounded,
                    colors: AppColors.candyRed,
                    onPressed: _confirmDelete,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }
    return DrillConfigLayout(
      drill: drill,
      config: _config,
      onConfigUpdate: (update) => setState(() => _config = update(_config)),
      title: widget.drillTitle,
      showSettings: false,
      buildActions: (context, time, sidebar) => _actions(time, sidebar),
    );
  }
}
