import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../widgets/drill_card.dart';
import '../widgets/hud_layout.dart';

/// A "stage select" of every drill, for screens whose only job is picking one -- what happens on
/// tap is up to the caller (deep-linking to it, configuring it for a playlist, etc). Each group of
/// a drill and its variations gets a card, previewing each one's notes.
class DrillPickerScreen extends StatelessWidget {
  final String title;
  final bool showSettings;
  final void Function(BuildContext context, Drill drill) onDrillTap;

  const DrillPickerScreen({
    super.key,
    required this.title,
    this.showSettings = true,
    required this.onDrillTap,
  });

  static const _maxCardWidth = 520.0;
  static const _gap = 14.0;

  Widget _card(BuildContext context, int index) => DrillGroupCard(
    number: index + 1,
    drills: data.drills[index],
    onTap: (drill) => onDrillTap(context, drill),
  );

  // A card's rough height: a main drill's part of it, plus a bit less for each variation.
  static double _cardHeight(List<Drill> group) => 103 + 94.0 * (group.length - 1);

  // The cards in [columns] columns, filled in order top to bottom and then left to right, with the
  // breaks between columns chosen (by their cards' rough heights) to make the tallest column as
  // short as possible.
  Widget _columns(BuildContext context, int columns, EdgeInsets padding) {
    final n = data.drills.length;
    final heights = [for (final group in data.drills) _cardHeight(group) + _gap];
    double run(int from, int to) => heights.sublist(from, to).fold(0.0, (a, b) => a + b);
    // tallest[k][i]: the tallest column, at best, laying out the first i cards in k columns; and
    // breaks[k][i]: where the last of those columns starts, to get it.
    final tallest = [
      [for (var i = 0; i <= n; i++) i == 0 ? 0.0 : double.infinity],
    ];
    final breaks = [List.filled(n + 1, 0)];
    for (var k = 1; k <= columns; k++) {
      tallest.add(List.filled(n + 1, double.infinity));
      breaks.add(List.filled(n + 1, 0));
      for (var i = 0; i <= n; i++) {
        for (var j = 0; j <= i; j++) {
          final h = tallest[k - 1][j] > run(j, i) ? tallest[k - 1][j] : run(j, i);
          if (h < tallest[k][i]) {
            tallest[k][i] = h;
            breaks[k][i] = j;
          }
        }
      }
    }
    final cards = List.generate(columns, (_) => <int>[]);
    for (var k = columns, end = n; k > 0; end = breaks[k][end], k--) {
      cards[k - 1].addAll([for (var i = breaks[k][end]; i < end; i++) i]);
    }
    return SingleChildScrollView(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) const SizedBox(width: _gap),
            Expanded(
              child: Column(
                children: [
                  for (var j = 0; j < cards[c].length; j++) ...[
                    if (j > 0) const SizedBox(height: _gap),
                    _card(context, cards[c][j]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final padding = EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24);
    return CreamScreen(
      title: title,
      showSettings: showSettings,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - padding.horizontal;
          final columns = (width / (_maxCardWidth + _gap)).ceil().clamp(1, 99);
          if (columns > 1) return _columns(context, columns, padding);
          return ListView.separated(
            padding: padding,
            itemCount: data.drills.length,
            separatorBuilder: (_, _) => const SizedBox(height: _gap),
            itemBuilder: _card,
          );
        },
      ),
    );
  }
}
