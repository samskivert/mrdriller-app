import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/drill_config.dart';
import '../util/colors.dart';
import '../widgets/drill_overview_view.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import 'pattern_trainer_run_screen.dart';

const _difficulties = [
  (Difficulty.easy, 'Easy', 'One measure, played four times.'),
  (Difficulty.medium, 'Medium', 'Two measures, taking turns.'),
  (Difficulty.hard, 'Hard', 'Four different measures.'),
];

const _visibilities = [
  (
    SectionVisibility.showAll,
    'All',
    'See each pattern while you listen, and while you play it back.',
  ),
  (
    SectionVisibility.showListen,
    'Listen',
    'See each pattern while you listen, then play it back from memory.',
  ),
  (
    SectionVisibility.showRepeat,
    'Repeat',
    'Hear each pattern without seeing it, then see it while you play it back.',
  ),
  (SectionVisibility.dontShow, 'Never', 'Ears only: you never see the patterns.'),
];

/// The pattern trainer's config screen: bpm, how many patterns, hands, difficulty (with an
/// example of what a pattern at that difficulty looks like), and when the patterns are shown,
/// persisted as the user changes them. START! hands off to [PatternTrainerRunScreen] for the
/// actual practice session.
class PatternTrainerScreen extends StatefulWidget {
  const PatternTrainerScreen({super.key});

  @override
  State<PatternTrainerScreen> createState() => _PatternTrainerScreenState();
}

class _PatternTrainerScreenState extends State<PatternTrainerScreen> {
  PatternTrainerConfig _config = const PatternTrainerConfig();

  @override
  void initState() {
    super.initState();
    loadPatternTrainerConfig().then((config) {
      if (mounted) setState(() => _config = config);
    });
  }

  // (Callbacks build on _config, the latest config, rather than whatever it was when they were
  // built, so that changes made in quick succession don't undo each other.)
  void _setConfig(PatternTrainerConfig config) {
    setState(() => _config = config);
    savePatternTrainerConfig(config);
  }

  void _handleStart() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PatternTrainerRunScreen(config: _config)));
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final c = _config;
    final difficulty = _difficulties.firstWhere((d) => d.$1 == c.difficulty);
    final visibility = _visibilities.firstWhere((v) => v.$1 == c.sectionVisibility);
    return CreamScreen(
      title: 'Pattern Trainer',
      showSettings: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 124,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: HudStepperCard(
                          HudStepperSpec(
                            label: 'BPM',
                            bannerColor: AppColors.bannerOrange,
                            value: c.bpm,
                            min: patternTrainerBpmLimits.min,
                            max: patternTrainerBpmLimits.max,
                            onChanged: (v) => _setConfig(_config.copyWith(bpm: v)),
                            decreaseLabel: 'Slower',
                            increaseLabel: 'Faster',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: HudStepperCard(
                          HudStepperSpec(
                            label: 'Patterns',
                            bannerColor: AppColors.bannerRed,
                            value: c.numPatterns,
                            min: patternCountLimits.min,
                            max: patternCountLimits.max,
                            format: (v) => '×$v',
                            onChanged: (v) => _setConfig(_config.copyWith(numPatterns: v)),
                            decreaseLabel: 'Fewer patterns',
                            increaseLabel: 'More patterns',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: HandsToggle(
                          swapped: c.swapHands,
                          onChanged: (v) => _setConfig(_config.copyWith(swapHands: v)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                BannerCard(
                  label: 'Difficulty',
                  color: AppColors.bannerBlue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CandySegmented(
                        options: [for (final (value, label, _) in _difficulties) (value, label)],
                        value: c.difficulty,
                        onChanged: (v) => _setConfig(_config.copyWith(difficulty: v)),
                      ),
                      const SizedBox(height: 10),
                      _Description(difficulty.$3),
                      const SizedBox(height: 10),
                      _ExamplePattern(difficulty: c.difficulty, swapped: c.swapHands),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                BannerCard(
                  label: 'Show patterns',
                  color: AppColors.bannerMagenta,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CandySegmented(
                        options: [for (final (value, label, _) in _visibilities) (value, label)],
                        value: c.sectionVisibility,
                        colors: AppColors.candyPink,
                        onChanged: (v) => _setConfig(_config.copyWith(sectionVisibility: v)),
                      ),
                      const SizedBox(height: 10),
                      _Description(visibility.$3),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                StartButton(
                  time: formatDrillClock(patternTrainerSeconds(c)),
                  onPressed: _handleStart,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Description extends StatelessWidget {
  final String text;

  const _Description(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.inkMuted,
      ),
    );
  }
}

/// An example of the kind of pattern [difficulty] makes: the same measure four times, two taking
/// turns, or four different ones.
class _ExamplePattern extends StatelessWidget {
  final Difficulty difficulty;
  final bool swapped;

  const _ExamplePattern({required this.difficulty, required this.swapped});

  @override
  Widget build(BuildContext context) {
    final a = measure([R, l, r, l]);
    final b = measure([r, L, r, L]);
    final c = measure([R, l, R, l]);
    final d = measure([r, l, r, L]);
    final measures = switch (difficulty) {
      Difficulty.easy => [a, a, a, a],
      Difficulty.medium => [a, b, a, b],
      Difficulty.hard => [a, b, c, d],
    };
    final example = Drill(
      id: 'example',
      title: 'Example',
      bpm: 4,
      rows: [
        [
          section('Example', 1, [
            line([measures[0], measures[1]]),
            line([measures[2], measures[3]]),
          ]),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DrillOverviewView(drill: swapped ? swapHands(example) : example),
        ),
      ),
    );
  }
}
