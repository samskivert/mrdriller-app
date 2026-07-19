import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/practice_plan.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/components.dart';
import '../widgets/screen_scaffold.dart';

/// A [TableRow] pairing a left-aligned label with a field, for a form where every label lines up
/// in its own column regardless of how long the other labels in the table are.
TableRow _fieldRow(String label, Widget field) {
  return TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: Text('$label:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 12), child: field),
    ],
  );
}

/// The last step of adding a drill to the practice plan (reached from
/// [SelectDrillForPlanScreen]), or the sole screen for editing an existing entry in place: set the
/// starting bpm/bpm-increase/repeat-count/swap-hands, then "Add to Plan" (or "Save", when
/// editing). When
/// adding, "Cancel" backs out without creating an entry; when editing, that slot is instead a
/// "Delete" button (with a confirmation) that removes the entry from the plan. The drill itself
/// can't be changed here -- editing only ever touches the config.
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
    Navigator.of(context).popUntil((route) => route.settings.name == '/practice-plan');
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Drill?'),
        content: Text('Remove "${widget.drillTitle}" from your practice plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.btnRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    practicePlan.removeAt(widget.editIndex!);
    _returnToPlan();
  }

  @override
  Widget build(BuildContext context) {
    final drill = _drill;
    final duration = drill == null
        ? null
        : formatDrillDuration(
            computeDrillDuration(
              drill,
              _config.bpm,
              _config.bpmIncrease,
              _config.drillRepeat,
              replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
            ),
          );

    return ScreenScaffold(
      title: widget.drillTitle,
      showSettings: false,
      contentMaxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: IntrinsicColumnWidth(), 1: IntrinsicColumnWidth()},
              children: [
                _fieldRow(
                  bpmFieldLabel,
                  bpmField(
                    value: _config.bpm,
                    onChanged: (v) => setState(() => _config = _config.copyWith(bpm: v)),
                    showLabel: false,
                  ),
                ),
                _fieldRow(
                  bpmIncreaseFieldLabel,
                  bpmIncreaseField(
                    value: _config.bpmIncrease,
                    onChanged: (v) => setState(() => _config = _config.copyWith(bpmIncrease: v)),
                    showLabel: false,
                  ),
                ),
                _fieldRow(
                  drillRepeatFieldLabel,
                  drillRepeatField(
                    value: _config.drillRepeat,
                    onChanged: (v) => setState(() => _config = _config.copyWith(drillRepeat: v)),
                    showLabel: false,
                  ),
                ),
                _fieldRow(
                  'Swap L/R',
                  Switch(
                    value: _config.swapHands,
                    onChanged: (v) => setState(() => _config = _config.copyWith(swapHands: v)),
                  ),
                ),
              ],
            ),
          ),
          if (duration != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                duration,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGray,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _isEditing
                    ? OutlinedButton(
                        onPressed: _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: AppColors.btnRed,
                          side: BorderSide(color: AppColors.btnRed),
                        ),
                        child: const Text('Delete'),
                      )
                    : OutlinedButton(
                        onPressed: _returnToPlan,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: const Text('Cancel'),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.btnGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isEditing ? 'Save' : 'Add to Plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
