import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/components.dart';
import '../widgets/drill_overview_view.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import 'drill_practice_screen.dart';

/// The overview/config screen, laid out like the practice screen it leads into (see [HudLayout]):
/// a static preview of the drill on the playfield, and a HUD with the bpm/bpm-up/loops steppers,
/// the hands toggle, and START!, which hands off to [DrillPracticeScreen] for the actual practice
/// session.
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

  void _setConfig(DrillConfig config) => setState(() {
    _config = config;
    _saveConfig();
  });

  List<HudStepperSpec> _steppers() => [
    HudStepperSpec(
      label: 'BPM',
      bannerColor: AppColors.bannerOrange,
      value: _config.bpm,
      min: bpmLimits.min,
      max: bpmLimits.max,
      onChanged: (v) => _setConfig(_config.copyWith(bpm: v)),
      decreaseLabel: 'Slower',
      increaseLabel: 'Faster',
    ),
    HudStepperSpec(
      label: 'BPM up',
      bannerColor: AppColors.bannerRed,
      value: _config.bpmIncrease,
      min: bpmIncreaseLimits.min,
      max: bpmIncreaseLimits.max,
      format: (v) => '+$v',
      onChanged: (v) => _setConfig(_config.copyWith(bpmIncrease: v)),
      decreaseLabel: 'Smaller bpm increase each loop',
      increaseLabel: 'Bigger bpm increase each loop',
    ),
    HudStepperSpec(
      label: 'Loops',
      bannerColor: AppColors.bannerMagenta,
      value: _config.drillRepeat,
      min: drillRepeatLimits.min,
      max: drillRepeatLimits.max,
      format: (v) => '×$v',
      onChanged: (v) => _setConfig(_config.copyWith(drillRepeat: v)),
      decreaseLabel: 'Fewer loops',
      increaseLabel: 'More loops',
    ),
  ];

  Widget _hands({bool row = false}) => HandsToggle(
    row: row,
    swapped: _config.swapHands,
    onChanged: (v) => _setConfig(_config.copyWith(swapHands: v)),
  );

  // The drill's total time depends on a setting (whether the count-in replays when the bpm goes
  // up), so it's rebuilt if that changes, e.g. via the settings button.
  Widget _start({double height = 76}) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => StartButton(
      height: height,
      onPressed: _handleStart,
      time: formatDrillClock(
        computeDrillDuration(
          widget.drill,
          _config.bpm,
          _config.bpmIncrease,
          _config.drillRepeat,
          replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final drill = widget.drill;
    final steppers = _steppers();
    return HudLayout(
      playfield: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
        child: Center(child: DrillOverviewView(drill: _activeDrillFor(drill))),
      ),
      hud: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Row(
              children: [
                const HudBackButton(),
                const SizedBox(width: 12),
                Expanded(child: HudTitle(drill.title)),
                const SizedBox(width: 12),
                const HudSettingsButton(),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 124,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final stepper in steppers) ...[
                    Expanded(child: HudStepperCard(stepper)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _hands()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: _start()),
          ],
        ),
      ),
      sidebar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const HudBackButton(),
              const SizedBox(width: 10),
              Expanded(child: HudTitle(drill.title, sidebar: true)),
              const SizedBox(width: 10),
              const HudSettingsButton(),
            ],
          ),
          const SizedBox(height: 12),
          HudRowsCard(children: [for (final s in steppers) HudStepperRow(s), _hands(row: true)]),
          const SizedBox(height: 12),
          _start(height: 70),
        ],
      ),
    );
  }
}
