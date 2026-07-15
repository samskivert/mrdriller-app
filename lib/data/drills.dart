// Defines the data for all drills. Mechanically translated from the TypeScript source
// (web/src/drills.ts).

import 'package:mrdriller/model/model.dart';

final Drill paradiddles = Drill(
  id: "paradiddles",
  title: "Paradiddles",
  bpm: 4,
  rows: [
    [
      section("Pa-ra-did-dle", 4, [
        line([measure([r, l, r, r]), measure([l, r, l, l])]),
        line([measure([r, l, r, r]), measure([l, r, l, l])]),
        line([measure([R, l, r, r]), measure([L, r, l, l])]),
        line([measure([R, l, r, r]), measure([L, r, l, l])]),
      ]),
    ],
  ],
);

final Drill kodoParadiddle = Drill(
  id: "kodo-paradiddle",
  title: "Paradiddle Drill",
  bpm: 4,
  rows: [
    [oneLineSection("Accent 1", 4, [measure([R, l, r, r]), measure([L, r, l, l])])],
    [oneLineSection("Accent 3+4", 4, [measure([r, l, R, R]), measure([l, r, L, L])])],
    [
      oneLineSection("Accent R", 2, [measure([R, l, R, R]), measure([l, R, l, l])]),
      oneLineSection("Accent L", 2, [measure([r, L, r, r]), measure([L, r, L, L])]),
    ],
    [
      oneLineSection("Accent R", 2, [measure([R, l, R, R]), measure([l, R, l, l])]),
      oneLineSection("Accent L", 2, [measure([r, L, r, r]), measure([L, r, L, L])]),
    ],
    [oneLineSection("Accent 4", 4, [measure([r, l, r, R]), measure([l, r, l, L])])],
  ],
);

final Drill paradiddleAccents = Drill(
  id: "paradiddle-accents",
  title: "Paradiddle Accents",
  bpm: 4,
  rows: [
    [oneLineSection("PA-ra-did-dle", 4, [measure([R, l, r, r]), measure([L, r, l, l])])],
    [oneLineSection("Pa-RA-did-dle", 4, [measure([r, L, r, r]), measure([l, R, l, l])])],
    [oneLineSection("PA-ra-DID-dle", 4, [measure([r, l, R, r]), measure([l, r, L, l])])],
    [oneLineSection("PA-ra-did-DLE", 4, [measure([r, l, r, R]), measure([l, r, l, L])])],
  ],
);

final Drill paradiddleInversions = Drill(
  id: "paradiddle-inversions",
  title: "Paradiddle Inversions",
  bpm: 4,
  rows: [
    [oneLineSection("Pa-ra-did-dle", 4, [measure([R, l, r, r]), measure([L, r, l, l])])],
    [oneLineSection("Ra-did-dle-pa", 4, [measure([R, l, l, r]), measure([L, r, r, l])])],
    [oneLineSection("Did-dle-pa-ra", 4, [measure([R, r, l, r]), measure([L, l, r, l])])],
    [oneLineSection("Dle-pa-ra-did", 4, [measure([R, l, r, l]), measure([L, r, l, r])])],
  ],
);

final Drill bachiHakobi = Drill(
  id: "bachi-hakobi",
  title: "Bachi Hakobi - 桴運び",
  bpm: 4,
  beeps: [1, 3],
  rows: [
    [
      oneLineSection("Three - R", 1, [
        [
          labeledBeat("1", [rd]),
          beat([ru]),
          null,
          null,
          labeledBeat("2", [ld]),
          beat([lu]),
          null,
          null,
          labeledBeat("3", [rd]),
          labeledBeat("+", [ru, ld]),
          null,
          null,
          labeledBeat("4", [rd]),
          beat([ru, lu]),
          null,
          null,
        ],
      ]),
      oneLineSection("Three - L", 1, [
        [
          labeledBeat("1", [ld]),
          beat([lu]),
          null,
          null,
          labeledBeat("2", [rd]),
          beat([ru]),
          null,
          null,
          labeledBeat("3", [ld]),
          labeledBeat("+", [lu, rd]),
          null,
          null,
          labeledBeat("4", [ld]),
          beat([lu, ru]),
          null,
          null,
        ],
      ]),
    ],

    [
      oneLineSection("Four - R", 1, [
        [
          labeledBeat("1", [rd]),
          beat([ru]),
          null,
          null,
          labeledBeat("2", [ld]),
          beat([lu]),
          null,
          null,
          labeledBeat("3", [rd]),
          beat([ru]),
          null,
          null,
          labeledBeat("4", [ld]),
          labeledBeat("+", [lu, rd]),
          null,
          null,
        ],
      ]),
      oneLineSection("Four - L", 1, [
        [
          labeledBeat("1", [ld]),
          beat([lu, ru]),
          null,
          null,
          labeledBeat("2", [rd]),
          beat([ru]),
          null,
          null,
          labeledBeat("3", [ld]),
          beat([lu]),
          null,
          null,
          labeledBeat("4", [rd]),
          labeledBeat("+", [ru, ld]),
          null,
          null,
        ],
      ]),
    ],

    [
      oneLineSection("One - R", 1, [
        [
          labeledBeat("1", [rd]),
          labeledBeat("+", [ru, ld]),
          null,
          null,
          labeledBeat("2", [rd]),
          beat([ru, lu]),
          null,
          null,
          labeledBeat("3", [ld]),
          beat([lu]),
          null,
          null,
          labeledBeat("4", [rd]),
          beat([ru]),
          null,
          null,
        ],
      ]),
      oneLineSection("One - L", 1, [
        [
          labeledBeat("1", [ld]),
          labeledBeat("+", [lu, rd]),
          null,
          null,
          labeledBeat("2", [ld]),
          beat([lu, ru]),
          null,
          null,
          labeledBeat("3", [rd]),
          beat([ru]),
          null,
          null,
          labeledBeat("4", [ld]),
          beat([lu]),
          null,
          null,
        ],
      ]),
    ],

    [
      oneLineSection("Two - R", 1, [
        [
          labeledBeat("1", [rd]),
          beat([ru]),
          null,
          null,
          labeledBeat("2", [ld]),
          labeledBeat("+", [lu, rd]),
          null,
          null,
          labeledBeat("3", [ld]),
          beat([lu, ru]),
          null,
          null,
          labeledBeat("4", [rd]),
          beat([ru]),
          null,
          null,
        ],
      ]),
      oneLineSection("Two - L", 1, [
        [
          labeledBeat("1", [ld]),
          beat([lu]),
          null,
          null,
          labeledBeat("2", [rd]),
          labeledBeat("+", [ru, ld]),
          null,
          null,
          labeledBeat("3", [rd]),
          beat([ru, lu]),
          null,
          null,
          labeledBeat("4", [ld]),
          beat([lu]),
          null,
          null,
        ],
      ]),
    ],
  ],
);

final Drill oneEAndA = Drill(
  id: "one-e-and-a",
  title: "One e and a (1e+a)",
  bpm: 4,
  forceIntro: true,
  rows: [
    [
      oneLineSection("Accent 1", 4, [measure([R, l, r, l])]),
      oneLineSection("Accent 2", 4, [measure([r, L, r, l])]),
      oneLineSection("Accent 3", 4, [measure([r, l, R, l])]),
      oneLineSection("Accent 4", 4, [measure([r, l, r, L])]),
    ],
    [
      oneLineSection("Accent 1+2", 4, [measure([R, L, r, l])]),
      oneLineSection("Accent 2+3", 4, [measure([r, L, R, l])]),
      oneLineSection("Accent 3+4", 4, [measure([r, l, R, L])]),
      oneLineSection("Accent 1+4", 4, [measure([R, l, r, L])]),
      oneLineSection("Accent 1+3", 4, [measure([R, l, R, l])]),
      oneLineSection("Accent 2+4", 4, [measure([r, L, r, L])]),
    ],
    [
      oneLineSection("Accent 1+2+3", 4, [measure([R, L, R, l])]),
      oneLineSection("Accent 2+3+4", 4, [measure([r, L, R, L])]),
      oneLineSection("Accent 1+3+4", 4, [measure([R, l, R, L])]),
      oneLineSection("Accent 1+2+4", 4, [measure([R, L, r, L])]),
    ],
    [oneLineSection("Accent 1+2+3+4", 4, [measure([R, L, R, L])])],
  ],
);

final Drill diddleAndA = Drill(
  id: "diddle-and-a",
  title: "Diddle and a",
  bpm: 4,
  forceIntro: true,
  rows: [
    [
      oneLineSection("Accent 1", 2, [measure([R, l, r, r]), measure([L, r, l, l])]),
      oneLineSection("Accent 2", 2, [measure([r, L, r, r]), measure([l, R, l, l])]),
      oneLineSection("Accent 3", 2, [measure([r, l, R, r]), measure([l, r, L, l])]),
      oneLineSection("Accent 4", 2, [measure([r, l, r, R]), measure([l, r, l, L])]),
    ],
    [
      oneLineSection("Accent 1+2", 2, [measure([R, L, r, r]), measure([L, R, l, l])]),
      oneLineSection("Accent 2+3", 2, [measure([r, L, R, r]), measure([l, R, L, l])]),
      oneLineSection("Accent 3+4", 2, [measure([r, l, R, R]), measure([l, r, L, L])]),
      oneLineSection("Accent 1+4", 2, [measure([R, l, r, R]), measure([L, r, l, L])]),
      oneLineSection("Accent 1+3", 2, [measure([R, l, R, r]), measure([L, r, L, l])]),
      oneLineSection("Accent 2+4", 2, [measure([r, L, r, R]), measure([l, R, l, L])]),
    ],
    [
      oneLineSection("Accent 1+2+3", 2, [measure([R, L, R, r]), measure([L, R, L, l])]),
      oneLineSection("Accent 2+3+4", 2, [measure([r, L, R, R]), measure([l, R, L, L])]),
      oneLineSection("Accent 1+3+4", 2, [measure([R, l, R, R]), measure([L, r, L, L])]),
      oneLineSection("Accent 1+2+4", 2, [measure([R, L, r, R]), measure([L, R, l, L])]),
    ],
    [oneLineSection("Accent 1+2+3+4", 2, [measure([R, L, R, R]), measure([L, R, L, L])])],
  ],
);

final Drill addingAccents = Drill(
  id: "adding-accents",
  title: "Adding accents",
  bpm: 4,
  rows: [
    [oneLineSection("None", 1, [measure([r, l, r, l]), measure([r, l, r, l])])],
    [oneLineSection("One", 1, [measure([R, l, r, l]), measure([R, l, r, l])])],
    [oneLineSection("One, Two", 1, [measure([R, L, r, l]), measure([R, L, r, l])])],
    [oneLineSection("One, Two, Three", 1, [measure([R, L, R, l]), measure([R, L, R, l])])],
    [oneLineSection("One, Two, Three, Four", 1, [measure([R, L, R, L]), measure([R, L, R, L])])],
  ],
);

final Drill iceSkater = Drill(
  id: "ice-skater",
  title: "Ice Skater",
  bpm: 8,
  beeps: [1, 3, 5, 7],
  scale: 0.5,
  rows: [
    [
      section("Four", 2, [
        line([measure([r, null, r, null, r, null, r, null])]),
        line([measure([l, null, l, null, l, null, l, null])]),
      ]),
    ],
    [
      section("Three", 2, [
        line([measure([r, null, r, null, r, null])]),
        line([measure([l, null, l, null, l, null])]),
      ]),
      oneLineSection("Four", 1, [measure([r, null, r, null, r, null, r, null])]),
    ],
    [
      section("Four", 2, [
        line([measure([l, null, l, null, l, null, l, null])]),
        line([measure([r, null, r, null, r, null, r, null])]),
      ]),
    ],
    [
      section("Three", 2, [
        line([measure([l, null, l, null, l, null])]),
        line([measure([r, null, r, null, r, null])]),
      ]),
      oneLineSection("Four", 1, [measure([l, null, l, null, l, null, l, null])]),
    ],
    [
      section("Four + 1", 2, [
        line([measure([r, l, r, null, r, null, r, null])]),
        line([measure([l, r, l, null, l, null, l, null])]),
      ]),
    ],
    [
      section("Three + 1", 2, [
        line([measure([r, l, r, null, r, null])]),
        line([measure([l, r, l, null, l, null])]),
      ]),
      oneLineSection("Four + 1", 1, [measure([r, l, r, null, r, null, r, null])]),
    ],
    [
      section("Four + 1", 2, [
        line([measure([l, r, l, null, l, null, l, null])]),
        line([measure([r, l, r, null, r, null, r, null])]),
      ]),
    ],
    [
      section("Three + 1", 2, [
        line([measure([l, r, l, null, l, null])]),
        line([measure([r, l, r, null, r, null])]),
      ]),
      oneLineSection("Four + 1", 1, [measure([l, r, l, null, l, null, l, null])]),
    ],
    [
      section("Four + 2", 2, [
        line([measure([r, l, r, l, r, null, r, null])]),
        line([measure([l, r, l, r, l, null, l, null])]),
      ]),
    ],
    [
      section("Three + 2", 2, [
        line([measure([r, l, r, l, r, null])]),
        line([measure([l, r, l, r, l, null])]),
      ]),
      oneLineSection("Four + 2", 1, [measure([r, l, r, l, r, null, r, null])]),
    ],
    [
      section("Four + 2", 2, [
        line([measure([l, r, l, r, l, null, l, null])]),
        line([measure([r, l, r, l, r, null, r, null])]),
      ]),
    ],
    [
      section("Three + 2", 2, [
        line([measure([l, r, l, r, l, null])]),
        line([measure([r, l, r, l, r, null])]),
      ]),
      oneLineSection("Four + 2", 1, [measure([l, r, l, r, l, null, l, null])]),
    ],
  ],
);

final Drill triplets = Drill(
  id: "triplets",
  title: "Triplets",
  bpm: 3,
  rows: [
    [
      oneLineSection("Accent 1", 4, [measure([R, l, r]), measure([L, r, l])]),
      oneLineSection("Accent 2", 4, [measure([r, L, r]), measure([l, R, l])]),
      oneLineSection("Accent 3", 4, [measure([r, l, R]), measure([l, r, L])]),
    ],
    [
      oneLineSection("Accent 2+3", 4, [measure([r, L, R]), measure([l, R, L])]),
      oneLineSection("Accent 1+3", 4, [measure([R, l, R]), measure([L, r, L])]),
      oneLineSection("Accent 1+2", 4, [measure([R, L, r]), measure([L, R, l])]),
    ],
  ],
);

final Measure ddkR = measure([r, null, r, l]);
final Measure ddkRs = measure([r, null, l, r]);
final Measure ddkL = measure([l, null, l, r]);
final Measure ddkLs = measure([l, null, r, l]);

final Drill dondoko = Drill(
  id: "dondoko",
  title: "Dondoko",
  bpm: 4,
  beeps: [1, 3],
  rows: [
    [
      section("8R", 1, [
        line([ddkR, ddkR]),
        line([ddkR, ddkR]),
        line([ddkR, ddkR]),
        line([ddkR, ddkRs]),
      ]),
      section("8L", 1, [
        line([ddkL, ddkL]),
        line([ddkL, ddkL]),
        line([ddkL, ddkL]),
        line([ddkL, ddkLs]),
      ]),
    ],
    [
      section("4s", 2, [
        line([ddkR, ddkR]),
        line([ddkR, ddkRs]),
        line([ddkL, ddkL]),
        line([ddkL, ddkLs]),
      ]),
    ],
    [
      section("2s", 4, [line([ddkR, ddkRs]), line([ddkL, ddkLs])]),
    ],
  ],
);

final Drill threeAgainstTwo = Drill(
  id: "three-against-two",
  title: "Three against Two",
  bpm: 6,
  beeps: [1, 3, 5],
  rows: [
    [
      oneLineSection("A", 8, [
        [beat([r, l]), null, beat([r]), beat([null, l]), beat([r]), null],
      ]),
      oneLineSection("B", 8, [
        [beat([r]), beat([null, l]), beat([r]), null, beat([r, l]), null],
      ]),
    ],
    [
      oneLineSection("C", 8, [
        [beat([r, l]), null, beat([null, l]), beat([r]), beat([null, l]), null],
      ]),
      oneLineSection("D", 8, [
        [beat([null, l]), beat([r]), beat([null, l]), null, beat([r, l]), null],
      ]),
    ],
  ],
);

final Beat beatRL = beat([r, l]);
final Beat beatR = beat([r]);
final Beat beatL = beat([null, l]);

final Drill fourAgainstThree = Drill(
  id: "four-against-three",
  title: "Four against Three",
  bpm: 12,
  beeps: [1, 5, 9],
  scale: 0.5,
  rows: [
    [
      oneLineSection("A", 8, [
        [beatRL, null, null, beatR, beatL, null, beatR, null, beatL, beatR, null, null],
      ]),
      oneLineSection("B", 8, [
        [beatR, beatL, null, beatR, null, beatL, beatR, null, null, beatRL, null, null],
      ]),
    ],
    [
      oneLineSection("C", 8, [
        [beatRL, null, null, beatL, beatR, null, beatL, null, beatR, beatL, null, null],
      ]),
      oneLineSection("D", 8, [
        [beatL, beatR, null, beatL, null, beatR, beatL, null, null, beatRL, null, null],
      ]),
    ],
  ],
);

final Drill allAgainstThree = Drill(
  id: "all-against-three",
  title: "1, 2, 3, 4 against Three",
  bpm: 12,
  beeps: [1, 5, 9],
  scale: 0.5,
  rows: [
    [
      oneLineSection("1 v 3 - R", 4, [
        [beatRL, null, null, null, beatR, null, null, null, beatR, null, null, null],
      ]),
      oneLineSection("2 v 3 - R", 4, [
        [beatRL, null, null, null, beatR, null, beatL, null, beatR, null, null, null],
      ]),
    ],
    [
      oneLineSection("3 v 3 - R", 4, [
        [beatRL, null, null, null, beatRL, null, null, null, beatRL, null, null, null],
      ]),
      oneLineSection("4 v 3 - R", 4, [
        [beatRL, null, null, beatL, beatR, null, beatL, null, beatR, beatL, null, null],
      ]),
    ],
    [
      oneLineSection("1 v 3 - L", 4, [
        [beatRL, null, null, null, beatL, null, null, null, beatL, null, null, null],
      ]),
      oneLineSection("2 v 3 - L", 4, [
        [beatRL, null, null, null, beatL, null, beatR, null, beatL, null, null, null],
      ]),
    ],
    [
      oneLineSection("3 v 3 - L", 4, [
        [beatRL, null, null, null, beatRL, null, null, null, beatRL, null, null, null],
      ]),
      oneLineSection("4 v 3 - L", 4, [
        [beatRL, null, null, beatR, beatL, null, beatR, null, beatL, beatR, null, null],
      ]),
    ],
  ],
);

final Measure dright8 = [beatRL, beatR, beatR, beatR, beatR, beatR, beatR, beatR];
final Measure dleft8 = [beatRL, beatL, beatL, beatL, beatL, beatL, beatL, beatL];
final Measure dright4 = [beatRL, beatR, beatR, beatR];
final Measure dleft4 = [beatRL, beatL, beatL, beatL];
final Measure dright2 = [beatRL, beatR];
final Measure dleft2 = [beatRL, beatL];
final Measure djan3 = [beatRL, beatRL, beatRL, null];

final Drill dexter = Drill(
  id: "dexter",
  title: "Dexter",
  bpm: 4,
  rows: [
    [
      oneLineSection("Right 8s", 2, [dright8]),
      oneLineSection("Right 4s", 2, [
        [...dright4, ...dright4],
      ]),
    ],
    [
      oneLineSection("Right 2s", 2, [
        [...dright2, ...dright2, ...dright2],
      ]),
      oneLineSection("Jan Jan Jan", 1, [djan3]),
    ],
    [
      oneLineSection("Left 8s", 2, [dleft8]),
      oneLineSection("Left 4s", 2, [
        [...dleft4, ...dleft4],
      ]),
    ],
    [
      oneLineSection("Left 2s", 2, [
        [...dleft2, ...dleft2, ...dleft2],
      ]),
      oneLineSection("Jan Jan Jan", 1, [djan3]),
    ],
    [
      oneLineSection("Right 8", 1, [dright8]),
      oneLineSection("Left 8", 1, [dleft8]),
    ],
    [
      oneLineSection("Alt 4s", 2, [
        [...dright4, ...dleft4],
      ]),
      oneLineSection("Alt 2s", 3, [
        [...dright2, ...dleft2],
      ]),
      oneLineSection("Jan Jan Jan", 1, [djan3]),
    ],
  ],
);

final Measure srr = [beat([r]), null, beat([r]), null];
final Measure srr2 = [...srr, ...srr];
final Measure sll = [beat([l]), null, beat([l]), null];
final Measure sll2 = [...sll, ...sll];

final Measure srlr = [beat([r]), beat([l]), beat([r]), null];
final Measure slrl = [beat([l]), beat([r]), beat([l]), null];

final Measure srlrl = [beat([r]), beat([l]), beat([r]), beat([l])];
final Measure srlrl2 = [...srlrl, ...srlrl];
final Measure slrlr = [beat([l]), beat([r]), beat([l]), beat([r])];
final Measure slrlr2 = [...slrlr, ...slrlr];

final Drill sixteens = Drill(
  id: "sixteens",
  title: "Sixteens",
  bpm: 8,
  beeps: [1, 3, 5, 7],
  scale: 0.5,
  rows: [
    [oneLineSection("0", 2, [srr2, srr2, srr2, srr2, sll2, sll2, sll2, sll2])],
    [
      oneLineSection("1", 2, [
        [...srlr, ...srr],
        srr2,
        srr2,
        srr2,
        [...slrl, ...sll],
        sll2,
        sll2,
        sll2,
      ]),
    ],
    [
      oneLineSection("2", 2, [
        [...srlrl, ...srr],
        srr2,
        srr2,
        srr2,
        [...slrlr, ...sll],
        sll2,
        sll2,
        sll2,
      ]),
    ],
    [
      oneLineSection("3", 2, [
        [...srlrl, ...srlr],
        srr2,
        srr2,
        srr2,
        [...slrlr, ...slrl],
        sll2,
        sll2,
        sll2,
      ]),
    ],
    [oneLineSection("4", 2, [srlrl2, srr2, srr2, srr2, slrlr2, sll2, sll2, sll2])],
    [
      oneLineSection("5", 2, [
        srlrl2,
        [...srlr, ...srr],
        srr2,
        srr2,
        slrlr2,
        [...slrl, ...sll],
        sll2,
        sll2,
      ]),
    ],
    [
      oneLineSection("6", 2, [
        srlrl2,
        [...srlrl, ...srr],
        srr2,
        srr2,
        slrlr2,
        [...slrlr, ...sll],
        sll2,
        sll2,
      ]),
    ],
    [
      oneLineSection("7", 2, [
        srlrl2,
        [...srlrl, ...srlr],
        srr2,
        srr2,
        slrlr2,
        [...slrlr, ...slrl],
        sll2,
        sll2,
      ]),
    ],
    [oneLineSection("8", 2, [srlrl2, srlrl2, srr2, srr2, slrlr2, slrlr2, sll2, sll2])],
    [
      oneLineSection("9", 2, [
        srlrl2,
        srlrl2,
        [...srlr, ...srr],
        srr2,
        slrlr2,
        slrlr2,
        [...slrl, ...sll],
        sll2,
      ]),
    ],
    [
      oneLineSection("10", 2, [
        srlrl2,
        srlrl2,
        [...srlrl, ...srr],
        srr2,
        slrlr2,
        slrlr2,
        [...slrlr, ...sll],
        sll2,
      ]),
    ],
    [
      oneLineSection("11", 2, [
        srlrl2,
        srlrl2,
        [...srlrl, ...srlr],
        srr2,
        slrlr2,
        slrlr2,
        [...slrlr, ...slrl],
        sll2,
      ]),
    ],
    [oneLineSection("12", 2, [srlrl2, srlrl2, srlrl2, srr2, slrlr2, slrlr2, slrlr2, sll2])],
    [
      oneLineSection("13", 2, [
        srlrl2,
        srlrl2,
        srlrl2,
        [...srlr, ...srr],
        slrlr2,
        slrlr2,
        slrlr2,
        [...slrl, ...sll],
      ]),
    ],
    [
      oneLineSection("14", 2, [
        srlrl2,
        srlrl2,
        srlrl2,
        [...srlrl, ...srr],
        slrlr2,
        slrlr2,
        slrlr2,
        [...slrlr, ...sll],
      ]),
    ],
    [
      oneLineSection("15", 2, [
        srlrl2,
        srlrl2,
        srlrl2,
        [...srlrl, ...srlr],
        slrlr2,
        slrlr2,
        slrlr2,
        [...slrlr, ...slrl],
      ]),
    ],
  ],
);

final Drill singleStrokeRoll = Drill(
  id: "single-stroke-roll",
  title: "Single Stroke Roll",
  bpm: 4,
  beeps: [1, 3],
  rows: [
    [
      section("R, L", 4, [
        line([measure([r, null, r, null, r, null, r, null])]),
        line([measure([l, null, l, null, l, null, l, null])]),
      ]),
    ],
    [
      section("Rx2, Lx2", 2, [
        line([measure([r, null, r, null, r, null, r, null])]),
        line([measure([r, null, r, null, r, null, r, null])]),
        line([measure([l, null, l, null, l, null, l, null])]),
        line([measure([l, null, l, null, l, null, l, null])]),
      ]),
    ],
    [
      section("Rx4", 1, [
        line([measure([r, null, r, null, r, null, r, null])]),
        line([measure([r, null, r, null, r, null, r, null])]),
        line([measure([r, null, r, null, r, null, r, null])]),
        line([measure([r, null, r, null, r, null, r, null])]),
      ]),
    ],
    [
      section("Lx4", 1, [
        line([measure([l, null, l, null, l, null, l, null])]),
        line([measure([l, null, l, null, l, null, l, null])]),
        line([measure([l, null, l, null, l, null, l, null])]),
        line([measure([l, null, l, null, l, null, l, null])]),
      ]),
    ],
    [
      section("R + L", 4, [
        line([measure([r, l, r, l, r, l, r, l])]),
        line([measure([r, l, r, l, r, l, r, l])]),
      ]),
    ],
  ],
);

final Drill doubleStrokeRoll = Drill(
  id: "double-stroke-roll",
  title: "Double Stroke Roll",
  bpm: 4,
  beeps: [1, 3],
  rows: [
    [oneLineSection("RL", 2, [measure([r, null, l, null, r, null, l, null])])],
    [oneLineSection("RRR", 2, [measure([r, r, r, null, r, r, r, null])])],
    [oneLineSection("RLL", 2, [measure([r, null, l, l, r, null, l, l])])],
    [oneLineSection("RRLL", 2, [measure([r, r, l, l, r, r, l, l])])],

    [oneLineSection("RL", 2, [measure([r, null, l, null, r, null, l, null])])],
    [oneLineSection("RRR", 2, [measure([r, r, r, null, r, r, r, null])])],
    [oneLineSection("RLL", 2, [measure([r, null, l, l, r, null, l, l])])],
    [oneLineSection("RRLL", 2, [measure([r, r, l, l, r, r, l, l])])],

    [oneLineSection("LR", 2, [measure([l, null, r, null, l, null, r, null])])],
    [oneLineSection("LLL", 2, [measure([l, l, l, null, l, l, l, null])])],
    [oneLineSection("LRR", 2, [measure([l, null, r, r, l, null, r, r])])],
    [oneLineSection("LLRR", 2, [measure([l, l, r, r, l, l, r, r])])],

    [oneLineSection("LR", 2, [measure([l, null, r, null, l, null, r, null])])],
    [oneLineSection("LLL", 2, [measure([l, l, l, null, l, l, l, null])])],
    [oneLineSection("LRR", 2, [measure([l, null, r, r, l, null, r, r])])],
    [oneLineSection("LLRR", 2, [measure([l, l, r, r, l, l, r, r])])],
  ],
);

final Beat beatRAL = beat([R, l]);
final Beat beatRLA = beat([r, L]);
final Beat beatRALA = beat([R, L]);

final Drill oneFourSeven = Drill(
  id: "one-four-seven",
  title: "One Four Seven",
  bpm: 4,
  rows: [
    [
      oneLineSection("Right", 4, [
        [beatRLA, beatR, beatR, beatRLA, beatR, beatR, beatRLA, beatR],
      ]),
    ],
    [
      oneLineSection("Left", 4, [
        [beatRAL, beatL, beatL, beatRAL, beatL, beatL, beatRAL, beatL],
      ]),
    ],
    [
      oneLineSection("Jan Right", 4, [
        [beatRALA, beatR, beatR, beatRALA, beatR, beatR, beatRALA, beatR],
      ]),
    ],
    [
      oneLineSection("Jan Left", 4, [
        [beatRALA, beatL, beatL, beatRALA, beatL, beatL, beatRALA, beatL],
      ]),
    ],
  ],
);

final Drill kihon = Drill(
  id: "kihon",
  title: "Kihon",
  bpm: 8,
  beeps: [1, 3, 5, 7],
  rows: [
    [oneLineSection("Right (Whole)", 8, [measure([R, null, null, null, null, null, null, null])])],
    [oneLineSection("Left (Whole)", 8, [measure([L, null, null, null, null, null, null, null])])],
    [oneLineSection("Right (Half)", 8, [measure([R, null, null, null, R, null, null, null])])],
    [oneLineSection("Left (Half)", 8, [measure([L, null, null, null, L, null, null, null])])],
    [oneLineSection("Right (Quarter)", 8, [measure([R, null, R, null, R, null, R, null])])],
    [oneLineSection("Left (Quarter)", 8, [measure([L, null, L, null, L, null, L, null])])],
    [oneLineSection("Right (Eighth)", 8, [measure([R, R, R, R, R, R, R, R])])],
    [oneLineSection("Left (Eighth)", 8, [measure([L, L, L, L, L, L, L, L])])],
    [
      oneLineSection("Alternate (Whole)", 8, [
        measure([R, null, null, null, null, null, null, null]),
        measure([L, null, null, null, null, null, null, null]),
      ]),
    ],
    [
      oneLineSection("Alternate (Half)", 8, [
        measure([R, null, null, null, L, null, null, null]),
        measure([R, null, null, null, L, null, null, null]),
      ]),
    ],
    [
      oneLineSection("Alternate (Quarter)", 8, [
        measure([R, null, L, null, R, null, L, null]),
        measure([R, null, L, null, R, null, L, null]),
      ]),
    ],
    [
      oneLineSection("Alternate (Eighth)", 8, [
        measure([R, L, R, L, R, L, R, L]),
        measure([R, L, R, L, R, L, R, L]),
      ]),
    ],
    [
      oneLineSection("Both (Whole)", 4, [
        [beatRALA, null, null, null, null, null, null, null],
      ]),
    ],
    [
      oneLineSection("Both (Half)", 4, [
        [beatRALA, null, null, null, beatRALA, null, null, null],
      ]),
    ],
    [
      oneLineSection("Both (Quarter)", 4, [
        [beatRALA, null, beatRALA, null, beatRALA, null, beatRALA, null],
      ]),
    ],
    [
      oneLineSection("Both (Eighth)", 4, [
        [
          beatRALA,
          beatRALA,
          beatRALA,
          beatRALA,
          beatRALA,
          beatRALA,
          beatRALA,
          beatRALA,
        ],
      ]),
    ],
  ],
);

final Drill shurui = Drill(
  id: "shurui",
  title: "Shurui",
  bpm: 4,
  rows: [
    [oneLineSection("From Top", 4, [measure([R, null, L, null, R, null, L, null])])],
    [oneLineSection("From Bottom", 4, [measure([R, null, L, null, R, null, L, null])])],
    [oneLineSection("Scissors", 4, [measure([R, null, L, null, R, null, L, null])])],
  ],
);

final List<Drill> drills = [
  oneEAndA,
  addingAccents,
  paradiddles,
  kodoParadiddle,
  paradiddleAccents,
  paradiddleInversions,
  diddleAndA,
  bachiHakobi,
  iceSkater,
  dondoko,
  triplets,
  threeAgainstTwo,
  fourAgainstThree,
  allAgainstThree,
  dexter,
  sixteens,
  singleStrokeRoll,
  doubleStrokeRoll,
  oneFourSeven,
  kihon,
  shurui,
];
