import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/clip.dart';
import '../../testing/golden.dart';
import '../../testing/packs/synthetic_pack.dart';
import 'pack_integrity_suite.dart';

// The widgets that show pack text draw its stored bytes (PRD section 9.4;
// docs/plans/M0.5.md, step F): every ayah of a synthetic pack in AyahRow,
// SearchResult and ShareCard, and every surah name in SurahName in each
// format. The texts come through the production path, the bytes they are
// compared with from the independent reader. Every string is synthetic;
// non-ASCII characters are written as escapes.

/// Surah names that any trimming, normalising or re-encoding would change:
/// leading, trailing and double spaces, a decomposed and a precomposed
/// e-acute, a character outside the BMP, an Arabic-script synthetic phrase
/// with a combining fatha, and a right-to-left mark.
const _names = [
  ' Synthetic  name e\u{301} ',
  _arabicScriptName,
  'Synthetic \u{E9} \u{1F600} name',
];

const _arabicScriptName =
    '\u{627}\u{633}\u{645}\u{64E} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}'
    '\u{200F}';

/// Long enough that a result [_resultWidth] wide cuts it, short enough that
/// a share card holds it at [_cardAyahSize].
const _longAyah = SyntheticAyah(
  'Synthetic long ayah that wraps past the height of a clamped result',
);

/// The default synthetic surahs under [_names], the last with [_longAyah]
/// added.
final _surahs = [
  for (final (index, surah) in defaultSyntheticSurahs.indexed)
    SyntheticSurah(
      name: _names[index],
      basmala: surah.basmala,
      revelationPlace: surah.revelationPlace,
      revelationOrder: surah.revelationOrder,
      ayat: [
        ...surah.ayat,
        if (index == defaultSyntheticSurahs.length - 1) _longAyah,
      ],
    ),
];

/// Narrow enough that [_longAyah] wraps past the height a clamp shows.
const double _resultWidth = 200;

/// The height a clamp shows at the default text size
/// (`.qk-result-body.is-clamped`).
const double _clampHeight = 92;

/// The least size a caller may fit a share card's ayah to (D-085).
const double _cardAyahSize = 22;

/// The ARB templates, read from the file so that no template is typed here.
final _templates =
    jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, Object?>;

final _placeholder = RegExp(r'\{(\w+)\}');

typedef _Surah = ({int number, PackText name, Uint8List stored, int ayahCount});

/// An ayah and its surah's name as the repository gives them, each with the
/// bytes the independent reader finds.
typedef _Ayah = ({
  QuranAddress address,
  PackText text,
  Uint8List stored,
  PackText surahName,
  Uint8List storedName,
});

void main() {
  late Directory root;
  PackUnderTest? loaded;
  var surahs = <_Surah>[];
  var ayat = <_Ayah>[];

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('widget_text_integrity');
    final built = await buildSyntheticPack(root, surahs: _surahs);
    final pack = loaded = await PackUnderTest.load(built.directory.path);
    (surahs, ayat) = await _texts(pack);
  });
  tearDownAll(() async {
    loaded?.close();
    await root.delete(recursive: true);
  });

  test('every surah and ayah the pack counts is under test', () {
    final counts = (loaded ?? fail('The pack was not loaded.')).manifest.counts;
    expect(surahs, hasLength(counts.surahs));
    expect(ayat, hasLength(counts.ayat));
  });

  test('the surah names hold what any change would break', () {
    expect(_names, hasLength(defaultSyntheticSurahs.length));
    expect(_names, anyElement(startsWith(' ')));
    expect(_names, anyElement(endsWith(' ')));
    expect(_names, anyElement(contains('  ')));
    expect(_names, anyElement(contains('e\u{301}')));
    expect(_names, anyElement(contains('\u{E9}')));
    expect(_names.any((name) => name.runes.any((r) => r > 0xFFFF)), isTrue);
    expect(_names, anyElement(contains('\u{64E}')));
    expect(_names, anyElement(contains('\u{200F}')));
  });

  for (final format in SurahNameFormat.values) {
    testWidgets('SurahName draws every stored surah name unchanged, '
        '${format.name}', (tester) async {
      final problems = <String>[];
      for (final surah in surahs) {
        final ayah = _carriesAyah(format) ? surah.ayahCount : null;
        await tester.pumpWidget(
          goldenApp(
            ReadingTheme.paper,
            SurahName(
              surah.name,
              style: const TextStyle(),
              format: format,
              ayah: ayah,
            ),
          ),
        );
        problems.addAll(
          _nameProblems(
            tester,
            find.byType(SurahName),
            'surah ${surah.number} name, ${format.name}',
            surah.stored,
            ayah,
          ),
        );
      }
      expectNoProblems(problems);
    });
  }

  testWidgets('AyahRow draws the stored bytes of every ayah', (tester) async {
    final problems = <String>[];
    for (final ayah in ayat) {
      await tester.pumpWidget(
        goldenApp(
          ReadingTheme.paper,
          AyahRow(
            number: ayah.address.ayah,
            text: ayah.text,
            onPlay: _ignore,
            onBookmark: _ignore,
            onStudy: _ignore,
          ),
        ),
      );
      problems.addAll(
        _quranTextProblems(
          tester,
          find.byType(AyahRow),
          '${ayah.address} AyahRow',
          ayah.stored,
        ),
      );
    }
    expectNoProblems(problems);
  });

  for (final clamp in [false, true]) {
    final state = clamp ? 'clamped' : 'whole';
    testWidgets('SearchResult, $state, draws the stored bytes of every ayah '
        'and its surah name', (tester) async {
      final problems = <String>[];
      var cut = 0;
      for (final ayah in ayat) {
        await tester.pumpWidget(
          goldenApp(
            ReadingTheme.paper,
            SizedBox(
              width: _resultWidth,
              child: SearchResult(
                surahName: ayah.surahName,
                ayahNumber: ayah.address.ayah,
                ayahText: ayah.text,
                onContext: _ignore,
                onOpen: _ignore,
                clamp: clamp,
              ),
            ),
          ),
        );
        final result = find.byType(SearchResult);
        final where = '${ayah.address} SearchResult $state';
        problems
          ..addAll(_quranTextProblems(tester, result, where, ayah.stored))
          ..addAll(
            _nameProblems(
              tester,
              result,
              '$where reference',
              ayah.storedName,
              ayah.address.ayah,
            ),
          );
        if (_isCut(tester, result)) cut++;
      }
      expectNoProblems(problems);
      // A clamp that cut nothing would prove nothing about cut ayat.
      expect(cut, clamp ? greaterThan(0) : 0);
    });
  }

  for (final design in ShareCardDesign.values) {
    testWidgets('ShareCard, ${design.name}, draws the stored bytes of every '
        'ayah and its surah name', (tester) async {
      final problems = <String>[];
      for (final ayah in ayat) {
        await tester.pumpWidget(
          goldenApp(
            ReadingTheme.paper,
            ShareCard(
              ayah: ayah.text,
              surahName: ayah.surahName,
              ayahNumber: ayah.address.ayah,
              ayahFontSize: _cardAyahSize,
              design: design,
            ),
          ),
        );
        final card = find.byType(ShareCard);
        final where = '${ayah.address} ShareCard ${design.name}';
        problems
          ..addAll(_quranTextProblems(tester, card, where, ayah.stored))
          ..addAll(
            _nameProblems(
              tester,
              card,
              '$where reference',
              ayah.storedName,
              ayah.address.ayah,
            ),
          );
      }
      expectNoProblems(problems);
    });
  }
}

void _ignore() {}

/// Every surah and ayah of [pack], in the order the independent reader
/// stores them, each with what the repository gives for it.
Future<(List<_Surah>, List<_Ayah>)> _texts(PackUnderTest pack) async {
  final repository = pack.openRepository();
  T ok<T>(Result<T> result, String what) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$what: $error'),
  };
  final names = {
    for (final surah in ok(await repository.surahs(), 'surah list'))
      surah.number: surah.name,
  };
  final surahs = <_Surah>[];
  final ayat = <_Ayah>[];
  for (final row in pack.raw.surahs()) {
    final name =
        names[row.number] ??
        fail('surah ${row.number}: the repository does not list it');
    surahs.add((
      number: row.number,
      name: name,
      stored: row.name,
      ayahCount: row.ayahCount,
    ));
    for (final (number, bytes) in pack.raw.ayat(row.number)) {
      final address = QuranAddress(repository.riwaya, row.number, number);
      ayat.add((
        address: address,
        text: ok(await repository.ayahText(address), '$address'),
        stored: bytes,
        surahName: name,
        storedName: row.name,
      ));
    }
  }
  return (surahs, ayat);
}

/// The problems of the one [QuranText] inside [widget], which should draw
/// [stored].
List<String> _quranTextProblems(
  WidgetTester tester,
  Finder widget,
  String where,
  List<int> stored,
) {
  final quranText = find.descendant(
    of: widget,
    matching: find.byType(QuranText),
  );
  final count = quranText.evaluate().length;
  if (count != 1) return ['$where: $count QuranText widgets, not one'];
  final drawn = find.descendant(of: quranText, matching: find.byType(RichText));
  return drawnTextProblems(
    where,
    tester.widget<RichText>(drawn).text,
    tester.renderObject<RenderParagraph>(drawn).text,
    stored,
  );
}

/// The problems of the one [SurahName] at or inside [widget], which should
/// draw the stored name [stored] whole in its format's ARB template, with
/// [ayah] when the format carries one.
List<String> _nameProblems(
  WidgetTester tester,
  Finder widget,
  String where,
  List<int> stored,
  int? ayah,
) {
  final surahName = find.descendant(
    of: widget,
    matching: find.byType(SurahName),
    matchRoot: true,
  );
  final count = surahName.evaluate().length;
  if (count != 1) return ['$where: $count SurahName widgets, not one'];
  final format = tester.widget<SurahName>(surahName).format;
  final drawn = find.descendant(of: surahName, matching: find.byType(RichText));
  final laidOut = tester.renderObject<RenderParagraph>(drawn).text;
  return [
    if (!_holds(utf8.encode(laidOut.toPlainText()), stored))
      '$where: the paragraph does not hold the stored name',
    ...drawnTextProblems(
      '$where, ${format.name}',
      tester.widget<RichText>(drawn).text,
      laidOut,
      _filled(format, stored, _carriesAyah(format) ? ayah : null),
    ),
  ];
}

bool _carriesAyah(SurahNameFormat format) => switch (format) {
  SurahNameFormat.withAyah || SurahNameFormat.titledWithAyah => true,
  SurahNameFormat.name || SurahNameFormat.titled => false,
};

/// The bytes [format] should draw: its ARB template, with the stored name
/// [name] for `{name}` and [ayah] in Arabic-Indic digits for `{ayah}`.
List<int> _filled(SurahNameFormat format, List<int> name, int? ayah) {
  final template = switch (format) {
    SurahNameFormat.name => '{name}',
    SurahNameFormat.titled => _templates['surahTitle']! as String,
    SurahNameFormat.withAyah => _templates['surahAyahReference']! as String,
    SurahNameFormat.titledWithAyah =>
      _templates['surahTitleAyahReference']! as String,
  };
  final bytes = <int>[];
  var at = 0;
  for (final placeholder in _placeholder.allMatches(template)) {
    bytes
      ..addAll(utf8.encode(template.substring(at, placeholder.start)))
      ..addAll(switch (placeholder[1]) {
        'name' => name,
        'ayah' => utf8.encode(
          arabicDigits(ayah ?? fail('${format.name} has no ayah')),
        ),
        final other => fail('${format.name} has the placeholder $other'),
      });
    at = placeholder.end;
  }
  return bytes..addAll(utf8.encode(template.substring(at)));
}

/// Whether [bytes] hold [part] at some offset.
bool _holds(List<int> bytes, List<int> part) {
  for (var start = 0; start + part.length <= bytes.length; start++) {
    var i = 0;
    while (i < part.length && bytes[start + i] == part[i]) {
      i++;
    }
    if (i == part.length) return true;
  }
  return false;
}

/// Whether the ayah inside the [SearchResult] [result] is laid out at least
/// a pixel taller than the clips of its ancestors up to the result let it
/// paint. A cut must also be painted, at the clamp's height.
bool _isCut(WidgetTester tester, Finder result) {
  final ayah = tester.renderObject<RenderBox>(
    find.descendant(
      of: find.descendant(of: result, matching: find.byType(QuranText)),
      matching: find.byType(RichText),
    ),
  );
  final within = tester.renderObject(result);
  if (ayah.size.height - shownRect(ayah, within).height < 1) return false;
  expect(
    result,
    paints..clipRect(rect: cutClip(ayah, within, _clampHeight)),
    reason: 'the ayah is declared cut, so the cut must be painted',
  );
  return true;
}
