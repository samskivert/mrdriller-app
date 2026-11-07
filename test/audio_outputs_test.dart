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

  test('starts with one output, in use', () async {
    final outputs = await loaded();
    expect(outputs.all.map((o) => o.name), ['This computer']);
    expect(outputs.current.name, 'This computer');
  });

  test('uses an output once added, and remembers it', () async {
    final outputs = await loaded();
    final airpods = outputs.add('AirPods');
    expect(outputs.current.id, airpods.id);
    final reloaded = await loaded();
    expect(reloaded.all.map((o) => o.name), ['This computer', 'AirPods']);
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
    expect(outputs.all.map((o) => o.name), ['This computer']);
    expect(outputs.current.id, 'default');
    outputs.delete('default');
    expect(outputs.all, hasLength(1));
  });
}
