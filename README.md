# Mr. Driller

A simple tool to display drumming drills, and animate them with a metronome.

This is a Flutter app that should work on iOS and Android, and in theory on the web as well but I
haven't tested that much.

## Building

You need the [Flutter SDK](https://docs.flutter.dev/install) installed.

Then you can run it with `flutter run`. You need an Adroid emulator, iOS simulator, or a real
device to run it on.

If you've never done Flutter dev before, then check out [their docs](https://docs.flutter.dev) and
good luck!

## Adding drills

The drills are defined in `lib/data/drills.dart` and are hopefully reasonably self-explanatory.
There are a bunch of existing drills as examples. If your drill doesn't do anything esoteric, you
can probably add it easily, and if it does do something fancy then fire up your favorite vibe coder
and add support for what you need. The AIs love to work on simple React web projects.

## License

Mr. Driller was created by Michael Bayne, an aspiring dilettante taiko drummer. It's released under
the MIT license, so feel free to modify and use it however you like.
