import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/services/cloud_store.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/metronome_settings.dart';
import 'package:mrdriller/state/playlists.dart';
import 'package:mrdriller/state/practice_log.dart';
import 'package:mrdriller/state/settings.dart';
import 'package:mrdriller/state/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

PracticeLogEntry _entry(DateTime at, [String drillId = 'paradiddles']) => PracticeLogEntry(
  completedAt: at,
  drillId: drillId,
  config: const DrillConfig(bpm: 90, swapHands: true),
  seconds: 300,
);

// Sets up local storage as it would be on a device that has run the app (or a fresh install, if
// empty), and loads all the synced state from it and the cloud.
Future<void> _launch(Map<String, Object> local) async {
  SharedPreferences.setMockInitialValues(local);
  await settings.load();
  await playlists.load();
  await practiceLog.load();
}

Map<String, String> _cloud() => {for (final key in cloudStore.keys) key: cloudStore[key]!};

void main() {
  setUp(() => cloudStore.debugSetValues({}));
  tearDown(cloudStore.debugReset);

  group('practice log', () {
    test('comes back from the cloud after a reinstall', () async {
      await _launch({});
      practiceLog.add(_entry(DateTime.utc(2026, 9, 30, 23)));
      practiceLog.add(_entry(DateTime.utc(2026, 10, 1, 1)));
      expect(cloudStore.keys.toSet(), {'practiceLog.2026-09', 'practiceLog.2026-10'});

      await _launch({});
      expect(practiceLog.entries.map((e) => e.completedAt), [
        DateTime.utc(2026, 10, 1, 1),
        DateTime.utc(2026, 9, 30, 23),
      ]);
      expect(practiceLog.entries.first.config.bpm, 90);
      expect(practiceLog.entries.first.config.swapHands, isTrue);
    });

    test("a metronome entry's preset name comes back from the cloud", () async {
      await _launch({});
      // At different times, as entries made in the same millisecond would be taken as one.
      withClock(Clock.fixed(DateTime(2026, 10, 1, 9)), () {
        practiceLog.recordMetronome(name: 'Fast', bpm: 180, seconds: 75);
      });
      withClock(Clock.fixed(DateTime(2026, 10, 1, 10)), () {
        practiceLog.recordMetronome(bpm: 90, seconds: 60);
      });
      await _launch({});
      expect(practiceLog.entries.map((e) => (e.drillId, e.title, e.config.bpm, e.seconds)), {
        (metronomeId, null, 90, 60),
        (metronomeId, 'Fast', 180, 75),
      });
    });

    test("keeps every device's entries, without duplicates", () async {
      await _launch({});
      practiceLog.add(_entry(DateTime.utc(2026, 10, 1, 1)));
      final first = _cloud();

      // Another device, which has its own entries from before the log synced, in local time.
      await _launch({
        'practiceLog.entries': jsonEncode([
          {..._entry(DateTime(2026, 10, 2, 9)).toJson(), 'completedAt': '2026-10-02T09:00:00.000'},
        ]),
      });
      expect(practiceLog.entries, hasLength(2));
      final local = jsonDecode(
        (await SharedPreferences.getInstance()).getString('practiceLog.entries')!,
      );
      expect(local[0]['completedAt'], endsWith('Z'));

      // The first device gets the change.
      final second = _cloud();
      cloudStore.debugSetValues(first);
      await _launch({});
      cloudStore.debugSetValues(second);
      expect(practiceLog.entries, hasLength(2));
      await _launch({});
      expect(practiceLog.entries, hasLength(2));
    });

    test('puts back entries lost when two devices wrote the same month', () async {
      await _launch({});
      practiceLog.add(_entry(DateTime.utc(2026, 10, 1)));
      practiceLog.add(_entry(DateTime.utc(2026, 10, 2)));
      // Another device's write of the month, without the second entry, landed last.
      cloudStore.debugSetValues({
        'practiceLog.2026-10': jsonEncode([
          [DateTime.utc(2026, 10, 1).millisecondsSinceEpoch, 'paradiddles', 90, 0, 1, 1, 1, 300],
          [DateTime.utc(2026, 10, 3).millisecondsSinceEpoch, 'paradiddles', 90, 0, 1, 1, 1, 300],
        ]),
      });
      expect(practiceLog.entries, hasLength(3));
      expect(jsonDecode(cloudStore['practiceLog.2026-10']!), hasLength(3));
    });
  });

  group('playlists', () {
    test('come back from the cloud after a reinstall, in order', () async {
      await _launch({});
      final a = playlists.create('A');
      playlists.create('B');
      playlists.addEntry(a.id, const PlaylistEntry(drillId: 'paradiddles', config: DrillConfig()));

      await _launch({});
      expect(playlists.playlists.map((p) => p.name), ['A', 'B']);
      expect(playlists.playlists.first.entries, hasLength(1));
    });

    test("one made before the cloud's copy arrives doesn't replace it", () async {
      await _launch({});
      playlists.create('Old');
      final cloud = _cloud();

      cloudStore.debugSetValues({});
      await _launch({});
      playlists.create('New');
      cloudStore.debugSetValues(cloud);
      expect(playlists.playlists.map((p) => p.name).toSet(), {'Old', 'New'});
    });

    test("a deletion isn't undone by a device that still has it", () async {
      await _launch({});
      final doomed = playlists.create('Doomed');
      playlists.create('Kept');
      final stale = (await SharedPreferences.getInstance()).getString('playlists.v2')!;

      await Future<void>.delayed(const Duration(milliseconds: 2));
      playlists.delete(doomed.id);
      await _launch({'playlists.v2': stale});
      expect(playlists.playlists.map((p) => p.name), ['Kept']);
    });

    test('keeps the ones saved before playlists synced', () async {
      await _launch({});
      playlists.create('Synced');
      await _launch({
        'playlists': jsonEncode([const Playlist(id: 'old', name: 'Unsynced').toJson()]),
      });
      expect(playlists.playlists.map((p) => p.name).toSet(), {'Synced', 'Unsynced'});
    });
  });

  test('metronome presets and settings come back from the cloud after a reinstall', () async {
    SharedPreferences.setMockInitialValues({});
    await metronomePresets.load();
    final preset = metronomePresets.create('Fast', const MetronomeConfig(bpm: 180));
    metronomePresets.save(preset.id, const MetronomeConfig(bpm: 200));
    await saveMetronomeConfig(const MetronomeConfig(bpm: 70));

    SharedPreferences.setMockInitialValues({});
    await metronomePresets.load();
    expect(metronomePresets.presets.single.name, 'Fast');
    expect(metronomePresets.presets.single.config.bpm, 200);
    expect((await loadMetronomeConfig()).bpm, 70);
  });

  test('the latest change to a drill config wins', () async {
    SharedPreferences.setMockInitialValues({});
    await saveDrillConfig('paradiddles', const DrillConfig(bpm: 100));
    final newer = _cloud();

    // A device with a config from before configs synced, which counts as older.
    SharedPreferences.setMockInitialValues({
      'config.paradiddles': jsonEncode(const DrillConfig(bpm: 70).toJson()),
    });
    expect((await loadDrillConfig('paradiddles')).bpm, 100);

    SharedPreferences.setMockInitialValues({
      'config.paradiddles': jsonEncode(Stamped(0, const DrillConfig(bpm: 70).toJson()).toJson()),
    });
    cloudStore.debugSetValues({});
    expect((await loadDrillConfig('paradiddles')).bpm, 70);
    expect(cloudStore['config.paradiddles'], isNotNull);
    cloudStore.debugSetValues(newer);
    expect((await loadDrillConfig('paradiddles')).bpm, 100);
  });

  test('settings saved before they synced are kept and synced', () async {
    await _launch({'settings.showBouncingDot': false});
    expect(settings.showBouncingDot, isFalse);
    await _launch({});
    expect(settings.showBouncingDot, isFalse);
    settings.setShowBouncingDot(true);
    await _launch({});
    expect(settings.showBouncingDot, isTrue);
  });
}
