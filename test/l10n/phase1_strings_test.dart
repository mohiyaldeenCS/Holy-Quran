import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The keys P1-01 added from Appendix A of docs/plans/PHASE1.md.
const _phase1Keys = [
  'homeGreeting',
  'homeContinueHint',
  'readingPositionLine',
  'indexTitle',
  'indexSummary',
  'indexTabSurahs',
  'indexTabJuz',
  'indexTabHizb',
  'juzLabel',
  'hizbLabel',
  'rubLabel',
  'pageLabel',
  'juzPageLine',
  'juzHizbLine',
  'sajdaLabel',
  'surahInfoLine',
  'surahIntroTitle',
  'goToTitle',
  'goToSurah',
  'goToAyah',
  'goToPage',
  'goToJuz',
  'goToHizb',
  'goToRub',
  'ayahNotInSurah',
  'contextSubtitle',
  'contextAmountLabel',
  'contextOneAyah',
  'contextSurah',
  'toolbarBookmark',
  'toolbarStudy',
  'toolbarCopy',
  'toolbarShare',
  'copySheetTitle',
  'copyAyahOnly',
  'copyWithSurah',
  'copyWithSurahAndNumber',
  'copyAction',
  'copyFormatFull',
  'shareDesignEmerald',
  'shareDesignPaper',
  'shareDesignNight',
  'shareTooLong',
  'searchTitle',
  'searchSortNearest',
  'searchSortFrequent',
  'searchScopeAll',
  'tafsirNoPassage',
  'connectionFailed',
  'noBookmarksYet',
  'undo',
  'back',
  'returnToRecitation',
  'wordTimingTag',
  'resourceManagerTitle',
  'resourceCategoryRecitations',
  'resourceCategoryTafsirs',
  'resourceCategoryPageMushaf',
  'resourceCategoryRiwayat',
  'resourceCategoryTajweed',
  'resourceCategoryLinguistic',
  'resourceAvailableMasculine',
  'resourceRedownload',
  'settingsTitle',
  'themeLabel',
  'textSettingsLabel',
  'followSystemDark',
  'sourcesTitle',
  'bookmarksAndNotes',
  'playerChange',
  'playerAyahOfTotal',
  'playerSilenceSeconds',
  'queueLabel',
  'recitationDownloadedLine',
  'playOnlyAyah',
  'playToPageEnd',
  'playToSurahEnd',
  'playToJuzEnd',
  'playUntilStopped',
];

/// Where a wording may come from: a board, the component reference, the
/// design-system notes, the PRD or the design-system document.
final _source = RegExp(
  r'Source: (design/identity-boards/\w+\.dc\.html'
  r'|design/design-system/components/src/index\.jsx'
  r'|design/design-system/README\.md'
  r'|docs/prd/PRD\.ar\.md'
  r'|docs/DESIGN_SYSTEM\.md)',
);

final _westernDigit = RegExp('[0-9]');
final _exclamation = RegExp('[!\u01C3\u203C\uFF01]');
final _emoji = RegExp(
  '[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\uFE0F\u200D]',
  unicode: true,
);

void main() {
  final arb =
      jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
          as Map<String, dynamic>;
  final generated = File('lib/l10n/app_localizations.dart').readAsStringSync();

  test('the key list has no duplicates', () {
    expect(_phase1Keys.toSet(), hasLength(_phase1Keys.length));
  });

  for (final key in _phase1Keys) {
    group(key, () {
      final message = arb[key];
      final meta = arb['@$key'] as Map<String, dynamic>?;

      test('is in the ARB file and the generated class', () {
        expect(message, isA<String>());
        expect(
          generated,
          matches(RegExp('String (get )?$key\\b')),
          reason: 'run flutter gen-l10n',
        );
      });

      test('has a description naming its source', () {
        expect(meta?['description'], matches(_source));
      });

      test('takes its wording from the source it names', () {
        final path = _source.firstMatch(meta!['description'] as String)![1]!;
        final source = File(path).readAsStringSync();
        final fixedParts = (message as String)
            .split(RegExp(r'\{\w+\}'))
            .where((part) => part.isNotEmpty);
        for (final part in fixedParts) {
          expect(source, contains(part), reason: path);
        }
      });

      test('has no Western digit, exclamation mark or emoji', () {
        expect(message, isNot(matches(_westernDigit)));
        expect(message, isNot(matches(_exclamation)));
        expect(message, isNot(matches(_emoji)));
      });

      test('types every placeholder as an already formatted String', () {
        final used = RegExp(
          r'\{(\w+)\}',
        ).allMatches(message as String).map((m) => m[1]).toSet();
        final declared =
            (meta?['placeholders'] as Map<String, dynamic>?) ?? const {};
        expect(declared.keys.toSet(), used);
        for (final placeholder in declared.values) {
          expect((placeholder as Map<String, dynamic>)['type'], 'String');
        }
      });
    });
  }
}
