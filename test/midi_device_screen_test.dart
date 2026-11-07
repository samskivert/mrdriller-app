import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
