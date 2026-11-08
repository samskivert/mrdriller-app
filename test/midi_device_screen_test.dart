import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/screens/calibration_screen.dart';
import 'package:mrdriller/screens/midi_device_screen.dart';
import 'package:mrdriller/state/audio_outputs.dart';
import 'package:mrdriller/state/midi_devices.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'KAT / KTMP1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await midiDevices.load();
    await audioOutputs.load();
  });

  testWidgets('sets, and turns off, the accent velocity', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MidiDeviceScreen(deviceKey: key)));
    await tester.pump();
    expect(midiDevices.accentVelocityOf(key), isNull);
    // Nothing's been hit to set it from.
    final setFromHits = find.ancestor(
      of: find.text('SET FROM MY HITS').first,
      matching: find.byType(CandyButton),
    );
    expect(tester.widget<CandyButton>(setFromHits).onPressed, isNull);

    // Dragging the slider sets it.
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pump();
    final velocity = midiDevices.accentVelocityOf(key);
    expect(velocity, isNotNull);
    expect(find.text('$velocity'), findsOneWidget);

    await tester.tap(find.text('OFF').first);
    await tester.pump();
    expect(midiDevices.accentVelocityOf(key), isNull);
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets('has a timing test, without the controls for investigating timing', (tester) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MidiDeviceScreen(deviceKey: key)));
    await tester.pump();
    expect(find.text('TIMING TEST'), findsOneWidget);
    expect(find.text('Microphone open'), findsNothing);
    expect(find.text('Play clicks now'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (button, banner) in [
    ('PLAY ALONG', 'PLAY ALONG'),
    ('BETWEEN CLICKS', 'BETWEEN CLICKS'),
  ]) {
    testWidgets('calibrates on a page of its own: $button', (tester) async {
      tester.view.physicalSize = const Size(390, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: MidiDeviceScreen(deviceKey: key)));
      await tester.pump();
      await tester.tap(find.text(button).first);
      await tester.pumpAndSettle();
      expect(find.byType(CalibrationScreen), findsOneWidget);
      expect(find.text('HOW TO'), findsOneWidget);
      expect(find.text(banner), findsWidgets);
      expect(find.text('Not calibrated yet.'), findsOneWidget);
      // Its instructions fold away, and back.
      expect(find.text('1.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.expand_less_rounded));
      await tester.pumpAndSettle();
      expect(find.text('1.'), findsNothing);
      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await tester.pumpAndSettle();
      expect(find.text('1.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
