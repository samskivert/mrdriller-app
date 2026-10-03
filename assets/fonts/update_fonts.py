#!/usr/bin/env python3
"""Regenerates the bundled font subsets from the characters used in lib/.

Each font is subset to Latin (plus common punctuation) and every non-ASCII character that appears
anywhere in lib/, so the app's Japanese text renders from the bundled fonts on every platform
(including web, where Flutter would otherwise lazily download a fallback font and show tofu until
it arrives).

Requires fonttools: python3 -m venv /tmp/ftenv && /tmp/ftenv/bin/pip install fonttools
then run (from anywhere): /tmp/ftenv/bin/python assets/fonts/update_fonts.py
"""

import io
import pathlib
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

BASE_URL = 'https://github.com/google/fonts/raw/main/ofl'

# (source file under BASE_URL, output file name)
FONTS = [
    ('mplusrounded1c/MPLUSRounded1c-Regular.ttf', 'MPLUSRounded1c-400.ttf'),
    ('mplusrounded1c/MPLUSRounded1c-Medium.ttf', 'MPLUSRounded1c-500.ttf'),
    ('mplusrounded1c/MPLUSRounded1c-Bold.ttf', 'MPLUSRounded1c-700.ttf'),
    ('mplusrounded1c/MPLUSRounded1c-ExtraBold.ttf', 'MPLUSRounded1c-800.ttf'),
    ('mplusrounded1c/MPLUSRounded1c-Black.ttf', 'MPLUSRounded1c-900.ttf'),
    ('mochiypopone/MochiyPopOne-Regular.ttf', 'MochiyPopOne-400.ttf'),
]

FONTS_DIR = pathlib.Path(__file__).resolve().parent
LIB_DIR = FONTS_DIR.parent.parent / 'lib'

# Always included, whether or not lib/ happens to use them today: printable ASCII, Latin-1, and
# general punctuation (dashes, quotes, bullets, ellipsis).
BASE_RANGES = [(0x20, 0x7E), (0xA0, 0xFF), (0x2010, 0x2027), (0x2030, 0x205E)]


def main():
    base = {chr(cp) for lo, hi in BASE_RANGES for cp in range(lo, hi + 1)}
    used = {c for p in LIB_DIR.rglob('*.dart') for c in p.read_text() if ord(c) > 0x7E}
    text = ''.join(sorted(base | used))
    print(f'Non-ASCII characters from lib/: {"".join(sorted(used))}')

    for source, out_name in FONTS:
        url = f'{BASE_URL}/{source}'
        print(f'Downloading {url}')
        with urllib.request.urlopen(url) as resp:
            font = TTFont(io.BytesIO(resp.read()))
        options = subset.Options()
        options.layout_features = ['*']
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        # keep the source font's timestamp so that rerunning doesn't churn unchanged files
        font.recalcTimestamp = False
        out = FONTS_DIR / out_name
        font.save(out)
        print(f'Wrote {out.relative_to(FONTS_DIR.parent.parent)}')


if __name__ == '__main__':
    main()
