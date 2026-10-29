import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../integrity/pack_integrity_suite.dart';
import '../ui/core/share/share_test_pack.dart';

// SH-01, SH-05, NF-20: what the user copies is the pack's text. No template is
// typed here, and no copied text is ever printed.

/// The bytes of the full copy format filled with the stored [ayah] and
/// [surah] and the number [number] in Arabic-Indic digits. The format is the
/// app's own, found by filling it with markers; the pack's bytes are spliced
/// in unchanged.
List<int> expectedCopy(List<int> ayah, List<int> surah, int number) {
  final slots = {
    'AYAH-MARKER': ayah,
    'SURAH-MARKER': surah,
    'NUMBER-MARKER': utf8.encode(arabicDigits(number)),
  };
  final template = flowL10n.copyFormatFull(
    'AYAH-MARKER',
    'SURAH-MARKER',
    'NUMBER-MARKER',
  );
  final places = [
    for (final marker in slots.keys)
      if (template.indexOf(marker) case final at when at >= 0) (at, marker),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  if (places.length != slots.length) fail('copyFormatFull lacks a placeholder');
  final bytes = <int>[];
  var from = 0;
  for (final (at, marker) in places) {
    bytes
      ..addAll(utf8.encode(template.substring(from, at)))
      ..addAll(slots[marker]!);
    from = at + marker.length;
  }
  return bytes..addAll(utf8.encode(template.substring(from)));
}

/// Copies each of [ayat] with [copy], which opens the copy sheet, presses
/// the copy button and returns the text on the clipboard afterwards, and
/// returns what differs from the stored text.
Future<List<String>> copyAll(
  List<PackAyah> ayat,
  Future<String?> Function(QuranAddress ayah) copy,
) async {
  final problems = <String>[];
  for (final ayah in ayat) {
    final copied = await copy(ayah.address);
    if (copied == null) {
      problems.add('${ayah.address}: nothing was copied');
      continue;
    }
    final mismatch = byteMismatch(
      utf8.encode(copied),
      expectedCopy(ayah.stored, ayah.storedName, ayah.address.ayah),
    );
    if (mismatch != null) problems.add('${ayah.address}: $mismatch');
  }
  return problems;
}

/// Every ayah of the bundled synthetic pack is copied through the app, from
/// the sheet the router opens, as the pack stores it, and the toolbar leads to
/// the same sheet.
Future<void> copyEverySyntheticAyah(WidgetTester tester, FlowRun run) async {
  final pack = await real(
    tester,
    () => PackUnderTest.load(run.rig.bundle.path),
  );
  addTearDown(pack.close);
  final ayat = await real(tester, () => packAyat(pack, pack.openRepository()));
  expect(ayat.length, pack.manifest.counts.ayat);

  await run.session(tester, (session) async {
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // The user's way to the sheet: the ayah, then «نسخ», then «انسخ».
    await tapNamed(tester, flowL10n.tabMushaf);
    final marker = find.byWidgetPredicate(
      (w) => w is AyahMarker && w.number == 3 && !w.playing,
    );
    await tester.tap(marker.first);
    await tester.pumpAndSettle();
    expect(find.byType(AyahToolbar), findsOneWidget);
    await clearClipboard(tester);
    await tapNamed(tester, flowL10n.toolbarCopy);
    await tapNamed(tester, flowL10n.copyAction);
    final first = ayat.firstWhere((a) => a.address.toString() == 'hafs:1:3');
    expect(
      byteMismatch(
        utf8.encode((await copiedText(tester))!),
        expectedCopy(first.stored, first.storedName, 3),
      ),
      isNull,
    );

    // Every ayah, through the sheet's route.
    final problems = await copyAll(ayat, (address) async {
      await clearClipboard(tester);
      router.go(Routes.mushafRead(address));
      await tester.pumpAndSettle();
      unawaited(router.push<Object?>(Routes.copySheet(address)));
      await tester.pumpAndSettle();
      await tapNamed(tester, flowL10n.copyAction);
      return copiedText(tester);
    });
    expectNoProblems(problems);
  });
}
