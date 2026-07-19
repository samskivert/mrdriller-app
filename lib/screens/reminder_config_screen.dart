import 'package:flutter/material.dart';

import '../state/reminders.dart';
import '../util/colors.dart';
import '../widgets/screen_scaffold.dart';

/// Adds a new practice reminder, or edits an existing one in place (reached from the daily
/// practice screen's "Add Reminder" button, or a reminder's Edit action): a time of day, which
/// days of the week it repeats on, and a custom message. When adding, "Cancel" backs out without
/// creating one; when editing, that slot is instead a "Delete" button (with a confirmation).
///
/// [editIndex]/[initialReminder] being non-null means this is editing an existing reminder rather
/// than adding a new one.
class ReminderConfigScreen extends StatefulWidget {
  final ReminderConfig? initialReminder;
  final int? editIndex;

  const ReminderConfigScreen({super.key, this.initialReminder, this.editIndex});

  @override
  State<ReminderConfigScreen> createState() => _ReminderConfigScreenState();
}

class _ReminderConfigScreenState extends State<ReminderConfigScreen> {
  late TimeOfDay _time;
  late Set<int> _days;
  late final TextEditingController _messageController;

  bool get _isEditing => widget.editIndex != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReminder;
    _time = initial?.timeOfDay ?? const TimeOfDay(hour: 9, minute: 0);
    _days = initial != null ? {...initial.days} : {...allWeekdays};
    _messageController = TextEditingController(text: initial?.message ?? defaultReminderMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _returnToPlan() {
    Navigator.of(context).popUntil((route) => route.settings.name == '/daily-practice');
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _toggleDay(int day) {
    setState(() {
      if (_days.contains(day)) {
        _days.remove(day);
      } else {
        _days.add(day);
      }
    });
  }

  void _save() {
    final message = _messageController.text.trim();
    final reminder = ReminderConfig(
      id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch,
      hour: _time.hour,
      minute: _time.minute,
      days: _days,
      message: message.isEmpty ? defaultReminderMessage : message,
    );
    if (_isEditing) {
      reminders.updateAt(widget.editIndex!, reminder);
    } else {
      reminders.add(reminder);
    }
    _returnToPlan();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: const Text('Remove this reminder?'),
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
    reminders.removeAt(widget.editIndex!);
    _returnToPlan();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: _isEditing ? 'Edit Reminder' : 'Add Reminder',
      showSettings: false,
      contentMaxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _pickTime,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_time.format(context), style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 24),
          const Text('Repeat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in allWeekdays)
                FilterChip(
                  label: Text(weekdayAbbreviation(day)),
                  selected: _days.contains(day),
                  onSelected: (_) => _toggleDay(day),
                ),
            ],
          ),
          if (_days.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Select at least one day.',
              style: TextStyle(color: AppColors.btnRed, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
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
                  onPressed: _days.isEmpty ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.btnGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isEditing ? 'Save' : 'Add Reminder'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
