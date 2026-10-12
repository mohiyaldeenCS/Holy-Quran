import 'synthetic_files.dart';
import 'synthetic_pack.dart';

/// The form kinds of a synthetic format 2 text pack.
const defaultSyntheticSearchFormKinds = [
  'synthetic-plain',
  'synthetic_spelled',
];

/// One defect of the search forms of a format 2 text pack.
enum SyntheticSearchFormFault {
  /// The first search form is not stored; the manifest still counts one form
  /// per word of each kind.
  missing,

  /// Every word also has a form of [unlistedSearchFormKind], which the
  /// manifest does not list.
  unlistedKind,

  /// The first search form is stored empty.
  empty,
}

/// The kind [SyntheticSearchFormFault.unlistedKind] adds.
const unlistedSearchFormKind = 'synthetic-unlisted';

/// A search form as stored: never derived from the ayah, as the pipeline
/// derives none either (D-037).
typedef SyntheticSearchForm = ({
  int surah,
  int ayah,
  int word,
  String kind,
  String form,
});

/// One form of each of [kinds] for every word of [surahs], in key order. The
/// forms are plainly synthetic text that would change under any normalising
/// or trimming: the first is NFC-unstable and has edge spaces.
List<SyntheticSearchForm> syntheticSearchForms(
  List<SyntheticSurah> surahs,
  List<String> kinds,
) => [
  for (final (s, surah) in surahs.indexed)
    for (final (a, ayah) in surah.ayat.indexed)
      for (var w = 1; w <= ayah.spans.length; w++)
        for (final kind in [...kinds]..sort())
          (
            surah: s + 1,
            ayah: a + 1,
            word: w,
            kind: kind,
            form: s == 0 && a == 0 && w == 1
                ? ' e\u{301} \u{E9} $syntheticArabic  '
                : '$syntheticArabic $kind ${s + 1}:${a + 1}:$w',
          ),
];
