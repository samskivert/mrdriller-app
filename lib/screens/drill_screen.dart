import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/components.dart';
import '../widgets/drill_overview_view.dart';
import '../widgets/screen_scaffold.dart';
import 'drill_practice_screen.dart';

/// The overview/config screen: a static preview of the drill plus the bpm/repeat/swap-hands
/// controls. Pressing Start hands off to [DrillPracticeScreen] for the actual practice session.
class DrillScreen extends StatefulWidget {
  final Drill drill;

  const DrillScreen({super.key, required this.drill});

  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  DrillConfig _config = const DrillConfig();

  // The overview re-renders on every config tweak, but swapHands() deep-clones the whole drill --
  // only worth redoing when config.swapHands itself actually changes.
  Drill? _cachedActiveDrill;
  bool? _cachedActiveDrillSwapFlag;

  Drill _activeDrillFor(Drill drill) {
    if (_cachedActiveDrill != null && _cachedActiveDrillSwapFlag == _config.swapHands) {
      return _cachedActiveDrill!;
    }
    final result = _config.swapHands ? swapHands(drill) : drill;
    _cachedActiveDrill = result;
    _cachedActiveDrillSwapFlag = _config.swapHands;
    return result;
  }

  @override
  void initState() {
    super.initState();
    loadDrillConfig(widget.drill.id).then((config) {
      if (!mounted) return;
      setState(() => _config = config);
    });
  }

  void _saveConfig() {
    saveDrillConfig(widget.drill.id, _config);
  }

  void _handleStart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrillPracticeScreen(drill: _activeDrillFor(widget.drill), config: _config),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drill = widget.drill;
    final activeDrill = _activeDrillFor(drill);

    return ScreenScaffold(
      title: drill.title,
      contentMaxWidth: 1200,
      contentPadding: EdgeInsets.zero,
      contentAlignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DrillControls(
            drill: drill,
            config: _config,
            onConfigChanged: (c) => setState(() {
              _config = c;
              _saveConfig();
            }),
            onStart: _handleStart,
          ),
          const SizedBox(height: 24),
          DrillOverviewView(drill: activeDrill),
        ],
      ),
    );
  }
}

class _DrillControls extends StatelessWidget {
  final Drill drill;
  final DrillConfig config;
  final ValueChanged<DrillConfig> onConfigChanged;
  final VoidCallback onStart;

  const _DrillControls({
    required this.drill,
    required this.config,
    required this.onConfigChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final duration = formatDrillDuration(
      computeDrillDuration(
        drill,
        config.bpm,
        config.bpmIncrease,
        config.drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        bpmField(
          value: config.bpm,
          onChanged: (v) => onConfigChanged(config.copyWith(bpm: v)),
        ),
        bpmIncreaseField(
          value: config.bpmIncrease,
          onChanged: (v) => onConfigChanged(config.copyWith(bpmIncrease: v)),
        ),
        drillRepeatField(
          value: config.drillRepeat,
          onChanged: (v) => onConfigChanged(config.copyWith(drillRepeat: v)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: config.swapHands,
              onChanged: (v) => onConfigChanged(config.copyWith(swapHands: v)),
            ),
            const Text('L↔︎R'),
          ],
        ),
        Text(
          duration,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textGray),
        ),
        ElevatedButton(
          onPressed: onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.btnGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 40),
          ),
          child: const Text('Start'),
        ),
      ],
    );
  }
}
