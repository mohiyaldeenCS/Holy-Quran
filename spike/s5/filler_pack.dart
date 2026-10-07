import '../../testing/packs/synthetic_pack.dart';

/// Three surahs of plainly synthetic filler, so that `text.sqlite` comes to
/// roughly [bytes] and a download takes long enough to interrupt. [tag]
/// makes two versions differ. Each ayah is one word.
List<SyntheticSurah> fillerSurahs({required int bytes, required String tag}) {
  const perAyah = 260;
  final ayat = (bytes ~/ perAyah).clamp(8, 1 << 20);
  final filler = 'synthetic filler ' * 12;
  return [
    for (var s = 1; s <= 3; s++)
      SyntheticSurah(
        name: 'Synthetic filler surah $s',
        ayat: [
          for (var a = 1; a <= ayat ~/ 3; a++)
            _ayah('Synthetic $tag $s:$a $filler'),
        ],
      ),
  ];
}

SyntheticAyah _ayah(String text) =>
    SyntheticAyah(text, words: [(0, text.length)]);
