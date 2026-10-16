import 'dart:async';

import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/app_info.dart';
import '../state/app_name.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/stroke_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: 'Settings',
      showSettings: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([settings, mrDrillerUnlocked]),
        builder: (context, _) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingCard(
                    label: 'Note highlight',
                    bannerColor: AppColors.bannerBlue,
                    description:
                        'Light up each note as it plays. When off, only the current section '
                        'is highlighted.',
                    value: settings.showBouncingDot,
                    onChanged: settings.setShowBouncingDot,
                    preview: _HighlightPreview(on: settings.showBouncingDot),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '${appName()} v$appVersion',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One on/off setting: a white card with its [label] on a banner, a [CandySwitch], its
/// [description], and optionally a [preview] of what it does. Tapping anywhere on it toggles it.
class _SettingCard extends StatelessWidget {
  final String label;
  final Color bannerColor;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? preview;

  const _SettingCard({
    required this.label,
    required this.bannerColor,
    required this.description,
    required this.value,
    required this.onChanged,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.creamShadow, width: 3)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: HudBanner(
                          label: label,
                          color: bannerColor,
                          fontSize: 14,
                          padding: const EdgeInsets.fromLTRB(14, 9, 16, 9),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 0),
                        child: CandySwitch(value: value, onChanged: onChanged),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  if (preview != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: ExcludeSemantics(child: preview!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A little navy strip of notes with the highlight stepping across them (while [on]), showing
/// what the note highlight setting does.
class _HighlightPreview extends StatefulWidget {
  final bool on;

  const _HighlightPreview({required this.on});

  @override
  State<_HighlightPreview> createState() => _HighlightPreviewState();
}

class _HighlightPreviewState extends State<_HighlightPreview> {
  static final _strokes = [R, l, r, l, L, r, l, r];
  int _beat = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      setState(() => _beat = (_beat + 1) % _strokes.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
        border: Border.all(color: widget.on ? AppColors.gold : AppColors.panelBorder, width: 2),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _strokes.length; i++)
                StrokeView(stroke: _strokes[i], size: 30, highlight: widget.on && i == _beat),
            ],
          ),
        ),
      ),
    );
  }
}
