import 'dart:math';

/// Plainly synthetic Arabic-script nonsense for layout tests: random runs of
/// letters of the Arabic block, some followed by a combining mark, never
/// words taken from any text. The same seed gives the same strings.
final class SyntheticArabicScript {
  SyntheticArabicScript(int seed) : _random = Random(seed);

  final Random _random;

  /// Alef and the letters U+0628 to U+063A and U+0641 to U+064A.
  static final letters = List<int>.unmodifiable([
    0x0627,
    for (var c = 0x0628; c <= 0x063A; c++) c,
    for (var c = 0x0641; c <= 0x064A; c++) c,
  ]);

  /// Fatha, damma, kasra, sukun.
  static const vowels = [0x064E, 0x064F, 0x0650, 0x0652];

  static const shadda = 0x0651;

  /// Every code point this generator writes, besides U+0020.
  static Set<int> get codePoints => {...letters, ...vowels, shadda};

  /// One nonsense word of [minLetters] to [maxLetters] letters. Long runs of
  /// random letters keep it from being a real word.
  String word({int minLetters = 5, int maxLetters = 9}) {
    final runes = <int>[];
    final length = minLetters + _random.nextInt(maxLetters - minLetters + 1);
    for (var i = 0; i < length; i++) {
      runes.add(letters[_random.nextInt(letters.length)]);
      if (_random.nextInt(8) == 0) runes.add(shadda);
      if (_random.nextInt(3) > 0) {
        runes.add(vowels[_random.nextInt(vowels.length)]);
      }
    }
    return String.fromCharCodes(runes);
  }

  /// [words] nonsense words, each followed by one U+0020 but the last.
  String phrase(int words) =>
      [for (var i = 0; i < words; i++) word()].join(' ');
}
