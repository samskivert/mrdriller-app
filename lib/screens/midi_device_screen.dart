import 'dart:async';

import 'package:flutter/material.dart';

import '../services/midi_connection.dart';
import '../services/midi_input.dart';
import '../model/grading.dart';
import '../state/audio_outputs.dart';
import '../state/midi_devices.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import '../widgets/mic_calibration_card.dart';
import '../widgets/midi_timing_test.dart';

/// Sets up a MIDI device (a drum pad): what it's called, which hand each of its pads is for, and
/// a test of hitting in time with them.
class MidiDeviceScreen extends StatefulWidget {
  final String deviceKey;

  const MidiDeviceScreen({super.key, required this.deviceKey});

  @override
  State<MidiDeviceScreen> createState() => _MidiDeviceScreenState();
}

class _MidiDeviceScreenState extends State<MidiDeviceScreen> {
  StreamSubscription<MidiMessage>? _subscription;
  // The device's pads' hits, and just its mapped pads', for the timing test.
  late final Stream<MidiMessage> _notes;
  late final Stream<MidiMessage> _hits;
  // What's been hit since the screen opened, by note, and the latest hits' velocities.
  final _seen = <int, _Seen>{};
  static const _velocitiesKept = 40;
  final _velocities = <int>[];

  String get _key => widget.deviceKey;

  bool _isFromDevice(MidiMessage message) {
    final port = midi.portById(message.portId);
    return port != null && midiDeviceKey(port) == _key;
  }

  @override
  void initState() {
    super.initState();
    final notes = _notes = midi.messages.where((m) => m.isNoteOn && _isFromDevice(m));
    _subscription = notes.listen((message) {
      setState(() {
        final seen = _seen.putIfAbsent(message.note, _Seen.new);
        seen.hits++;
        seen.velocity = message.velocity;
        _velocities.add(message.velocity);
        if (_velocities.length > _velocitiesKept) _velocities.removeAt(0);
      });
    });
    _hits = notes.where((m) {
      final role = midiDevices.roleOf(_key, m.note);
      return role == PadRole.right || role == PadRole.left;
    });
    midi.connect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _rename() async {
    final name = await promptForName(
      context,
      title: 'Rename device',
      initial: midiDevices.nameOf(_key),
      confirmLabel: 'RENAME',
    );
    if (name != null) midiDevices.rename(_key, name);
  }

  Future<void> _forget() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Forget device',
      message: "Forget ${midiDevices.nameOf(_key)}'s name and pads?",
    );
    if (!confirmed || !mounted) return;
    midiDevices.forget(_key);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([midi, midiDevices, audioOutputs]),
      builder: (context, _) => CreamScreen(
        title: midiDevices.nameOf(_key),
        actions: [RoundIconButton(icon: Icons.edit_rounded, tooltip: 'Rename', onPressed: _rename)],
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusCard(),
                  const SizedBox(height: 16),
                  _padsCard(),
                  const SizedBox(height: 16),
                  _accentsCard(),
                  const SizedBox(height: 16),
                  _calibrationCard(),
                  const SizedBox(height: 16),
                  _micCalibration(),
                  const SizedBox(height: 16),
                  _timingTest(),
                  if (midiDevices.byKey(_key) != null) ...[
                    const SizedBox(height: 24),
                    CandyButton(
                      label: 'FORGET DEVICE',
                      icon: Icons.delete_rounded,
                      colors: AppColors.candyRed,
                      onPressed: _forget,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final connected = midi.ports.any((p) => p.connected && midiDeviceKey(p) == _key);
    final String status;
    if (midi.status == MidiStatus.connected) {
      status = connected ? 'Connected' : 'Not connected';
    } else {
      status = midi.error ?? 'Connecting to MIDI...';
    }
    return BannerCard(
      label: 'Device',
      color: AppColors.bannerBlue,
      child: Row(
        children: [
          ConnectionDot(connected: connected),
          const SizedBox(width: 10),
          Expanded(child: Text(status, style: midiTextStyle(strong: true))),
          if (midiDevices.nameOf(_key) != _key)
            Flexible(
              child: Text(_key, style: midiTextStyle(), textAlign: TextAlign.end),
            ),
        ],
      ),
    );
  }

  Widget _micCalibration() {
    return MicCalibrationCard(
      // Any of the device's pads will do, mapped or not.
      hits: _notes,
      now: midi.now,
      onSave: (measurement) {
        final stats = measurement.stats;
        midiDevices.setCalibration(
          _key,
          audioOutputs.current.id,
          Calibration(
            offsetMs: stats.mean,
            spreadMs: stats.spread,
            hits: stats.count,
            bpm: 60,
            measured: DateTime.now(),
            source: CalibrationSource.microphone,
          ),
        );
      },
    );
  }

  Widget _timingTest() {
    final output = audioOutputs.current;
    return MidiTimingTest(
      hits: _hits,
      now: midi.now,
      calibrationMs: midiDevices.calibrationOf(_key, output.id)?.offsetMs,
      calibrationLabel: output.name,
      onSave: (hits, bpm) => midiDevices.setCalibration(
        _key,
        output.id,
        Calibration(
          offsetMs: hits.mean,
          spreadMs: hits.spread,
          hits: hits.count,
          bpm: bpm,
          measured: DateTime.now(),
        ),
      ),
    );
  }

  Widget _calibrationCard() {
    final current = audioOutputs.current;
    return BannerCard(
      label: 'Calibration',
      color: AppColors.bannerOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sound takes longer to reach you through some speakers and headphones than others, '
            'so hits are adjusted by the calibration for the audio output in use. To calibrate '
            'for it, play the timing test below and save the result. Tap an output to use it.',
            style: midiTextStyle(),
          ),
          const SizedBox(height: 4),
          for (final output in audioOutputs.all)
            _calibrationRow(output, inUse: output.id == current.id),
        ],
      ),
    );
  }

  Widget _calibrationRow(AudioOutput output, {required bool inUse}) {
    final calibration = midiDevices.calibrationOf(_key, output.id);
    return InkWell(
      onTap: () => audioOutputs.select(output.id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              inUse ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: inUse ? AppColors.bannerOrange : AppColors.inkMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inUse ? '${output.name} (in use)' : output.name,
                    style: midiTextStyle(strong: true),
                  ),
                  Text(
                    calibration == null ? 'Not calibrated' : describeCalibration(calibration),
                    style: midiTextStyle(),
                  ),
                ],
              ),
            ),
            if (calibration != null)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.inkMuted,
                tooltip: 'Clear calibration',
                onPressed: () => midiDevices.setCalibration(_key, output.id, null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _accentsCard() {
    final threshold = midiDevices.accentVelocityOf(_key);
    final suggested = accentVelocityFor(_velocities);
    return BannerCard(
      label: 'Accents',
      color: AppColors.bannerRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            threshold == null
                ? "Accents aren't graded yet. Play a mix of soft and loud hits, then set the "
                      'accent velocity from them, or drag it.'
                : 'Hits at or above the accent velocity count as accents. Play a mix of soft and '
                      'loud hits to check, or set it again from them.',
            style: midiTextStyle(),
          ),
          const SizedBox(height: 12),
          _VelocityStrip(velocities: _velocities, threshold: threshold),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: (threshold ?? 64).toDouble(),
                  min: 1,
                  max: 127,
                  divisions: 126,
                  activeColor: threshold == null ? AppColors.candyGray.base : AppColors.bannerRed,
                  onChanged: (v) => midiDevices.setAccentVelocity(_key, v.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  threshold == null ? 'off' : '$threshold',
                  textAlign: TextAlign.end,
                  style: midiTextStyle(strong: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: CandyButton(
                  label: 'SET FROM MY HITS',
                  icon: Icons.auto_fix_high_rounded,
                  colors: AppColors.candyGreen,
                  onPressed: suggested == null
                      ? null
                      : () => midiDevices.setAccentVelocity(_key, suggested),
                ),
              ),
              if (threshold != null) ...[
                const SizedBox(width: 10),
                CandyButton(
                  label: 'OFF',
                  icon: Icons.block_rounded,
                  colors: AppColors.candyGray,
                  onPressed: () => midiDevices.setAccentVelocity(_key, null),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _padsCard() {
    final mapped = midiDevices.byKey(_key)?.pads ?? const {};
    final notes = {..._seen.keys, ...mapped.keys}.toList()..sort();
    return BannerCard(
      label: 'Pads',
      color: AppColors.bannerMagenta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hit each pad, then choose which hand it counts as. Ignored pads (and any not set) '
            "don't count as hits.",
            style: midiTextStyle(),
          ),
          for (final note in notes) ...[
            const Divider(height: 24, thickness: 2, color: AppColors.creamShadow),
            _PadRow(
              note: note,
              role: mapped[note],
              seen: _seen[note],
              onChanged: (role) => midiDevices.setRole(_key, note, role),
            ),
          ],
        ],
      ),
    );
  }
}

/// The latest hits' [velocities] as dots along the range of velocities (1 to 127), the newest
/// biggest, and gold if accented (at or above the [threshold], if there is one), with the
/// threshold marked.
class _VelocityStrip extends StatelessWidget {
  final List<int> velocities;
  final int? threshold;

  const _VelocityStrip({required this.velocities, required this.threshold});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
        border: Border.all(color: AppColors.panelBorder, width: 2),
      ),
      child: CustomPaint(painter: _VelocityStripPainter([...velocities], threshold)),
    );
  }
}

class _VelocityStripPainter extends CustomPainter {
  final List<int> velocities;
  final int? threshold;

  _VelocityStripPainter(this.velocities, this.threshold);

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 12.0;
    double x(num velocity) => margin + (size.width - margin * 2) * (velocity - 1) / 126;
    final mid = size.height / 2;
    final line = Paint()
      ..color = AppColors.panelBorder
      ..strokeWidth = 2;
    canvas.drawLine(Offset(margin, mid), Offset(size.width - margin, mid), line);
    final threshold = this.threshold;
    if (threshold != null) {
      canvas.drawLine(
        Offset(x(threshold), 5),
        Offset(x(threshold), size.height - 5),
        Paint()
          ..color = AppColors.candyRed.base
          ..strokeWidth = 2,
      );
    }
    for (final (i, velocity) in velocities.indexed) {
      final newest = i == velocities.length - 1;
      final age = (velocities.length - 1 - i) / (velocities.length > 1 ? velocities.length - 1 : 1);
      final accented = threshold != null && velocity >= threshold;
      final color = accented ? AppColors.gold : AppColors.cream;
      canvas.drawCircle(
        Offset(x(velocity), mid),
        newest ? 7 : 4.5,
        Paint()..color = color.withValues(alpha: newest ? 1 : 0.85 - 0.6 * age),
      );
    }
  }

  @override
  bool shouldRepaint(_VelocityStripPainter old) =>
      old.velocities != velocities || old.threshold != threshold;
}

class _Seen {
  int hits = 0;
  int velocity = 0;
}

class _PadRow extends StatelessWidget {
  final int note;
  final PadRole? role;
  final _Seen? seen;
  final ValueChanged<PadRole?> onChanged;

  const _PadRow({
    required this.note,
    required this.role,
    required this.seen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final seen = this.seen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _NoteBadge(note: note, role: role, hits: seen?.hits ?? 0),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Note $note (${midiNoteName(note)})', style: midiTextStyle(strong: true)),
            ),
            Text(
              seen == null ? 'not hit yet' : 'velocity ${seen.velocity}',
              style: midiTextStyle(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CandySegmented<PadRole?>(
          options: [for (final role in PadRole.values) (role, role.label)],
          value: role,
          // Tapping the role it already has unsets it.
          onChanged: (picked) => onChanged(picked == role ? null : picked),
          colors: switch (role) {
            PadRole.right => AppColors.candyBlue,
            PadRole.left => AppColors.candyOrange,
            _ => AppColors.candyGray,
          },
        ),
      ],
    );
  }
}

/// A candy block for a pad, colored for the hand it's for (as strokes are), that flashes each
/// time it's hit ([hits] changes).
class _NoteBadge extends StatefulWidget {
  final int note;
  final PadRole? role;
  final int hits;

  const _NoteBadge({required this.note, required this.role, required this.hits});

  @override
  State<_NoteBadge> createState() => _NoteBadgeState();
}

class _NoteBadgeState extends State<_NoteBadge> with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );

  @override
  void didUpdateWidget(_NoteBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hits != oldWidget.hits) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candy = switch (widget.role) {
      PadRole.right => AppColors.candyBlue,
      PadRole.left => AppColors.candyOrange,
      _ => AppColors.candyGray,
    };
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, child) {
          final glow = 1 - Curves.easeOut.transform(_flash.value);
          return Transform.scale(
            scale: 1 + 0.12 * glow,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.lerp(candy.base, candy.icing, glow),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: candy.outline, width: 2),
                boxShadow: [BoxShadow(color: candy.lo, offset: const Offset(0, 3))],
              ),
              child: child,
            ),
          );
        },
        child: OutlinedText(
          switch (widget.role) {
            PadRole.right => 'R',
            PadRole.left => 'L',
            _ => '?',
          },
          style: const TextStyle(fontFamily: AppFonts.display, fontSize: 20, height: 1),
          color: Colors.white,
          outline: candy.outline,
        ),
      ),
    );
  }
}

/// A green dot if [connected], else gray.
class ConnectionDot extends StatelessWidget {
  final bool connected;

  const ConnectionDot({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? AppColors.candyGreen.base : AppColors.candyGray.base,
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A calibration in a line, e.g. "12.3ms late (spread 9.8ms, 40 hits at 120 bpm, 6 Nov)".
String describeCalibration(Calibration c) {
  final offset = c.offsetMs < 0
      ? '${(-c.offsetMs).toStringAsFixed(1)}ms early'
      : '${c.offsetMs.toStringAsFixed(1)}ms late';
  final date = '${c.measured.day} ${_months[c.measured.month - 1]}';
  final how = switch (c.source) {
    CalibrationSource.playing => 'by playing',
    CalibrationSource.microphone => 'by microphone',
  };
  return '$offset $how (spread ${c.spreadMs.toStringAsFixed(1)}ms, ${c.hits} hits at ${c.bpm} '
      'bpm, $date)';
}

const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// A MIDI note's name, with middle C (60) as C4.
String midiNoteName(int note) => '${_noteNames[note % 12]}${note ~/ 12 - 1}';

/// The body text style of the MIDI screens.
TextStyle midiTextStyle({bool strong = false}) => TextStyle(
  fontFamily: AppFonts.body,
  fontSize: 14,
  height: 1.4,
  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
  color: strong ? AppColors.ink : AppColors.inkMuted,
);
