// Defines a data model for drills.

enum Hand { L, R }

enum StrokeDir { U, D }

/// Represents a single stroke. Usually this is a strike (up and down), but can be just the down
/// stroke or the up stroke.
class Stroke {
  final Hand hand;
  final bool accent;
  final StrokeDir? dir;

  const Stroke({required this.hand, this.accent = false, this.dir});

  Stroke withHand(Hand newHand) => Stroke(hand: newHand, accent: accent, dir: dir);
}

Stroke hit(Hand hand, [bool accent = false]) => Stroke(hand: hand, accent: accent);
Stroke downStroke(Hand hand, [bool accent = false]) =>
    Stroke(hand: hand, accent: accent, dir: StrokeDir.D);
Stroke upStroke(Hand hand) => Stroke(hand: hand, dir: StrokeDir.U);

final Stroke R = hit(Hand.R, true);
final Stroke r = hit(Hand.R);
final Stroke L = hit(Hand.L, true);
final Stroke l = hit(Hand.L);

final Stroke rd = downStroke(Hand.R);
final Stroke ru = upStroke(Hand.R);
final Stroke ld = downStroke(Hand.L);
final Stroke lu = upStroke(Hand.L);

/// A beat contains everything that happens on a particular beat. Usually this is just a single
/// strike, but some drills break out one hand doing the up stroke on a beat while another does
/// the down stroke on that beat. And a beat can be labeled (which is shown above the strokes).
/// Strokes can be null, which will leave an empty space in the visualization.
class Beat {
  final String? label;
  final List<Stroke?> strokes;

  const Beat({this.label, required this.strokes});
}

Beat beat(List<Stroke?> strokes) => Beat(strokes: strokes);
Beat labeledBeat(String label, List<Stroke?> strokes) => Beat(label: label, strokes: strokes);

/// A measure is some number of beats, to be spaced evenly in time. An element can be null which
/// means nothing is done on that beat.
typedef Measure = List<Beat?>;

/// Creates a simple measure that has a single unlabeled stroke on every beat (or a null for rest).
Measure measure(List<Stroke?> strokes) =>
    strokes.map<Beat?>((s) => s == null ? null : beat([s])).toList();

/// A line is a collection of measures that we try to render on a single horizontal line.
class Line {
  final List<Measure> measures;

  const Line({required this.measures});
}

Line line(List<Measure> measures) => Line(measures: measures);

/// A section is a collection of lines, with an optional label. The lines in a section are
/// rendered in a vertical list, with the label above it, and all surrounded by a box. Sections
/// may be repeated one or more times.
class Section {
  final String? label;
  final List<Line> lines;
  final int repeat;

  const Section({this.label, required this.lines, required this.repeat});
}

Section section(String label, int repeat, List<Line> lines) =>
    Section(label: label, lines: lines, repeat: repeat);

Section oneLineSection(String label, int repeat, List<Measure> measures) =>
    section(label, repeat, [Line(measures: measures)]);

/// A row is a collection of sections that are displayed horizontally in a single row.
typedef DrillRow = List<Section>;

class Drill {
  final String id;
  final String title;
  final int bpm; // beats per measure
  final List<int>? beeps; // beats on which to beep
  final double scale; // scales the quarter note duration (default is 1)
  final bool forceIntro; // always show ichi-ni-so-re (vs only on BPM increase)
  final List<DrillRow> rows;

  const Drill({
    required this.id,
    required this.title,
    required this.bpm,
    this.beeps,
    this.scale = 1,
    this.forceIntro = false,
    required this.rows,
  });
}

class Pos {
  final int row;
  final int section;
  final int line;
  final int measure;
  final int offset;
  final int repeat;

  const Pos({
    required this.row,
    required this.section,
    required this.line,
    required this.measure,
    required this.offset,
    required this.repeat,
  });
}

Hand _swapHand(Hand hand) => hand == Hand.L ? Hand.R : Hand.L;
Stroke? _swapStrokeHands(Stroke? stroke) => stroke?.withHand(_swapHand(stroke.hand));
Beat? _swapBeatHands(Beat? beat) => beat == null
    ? null
    : Beat(label: beat.label, strokes: beat.strokes.map(_swapStrokeHands).toList());
Measure _swapMeasureHands(Measure measure) => measure.map(_swapBeatHands).toList();
Line _swapLineHands(Line line) => Line(measures: line.measures.map(_swapMeasureHands).toList());

/// Swaps the L and R hands in a section.
Section swapSectionHands(Section section) => Section(
  label: section.label,
  lines: section.lines.map(_swapLineHands).toList(),
  repeat: section.repeat,
);

DrillRow _swapRowHands(DrillRow row) => row.map(swapSectionHands).toList();

/// Swaps the L and R hands in a drill.
Drill swapHands(Drill drill) => Drill(
  id: drill.id,
  title: drill.title,
  bpm: drill.bpm,
  beeps: drill.beeps,
  scale: drill.scale,
  forceIntro: drill.forceIntro,
  rows: drill.rows.map(_swapRowHands).toList(),
);

const int maxBpm = 250;

/// Compute the total duration of a drill in seconds.
double computeDrillDuration(
  Drill drill,
  int bpm,
  int bpmIncrease,
  int drillRepeat, {
  bool replayIntroOnBpmIncrease = true,
}) {
  // Count the total beats for one pass through the drill (excluding intro)
  int drillBeats = 0;
  for (final row in drill.rows) {
    for (final section in row) {
      for (int rep = 0; rep < section.repeat; rep++) {
        for (final line in section.lines) {
          for (final measure in line.measures) {
            drillBeats += measure.length;
          }
        }
      }
    }
  }

  final introBeats = drill.bpm * 4;
  final scale = drill.scale;
  double totalSeconds = 0;

  for (int rep = 0; rep < drillRepeat; rep++) {
    final currentBpm = (bpm + bpmIncrease * rep).clamp(0, maxBpm);
    final tickMs = (60 * 1000 / currentBpm / 4) * scale;

    // First repeat always has intro; subsequent repeats have intro if bpmIncrease > 0 (and the
    // setting allows it) or forceIntro
    final hasIntro = rep == 0 || (bpmIncrease > 0 && replayIntroOnBpmIncrease) || drill.forceIntro;
    final beats = drillBeats + (hasIntro ? introBeats : 0);
    totalSeconds += (beats * tickMs) / 1000;
  }

  return totalSeconds;
}

/// Formats a duration in seconds (e.g. from [computeDrillDuration]) as "1m 30s".
String formatDrillDuration(double seconds) {
  final mins = seconds ~/ 60;
  final secs = (seconds % 60).round();
  return '${mins}m ${secs.toString().padLeft(2, '0')}s';
}

/// Formats a bpm and its (optional) planned increase as e.g. "90 bpm" or "90 bpm (+5)".
String formatBpmSummary(int bpm, int bpmIncrease) =>
    '$bpm bpm${bpmIncrease > 0 ? ' (+$bpmIncrease)' : ''}';

// defines a data model for tools

class Tool {
  final String id;
  final String title;

  const Tool({required this.id, required this.title});
}

// defines a data model for activities (tools or drills)

sealed class Activity {
  String get id;
  String get title;
}

class DrillActivity extends Activity {
  final Drill drill;
  DrillActivity(this.drill);
  @override
  String get id => drill.id;
  @override
  String get title => drill.title;
}

class ToolActivity extends Activity {
  final Tool tool;
  ToolActivity(this.tool);
  @override
  String get id => tool.id;
  @override
  String get title => tool.title;
}
