import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/colors.dart';
import '../widgets/arcade.dart';

/// Shown for a route that doesn't exist (e.g. a mistyped /drills/... link on the web): a mystery
/// "?", LOST UNDERGROUND!, which [path] wasn't found, and a button back to the main menu. That
/// replaces the whole history, since a page like this is often the very first one, reached from a
/// link, with nothing to go back to.
class UnknownScreen extends StatelessWidget {
  final String path;

  const UnknownScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Bubbles(
                bubbles: [(1.0, 0.05, 90), (0.1, 0.12, 36), (0.0, 0.8, 70), (0.9, 0.95, 40)],
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  safe.left + 24,
                  safe.top + 24,
                  safe.right + 24,
                  safe.bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: PuffyText(
                          '?',
                          size: 90,
                          color: AppColors.gold,
                          shadow: AppColors.goldOutline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        label: 'Lost underground!',
                        excludeSemantics: true,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            children: [
                              PuffyText('LOST', size: 46),
                              PuffyText('UNDERGROUND!', size: 46),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        path.isEmpty
                            ? "There's nothing here."
                            : "There's no drill or tool at $path.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      CandyButton(
                        label: 'MENU',
                        icon: Icons.home_rounded,
                        colors: AppColors.candyBlue,
                        height: 58,
                        fontSize: 20,
                        onPressed: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
                      ),
                    ],
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
