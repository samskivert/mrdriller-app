import 'package:flutter/material.dart';

import '../services/metronome_player.dart';
import '../state/metronome_settings.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/metronome_controls.dart';

/// The metronome (at `/metronome`): its settings (persisted as the user changes them) and PLAY,
/// then the user's presets of settings, as cards (tap one to open it -- see
/// [MetronomePresetScreen]), and a button to save the settings as a new one, which asks for its
/// name and then opens it.
class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  MetronomeConfig _config = const MetronomeConfig();
  late final _player = MetronomePlayer(_config);

  @override
  void initState() {
    super.initState();
    loadMetronomeConfig().then((config) {
      if (!mounted) return;
      setState(() => _config = config);
      _player.config = config;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setConfig(MetronomeConfig config) {
    setState(() => _config = config);
    _player.config = config;
    saveMetronomeConfig(config);
  }

  void _open(MetronomePreset preset) {
    _player.pause();
    Navigator.of(context).pushNamed('/metronome/${preset.id}');
  }

  Future<void> _create() async {
    final name = await promptForName(context, title: 'New preset', confirmLabel: 'CREATE');
    if (name == null || !mounted) return;
    _open(metronomePresets.create(name, _config));
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: 'Metronome',
      showSettings: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetronomeControls(config: _config, onChanged: _setConfig, player: _player),
                const SizedBox(height: 20),
                MetronomePlayButton(player: _player),
                const SizedBox(height: 26),
                const SectionHeading('Presets', AppColors.bannerGreen),
                ListenableBuilder(
                  listenable: metronomePresets,
                  builder: (context, _) {
                    final all = metronomePresets.presets;
                    if (all.isEmpty) {
                      return const EmptyCard(
                        'No presets yet. Save these settings as one to come back to them.',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < all.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _PresetCard(number: i + 1, preset: all[i], onTap: () => _open(all[i])),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                CandyButton(
                  label: 'NEW PRESET',
                  icon: Icons.add_rounded,
                  colors: AppColors.candyOrange,
                  height: 50,
                  fontSize: 17,
                  onPressed: _create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A preset as a card: its [number] on a banner, its name, and a summary of its settings.
class _PresetCard extends StatelessWidget {
  final int number;
  final MetronomePreset preset;
  final VoidCallback onTap;

  const _PresetCard({required this.number, required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = preset.config;
    final summary = [
      '${c.bpm} BPM',
      '${c.beats.length} beats',
      if (c.increaseEvery > 0)
        '+${c.bpmIncrease} every ${c.increaseEvery == 1 ? 'measure' : '${c.increaseEvery}'}',
    ].join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.creamShadow, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HudBanner(
                label: number.toString().padLeft(2, '0'),
                color: AppColors.banner(number - 1),
                fontSize: 14,
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 17,
                          height: 1.1,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 10, 0),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
