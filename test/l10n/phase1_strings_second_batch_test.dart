import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The keys P1-38 added from Appendix B of docs/plans/PHASE1.md, approved by the
/// owner (D-128 (4)), and the copy preview's reference part (D-130).
const _ownerKeys = [
  'openAtLastPosition',
  'keepScreenAwake',
  'textSizeLabel',
  'distractionFreeMode',
  'playerSpeed',
  'playerEndOfAyah',
  'playerEndOfSurah',
  'stopAfterAyah',
  'stopAfterPage',
  'stopAfterSurah',
  'playerStop',
  'nextSurah',
  'previousSurah',
  'qualityLabel',
  'wifiOnly',
  'sortNewest',
  'noteLabel',
  'tagsLabel',
  'searchHistoryTitle',
  'resourceUpdate',
  'resourceInProgress',
  'repeatUnlimited',
  'tafsirReaderTitle',
  'recitationPickerTitle',
  'defaultTafsirLabel',
  'resourcesDownloaded',
  'resourcesAvailable',
  'sourceAuthor',
  'sourceEditionOrEditor',
  'sourceDigitisation',
  'versionLabel',
  'copyFormatAyahOnly',
  'copyFormatWithSurah',
  'reportError',
  'setupStepDisplayMode',
  'setupStepLevel',
  'setupStepRecitation',
  'copyReferenceSurah',
];

/// The keys P1-38 added from Appendix C, worded by the lead on the owner's
/// delegation (D-128 (5)). The last two are plurals.
const _leadKeys = [
  'setupDisplayModePrompt',
  'setupLevelPrompt',
  'setupRecitationPrompt',
  'setupContinue',
  'setupFinish',
  'reportSend',
  'reportNote',
  'integrityBaseTitle',
  'integrityBaseBody',
  'integrityPackTitle',
  'integrityPackBody',
  'integrityIconLabel',
  'pageNotFound',
  'juzNotFound',
  'hizbNotFound',
  'rubNotFound',
  'surahNotFound',
  'addressUnreadable',
  'levelAlwaysShow',
  'lowSpace',
  'storageSummary',
  'downloadSize',
  'waitingForWifi',
  'updateAvailable',
  'deletePackTitle',
  'deletePackBody',
  'downloadNotSaved',
  'noNotesYet',
  'noSearchResults',
  'noTafsirsYet',
  'noRecitationsYet',
  'queueEmpty',
  'noteHint',
  'noteSave',
  'noteDelete',
  'shareSheetTitle',
  'addToQueue',
  'repeatCounter',
  'rangeFrom',
  'rangeTo',
  'repeatUnitAyah',
  'repeatUnitRange',
  'userDataNotSaved',
  'searchPlaces',
  'minutesCount',
];

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

  test('the key lists have no duplicates', () {
    final all = [..._ownerKeys, ..._leadKeys];
    expect(all.toSet(), hasLength(all.length));
  });

  void check(String key, String description) {
    group(key, () {
      final message = arb[key];
      final meta = arb['@$key'] as Map<String, dynamic>?;

      test('is in the ARB file and the generated class', () {
        expect(message, isA<String>());
        expect(
          RegExp('String (get )?$key\\b').hasMatch(generated),
          isTrue,
          reason: 'run flutter gen-l10n',
        );
      });

      test('has a description naming who worded it', () {
        expect(meta?['description'], startsWith(description));
      });

      test('has no Western digit, exclamation mark or emoji', () {
        expect(message, isNot(matches(_westernDigit)));
        expect(message, isNot(matches(_exclamation)));
        expect(message, isNot(matches(_emoji)));
      });

      test('types every placeholder, plurals with count and digits', () {
        final text = message as String;
        final used = text.contains(', plural,')
            ? {'count', 'digits'}
            : RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m[1]).toSet();
        final declared =
            (meta?['placeholders'] as Map<String, dynamic>?) ?? const {};
        expect(declared.keys.toSet(), used);
        for (final entry in declared.entries) {
          final type = (entry.value as Map<String, dynamic>)['type'];
          expect(type, entry.key == 'count' ? 'int' : 'String');
        }
      });
    });
  }

  for (final key in _ownerKeys) {
    check(key, 'Owner, 2026-10-28');
  }
  for (final key in _leadKeys) {
    check(key, 'Lead, 2026-10-28, D-128 (5)');
  }
}
