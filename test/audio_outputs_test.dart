import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/state/audio_outputs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AudioOutputs> loaded() async {
    final outputs = AudioOutputs();
    await outputs.load();
    return outputs;
  }

  // (Tests run as a phone would, not on web, where it's "This computer".)
  test('starts with one output, the device itself, in use', () async {
    final outputs = await loaded();
    expect(outputs.all.map((o) => o.name), ['This device']);
    expect(outputs.current.name, 'This device');
  });

  test('uses an output once added, and remembers it', () async {
    final outputs = await loaded();
    final airpods = outputs.add('AirPods');
    expect(outputs.current.id, airpods.id);
    final reloaded = await loaded();
    expect(reloaded.all.map((o) => o.name), ['This device', 'AirPods']);
    expect(reloaded.current.name, 'AirPods');
  });

  test('selects and renames outputs', () async {
    final outputs = await loaded();
    final tv = outputs.add('TV');
    outputs.select('default');
    expect(outputs.current.id, 'default');
    outputs.rename(tv.id, 'Living room TV');
    expect(outputs.byId(tv.id)?.name, 'Living room TV');
    expect((await loaded()).byId(tv.id)?.name, 'Living room TV');
  });

  test('deleting the output in use uses the first one left, and never deletes the last', () async {
    final outputs = await loaded();
    final tv = outputs.add('TV');
    outputs.delete(tv.id);
    expect(outputs.all.map((o) => o.name), ['This device']);
    expect(outputs.current.id, 'default');
    outputs.delete('default');
    expect(outputs.all, hasLength(1));
  });

  test('calls the built-in output saved as "This computer" on a phone "This device"', () async {
    SharedPreferences.setMockInitialValues({
      'audio.outputs':
          '{"outputs": [{"id": "default", "name": "This computer"}, {"id": "o1", "name": "TV"}], '
          '"current": "o1"}',
    });
    final outputs = await loaded();
    expect(outputs.all.map((o) => o.name), ['This device', 'TV']);
    expect(outputs.current.name, 'TV');
    // But not if it's been renamed.
    outputs.rename('default', 'My phone');
    expect((await loaded()).byId('default')?.name, 'My phone');
  });
}
