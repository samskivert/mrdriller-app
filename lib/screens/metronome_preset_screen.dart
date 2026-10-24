import 'package:flutter/material.dart';

import '../services/metronome_player.dart';
import '../state/metronome_settings.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/metronome_controls.dart';

/// One metronome preset (at `/metronome/<id>`): its settings and PLAY, SAVE (once they've been
/// changed from the saved ones), and DELETE, plus a button to rename it. Changes that aren't saved
/// are dropped on leaving.
class MetronomePresetScreen extends StatefulWidget {
  final String presetId;

  const MetronomePresetScreen({super.key, required this.presetId});

  @override
  State<MetronomePresetScreen> createState() => _MetronomePresetScreenState();
}

class _MetronomePresetScreenState extends State<MetronomePresetScreen> {
  // The settings as changed here, or null while they're the saved ones (which then follow any
  // change made to the preset elsewhere, e.g. on another device).
  MetronomeConfig? _edited;
  late final _player = MetronomePlayer(
    metronomePresets.byId(widget.presetId)?.config ?? const MetronomeConfig(),
  );

  @override
  void initState() {
    super.initState();
    metronomePresets.addListener(_handlePresetsChanged);
  }

  @override
  void dispose() {
    metronomePresets.removeListener(_handlePresetsChanged);
    _player.dispose();
    super.dispose();
  }

  // Keeps playing what's shown, including the saved settings changing elsewhere.
  void _handlePresetsChanged() {
    final preset = metronomePresets.byId(widget.presetId);
    if (preset != null && _edited == null) _player.config = preset.config;
  }

  void _setConfig(MetronomePreset preset, MetronomeConfig config) {
    setState(() => _edited = config == preset.config ? null : config);
    _player.config = config;
  }

  void _save(MetronomePreset preset) {
    final edited = _edited;
    if (edited == null) return;
    metronomePresets.save(preset.id, edited);
    setState(() => _edited = null);
  }

  Future<void> _rename(MetronomePreset preset) async {
    final name = await promptForName(
      context,
      title: 'Rename preset',
      initial: preset.name,
      confirmLabel: 'SAVE',
    );
    if (name != null) metronomePresets.rename(preset.id, name);
  }

  Future<void> _delete(MetronomePreset preset) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete preset?',
      message: 'Delete "${preset.name}"?',
    );
    if (!confirmed || !mounted) return;
    _player.pause();
    Navigator.of(context).pop();
    metronomePresets.delete(preset.id);
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: metronomePresets,
      builder: (context, _) {
        final preset = metronomePresets.byId(widget.presetId);
        // (Just deleted, and on its way out.)
        if (preset == null) return const CreamScreen(title: '', child: SizedBox());
        final config = _edited ?? preset.config;
        // Logged as the preset's name (as it is when it's logged, if it's renamed).
        _player.practiceName = preset.name;
        return CreamScreen(
          title: preset.name,
          showSettings: false,
          actions: [
            RoundIconButton(
              icon: Icons.edit_rounded,
              tooltip: 'Rename preset',
              onPressed: () => _rename(preset),
            ),
          ],
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MetronomeControls(
                      config: config,
                      onChanged: (c) => _setConfig(preset, c),
                      player: _player,
                    ),
                    const SizedBox(height: 20),
                    MetronomePlayButton(player: _player),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CandyButton(
                            label: 'SAVE',
                            icon: Icons.save_rounded,
                            colors: AppColors.candyBlue,
                            height: 50,
                            fontSize: 17,
                            onPressed: _edited == null ? null : () => _save(preset),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CandyButton(
                            label: 'DELETE',
                            icon: Icons.delete_rounded,
                            colors: AppColors.candyRed,
                            height: 50,
                            fontSize: 17,
                            onPressed: () => _delete(preset),
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
      },
    );
  }
}
