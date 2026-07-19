import 'package:flutter/material.dart';

import '../state/settings.dart';
import '../widgets/app_header.dart';

class _SettingRow extends StatelessWidget {
  final String label;
  final String description;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.label,
    required this.description,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(value: checked, onChanged: onChanged),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: AppHeader(title: 'Settings', showSettings: false),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AnimatedBuilder(
                      animation: settings,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SettingRow(
                            label: 'Bouncing dot',
                            description:
                                'Highlight the active beat while a drill plays. When off, only the active section is highlighted.',
                            checked: settings.showBouncingDot,
                            onChanged: settings.setShowBouncingDot,
                          ),
                          const SizedBox(height: 20),
                          _SettingRow(
                            label: 'Replay intro on BPM increase',
                            description:
                                'When the BPM goes up mid-drill, replay the "Ichi, Ni, So, Re" intro. When off, the repeat starts straight away.',
                            checked: settings.replayIntroOnBpmIncrease,
                            onChanged: settings.setReplayIntroOnBpmIncrease,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
