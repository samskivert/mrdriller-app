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
  int _bpm = 60;
  int _bpmIncrease = 0;
  int _drillRepeat = 1;
  bool _swapHandsEnabled = false;

  // The overview re-renders on every config tweak (bpm/bpmIncrease/drillRepeat/swap), but
  // swapHands() deep-clones the whole drill -- only worth redoing when the swap flag itself
  // actually changes.
  Drill? _cachedActiveDrill;
  bool? _cachedActiveDrillSwapFlag;

  Drill _activeDrillFor(Drill drill) {
    if (_cachedActiveDrill != null && _cachedActiveDrillSwapFlag == _swapHandsEnabled) {
      return _cachedActiveDrill!;
    }
    final result = _swapHandsEnabled ? swapHands(drill) : drill;
    _cachedActiveDrill = result;
    _cachedActiveDrillSwapFlag = _swapHandsEnabled;
    return result;
  }

  @override
  void initState() {
    super.initState();
    loadDrillConfig(widget.drill.id).then((config) {
      if (!mounted) return;
      setState(() {
        _bpm = config.bpm;
        _bpmIncrease = config.bpmIncrease;
        _drillRepeat = config.drillRepeat;
      });
    });
  }

  void _saveConfig() {
    saveDrillConfig(
      widget.drill.id,
      DrillConfig(bpm: _bpm, bpmIncrease: _bpmIncrease, drillRepeat: _drillRepeat),
    );
  }

  void _handleStart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrillPracticeScreen(
          drill: _activeDrillFor(widget.drill),
          bpm: _bpm,
          bpmIncrease: _bpmIncrease,
          drillRepeat: _drillRepeat,
        ),
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
            bpm: _bpm,
            onBpmChanged: (v) => setState(() {
              _bpm = v;
              _saveConfig();
            }),
            bpmIncrease: _bpmIncrease,
            onBpmIncreaseChanged: (v) => setState(() {
              _bpmIncrease = v;
              _saveConfig();
            }),
            drillRepeat: _drillRepeat,
            onDrillRepeatChanged: (v) => setState(() {
              _drillRepeat = v;
              _saveConfig();
            }),
            swapHands: _swapHandsEnabled,
            onSwapHandsChanged: (v) => setState(() => _swapHandsEnabled = v),
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
  final int bpm;
  final ValueChanged<int> onBpmChanged;
  final int bpmIncrease;
  final ValueChanged<int> onBpmIncreaseChanged;
  final int drillRepeat;
  final ValueChanged<int> onDrillRepeatChanged;
  final bool swapHands;
  final ValueChanged<bool> onSwapHandsChanged;
  final VoidCallback onStart;

  const _DrillControls({
    required this.drill,
    required this.bpm,
    required this.onBpmChanged,
    required this.bpmIncrease,
    required this.onBpmIncreaseChanged,
    required this.drillRepeat,
    required this.onDrillRepeatChanged,
    required this.swapHands,
    required this.onSwapHandsChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final duration = formatDrillDuration(
      computeDrillDuration(
        drill,
        bpm,
        bpmIncrease,
        drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        bpmField(value: bpm, onChanged: onBpmChanged),
        bpmIncreaseField(value: bpmIncrease, onChanged: onBpmIncreaseChanged),
        drillRepeatField(value: drillRepeat, onChanged: onDrillRepeatChanged),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: swapHands, onChanged: onSwapHandsChanged),
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
