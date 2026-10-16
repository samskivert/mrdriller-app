import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/drill_config.dart';
import '../widgets/drill_config_layout.dart';
import '../widgets/hud_controls.dart';
import 'drill_practice_screen.dart';

/// The overview/config screen, laid out like the practice screen it leads into (see
/// [DrillConfigLayout]): a static preview of the drill on the playfield, and a HUD with the
/// bpm/bpm-up/loops steppers, the hands toggle, and START!, which hands off to
/// [DrillPracticeScreen] for the actual practice session. The config is saved as it's changed.
class DrillScreen extends StatefulWidget {
  final Drill drill;

  const DrillScreen({super.key, required this.drill});

  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  DrillConfig _config = const DrillConfig();

  @override
  void initState() {
    super.initState();
    loadDrillConfig(widget.drill.id).then((config) {
      if (!mounted) return;
      setState(() => _config = config);
    });
  }

  void _updateConfig(DrillConfig Function(DrillConfig config) update) {
    setState(() => _config = update(_config));
    saveDrillConfig(widget.drill.id, _config);
  }

  void _handleStart() {
    final drill = _config.swapHands ? swapHands(widget.drill) : widget.drill;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrillPracticeScreen(drill: drill, config: _config),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrillConfigLayout(
      drill: widget.drill,
      config: _config,
      onConfigUpdate: _updateConfig,
      title: widget.drill.title,
      buildActions: (context, time, sidebar) {
        if (sidebar) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: time),
              const SizedBox(height: 10),
              StartButton(onPressed: _handleStart, height: 70),
            ],
          );
        }
        return Row(
          children: [
            time,
            const SizedBox(width: 10),
            Expanded(child: StartButton(onPressed: _handleStart)),
          ],
        );
      },
    );
  }
}
