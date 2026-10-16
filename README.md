# Taiko Trainer

A simple tool to display drumming drills, and animate them with a metronome. Its arcade look is an
homage to Namco's Mr. Driller games (the app's original name).

This is a Flutter app that should work on iOS and Android, and in theory on the web as well but I
haven't tested that much.

## Building

You need the [Flutter SDK](https://docs.flutter.dev/install) installed. If you've never done
Flutter dev before, then check out [their docs](https://docs.flutter.dev) and good luck!

You can run it for development in a number of ways. Run `flutter devices` to see what's available.
On my machine, I can run:

```sh
flutter run -d chrome  # runs in web mode on local chrome instance
flutter run -d macos   # runs a "native" macOS app in dev mode
flutter run -d ios     # runs on my locally running iPhone simulator
flutter run -d Pokekon # runs in dev mode on my actual iPhone
```

### Nativel release build

To install a release build to an iOS device:

```sh
flutter build ios --release
flutter install --release -d Pokekon
```

To build an IPA for upload to the AppStore:

```sh
flutter build ipa
```

### Web release build

```sh
flutter build web --release --base-href /mrdriller/
```

## Adding drills

The drills are defined in `lib/data/drills.dart` and are hopefully reasonably self-explanatory.
There are a bunch of existing drills as examples. If your drill doesn't do anything esoteric, you
can probably add it easily, and if it does do something fancy then fire up your favorite vibe coder
and add support for what you need. The AIs love to work on simple React web projects.

## License

Taiko Trainer was created by Michael Bayne, an aspiring dilettante taiko drummer. It's released under
the MIT license, so feel free to modify and use it however you like.
