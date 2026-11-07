import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/midi_input.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';

/// A diagnostic tool for MIDI input: lists the MIDI inputs, lights up a block for each note as
/// it's hit, and logs every message with its timestamps, to check that a drum pad is hooked up and
/// to see how much delay there is between a hit arriving and the app hearing about it.
class MidiDiagnosticsScreen extends StatefulWidget {
  const MidiDiagnosticsScreen({super.key});

  @override
  State<MidiDiagnosticsScreen> createState() => _MidiDiagnosticsScreenState();
}

class _MidiDiagnosticsScreenState extends State<MidiDiagnosticsScreen> {
  static const _maxLogEntries = 200;
  // How many recent messages the lag stats cover.
  static const _lagWindow = 100;

  MidiInput? _midi;
  bool _connecting = false;
  String? _error;
  final _subscriptions = <StreamSubscription<Object?>>[];

  List<MidiPort> _ports = const [];
  final _portMessages = <String, int>{};
  final _pads = <int, _Pad>{};
  // Newest first.
  final _log = <_LogEntry>[];
  final _lags = <double>[];
  double? _lastNoteOnAt;

  @override
  void initState() {
    super.initState();
    // Off the web there's nothing to connect to; on the web, ask right away (Chrome prompts the
    // first time, then remembers).
    if (MidiInput.isSupported) _connect();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _midi?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final midi = await MidiInput.open();
      if (!mounted) {
        midi.close();
        return;
      }
      _subscriptions
        ..add(midi.onPortsChanged.listen((ports) => setState(() => _ports = ports)))
        ..add(midi.messages.listen(_onMessage));
      setState(() {
        _midi = midi;
        _ports = midi.ports;
      });
    } on MidiUnavailable catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _onMessage(MidiMessage message) {
    setState(() {
      _portMessages.update(message.portId, (n) => n + 1, ifAbsent: () => 1);
      _lags.add(message.receivedAt - message.timestamp);
      if (_lags.length > _lagWindow) _lags.removeAt(0);

      double? sinceLastHit;
      if (message.isNoteOn) {
        final last = _lastNoteOnAt;
        if (last != null) sinceLastHit = message.timestamp - last;
        _lastNoteOnAt = message.timestamp;
        final pad = _pads.putIfAbsent(message.note, () => _Pad(message.note));
        pad.hits++;
        pad.lastVelocity = message.velocity;
        pad.channel = message.channel;
      }
      _log.insert(0, _LogEntry(message, sinceLastHit));
      if (_log.length > _maxLogEntries) _log.removeLast();
    });
  }

  void _clear() {
    setState(() {
      _portMessages.clear();
      _pads.clear();
      _log.clear();
      _lags.clear();
      _lastNoteOnAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: 'MIDI Diagnostics',
      actions: [
        if (_midi != null)
          RoundIconButton(icon: Icons.delete_sweep_rounded, tooltip: 'Clear', onPressed: _clear),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _midi == null ? _disconnected() : _connected(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _disconnected() {
    if (!MidiInput.isSupported) {
      return const [
        EmptyCard(
          'MIDI input only works in the web version for now, in a browser that supports it '
          '(Chrome, Edge or Firefox).',
        ),
      ];
    }
    return [
      BannerCard(
        label: 'MIDI access',
        color: AppColors.bannerOrange,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Body(
              _error ??
                  (_connecting
                      ? 'Asking the browser for MIDI access...'
                      : 'Connect to see your MIDI devices.'),
            ),
            const SizedBox(height: 12),
            CandyButton(
              label: _error == null ? 'CONNECT' : 'TRY AGAIN',
              icon: Icons.cable_rounded,
              colors: AppColors.candyGreen,
              onPressed: _connecting ? null : _connect,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _connected() {
    final pads = _pads.values.toList()..sort((a, b) => a.note.compareTo(b.note));
    return [
      BannerCard(
        label: 'Inputs',
        color: AppColors.bannerBlue,
        child: _ports.isEmpty
            ? const _Body('No MIDI inputs. Plug in your pad or MIDI cable; it should show up here.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final port in _ports) _portRow(port)],
              ),
      ),
      const SizedBox(height: 16),
      BannerCard(
        label: 'Pads',
        color: AppColors.bannerMagenta,
        child: pads.isEmpty
            ? const _Body('Hit a pad. Each note that comes in gets a block here.')
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // So that a tile's flash repaints only the tile.
                  for (final pad in pads)
                    RepaintBoundary(
                      child: _PadTile(pad: pad, hits: pad.hits),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      BannerCard(
        label: 'Messages',
        color: AppColors.bannerGreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Body(_lagSummary()),
            const SizedBox(height: 10),
            const _LogRow.header(),
            // Lazy and fixed-height, so that each message rebuilds and repaints only the visible
            // rows, and the page around it doesn't repaint with it. Rendering the whole log on every
            // message delayed later messages more and more as the log grew.
            RepaintBoundary(
              child: SizedBox(
                height: 360,
                child: ListView.builder(
                  itemCount: _log.length,
                  itemExtent: _LogRow.height,
                  itemBuilder: (context, i) => _LogRow(_log[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _portRow(MidiPort port) {
    final count = _portMessages[port.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: port.connected ? AppColors.candyGreen.base : AppColors.candyGray.base,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [port.name, if (port.manufacturer.isNotEmpty) port.manufacturer].join(' - '),
              style: _bodyStyle.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            port.connected ? '$count message${count == 1 ? '' : 's'}' : 'disconnected',
            style: _bodyStyle,
          ),
        ],
      ),
    );
  }

  String _lagSummary() {
    if (_lags.isEmpty) {
      return 'Lag is how long a message waited between arriving from the device and reaching '
          'the app.';
    }
    final average = _lags.reduce((a, b) => a + b) / _lags.length;
    final worst = _lags.reduce(math.max);
    return 'Lag over the last ${_lags.length}: average ${_ms(average)}, worst ${_ms(worst)}.';
  }
}

String _ms(double ms) => '${ms.toStringAsFixed(1)}ms';

const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// A note's name, with middle C (60) as C4.
String _noteName(int note) => '${_noteNames[note % 12]}${note ~/ 12 - 1}';

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontSize: 14,
  height: 1.4,
  fontWeight: FontWeight.w500,
  color: AppColors.inkMuted,
);

class _Body extends StatelessWidget {
  final String text;

  const _Body(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: _bodyStyle);
}

/// A note that's been hit, and what's been seen of it.
class _Pad {
  final int note;
  int hits = 0;
  int lastVelocity = 0;
  int channel = 1;

  _Pad(this.note);
}

/// A candy block for a [_Pad] that flashes each time it's hit ([hits] changes), brighter the
/// harder the hit.
class _PadTile extends StatefulWidget {
  final _Pad pad;
  final int hits;

  const _PadTile({required this.pad, required this.hits});

  @override
  State<_PadTile> createState() => _PadTileState();
}

class _PadTileState extends State<_PadTile> with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    _flash.forward(from: 0);
  }

  @override
  void didUpdateWidget(_PadTile oldWidget) {
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
    final pad = widget.pad;
    final candy = AppColors.candyPink;
    final strength = 0.35 + 0.65 * pad.lastVelocity / 127;
    return AnimatedBuilder(
      animation: _flash,
      builder: (context, child) {
        final glow = (1 - Curves.easeOut.transform(_flash.value)) * strength;
        return Transform.scale(
          scale: 1 + 0.08 * glow,
          child: Container(
            width: 104,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Color.lerp(candy.base, candy.icing, glow),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: candy.outline, width: 2),
              boxShadow: [
                BoxShadow(color: candy.lo, offset: const Offset(0, 3)),
                if (glow > 0) BoxShadow(color: candy.hi.withValues(alpha: glow), blurRadius: 16),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          OutlinedText(
            _noteName(pad.note),
            style: const TextStyle(fontFamily: AppFonts.display, fontSize: 22, height: 1.1),
            color: Colors.white,
            outline: candy.outline,
          ),
          const SizedBox(height: 4),
          Text(
            'note ${pad.note}  ch ${pad.channel}\n'
            '${pad.hits} hit${pad.hits == 1 ? '' : 's'}  vel ${pad.lastVelocity}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: candy.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry {
  final MidiMessage message;

  // Milliseconds since the previous note on, if this is one and there was one.
  final double? sinceLastHit;

  _LogEntry(this.message, this.sinceLastHit);
}

/// One row of the message log (or its [header]), in fixed-width columns.
class _LogRow extends StatelessWidget {
  final _LogEntry? entry;

  const _LogRow(_LogEntry this.entry);

  const _LogRow.header() : entry = null;

  static const height = 18.0;
  static const _flex = [5, 5, 2, 4, 2, 4, 3];

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final cells = entry == null
        ? const ['Time', 'Type', 'Ch', 'Note', 'Vel', 'Gap', 'Lag']
        : _cells(entry);
    final style = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 12,
      height: 1.5,
      fontWeight: entry == null ? FontWeight.w900 : FontWeight.w600,
      color: entry == null ? AppColors.inkMuted : AppColors.ink,
    );
    return Container(
      decoration: entry == null
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.creamShadow, width: 2)),
            )
          : null,
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(cells[i], style: style, maxLines: 1, overflow: TextOverflow.clip),
            ),
        ],
      ),
    );
  }

  static List<String> _cells(_LogEntry entry) {
    final m = entry.message;
    final time = '${(m.timestamp / 1000).toStringAsFixed(3)}s';
    final lag = _ms(m.receivedAt - m.timestamp);
    final gap = entry.sinceLastHit == null ? '' : _ms(entry.sinceLastHit!);
    if (m.isNoteOn || m.isNoteOff) {
      return [
        time,
        m.isNoteOn ? 'Note on' : 'Note off',
        '${m.channel}',
        '${m.note} ${_noteName(m.note)}',
        '${m.velocity}',
        gap,
        lag,
      ];
    }
    final type = switch (m.command) {
      0xA0 => 'Aftertouch',
      0xB0 => 'CC ${m.data1}',
      0xC0 => 'Program',
      0xD0 => 'Pressure',
      0xE0 => 'Pitch bend',
      _ => m.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
    };
    final isChannelMessage = m.status >= 0x80 && m.status < 0xF0;
    return [
      time,
      type,
      isChannelMessage ? '${m.channel}' : '',
      '',
      m.command == 0xB0 ? '${m.data2}' : '',
      '',
      lag,
    ];
  }
}
