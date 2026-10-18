import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/drill_config.dart';
import '../widgets/drill_card.dart';
import '../widgets/hud_layout.dart';

/// A "stage select" of every drill, for screens whose only job is picking one -- what happens on
/// tap is up to the caller (deep-linking to it, configuring it for a playlist, etc). Each
/// drill's card shows a preview of its notes and its saved settings, which are reloaded once
/// [onDrillTap]'s future completes (e.g. on returning from the drill's screen, where they may
/// have been changed).
class DrillPickerScreen extends StatefulWidget {
  final String title;
  final bool showSettings;
  final Future<void> Function(BuildContext context, Drill drill) onDrillTap;

  const DrillPickerScreen({
    super.key,
    required this.title,
    this.showSettings = true,
    required this.onDrillTap,
  });

  @override
  State<DrillPickerScreen> createState() => _DrillPickerScreenState();
}

class _DrillPickerScreenState extends State<DrillPickerScreen> {
  final Map<String, DrillConfig> _configs = {};

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    for (final drill in data.drills) {
      final config = await loadDrillConfig(drill.id);
      if (!mounted) return;
      setState(() => _configs[drill.id] = config);
    }
  }

  Future<void> _handleTap(Drill drill) async {
    await widget.onDrillTap(context, drill);
    final config = await loadDrillConfig(drill.id);
    if (mounted) setState(() => _configs[drill.id] = config);
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: widget.title,
      showSettings: widget.showSettings,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 520,
          mainAxisExtent: 146,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemCount: data.drills.length,
        itemBuilder: (context, i) {
          final drill = data.drills[i];
          return DrillCard(
            number: i + 1,
            drill: drill,
            config: _configs[drill.id],
            onTap: () => _handleTap(drill),
          );
        },
      ),
    );
  }
}
