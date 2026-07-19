import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../widgets/app_header.dart';
import '../widgets/components.dart';

/// Lists every drill, linking to each one's overview/config screen.
class DrillMenuScreen extends StatelessWidget {
  const DrillMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: AppHeader(title: 'Drills'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 512),
                    child: ActivityGrid(
                      items: [
                        for (final drill in data.drills)
                          ActivityButton(
                            title: drill.title,
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/drill/${drill.id}'),
                          ),
                      ],
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
