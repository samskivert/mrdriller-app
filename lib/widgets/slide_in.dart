import 'package:flutter/material.dart';

/// Plays a one-shot slide-from-[begin]-to-rest animation starting the instant it mounts.
///
/// Give it a `key` that changes whenever the content it wraps changes (e.g. `ValueKey(sectionId)`)
/// so Flutter discards the old element and mounts a brand new one — that's what makes the
/// animation restart. Deliberately NOT built on `TweenAnimationBuilder`/`AnimatedWidgetBaseState`:
/// those only animate when their `tween` changes on an *already-mounted* instance, and jump
/// straight to the end value on first build — exactly the opposite of what "restart on key
/// change" needs. An explicit `AnimationController.forward()` in `initState` is what actually
/// guarantees the first rendered frame is at `begin`.
class SlideIn extends StatefulWidget {
  final Widget child;
  final Offset begin;
  final Duration duration;
  final Curve curve;

  const SlideIn({
    super.key,
    required this.child,
    this.begin = const Offset(0, 1),
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOut,
  });

  @override
  State<SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<SlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    // AnimationBehavior.preserve opts out of the OS "reduce motion" accessibility setting, which
    // otherwise makes AnimationController silently run at 5% of its configured duration. The web
    // version never checked prefers-reduced-motion, so this keeps the two in parity; a future
    // pass could instead honor it (e.g. skip straight to Offset.zero) if that's preferred.
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      animationBehavior: AnimationBehavior.preserve,
    )..forward();
    _offset = Tween<Offset>(
      begin: widget.begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => FractionalTranslation(
        key: const ValueKey('slide-in'),
        translation: _offset.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Fades in from transparent to opaque, but only after [delay] has elapsed since mounting —
/// stays fully invisible until then. Same "restart via changing key" usage as [SlideIn].
class FadeInDelayed extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeInDelayed({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 400),
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeInDelayed> createState() => _FadeInDelayedState();
}

class _FadeInDelayedState extends State<FadeInDelayed> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0,
      animationBehavior: AnimationBehavior.preserve,
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}
