/// The sounds the metronome clicks with: a high one (on the beat) and a low one (between). The
/// percussive ones are bright, with a sharp attack and a short ring, to be heard over drums (see
/// assets/sounds/update_sounds.py, which makes them all).
enum ClickSound {
  classic('Classic', 'assets/sounds/beep.wav', 'assets/sounds/boop.wav'),
  woodblock('Woodblock', 'assets/sounds/woodblock_high.wav', 'assets/sounds/woodblock_low.wav'),
  cowbell('Cowbell', 'assets/sounds/cowbell_high.wav', 'assets/sounds/cowbell_low.wav');

  final String label;
  final String high;
  final String low;

  const ClickSound(this.label, this.high, this.low);
}
