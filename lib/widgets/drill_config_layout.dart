import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/drill_config.dart';
import '../util/colors.dart';
import 'components.dart';
import 'drill_overview_view.dart';
import 'hud_controls.dart';
import 'hud_layout.dart';

/// The layout for configuring how a drill is played, shared by the drill overview and the
/// screen for adding a drill to a playlist (see [HudLayout]): a static preview of [drill]
/// (with its hands swapped, if [config] says so) on the playfield, and a HUD with [title], the
/// BPM / BPM UP / LOOPS steppers, HANDS toggle and COUNT switch, and the screen's own buttons below them, from
/// [buildActions].
///
/// Changes are reported via [onConfigUpdate] as an update to apply to the screen's latest config,
/// rather than as a whole new config built from [config] -- which, after a change in quick
/// succession, may already be out of date.
///
/// [buildActions] is given a [TimeChip] of the drill's total time at this config to place
/// alongside its buttons, and whether it's for the narrow landscape [sidebar] rather than the full
/// width of a portrait HUD.
class DrillConfigLayout extends StatefulWidget {
  final Drill drill;
  final DrillConfig config;
  final void Function(DrillConfig Function(DrillConfig config) update) onConfigUpdate;
  final String title;
  final Widget Function(BuildContext context, Widget time, bool sidebar) buildActions;

  const DrillConfigLayout({
    super.key,
    required this.drill,
    required this.config,
    required this.onConfigUpdate,
    required this.title,
    required this.buildActions,
  });

  @override
  State<DrillConfigLayout> createState() => _DrillConfigLayoutState();
}

class _DrillConfigLayoutState extends State<DrillConfigLayout> {
  // The preview re-renders on every config tweak, but swapHands() deep-clones the whole drill --
  // only worth redoing when config.swapHands itself actually changes.
  Drill? _previewDrill;
  bool? _previewSwapped;

  Drill get _preview {
    if (_previewDrill == null || _previewSwapped != widget.config.swapHands) {
      _previewDrill = widget.config.swapHands ? swapHands(widget.drill) : widget.drill;
      _previewSwapped = widget.config.swapHands;
    }
    return _previewDrill!;
  }

  @override
  void didUpdateWidget(DrillConfigLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drill != oldWidget.drill) _previewDrill = null;
  }

  List<HudStepperSpec> _steppers() {
    final config = widget.config;
    final update = widget.onConfigUpdate;
    return [
      HudStepperSpec(
        label: 'BPM',
        bannerColor: AppColors.bannerOrange,
        value: config.bpm,
        min: bpmLimits.min,
        max: bpmLimits.max,
        onChanged: (v) => update((c) => c.copyWith(bpm: v)),
        decreaseLabel: 'Slower',
        increaseLabel: 'Faster',
      ),
      HudStepperSpec(
        label: 'BPM up',
        bannerColor: AppColors.bannerRed,
        value: config.bpmIncrease,
        min: bpmIncreaseLimits.min,
        max: bpmIncreaseLimits.max,
        format: (v) => '+$v',
        onChanged: (v) => update((c) => c.copyWith(bpmIncrease: v)),
        decreaseLabel: 'Smaller bpm increase each loop',
        increaseLabel: 'Bigger bpm increase each loop',
      ),
      HudStepperSpec(
        label: 'Loops',
        bannerColor: AppColors.bannerMagenta,
        value: config.drillRepeat,
        min: drillRepeatLimits.min,
        max: drillRepeatLimits.max,
        format: (v) => '×$v',
        onChanged: (v) => update((c) => c.copyWith(drillRepeat: v)),
        decreaseLabel: 'Fewer loops',
        increaseLabel: 'More loops',
      ),
    ];
  }

  Widget _hands({bool row = false}) => HandsToggle(
    row: row,
    swapped: widget.config.swapHands,
    onChanged: (v) => widget.onConfigUpdate((c) => c.copyWith(swapHands: v)),
  );

  Widget _countIn({bool row = false}) => CountInToggle(
    row: row,
    value: widget.config.replayIntroOnBpmIncrease,
    onChanged: (v) => widget.onConfigUpdate((c) => c.copyWith(replayIntroOnBpmIncrease: v)),
  );

  Widget _actions({required bool sidebar}) {
    final time = formatDrillClock(drillDuration(widget.drill, widget.config));
    return widget.buildActions(context, TimeChip(time: time, fontSize: 16), sidebar);
  }

  Widget _header({required bool sidebar}) => Row(
    children: [
      const HudBackButton(),
      SizedBox(width: sidebar ? 10 : 12),
      Expanded(child: HudTitle(widget.title, sidebar: sidebar)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final steppers = _steppers();
    return HudLayout(
      playfield: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
        child: Center(child: DrillOverviewView(drill: _preview)),
      ),
      hud: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            _header(sidebar: false),
            const SizedBox(height: 14),
            SizedBox(
              height: 124,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < steppers.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: HudStepperCard(steppers[i])),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _hands()),
                const SizedBox(width: 8),
                Expanded(child: _countIn()),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: _actions(sidebar: false)),
          ],
        ),
      ),
      sidebar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(sidebar: true),
          const SizedBox(height: 12),
          HudRowsCard(
            children: [
              for (final s in steppers) HudStepperRow(s),
              _hands(row: true),
              _countIn(row: true),
            ],
          ),
          const SizedBox(height: 12),
          _actions(sidebar: true),
        ],
      ),
    );
  }
}
