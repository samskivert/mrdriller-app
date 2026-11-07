import 'dart:async';

import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/app_info.dart';
import '../services/midi_connection.dart';
import '../state/app_name.dart';
import '../state/midi_devices.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import 'midi_device_screen.dart';
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
                  const SizedBox(height: 16),
                  const _MidiDevicesCard(),
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

/// The MIDI devices (drum pads) that are connected or have been set up, each opening its
/// [MidiDeviceScreen], and a way to the MIDI diagnostics.
class _MidiDevicesCard extends StatefulWidget {
  const _MidiDevicesCard();

  @override
  State<_MidiDevicesCard> createState() => _MidiDevicesCardState();
}

class _MidiDevicesCardState extends State<_MidiDevicesCard> {
  @override
  void initState() {
    super.initState();
    midi.connect();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([midi, midiDevices]),
      builder: (context, _) {
        final connected = {
          for (final port in midi.ports)
            if (port.connected) midiDeviceKey(port),
        };
        final keys = {...connected, ...midiDevices.all.map((d) => d.key)};
        return BannerCard(
          label: 'MIDI devices',
          color: AppColors.bannerGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (midi.status == MidiStatus.unsupported)
                Text("MIDI input isn't supported here yet.", style: midiTextStyle())
              else if (midi.status == MidiStatus.failed) ...[
                Text(midi.error ?? "Couldn't connect to MIDI.", style: midiTextStyle()),
                const SizedBox(height: 10),
                CandyButton(
                  label: 'TRY AGAIN',
                  icon: Icons.cable_rounded,
                  colors: AppColors.candyGreen,
                  onPressed: midi.connect,
                ),
              ] else if (keys.isEmpty)
                Text(
                  midi.status == MidiStatus.connected
                      ? 'No MIDI devices. Plug in a drum pad to set it up.'
                      : 'Connecting to MIDI...',
                  style: midiTextStyle(),
                ),
              for (final key in keys) _deviceRow(key, connected: connected.contains(key)),
              const SizedBox(height: 4),
              _row(
                icon: Icons.monitor_heart_rounded,
                title: 'MIDI diagnostics',
                onTap: () => Navigator.of(context).pushNamed('/tool/midi-diagnostics'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _deviceRow(String key, {required bool connected}) {
    final mapped = midiDevices.byKey(key)?.pads.values.where((r) => r != PadRole.ignore).length;
    final name = midiDevices.nameOf(key);
    return _row(
      leading: ConnectionDot(connected: connected),
      title: name,
      subtitle: [
        if (name != key) key,
        mapped == null || mapped == 0 ? 'No pads set up' : '$mapped pad${mapped == 1 ? '' : 's'}',
      ].join(' - '),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => MidiDeviceScreen(deviceKey: key))),
    );
  }

  Widget _row({
    Widget? leading,
    IconData? icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(child: leading ?? Icon(icon, size: 20, color: AppColors.inkMuted)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: midiTextStyle(strong: true)),
                  if (subtitle != null) Text(subtitle, style: midiTextStyle()),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
          ],
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
