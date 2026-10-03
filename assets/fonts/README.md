# Fonts

`NotoSansJP-*.ttf` are static-weight subsets of [Noto Sans JP](https://fonts.google.com/noto/specimen/Noto+Sans+JP)
(SIL Open Font License, see `NotoSansJP-OFL.txt`) containing only the Japanese characters (and arrows)
used in the app. They're used as a fallback font on web so that Flutter doesn't have to lazily download
Noto fonts at runtime (which shows tofu boxes until the download completes).

When adding new Japanese text (or arrows) to the app, regenerate them with `update_fonts.py`:

```sh
python3 -m venv /tmp/ftenv && /tmp/ftenv/bin/pip install fonttools
/tmp/ftenv/bin/python assets/fonts/update_fonts.py
```
