// Works out which side of a landscape screen has the camera housing (notch/Dynamic Island), so a
// layout can keep clear of it on that side but use (most of) the safe-area inset on the other,
// which is only there for the screen's rounded corners.
//
// Neither platform says this directly through Flutter's safe-area padding: iOS reports equal
// insets on both sides in landscape whichever way the phone is turned. Flutter does expose cutout
// positions as display features, but only on Android; on iOS we ask the app which way the
// interface is rotated, and it tells us when that changes (see ios/Runner/AppDelegate.swift).

import 'dart:ui' show DisplayFeatureType, FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum CutoutSide { left, right, none }

const _channel = MethodChannel('mrdriller/display');

// The iOS interface orientation, as last reported by the app (see [refreshCutoutSide]).
final ValueNotifier<String?> _iosOrientation = ValueNotifier(null);

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Notifies when [landscapeCutoutSide]'s answer may have changed without the screen's size or
/// insets changing (e.g. turning an iPhone from one landscape orientation to the other).
Listenable get cutoutSideChanges => _iosOrientation;

/// Starts listening for interface rotations reported by the app. Call once at startup.
void initScreenCutout() {
  if (!_isIOS) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'interfaceOrientationChanged') {
      _iosOrientation.value = call.arguments as String?;
    }
  });
  refreshCutoutSide();
}

/// Asks the app for the current interface orientation again, e.g. after the screen's size
/// changes. Listeners of [cutoutSideChanges] hear about the answer if it's different.
Future<void> refreshCutoutSide() async {
  if (!_isIOS) return;
  try {
    _iosOrientation.value = await _channel.invokeMethod<String>('interfaceOrientation');
  } on PlatformException {
    // Leave it unknown.
  } on MissingPluginException {
    // Leave it unknown.
  }
}

/// Which side of [view] the camera cutout is on, assuming it's in landscape: [CutoutSide.none] if
/// the screen has no cutout, or null if that can't be determined (e.g. on web, or other platforms),
/// in which case the safe-area insets should be respected as-is on both sides.
CutoutSide? landscapeCutoutSide(FlutterView view) {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final cutouts = view.displayFeatures.where((f) => f.type == DisplayFeatureType.cutout);
      if (cutouts.isEmpty) return CutoutSide.none;
      // Physical pixels, in the same space as the view's own size.
      final center = cutouts.first.bounds.center.dx;
      return center < view.physicalSize.width / 2 ? CutoutSide.left : CutoutSide.right;
    case TargetPlatform.iOS:
      // UIKit names landscape orientations by where the home button would be, so the top of the
      // device -- with the camera housing -- is on the opposite side.
      return switch (_iosOrientation.value) {
        'landscapeRight' => CutoutSide.left,
        'landscapeLeft' => CutoutSide.right,
        _ => null,
      };
    default:
      return null;
  }
}
