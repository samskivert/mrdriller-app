// HUD-styled controls for configuring a drill: number steppers, the hands toggle, and the start
// button.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/model.dart';
import '../util/colors.dart';
import 'arcade.dart';
import 'stroke_view.dart';

/// One configurable number for [HudStepperCard]/[HudStepperRow]: its [label] (on a [bannerColor]
/// banner), [value] (shown via [format], e.g. "+5"), and the range it's limited to.
class HudStepperSpec {
  final String label;
  final Color bannerColor;
  final int value;
  final int min;
  final int max;
  final String Function(int value) format;
  final ValueChanged<int> onChanged;
  final String decreaseLabel;
  final String increaseLabel;

  const HudStepperSpec({
    required this.label,
    required this.bannerColor,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.format = _plain,
  });

  static String _plain(int value) => '$value';

  void _step(int delta) {
    final next = (value + delta).clamp(min, max);
    if (next != value) onChanged(next);
  }
}

Widget _stepButton(HudStepperSpec spec, int delta, double size) => CandyButton(
  icon: delta < 0 ? Icons.remove_rounded : Icons.add_rounded,
  tooltip: delta < 0 ? spec.decreaseLabel : spec.increaseLabel,
  colors: AppColors.candyBlue,
  height: size,
  repeat: true,
  onPressed: (delta < 0 ? spec.value > spec.min : spec.value < spec.max)
      ? () => spec._step(delta)
      : null,
);

/// The stepper's value in digit tiles. Tapping it opens a dialog to type a new value directly
/// (quicker than stepping for a big change, e.g. 60 to 120 bpm).
Widget _value(BuildContext context, HudStepperSpec spec, double height) => Semantics(
  button: true,
  label: '${spec.label}: ${spec.format(spec.value)}. Tap to type a new value.',
  excludeSemantics: true,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _editValue(context, spec),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: DigitTiles(value: spec.format(spec.value), height: height),
    ),
  ),
);

Future<void> _editValue(BuildContext context, HudStepperSpec spec) async {
  final controller = TextEditingController(text: '${spec.value}');
  controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
  int? parse() => int.tryParse(controller.text);
  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Align(
        alignment: Alignment.centerLeft,
        child: HudBanner(
          label: spec.label,
          color: spec.bannerColor,
          fontSize: 15,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.ink,
        ),
        decoration: InputDecoration(
          helperText: '${spec.min} – ${spec.max}',
          helperStyle: const TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w700),
        ),
        onSubmitted: (_) => Navigator.of(context).pop(parse()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        CandyButton(
          label: 'OK',
          colors: AppColors.candyGreen,
          onPressed: () => Navigator.of(context).pop(parse()),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result != null) {
    final clamped = result.clamp(spec.min, spec.max);
    if (clamped != spec.value) spec.onChanged(clamped);
  }
}

/// A stepper as a HUD card (for a row of them across a portrait HUD): the banner, the value in
/// digit tiles, and -/+ candy buttons below. Fills the height it's given (so give it one).
class HudStepperCard extends StatelessWidget {
  final HudStepperSpec spec;

  const HudStepperCard(this.spec, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HudBanner(label: spec.label, color: spec.bannerColor),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(child: _value(context, spec, 32)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Smaller buttons in a narrow card (e.g. on a small phone), leaving a gap between.
                final size = ((constraints.maxWidth - 6) / 2).clamp(24.0, 38.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_stepButton(spec, -1, size), _stepButton(spec, 1, size)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A stepper as one row of a HUD card (for a stack of them in a landscape sidebar): the banner,
/// then -, the value in digit tiles, and +.
class HudStepperRow extends StatelessWidget {
  final HudStepperSpec spec;

  const HudStepperRow(this.spec, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: HudBanner(
            label: spec.label,
            color: spec.bannerColor,
            borderRadius: BorderRadius.circular(9),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          ),
        ),
        const SizedBox(width: 6),
        _stepButton(spec, -1, 34),
        Expanded(child: Center(child: _value(context, spec, 30))),
        _stepButton(spec, 1, 34),
      ],
    );
  }
}

/// A white HUD card holding [children] as rows, e.g. a stack of [HudStepperRow]s.
class HudRowsCard extends StatelessWidget {
  final List<Widget> children;

  const HudRowsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The HANDS setting: shows which hand a drill leads with (R then L normally, L then R once
/// [swapped]), and tapping it swaps them. A card (alongside [HudStepperCard]s) by default, or a
/// [row] (alongside [HudStepperRow]s in a [HudRowsCard]).
class HandsToggle extends StatelessWidget {
  final bool swapped;
  final ValueChanged<bool> onChanged;
  final bool row;

  const HandsToggle({super.key, required this.swapped, required this.onChanged, this.row = false});

  @override
  Widget build(BuildContext context) {
    final miniSize = row ? 26.0 : 30.0;
    Widget mini(Hand hand) => StrokeView(stroke: hit(hand, true), size: miniSize);
    final hands = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mini(swapped ? Hand.L : Hand.R),
          Icon(Icons.swap_horiz_rounded, size: miniSize * 0.7, color: const Color(0xFF9A90A8)),
          mini(swapped ? Hand.R : Hand.L),
        ],
      ),
    );
    final Widget content;
    if (row) {
      content = SizedBox(
        height: 38,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: HudBanner(
                label: 'Hands',
                color: AppColors.bannerGreen,
                borderRadius: BorderRadius.circular(9),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              ),
            ),
            Expanded(child: Center(child: hands)),
          ],
        ),
      );
    } else {
      content = Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HudBanner(label: 'Hands', color: AppColors.bannerGreen),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Center(child: hands),
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      toggled: swapped,
      label: 'Swap hands',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!swapped),
        child: content,
      ),
    );
  }
}

/// The big green START! button (or another [label]), optionally with the total [time] it'll take
/// (e.g. "3:12") in a chip below.
class StartButton extends StatelessWidget {
  final String? time;
  final VoidCallback onPressed;
  final double height;
  final String label;
  final IconData icon;

  const StartButton({
    super.key,
    this.time,
    required this.onPressed,
    this.height = 76,
    this.label = 'START!',
    this.icon = Icons.play_arrow_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return CandyButton(
      label: label,
      icon: icon,
      colors: AppColors.candyGreen,
      height: height,
      fontSize: height * 0.3,
      onPressed: onPressed,
      below: time == null ? null : TimeChip(time: time!, fontSize: height * 0.2),
    );
  }
}

/// A candy on/off switch: a green candy track with the knob on the right when [value] is on, or a
/// gray one with it on the left when off.
class CandySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CandySwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const width = 58.0;
    const height = 34.0;
    const knob = 26.0;
    const duration = Duration(milliseconds: 160);
    final candy = AppColors.candyGreen;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: duration,
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: value
                  ? [candy.hi, candy.base, candy.lo]
                  : const [Color(0xFFD9D4E2), Color(0xFFC6C0D2), Color(0xFFB2ABC2)],
            ),
            boxShadow: [
              BoxShadow(
                color: value ? candy.outline : const Color(0xFF8C849E),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: knob,
              height: knob,
              margin: const EdgeInsets.symmetric(horizontal: (height - knob) / 2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How long something will take (e.g. "3:12"), as a little dark green pill with a clock icon --
/// shown inside a [StartButton], or on its own beside one.
class TimeChip extends StatelessWidget {
  final String time;
  final double fontSize;

  const TimeChip({super.key, required this.time, this.fontSize = 15});

  @override
  Widget build(BuildContext context) {
    final green = AppColors.candyGreen;
    return Semantics(
      label: 'Time: $time',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.3),
        decoration: BoxDecoration(
          color: green.outline.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(fontSize),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: fontSize, color: green.icing),
            SizedBox(width: fontSize * 0.3),
            Text(
              time,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: fontSize,
                height: 1,
                fontWeight: FontWeight.w900,
                color: green.icing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
