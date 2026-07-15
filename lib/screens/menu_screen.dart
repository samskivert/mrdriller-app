import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../util/colors.dart';

final List<Tool> tools = [const Tool(id: 'pattern-trainer', title: 'Pattern Trainer')];

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1024;
            final content = SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: const _MenuContent(),
                ),
              ),
            );
            if (!wide) return content;
            return Stack(
              children: [
                Positioned(
                  left: constraints.maxWidth * 0.25 - 256,
                  top: 0,
                  child: Image.asset('assets/images/mrdriller.png', width: 512, fit: BoxFit.fitWidth),
                ),
                Align(alignment: Alignment.centerRight, child: FractionallySizedBox(widthFactor: 0.5, child: content)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuContent extends StatelessWidget {
  const _MenuContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 32),
            const Expanded(child: _TitleText()),
            IconButton(
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ActivityGrid(
          items: [
            for (final drill in data.drills)
              _ActivityButton(title: drill.title, onTap: () => Navigator.of(context).pushNamed('/drill/${drill.id}')),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        _ActivityGrid(
          items: [
            for (final tool in tools)
              _ActivityButton(title: tool.title, onTap: () => Navigator.of(context).pushNamed('/tool/${tool.id}')),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Mr. Driller · Flutter Edition',
            style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
      ],
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    const text = 'Mr. Driller';
    const style = TextStyle(fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: 4, height: 1);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = AppColors.brandOutline,
          ),
        ),
        Text(text, textAlign: TextAlign.center, style: style.copyWith(color: AppColors.brandRed)),
      ],
    );
  }
}

class _ActivityGrid extends StatelessWidget {
  final List<Widget> items;

  const _ActivityGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columns = constraints.maxWidth >= 340 ? 2 : 1;
        final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final item in items) SizedBox(width: itemWidth, child: item)],
        );
      },
    );
  }
}

class _ActivityButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ActivityButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.btnBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      child: Text(title, textAlign: TextAlign.center),
    );
  }
}
