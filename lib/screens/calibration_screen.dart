import 'package:flutter/material.dart';

import '../services/midi_connection.dart';
import '../services/midi_input.dart';
import '../state/audio_outputs.dart';
import '../state/midi_devices.dart';
import '../util/colors.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/mic_calibration_card.dart';
import '../widgets/midi_timing_test.dart';
import 'midi_device_screen.dart';

/// The ways a drum pad can be calibrated, both with the microphone, so that only the delays are
/// measured, not the player's own habit of hitting early or late.
enum CalibrationMethod {
  /// Playing along with clicks, while the microphone hears the hits against them (see
  /// ear_check.dart).
  playAlong('Play along'),

  /// Hitting between clicks, while the microphone hears both (see mic_calibration.dart).
  betweenClicks('Between clicks');

  final String title;

  const CalibrationMethod(this.title);
}

/// Calibrates a MIDI device for the audio output in use, by one [method], with instructions.
class CalibrationScreen extends StatefulWidget {
  final String deviceKey;
  final CalibrationMethod method;

  const CalibrationScreen({super.key, required this.deviceKey, required this.method});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  // Hits on any of the device's pads, mapped or not.
  late final Stream<MidiMessage> _notes = midi.messages.where((m) {
    final port = midi.portById(m.portId);
    return m.isNoteOn && port != null && midiDeviceKey(port) == widget.deviceKey;
  });

  // Whether the instructions are shown in full (which they're not once a calibration starts, to
  // leave room for it).
  var _instructionsOpen = true;

  @override
  void initState() {
    super.initState();
    midi.connect();
  }

  void _started() {
    if (_instructionsOpen) setState(() => _instructionsOpen = false);
  }

  void _save(double offsetMs, double spreadMs, int hits, int bpm, CalibrationSource source) {
    midiDevices.setCalibration(
      widget.deviceKey,
      audioOutputs.current.id,
      Calibration(
        offsetMs: offsetMs,
        spreadMs: spreadMs,
        hits: hits,
        bpm: bpm,
        measured: DateTime.now(),
        source: source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: widget.method.title,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _instructions(),
                const SizedBox(height: 16),
                switch (widget.method) {
                  CalibrationMethod.playAlong => MidiTimingTest(
                    hits: _notes,
                    now: midi.now,
                    listen: true,
                    onStarted: _started,
                    header: _status(),
                    onSave: (delay, bpm) => _save(
                      delay.mean,
                      delay.spread,
                      delay.count,
                      bpm,
                      CalibrationSource.inTheAir,
                    ),
                  ),
                  CalibrationMethod.betweenClicks => MicCalibrationCard(
                    hits: _notes,
                    now: midi.now,
                    onStarted: _started,
                    header: _status(),
                    onSave: (measurement) => _save(
                      measurement.stats.mean,
                      measurement.stats.spread,
                      measurement.stats.count,
                      60,
                      CalibrationSource.microphone,
                    ),
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _instructions() {
    final (steps, how) = switch (widget.method) {
      CalibrationMethod.playAlong => (
        [
          "Use speakers, or headphones held right up to the computer's microphone, as it has to "
              'hear the clicks. Put the pad near the microphone, and play it with sticks.',
          'Press START, and listen to the first row of clicks (four beats) without playing.',
          'Then play every click, 64 hits (eight rows), checked off as they go. It stops by '
              'itself after the last one: then SAVE CALIBRATION.',
        ],
        'The microphone hears where your hits land against the clicks, and compares that with '
            'when they came in from the pad, so your own timing cancels out. You see how far '
            'ahead of or behind the clicks you play, too.',
      ),
      CalibrationMethod.betweenClicks => (
        [
          "Use speakers, not headphones, as the computer's microphone has to hear the clicks. "
              'Put the pad near the microphone, and play it with sticks.',
          'Press START. A click plays every second.',
          'Hit the pad once between each pair of clicks, about halfway, never on a click. It '
              'stops after 12 hits. Then SAVE CALIBRATION.',
        ],
        'The microphone hears each click and each hit, and how far apart they sound is compared '
            'with how far apart they were sent and came in, so your own timing doesn\'t come into '
            'it. Use this one if Play along doesn\'t work out.',
      ),
    };
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: BannerCard(
        label: 'How to',
        color: AppColors.bannerOrange,
        onTap: () => setState(() => _instructionsOpen = !_instructionsOpen),
        trailing: Icon(
          _instructionsOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          color: AppColors.inkMuted,
          semanticLabel: _instructionsOpen ? 'Hide instructions' : 'Show instructions',
        ),
        child: _instructionsOpen ? _steps(steps, how) : null,
      ),
    );
  }

  // Which output it's calibrating for, and its calibration so far.
  Widget _status() {
    return ListenableBuilder(
      listenable: Listenable.merge([midiDevices, audioOutputs]),
      builder: (context, _) {
        final output = audioOutputs.current;
        final calibration = midiDevices.calibrationOf(widget.deviceKey, output.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Calibrating for ${output.name}', style: midiTextStyle(strong: true)),
            Text(
              calibration == null
                  ? 'Not calibrated yet.'
                  : 'Current: ${describeCalibration(calibration)}',
              style: midiTextStyle(),
            ),
          ],
        );
      },
    );
  }

  Widget _steps(List<String> steps, String how) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 24, child: Text('${i + 1}.', style: midiTextStyle(strong: true))),
                Expanded(child: Text(step, style: midiTextStyle())),
              ],
            ),
          ),
        Text(how, style: midiTextStyle()),
      ],
    );
  }
}
