import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../services/screen_cutout.dart';
import '../state/drill_config.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import 'arcade.dart';
import 'drill_practice_view.dart';
import 'drill_status_view.dart';

/// The screen-level shell for running one drill, laid out like the arcade game: a navy playfield
/// with a rainbow depth ruler, hosting a [DrillPracticeView] for [drill]/[config], and a cream HUD
/// (back button, [title], the [DrillStatusView] readouts and a [PauseButton]). The HUD runs across
/// the top of the screen in portrait, and down a sidebar to the right of the playfield in
/// landscape. Owns the [Metronome] and live-status notifier that the playfield and HUD share.
///
/// Give this a fresh [Key] (e.g. keyed by the drill's id or an index) when reusing it across a
/// sequence of drills, so each gets its own freshly-initialized metronome/status/drill state
/// instead of one being update-reused for another.
class DrillPracticeHost extends StatefulWidget {
  final String title;
  final Drill drill;
  final DrillConfig config;
  final VoidCallback onDone;

  const DrillPracticeHost({
    super.key,
    required this.title,
    required this.drill,
    required this.config,
    required this.onDone,
  });

  @override
  State<DrillPracticeHost> createState() => _DrillPracticeHostState();
}

class _DrillPracticeHostState extends State<DrillPracticeHost> {
  late final Metronome _metronome = Metronome();
  late final ValueNotifier<DrillRunStatus> _status = ValueNotifier(
    DrillRunStatus(
      bpm: widget.config.bpm,
      bpmIncrease: widget.config.bpmIncrease,
      drillRepeat: widget.config.drillRepeat,
      drillRepeatCount: 0,
      elapsedSeconds: 0,
      totalSeconds: computeDrillDuration(
        widget.drill,
        widget.config.bpm,
        widget.config.bpmIncrease,
        widget.config.drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      ),
    ),
  );

  // The screen size we last asked the platform about its cutout for: asked again whenever it
  // changes (i.e. on rotation), with any change in the answer notified via cutoutSideChanges.
  Size? _cutoutQueriedFor;

  // In landscape, the safe-area insets to actually keep clear of: the full inset on the side with
  // the camera cutout, but on the other side (where the inset is only there for the screen's
  // rounded corners) just a small margin, to reclaim the rest for the drill. The bottom inset is
  // dropped too; it's only the home indicator, which the scrolling playfield can run beneath.
  EdgeInsets _landscapeInsets(EdgeInsets safe) {
    const cornerMargin = 16.0;
    final cutout = landscapeCutoutSide(View.of(context));
    if (cutout == null) return safe;
    return EdgeInsets.only(
      left: cutout == CutoutSide.left ? safe.left : math.min(safe.left, cornerMargin),
      top: safe.top,
      right: cutout == CutoutSide.right ? safe.right : math.min(safe.right, cornerMargin),
      bottom: safe.bottom,
    );
  }

  @override
  void dispose() {
    _metronome.dispose();
    _status.dispose();
    super.dispose();
  }

  Widget _statusView({required bool vertical}) => ValueListenableBuilder(
    valueListenable: _status,
    builder: (context, status, _) => DrillStatusView(status: status, vertical: vertical),
  );

  Widget _backButton() => RoundIconButton(
    icon: Icons.arrow_back_rounded,
    tooltip: 'Back',
    onPressed: () => Navigator.of(context).pop(),
  );

  Widget _title({int maxLines = 1, double fontSize = 21}) => Text(
    widget.title,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: AppFonts.display,
      fontSize: fontSize,
      height: 1.15,
      color: AppColors.ink,
    ),
  );

  // Portrait and landscape place the playfield at different spots in the widget tree; this key
  // lets Flutter move the same running playfield (and the drill's whole state within it) between
  // them when the phone rotates, instead of tearing it down and starting the drill over.
  final _playfieldKey = GlobalKey();

  Widget _playfield() => KeyedSubtree(key: _playfieldKey, child: _playfieldContent());

  Widget _playfieldContent() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.navyTop, AppColors.navyBottom],
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 0, 16),
          child: ValueListenableBuilder(
            valueListenable: _status,
            builder: (context, status, _) => DepthRuler(progress: status.progress),
          ),
        ),
        Expanded(
          // The host has already kept the playfield clear of any safe-area insets.
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeTop: true,
            removeRight: true,
            removeBottom: true,
            child: DrillPracticeView(
              drill: widget.drill,
              config: widget.config,
              metronome: _metronome,
              status: _status,
              onDone: widget.onDone,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _portrait(EdgeInsets safe) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        color: AppColors.cream,
        padding: EdgeInsets.fromLTRB(safe.left + 16, safe.top + 14, safe.right + 16, 14),
        child: Stack(
          children: [
            const Positioned.fill(child: Bubbles()),
            Column(
              children: [
                Row(
                  children: [
                    _backButton(),
                    const SizedBox(width: 12),
                    Expanded(child: _title()),
                    const SizedBox(width: 12),
                    PauseButton(metronome: _metronome),
                  ],
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _statusView(vertical: false),
                ),
              ],
            ),
          ],
        ),
      ),
      const DripEdge(),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: safe.left, right: safe.right),
          child: _playfield(),
        ),
      ),
    ],
  );

  Widget _landscape(EdgeInsets safe, double height) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Container(
          color: AppColors.navyTop,
          padding: EdgeInsets.only(left: safe.left, top: safe.top),
          child: _playfield(),
        ),
      ),
      const DripEdge(axis: Axis.vertical),
      Container(
        // Narrower on a short phone held sideways, where every pixel of playfield counts.
        width: (height < 500 ? 230 : 280) + safe.right,
        color: AppColors.cream,
        child: Stack(
          children: [
            const Positioned.fill(child: Bubbles()),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14, safe.top + 14, safe.right + 14, safe.bottom + 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _backButton(),
                      const SizedBox(width: 10),
                      Expanded(child: _title(maxLines: 2, fontSize: 17)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _statusView(vertical: true),
                  const SizedBox(height: 14),
                  PauseButton(metronome: _metronome, showLabel: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.size.width > media.size.height;
    if (media.size != _cutoutQueriedFor) {
      _cutoutQueriedFor = media.size;
      refreshCutoutSide();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status bar icons sit over the cream HUD in portrait, but over the navy playfield in
      // landscape.
      value: isLandscape ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: isLandscape
            ? ListenableBuilder(
                listenable: cutoutSideChanges,
                builder: (context, _) =>
                    _landscape(_landscapeInsets(media.padding), media.size.height),
              )
            : _portrait(media.padding),
      ),
    );
  }
}
