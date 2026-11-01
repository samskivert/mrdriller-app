import 'dart:async';

import 'package:flutter/widgets.dart';

/// Completes once the widget at [context] has been drawn and its route has finished animating in
/// (or right after that first frame, if it isn't animating). Something time-critical, like a
/// metronome's first beats, should wait for this: the first frame of a new screen and the frames
/// of its transition are the slowest the app draws, and they hold up timers on the UI thread.
/// Callers should check that they're still mounted afterwards (the route can be popped before it
/// ever finishes coming in, which also completes this).
Future<void> routeSettled(BuildContext context) async {
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  final animation = ModalRoute.of(context)?.animation;
  if (animation == null || animation.isCompleted) return;
  final done = Completer<void>();
  void listener(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) {
      animation.removeStatusListener(listener);
      done.complete();
    }
  }

  animation.addStatusListener(listener);
  await done.future;
  // And the frame after it's done, in which the route drops its transition.
  await WidgetsBinding.instance.endOfFrame;
}
