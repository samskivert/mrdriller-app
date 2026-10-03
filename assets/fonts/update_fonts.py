#!/usr/bin/env python3
"""Regenerates the NotoSansJP-*.ttf subsets from the characters used in lib/.

Requires fonttools: python3 -m venv /tmp/ftenv && /tmp/ftenv/bin/pip install fonttools
then run (from anywhere): /tmp/ftenv/bin/python assets/fonts/update_fonts.py
"""

import io
import pathlib
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FONT_URL = 'https://github.com/google/fonts/raw/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf'
WEIGHTS = [400, 500, 600, 700, 900]

FONTS_DIR = pathlib.Path(__file__).resolve().parent
LIB_DIR = FONTS_DIR.parent.parent / 'lib'


def wanted(c):
    cp = ord(c)
    return (0x2190 <= cp <= 0x21FF  # arrows
            or 0x3000 <= cp <= 0x9FFF  # CJK punctuation, kana, kanji
            or 0xFF00 <= cp <= 0xFFEF)  # full-width forms


def main():
    text = ''.join(sorted({c for p in LIB_DIR.rglob('*.dart') for c in p.read_text() if wanted(c)}))
    print(f'Characters: {text}')

    print(f'Downloading {FONT_URL}')
    with urllib.request.urlopen(FONT_URL) as resp:
        data = resp.read()

    font = TTFont(io.BytesIO(data))
    options = subset.Options()
    options.layout_features = ['*']
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)

    for weight in WEIGHTS:
        out = FONTS_DIR / f'NotoSansJP-{weight}.ttf'
        instance = instancer.instantiateVariableFont(font, {'wght': weight})
        # keep the source font's timestamp so that rerunning doesn't churn unchanged files
        instance.recalcTimestamp = False
        instance.save(out)
        print(f'Wrote {out.relative_to(FONTS_DIR.parent.parent)}')


if __name__ == '__main__':
    main()
