# Fonts

The app bundles static-weight subsets of two fonts (both under the SIL Open Font License, see the
`*-OFL.txt` files):

- [M PLUS Rounded 1c](https://fonts.google.com/specimen/M+PLUS+Rounded+1c) (`MPLUSRounded1c-*.ttf`,
  weights 400–900): the UI font.
- [Mochiy Pop One](https://fonts.google.com/specimen/Mochiy+Pop+One) (`MochiyPopOne-400.ttf`): the
  puffy display font for titles and big arcade text.

Each is subset to Latin plus whatever non-ASCII characters (Japanese text, arrows, etc.) appear in
`lib/`, which keeps them small and means Flutter on web doesn't have to lazily download a fallback
font for the Japanese text (which shows tofu boxes until the download completes).

When adding new Japanese text (or other non-Latin characters) to the app, regenerate them with
`update_fonts.py`:

```sh
python3 -m venv /tmp/ftenv && /tmp/ftenv/bin/pip install fonttools
/tmp/ftenv/bin/python assets/fonts/update_fonts.py
```
