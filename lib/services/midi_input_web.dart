import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'midi_input.dart';

// Safari has no Web MIDI.
bool get isSupported => web.window.navigator.has('requestMIDIAccess');

Future<MidiInput> open() async {
  if (!isSupported) {
    throw const MidiUnavailable(
      "This browser doesn't support MIDI. Try Chrome, Edge or Firefox (not Safari).",
    );
  }
  // A hot restart reloads the Dart code without disposing of the old screen, which would leave its
  // handlers attached, and every message would first go to dead code (slowly failing in a debug
  // build) before reaching ours. So whatever's open closes itself when the next one opens.
  final closePrevious = globalContext.getProperty<JSFunction?>(_closeKey.toJS);
  try {
    closePrevious?.callAsFunction();
  } catch (_) {
    // It's the previous run's code; if it can't clean up, we carry on regardless.
  }
  final web.MIDIAccess access;
  try {
    access = await web.window.navigator.requestMIDIAccess().toDart;
  } catch (e) {
    throw MidiUnavailable('The browser refused MIDI access: $e');
  }
  final input = _WebMidiInput(access);
  globalContext.setProperty(_closeKey.toJS, input.close.toJS);
  return input;
}

// Where the open input leaves a function to close it, outlasting a hot restart.
const _closeKey = '_dokodokoCloseMidiInput';

// package:web leaves MIDIInputMap's (maplike) methods out.
extension on web.MIDIInputMap {
  external void forEach(JSFunction callback);
}

class _WebMidiInput implements MidiInput {
  final web.MIDIAccess _access;
  final _messages = StreamController<MidiMessage>.broadcast();
  final _portsChanged = StreamController<List<MidiPort>>.broadcast();
  final _inputs = <String, web.MIDIInput>{};
  // One handler per input, kept so that reassigning it on every refresh is harmless.
  final _handlers = <String, JSFunction>{};
  List<MidiPort> _ports = const [];

  _WebMidiInput(this._access) {
    _access.onstatechange = ((web.Event _) => _refresh(notify: true)).toJS;
    _refresh(notify: false);
  }

  @override
  List<MidiPort> get ports => _ports;

  @override
  Stream<List<MidiPort>> get onPortsChanged => _portsChanged.stream;

  @override
  Stream<MidiMessage> get messages => _messages.stream;

  @override
  double now() => web.window.performance.now();

  void _refresh({required bool notify}) {
    final inputs = <web.MIDIInput>[];
    _access.inputs.forEach(
      ((web.MIDIInput input, JSAny? key, JSAny? map) {
        inputs.add(input);
      }).toJS,
    );
    _inputs.clear();
    final ports = <MidiPort>[];
    for (final input in inputs) {
      final id = input.id;
      _inputs[id] = input;
      // Setting a message handler also opens the port.
      input.onmidimessage = _handlers.putIfAbsent(id, () => _handlerFor(id));
      ports.add(
        MidiPort(
          id: id,
          name: input.name ?? 'Unnamed input',
          manufacturer: input.manufacturer ?? '',
          connected: input.state == 'connected',
        ),
      );
    }
    _ports = List.unmodifiable(ports);
    if (notify && !_portsChanged.isClosed) _portsChanged.add(_ports);
  }

  JSFunction _handlerFor(String portId) {
    return ((web.MIDIMessageEvent event) {
      final receivedAt = web.window.performance.now();
      final data = event.data;
      if (data == null || _messages.isClosed) return;
      _messages.add(
        MidiMessage(
          portId: portId,
          data: Uint8List.fromList(data.toDart),
          // Like performance.now(), relative to the page's time origin.
          timestamp: event.timeStamp.toDouble(),
          receivedAt: receivedAt,
        ),
      );
    }).toJS;
  }

  @override
  void close() {
    if (_messages.isClosed) return;
    _access.onstatechange = null;
    for (final input in _inputs.values) {
      input.onmidimessage = null;
      input.close();
    }
    _inputs.clear();
    _messages.close();
    _portsChanged.close();
  }
}
