import 'dart:async';

import 'package:flutter/material.dart';

import '../services/reminder_scheduler.dart';
import '../state/app_name.dart';
import '../state/reminders.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/taiko_drum_head.dart';

/// Adds a new practice reminder, or edits an existing one in place (reached from the daily
/// practice screen's ADD REMINDER button, or by tapping a reminder): a time of day, which days of
/// the week it repeats on, and a custom message (with a preview of the notification). When adding,
/// CANCEL backs out without creating one; when editing, that slot is instead a DELETE button (with
/// a confirmation).
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
    final picked = await showCandyTimePicker(context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _setDays(Set<int> days) => setState(() => _days = days);

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
    unawaited(refreshScheduledReminders());
    _returnToPlan();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete reminder?',
      message: 'Remove this reminder?',
    );
    if (!confirmed || !mounted) return;
    reminders.removeAt(widget.editIndex!);
    unawaited(refreshScheduledReminders());
    _returnToPlan();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: _isEditing ? 'Edit Reminder' : 'Add Reminder',
      showSettings: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BannerCard(
                  label: 'Time',
                  color: AppColors.bannerMagenta,
                  child: _TimeButton(time: _time, onTap: _pickTime),
                ),
                const SizedBox(height: 14),
                BannerCard(
                  label: 'Days',
                  color: AppColors.bannerBlue,
                  child: _DaysPicker(days: _days, onToggle: _toggleDay, onSet: _setDays),
                ),
                const SizedBox(height: 14),
                BannerCard(
                  label: 'Message',
                  color: AppColors.bannerOrange,
                  child: _MessageEditor(controller: _messageController),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CandyButton(
                        label: _isEditing ? 'DELETE' : 'CANCEL',
                        icon: _isEditing ? Icons.delete_rounded : Icons.close_rounded,
                        colors: _isEditing ? AppColors.candyRed : AppColors.candyGray,
                        height: 56,
                        fontSize: 17,
                        onPressed: _isEditing ? _confirmDelete : _returnToPlan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CandyButton(
                        label: _isEditing ? 'SAVE' : 'ADD',
                        icon: _isEditing ? Icons.check_rounded : Icons.add_alarm_rounded,
                        colors: AppColors.candyGreen,
                        height: 56,
                        fontSize: 17,
                        onPressed: _days.isEmpty ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reminder's time in big digit tiles (with AM/PM beside them, unless the device uses
/// 24-hour time). Tapping it opens the time picker.
class _TimeButton extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatted = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    // E.g. "7:30" and "AM", so that just the numbers go in digit tiles.
    final match = RegExp(r'^([\d:]+)\s*(.*)$').firstMatch(formatted);
    final digits = match?.group(1) ?? formatted;
    final suffix = match?.group(2) ?? '';
    return Semantics(
      button: true,
      label: 'Time: $formatted. Tap to change.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DigitTiles(value: digits, height: 52),
                if (suffix.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    suffix,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to change',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A toggle for each day of the week, plus shortcuts for every day, weekdays, and weekends.
class _DaysPicker extends StatelessWidget {
  final Set<int> days;
  final ValueChanged<int> onToggle;
  final ValueChanged<Set<int>> onSet;

  const _DaysPicker({required this.days, required this.onToggle, required this.onSet});

  static const _presets = [
    ('Every day', {1, 2, 3, 4, 5, 6, 7}),
    ('Weekdays', {1, 2, 3, 4, 5}),
    ('Weekends', {6, 7}),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in allWeekdays)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _DayButton(
                    day: day,
                    selected: days.contains(day),
                    onTap: () => onToggle(day),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, preset) in _presets)
              _PresetButton(
                label: label,
                selected: days.length == preset.length && days.containsAll(preset),
                onTap: () => onSet({...preset}),
              ),
          ],
        ),
        if (days.isEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Pick at least one day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.bannerRed,
            ),
          ),
        ],
      ],
    );
  }
}

/// One day of the week, as its initial in a round button: a candy circle while [selected], or
/// just an outline otherwise.
class _DayButton extends StatelessWidget {
  final int day;
  final bool selected;
  final VoidCallback onTap;

  const _DayButton({required this.day, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final candy = AppColors.candyPink;
    const size = 42.0;
    return Semantics(
      button: true,
      toggled: selected,
      label: weekdayAbbreviation(day),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [candy.hi, candy.base, candy.lo],
                  )
                : null,
            border: selected ? null : Border.all(color: AppColors.creamShadow, width: 2),
            boxShadow: selected
                ? [BoxShadow(color: candy.outline, offset: const Offset(0, 3))]
                : null,
          ),
          child: selected
              ? OutlinedText(
                  weekdayAbbreviation(day)[0],
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                  color: Colors.white,
                  outline: candy.outline,
                  outlineWidth: 2,
                )
              : Text(
                  weekdayAbbreviation(day)[0],
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.inkMuted,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A shortcut for picking a set of days at once, highlighted while it's the set picked.
class _PresetButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.ink : AppColors.creamShadow, width: 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.cream : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The reminder's message, and a preview of the notification it'll show.
class _MessageEditor extends StatelessWidget {
  final TextEditingController controller;

  const _MessageEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          style: textStyle,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cream,
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.bannerOrange, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // What the notification will look like.
        ExcludeSemantics(
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, mrDrillerUnlocked]),
            builder: (context, _) {
              final message = controller.text.trim();
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The app's icon, as the notification will show it.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const AppIcon(size: 36),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName().toUpperCase(),
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message.isEmpty ? defaultReminderMessage : message,
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
