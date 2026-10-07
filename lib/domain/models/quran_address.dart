/// An ayah, or a word of it, in one riwaya. Canonical form: `hafs:2:255` or
/// `hafs:2:255:3`. No upper bound is checked here; the counts come from the
/// pack.
final class QuranAddress implements Comparable<QuranAddress> {
  QuranAddress(this.riwaya, this.surah, this.ayah, [this.word]) {
    if (!_riwaya.hasMatch(riwaya)) {
      throw ArgumentError.value(
        riwaya,
        'riwaya',
        'must match ${_riwaya.pattern}',
      );
    }
    _checkNumber(surah, 'surah');
    _checkNumber(ayah, 'ayah');
    if (word case final word?) _checkNumber(word, 'word');
  }

  final String riwaya;
  final int surah;
  final int ayah;
  final int? word;

  /// A signed 32-bit integer, so that any reader of the form can hold it.
  static const _maxNumber = (1 << 31) - 1;
  static final _riwaya = RegExp(r'^[a-z][a-z0-9_]*$');
  static final _canonical = RegExp(
    r'^([a-z][a-z0-9_]*):([1-9][0-9]*):([1-9][0-9]*)(?::([1-9][0-9]*))?$',
  );

  /// Throws a [FormatException] unless [source] is in the canonical form.
  static QuranAddress parse(String source) =>
      tryParse(source) ??
      (throw FormatException('Not a canonical Quran address', source));

  static QuranAddress? tryParse(String source) {
    final match = _canonical.firstMatch(source);
    if (match == null) return null;
    final surah = _number(match[2]!);
    final ayah = _number(match[3]!);
    final wordDigits = match[4];
    final word = wordDigits == null ? null : _number(wordDigits);
    if (surah == null || ayah == null || (wordDigits != null && word == null)) {
      return null;
    }
    return QuranAddress(match[1]!, surah, ayah, word);
  }

  static int? _number(String digits) {
    if (digits.length > 10) return null;
    final value = int.parse(digits);
    return value <= _maxNumber ? value : null;
  }

  static void _checkNumber(int value, String name) {
    if (value < 1 || value > _maxNumber) {
      throw ArgumentError.value(value, name, 'must be in 1..$_maxNumber');
    }
  }

  bool get isWord => word != null;

  /// This address without its word.
  QuranAddress get ayahAddress =>
      isWord ? QuranAddress(riwaya, surah, ayah) : this;

  /// Orders by surah, ayah, then word, an ayah before its words. Throws an
  /// [ArgumentError] when [other] is in another riwaya.
  @override
  int compareTo(QuranAddress other) {
    if (other.riwaya != riwaya) {
      throw ArgumentError.value(other, 'other', 'is not in riwaya $riwaya');
    }
    if (surah != other.surah) return surah.compareTo(other.surah);
    if (ayah != other.ayah) return ayah.compareTo(other.ayah);
    return (word ?? 0).compareTo(other.word ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      other is QuranAddress &&
      other.riwaya == riwaya &&
      other.surah == surah &&
      other.ayah == ayah &&
      other.word == word;

  @override
  int get hashCode => Object.hash(riwaya, surah, ayah, word);

  @override
  String toString() => '$riwaya:$surah:$ayah${isWord ? ':$word' : ''}';
}
