// Renders the app's icons from the app's own widgets (see AppIcon and Mitsudomoe, in
// lib/widgets/taiko_drum_head.dart), so they can't drift out of sync with the design:
//
// - assets/icon/icon.png: the app icon (opaque, as iOS requires).
// - assets/icon/icon_foreground.png: the foreground layer of the Android adaptive icon.
// - android/app/src/main/res/drawable-*/ic_notification.png: Android's notification (status bar)
//   icon, a white silhouette at each screen density.
//
// Run from the project root, then regenerate each platform's icons from the first two:
//
//   flutter test tool/generate_icons_test.dart
//   dart run flutter_launcher_icons

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/widgets/taiko_drum_head.dart';

Future<void> _render(WidgetTester tester, Widget widget, double size, String path) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(size, size);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: size, height: size, child: widget),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('Wrote $path');
}

void main() {
  testWidgets('generate icons', (tester) async {
    addTearDown(tester.view.reset);
    await _render(tester, const AppIcon(size: 1024), 1024, 'assets/icon/icon.png');
    await _render(
      tester,
      const AppIcon(size: 1024, foreground: true),
      1024,
      'assets/icon/icon_foreground.png',
    );
    // 24dp, its silhouette inside the 22dp that Android keeps clear of the edges.
    for (final (density, scale) in const [
      ('mdpi', 1.0),
      ('hdpi', 1.5),
      ('xhdpi', 2.0),
      ('xxhdpi', 3.0),
      ('xxxhdpi', 4.0),
    ]) {
      await _render(
        tester,
        Padding(
          padding: EdgeInsets.all(scale),
          child: const Mitsudomoe(color: Colors.white),
        ),
        24 * scale,
        'android/app/src/main/res/drawable-$density/ic_notification.png',
      );
    }
  });
}
