import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/services/metronome_player.dart';
import 'package:mrdriller/services/metronome_sounds.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/metronome_settings.dart';
import 'package:mrdriller/state/practice_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hi = BeatLevel.high, _lo = BeatLevel.low, _off = BeatLevel.off;

// At 60 bpm, a beat every second.
const _second = Duration(seconds: 1);

// Ready at once, and keeps track of what it played.
class _FakeSounds implements MetronomeSounds {
  final played = <String>[];

  // (Not final: the real one's is set once it starts loading.)
  @override
  Future<void> ready = Future.value();

  @override
  void playBeep() => played.add('beep');

  @override
  void playBoop() => played.add('boop');

  @override
  void pause() {}

  @override
  void dispose() {}
}

MetronomePlayer _player(MetronomeConfig config, [_FakeSounds? sounds]) =>
    MetronomePlayer(config, makeSounds: () => sounds ?? _FakeSounds());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('plays the first beat at once, then a beat at a time around the measure', () {
    fakeAsync((async) {
      final sounds = _FakeSounds();
      final player = _player(const MetronomeConfig(bpm: 60, beats: [_hi, _lo, _off]), sounds);
      expect(player.beat, isNull);
      player.play();
      async.flushMicrotasks();
      expect(player.playing, isTrue);
      expect(player.beat, 0);
      async.elapse(_second);
      expect(player.beat, 1);
      async.elapse(_second);
      expect(player.beat, 2);
      async.elapse(_second);
      expect(player.beat, 0);
      // Nothing for the beat that's off.
      expect(sounds.played, ['beep', 'boop', 'beep']);
      player.dispose();
    });
  });

  test('speeds up every so many measures, from the next measure', () {
    fakeAsync((async) {
      final player = _player(
        const MetronomeConfig(bpm: 60, beats: [_hi, _lo], bpmIncrease: 30, increaseEvery: 2),
      );
      player.play();
      async.flushMicrotasks();
      // Two measures of two beats at 60 bpm: the fourth beat, ending them, comes at 3s.
      async.elapse(_second * 3);
      expect(player.beat, 1);
      expect(player.bpm, 90);
      // Then the next measure starts at 90 bpm: two-thirds of a second later.
      async.elapse(const Duration(milliseconds: 600));
      expect(player.beat, 1);
      async.elapse(const Duration(milliseconds: 100));
      expect(player.beat, 0);
      player.dispose();
    });
  });

  for (final (note, perSecond) in [
    (NoteValue.eighth, 2),
    (NoteValue.triplet, 3),
    (NoteValue.sixteenth, 4),
  ]) {
    test('plays ${note.plural} $perSecond to a quarter note', () {
      fakeAsync((async) {
        final sounds = _FakeSounds();
        final player = _player(
          MetronomeConfig(bpm: 60, beats: const [_hi, _lo, _lo, _lo, _lo], note: note),
          sounds,
        );
        player.play();
        async.flushMicrotasks();
        // (Just under a second, in case of rounding.)
        async.elapse(const Duration(milliseconds: 999));
        expect(sounds.played, hasLength(perSecond));
        async.elapse(const Duration(milliseconds: 2));
        expect(sounds.played, hasLength(perSecond + 1));
        player.dispose();
      });
    });
  }

  test('changing the note while playing changes the pace from the next beat', () {
    fakeAsync((async) {
      final sounds = _FakeSounds();
      const config = MetronomeConfig(bpm: 60, beats: [_hi, _lo, _lo, _lo]);
      final player = _player(config, sounds);
      player.play();
      async.flushMicrotasks();
      player.config = config.copyWith(note: NoteValue.sixteenth);
      async.elapse(const Duration(milliseconds: 251));
      expect(sounds.played, hasLength(2));
      player.dispose();
    });
  });

  test("doesn't speed up past the most bpm allowed", () {
    fakeAsync((async) {
      final player = _player(
        MetronomeConfig(
          bpm: metronomeBpmLimits.max - 10,
          beats: const [_hi, _lo],
          bpmIncrease: 50,
          increaseEvery: 1,
        ),
      );
      player.play();
      async.flushMicrotasks();
      async.elapse(_second * 2);
      expect(player.bpm, metronomeBpmLimits.max);
      player.dispose();
    });
  });

  test('picks up from the next beat after a pause', () {
    fakeAsync((async) {
      final player = _player(const MetronomeConfig(bpm: 60, beats: [_hi, _lo, _lo, _lo]));
      player.play();
      async.flushMicrotasks();
      async.elapse(_second);
      expect(player.beat, 1);
      player.pause();
      expect(player.beat, isNull);
      async.elapse(_second * 5);
      player.play();
      async.flushMicrotasks();
      expect(player.beat, 2);
      player.dispose();
    });
  });

  test('a new bpm starts over from it, and a shorter measure wraps around', () {
    fakeAsync((async) {
      final config = MetronomeConfig(
        bpm: 60,
        beats: const [_hi, _lo, _lo, _lo],
        bpmIncrease: 30,
        increaseEvery: 1,
      );
      final player = _player(config);
      player.play();
      async.flushMicrotasks();
      async.elapse(_second * 4);
      expect(player.bpm, 90);
      player.config = config.copyWith(bpm: 120);
      expect(player.bpm, 120);
      // On the second beat, with the third up next, which a two-beat measure doesn't have.
      async.elapse(const Duration(milliseconds: 500));
      expect(player.beat, 1);
      player.config = config.copyWith(bpm: 120).withBeatCount(2);
      async.elapse(const Duration(milliseconds: 500));
      expect(player.beat, 0);
      player.dispose();
    });
  });

  group('practice log', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await practiceLog.load();
    });

    test('a minute or more of playing is logged on leaving it', () {
      fakeAsync((async) {
        final player = _player(const MetronomeConfig(bpm: 90));
        player.play();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 61));
        player.dispose();
        final entry = practiceLog.entries.single;
        expect(entry.drillId, metronomeId);
        expect(entry.title, isNull);
        expect(entry.config.bpm, 90);
        expect(entry.seconds, 61);
      });
    });

    test("less than a minute isn't", () {
      fakeAsync((async) {
        final player = _player(const MetronomeConfig());
        player.play();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 59));
        player.dispose();
        expect(practiceLog.entries, isEmpty);
      });
    });

    test("time paused doesn't count, but playing either side of a pause adds up", () {
      fakeAsync((async) {
        final player = _player(const MetronomeConfig())..practiceName = 'Warm up';
        player.play();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 40));
        player.pause();
        async.elapse(const Duration(minutes: 5));
        player.play();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));
        player.dispose();
        final entry = practiceLog.entries.single;
        expect(entry.title, 'Warm up');
        expect(entry.seconds, 70);
      });
    });

    test('a titled entry survives being saved and loaded', () {
      final entry = PracticeLogEntry.fromJson(
        PracticeLogEntry(
          completedAt: DateTime.utc(2026, 10, 23),
          drillId: metronomeId,
          config: const DrillConfig(bpm: 120),
          seconds: 90,
          title: 'Fast',
        ).toJson(),
      );
      expect(entry.title, 'Fast');
      expect(entry.config.bpm, 120);
    });
  });

  group('config', () {
    test('a tap on a beat goes high, low, off, and back to high', () {
      var c = const MetronomeConfig(beats: [_hi, _lo]);
      c = c.withBeatToggled(0);
      expect(c.beats, [_lo, _lo]);
      c = c.withBeatToggled(0);
      expect(c.beats, [_off, _lo]);
      c = c.withBeatToggled(0);
      expect(c.beats, [_hi, _lo]);
    });

    test('a longer measure adds low beats, and a shorter one drops beats off the end', () {
      const c = MetronomeConfig(beats: [_hi, _off, _lo]);
      expect(c.withBeatCount(5).beats, [_hi, _off, _lo, _lo, _lo]);
      expect(c.withBeatCount(2).beats, [_hi, _off]);
    });

    test('survives being saved and loaded', () {
      const c = MetronomeConfig(
        bpm: 72,
        beats: [_hi, _off, _lo],
        note: NoteValue.triplet,
        bpmIncrease: 3,
        increaseEvery: 8,
      );
      expect(MetronomeConfig.fromJson(c.toJson()), c);
      expect(MetronomeConfig.fromJson(c.toJson()).hashCode, c.hashCode);
      expect(c == c.copyWith(bpm: 73), isFalse);
      expect(c == c.copyWith(note: NoteValue.eighth), isFalse);
      // Saved before there were notes: quarters.
      expect(MetronomeConfig.fromJson(c.toJson()..remove('note')).note, NoteValue.quarter);
    });
  });
}
