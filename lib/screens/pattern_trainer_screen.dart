import 'package:flutter/material.dart';

import '../state/drill_config.dart';
import '../util/colors.dart';
import '../widgets/components.dart';
import '../widgets/screen_scaffold.dart';
import 'pattern_trainer_run_screen.dart';

/// The pattern trainer's config screen: bpm/difficulty/pattern-count/swap-hands/visibility
/// controls, persisted as the user changes them. Pressing Start hands off to
/// [PatternTrainerRunScreen] for the actual practice session.
class PatternTrainerScreen extends StatefulWidget {
  const PatternTrainerScreen({super.key});

  @override
  State<PatternTrainerScreen> createState() => _PatternTrainerScreenState();
}

class _PatternTrainerScreenState extends State<PatternTrainerScreen> {
  int _bpm = 60;
  Difficulty _difficulty = Difficulty.easy;
  int _numPatterns = 5;
  bool _swapHands = false;
  SectionVisibility _sectionVisibility = SectionVisibility.showAll;

  @override
  void initState() {
    super.initState();
    loadPatternTrainerConfig().then((config) {
      if (!mounted) return;
      setState(() {
        _bpm = config.bpm;
        _difficulty = config.difficulty;
        _numPatterns = config.numPatterns;
        _swapHands = config.swapHands;
        _sectionVisibility = config.sectionVisibility;
      });
    });
  }

  void _saveConfig() {
    savePatternTrainerConfig(
      PatternTrainerConfig(
        bpm: _bpm,
        difficulty: _difficulty,
        numPatterns: _numPatterns,
        swapHands: _swapHands,
        sectionVisibility: _sectionVisibility,
      ),
    );
  }

  void _handleStart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatternTrainerRunScreen(
          config: PatternTrainerConfig(
            bpm: _bpm,
            difficulty: _difficulty,
            numPatterns: _numPatterns,
            swapHands: _swapHands,
            sectionVisibility: _sectionVisibility,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Pattern Trainer',
      showSettings: false,
      headerPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      headerBottomSpacing: 24,
      contentPadding: const EdgeInsets.all(10),
      contentMaxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: IntrinsicColumnWidth(), 1: IntrinsicColumnWidth()},
              children: [
                fieldRow(
                  'Difficulty',
                  DropdownButton<Difficulty>(
                    value: _difficulty,
                    items: const [
                      DropdownMenuItem(value: Difficulty.easy, child: Text('Easy')),
                      DropdownMenuItem(value: Difficulty.medium, child: Text('Medium')),
                      DropdownMenuItem(value: Difficulty.hard, child: Text('Hard')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _difficulty = v;
                        _saveConfig();
                      });
                    },
                  ),
                ),
                fieldRow(
                  'Show',
                  DropdownButton<SectionVisibility>(
                    value: _sectionVisibility,
                    items: const [
                      DropdownMenuItem(value: SectionVisibility.showAll, child: Text('All')),
                      DropdownMenuItem(value: SectionVisibility.showListen, child: Text('Listen')),
                      DropdownMenuItem(value: SectionVisibility.showRepeat, child: Text('Repeat')),
                      DropdownMenuItem(value: SectionVisibility.dontShow, child: Text('Never')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _sectionVisibility = v;
                        _saveConfig();
                      });
                    },
                  ),
                ),
                fieldRow(
                  'BPM',
                  NumberInputField(
                    label: 'BPM',
                    showLabel: false,
                    value: _bpm,
                    onChanged: (v) => setState(() {
                      _bpm = v;
                      _saveConfig();
                    }),
                    min: 30,
                    max: 120,
                    width: 60,
                  ),
                ),
                fieldRow(
                  'Patterns',
                  NumberInputField(
                    label: 'Patterns',
                    showLabel: false,
                    value: _numPatterns,
                    onChanged: (v) => setState(() {
                      _numPatterns = v;
                      _saveConfig();
                    }),
                    min: 1,
                    max: 20,
                    width: 60,
                  ),
                ),
                fieldRow(
                  'Swap L↔︎R',
                  // Table stretches every cell in a column to that column's full width (here,
                  // wide enough for the dropdowns) -- unlike NumberInputField/DropdownButton,
                  // which pack their content at the start when given extra width, Switch's own
                  // renderer centers its track within whatever box it's given. Align pins it to
                  // the left instead; shrinkWrap also drops its invisible min-tap-target padding
                  // (48x48, for accessibility), which would otherwise widen that box further.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Switch(
                      value: _swapHands,
                      onChanged: (v) => setState(() {
                        _swapHands = v;
                        _saveConfig();
                      }),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleStart,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.btnGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
